#import "LCTheme.h"

@implementation LCTheme

+ (UIColor *)barColor { return [UIColor colorWithRed:222 / 255.0 green:184 / 255.0 blue:135 / 255.0 alpha:1]; }   // #DEB887

// Solid #DEB887 with a thin darker line along the bottom edge.
+ (UIImage *)barBackground {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 44), YES, 0);
    CGContextRef g = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(g, [self barColor].CGColor);
    CGContextFillRect(g, CGRectMake(0, 0, 4, 44));
    CGContextSetFillColorWithColor(g, [UIColor colorWithRed:0.62 green:0.48 blue:0.30 alpha:1].CGColor);
    CGContextFillRect(g, CGRectMake(0, 43, 4, 1));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsZero];
}

+ (void)installNavigationBarAppearance {
    UINavigationBar *bar = [UINavigationBar appearance];
    [bar setBackgroundImage:[self barBackground] forBarMetrics:UIBarMetricsDefault];
    [bar setTintColor:[UIColor colorWithRed:0.55 green:0.37 blue:0.20 alpha:1]];          // bar buttons and the back button
    [bar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
        [UIColor colorWithRed:0.23 green:0.16 blue:0.08 alpha:1], UITextAttributeTextColor,
        [UIColor colorWithWhite:1 alpha:0.45], UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(0, 1)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:20], UITextAttributeFont, nil]];
}

+ (UIImage *)woodImage {
    static UIImage *img;
    if (!img) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"wood_background" ofType:@"jpg"];
        if (path) img = [UIImage imageWithContentsOfFile:path];
        if (!img) img = [UIImage imageNamed:@"wood_background.jpg"];
    }
    return img;
}

+ (UIColor *)woodFallbackColor { return [UIColor colorWithRed:0.27 green:0.22 blue:0.18 alpha:1]; }

@end
