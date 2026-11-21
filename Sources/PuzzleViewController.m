#import "PuzzleViewController.h"
#import "LCBoardView.h"
#import "LCClient.h"
#import "LCPuzzleThemes.h"
#import "LCUtil.h"

static NSString *const kStreakBest = @"lc.streak.best";
static NSString *const kStormBest = @"lc.storm.best";
static const double kStormSeconds = 180, kStormPenalty = 10;

static BOOL IsLegalUCI(const LCPosition *p, NSString *uci) {
    LCMove mv[256];
    int n = LCLegalMoves(p, mv);
    for (int i = 0; i < n; i++) {
        char u[6]; LCMoveToUCI(mv[i], u);
        if ([uci isEqualToString:[NSString stringWithUTF8String:u]]) return YES;
    }
    return NO;
}

static NSString *ClockString(double s) {
    int t = (int)(s < 0 ? 0 : s + 0.999);
    return [NSString stringWithFormat:@"%d:%02d", t / 60, t % 60];
}

@interface PuzzleViewController () <LCBoardViewDelegate> {
    PuzzleMode _mode;
    NSString *_angle, *_puzzleId;
    LCBoardView *_board;
    UILabel *_info, *_status;
    UIButton *_btnA, *_btnB;
    UIActivityIndicatorView *_spin;

    LCPosition _pos, _originalPosition;
    NSDictionary *_current;
    NSArray *_solution;
    int _idx, _mistakes;
    BOOL _solved, _loading, _started, _dead;

    // streak / storm
    NSMutableArray *_queue;
    NSMutableSet *_seen;
    int _inflight, _failures, _score, _combo, _count;
    BOOL _running, _over, _waiting, _skipUsed;
    double _remaining;
    NSDate *_tick;
    NSTimer *_timer;
}
@end

@implementation PuzzleViewController

- (id)initWithMode:(PuzzleMode)mode angle:(NSString *)angle puzzleId:(NSString *)pid title:(NSString *)title {
    if ((self = [super init])) {
        _mode = mode; _angle = [angle copy]; _puzzleId = [pid copy];
        _queue = [NSMutableArray array]; _seen = [NSMutableSet set];
        self.hidesBottomBarWhenPushed = YES;
        if (title) self.title = title;
        else switch (mode) {
            case PuzzleModeDaily: self.title = @"Daily puzzle"; break;
            case PuzzleModeStreak: self.title = @"Puzzle Streak"; break;
            case PuzzleModeStorm: self.title = @"Puzzle Storm"; break;
            default: self.title = @"Puzzle"; break;
        }
    }
    return self;
}

#pragma mark - View

- (UILabel *)labelWithSize:(CGFloat)size {
    UILabel *l = [[UILabel alloc] init];
    l.backgroundColor = [UIColor clearColor]; l.textColor = [UIColor whiteColor];
    l.textAlignment = UITextAlignmentCenter; l.numberOfLines = 2; l.font = [UIFont boldSystemFontOfSize:size];
    return l;
}

- (UIButton *)buttonWithAction:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    _info = [self labelWithSize:14];
    _status = [self labelWithSize:15];
    _board = [[LCBoardView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    _board.delegate = self; _board.interactive = NO;
    _btnA = [self buttonWithAction:@selector(aTapped)];
    _btnB = [self buttonWithAction:@selector(bTapped)];
    _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _spin.hidesWhenStopped = YES;
    for (UIView *v in [NSArray arrayWithObjects:_info, _board, _status, _btnA, _btnB, _spin, nil]) [self.view addSubview:v];
    [self refreshButtons];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height;
    if (W > H) {                                  // landscape: board on the left, text and buttons on the right
        CGFloat side = MIN(H, W - 190);
        CGFloat by = floor((H - side) / 2), px = side + 10, pw = W - side - 20;
        _board.frame = CGRectMake(0, by, side, side);
        _info.frame = CGRectMake(px, by + 4, pw, 44);
        _status.frame = CGRectMake(px, by + 54, pw, 48);
        _btnB.frame = CGRectMake(px, by + side - 42, pw, 38);
        _btnA.frame = CGRectMake(px, by + side - 88, pw, 38);
        _spin.center = CGPointMake(px + pw / 2, by + side / 2);
        return;
    }
    CGFloat side = MIN(W, H - 36 - 44 - 46);
    _info.frame = CGRectMake(8, 2, W - 16, 34);
    _board.frame = CGRectMake((W - side) / 2, 36, side, side);
    _status.frame = CGRectMake(8, 36 + side + 2, W - 16, 40);
    _btnA.frame = CGRectMake(W / 2 - 130, 36 + side + 44, 120, 38);
    _btnB.frame = CGRectMake(W / 2 + 10, 36 + side + 44, 120, 38);
    _spin.center = CGPointMake(W / 2, 18);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_started) return;
    _started = YES;
    switch (_mode) {
        case PuzzleModeStreak: [self newStreak]; break;
        case PuzzleModeStorm: [self prepareStorm]; break;
        default: [self loadSingle]; break;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self isMovingFromParentViewController]) [self shutDown];
}

- (void)shutDown {
    _dead = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_timer invalidate]; _timer = nil;
}
- (void)dealloc { [_timer invalidate]; }

#pragma mark - Loading puzzles

- (void)loadSingle {
    if (_loading) return;
    _loading = YES; _solved = NO; _board.interactive = NO;
    [_spin startAnimating];
    _status.text = @"Loading…";
    LCResultBlock cb = ^(id json, NSString *err) {
        _loading = NO; [_spin stopAnimating];
        if (_dead) return;
        if (err) { _status.text = err; return; }
        [self setupFromJSON:json];
    };
    LCClient *c = [LCClient shared];
    if (_mode == PuzzleModeDaily) [c fetchDailyPuzzle:cb];
    else if (_mode == PuzzleModeById) [c fetchPuzzleById:_puzzleId done:cb];
    else [c fetchNextPuzzleAngle:_angle difficulty:nil done:cb];
}

// Builds the start position (replaying the PGN) and arms the board. Returns NO if the data can't be used.
- (BOOL)setupFromJSON:(id)json {
    id puzzle = LCGet(json, @"puzzle"), game = LCGet(json, @"game");
    id sol = LCGet(puzzle, @"solution");
    NSString *pgn = LCStr(game, @"pgn");
    if (![sol isKindOfClass:[NSArray class]] || [sol count] == 0 || !pgn) { _status.text = @"Unexpected puzzle data"; return NO; }

    NSMutableArray *sans = [NSMutableArray array];
    for (NSString *tok in [pgn componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        NSString *t = tok;
        NSRange dot = [t rangeOfString:@"." options:NSBackwardsSearch];
        if (dot.location != NSNotFound) t = [t substringFromIndex:dot.location + 1];   // "12.e4" -> "e4"
        if (!t.length || [t hasPrefix:@"{"] || [t hasPrefix:@"["]) continue;
        if ([t isEqualToString:@"1-0"] || [t isEqualToString:@"0-1"] || [t isEqualToString:@"1/2-1/2"] || [t isEqualToString:@"*"]) continue;
        [sans addObject:t];
    }
    id ip = LCGet(puzzle, @"initialPly");
    if ([ip isKindOfClass:[NSNumber class]] && sans.count > (NSUInteger)([ip intValue] + 1))
        [sans removeObjectsInRange:NSMakeRange([ip intValue] + 1, sans.count - [ip intValue] - 1)];

    LCPosition p;
    LCPositionStart(&p);
    for (NSString *san in sans)
        if (!LCPositionApplySAN(&p, [san UTF8String])) { _status.text = [NSString stringWithFormat:@"Can't read move “%@”", san]; return NO; }
    if (!IsLegalUCI(&p, [sol objectAtIndex:0])) { _status.text = @"Puzzle format not supported"; return NO; }

    _current = json; _solution = sol; _idx = 0; _mistakes = 0; _solved = NO;
    _pos = p; _originalPosition = p;
    _board.flipped = !p.whiteToMove;
    _board.position = p;
    _board.interactive = (_mode != PuzzleModeStorm) || _running;
    _status.text = _mode == PuzzleModeStorm ? @"" : @"Find the best move";
    [self updateInfo];
    [self refreshButtons];
    return YES;
}

- (void)updateInfo {
    NSString *side = _pos.whiteToMove ? @"White" : @"Black";
    id rating = LCGet(LCGet(_current, @"puzzle"), @"rating");
    NSString *r = [rating isKindOfClass:[NSNumber class]] ? [rating description] : @"?";
    switch (_mode) {
        case PuzzleModeStreak:
            _info.text = [NSString stringWithFormat:@"Streak %d  (best %d)\n%@ to move", _count, (int)[[NSUserDefaults standardUserDefaults] integerForKey:kStreakBest], side];
            break;
        case PuzzleModeStorm:
            _info.text = _running ? [NSString stringWithFormat:@"Score %d  •  combo %d  •  %@\n%@ to move", _score, _combo, ClockString(_remaining), side]
                                  : [NSString stringWithFormat:@"Score %d  •  %@\nbest %d", _score, ClockString(_running || _over ? _remaining : kStormSeconds), (int)[[NSUserDefaults standardUserDefaults] integerForKey:kStormBest]];
            break;
        case PuzzleModeDaily: _info.text = [NSString stringWithFormat:@"Daily puzzle • rating %@\n%@ to move", r, side]; break;
        default: _info.text = [NSString stringWithFormat:@"Rating %@\n%@ to move", r, side]; break;
    }
}

#pragma mark - Buttons

- (void)refreshButtons {
    NSString *a = nil, *b = nil; BOOL ea = YES, eb = YES;
    switch (_mode) {
        case PuzzleModeStreak:
            a = @"Skip"; ea = _running && !_over && !_skipUsed && !_waiting; b = @"New run"; break;
        case PuzzleModeStorm:
            a = _over ? @"Play again" : @"Start"; ea = !_running; b = @"Stop"; eb = _running; break;
        case PuzzleModeTheme:
            a = @"Solution"; ea = _current != nil && !_loading; b = @"Next puzzle"; eb = !_loading; break;
        default:
            a = @"Solution"; ea = _current != nil; b = @"Restart"; eb = _current != nil; break;
    }
    [_btnA setTitle:a forState:UIControlStateNormal]; _btnA.enabled = ea;
    [_btnB setTitle:b forState:UIControlStateNormal]; _btnB.enabled = eb;
}

- (void)aTapped {
    switch (_mode) {
        case PuzzleModeStreak: if (_running && !_skipUsed) { _skipUsed = YES; [self cancelAdvance]; [self presentNext]; [self refreshButtons]; } break;
        case PuzzleModeStorm: if (!_running) [self startStorm]; break;
        default: [self showSolution]; break;
    }
}

- (void)bTapped {
    switch (_mode) {
        case PuzzleModeStreak: [self newStreak]; break;
        case PuzzleModeStorm: if (_running) [self endStorm]; break;
        case PuzzleModeTheme: [self cancelAdvance]; [self loadSingle]; break;
        default: [self restart]; break;
    }
}

- (void)restart {
    if (!_current) return;
    [self cancelAdvance];
    _pos = _originalPosition; _idx = 0; _mistakes = 0; _solved = NO;
    _board.position = _pos; _board.interactive = YES;
    _status.text = @"Find the best move";
}

- (void)showSolution {
    if (!_current || _idx >= (int)_solution.count) return;
    NSArray *rest = [_solution subarrayWithRange:NSMakeRange(_idx, _solution.count - _idx)];
    _status.text = [@"Solution: " stringByAppendingString:[rest componentsJoinedByString:@" "]];
}

- (void)cancelAdvance {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(advance) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(opponentReply) object:nil];
}

#pragma mark - Move handling

- (void)boardView:(LCBoardView *)v moveFrom:(int)from to:(int)to needsPromotion:(BOOL)promo {
    if (_solved || _over || !_current || _idx >= (int)_solution.count) return;
    NSString *expected = [_solution objectAtIndex:_idx];
    NSString *base = [NSString stringWithFormat:@"%c%c%c%c", 'a' + (from & 7), '1' + (from >> 3), 'a' + (to & 7), '1' + (to >> 3)];
    BOOL match = [expected hasPrefix:base];
    NSString *uci = match ? expected : (promo ? [base stringByAppendingString:@"q"] : base);

    LCPosition q = _pos;
    LCPositionApplyUCI(&q, [uci UTF8String]);
    BOOL mate = NO;
    if (!match) {                                   // Lichess accepts any checkmating move
        LCMove tmp[256];
        mate = (LCLegalMoves(&q, tmp) == 0 && LCInCheck(&q, q.whiteToMove));
    }
    if (!match && !mate) { [self mistake]; return; }
    _pos = q; _board.position = q; _idx++;
    if (mate || _idx >= (int)_solution.count) { [self puzzleDone]; return; }
    _board.interactive = NO;
    if (_mode != PuzzleModeStorm) _status.text = @"Good move…";
    [self performSelector:@selector(opponentReply) withObject:nil afterDelay:_mode == PuzzleModeStorm ? 0.2 : 0.5];
}

- (void)opponentReply {
    if (_dead || _idx >= (int)_solution.count) return;
    LCPositionApplyUCI(&_pos, [[_solution objectAtIndex:_idx] UTF8String]);
    _board.position = _pos; _idx++;
    if (_idx >= (int)_solution.count) { [self puzzleDone]; return; }
    _board.interactive = YES;
    if (_mode != PuzzleModeStorm) _status.text = @"Your move";
    [self updateInfo];
}

- (void)mistake {
    _mistakes++;
    _board.position = _pos;                         // clears the selection
    switch (_mode) {
        case PuzzleModeStreak: [self endStreak]; break;
        case PuzzleModeStorm:
            _combo = 0; _remaining -= kStormPenalty;
            _board.interactive = NO; _status.text = @"Wrong! −10 s";
            [self updateInfo];
            if (_remaining <= 0) [self endStorm]; else [self scheduleAdvance:0.35];
            break;
        default: _status.text = @"That's not the move. Try again."; break;
    }
}

- (void)puzzleDone {
    _solved = YES; _board.interactive = NO;
    switch (_mode) {
        case PuzzleModeStreak: {
            _count++;
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            if (_count > [d integerForKey:kStreakBest]) [d setInteger:_count forKey:kStreakBest];
            _status.text = @"Correct!";
            [self updateInfo];
            [self scheduleAdvance:0.6];
            break;
        }
        case PuzzleModeStorm: {
            _score++; _count++; _combo++;
            int bonus = (_combo == 5) ? 3 : (_combo == 12) ? 5 : (_combo == 20) ? 7 : (_combo == 30) ? 10 : 0;
            _remaining += bonus;
            _status.text = bonus ? [NSString stringWithFormat:@"Combo %d! +%d s", _combo, bonus] : @"";
            [self updateInfo];
            [self scheduleAdvance:0.25];
            break;
        }
        default: {
            NSMutableArray *names = [NSMutableArray array];
            id themes = LCGet(LCGet(_current, @"puzzle"), @"themes");
            if ([themes isKindOfClass:[NSArray class]])
                for (id k in themes) if ([k isKindOfClass:[NSString class]] && names.count < 4) [names addObject:LCPuzzleThemeName(k)];
            NSString *head = _mistakes ? [NSString stringWithFormat:@"Puzzle solved (%d mistake%@)", _mistakes, _mistakes == 1 ? @"" : @"s"] : @"Puzzle solved";
            _status.text = names.count ? [NSString stringWithFormat:@"%@\n%@", head, [names componentsJoinedByString:@", "]] : head;
            break;
        }
    }
}

#pragma mark - Streak / Storm plumbing

- (NSString *)difficulty {
    static NSString *const names[] = { @"easiest", @"easier", @"normal", @"harder", @"hardest" };
    int level = (_mode == PuzzleModeStreak) ? MIN(4, _count / 3) : MIN(4, 1 + _count / 8);
    return names[level];
}

- (void)fillQueue {
    if (_dead) return;
    int target = (_mode == PuzzleModeStorm) ? 4 : 2;
    while ((int)_queue.count + _inflight < target && _failures < 4) {
        _inflight++;
        [[LCClient shared] fetchNextPuzzleAngle:nil difficulty:[self difficulty] done:^(id json, NSString *err) {
            _inflight--;
            if (_dead) return;
            if (err) {
                _failures++;
                if (_failures < 4) [self performSelector:@selector(fillQueue) withObject:nil afterDelay:1.5];
                else if (_waiting) { _waiting = NO; [_spin stopAnimating]; _status.text = err; }
                return;
            }
            NSString *pid = LCStr(LCGet(json, @"puzzle"), @"id");
            if (pid && ![_seen containsObject:pid]) { [_seen addObject:pid]; [_queue addObject:json]; _failures = 0; }
            else _failures++;
            if (_waiting && _queue.count) { _waiting = NO; [_spin stopAnimating]; [self presentNext]; }
            [self fillQueue];
        }];
    }
}

- (void)presentNext {
    if (_dead) return;
    if (_queue.count) {
        id json = [_queue objectAtIndex:0];
        [_queue removeObjectAtIndex:0];
        [self fillQueue];
        if (![self setupFromJSON:json]) [self presentNext];     // skip unusable puzzles
        return;
    }
    _waiting = YES; _board.interactive = NO;
    _status.text = @"Loading the next puzzle…";
    [_spin startAnimating];
    _failures = 0;
    [self fillQueue];
}

- (void)scheduleAdvance:(NSTimeInterval)d { [self performSelector:@selector(advance) withObject:nil afterDelay:d]; }

- (void)advance {
    if (_dead || !_running || _over) return;
    [self presentNext];
}

#pragma mark Streak

- (void)newStreak {
    [self cancelAdvance];
    _running = YES; _over = NO; _skipUsed = NO; _count = 0; _failures = 0; _waiting = NO;
    [_queue removeAllObjects]; [_seen removeAllObjects];
    _current = nil;
    [self refreshButtons];
    [self presentNext];
}

- (void)endStreak {
    _running = NO; _over = YES; _board.interactive = NO;
    [self cancelAdvance];
    BOOL best = _count >= [[NSUserDefaults standardUserDefaults] integerForKey:kStreakBest] && _count > 0;
    NSString *sol = (_idx < (int)_solution.count) ? [_solution objectAtIndex:_idx] : nil;
    _status.text = [NSString stringWithFormat:@"Wrong move. Streak: %d%@%@", _count, best ? @" (best!)" : @"", sol ? [@"\nCorrect: " stringByAppendingString:sol] : @""];
    [self updateInfo];
    [self refreshButtons];
}

#pragma mark Storm

- (void)prepareStorm {
    _running = NO; _over = NO; _score = 0; _combo = 0; _count = 0; _remaining = kStormSeconds; _failures = 0;
    [self fillQueue];                               // prefetch while the player gets ready
    _current = nil;
    _status.text = @"3 minutes. Solve as many puzzles as you can.\nWrong move: −10 seconds.";
    [self updateInfo];
    [self refreshButtons];
}

- (void)startStorm {
    [self cancelAdvance];
    if (_over) {                                    // play again
        [_queue removeAllObjects]; [_seen removeAllObjects]; _failures = 0;
    }
    _running = YES; _over = NO; _score = 0; _combo = 0; _count = 0; _remaining = kStormSeconds; _waiting = NO;
    _tick = [NSDate date];
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(stormTick) userInfo:nil repeats:YES];
    [self refreshButtons];
    [self presentNext];
}

- (void)stormTick {
    if (!_running) return;
    NSDate *now = [NSDate date];
    _remaining -= [now timeIntervalSinceDate:_tick];
    _tick = now;
    if (_remaining <= 0) { _remaining = 0; [self endStorm]; return; }
    [self updateInfo];
}

- (void)endStorm {
    _running = NO; _over = YES; _board.interactive = NO; _waiting = NO;
    [_spin stopAnimating];
    [_timer invalidate]; _timer = nil;
    [self cancelAdvance];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL best = _score > [d integerForKey:kStormBest];
    if (best) [d setInteger:_score forKey:kStormBest];
    _status.text = [NSString stringWithFormat:@"%@ Score: %d", best && _score > 0 ? @"New best!" : @"Time's up!", _score];
    [self updateInfo];
    [self refreshButtons];
}

@end
