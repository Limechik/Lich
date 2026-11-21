#import "LCSegmentCell.h"

@implementation LCSegmentCell
@synthesize segmentedControl = _segmentedControl;

- (void)setSegmentedControl:(UISegmentedControl *)sc {
    [_segmentedControl removeFromSuperview];
    _segmentedControl = sc;
    if (sc) [self.contentView addSubview:sc];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    CGFloat h = 32;
    _segmentedControl.frame = CGRectMake(8, floor((b.size.height - h) / 2), MAX(0, b.size.width - 16), h);
}
@end
