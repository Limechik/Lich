#import <UIKit/UIKit.h>

// Offline game: against the built-in engine, or two players on one device.
// cfg keys: opponent ("engine"|"otb"), clock (BOOL), minutes (double), increment (int s), color ("random"|"white"|"black"), level (1-8)
@interface LocalGameViewController : UIViewController
- (id)initWithConfig:(NSDictionary *)cfg;
- (id)initWithSavedGame:(NSDictionary *)saved;
+ (NSDictionary *)savedGame;      // unfinished game, or nil
+ (void)clearSavedGame;
@end
