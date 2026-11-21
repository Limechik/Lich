#import "GameReplayViewController.h"
#import "LCBoardView.h"
#import "LCClient.h"
#import "LCUtil.h"

static NSString *PlayerName(id p) {
    id ai = LCGet(p, @"aiLevel");
    if ([ai isKindOfClass:[NSNumber class]]) return [NSString stringWithFormat:@"Stockfish level %@", ai];
    id user = LCGet(p, @"user");
    NSString *name = LCStr(user, @"name") ?: @"Anonymous";
    NSString *title = LCStr(user, @"title");
    if (title.length) name = [NSString stringWithFormat:@"%@ %@", title, name];
    id r = LCGet(p, @"rating");
    if ([r isKindOfClass:[NSNumber class]]) name = [NSString stringWithFormat:@"%@ (%@)", name, r];
    return name;
}

@interface GameReplayViewController () {
    NSDictionary *_game;
    NSMutableArray *_positions;     // NSData(LCPosition), index = ply
    NSMutableArray *_sans;
    int _ply;
    BOOL _truncated;
    LCBoardView *_board;
    UIView *_topBar, *_bottomBar;
    UILabel *_result;
    UIToolbar *_toolbar;
    BOOL _bottomIsWhite;
}
@end

@implementation GameReplayViewController

- (id)initWithGame:(NSDictionary *)game {
    if ((self = [super init])) {
        _game = [game copy];
        self.hidesBottomBarWhenPushed = YES;
        self.title = @"Game";
    }
    return self;
}

- (UIView *)makeBar {
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    UILabel *name = [[UILabel alloc] init];
    name.tag = 1; name.backgroundColor = [UIColor clearColor]; name.textColor = [UIColor whiteColor];
    name.font = [UIFont boldSystemFontOfSize:15]; name.adjustsFontSizeToFitWidth = YES; name.minimumFontSize = 10;
    [bar addSubview:name];
    return bar;
}

- (NSString *)resultText {
    NSString *st = LCStr(_game, @"status") ?: @"", *winner = LCStr(_game, @"winner");
    NSDictionary *why = [NSDictionary dictionaryWithObjectsAndKeys:
        @"checkmate", @"mate", @"resignation", @"resign", @"stalemate", @"stalemate", @"time out", @"timeout",
        @"time out", @"outoftime", @"agreement", @"draw", nil];
    NSString *by = [why objectForKey:st];
    if ([st isEqualToString:@"aborted"] || [st isEqualToString:@"noStart"]) return @"Game aborted";
    if (winner) return [NSString stringWithFormat:@"%@ won%@", [winner isEqualToString:@"white"] ? @"White" : @"Black", by ? [@" by " stringByAppendingString:by] : @""];
    if ([st isEqualToString:@"stalemate"] || [st isEqualToString:@"draw"]) return [@"Draw" stringByAppendingString:by && ![st isEqualToString:@"draw"] ? [@" by " stringByAppendingString:by] : @""];
    return st.length ? st : @"";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];

    // Build every position up front by replaying the SAN list.
    _positions = [NSMutableArray array]; _sans = [NSMutableArray array];
    LCPosition p;
    NSString *fen = LCStr(_game, @"initialFen");
    if (!(fen && ![fen isEqualToString:@"startpos"] && LCPositionFromFEN(&p, [fen UTF8String]))) LCPositionStart(&p);
    [_positions addObject:[NSData dataWithBytes:&p length:sizeof p]];
    for (NSString *san in [(LCStr(_game, @"moves") ?: @"") componentsSeparatedByString:@" "]) {
        if (!san.length) continue;
        if (!LCPositionApplySAN(&p, [san UTF8String])) { _truncated = YES; break; }
        [_sans addObject:san];
        [_positions addObject:[NSData dataWithBytes:&p length:sizeof p]];
    }
    _ply = (int)_sans.count;                       // open on the final position

    id players = LCGet(_game, @"players");
    _topBar = [self makeBar]; _bottomBar = [self makeBar];
    ((UILabel *)[_bottomBar viewWithTag:1]).text = PlayerName(LCGet(players, @"white"));
    ((UILabel *)[_topBar viewWithTag:1]).text = PlayerName(LCGet(players, @"black"));
    _bottomIsWhite = YES;
    // Show the game from my side when it was my game.
    NSString *me = [LCClient shared].userId;
    if (me.length && [[LCStr(LCGet(LCGet(players, @"black"), @"user"), @"id") lowercaseString] isEqualToString:me]) {
        _bottomIsWhite = NO;
        id tmp = ((UILabel *)[_bottomBar viewWithTag:1]).text;
        ((UILabel *)[_bottomBar viewWithTag:1]).text = ((UILabel *)[_topBar viewWithTag:1]).text;
        ((UILabel *)[_topBar viewWithTag:1]).text = tmp;
    }

    _board = [[LCBoardView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    _board.interactive = NO;
    _board.flipped = !_bottomIsWhite;
    _result = [[UILabel alloc] init];
    _result.backgroundColor = [UIColor clearColor]; _result.textColor = [UIColor lightGrayColor];
    _result.textAlignment = UITextAlignmentCenter; _result.font = [UIFont systemFontOfSize:13];
    _result.text = _truncated ? @"Some moves could not be read" : [self resultText];

    _toolbar = [[UIToolbar alloc] init];
    _toolbar.barStyle = UIBarStyleBlack;
    UIBarButtonItem *sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    NSArray *titles = [NSArray arrayWithObjects:@"|<", @"<", @">", @">|", @"Flip", nil];
    SEL acts[] = { @selector(toStart), @selector(back), @selector(forward), @selector(toEnd), @selector(flip) };
    NSMutableArray *items = [NSMutableArray array];
    for (int i = 0; i < 5; i++) {
        [items addObject:[[UIBarButtonItem alloc] initWithTitle:[titles objectAtIndex:i] style:UIBarButtonItemStyleBordered target:self action:acts[i]]];
        if (i < 4) [items addObject:sp];
    }
    _toolbar.items = items;
    for (UIView *v in [NSArray arrayWithObjects:_topBar, _board, _bottomBar, _result, _toolbar, nil]) [self.view addSubview:v];
    if (LCStr(_game, @"pgn").length || LCStr(_game, @"id").length)
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Analyse" style:UIBarButtonItemStyleBordered target:self action:@selector(analyseTapped)];
    [self show];
}

// Games that live on lichess.org open directly; imported PGNs are first sent to Lichess (POST /api/import).
- (void)analyseTapped {
    NSString *gid = LCStr(_game, @"id"), *pgn = LCStr(_game, @"pgn");
    if (gid.length && !pgn.length) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://lichess.org/" stringByAppendingString:gid]]];
        return;
    }
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [[LCClient shared] importPGN:pgn done:^(id json, NSString *err) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        NSString *url = LCStr(json, @"url");
        if (err || !url) {
            [[[UIAlertView alloc] initWithTitle:@"Can't import to Lichess" message:err ?: @"No link returned." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height, barH = 32;
    BOOL land = W > H;
    CGFloat tbH = LCToolbarHeight(land);
    CGFloat barW;
    if (land) {                                   // board on the left, players and result beside it
        CGFloat avail = H - tbH;
        CGFloat side = MIN(avail, W - 200);
        CGFloat by = floor((avail - side) / 2), px = side + 8;
        barW = W - side - 16;
        _board.frame = CGRectMake(0, by, side, side);
        _topBar.frame = CGRectMake(px, by, barW, barH);
        _bottomBar.frame = CGRectMake(px, by + side - barH, barW, barH);
        _result.frame = CGRectMake(px, by + barH + 6, barW, 40);
    } else {
        CGFloat side = MIN(W, H - 2 * barH - tbH - 26);
        CGFloat y0 = MAX(0, (H - tbH - (2 * barH + side + 26)) / 2), x = (W - side) / 2;
        barW = side;
        _topBar.frame = CGRectMake(x, y0, side, barH);
        _board.frame = CGRectMake(x, y0 + barH, side, side);
        _bottomBar.frame = CGRectMake(x, y0 + barH + side, side, barH);
        _result.frame = CGRectMake(0, y0 + 2 * barH + side + 4, W, 20);
    }
    _result.numberOfLines = land ? 2 : 1;
    _toolbar.frame = CGRectMake(0, H - tbH, W, tbH);
    for (UIView *bar in [NSArray arrayWithObjects:_topBar, _bottomBar, nil]) [bar viewWithTag:1].frame = CGRectMake(8, 0, barW - 16, barH);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)show {
    LCPosition p; [[_positions objectAtIndex:_ply] getBytes:&p length:sizeof p];
    _board.position = p;
    if (_ply == 0) self.title = @"Start position";
    else self.title = [NSString stringWithFormat:@"%d%@ %@", (_ply + 1) / 2, (_ply % 2 == 1) ? @"." : @"…", [_sans objectAtIndex:_ply - 1]];
}

- (void)toStart { _ply = 0; [self show]; }
- (void)back { if (_ply > 0) { _ply--; [self show]; } }
- (void)forward { if (_ply < (int)_sans.count) { _ply++; [self show]; } }
- (void)toEnd { _ply = (int)_sans.count; [self show]; }
- (void)flip {
    _bottomIsWhite = !_bottomIsWhite;
    _board.flipped = !_bottomIsWhite;
    NSString *a = ((UILabel *)[_bottomBar viewWithTag:1]).text;
    ((UILabel *)[_bottomBar viewWithTag:1]).text = ((UILabel *)[_topBar viewWithTag:1]).text;
    ((UILabel *)[_topBar viewWithTag:1]).text = a;
}

@end
