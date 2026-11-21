#import "TVViewController.h"
#import "LCBoardView.h"
#import "LCClient.h"
#import "LCUtil.h"

static NSString *FormatMs(long long ms) {
    if (ms < 0) return @"--:--";
    long long s = ms / 1000, h = s / 3600, m = (s % 3600) / 60; s %= 60;
    if (h > 0) return [NSString stringWithFormat:@"%lld:%02lld:%02lld", h, m, s];
    return [NSString stringWithFormat:@"%lld:%02lld", m, s];
}

@interface TVViewController () {
    NSString *_channel;
    LCBoardView *_board;
    UIView *_topBar, *_bottomBar;
    UILabel *_status;
    LCConnection *_stream;
    NSTimer *_timer;
    NSString *_whiteName, *_blackName;
    BOOL _bottomIsWhite, _whiteToMove, _alive;
    long long _wc, _bc;
    NSDate *_stamp;
}
@end

@implementation TVViewController

- (id)initWithChannel:(NSString *)channel title:(NSString *)title {
    if ((self = [super init])) {
        _channel = [channel copy]; self.title = title;
        self.hidesBottomBarWhenPushed = YES;
        _bottomIsWhite = YES; _wc = _bc = -1;
    }
    return self;
}

- (UIView *)makeBar {
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    UILabel *name = [[UILabel alloc] init];
    name.tag = 1; name.backgroundColor = [UIColor clearColor]; name.textColor = [UIColor whiteColor];
    name.font = [UIFont boldSystemFontOfSize:15]; name.adjustsFontSizeToFitWidth = YES; name.minimumFontSize = 10;
    UILabel *clock = [[UILabel alloc] init];
    clock.tag = 2; clock.textAlignment = UITextAlignmentCenter; clock.textColor = [UIColor whiteColor];
    clock.backgroundColor = [UIColor colorWithWhite:0.28 alpha:1];
    clock.font = [UIFont fontWithName:@"Courier-Bold" size:19];
    [bar addSubview:name]; [bar addSubview:clock];
    return bar;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    _topBar = [self makeBar]; _bottomBar = [self makeBar];
    _board = [[LCBoardView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    _board.interactive = NO;
    _status = [[UILabel alloc] init];
    _status.backgroundColor = [UIColor clearColor]; _status.textColor = [UIColor lightGrayColor];
    _status.textAlignment = UITextAlignmentCenter; _status.font = [UIFont systemFontOfSize:13];
    _status.text = @"Connecting to Lichess TV…";
    for (UIView *v in [NSArray arrayWithObjects:_topBar, _board, _bottomBar, _status, nil]) [self.view addSubview:v];
    _alive = YES;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [self connect];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height, barH = 32;
    BOOL land = W > H;
    CGFloat barW;
    if (land) {                                   // board on the left, players, clocks and status beside it
        CGFloat side = MIN(H, W - 200);
        CGFloat by = floor((H - side) / 2), px = side + 8;
        barW = W - side - 16;
        _board.frame = CGRectMake(0, by, side, side);
        _topBar.frame = CGRectMake(px, by, barW, barH);
        _bottomBar.frame = CGRectMake(px, by + side - barH, barW, barH);
        _status.frame = CGRectMake(px, by + barH + 6, barW, 40);
    } else {
        CGFloat side = MIN(W, H - 2 * barH - 30);
        CGFloat y0 = MAX(0, (H - (2 * barH + side + 30)) / 2), x = (W - side) / 2;
        barW = side;
        _topBar.frame = CGRectMake(x, y0, side, barH);
        _board.frame = CGRectMake(x, y0 + barH, side, side);
        _bottomBar.frame = CGRectMake(x, y0 + barH + side, side, barH);
        _status.frame = CGRectMake(0, y0 + 2 * barH + side + 4, W, 22);
    }
    _status.numberOfLines = land ? 2 : 1;
    for (UIView *bar in [NSArray arrayWithObjects:_topBar, _bottomBar, nil]) {
        [bar viewWithTag:1].frame = CGRectMake(8, 0, barW - 108, barH);
        [bar viewWithTag:2].frame = CGRectMake(barW - 98, 3, 92, barH - 6);
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self isMovingFromParentViewController]) {
        _alive = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [_timer invalidate]; _timer = nil;
        [_stream cancel]; _stream = nil;
    }
}

- (void)dealloc { [_timer invalidate]; [_stream cancel]; }

#pragma mark - Stream

- (void)connect {
    [_stream cancel];
    _stream = [[LCClient shared] streamTV:_channel
        onEvent:^(id e) { [self handle:e]; }
        onEnd:^(NSString *err) {
            _stream = nil;
            if (!_alive) return;
            _status.text = err ? err : @"Reconnecting…";
            [self performSelector:@selector(connect) withObject:nil afterDelay:3.0];
        }];
}

- (NSString *)nameFor:(id)player {
    id user = LCGet(player, @"user");
    NSString *name = LCStr(user, @"name") ?: LCStr(user, @"id") ?: @"Anonymous";
    NSString *title = LCStr(user, @"title");
    if (title.length) name = [NSString stringWithFormat:@"%@ %@", title, name];
    id rating = LCGet(player, @"rating");
    if ([rating isKindOfClass:[NSNumber class]]) name = [NSString stringWithFormat:@"%@ (%@)", name, rating];
    return name;
}

- (void)handle:(id)e {
    NSString *type = LCStr(e, @"t");
    id d = LCGet(e, @"d");
    if ([type isEqualToString:@"featured"]) {
        _status.text = @"";
        id players = LCGet(d, @"players");
        if ([players isKindOfClass:[NSArray class]]) {
            for (id p in players) {
                if ([LCStr(p, @"color") isEqualToString:@"white"]) _whiteName = [self nameFor:p];
                else _blackName = [self nameFor:p];
                id secs = LCGet(p, @"seconds");
                if ([secs isKindOfClass:[NSNumber class]]) {
                    if ([LCStr(p, @"color") isEqualToString:@"white"]) _wc = [secs longLongValue] * 1000; else _bc = [secs longLongValue] * 1000;
                }
            }
        }
        _bottomIsWhite = ![LCStr(d, @"orientation") isEqualToString:@"black"];
        _board.flipped = !_bottomIsWhite;
        [self applyFEN:LCStr(d, @"fen") lastMove:nil];
    } else if ([type isEqualToString:@"fen"]) {
        id wc = LCGet(d, @"wc"), bc = LCGet(d, @"bc");
        if ([wc isKindOfClass:[NSNumber class]]) _wc = [wc longLongValue] * 1000;
        if ([bc isKindOfClass:[NSNumber class]]) _bc = [bc longLongValue] * 1000;
        [self applyFEN:LCStr(d, @"fen") lastMove:LCStr(d, @"lm")];
    }
}

- (void)applyFEN:(NSString *)fen lastMove:(NSString *)lm {
    if (!fen) return;
    LCPosition p;
    if (!LCPositionFromFEN(&p, [fen UTF8String])) return;
    if (lm.length >= 4) {
        const char *u = [lm UTF8String];
        p.lastFrom = (u[1] - '1') * 8 + (u[0] - 'a');
        p.lastTo = (u[3] - '1') * 8 + (u[2] - 'a');
        if ([fen rangeOfString:@" "].location == NSNotFound) {   // placement only: infer the side to move
            char moved = p.board[p.lastTo];
            p.whiteToMove = !(moved >= 'A' && moved <= 'Z');
        }
    }
    _whiteToMove = p.whiteToMove != 0;
    _board.position = p;
    _stamp = [NSDate date];
    [self refreshNames];
}

- (void)refreshNames {
    NSString *wn = _whiteName ?: @"White", *bn = _blackName ?: @"Black";
    ((UILabel *)[_bottomBar viewWithTag:1]).text = _bottomIsWhite ? wn : bn;
    ((UILabel *)[_topBar viewWithTag:1]).text = _bottomIsWhite ? bn : wn;
    [self tick];
}

- (void)tick {
    long long w = _wc, b = _bc;
    if (_stamp) {
        long long el = (long long)(-[_stamp timeIntervalSinceNow] * 1000.0);
        if (_whiteToMove) { if (w >= 0) w = MAX(0, w - el); } else { if (b >= 0) b = MAX(0, b - el); }
    }
    ((UILabel *)[(_bottomIsWhite ? _bottomBar : _topBar) viewWithTag:2]).text = FormatMs(w);
    ((UILabel *)[(_bottomIsWhite ? _topBar : _bottomBar) viewWithTag:2]).text = FormatMs(b);
}

@end
