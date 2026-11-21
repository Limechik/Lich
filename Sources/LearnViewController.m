#import "LearnViewController.h"
#import "LCUtil.h"

// Lichess' interactive lessons are web apps, so this tab links to them in Safari.
@implementation LearnViewController {
    NSArray *_sections;   // { header, [ {title, subtitle, path} ... ] }
}

static NSArray *Item(NSString *t, NSString *s, NSString *p) { return [NSArray arrayWithObjects:t, s, p, nil]; }

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Learn";
        _sections = [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:@"Basics", [NSArray arrayWithObjects:
                Item(@"Chess basics", @"Interactive lessons from the very start", @"/learn"),
                Item(@"Practice", @"Checkmates, tactics and endgames", @"/practice"),
                Item(@"Coordinates", @"Learn to read the board", @"/training/coordinate"), nil], nil],
            [NSArray arrayWithObjects:@"Improve", [NSArray arrayWithObjects:
                Item(@"Tactics by theme", @"Train specific patterns", @"/training/themes"),
                Item(@"Opening explorer", @"Study openings from real games", @"/opening"),
                Item(@"Studies", @"Shared analysis and lessons", @"/study"),
                Item(@"Video library", @"Lessons from titled players", @"/video"), nil], nil],
            nil];
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[[_sections objectAtIndex:s] objectAtIndex:1] count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return [[_sections objectAtIndex:s] objectAtIndex:0]; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    NSArray *it = [[[_sections objectAtIndex:ip.section] objectAtIndex:1] objectAtIndex:ip.row];
    cell.textLabel.text = [it objectAtIndex:0];
    cell.detailTextLabel.text = [it objectAtIndex:1];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == (NSInteger)_sections.count - 1 ? @"Lessons open on lichess.org in Safari." : nil;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSArray *it = [[[_sections objectAtIndex:ip.section] objectAtIndex:1] objectAtIndex:ip.row];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://lichess.org" stringByAppendingString:[it objectAtIndex:2]]]];
}

@end
