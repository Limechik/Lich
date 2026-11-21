#import <UIKit/UIKit.h>
#import <stdlib.h>
#import <time.h>
#import "AppDelegate.h"

int main(int argc, char *argv[]) {
    srand((unsigned)time(NULL));
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
