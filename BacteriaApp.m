#import "BacteriaApp.h"
#import "SpriteSheet.h"
#import "InputPanel.h"
#import "ChatBubble.h"
#import "ClaudeClient.h"
#import <math.h>

#define SPRITE_SIZE  128.0
#define WALK_SPEED     1.5
#define SCREEN_MARGIN 20.0
#define SPRITE_FPS     8

// ── BacteriaView ─────────────────────────────────────────────────────────────

@class BacteriaApp;
@interface BacteriaApp (Events)
- (void)handleLeftClick;
- (void)setHovered:(BOOL)hovered;
@end

@interface BacteriaView : NSView
@property (nonatomic, strong) SpriteSheet *sprite;
@property (nonatomic) NSInteger frameIdx;
@property (nonatomic) CGFloat   visualAngle; // degrees, screen coords (Y-down), 0=right CW+
@property (nonatomic, weak) BacteriaApp *controller;
@end

@implementation BacteriaView

- (BOOL)isFlipped           { return YES; }  // Y down, matches screen coords
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }

- (void)drawRect:(NSRect)dirty {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextClearRect(ctx, dirty);

    CGImageRef frame = [self.sprite frameAtIndex:self.frameIdx];
    if (!frame) return;

    CGFloat cx = SPRITE_SIZE / 2, cy = SPRITE_SIZE / 2;
    CGContextSaveGState(ctx);
    // Flip Y back for CG drawing (isFlipped=YES inverts Y for AppKit drawing,
    // but CGContext origin is still bottom-left inside drawRect on a flipped view)
    CGContextTranslateCTM(ctx, cx, cy);
    CGContextRotateCTM(ctx, self.visualAngle * M_PI / 180.0);
    CGContextTranslateCTM(ctx, -cx, -cy);
    CGContextDrawImage(ctx, CGRectMake(0, 0, SPRITE_SIZE, SPRITE_SIZE), frame);
    CGContextRestoreGState(ctx);
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *ta in self.trackingAreas.copy)
        [self removeTrackingArea:ta];
    [self addTrackingArea:[[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
               owner:self userInfo:nil]];
}

- (void)mouseEntered:(NSEvent *)e { [self.controller setHovered:YES]; }
- (void)mouseExited:(NSEvent *)e  { [self.controller setHovered:NO];  }

- (void)mouseDown:(NSEvent *)e { [self.controller handleLeftClick]; }

- (void)rightMouseDown:(NSEvent *)e {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [[menu addItemWithTitle:@"Brain" action:@selector(openBrain) keyEquivalent:@""] setTarget:self.controller];
    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:@"Quit"  action:@selector(quit)      keyEquivalent:@""] setTarget:self.controller];
    [NSMenu popUpContextMenu:menu withEvent:e forView:self];
}
@end

// ── BacteriaApp ──────────────────────────────────────────────────────────────

@implementation BacteriaApp {
    NSPanel      *_panel;
    BacteriaView *_view;
    SpriteSheet  *_walkSprite;
    SpriteSheet  *_idleSprite;
    NSTimer      *_animTimer;
    NSTimer      *_walkTimer;
    NSTimer      *_wanderTimer;
    NSTimer      *_mouseTimer;

    CGFloat _x, _y;          // screen coords (Y down), top-left corner
    CGFloat _dx, _dy;        // velocity in screen coords
    CGFloat _visualAngle;    // degrees, 0=right, CW positive

    BOOL _isAsking;
    BOOL _isHovered;
    ClaudeClient *_claude;
}

// ── setup ────────────────────────────────────────────────────────────────────

- (void)start {
    [self loadSprites];
    [self createWindow];
    [self startTimers];
    _claude = [ClaudeClient new];
    [_panel orderFrontRegardless];

    [NSWorkspace.sharedWorkspace.notificationCenter
        addObserver:self
           selector:@selector(activeSpaceChanged:)
               name:NSWorkspaceActiveSpaceDidChangeNotification
             object:nil];
}

- (void)activeSpaceChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Pull window into the newly active Space, then walk in from an edge
        [self->_panel orderFrontRegardless];
        [self spawnFromScreenEdge];
    });
}

// Place bacteria at a random edge of the main screen, moving inward.
- (void)spawnFromScreenEdge {
    NSScreen *scr = NSScreen.mainScreen;
    CGFloat sw = scr.frame.size.width, sh = scr.frame.size.height;
    CGFloat m = SCREEN_MARGIN, sz = SPRITE_SIZE;

    switch (arc4random_uniform(4)) {
        case 0: // top edge → walk down
            _x = m + arc4random_uniform((uint32_t)(sw - sz - 2*m));
            _y = m;
            _dx = 0; _dy = WALK_SPEED; break;
        case 1: // right edge → walk left
            _x = sw - sz - m;
            _y = m + arc4random_uniform((uint32_t)(sh - sz - 2*m));
            _dx = -WALK_SPEED; _dy = 0; break;
        case 2: // bottom edge → walk up
            _x = m + arc4random_uniform((uint32_t)(sw - sz - 2*m));
            _y = sh - sz - m;
            _dx = 0; _dy = -WALK_SPEED; break;
        default: // left edge → walk right
            _x = m;
            _y = m + arc4random_uniform((uint32_t)(sh - sz - 2*m));
            _dx = WALK_SPEED; _dy = 0; break;
    }
    [_panel setFrame:[self toMacRect] display:YES];
}

- (NSString *)assetsDir {
    NSString *exe = NSBundle.mainBundle.executablePath;
    return [[exe stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"assets"];
}

- (void)loadSprites {
    NSString *a = [self assetsDir];
    _walkSprite = [[SpriteSheet alloc] initWithPath:
                   [a stringByAppendingPathComponent:@"main/walk.gif"]];
    _idleSprite = [[SpriteSheet alloc] initWithPath:
                   [a stringByAppendingPathComponent:@"main/idle.gif"]];
}

- (void)createWindow {
    _x = 100; _y = 100;   // screen coords
    // random initial direction
    CGFloat angle = (CGFloat)(arc4random_uniform(628)) / 100.0;
    _dx = cos(angle) * WALK_SPEED;
    _dy = sin(angle) * WALK_SPEED;
    _visualAngle = fmod(atan2(_dy, _dx) * 180.0 / M_PI + 360.0, 360.0);

    NSRect macRect = [self toMacRect];
    _panel = [[NSPanel alloc]
        initWithContentRect:macRect
                 styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                   backing:NSBackingStoreBuffered
                     defer:NO];
    _panel.backgroundColor  = [NSColor clearColor];
    _panel.opaque           = NO;
    _panel.hasShadow        = NO;
    _panel.level            = NSFloatingWindowLevel;
    // MoveToActiveSpace: window teleports to the current Space when ordered front.
    // Do NOT use CanJoinAllSpaces — bacteria lives on one Space at a time.
    _panel.collectionBehavior =
        NSWindowCollectionBehaviorMoveToActiveSpace |
        NSWindowCollectionBehaviorIgnoresCycle;
    _panel.becomesKeyOnlyIfNeeded = YES;

    _view = [[BacteriaView alloc] initWithFrame:NSMakeRect(0, 0, SPRITE_SIZE, SPRITE_SIZE)];
    _view.controller   = self;
    _view.sprite       = _walkSprite;
    _view.frameIdx     = 0;
    _view.visualAngle  = _visualAngle;
    _panel.contentView = _view;
}

// Convert _x,_y (screen coords, Y down) → macOS window frame (Y up)
- (NSRect)toMacRect {
    CGFloat sh = NSScreen.mainScreen.frame.size.height;
    return NSMakeRect(_x, sh - _y - SPRITE_SIZE, SPRITE_SIZE, SPRITE_SIZE);
}

// ── timers ───────────────────────────────────────────────────────────────────

- (void)startTimers {
    _animTimer   = [NSTimer scheduledTimerWithTimeInterval:1.0/SPRITE_FPS
                                                    target:self selector:@selector(tickAnimate)
                                                  userInfo:nil repeats:YES];
    _walkTimer   = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                    target:self selector:@selector(tickWalk)
                                                  userInfo:nil repeats:YES];
    _wanderTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                    target:self selector:@selector(tickWander)
                                                  userInfo:nil repeats:YES];
    _mouseTimer  = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                    target:self selector:@selector(tickMouse)
                                                  userInfo:nil repeats:YES];
}

- (void)tickAnimate {
    _view.frameIdx = (_view.frameIdx + 1) % _view.sprite.count;

    // travel angle in screen coords (Y down): atan2(dy, dx), positive = clockwise
    CGFloat target = fmod(atan2(_dy, _dx) * 180.0 / M_PI + 360.0, 360.0);
    CGFloat diff   = fmod(target - _visualAngle + 180.0 + 360.0, 360.0) - 180.0;
    _visualAngle   = fmod(_visualAngle + diff * 0.2 + 360.0, 360.0);
    _view.visualAngle = _visualAngle;

    [_view setNeedsDisplay:YES];
}

- (void)tickWalk {
    if (_isAsking || _isHovered) return;
    _x += _dx;  _y += _dy;

    // Bounce at the union of all physical screen bounds (enables cross-monitor walking).
    CGFloat mainH = NSScreen.mainScreen.frame.size.height;
    CGFloat m = SCREEN_MARGIN, sz = SPRITE_SIZE;
    CGFloat minX =  1e9, minY =  1e9;
    CGFloat maxX = -1e9, maxY = -1e9;

    for (NSScreen *scr in NSScreen.screens) {
        NSRect f = scr.frame;                      // macOS coords (Y up)
        CGFloat sx = f.origin.x;
        CGFloat sy = mainH - (f.origin.y + f.size.height);  // screen Y of screen top
        minX = MIN(minX, sx + m);
        minY = MIN(minY, sy + m);
        maxX = MAX(maxX, sx + f.size.width  - sz - m);
        maxY = MAX(maxY, sy + f.size.height - sz - m);
    }

    if (_x < minX)       { _x = minX; _dx =  fabs(_dx); }
    else if (_x > maxX)  { _x = maxX; _dx = -fabs(_dx); }
    if (_y < minY)       { _y = minY; _dy =  fabs(_dy); }
    else if (_y > maxY)  { _y = maxY; _dy = -fabs(_dy); }

    [_panel setFrame:[self toMacRect] display:NO];
}

- (void)tickWander {
    if (_isAsking || _isHovered) return;
    CGFloat a = atan2(_dy, _dx) + ((CGFloat)arc4random_uniform(100) - 50) / 100.0;
    _dx = cos(a) * WALK_SPEED;
    _dy = sin(a) * WALK_SPEED;
}

- (void)tickMouse {
    if (!_isAsking) return;
    NSPoint mouse  = [NSEvent mouseLocation];   // macOS coords (Y up)
    CGFloat sh     = NSScreen.mainScreen.frame.size.height;
    CGFloat mouseY = sh - mouse.y;             // convert to screen Y-down

    CGFloat cx = _x + SPRITE_SIZE/2;
    CGFloat cy = _y + SPRITE_SIZE/2;
    CGFloat ddx = mouse.x - cx;
    CGFloat ddy = mouseY  - cy;
    CGFloat dist = hypot(ddx, ddy);
    if (dist > 1) { _dx = ddx/dist * WALK_SPEED; _dy = ddy/dist * WALK_SPEED; }
}

// ── idle / sprite switch ──────────────────────────────────────────────────────

- (void)setIdle:(BOOL)idle {
    SpriteSheet *next = idle ? _idleSprite : _walkSprite;
    if (next != _view.sprite) { _view.sprite = next; _view.frameIdx = 0; }
}

- (void)setHovered:(BOOL)hovered {
    if (_isHovered == hovered) return;
    _isHovered = hovered;
    [self setIdle:_isHovered || _isAsking];
}

// ── clicks ────────────────────────────────────────────────────────────────────

- (void)handleLeftClick {
    CGFloat bx = _x + SPRITE_SIZE/2;
    CGFloat by = _y;
    [[InputPanel shared] showAtBacteriaX:bx bacteriaY:by callback:^(NSString *text) {
        [self handlePrompt:text];
    }];
}


- (void)openBrain {
    [[NSWorkspace sharedWorkspace] openURL:
        [NSURL fileURLWithPath:@"/tmp/bacteria_brain.log"]];
}

- (void)quit { [NSApp terminate:nil]; }

// ── Claude ────────────────────────────────────────────────────────────────────

- (void)handlePrompt:(NSString *)text {
    if (!text.length) return;
    _isAsking = YES;
    [self setIdle:YES];
    [self brainLog:[NSString stringWithFormat:@"\n[you] %@\n[bacteria] ", text]];

    [_claude sendMessage:text
                onChunk:^(NSString *c) { [self brainLog:c]; }
             onComplete:^(NSString *full) { [self handleResponse:full]; }
                onError:^(NSString *e)   {
                    [self brainLog:[NSString stringWithFormat:@"\n[err] %@\n", e]];
                    [self handleResponse:@"*confused bacteria noises*"];
                }];
}

- (void)handleResponse:(NSString *)text {
    _isAsking = NO;
    [self setIdle:NO];
    [self brainLog:@"\n"];
    [ChatBubble showText:text bacteriaX:_x bacteriaY:_y spriteSize:SPRITE_SIZE];
}

- (void)brainLog:(NSString *)text {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("brain.log", DISPATCH_QUEUE_SERIAL); });
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_async(q, ^{
        NSString *path = @"/tmp/bacteria_brain.log";
        if (![[NSFileManager defaultManager] fileExistsAtPath:path])
            [@"" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        [fh seekToEndOfFile];
        [fh writeData:data];
        [fh closeFile];
    });
}
@end
