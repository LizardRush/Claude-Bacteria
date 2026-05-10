#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>

@interface SpriteSheet : NSObject
@property (readonly) NSInteger count;
- (instancetype)initWithPath:(NSString *)path;
- (CGImageRef)frameAtIndex:(NSInteger)idx;
@end
