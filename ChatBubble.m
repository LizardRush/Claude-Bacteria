#import "ChatBubble.h"

// ── BubbleView ──────────────────────────────────────────────────────────────

@interface BubbleView : NSView
@property (nonatomic, copy) NSString *text;
@end

@implementation BubbleView

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirty {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextClearRect(ctx, dirty);

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat tail = 14, border = 3, r = 14;
    CGFloat bubbleH = h - tail;

    CGRect bubble = CGRectMake(border/2, border/2, w - border, bubbleH - border/2);

    // Shadow
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, -2), 4,
        [[NSColor colorWithWhite:0 alpha:0.3] CGColor]);

    // White fill
    CGPathRef path = [NSBezierPath bezierPathWithRoundedRect:bubble
                                                     xRadius:r
                                                     yRadius:r].CGPath;
    CGContextAddPath(ctx, path);
    CGContextSetFillColorWithColor(ctx, [NSColor whiteColor].CGColor);
    CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);

    // Border
    CGContextAddPath(ctx, path);
    CGContextSetStrokeColorWithColor(ctx, [NSColor blackColor].CGColor);
    CGContextSetLineWidth(ctx, border);
    CGContextStrokePath(ctx);

    // Tail triangle (pointing down toward bacteria)
    CGFloat tx = w / 2;
    CGFloat ty = bubbleH;
    CGContextMoveToPoint(ctx, tx - 10, ty - 1);
    CGContextAddLineToPoint(ctx, tx + 10, ty - 1);
    CGContextAddLineToPoint(ctx, tx, ty + tail);
    CGContextClosePath(ctx);
    CGContextSetFillColorWithColor(ctx, [NSColor whiteColor].CGColor);
    CGContextFillPath(ctx);
    // Tail outline sides
    CGContextSetStrokeColorWithColor(ctx, [NSColor blackColor].CGColor);
    CGContextSetLineWidth(ctx, border);
    CGContextMoveToPoint(ctx, tx - 10, ty);
    CGContextAddLineToPoint(ctx, tx, ty + tail);
    CGContextAddLineToPoint(ctx, tx + 10, ty);
    CGContextStrokePath(ctx);

    // Text
    NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
    para.alignment = NSTextAlignmentLeft;
    para.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attrs = @{
        NSFontAttributeName:            [NSFont boldSystemFontOfSize:13],
        NSForegroundColorAttributeName: [NSColor blackColor],
        NSParagraphStyleAttributeName:  para,
    };
    CGFloat pad = 14;
    NSRect textRect = NSMakeRect(pad, pad, w - 2*pad, bubbleH - 2*pad);
    [self.text drawInRect:textRect withAttributes:attrs];
}
@end

// ── ChatBubble (factory) ────────────────────────────────────────────────────

@implementation ChatBubble

+ (void)showText:(NSString *)text
       bacteriaX:(CGFloat)bx
       bacteriaY:(CGFloat)by
      spriteSize:(CGFloat)sz {
    // Measure text
    CGFloat maxW = 260, pad = 14, tail = 14, border = 3;
    NSDictionary *attrs = @{
        NSFontAttributeName:           [NSFont boldSystemFontOfSize:13],
        NSParagraphStyleAttributeName: ({
            NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
            p.lineBreakMode = NSLineBreakByWordWrapping;
            p;
        }),
    };
    NSRect textBounds = [text boundingRectWithSize:NSMakeSize(maxW - 2*pad, 9999)
                                          options:NSStringDrawingUsesLineFragmentOrigin
                                       attributes:attrs];
    CGFloat bw = ceil(textBounds.size.width)  + 2*pad + border;
    CGFloat bh = ceil(textBounds.size.height) + 2*pad + border + tail;
    bw = MAX(bw, 80);

    NSScreen *scr   = [NSScreen mainScreen];
    CGFloat   sh    = scr.frame.size.height;
    // bx,by in screen coords (Y down); convert to macOS (Y up)
    CGFloat winX = bx + sz/2 - bw/2;
    CGFloat winY = sh - by + 4;   // 4pt above bacteria top
    winX = MAX(4, MIN(winX, scr.frame.size.width - bw - 4));
    winY = MAX(4, winY);

    NSPanel *panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(winX, winY, bw, bh)
                 styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                   backing:NSBackingStoreBuffered
                     defer:NO];
    panel.backgroundColor = [NSColor clearColor];
    panel.opaque = NO;
    [panel setHasShadow:NO];
    panel.level = NSFloatingWindowLevel;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                               NSWindowCollectionBehaviorIgnoresCycle;
    panel.ignoresMouseEvents = YES;

    BubbleView *view = [[BubbleView alloc] initWithFrame:NSMakeRect(0, 0, bw, bh)];
    view.text = text;
    panel.contentView = view;
    [panel orderFrontRegardless];

    NSInteger words = [[text componentsSeparatedByString:@" "] count];
    NSTimeInterval duration = MAX(4.0, words * 0.35);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [panel orderOut:nil];
    });
}
@end
