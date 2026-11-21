#import "ClockViewController.h"
#import "LCUtil.h"
#import <AudioToolbox/AudioToolbox.h>
#import "ClockSettingsViewController.h"

enum { StateIdle, StateRunning, StatePaused, StateFlagged };

static NSString *FormatTime(double s) {
    if (s <= 0) return @"0:00";
    if (s < 10) return [NSString stringWithFormat:@"0:%04.1f", floor(s * 10) / 10];
    int t = (int)ceil(s), h = t / 3600, m = (t % 3600) / 60, sec = t % 60;
    if (h > 0) return [NSString stringWithFormat:@"%d:%02d:%02d", h, m, sec];
    return [NSString stringWithFormat:@"%d:%02d", m, sec];
}

@interface ClockViewController () {
    NSArray *_panes;                    // [top, bottom]
    UIToolbar *_bar;
    UIBarButtonItem *_playPause;
    NSTimer *_timer;
    int _state, _active;                // _active: 0 = top, 1 = bottom, -1 = none
    double _remaining[2];
    int _moves[2];
    double _initial, _increment;
    NSDate *_lastTick;
}
@end

@implementation ClockViewController

- (id)init {
    if ((self = [super init])) {
        self.title = @"Clock";
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (UIControl *)makePane:(int)tag {
    UIControl *p = [[UIControl alloc] init];
    p.tag = tag;
    [p addTarget:self action:@selector(paneTapped:) forControlEvents:UIControlEventTouchDown];
    UILabel *time = [[UILabel alloc] init];
    time.tag = 101; time.backgroundColor = [UIColor clearColor]; time.textColor = [UIColor whiteColor];
    time.textAlignment = UITextAlignmentCenter; time.adjustsFontSizeToFitWidth = YES; time.minimumFontSize = 24;
    time.userInteractionEnabled = NO;
    UILabel *sub = [[UILabel alloc] init];
    sub.tag = 102; sub.backgroundColor = [UIColor clearColor]; sub.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    sub.textAlignment = UITextAlignmentCenter; sub.font = [UIFont systemFontOfSize:16];
    sub.userInteractionEnabled = NO;
    [p addSubview:time]; [p addSubview:sub];
    return p;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    UIControl *top = [self makePane:0], *bottom = [self makePane:1];
    top.transform = CGAffineTransformMakeRotation(M_PI);          // the opponent reads it from the other side
    _panes = [NSArray arrayWithObjects:top, bottom, nil];
    [self.view addSubview:top]; [self.view addSubview:bottom];

    _bar = [[UIToolbar alloc] init];
    _bar.barStyle = UIBarStyleBlack;
    [self.view addSubview:_bar];
    self.navigationItem.rightBarButtonItem = nil;

    [self loadSettingsAndReset];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appInactive) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)dealloc {
    [_timer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;     // keep the screen on while the clock is open
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (_state == StateRunning) { [self advance]; _state = StatePaused; [self refresh]; }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewDidLayoutSubviews {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height, barH = LCToolbarHeight(W > H);
    CGFloat ph = floor((H - barH) / 2);
    UIControl *top = [_panes objectAtIndex:0], *bottom = [_panes objectAtIndex:1];
    top.bounds = CGRectMake(0, 0, W, ph);                          // bounds + center: the view is rotated, so no frame
    top.center = CGPointMake(W / 2, ph / 2);
    bottom.frame = CGRectMake(0, ph + barH, W, H - ph - barH);
    _bar.frame = CGRectMake(0, ph, W, barH);
    for (UIControl *p in _panes) {
        CGFloat h = p.bounds.size.height;
        UILabel *time = (UILabel *)[p viewWithTag:101], *sub = (UILabel *)[p viewWithTag:102];
        time.font = [UIFont fontWithName:@"Courier-Bold" size:floor(h * 0.42)];
        time.frame = CGRectMake(8, h * 0.14, W - 16, h * 0.55);
        sub.frame = CGRectMake(8, h * 0.74, W - 16, 24);
    }
}

#pragma mark - State

- (void)loadSettingsAndReset {
    _initial = [ClockSettingsViewController savedMinutes] * 60.0;
    _increment = [ClockSettingsViewController savedIncrement];
    _state = StateIdle; _active = -1;
    _remaining[0] = _remaining[1] = _initial;
    _moves[0] = _moves[1] = 0;
    [self refresh];
}

- (void)advance {                                                  // charge the running side for the time since the last tick
    NSDate *now = [NSDate date];
    if (_state == StateRunning && _active >= 0 && _lastTick) _remaining[_active] -= [now timeIntervalSinceDate:_lastTick];
    _lastTick = now;
}

- (void)tick {
    if (_state != StateRunning) return;
    [self advance];
    if (_remaining[_active] <= 0) {
        _remaining[_active] = 0;
        _state = StateFlagged;
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        [self refresh];                                            // flagged: the buttons change too
        return;
    }
    [self refreshPanes];
}

- (void)appInactive { if (_state == StateRunning) { [self advance]; _state = StatePaused; [self refresh]; } }   // never lose time to the background

- (void)paneTapped:(UIControl *)pane {
    int i = (int)pane.tag;
    if (_state == StateIdle) {                                     // "I've moved": the other side's clock starts
        _moves[i]++; _active = 1 - i; _state = StateRunning; _lastTick = [NSDate date];
    } else if (_state == StateRunning && i == _active) {
        [self advance];
        _remaining[i] += _increment;
        _moves[i]++;
        _active = 1 - i;
    } else return;
    [self refresh];
}

- (void)playPauseTapped {
    if (_state == StateRunning) { [self advance]; _state = StatePaused; }
    else if (_state == StatePaused) { _lastTick = [NSDate date]; _state = StateRunning; }
    else if (_state == StateIdle) { _active = 1; _state = StateRunning; _lastTick = [NSDate date]; }   // the bottom player starts
    [self refresh];
}

- (void)resetTapped { [self loadSettingsAndReset]; }

- (void)settingsTapped {
    if (_state == StateRunning) { [self advance]; _state = StatePaused; }
    ClockSettingsViewController *vc = [[ClockSettingsViewController alloc] init];
    vc.onChange = ^{ [self loadSettingsAndReset]; };
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UI

- (void)refresh { [self refreshPanes]; [self refreshBar]; }

- (void)refreshPanes {
    UIColor *idle = [UIColor colorWithWhite:0.18 alpha:1], *active = [UIColor colorWithRed:0.25 green:0.52 blue:0.22 alpha:1],
            *flagged = [UIColor colorWithRed:0.72 green:0.16 blue:0.12 alpha:1], *paused = [UIColor colorWithRed:0.45 green:0.40 blue:0.15 alpha:1];
    for (int i = 0; i < 2; i++) {
        UIControl *p = [_panes objectAtIndex:i];
        UIColor *bg = idle;
        if (_state == StateFlagged) bg = (i == _active) ? flagged : idle;
        else if (_state == StateRunning && i == _active) bg = active;
        else if (_state == StatePaused && i == _active) bg = paused;
        p.backgroundColor = bg;
        ((UILabel *)[p viewWithTag:101]).text = FormatTime(_remaining[i]);
        ((UILabel *)[p viewWithTag:102]).text = [NSString stringWithFormat:@"Moves: %d%@", _moves[i], _increment > 0 ? [NSString stringWithFormat:@"   +%gs", _increment] : @""];
    }
}

- (void)refreshBar {
    UIBarButtonItem *reset = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStyleBordered target:self action:@selector(resetTapped)];
    UIBarButtonItem *settings = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStyleBordered target:self action:@selector(settingsTapped)];
    _playPause = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(_state == StateRunning ? UIBarButtonSystemItemPause : UIBarButtonSystemItemPlay)
                                                               target:self action:@selector(playPauseTapped)];
    _playPause.enabled = (_state != StateFlagged);
    UIBarButtonItem *sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    _bar.items = [NSArray arrayWithObjects:reset, sp, _playPause, sp, settings, nil];
}

@end
