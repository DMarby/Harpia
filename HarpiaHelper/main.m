#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[]) {
    NSString *appPath = [[[[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];

    [[NSWorkspace sharedWorkspace] launchApplication:appPath];
    return 0;
}