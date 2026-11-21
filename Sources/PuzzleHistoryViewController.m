#import "PuzzleHistoryViewController.h"
#import "LCClient.h"
#import "LCPuzzleThemes.h"
#import "LCUtil.h"
#import "PuzzleViewController.h"

static NSString *Ago(double seconds) {
    if (seconds < 60) return @"just now";
    if (seconds < 3600) return [NSString stringWithFormat:@"%d min ago", (int)(seconds / 60)];
    if (seconds < 86400) return [NSString stringWithFormat:@"%d h ago", (int)(seconds / 3600)];
    return [NSString stringWithFormat:@"%d d ago", (int)(seconds / 86400)];
}

@implementation PuzzleHistoryViewController {
    NSArray *_rows;
    NSString *_status;
}

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Puzzle history";
        _rows = [NSArray array]; _status = @"Loading…";
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewDidLoad {
    [super viewDidLoad];
    [[LCClient shared] fetchPuzzleActivity:50 done:^(id json, NSString *err) {
        if (err) { _status = err; }
        else { _rows = json; _status = _rows.count ? nil : @"No puzzles played yet"; }
        [self.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _rows.count ? (NSInteger)_rows.count : 1; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (!_rows.count) {
        cell.textLabel.text = _status ?: @""; cell.textLabel.textColor = [UIColor grayColor]; cell.textLabel.numberOfLines = 3;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    id r = [_rows objectAtIndex:ip.row], pz = LCGet(r, @"puzzle");
    BOOL win = [LCGet(r, @"win") boolValue];
    id rating = LCGet(pz, @"rating");
    cell.textLabel.text = [NSString stringWithFormat:@"Puzzle %@ · rating %@", LCStr(pz, @"id") ?: @"?", [rating isKindOfClass:[NSNumber class]] ? rating : @"?"];
    NSMutableArray *names = [NSMutableArray array];
    id themes = LCGet(pz, @"themes");
    if ([themes isKindOfClass:[NSArray class]]) for (id k in themes) if ([k isKindOfClass:[NSString class]] && names.count < 3) [names addObject:LCPuzzleThemeName(k)];
    double date = [LCGet(r, @"date") doubleValue] / 1000.0;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@%@", win ? @"Solved" : @"Failed", names.count ? [[names componentsJoinedByString:@", "] stringByAppendingString:@" · "] : @"",
                                 date > 0 ? Ago([[NSDate date] timeIntervalSince1970] - date) : @""];
    cell.detailTextLabel.textColor = win ? [UIColor colorWithRed:0.2 green:0.5 blue:0.15 alpha:1] : [UIColor colorWithRed:0.75 green:0.2 blue:0.15 alpha:1];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (!_rows.count) return;
    NSString *pid = LCStr(LCGet([_rows objectAtIndex:ip.row], @"puzzle"), @"id");
    if (!pid) return;
    PuzzleViewController *vc = [[PuzzleViewController alloc] initWithMode:PuzzleModeById angle:nil puzzleId:pid title:[@"Puzzle " stringByAppendingString:pid]];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
