#import "LCWoodTableViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "LCTheme.h"

@implementation LCWoodTableViewController {
    UIImageView *_wood;
}

// The wood is an image view placed behind every row and re-pinned to the visible area on each scroll,
// so it stays still while the content moves. (More dependable than UITableView.backgroundView.)
- (void)viewDidLoad {
    [super viewDidLoad];
    UITableView *tv = self.tableView;
    tv.backgroundView = nil;
    tv.backgroundColor = [LCTheme woodFallbackColor];          // brown instead of black, even if the picture is missing
    UIImage *wood = [LCTheme woodImage];
    if (wood) {
        // Clear, not brown: grouped cells paint their side margins with the table's colour, which showed as
        // flat bands across the wood (very visible on iPad, where the margins are wide).
        tv.backgroundColor = [UIColor clearColor];
        _wood = [[UIImageView alloc] initWithImage:wood];
        _wood.contentMode = UIViewContentModeScaleAspectFill;
        _wood.clipsToBounds = YES;
        _wood.userInteractionEnabled = NO;
        _wood.layer.zPosition = -1000;                         // always drawn behind the rows, however UITableView reorders its subviews
        [tv insertSubview:_wood atIndex:0];
        [self pinWood];
    }
}

- (void)pinWood {
    if (!_wood) return;
    _wood.frame = self.tableView.bounds;
    [self.tableView sendSubviewToBack:_wood];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self pinWood]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self pinWood]; }
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { [self pinWood]; }

- (CGFloat)sideInset:(UITableView *)tv { return tv.bounds.size.width > 500 ? 54 : 20; }

- (NSString *)headerTextFor:(UITableView *)tv section:(NSInteger)s {
    return [self respondsToSelector:@selector(tableView:titleForHeaderInSection:)] ? [self tableView:tv titleForHeaderInSection:s] : nil;
}

- (NSString *)footerTextFor:(UITableView *)tv section:(NSInteger)s {
    return [self respondsToSelector:@selector(tableView:titleForFooterInSection:)] ? [self tableView:tv titleForFooterInSection:s] : nil;
}

- (UILabel *)labelWithFont:(UIFont *)font alignment:(UITextAlignment)align {
    UILabel *l = [[UILabel alloc] init];
    l.backgroundColor = [UIColor clearColor];
    l.font = font; l.textAlignment = align; l.numberOfLines = 0;
    l.textColor = [UIColor colorWithWhite:0.96 alpha:1];
    l.shadowColor = [UIColor colorWithWhite:0 alpha:0.75]; l.shadowOffset = CGSizeMake(0, -1);
    return l;
}

#pragma mark - Headers / footers (grouped tables only; plain tables keep the system look)

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    if (tv.style != UITableViewStyleGrouped) return nil;
    NSString *t = [self headerTextFor:tv section:s];
    if (!t.length) return nil;
    CGFloat inset = [self sideInset:tv];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.bounds.size.width, 34)];
    UILabel *l = [self labelWithFont:[UIFont boldSystemFontOfSize:17] alignment:UITextAlignmentLeft];
    l.frame = CGRectMake(inset, 8, tv.bounds.size.width - 2 * inset, 24);
    l.numberOfLines = 1;
    l.text = t;
    [v addSubview:l];
    return v;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
    if (tv.style != UITableViewStyleGrouped) return tv.sectionHeaderHeight;
    return [self headerTextFor:tv section:s].length ? 34 : 6;
}

- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s {
    if (tv.style != UITableViewStyleGrouped) return nil;
    NSString *t = [self footerTextFor:tv section:s];
    if (!t.length) return nil;
    CGFloat inset = [self sideInset:tv], w = tv.bounds.size.width - 2 * inset;
    UIFont *font = [UIFont systemFontOfSize:13];
    CGFloat h = ceil([t sizeWithFont:font constrainedToSize:CGSizeMake(w, 1000) lineBreakMode:UILineBreakModeWordWrap].height);
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.bounds.size.width, h + 18)];
    UILabel *l = [self labelWithFont:font alignment:UITextAlignmentCenter];
    l.frame = CGRectMake(inset, 6, w, h);
    l.text = t;
    [v addSubview:l];
    return v;
}

- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s {
    if (tv.style != UITableViewStyleGrouped) return tv.sectionFooterHeight;
    NSString *t = [self footerTextFor:tv section:s];
    if (!t.length) return 6;
    CGFloat w = tv.bounds.size.width - 2 * [self sideInset:tv];
    return ceil([t sizeWithFont:[UIFont systemFontOfSize:13] constrainedToSize:CGSizeMake(w, 1000) lineBreakMode:UILineBreakModeWordWrap].height) + 18;
}

@end
