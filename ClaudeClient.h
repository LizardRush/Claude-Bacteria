#import <Foundation/Foundation.h>

typedef void (^ChunkBlock)(NSString *chunk);
typedef void (^CompleteBlock)(NSString *full);
typedef void (^ErrorBlock)(NSString *err);

@interface ClaudeClient : NSObject
- (void)sendMessage:(NSString *)text
            onChunk:(ChunkBlock)onChunk
         onComplete:(CompleteBlock)onComplete
            onError:(ErrorBlock)onError;
@end
