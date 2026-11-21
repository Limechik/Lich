#import "PuzzleThemesViewController.h"
#import "LCUtil.h"
#import "LCPuzzleThemes.h"
#import "PuzzleViewController.h"

@implementation PuzzleThemesViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Puzzle themes";
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return LCPuzzleThemeGroups().count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[[LCPuzzleThemeGroups() objectAtIndex:s] objectAtIndex:1] count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return [[LCPuzzleThemeGroups() objectAtIndex:s] objectAtIndex:0]; }

- (NSArray *)themeAt:(NSIndexPath *)ip { return [[[LCPuzzleThemeGroups() objectAtIndex:ip.section] objectAtIndex:1] objectAtIndex:ip.row]; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    NSArray *t = [self themeAt:ip];
    cell.textLabel.text = [t objectAtIndex:1];
    cell.detailTextLabel.text = [t objectAtIndex:2];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSArray *t = [self themeAt:ip];
    PuzzleViewController *vc = [[PuzzleViewController alloc] initWithMode:PuzzleModeTheme angle:[t objectAtIndex:0] puzzleId:nil title:[t objectAtIndex:1]];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
