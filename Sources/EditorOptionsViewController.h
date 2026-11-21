#import <UIKit/UIKit.h>
#import "LCWoodTableViewController.h"
#import "LCChess.h"

// Side to move, castling rights and en passant of the position being edited.
@interface EditorOptionsViewController : LCWoodTableViewController
@property (nonatomic, copy) void (^onChange)(LCPosition pos);
- (id)initWithPosition:(LCPosition)pos;
@end
