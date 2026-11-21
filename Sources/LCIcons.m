#import "LCIcons.h"

UIImage *LCTabIcon(int kind) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0);
    CGContextRef g = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(g, [UIColor blackColor].CGColor);
    switch (kind) {
        case 0: {   // house
            CGContextMoveToPoint(g, 15, 4); CGContextAddLineToPoint(g, 28, 15); CGContextAddLineToPoint(g, 2, 15);
            CGContextClosePath(g); CGContextFillPath(g);
            CGContextFillRect(g, CGRectMake(6, 15, 18, 11));
            CGContextSetBlendMode(g, kCGBlendModeClear);
            CGContextFillRect(g, CGRectMake(12, 19, 6, 7));
            break;
        }
        case 1: {   // puzzle piece
            CGContextFillRect(g, CGRectMake(5, 9, 17, 17));
            CGContextFillEllipseInRect(g, CGRectMake(9, 3, 9, 9));
            CGContextFillEllipseInRect(g, CGRectMake(19, 13, 9, 9));
            break;
        }
        case 2: {   // open book
            CGContextMoveToPoint(g, 2, 7); CGContextAddLineToPoint(g, 14, 10); CGContextAddLineToPoint(g, 14, 26); CGContextAddLineToPoint(g, 2, 23);
            CGContextClosePath(g); CGContextFillPath(g);
            CGContextMoveToPoint(g, 28, 7); CGContextAddLineToPoint(g, 16, 10); CGContextAddLineToPoint(g, 16, 26); CGContextAddLineToPoint(g, 28, 23);
            CGContextClosePath(g); CGContextFillPath(g);
            break;
        }
        case 3: {   // tv with play triangle
            CGContextFillRect(g, CGRectMake(2, 5, 26, 18));
            CGContextFillRect(g, CGRectMake(9, 25, 12, 3));
            CGContextSetBlendMode(g, kCGBlendModeClear);
            CGContextMoveToPoint(g, 12, 9); CGContextAddLineToPoint(g, 12, 19); CGContextAddLineToPoint(g, 20, 14);
            CGContextClosePath(g); CGContextFillPath(g);
            break;
        }
        default: {  // three dots
            for (int i = 0; i < 3; i++) CGContextFillEllipseInRect(g, CGRectMake(3 + i * 9, 12, 6, 6));
            break;
        }
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
