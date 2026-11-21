#import <UIKit/UIKit.h>
#import "LCWoodTableViewController.h"

// Single-choice list with a thumbnail per row (board themes, piece sets, shape colours).
@interface StylePickerViewController : LCWoodTableViewController
@property (nonatomic, copy) NSArray *items;            // [ {id, title, image} ]
@property (nonatomic, copy) NSString *selectedId;
@property (nonatomic, copy) void (^onSelect)(NSString *itemId);
@end
