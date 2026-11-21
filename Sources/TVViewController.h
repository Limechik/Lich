#import <UIKit/UIKit.h>
// Live Lichess TV game: GET /api/tv/{channel}/feed
@interface TVViewController : UIViewController
- (id)initWithChannel:(NSString *)channel title:(NSString *)title;
@end
