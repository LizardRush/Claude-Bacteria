#import "AppDelegate.h"
#import "BacteriaApp.h"

@implementation AppDelegate {
    BacteriaApp *_app;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    _app = [BacteriaApp new];
    [_app start];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return NO;
}
@end
