#import <Cocoa/Cocoa.h>

typedef void (^InputCallback)(NSString *text);

@interface InputPanel : NSObject
+ (instancetype)shared;
- (void)showAtBacteriaX:(CGFloat)bx bacteriaY:(CGFloat)by
               callback:(InputCallback)cb;
@end
