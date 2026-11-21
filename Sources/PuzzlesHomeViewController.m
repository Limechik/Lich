#import "PuzzlesHomeViewController.h"
#import "LCUtil.h"
#import "LCClient.h"
#import "PuzzleViewController.h"
#import "PuzzleThemesViewController.h"
#import "PuzzleDashboardViewController.h"
#import "PuzzleHistoryViewController.h"

enum { RowDaily, RowThemes, RowStreak, RowStorm, RowDashboard, RowHistory };

@implementation PuzzlesHomeViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Puzzles";
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

- (BOOL)isGuest { return ![[LCClient shared].token length]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 1 : 5; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s != 1) return nil;
    return [self isGuest] ? @"Dashboard and history need an account (token with the puzzle:read scope). Streak and Storm run on this device; their scores are not sent to Lichess."
                          : @"Dashboard and history need a token with the puzzle:read scope. Streak and Storm run on this device; their scores are not sent to Lichess.";
}

- (int)rowIdAt:(NSIndexPath *)ip { return ip.section == 0 ? RowDaily : RowThemes + (int)ip.row; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    switch ([self rowIdAt:ip]) {
        case RowDaily: cell.textLabel.text = @"Daily puzzle"; cell.detailTextLabel.text = @"Today's puzzle for everyone"; break;
        case RowThemes: cell.textLabel.text = @"Puzzle themes"; cell.detailTextLabel.text = @"Train a specific pattern"; break;
        case RowStreak:
            cell.textLabel.text = @"Puzzle Streak";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Solve until your first mistake • best %d", (int)[d integerForKey:@"lc.streak.best"]];
            break;
        case RowStorm:
            cell.textLabel.text = @"Puzzle Storm";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"As many as you can in 3 minutes • best %d", (int)[d integerForKey:@"lc.storm.best"]];
            break;
        case RowDashboard: cell.textLabel.text = @"Puzzle dashboard"; cell.detailTextLabel.text = [self isGuest] ? @"Log in to see your stats" : @"Your results by theme"; break;
        default: cell.textLabel.text = @"Puzzle history"; cell.detailTextLabel.text = [self isGuest] ? @"Log in to see your puzzles" : @"Puzzles you have played"; break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    UIViewController *vc = nil;
    switch ([self rowIdAt:ip]) {
        case RowDaily: vc = [[PuzzleViewController alloc] initWithMode:PuzzleModeDaily angle:nil puzzleId:nil title:nil]; break;
        case RowThemes: vc = [[PuzzleThemesViewController alloc] init]; break;
        case RowStreak: vc = [[PuzzleViewController alloc] initWithMode:PuzzleModeStreak angle:nil puzzleId:nil title:nil]; break;
        case RowStorm: vc = [[PuzzleViewController alloc] initWithMode:PuzzleModeStorm angle:nil puzzleId:nil title:nil]; break;
        case RowDashboard:
        case RowHistory:
            if ([self isGuest]) {
                [[[UIAlertView alloc] initWithTitle:@"Account needed" message:@"Log in with a token that has the puzzle:read scope (More → Log in)."
                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                return;
            }
            vc = [self rowIdAt:ip] == RowDashboard ? (UIViewController *)[[PuzzleDashboardViewController alloc] init]
                                                   : (UIViewController *)[[PuzzleHistoryViewController alloc] init];
            break;
    }
    if (vc) [self.navigationController pushViewController:vc animated:YES];
}

@end
