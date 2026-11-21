#import <UIKit/UIKit.h>
#import "LCWoodTableViewController.h"

typedef void (^LCConfigBlock)(NSDictionary *cfg);

// Custom game builder. cfg keys: opponent (online|ai|engine|otb), clock, minutes, increment, rated, color, level.
@interface CustomGameViewController : LCWoodTableViewController
@property (nonatomic, copy) LCConfigBlock onStart;
- (id)initAsGuest:(BOOL)guest;
@end
