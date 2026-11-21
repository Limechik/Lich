#import "PuzzleDashboardViewController.h"
#import "LCClient.h"
#import "LCPuzzleThemes.h"
#import "LCUtil.h"

static const int kDays[] = { 7, 30, 90 };

@interface PuzzleDashboardViewController () {
    UISegmentedControl *_seg;
    NSArray *_overview;      // [ [label, value] ]
    NSArray *_themes;        // [ [name, detail] ]
    NSString *_status;
}
@end

@implementation PuzzleDashboardViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Puzzle dashboard";
        _overview = [NSArray array]; _themes = [NSArray array]; _status = @"Loading…";
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
    _seg = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"7 days", @"30 days", @"90 days", nil]];
    _seg.frame = CGRectMake(20, 10, 280, 32);
    _seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _seg.selectedSegmentIndex = 1;
    [_seg addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    [header addSubview:_seg];
    self.tableView.tableHeaderView = header;
    [self load];
}

- (void)load {
    _status = @"Loading…"; _overview = [NSArray array]; _themes = [NSArray array];
    [self.tableView reloadData];
    int days = kDays[_seg.selectedSegmentIndex];
    [[LCClient shared] fetchPuzzleDashboardDays:days done:^(id json, NSString *err) {
        if (err) {
            BOOL scope = [err rangeOfString:@"authorized"].location != NSNotFound || [err rangeOfString:@"403"].location != NSNotFound;
            _status = scope ? @"Your token needs the puzzle:read scope. Create a new token (see the login screen)." : err;
            [self.tableView reloadData];
            return;
        }
        id g = LCGet(json, @"global");
        int nb = [LCGet(g, @"nb") intValue], first = [LCGet(g, @"firstWins") intValue], replay = [LCGet(g, @"replayWins") intValue];
        _overview = [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:@"Puzzles played", [NSString stringWithFormat:@"%d", nb], nil],
            [NSArray arrayWithObjects:@"Solved first try", nb ? [NSString stringWithFormat:@"%d%%", first * 100 / nb] : @"–", nil],
            [NSArray arrayWithObjects:@"Solved on replay", [NSString stringWithFormat:@"%d", replay], nil],
            [NSArray arrayWithObjects:@"Performance", [NSString stringWithFormat:@"%d", [LCGet(g, @"performance") intValue]], nil],
            [NSArray arrayWithObjects:@"Average puzzle rating", [NSString stringWithFormat:@"%d", [LCGet(g, @"puzzleRatingAvg") intValue]], nil], nil];

        NSMutableArray *rows = [NSMutableArray array];
        id themes = LCGet(json, @"themes");
        if ([themes isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in themes) {
                id e = [themes objectForKey:key], r = LCGet(e, @"results");
                int tn = [LCGet(r, @"nb") intValue], tf = [LCGet(r, @"firstWins") intValue];
                if (tn <= 0) continue;
                NSString *k = LCStr(e, @"theme") ?: key;
                [rows addObject:[NSArray arrayWithObjects:LCPuzzleThemeName(k), [NSNumber numberWithInt:tn],
                    [NSString stringWithFormat:@"%d played · %d%% first try · perf %d", tn, tf * 100 / tn, [LCGet(r, @"performance") intValue]], nil]];
            }
        }
        [rows sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
            return [[b objectAtIndex:1] intValue] > [[a objectAtIndex:1] intValue] ? NSOrderedDescending : NSOrderedAscending;
        }];
        if (rows.count > 30) [rows removeObjectsInRange:NSMakeRange(30, rows.count - 30)];
        _themes = rows;
        _status = (nb == 0) ? @"No puzzles played in this period" : nil;
        [self.tableView reloadData];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return _overview.count ? (NSInteger)_overview.count : 1;
    return _themes.count;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return @"Overview";
    return _themes.count ? @"Most played themes" : nil;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return (s == 0 && _overview.count && _status) ? _status : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (!_overview.count) { cell.textLabel.text = _status ?: @""; cell.textLabel.textColor = [UIColor grayColor]; cell.textLabel.numberOfLines = 3; return cell; }
        NSArray *r = [_overview objectAtIndex:ip.row];
        cell.textLabel.text = [r objectAtIndex:0]; cell.detailTextLabel.text = [r objectAtIndex:1];
        return cell;
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSArray *r = [_themes objectAtIndex:ip.row];
    cell.textLabel.text = [r objectAtIndex:0]; cell.detailTextLabel.text = [r objectAtIndex:2];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return (ip.section == 0 && !_overview.count) ? 70 : 50;
}

@end
