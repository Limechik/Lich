#import "WatchViewController.h"
#import "LCUtil.h"
#import "TVViewController.h"

@implementation WatchViewController {
    NSArray *_channels;    // { title, subtitle, channel id }
}

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Watch";
        _channels = [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:@"Top Rated", @"The best players right now", @"best", nil],
            [NSArray arrayWithObjects:@"Bullet", @"Fast games", @"bullet", nil],
            [NSArray arrayWithObjects:@"Blitz", @"3–5 minute games", @"blitz", nil],
            [NSArray arrayWithObjects:@"Rapid", @"10–15 minute games", @"rapid", nil],
            [NSArray arrayWithObjects:@"Classical", @"Long games", @"classical", nil],
            [NSArray arrayWithObjects:@"UltraBullet", @"Even faster", @"ultraBullet", nil],
            [NSArray arrayWithObjects:@"Bots", @"Engines playing each other", @"bot", nil],
            [NSArray arrayWithObjects:@"Computer", @"Top rated vs Stockfish", @"computer", nil],
            nil];
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 1; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _channels.count; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @"Lichess TV"; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    NSArray *ch = [_channels objectAtIndex:ip.row];
    cell.textLabel.text = [ch objectAtIndex:0];
    cell.detailTextLabel.text = [ch objectAtIndex:1];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSArray *ch = [_channels objectAtIndex:ip.row];
    [self.navigationController pushViewController:[[TVViewController alloc] initWithChannel:[ch objectAtIndex:2] title:[ch objectAtIndex:0]] animated:YES];
}

@end
