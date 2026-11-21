#import "BoardAppearanceViewController.h"
#import "LCUtil.h"
#import <QuartzCore/QuartzCore.h>
#import "LCBoardStyle.h"
#import "LCBoardView.h"
#import "StylePickerViewController.h"

enum { SecStyle, SecDisplay };
enum { RowBoard, RowPieces, RowShapes };

@implementation BoardAppearanceViewController {
    LCBoardView *_preview;
}

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Board appearance";
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat side = 220;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, side + 28)];
    header.backgroundColor = [UIColor colorWithWhite:0.11 alpha:1];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _preview = [[LCBoardView alloc] initWithFrame:CGRectMake((320 - side) / 2, 14, side, side)];
    _preview.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _preview.interactive = NO;
    _preview.layer.cornerRadius = 6;
    _preview.layer.masksToBounds = YES;
    // 1.e4, with the sample annotations from the Android app: an arrow b8 -> c6 and a circle on b8
    LCPosition p;
    LCPositionFromFEN(&p, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1");
    p.lastFrom = 12; p.lastTo = 28;
    _preview.position = p;
    [_preview setArrows:[NSArray arrayWithObject:[NSNumber numberWithInt:57 * 64 + 42]] circles:[NSArray arrayWithObject:[NSNumber numberWithInt:57]]];
    [header addSubview:_preview];
    self.tableView.tableHeaderView = header;
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == SecStyle ? 3 : 2; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == SecStyle ? @"Shape colour is used for arrows and circles you draw on a board: drag with two fingers for an arrow, tap with two fingers for a circle. A single tap clears them." : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    LCBoardStyle *st = [LCBoardStyle shared];
    if (ip.section == SecStyle) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        switch (ip.row) {
            case RowBoard:
                cell.textLabel.text = @"Board"; cell.detailTextLabel.text = [st boardName];
                cell.imageView.image = [st swatchForBoard:[self currentBoardEntry] size:30];
                break;
            case RowPieces:
                cell.textLabel.text = @"Pieces"; cell.detailTextLabel.text = [st pieceSetName];
                cell.imageView.image = [st swatchForSet:st.pieceSetId height:30];
                break;
            default:
                cell.textLabel.text = @"Shape colour";
                cell.detailTextLabel.text = [[st.shapeColors objectAtIndex:st.shapeColorIndex] objectForKey:@"name"];
                cell.imageView.image = [st swatchForColor:[st shapeColor] size:30];
                break;
        }
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.tag = ip.row;
        if (ip.row == 0) { cell.textLabel.text = @"Board coordinates (A–H, 1–8)"; sw.on = st.showCoordinates; }
        else { cell.textLabel.text = @"Show frame"; sw.on = st.showFrame; }
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    return cell;
}

- (NSDictionary *)currentBoardEntry {
    LCBoardStyle *st = [LCBoardStyle shared];
    for (NSDictionary *b in st.boards) if ([[b objectForKey:@"id"] isEqualToString:st.boardId]) return b;
    return [st.boards objectAtIndex:0];
}

- (void)switchChanged:(UISwitch *)sw {
    LCBoardStyle *st = [LCBoardStyle shared];
    if (sw.tag == 0) st.showCoordinates = sw.on; else st.showFrame = sw.on;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != SecStyle) return;
    LCBoardStyle *st = [LCBoardStyle shared];
    StylePickerViewController *vc = [[StylePickerViewController alloc] initWithStyle:UITableViewStylePlain];
    NSMutableArray *items = [NSMutableArray array];
    switch (ip.row) {
        case RowBoard:
            vc.title = @"Board";
            for (NSDictionary *b in st.boards)
                [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:[b objectForKey:@"id"], @"id", [b objectForKey:@"name"], @"title",
                                  [st swatchForBoard:b size:40], @"image", nil]];
            vc.selectedId = st.boardId;
            vc.onSelect = ^(NSString *chosen) { [LCBoardStyle shared].boardId = chosen; };
            break;
        case RowPieces:
            vc.title = @"Pieces";
            for (NSDictionary *p in st.pieceSets)
                [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:[p objectForKey:@"id"], @"id", [p objectForKey:@"name"], @"title",
                                  [st swatchForSet:[p objectForKey:@"id"] height:40], @"image", nil]];
            vc.selectedId = st.pieceSetId;
            vc.onSelect = ^(NSString *chosen) { [LCBoardStyle shared].pieceSetId = chosen; };
            break;
        default: {
            vc.title = @"Shape colour";
            int i = 0;
            for (NSDictionary *c in st.shapeColors)
                [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%d", i++], @"id", [c objectForKey:@"name"], @"title",
                                  [st swatchForColor:[c objectForKey:@"color"] size:40], @"image", nil]];
            vc.selectedId = [NSString stringWithFormat:@"%d", st.shapeColorIndex];
            vc.onSelect = ^(NSString *chosen) { [LCBoardStyle shared].shapeColorIndex = [chosen intValue]; };
            break;
        }
    }
    vc.items = items;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
