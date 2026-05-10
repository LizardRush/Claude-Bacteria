#import "SpriteSheet.h"

@implementation SpriteSheet {
    CGImageRef *_frames;
    NSInteger   _count;
}

- (instancetype)initWithPath:(NSString *)path {
    if (!(self = [super init])) return nil;
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
    if (!src) { NSLog(@"[sprite] failed to load %@", path); return nil; }

    _count  = (NSInteger)CGImageSourceGetCount(src);
    _frames = malloc((size_t)_count * sizeof(CGImageRef));
    for (NSInteger i = 0; i < _count; i++)
        _frames[i] = CGImageSourceCreateImageAtIndex(src, (size_t)i, nil);
    CFRelease(src);
    return self;
}

- (CGImageRef)frameAtIndex:(NSInteger)idx {
    if (_count == 0) return NULL;
    return _frames[idx % _count];
}

- (NSInteger)count { return _count; }

- (void)dealloc {
    for (NSInteger i = 0; i < _count; i++) CGImageRelease(_frames[i]);
    free(_frames);
}
@end
