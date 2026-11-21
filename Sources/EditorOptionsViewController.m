#import "EditorOptionsViewController.h"
#import "LCSegmentCell.h"
#import "LCUtil.h"

enum { SecSide, SecCastling, SecEnPassant };

@interface EditorOptionsViewController () <UIActionSheetDelegate> {
    LCPosition _pos;
}
@end

@implementation EditorOptionsViewController
@synthesize onChange;

- (id)initWithPosition:(LCPosition)pos {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _pos = pos;
        self.title = @"Position options";
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)notify { if (self.onChange) self.onChange(_pos); }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == SecCastling ? 4 : 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return s == SecSide ? @"Side to move" : (s == SecCastling ? @"Castling" : @"En passant");
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == SecCastling) return @"A right can be switched on only while the king and that rook stand on their starting squares.";
    if (s == SecEnPassant) return @"Available when a pawn has just made a double step next to which a capture could happen.";
    return nil;
}

- (NSString *)squareNameForFile:(int)f { return [NSString stringWithFormat:@"%c%d", 'a' + f, _pos.whiteToMove ? 6 : 3]; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[(ip.section == SecSide ? [LCSegmentCell class] : [UITableViewCell class]) alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (ip.section == SecSide) {
        UISegmentedControl *sc = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"White to move", @"Black to move", nil]];
        sc.selectedSegmentIndex = _pos.whiteToMove ? 0 : 1;
        [sc addTarget:self action:@selector(sideChanged:) forControlEvents:UIControlEventValueChanged];
        ((LCSegmentCell *)cell).segmentedControl = sc;
    } else if (ip.section == SecCastling) {
        static NSString *const labels[] = { @"White O-O (kingside)", @"White O-O-O (queenside)", @"Black O-O (kingside)", @"Black O-O-O (queenside)" };
        int bit = 1 << ip.row, avail = LCCastlingAvailable(&_pos);
        cell.textLabel.text = labels[ip.row];
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = (_pos.castle & bit) != 0 && (avail & bit) != 0;
        sw.enabled = (avail & bit) != 0;
        sw.tag = bit;
        [sw addTarget:self action:@selector(castleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        if (!sw.enabled) cell.textLabel.textColor = [UIColor grayColor];
    } else {
        int mask = LCEnPassantFiles(&_pos);
        cell.textLabel.text = @"En passant square";
        if (!mask) { cell.detailTextLabel.text = @"Not available"; cell.textLabel.textColor = [UIColor grayColor]; }
        else {
            cell.detailTextLabel.text = _pos.ep >= 0 ? [self squareNameForFile:_pos.ep & 7] : @"None";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 44; }

- (void)sideChanged:(UISegmentedControl *)sc {
    _pos.whiteToMove = sc.selectedSegmentIndex == 0;
    _pos.ep = -1;                                    // the target rank depends on the side to move
    [self notify];
    [self.tableView reloadData];
}

- (void)castleChanged:(UISwitch *)sw {
    if (sw.on) _pos.castle |= sw.tag; else _pos.castle &= ~(int)sw.tag;
    [self notify];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != SecEnPassant) return;
    int mask = LCEnPassantFiles(&_pos);
    if (!mask) return;
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"En passant square" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [as addButtonWithTitle:@"None"];
    for (int f = 0; f < 8; f++) if (mask & (1 << f)) [as addButtonWithTitle:[self squareNameForFile:f]];
    as.cancelButtonIndex = [as addButtonWithTitle:@"Cancel"];
    [as showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)idx {
    if (idx == as.cancelButtonIndex) return;
    if (idx == 0) _pos.ep = -1;
    else {
        NSString *name = [as buttonTitleAtIndex:idx];
        int f = [name characterAtIndex:0] - 'a';
        _pos.ep = (_pos.whiteToMove ? 5 : 2) * 8 + f;
    }
    [self notify];
    [self.tableView reloadData];
}

@end
