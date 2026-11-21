#import <UIKit/UIKit.h>
#import "LCWoodTableViewController.h"

// Time control of the chess clock (same time for both players + increment). Saved on the device.
@interface ClockSettingsViewController : LCWoodTableViewController
@property (nonatomic, copy) void (^onChange)(void);
+ (double)savedMinutes;
+ (int)savedIncrement;
@end
