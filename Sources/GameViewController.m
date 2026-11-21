#import "GameViewController.h"
#import "LCBoardView.h"
#import "LCClient.h"
#import "LCUtil.h"

static NSString *FormatClock(long long ms) {
    if (ms < 0) return @"--:--";
    if (ms < 10000) return [NSString stringWithFormat:@"0:%04.1f", ms / 1000.0];
    long long s = ms / 1000, h = s / 3600, m = (s % 3600) / 60;
    s %= 60;
    if (h > 0) return [NSString stringWithFormat:@"%lld:%02lld:%02lld", h, m, s];
    return [NSString stringWithFormat:@"%lld:%02lld", m, s];
}

static NSString *ReasonForStatus(NSString *s) {
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
        @"Checkmate", @"mate", @"Resignation", @"resign", @"Stalemate", @"stalemate",
        @"Time out", @"timeout", @"Time out", @"outoftime", @"Draw", @"draw",
        @"Game aborted", @"aborted", @"Game not started", @"noStart",
        @"Cheat detected", @"cheat", @"Variant ending", @"variantEnd", nil];
    return [d objectForKey:s] ?: (s ?: @"Finished");
}

static NSString *DisplayName(id player) {
    id ai = LCGet(player, @"aiLevel");
    if ([ai isKindOfClass:[NSNumber class]]) return [NSString stringWithFormat:@"Stockfish level %@", ai];
    NSString *name = LCStr(player, @"name") ?: LCStr(player, @"id") ?: @"Anonymous";
    NSString *title = LCStr(player, @"title");
    if (title.length) name = [NSString stringWithFormat:@"%@ %@", title, name];
    id rating = LCGet(player, @"rating");
    if ([rating isKindOfClass:[NSNumber class]]) name = [NSString stringWithFormat:@"%@ (%@)", name, rating];
    return name;
}

enum { TagPromotion = 1, TagResign = 2, TagDrawOffer = 3, TagInfo = 4 };

@interface GameViewController () <LCBoardViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
    NSString *_gameId, *_colorHint;
    LCBoardView *_board;
    UIView *_topBar, *_bottomBar;
    UIToolbar *_toolbar;
    UIBarButtonItem *_resignItem, *_drawItem;
    LCConnection *_stream;
    NSTimer *_timer;

    NSString *_initialFen, *_whiteName, *_blackName;
    BOOL _hasClock, _myWhite, _bottomIsWhite, _finished, _resultShown, _gotFull, _unsupported;
    BOOL _wdraw, _bdraw, _drawPromptShown;
    int _retries, _pendingFrom, _pendingTo;
    NSArray *_moves;
    long long _wtime, _btime;
    NSDate *_stamp;
    NSString *_status, *_winner;
    LCPosition _pos;
}
@end

@implementation GameViewController

- (id)initWithGameId:(NSString *)gameId colorHint:(NSString *)colorHint {
    if ((self = [super init])) {
        _gameId = [gameId copy]; _colorHint = [colorHint copy];
        _myWhite = ![colorHint isEqualToString:@"black"];
        _bottomIsWhite = _myWhite;
        _wtime = _btime = -1;
        _moves = [NSArray array];
        _status = @"started";
        LCPositionStart(&_pos);
        self.title = @"Game";
        self.hidesBottomBarWhenPushed = YES;
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
    [self.view addSubview:_topBar]; [self.view addSubview:_bottomBar];

    _board = [[LCBoardView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    _board.delegate = self;
    _board.flipped = !_myWhite;
    [self.view addSubview:_board];

    _toolbar = [[UIToolbar alloc] init];
    _toolbar.barStyle = UIBarStyleBlack;
    _resignItem = [[UIBarButtonItem alloc] initWithTitle:@"Abort" style:UIBarButtonItemStyleBordered target:self action:@selector(resignTapped)];
    _drawItem = [[UIBarButtonItem alloc] initWithTitle:@"Draw" style:UIBarButtonItemStyleBordered target:self action:@selector(drawTapped)];
    UIBarButtonItem *flip = [[UIBarButtonItem alloc] initWithTitle:@"Flip" style:UIBarButtonItemStyleBordered target:self action:@selector(flipTapped)];
    UIBarButtonItem *sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    _toolbar.items = [NSArray arrayWithObjects:_resignItem, sp, _drawItem, sp, flip, nil];
    [self.view addSubview:_toolbar];

    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateClocks) userInfo:nil repeats:YES];
    [self refreshUI];
    [self connect];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height;
    BOOL land = W > H;
    CGFloat barH = 32, tbH = LCToolbarHeight(land);
    CGFloat barW;
    if (land) {                                   // board on the left, players and clocks beside it
        CGFloat avail = H - tbH;
        CGFloat side = MIN(avail, W - 200);
        CGFloat by = floor((avail - side) / 2), px = side + 8;
        barW = W - side - 16;
        _board.frame = CGRectMake(0, by, side, side);
        _topBar.frame = CGRectMake(px, by, barW, barH);
        _bottomBar.frame = CGRectMake(px, by + side - barH, barW, barH);
    } else {
        CGFloat side = MIN(W, H - 2 * barH - tbH);
        CGFloat y0 = MAX(0, (H - tbH - (2 * barH + side)) / 2);
        CGFloat x = (W - side) / 2;
        barW = side;
        _topBar.frame = CGRectMake(x, y0, side, barH);
        _board.frame = CGRectMake(x, y0 + barH, side, side);
        _bottomBar.frame = CGRectMake(x, y0 + barH + side, side, barH);
    }
    _toolbar.frame = CGRectMake(0, H - tbH, W, tbH);
    for (UIView *bar in [NSArray arrayWithObjects:_topBar, _bottomBar, nil]) {
        [bar viewWithTag:1].frame = CGRectMake(8, 0, barW - 108, barH);
        [bar viewWithTag:2].frame = CGRectMake(barW - 98, 3, 92, barH - 6);
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self isMovingFromParentViewController]) [self shutDown];
}

- (void)shutDown {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_timer invalidate]; _timer = nil;
    [_stream cancel]; _stream = nil;
}

- (void)dealloc { [_timer invalidate]; [_stream cancel]; }

#pragma mark - Streaming

- (void)connect {
    [_stream cancel];
    _stream = [[LCClient shared] streamGame:_gameId
        onEvent:^(id e) { [self handleEvent:e]; }
        onEnd:^(NSString *err) { [self streamEnded:err]; }];
}

- (void)streamEnded:(NSString *)err {
    _stream = nil;
    if (_finished || _unsupported) return;
    if (_retries < 8) {
        _retries++;
        self.title = @"Reconnecting…";
        [self performSelector:@selector(connect) withObject:nil afterDelay:2.0];
    } else if (err) {
        [self alert:@"Connection lost" message:err tag:TagInfo];
    }
}

- (void)handleEvent:(id)e {
    _retries = 0;
    NSString *type = LCStr(e, @"type");
    if ([type isEqualToString:@"gameFull"]) {
        NSString *variant = LCStr(LCGet(e, @"variant"), @"key");
        if (variant && ![variant isEqualToString:@"standard"] && ![variant isEqualToString:@"fromPosition"]) {
            _unsupported = YES;
            [self alert:@"Unsupported variant" message:@"Only standard chess is supported in this build." tag:TagInfo];
            return;
        }
        _initialFen = LCStr(e, @"initialFen");
        id white = LCGet(e, @"white"), black = LCGet(e, @"black");
        _whiteName = DisplayName(white); _blackName = DisplayName(black);
        _hasClock = LCGet(e, @"clock") != nil;
        NSString *me = [LCClient shared].userId;
        if (me.length && [LCStr(white, @"id") isEqualToString:me]) _myWhite = YES;
        else if (me.length && [LCStr(black, @"id") isEqualToString:me]) _myWhite = NO;
        else if (_colorHint) _myWhite = [_colorHint isEqualToString:@"white"];
        if (!_gotFull) { _bottomIsWhite = _myWhite; _board.flipped = !_myWhite; }
        _gotFull = YES;
        [self applyState:LCGet(e, @"state")];
    } else if ([type isEqualToString:@"gameState"]) {
        [self applyState:e];
    }
}

- (void)applyState:(id)st {
    if (!st) return;
    NSMutableArray *moves = [NSMutableArray array];
    for (NSString *m in [(LCStr(st, @"moves") ?: @"") componentsSeparatedByString:@" "])
        if (m.length) [moves addObject:m];
    _moves = moves;

    LCPosition p;
    if (_initialFen && ![_initialFen isEqualToString:@"startpos"] && LCPositionFromFEN(&p, [_initialFen UTF8String])) {}
    else LCPositionStart(&p);
    for (NSString *m in moves) LCPositionApplyUCI(&p, [m UTF8String]);
    _pos = p;
    _board.position = p;

    id w = LCGet(st, @"wtime"), b = LCGet(st, @"btime");
    _wtime = (_hasClock && [w isKindOfClass:[NSNumber class]]) ? [w longLongValue] : -1;
    _btime = (_hasClock && [b isKindOfClass:[NSNumber class]]) ? [b longLongValue] : -1;
    _stamp = [NSDate date];

    _status = LCStr(st, @"status") ?: @"started";
    _winner = LCStr(st, @"winner");
    _wdraw = [LCGet(st, @"wdraw") boolValue];
    _bdraw = [LCGet(st, @"bdraw") boolValue];
    _finished = !([_status isEqualToString:@"started"] || [_status isEqualToString:@"created"]);

    [self refreshUI];
    if (_finished) { [self showResult]; return; }

    BOOL oppOffer = _myWhite ? _bdraw : _wdraw;
    if (!oppOffer) _drawPromptShown = NO;
    else if (!_drawPromptShown) {
        _drawPromptShown = YES;
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Draw offer" message:@"Your opponent offers a draw."
                                                   delegate:self cancelButtonTitle:@"Decline" otherButtonTitles:@"Accept", nil];
        a.tag = TagDrawOffer; [a show];
    }
}

#pragma mark - UI

- (void)refreshUI {
    BOOL myTurn = !_finished && (_pos.whiteToMove != 0) == _myWhite;
    _board.interactive = myTurn;
    if (_finished) self.title = ReasonForStatus(_status);
    else self.title = myTurn ? @"Your turn" : @"Opponent's turn";

    BOOL bw = _bottomIsWhite;
    NSString *wn = _whiteName ?: @"White", *bn = _blackName ?: @"Black";
    ((UILabel *)[_bottomBar viewWithTag:1]).text = bw ? wn : bn;
    ((UILabel *)[_topBar viewWithTag:1]).text = bw ? bn : wn;

    _resignItem.title = _moves.count < 2 ? @"Abort" : @"Resign";
    _resignItem.enabled = !_finished;
    _drawItem.enabled = !_finished && _moves.count >= 2;
    [self updateClocks];
}

- (void)updateClocks {
    long long w = _wtime, b = _btime;
    BOOL running = !_finished && _hasClock && _moves.count >= 2 && _stamp != nil;
    if (running) {
        long long el = (long long)(-[_stamp timeIntervalSinceNow] * 1000.0);
        if (_pos.whiteToMove) { if (w >= 0) w = MAX(0, w - el); }
        else { if (b >= 0) b = MAX(0, b - el); }
    }
    UILabel *wl = (UILabel *)[(_bottomIsWhite ? _bottomBar : _topBar) viewWithTag:2];
    UILabel *bl = (UILabel *)[(_bottomIsWhite ? _topBar : _bottomBar) viewWithTag:2];
    wl.text = FormatClock(w); bl.text = FormatClock(b);
    UIColor *active = [UIColor colorWithRed:0.25 green:0.5 blue:0.2 alpha:1], *idle = [UIColor colorWithWhite:0.28 alpha:1];
    wl.backgroundColor = (running && _pos.whiteToMove) ? active : idle;
    bl.backgroundColor = (running && !_pos.whiteToMove) ? active : idle;
}

- (void)alert:(NSString *)title message:(NSString *)msg tag:(int)tag {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    a.tag = tag; [a show];
}

- (void)showResult {
    if (_resultShown) return;
    _resultShown = YES;
    NSString *res = @"";
    if ([_winner isEqualToString:@"white"]) res = @"White is victorious";
    else if ([_winner isEqualToString:@"black"]) res = @"Black is victorious";
    [self alert:ReasonForStatus(_status) message:res tag:TagInfo];
}

#pragma mark - Actions

- (void)flipTapped {
    _bottomIsWhite = !_bottomIsWhite;
    _board.flipped = !_bottomIsWhite;
    [self refreshUI];
}

- (void)resignTapped {
    if (_finished) return;
    if (_moves.count < 2) {
        [[LCClient shared] abortGame:_gameId done:^(id json, NSString *err) {
            if (err) [self alert:@"Can't abort" message:err tag:TagInfo];
        }];
        return;
    }
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Resign this game?" delegate:self cancelButtonTitle:@"Cancel"
                                      destructiveButtonTitle:@"Resign" otherButtonTitles:nil];
    as.tag = TagResign;
    [as showFromToolbar:_toolbar];
}

- (void)drawTapped {
    if (_finished) return;
    [[LCClient shared] drawGame:_gameId accept:YES done:^(id json, NSString *err) {
        if (err) [self alert:@"Draw" message:err tag:TagInfo];
        else [self alert:@"Draw" message:@"Draw offer sent." tag:TagInfo];
    }];
}

- (void)boardView:(LCBoardView *)v moveFrom:(int)from to:(int)to needsPromotion:(BOOL)promo {
    if (promo) {
        _pendingFrom = from; _pendingTo = to;
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Promote to" delegate:self cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:nil otherButtonTitles:@"Queen", @"Rook", @"Bishop", @"Knight", nil];
        as.tag = TagPromotion;
        [as showFromToolbar:_toolbar];
        return;
    }
    [self sendMoveFrom:from to:to promo:0];
}

- (void)sendMoveFrom:(int)from to:(int)to promo:(char)promo {
    LCMove m; m.from = (signed char)from; m.to = (signed char)to; m.promo = promo;
    char u[6]; LCMoveToUCI(m, u);
    NSString *uci = [NSString stringWithUTF8String:u];
    LCPosition q = _pos;
    if (LCPositionApplyUCI(&q, u)) {           // optimistic update; the server echo rebuilds it anyway
        _pos = q; _board.position = q;
        [self refreshUI];
    }
    [[LCClient shared] move:uci game:_gameId done:^(id json, NSString *err) {
        if (err) {
            [self alert:@"Move rejected" message:err tag:TagInfo];
            [self connect];                    // resync from the server
        }
    }];
}

- (void)actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)idx {
    if (idx == as.cancelButtonIndex) return;
    if (as.tag == TagPromotion) {
        const char promos[4] = { 'q', 'r', 'b', 'n' };
        if (idx >= 0 && idx < 4) [self sendMoveFrom:_pendingFrom to:_pendingTo promo:promos[idx]];
    } else if (as.tag == TagResign && idx == as.destructiveButtonIndex) {
        [[LCClient shared] resignGame:_gameId done:^(id json, NSString *err) {
            if (err) [self alert:@"Can't resign" message:err tag:TagInfo];
        }];
    }
}

- (void)alertView:(UIAlertView *)av clickedButtonAtIndex:(NSInteger)idx {
    if (av.tag == TagDrawOffer)
        [[LCClient shared] drawGame:_gameId accept:(idx == 1) done:nil];
}

@end
