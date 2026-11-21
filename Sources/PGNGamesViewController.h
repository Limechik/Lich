#import <UIKit/UIKit.h>
#import "LCWoodTableViewController.h"

// List of the games found in an imported PGN.
@interface PGNGamesViewController : LCWoodTableViewController
- (id)initWithGames:(NSArray *)games;
@end
