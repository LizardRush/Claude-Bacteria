#import "InputPanel.h"

// Borderless panels return NO from canBecomeKeyWindow by default — override it.
@interface _InputWindow : NSPanel
@end
@implementation _InputWindow
- (BOOL)canBecomeKeyWindow  { return YES; }
- (BOOL)canBecomeMainWindow { return NO;  }
@end

// ─────────────────────────────────────────────────────────────────────────────

@interface InputPanel () <NSTextFieldDelegate>
@end

@implementation InputPanel {
    _InputWindow *_panel;
    NSTextField  *_field;
    InputCallback _callback;
}

+ (instancetype)shared {
    static InputPanel *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [InputPanel new]; });
    return s;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    CGFloat w = 300, h = 44;
    _panel = [[_InputWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, w, h)
                 styleMask:NSWindowStyleMaskBorderless
                   backing:NSBackingStoreBuffered
                     defer:NO];
    _panel.backgroundColor = [NSColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1];
    _panel.level           = NSPopUpMenuWindowLevel;
    _panel.collectionBehavior =
        NSWindowCollectionBehaviorMoveToActiveSpace | NSWindowCollectionBehaviorIgnoresCycle;
    _panel.opaque    = YES;
    _panel.hasShadow = YES;

    // Inner rounded box
    NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(4, 4, w - 8, h - 8)];
    box.boxType      = NSBoxCustom;
    box.fillColor    = [NSColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1];
    box.borderWidth  = 0;
    box.cornerRadius = 8;

    _field = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 7, w - 20, h - 18)];
    _field.bordered          = NO;
    _field.drawsBackground   = NO;
    _field.textColor         = [NSColor colorWithWhite:0.96 alpha:1];
    _field.font              = [NSFont systemFontOfSize:15];
    _field.focusRingType     = NSFocusRingTypeNone;
    _field.delegate          = self;
    _field.placeholderString = @"Ask bacteria…";
    [_field.cell setWraps:NO];
    [_field.cell setScrollable:YES];

    [box addSubview:_field];
    [_panel.contentView addSubview:box];
    return self;
}

- (void)showAtBacteriaX:(CGFloat)bx bacteriaY:(CGFloat)by callback:(InputCallback)cb {
    _callback          = [cb copy];
    _field.stringValue = @"";

    NSScreen *scr = [NSScreen mainScreen];
    CGFloat   sh  = scr.frame.size.height;
    CGFloat   w   = _panel.frame.size.width;
    CGFloat   h   = _panel.frame.size.height;

    CGFloat winX = MAX(4, MIN(bx - w/2, scr.frame.size.width - w - 4));
    CGFloat winY = MAX(4, MIN(sh - by + 8, sh - h - 4));
    [_panel setFrameOrigin:NSMakePoint(winX, winY)];

    // Accessory-policy apps can't receive key events without a brief policy lift.
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [_panel makeKeyAndOrderFront:nil];
    [_panel makeFirstResponder:_field];
}

// ── NSTextFieldDelegate ───────────────────────────────────────────────────────

- (void)controlTextDidEndEditing:(NSNotification *)note {
    if ([note.userInfo[@"NSTextMovement"] integerValue] == NSReturnTextMovement)
        [self _submit];
}

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)tv
doCommandBySelector:(SEL)cmd {
    if (cmd == @selector(cancelOperation:)) { [self _dismiss]; return YES; }
    return NO;
}

// ── private ──────────────────────────────────────────────────────────────────

- (void)_submit {
    NSString *text = [_field.stringValue copy];
    [self _dismiss];
    if (_callback && text.length) _callback(text);
    _callback = nil;
}

- (void)_dismiss {
    [_panel orderOut:nil];
    // Return to accessory policy so the app hides from the Dock again.
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

@end
