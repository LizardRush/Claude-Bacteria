#import <Cocoa/Cocoa.h>

@interface ChatBubble : NSObject
+ (void)showText:(NSString *)text
       bacteriaX:(CGFloat)bx
       bacteriaY:(CGFloat)by
      spriteSize:(CGFloat)sz;
@end
