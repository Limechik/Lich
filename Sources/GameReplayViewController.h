#import <UIKit/UIKit.h>

// Step through a finished game (a game object from /api/games/user with SAN "moves").
@interface GameReplayViewController : UIViewController
- (id)initWithGame:(NSDictionary *)game;
@end
