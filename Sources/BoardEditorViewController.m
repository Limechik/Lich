#import "BoardEditorViewController.h"
#import "EditorOptionsViewController.h"
#import "GameViewController.h"
#import "LCBoardView.h"
#import "LCClient.h"
#import "LCUtil.h"
#import "LocalGameViewController.h"

static NSString *const kPieces = @"kqrbnpKQRBNP";      // palette tools 0..11: black row, then white row
static NSString *const kSavedFEN = @"lc.editor.fen";
enum { ToolMove = -2, ToolErase = -1 };
enum { TagMoveButton = 100, TagEraseButton = 101 };
enum { SheetMenu = 1, SheetPlay = 2, SheetLevel = 3 };
enum { AlertLoadFEN = 10, AlertInfo = 11 };
enum { MenuOptions, MenuReset, MenuClear, MenuLoad, MenuCopy, MenuAnalyse, MenuPlay };
enum { PlayComputer, PlayTwoPlayers, PlayLichessAI };
static const int kLevels[] = { 1, 3, 5, 8 };

#pragma mark - Drawing helpers

static UIImage *ColorImage(UIColor *c) {
    UIGraphicsBeginImageContext(CGSizeMake(1, 1));
    [c setFill]; UIRectFill(CGRectMake(0, 0, 1, 1));
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

static UIImage *ScaledImage(UIImage *src, CGFloat side) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
    [src drawInRect:CGRectMake(0, 0, side, side)];
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

// kind 0: four-way arrow (move), 1: trash can (erase). White on transparent.
static UIImage *ToolIcon(int kind, CGFloat side) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
    CGContextRef g = UIGraphicsGetCurrentContext();
    CGFloat u = side / 32.0;
    CGContextScaleCTM(g, u, u);
    CGContextSetFillColorWithColor(g, [UIColor whiteColor].CGColor);
    if (kind == 0) {
        CGContextFillRect(g, CGRectMake(15, 7, 2, 18));
        CGContextFillRect(g, CGRectMake(7, 15, 18, 2));
        CGPoint tri[4][3] = {
            { {16, 2}, {11, 9}, {21, 9} }, { {16, 30}, {11, 23}, {21, 23} },
            { {2, 16}, {9, 11}, {9, 21} }, { {30, 16}, {23, 11}, {23, 21} } };
        for (int i = 0; i < 4; i++) {
            CGContextMoveToPoint(g, tri[i][0].x, tri[i][0].y);
            CGContextAddLineToPoint(g, tri[i][1].x, tri[i][1].y);
            CGContextAddLineToPoint(g, tri[i][2].x, tri[i][2].y);
            CGContextClosePath(g); CGContextFillPath(g);
        }
    } else {
        CGContextFillRect(g, CGRectMake(6, 7, 20, 3));
        CGContextFillRect(g, CGRectMake(12, 4, 8, 3));
        CGContextMoveToPoint(g, 8, 11); CGContextAddLineToPoint(g, 24, 11);
        CGContextAddLineToPoint(g, 22, 28); CGContextAddLineToPoint(g, 10, 28);
        CGContextClosePath(g); CGContextFillPath(g);
        CGContextSetBlendMode(g, kCGBlendModeClear);
        CGContextFillRect(g, CGRectMake(12.5, 13, 1.5, 12));
        CGContextFillRect(g, CGRectMake(15.5, 13, 1.5, 12));
        CGContextFillRect(g, CGRectMake(18.5, 13, 1.5, 12));
    }
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

#pragma mark - Editor

@interface BoardEditorViewController () <LCBoardEditDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
    LCBoardView *_board;
    UIView *_topRow, *_bottomRow;
    UIToolbar *_toolbar;
    UIBarButtonItem *_turnItem;
    LCPosition _pos;
    int _tool;
    CGFloat _iconSide;
    NSArray *_menuCodes, *_playChoices;
    int _chosenPlay;
}
@end

@implementation BoardEditorViewController

- (id)init {
    if ((self = [super init])) {
        self.title = @"Board editor";
        self.hidesBottomBarWhenPushed = YES;
        _tool = ToolMove;
    }
    return self;
}

- (UIView *)makeRowWithTags:(NSArray *)tags {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    UIImage *sel = ColorImage([UIColor colorWithRed:0.35 green:0.55 blue:0.25 alpha:1]);
    for (NSNumber *t in tags) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = [t intValue];
        [b setBackgroundImage:sel forState:UIControlStateSelected];
        [b addTarget:self action:@selector(paletteTapped:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:b];
    }
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];

    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:kSavedFEN];
    if (!(saved.length && LCPositionFromFEN(&_pos, [saved UTF8String]))) LCPositionStart(&_pos);

    _board = [[LCBoardView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    _board.editMode = YES;
    _board.editDelegate = self;
    _board.editTool = ToolMove;
    _topRow = [self makeRowWithTags:[NSArray arrayWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:1], [NSNumber numberWithInt:2],
                                     [NSNumber numberWithInt:3], [NSNumber numberWithInt:4], [NSNumber numberWithInt:5], [NSNumber numberWithInt:TagMoveButton], nil]];
    _bottomRow = [self makeRowWithTags:[NSArray arrayWithObjects:[NSNumber numberWithInt:6], [NSNumber numberWithInt:7], [NSNumber numberWithInt:8],
                                        [NSNumber numberWithInt:9], [NSNumber numberWithInt:10], [NSNumber numberWithInt:11], [NSNumber numberWithInt:TagEraseButton], nil]];

    _toolbar = [[UIToolbar alloc] init];
    _toolbar.barStyle = UIBarStyleBlack;
    UIBarButtonItem *flip = [[UIBarButtonItem alloc] initWithTitle:@"Flip" style:UIBarButtonItemStyleBordered target:self action:@selector(flipTapped)];
    _turnItem = [[UIBarButtonItem alloc] initWithTitle:@"White to move" style:UIBarButtonItemStyleBordered target:self action:@selector(turnTapped)];
    UIBarButtonItem *opts = [[UIBarButtonItem alloc] initWithTitle:@"Options" style:UIBarButtonItemStyleBordered target:self action:@selector(optionsTapped)];
    UIBarButtonItem *sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    _toolbar.items = [NSArray arrayWithObjects:flip, sp, _turnItem, sp, opts, nil];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Menu" style:UIBarButtonItemStyleBordered target:self action:@selector(menuTapped)];

    for (UIView *v in [NSArray arrayWithObjects:_topRow, _board, _bottomRow, _toolbar, nil]) [self.view addSubview:v];
    [self sanitize];
    [self refresh];
    [self updateToolSelection];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height;
    BOOL land = W > H;
    CGFloat tbH = LCToolbarHeight(land);
    CGFloat palH, rowW;
    if (land) {                                   // board on the left, the two palette rows stacked beside it
        CGFloat avail = H - tbH;
        CGFloat side = MIN(avail, W - 230);
        CGFloat by = floor((avail - side) / 2), px = side + 8;
        rowW = W - side - 16;
        palH = floor(MIN(MAX(rowW / 7.0, 40), 46));
        _board.frame = CGRectMake(0, by, side, side);
        _topRow.frame = CGRectMake(px, by, rowW, palH);
        _bottomRow.frame = CGRectMake(px, by + palH + 10, rowW, palH);
    } else {
        palH = floor(MIN(W / 7.0, 46));
        CGFloat side = MIN(W, H - 2 * palH - tbH);
        CGFloat y0 = MAX(0, (H - tbH - (2 * palH + side)) / 2), x = (W - side) / 2;
        rowW = side;
        _topRow.frame = CGRectMake(x, y0, side, palH);
        _board.frame = CGRectMake(x, y0 + palH, side, side);
        _bottomRow.frame = CGRectMake(x, y0 + palH + side, side, palH);
    }
    _toolbar.frame = CGRectMake(0, H - tbH, W, tbH);

    CGFloat bw = rowW / 7.0;
    CGFloat iconSize = MIN(bw, palH) - 8;
    for (UIView *row in [NSArray arrayWithObjects:_topRow, _bottomRow, nil]) {
        int i = 0;
        for (UIButton *b in row.subviews) {
            b.frame = CGRectMake(i * bw, 0, bw, palH);
            if (_iconSide != iconSize) {
                CGFloat icon = iconSize;
                if (b.tag == TagMoveButton) [b setImage:ToolIcon(0, icon) forState:UIControlStateNormal];
                else if (b.tag == TagEraseButton) [b setImage:ToolIcon(1, icon) forState:UIControlStateNormal];
                else {
                    UIImage *img = [LCBoardView imageForPiece:(char)[kPieces characterAtIndex:b.tag]];
                    if (img) [b setImage:ScaledImage(img, icon) forState:UIControlStateNormal];
                }
            }
            i++;
        }
    }
    _iconSide = iconSize;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _iconSide = 0;                                   // rebuild the palette pictures (the piece set may have changed)
    [self.view setNeedsLayout];
}

#pragma mark - State

- (void)sanitize {
    _pos.castle &= LCCastlingAvailable(&_pos);
    if (_pos.ep >= 0) {
        int f = _pos.ep & 7, rank = _pos.ep >> 3;
        BOOL okRank = _pos.whiteToMove ? rank == 5 : rank == 2;
        if (!okRank || !(LCEnPassantFiles(&_pos) & (1 << f))) _pos.ep = -1;
    }
    _pos.lastFrom = _pos.lastTo = -1;
}

- (void)refresh {
    _board.position = _pos;
    _turnItem.title = _pos.whiteToMove ? @"White to move" : @"Black to move";
}

- (void)changed {
    [self sanitize];
    [self refresh];
    char buf[96]; LCPositionToFEN(&_pos, buf, sizeof buf);
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithUTF8String:buf] forKey:kSavedFEN];
}

- (NSString *)currentFEN {
    char buf[96]; LCPositionToFEN(&_pos, buf, sizeof buf);
    return [NSString stringWithUTF8String:buf];
}

// FEN if the position can be played from, otherwise nil (after telling the user why).
- (NSString *)validatedFEN {
    const char *why = NULL;
    if (!LCPositionValidate(&_pos, &why)) { [self alertTitle:@"Invalid position" message:why ? [NSString stringWithUTF8String:why] : @""]; return nil; }
    return [self currentFEN];
}

- (void)alertTitle:(NSString *)t message:(NSString *)m {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:t message:m delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    a.tag = AlertInfo; [a show];
}

#pragma mark - Palette & editing

- (void)updateToolSelection {
    int wanted = _tool >= 0 ? _tool : (_tool == ToolMove ? TagMoveButton : TagEraseButton);
    for (UIView *row in [NSArray arrayWithObjects:_topRow, _bottomRow, nil])
        for (UIButton *b in row.subviews) b.selected = (b.tag == wanted);
}

- (void)paletteTapped:(UIButton *)b {
    _tool = (b.tag == TagMoveButton) ? ToolMove : (b.tag == TagEraseButton ? ToolErase : (int)b.tag);
    _board.editTool = _tool;
    [self updateToolSelection];
}

static BOOL IsPawnOnBackRank(char piece, int sq) { return (piece == 'P' || piece == 'p') && ((sq >> 3) == 0 || (sq >> 3) == 7); }

- (void)boardView:(LCBoardView *)v paintSquare:(int)sq {
    char piece = (_tool >= 0) ? (char)[kPieces characterAtIndex:_tool] : 0;     // ToolErase -> 0
    if (IsPawnOnBackRank(piece, sq)) return;
    if (_pos.board[sq] == piece) return;
    _pos.board[sq] = piece;
    [self changed];
}

- (void)boardView:(LCBoardView *)v movePieceFrom:(int)from to:(int)to {
    char piece = _pos.board[from];
    if (to < 0) { _pos.board[from] = 0; [self changed]; return; }                // dropped off the board: delete
    if (IsPawnOnBackRank(piece, to)) { [self refresh]; return; }                 // snap back
    _pos.board[to] = piece;
    _pos.board[from] = 0;
    [self changed];
}

- (void)flipTapped { _board.flipped = !_board.flipped; }

- (void)turnTapped {
    _pos.whiteToMove = !_pos.whiteToMove;
    _pos.ep = -1;
    [self changed];
}

- (void)optionsTapped {
    EditorOptionsViewController *vc = [[EditorOptionsViewController alloc] initWithPosition:_pos];
    vc.onChange = ^(LCPosition p) { _pos = p; [self changed]; };
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Menu

- (void)menuTapped {
    NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"Position options…", @"Reset position", @"Clear board", @"Load FEN…", @"Copy FEN", @"Analyse on lichess.org", @"Play from this position…", nil];
    _menuCodes = [NSArray arrayWithObjects:[NSNumber numberWithInt:MenuOptions], [NSNumber numberWithInt:MenuReset], [NSNumber numberWithInt:MenuClear],
                  [NSNumber numberWithInt:MenuLoad], [NSNumber numberWithInt:MenuCopy], [NSNumber numberWithInt:MenuAnalyse], [NSNumber numberWithInt:MenuPlay], nil];
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *t in titles) [as addButtonWithTitle:t];
    as.cancelButtonIndex = [as addButtonWithTitle:@"Cancel"];
    as.tag = SheetMenu;
    [as showFromToolbar:_toolbar];
}

- (void)actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)idx {
    if (idx == as.cancelButtonIndex || idx < 0) return;
    if (as.tag == SheetMenu) {
        switch ([[_menuCodes objectAtIndex:idx] intValue]) {
            case MenuOptions: [self optionsTapped]; break;
            case MenuReset: LCPositionStart(&_pos); [self changed]; break;
            case MenuClear: LCPositionClear(&_pos); [self changed]; break;
            case MenuLoad: {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Load FEN" message:@"Paste or type a position" delegate:self
                                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Load", nil];
                a.alertViewStyle = UIAlertViewStylePlainTextInput;
                UITextField *f = [a textFieldAtIndex:0];
                f.text = [self currentFEN];
                f.autocapitalizationType = UITextAutocapitalizationTypeNone; f.autocorrectionType = UITextAutocorrectionTypeNo;
                a.tag = AlertLoadFEN; [a show];
                break;
            }
            case MenuCopy:
                [UIPasteboard generalPasteboard].string = [self currentFEN];
                [self alertTitle:@"FEN copied" message:[self currentFEN]];
                break;
            case MenuAnalyse: {
                NSString *fen = [self validatedFEN];
                if (!fen) break;
                NSString *url = [@"https://lichess.org/analysis/" stringByAppendingString:[fen stringByReplacingOccurrencesOfString:@" " withString:@"_"]];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                break;
            }
            case MenuPlay: [self playTapped]; break;
        }
    } else if (as.tag == SheetPlay) {
        int choice = [[_playChoices objectAtIndex:idx] intValue];
        if (choice == PlayTwoPlayers) [self startLocalOpponent:@"otb" level:3];
        else { _chosenPlay = choice; [self askLevel]; }
    } else if (as.tag == SheetLevel) {
        if (idx >= 4) return;
        int level = kLevels[idx];
        if (_chosenPlay == PlayComputer) [self startLocalOpponent:@"engine" level:level];
        else [self startLichessAILevel:level];
    }
}

- (void)alertView:(UIAlertView *)av clickedButtonAtIndex:(NSInteger)idx {
    if (av.tag != AlertLoadFEN || idx == av.cancelButtonIndex) return;
    NSString *t = [[av textFieldAtIndex:0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    LCPosition p;
    if (!t.length || !LCPositionFromFEN(&p, [t UTF8String])) { [self alertTitle:@"Invalid FEN" message:@"That doesn't look like a valid position."]; return; }
    _pos = p;
    [self changed];
}

#pragma mark - Play from position

- (void)playTapped {
    if (![self validatedFEN]) return;
    NSMutableArray *titles = [NSMutableArray arrayWithObjects:@"Offline vs computer", @"Two players (offline)", nil];
    NSMutableArray *choices = [NSMutableArray arrayWithObjects:[NSNumber numberWithInt:PlayComputer], [NSNumber numberWithInt:PlayTwoPlayers], nil];
    if ([[LCClient shared].token length]) { [titles addObject:@"Lichess AI"]; [choices addObject:[NSNumber numberWithInt:PlayLichessAI]]; }
    _playChoices = choices;
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Play from this position" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *t in titles) [as addButtonWithTitle:t];
    as.cancelButtonIndex = [as addButtonWithTitle:@"Cancel"];
    as.tag = SheetPlay;
    [as showFromToolbar:_toolbar];
}

- (void)askLevel {
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Computer strength" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil
                                           otherButtonTitles:@"Level 1 (beginner)", @"Level 3", @"Level 5", @"Level 8 (strongest)", nil];
    as.cancelButtonIndex = [as addButtonWithTitle:@"Cancel"];
    as.tag = SheetLevel;
    [as showFromToolbar:_toolbar];
}

- (void)startLocalOpponent:(NSString *)opponent level:(int)level {
    NSString *fen = [self validatedFEN];
    if (!fen) return;
    NSDictionary *cfg = [NSDictionary dictionaryWithObjectsAndKeys:
        opponent, @"opponent", [NSNumber numberWithBool:NO], @"clock",
        [NSNumber numberWithDouble:10], @"minutes", [NSNumber numberWithInt:0], @"increment",
        @"random", @"color", [NSNumber numberWithInt:level], @"level", fen, @"fen", nil];
    [self.navigationController pushViewController:[[LocalGameViewController alloc] initWithConfig:cfg] animated:YES];
}

- (void)startLichessAILevel:(int)level {
    NSString *fen = [self validatedFEN];
    if (!fen) return;
    self.view.userInteractionEnabled = NO;
    [[LCClient shared] challengeAILevel:level limitSeconds:-1 increment:0 color:@"random" fen:fen done:^(id json, NSString *err) {
        self.view.userInteractionEnabled = YES;
        if (err) { [self alertTitle:@"Can't start game" message:err]; return; }
        NSString *gid = LCStr(json, @"id");
        if (gid) [self.navigationController pushViewController:[[GameViewController alloc] initWithGameId:gid colorHint:LCStr(json, @"player")] animated:YES];
    }];
}

@end
