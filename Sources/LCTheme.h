#import <UIKit/UIKit.h>

// App-wide look: burlywood navigation bars (#DEB887) and a wood background behind the table screens.
@interface LCTheme : NSObject
+ (UIColor *)barColor;                       // #DEB887
+ (void)installNavigationBarAppearance;     // call once at launch, before creating navigation controllers
+ (UIImage *)woodImage;
+ (UIColor *)woodFallbackColor;              // dark brown, shown if the picture can't be loaded
@end
