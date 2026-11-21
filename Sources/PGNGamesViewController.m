#import "PGNGamesViewController.h"
#import "GameReplayViewController.h"
#import "LCPGNImporter.h"
#import "LCUtil.h"

@implementation PGNGamesViewController {
    NSArray *_games;
}

- (id)initWithGames:(NSArray *)games {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _games = [games copy];
        self.title = [NSString stringWithFormat:@"%lu games", (unsigned long)games.count];
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _games.count; }

- (NSString *)nameOf:(id)player { return LCStr(LCGet(player, @"user"), @"name") ?: @"?"; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    NSDictionary *g = [_games objectAtIndex:ip.row];
    id players = LCGet(g, @"players");
    cell.textLabel.text = [NSString stringWithFormat:@"%@ vs %@", [self nameOf:LCGet(players, @"white")], [self nameOf:LCGet(players, @"black")]];
    NSMutableArray *bits = [NSMutableArray array];
    NSString *r = LCStr(g, @"result");
    if (r.length) [bits addObject:r];
    if (LCStr(g, @"event").length) [bits addObject:LCStr(g, @"event")];
    if (LCStr(g, @"date").length) [bits addObject:LCStr(g, @"date")];
    [bits addObject:[NSString stringWithFormat:@"%d moves", ([LCGet(g, @"plies") intValue] + 1) / 2]];
    if (![LCPGNImporter isPlayable:g]) [bits addObject:@"variant"];
    cell.detailTextLabel.text = [bits componentsJoinedByString:@" · "];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *g = [_games objectAtIndex:ip.row];
    if (![LCPGNImporter isPlayable:g]) {
        [[[UIAlertView alloc] initWithTitle:@"Variant not supported" message:@"Only standard chess games can be replayed here." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    if ([LCGet(g, @"plies") intValue] == 0) {
        [[[UIAlertView alloc] initWithTitle:@"No moves" message:LCStr(g, @"error") ?: @"This game has no readable moves." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    [self.navigationController pushViewController:[[GameReplayViewController alloc] initWithGame:g] animated:YES];
}

@end
