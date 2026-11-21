#import "LocalGameViewController.h"
#import "LCBoardView.h"
#import "LCEngine.h"
#import "LCUtil.h"

typedef struct { LCPosition pos; int halfmove; long long wtime, btime; } LGSnap;

static NSString *const kSaveKey = @"lc.localgame";
enum { LGTagPromotion = 1, LGTagResign = 2, LGTagDraw = 3, LGTagInfo = 4 };

static NSString *LGClock(long long ms) {
    if (ms < 0) return @"--:--";
    if (ms < 10000) return [NSString stringWithFormat:@"0:%04.1f", ms / 1000.0];
    long long s = ms / 1000, h = s / 3600, m = (s % 3600) / 60; s %= 60;
    if (h > 0) return [NSString stringWithFormat:@"%lld:%02lld:%02lld", h, m, s];
    return [NSString stringWithFormat:@"%lld:%02lld", m, s];
}

static BOOL LGMoveFromUCI(const LCPosition *p, NSString *uci, LCMove *out) {
    LCMove mv[256];
    int n = LCLegalMoves(p, mv);
    for (int i = 0; i < n; i++) {
        char u[6]; LCMoveToUCI(mv[i], u);
        if ([uci isEqualToString:[NSString stringWithUTF8String:u]]) { *out = mv[i]; return YES; }
    }
    return NO;
}

@interface LocalGameViewController () <LCBoardViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
    NSDictionary *_cfg;
    NSArray *_savedMoves;
    long long _savedW, _savedB;
    BOOL _engine, _clock, _humanWhite, _finished, _thinking, _paused, _bottomIsWhite;
    BOOL _startWhite;                      // side to move in the initial position (differs from White when started from a FEN)
    int _level, _halfmove, _serial, _pendFrom, _pendTo;
    double _incMs, _initialMs;
    long long _wtime, _btime;
    NSDate *_lastTick;
    LCPosition _pos;
    NSMutableArray *_moves, *_sans, *_snaps, *_keys;
    NSString *_resultTitle, *_whiteName, *_blackName;

    LCBoardView *_board;
    UIView *_topBar, *_bottomBar;
    UITextView *_movesView;
    UIToolbar *_toolbar;
    UIBarButtonItem *_undoItem, *_drawItem, *_resignItem;
    NSTimer *_timer;
}
@end

@implementation LocalGameViewController

+ (NSDictionary *)savedGame {
    id d = [[NSUserDefaults standardUserDefaults] objectForKey:kSaveKey];
    return [d isKindOfClass:[NSDictionary class]] ? d : nil;
}
+ (void)clearSavedGame { [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSaveKey]; }

- (void)readConfig {
    _engine = [LCStr(_cfg, @"opponent") isEqualToString:@"engine"];
    _clock = [LCGet(_cfg, @"clock") boolValue];
    _initialMs = [LCGet(_cfg, @"minutes") doubleValue] * 60000.0;
    _incMs = [LCGet(_cfg, @"increment") intValue] * 1000.0;
    _level = [LCGet(_cfg, @"level") intValue];
    if (_level < 1) _level = 3;
    if (_clock && _initialMs <= 0) _clock = NO;
    _whiteName = _engine ? (_humanWhite ? @"You" : [NSString stringWithFormat:@"Computer (level %d)", _level]) : @"White";
    _blackName = _engine ? (_humanWhite ? [NSString stringWithFormat:@"Computer (level %d)", _level] : @"You") : @"Black";
}

- (id)initWithConfig:(NSDictionary *)cfg {
    if ((self = [super init])) {
        _cfg = [cfg copy];
        NSString *col = LCStr(cfg, @"color");
        _humanWhite = [col isEqualToString:@"white"] ? YES : ([col isEqualToString:@"black"] ? NO : (rand() % 2 == 0));
        [self readConfig];
        self.title = _engine ? @"Computer" : @"Two players";
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (id)initWithSavedGame:(NSDictionary *)saved {
    if ((self = [super init])) {
        _cfg = [saved copy];
        _humanWhite = [LCGet(saved, @"humanWhite") boolValue];
        id mv = LCGet(saved, @"moves");
        _savedMoves = [mv isKindOfClass:[NSArray class]] ? mv : [NSArray array];
        _savedW = [LCGet(saved, @"wtime") longLongValue];
        _savedB = [LCGet(saved, @"btime") longLongValue];
        [self readConfig];
        self.title = _engine ? @"Computer" : @"Two players";
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

#pragma mark - View

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
    _board.delegate = self;
    _movesView = [[UITextView alloc] init];
    _movesView.editable = NO; _movesView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    _movesView.textColor = [UIColor colorWithWhite:0.85 alpha:1]; _movesView.font = [UIFont systemFontOfSize:13];
    _toolbar = [[UIToolbar alloc] init];
    _toolbar.barStyle = UIBarStyleBlack;
    _undoItem = [[UIBarButtonItem alloc] initWithTitle:@"Undo" style:UIBarButtonItemStyleBordered target:self action:@selector(undoTapped)];
    UIBarButtonItem *flip = [[UIBarButtonItem alloc] initWithTitle:@"Flip" style:UIBarButtonItemStyleBordered target:self action:@selector(flipTapped)];
    _drawItem = [[UIBarButtonItem alloc] initWithTitle:@"Draw" style:UIBarButtonItemStyleBordered target:self action:@selector(drawTapped)];
    _resignItem = [[UIBarButtonItem alloc] initWithTitle:@"Resign" style:UIBarButtonItemStyleBordered target:self action:@selector(resignTapped)];
    UIBarButtonItem *sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    _toolbar.items = [NSArray arrayWithObjects:_undoItem, sp, flip, sp, _drawItem, sp, _resignItem, nil];
    for (UIView *v in [NSArray arrayWithObjects:_topBar, _board, _bottomBar, _movesView, _toolbar, nil]) [self.view addSubview:v];

    _moves = [NSMutableArray array]; _sans = [NSMutableArray array];
    _snaps = [NSMutableArray array]; _keys = [NSMutableArray array];
    NSString *startFEN = LCStr(_cfg, @"fen");
    if (!(startFEN.length && LCPositionFromFEN(&_pos, [startFEN UTF8String]))) LCPositionStart(&_pos);
    _startWhite = _pos.whiteToMove != 0;
    _halfmove = 0;
    _wtime = _btime = _clock ? (long long)_initialMs : -1;
    [self pushSnapshot];

    if (_savedMoves) {
        for (NSString *u in _savedMoves) {
            LCMove m;
            if (!LGMoveFromUCI(&_pos, u, &m)) break;
            [self applyMove:m];
        }
        if (_clock) {
            _wtime = _savedW; _btime = _savedB;
            LGSnap s; [[_snaps lastObject] getBytes:&s length:sizeof s];
            s.wtime = _wtime; s.btime = _btime;
            [_snaps replaceObjectAtIndex:_snaps.count - 1 withObject:[NSData dataWithBytes:&s length:sizeof s]];
        }
        _board.position = _pos;
        [self updateMovesText];
    }
    _bottomIsWhite = _engine ? _humanWhite : YES;
    _board.flipped = !_bottomIsWhite;
    _lastTick = [NSDate date];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appInactive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self refreshUI];
    [self scheduleEngineIfNeeded];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height;
    BOOL land = W > H;
    CGFloat barH = 32, movesH = 40, tbH = LCToolbarHeight(land);
    CGFloat barW;
    if (land) {                                   // board on the left; players, clocks and the move list beside it
        CGFloat avail = H - tbH;
        CGFloat side = MIN(avail, W - 200);
        CGFloat by = floor((avail - side) / 2), px = side + 8;
        barW = W - side - 16;
        _board.frame = CGRectMake(0, by, side, side);
        _topBar.frame = CGRectMake(px, by, barW, barH);
        _bottomBar.frame = CGRectMake(px, by + side - barH, barW, barH);
        _movesView.frame = CGRectMake(px, by + barH + 6, barW, MAX(0, side - 2 * barH - 12));
    } else {
        CGFloat side = MIN(W, H - 2 * barH - movesH - tbH);
        CGFloat y0 = MAX(0, (H - tbH - (2 * barH + side + movesH)) / 2), x = (W - side) / 2;
        barW = side;
        _topBar.frame = CGRectMake(x, y0, side, barH);
        _board.frame = CGRectMake(x, y0 + barH, side, side);
        _bottomBar.frame = CGRectMake(x, y0 + barH + side, side, barH);
        _movesView.frame = CGRectMake(0, y0 + 2 * barH + side, W, movesH);
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
    [self advanceClock];
    [self save];
    _serial++; _thinking = NO;
    [_timer invalidate]; _timer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    [_timer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appInactive { [self advanceClock]; _paused = YES; [self save]; }
- (void)appActive { _paused = NO; _lastTick = [NSDate date]; }

#pragma mark - Game state

- (void)pushSnapshot {
    LGSnap s; memset(&s, 0, sizeof s);
    s.pos = _pos; s.halfmove = _halfmove; s.wtime = _wtime; s.btime = _btime;
    [_snaps addObject:[NSData dataWithBytes:&s length:sizeof s]];
    char key[80]; LCPositionKey(&_pos, key);
    [_keys addObject:[NSString stringWithUTF8String:key]];
}

// Bookkeeping for one move (no clock handling). Pushes a snapshot with the current clock values.
- (void)applyMove:(LCMove)m {
    char u[6]; LCMoveToUCI(m, u);
    char san[16]; LCMoveToSAN(&_pos, m, san);
    char pc = _pos.board[(int)m.from];
    BOOL pawn = (pc == 'P' || pc == 'p');
    BOOL cap = _pos.board[(int)m.to] != 0 || (pawn && m.to == _pos.ep && (m.from & 7) != (m.to & 7));
    _halfmove = (pawn || cap) ? 0 : _halfmove + 1;
    LCPositionMakeMove(&_pos, m);
    [_moves addObject:[NSString stringWithUTF8String:u]];
    [_sans addObject:[NSString stringWithUTF8String:san]];
    [self pushSnapshot];
}

- (void)advanceClock {
    NSDate *now = [NSDate date];
    BOOL running = _clock && !_finished && !_paused && _moves.count >= 1 && _lastTick != nil;
    if (running) {
        long long dt = (long long)([now timeIntervalSinceDate:_lastTick] * 1000.0);
        if (_pos.whiteToMove) _wtime -= dt; else _btime -= dt;
    }
    _lastTick = now;
}

- (NSString *)winMessage:(BOOL)whiteWins {
    if (_engine) return whiteWins == _humanWhite ? @"You win!" : @"The computer wins";
    return whiteWins ? @"White wins" : @"Black wins";
}

- (void)finishWithTitle:(NSString *)title message:(NSString *)msg {
    if (_finished) return;
    _finished = YES; _resultTitle = title; _thinking = NO; _serial++;
    [LocalGameViewController clearSavedGame];
    [self refreshUI];
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    a.tag = LGTagInfo; [a show];
}

- (BOOL)checkEnd {
    LCMove tmp[256];
    if (LCLegalMoves(&_pos, tmp) == 0) {
        if (LCInCheck(&_pos, _pos.whiteToMove)) [self finishWithTitle:@"Checkmate" message:[self winMessage:!_pos.whiteToMove]];
        else [self finishWithTitle:@"Stalemate" message:@"Draw"];
        return YES;
    }
    if (LCInsufficientMaterial(&_pos)) { [self finishWithTitle:@"Draw" message:@"Insufficient material"]; return YES; }
    if (_halfmove >= 100) { [self finishWithTitle:@"Draw" message:@"Fifty-move rule"]; return YES; }
    NSString *cur = [_keys lastObject];
    int count = 0;
    for (NSString *k in _keys) if ([k isEqualToString:cur]) count++;
    if (count >= 3) { [self finishWithTitle:@"Draw" message:@"Threefold repetition"]; return YES; }
    return NO;
}

- (void)commitMove:(LCMove)m {
    [self advanceClock];
    BOOL whiteMoved = _pos.whiteToMove;
    if (_clock) { if (whiteMoved) _wtime += (long long)_incMs; else _btime += (long long)_incMs; }
    [self applyMove:m];
    _board.position = _pos;
    [self updateMovesText];
    [self save];
    if (![self checkEnd]) { [self refreshUI]; [self scheduleEngineIfNeeded]; }
}

- (void)scheduleEngineIfNeeded {
    if (!_engine || _finished || _thinking) return;
    if ((_pos.whiteToMove != 0) == _humanWhite) return;
    _thinking = YES;
    int serial = ++_serial, level = _level;
    LCPosition snap = _pos;
    [self refreshUI];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LCMove m;
        int ok = LCEngineBestMove(&snap, level, &m);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (serial != _serial) return;           // undone / finished / left the screen meanwhile
            _thinking = NO;
            if (ok) [self commitMove:m]; else [self checkEnd];
        });
    });
}

- (void)timerTick {
    [self advanceClock];
    if (_clock && !_finished && _moves.count >= 1) {
        if (_pos.whiteToMove && _wtime <= 0) { _wtime = 0; [self finishWithTitle:@"Time out" message:[self winMessage:NO]]; return; }
        if (!_pos.whiteToMove && _btime <= 0) { _btime = 0; [self finishWithTitle:@"Time out" message:[self winMessage:YES]]; return; }
    }
    [self updateClocks];
}

- (void)save {
    if (_finished || _moves.count == 0) return;
    NSMutableDictionary *d = [_cfg mutableCopy];
    [d setObject:[NSNumber numberWithBool:_humanWhite] forKey:@"humanWhite"];
    [d setObject:[_moves copy] forKey:@"moves"];
    [d setObject:[NSNumber numberWithLongLong:_wtime] forKey:@"wtime"];
    [d setObject:[NSNumber numberWithLongLong:_btime] forKey:@"btime"];
    [[NSUserDefaults standardUserDefaults] setObject:d forKey:kSaveKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - UI

- (void)updateMovesText {
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < _sans.count; i++) {
        NSUInteger ply = i + (_startWhite ? 0 : 1);        // black to move first: "1... e5"
        if (ply % 2 == 0) [s appendFormat:@"%lu. ", (unsigned long)(ply / 2 + 1)];
        else if (i == 0) [s appendFormat:@"%lu… ", (unsigned long)(ply / 2 + 1)];
        [s appendFormat:@"%@ ", [_sans objectAtIndex:i]];
    }
    _movesView.text = s;
    if (s.length) [_movesView scrollRangeToVisible:NSMakeRange(s.length - 1, 1)];
}

- (int)pliesToUndo {
    if (_moves.count == 0) return 0;
    int p = 1;
    if (_engine) p = ((_pos.whiteToMove != 0) == _humanWhite) ? 2 : 1;
    int remaining = (int)_moves.count - p, minRemain = (_engine && _startWhite != _humanWhite) ? 1 : 0;
    return remaining < minRemain ? 0 : p;
}

- (void)refreshUI {
    NSString *t;
    if (_finished) t = _resultTitle;
    else if (_thinking) t = @"Computer is thinking…";
    else if (_engine) t = @"Your move";
    else t = _pos.whiteToMove ? @"White to move" : @"Black to move";
    if (!_finished && !_thinking && LCInCheck(&_pos, _pos.whiteToMove)) t = [t stringByAppendingString:@" (check)"];
    self.title = t;
    _board.interactive = !_finished && !_thinking && (!_engine || (_pos.whiteToMove != 0) == _humanWhite);
    ((UILabel *)[_bottomBar viewWithTag:1]).text = _bottomIsWhite ? _whiteName : _blackName;
    ((UILabel *)[_topBar viewWithTag:1]).text = _bottomIsWhite ? _blackName : _whiteName;
    _undoItem.enabled = [self pliesToUndo] > 0;
    _drawItem.enabled = !_engine && !_finished;
    _resignItem.enabled = !_finished;
    [self updateClocks];
}

- (void)updateClocks {
    BOOL running = _clock && !_finished && _moves.count >= 1;
    UILabel *wl = (UILabel *)[(_bottomIsWhite ? _bottomBar : _topBar) viewWithTag:2];
    UILabel *bl = (UILabel *)[(_bottomIsWhite ? _topBar : _bottomBar) viewWithTag:2];
    wl.text = LGClock(_clock ? MAX(0, _wtime) : -1);
    bl.text = LGClock(_clock ? MAX(0, _btime) : -1);
    UIColor *active = [UIColor colorWithRed:0.25 green:0.5 blue:0.2 alpha:1], *idle = [UIColor colorWithWhite:0.28 alpha:1];
    wl.backgroundColor = (running && _pos.whiteToMove) ? active : idle;
    bl.backgroundColor = (running && !_pos.whiteToMove) ? active : idle;
}

#pragma mark - Actions

- (void)flipTapped {
    _bottomIsWhite = !_bottomIsWhite;
    _board.flipped = !_bottomIsWhite;
    [self refreshUI];
}

- (void)undoTapped {
    int p = [self pliesToUndo];
    if (!p) return;
    [self advanceClock];
    _serial++; _thinking = NO; _finished = NO; _resultTitle = nil;
    int idx = (int)_moves.count - p;
    LGSnap s; [[_snaps objectAtIndex:idx] getBytes:&s length:sizeof s];
    [_moves removeObjectsInRange:NSMakeRange(idx, _moves.count - idx)];
    [_sans removeObjectsInRange:NSMakeRange(idx, _sans.count - idx)];
    [_snaps removeObjectsInRange:NSMakeRange(idx + 1, _snaps.count - idx - 1)];
    [_keys removeObjectsInRange:NSMakeRange(idx + 1, _keys.count - idx - 1)];
    _pos = s.pos; _halfmove = s.halfmove; _wtime = s.wtime; _btime = s.btime;
    _lastTick = [NSDate date];
    _board.position = _pos;
    [self updateMovesText];
    [self save];
    [self refreshUI];
    [self scheduleEngineIfNeeded];
}

- (void)drawTapped {
    if (_finished || _engine) return;
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Draw" message:@"Do both players agree to a draw?" delegate:self
                                      cancelButtonTitle:@"No" otherButtonTitles:@"Yes, draw", nil];
    a.tag = LGTagDraw; [a show];
}

- (void)resignTapped {
    if (_finished) return;
    UIActionSheet *as;
    if (_engine)
        as = [[UIActionSheet alloc] initWithTitle:@"Resign this game?" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Resign" otherButtonTitles:nil];
    else
        as = [[UIActionSheet alloc] initWithTitle:@"Who resigns?" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"White resigns", @"Black resigns", nil];
    as.tag = LGTagResign;
    [as showFromToolbar:_toolbar];
}

- (void)boardView:(LCBoardView *)v moveFrom:(int)from to:(int)to needsPromotion:(BOOL)promo {
    if (promo) {
        _pendFrom = from; _pendTo = to;
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Promote to" delegate:self cancelButtonTitle:@"Cancel"
                                          destructiveButtonTitle:nil otherButtonTitles:@"Queen", @"Rook", @"Bishop", @"Knight", nil];
        as.tag = LGTagPromotion;
        [as showFromToolbar:_toolbar];
        return;
    }
    [self humanMoveFrom:from to:to promo:0];
}

- (void)humanMoveFrom:(int)from to:(int)to promo:(char)promo {
    LCMove m; m.from = (signed char)from; m.to = (signed char)to; m.promo = promo;
    [self commitMove:m];
}

- (void)actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)idx {
    if (idx == as.cancelButtonIndex) return;
    if (as.tag == LGTagPromotion) {
        const char promos[4] = { 'q', 'r', 'b', 'n' };
        if (idx >= 0 && idx < 4) [self humanMoveFrom:_pendFrom to:_pendTo promo:promos[idx]];
    } else if (as.tag == LGTagResign) {
        BOOL whiteResigns;
        if (_engine) whiteResigns = _humanWhite; else whiteResigns = (idx == 0);
        [self advanceClock];
        [self finishWithTitle:@"Resignation" message:[self winMessage:!whiteResigns]];
    }
}

- (void)alertView:(UIAlertView *)av clickedButtonAtIndex:(NSInteger)idx {
    if (av.tag == LGTagDraw && idx != av.cancelButtonIndex) [self finishWithTitle:@"Draw" message:@"Draw by agreement"];
}

@end
