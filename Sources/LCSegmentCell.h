#import <UIKit/UIKit.h>

// A table cell that holds one UISegmentedControl and keeps it exactly as wide as the cell's content area.
// (Sizing the control from the table width broke on iPad, where grouped tables have wide side margins.)
@interface LCSegmentCell : UITableViewCell
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@end
