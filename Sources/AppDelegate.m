#import "AppDelegate.h"
#import "LCClient.h"
#import "LCIcons.h"
#import "LCTheme.h"
#import "LoginViewController.h"
#import "HomeViewController.h"
#import "PuzzlesHomeViewController.h"
#import "LearnViewController.h"
#import "WatchViewController.h"
#import "MoreViewController.h"
#import "PGNImportViewController.h"

@implementation AppDelegate

- (UIViewController *)tab:(UIViewController *)vc title:(NSString *)title icon:(int)icon {
    UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:vc];
    n.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:LCTabIcon(icon) tag:icon];
    return n;
}

- (UITabBarController *)makeTabs {
    UITabBarController *tb = [[UITabBarController alloc] init];
    tb.viewControllers = [NSArray arrayWithObjects:
        [self tab:[[HomeViewController alloc] init] title:@"Home" icon:0],
        [self tab:[[PuzzlesHomeViewController alloc] init] title:@"Puzzles" icon:1],
        [self tab:[[LearnViewController alloc] init] title:@"Learn" icon:2],
        [self tab:[[WatchViewController alloc] init] title:@"Watch" icon:3],
        [self tab:[[MoreViewController alloc] init] title:@"More" icon:4],
        nil];
    return tb;
}

- (UIViewController *)makeLogin {
    UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:[[LoginViewController alloc] init]];
    return n;
}

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [LCTheme installNavigationBarAppearance];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = ([[LCClient shared].token length] || [LCClient shared].guest) ? (UIViewController *)[self makeTabs] : [self makeLogin];
    [self.window makeKeyAndVisible];
    return YES;
}

// "Open in..." of a .pgn file: show it in More -> Import PGN.
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation {
    if (![url isFileURL]) return NO;
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!text && data) text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text.length) return NO;
    UIViewController *root = self.window.rootViewController;
    if (![root isKindOfClass:[UITabBarController class]]) return NO;                  // login screen is showing
    UITabBarController *tabs = (UITabBarController *)root;
    tabs.selectedIndex = 4;                                                          // More
    UINavigationController *nav = (UINavigationController *)tabs.selectedViewController;
    [nav popToRootViewControllerAnimated:NO];
    [nav pushViewController:[[PGNImportViewController alloc] initWithText:text] animated:NO];
    return YES;
}

- (void)showLogin { self.window.rootViewController = [self makeLogin]; }
- (void)showHome { self.window.rootViewController = [self makeTabs]; }

@end
