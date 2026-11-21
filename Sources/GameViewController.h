#import <UIKit/UIKit.h>

@interface GameViewController : UIViewController
- (id)initWithGameId:(NSString *)gameId colorHint:(NSString *)colorHint;   // colorHint: "white"/"black"/nil
@end
