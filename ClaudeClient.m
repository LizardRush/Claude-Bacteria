#import "ClaudeClient.h"

@interface ClaudeClient () <NSURLSessionDataDelegate>
@end

@implementation ClaudeClient {
    NSURLSession   *_session;
    NSMutableData  *_buf;
    NSMutableString *_accumulated;
    ChunkBlock      _onChunk;
    CompleteBlock   _onComplete;
    ErrorBlock      _onError;
    BOOL            _completed;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    return self;
}

- (void)sendMessage:(NSString *)text
            onChunk:(ChunkBlock)onChunk
         onComplete:(CompleteBlock)onComplete
            onError:(ErrorBlock)onError {
    _onChunk    = [onChunk copy];
    _onComplete = [onComplete copy];
    _onError    = [onError copy];
    _buf        = [NSMutableData data];
    _accumulated = [NSMutableString string];
    _completed  = NO;

    NSString *apiKey = [NSProcessInfo.processInfo.environment
                        objectForKey:@"ANTHROPIC_API_KEY"] ?: @"";

    NSURL *url = [NSURL URLWithString:@"https://api.anthropic.com/v1/messages"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json"              forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"2023-06-01"                    forHTTPHeaderField:@"anthropic-version"];
    [req setValue:apiKey                           forHTTPHeaderField:@"x-api-key"];

    NSDictionary *body = @{
        @"model":      @"claude-haiku-4-5-20251001",
        @"max_tokens": @256,
        @"stream":     @YES,
        @"system":     @"You are a tiny bacteria creature on the user's screen. "
                        @"Be playful. Reply in 1-3 short sentences max.",
        @"messages":   @[@{@"role": @"user", @"content": text}]
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[_session dataTaskWithRequest:req] resume];
}

// ── NSURLSessionDataDelegate ──────────────────────────────────────────────

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)task
    didReceiveData:(NSData *)data {
    [_buf appendData:data];
    [self flushBuffer];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error) {
        if (_onError) dispatch_async(dispatch_get_main_queue(), ^{
            self->_onError(error.localizedDescription);
        });
    } else if (!_completed && _onError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_onError(@"No response (check API key)");
        });
    }
}

- (void)flushBuffer {
    NSString *str = [[NSString alloc] initWithData:_buf encoding:NSUTF8StringEncoding];
    if (!str) return;

    NSArray<NSString *> *lines = [str componentsSeparatedByString:@"\n"];
    BOOL hasIncomplete = NO;

    for (NSString *line in lines) {
        if (![line hasPrefix:@"data: "]) continue;
        NSString *payload = [line substringFromIndex:6];
        if ([payload isEqualToString:@"[DONE]"]) continue;

        NSData *jd = [payload dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:jd
                                                           options:0 error:nil];
        if (!obj) { hasIncomplete = YES; continue; }

        NSString *type = obj[@"type"];
        if ([type isEqualToString:@"content_block_delta"]) {
            NSString *text = obj[@"delta"][@"text"];
            if (text) {
                [_accumulated appendString:text];
                if (_onChunk) {
                    NSString *copy = [text copy];
                    dispatch_async(dispatch_get_main_queue(), ^{ self->_onChunk(copy); });
                }
            }
        } else if ([type isEqualToString:@"message_stop"]) {
            _completed = YES;
            NSString *full = [_accumulated copy];
            if (_onComplete) {
                dispatch_async(dispatch_get_main_queue(), ^{ self->_onComplete(full); });
            }
        }
    }
    if (!hasIncomplete) _buf = [NSMutableData data];
}
@end
