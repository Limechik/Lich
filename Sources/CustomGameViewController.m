#import "CustomGameViewController.h"
#import "LCSegmentCell.h"
#import "LCUtil.h"

static const double kMinutes[] = { 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20, 25, 30, 45, 60, 90, 120, 180 };
static const int kMinCount = 23;
static const int kIncs[] = { 0, 1, 2, 3, 4, 5, 6, 7, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180 };
static const int kIncCount = 18;

enum { ModeOnline = 0, ModeLichessAI = 1, ModeOfflineAI = 2, ModeTwoPlayers = 3 };
enum { RMode, RClock, RMinutes, RInc, RType, RRated, RColour, RLevel, RStart };

static NSString *MinutesText(double m) {
    if (m == 0.25) return @"¼ min";
    if (m == 0.5) return @"½ min";
    if (m == 0.75) return @"¾ min";
    if (m == (int)m) return [NSString stringWithFormat:@"%d min", (int)m];
    return [NSString stringWithFormat:@"%g min", m];
}

static NSString *Classify(double minutes, int inc) {
    double est = minutes * 60 + 40 * inc;
    if (est < 30) return @"UltraBullet";
    if (est < 180) return @"Bullet";
    if (est < 480) return @"Blitz";
    if (est < 1500) return @"Rapid";
    return @"Classical";
}

@interface CustomGameViewController () {
    BOOL _guest, _useClock, _rated;
    int _mode, _minIdx, _incIdx, _colorIdx, _level;
    NSArray *_layout;      // [ {header, [row ids]} ]
    UILabel *_minLabel, *_incLabel, *_typeLabel, *_levelLabel;
}
@end

@implementation CustomGameViewController

- (id)initAsGuest:(BOOL)guest {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _guest = guest;
        self.title = @"Custom game";
        _mode = guest ? ModeOfflineAI : ModeOnline;
        _useClock = YES; _rated = NO;
        _minIdx = 12; _incIdx = 0;      // 10 min + 0
        _colorIdx = 0; _level = 3;
        [self rebuildLayout];
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

#pragma mark - Layout model

static NSArray *Rows(int first, ...) {
    NSMutableArray *a = [NSMutableArray array];
    va_list args; va_start(args, first);
    for (int r = first; r >= 0; r = va_arg(args, int)) [a addObject:[NSNumber numberWithInt:r]];
    va_end(args);
    return a;
}

- (void)rebuildLayout {
    NSMutableArray *sections = [NSMutableArray array];
    [sections addObject:[NSArray arrayWithObjects:@"Opponent", Rows(RMode, -1), nil]];

    NSMutableArray *time = [NSMutableArray array];
    BOOL clockChoice = (_mode != ModeOnline);                 // online pairing always needs a clock
    if (clockChoice) [time addObject:[NSNumber numberWithInt:RClock]];
    if (_useClock || !clockChoice) {
        [time addObject:[NSNumber numberWithInt:RMinutes]];
        [time addObject:[NSNumber numberWithInt:RInc]];
        [time addObject:[NSNumber numberWithInt:RType]];
    }
    [sections addObject:[NSArray arrayWithObjects:@"Time control", time, nil]];

    NSMutableArray *opts = [NSMutableArray array];
    if (_mode == ModeOnline) [opts addObject:[NSNumber numberWithInt:RRated]];
    if (_mode != ModeTwoPlayers && !(_mode == ModeOnline && _rated)) [opts addObject:[NSNumber numberWithInt:RColour]];
    if (_mode == ModeLichessAI || _mode == ModeOfflineAI) [opts addObject:[NSNumber numberWithInt:RLevel]];
    if (opts.count) [sections addObject:[NSArray arrayWithObjects:@"Options", opts, nil]];

    [sections addObject:[NSArray arrayWithObjects:@"", Rows(RStart, -1), nil]];
    _layout = sections;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _layout.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[[_layout objectAtIndex:s] objectAtIndex:1] count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    NSString *h = [[_layout objectAtIndex:s] objectAtIndex:0];
    return h.length ? h : nil;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    NSString *h = [[_layout objectAtIndex:s] objectAtIndex:0];
    if ([h isEqualToString:@"Opponent"]) {
        switch (_mode) {
            case ModeOnline: return @"A real player on lichess.org. Needs an account. Pairing allows rapid and classical only.";
            case ModeLichessAI: return @"Stockfish on lichess.org. Needs an account and internet; any time control.";
            case ModeOfflineAI: return @"Built-in engine, works without internet.";
            default: return @"Pass and play on this device, works without internet.";
        }
    }
    return nil;
}

#pragma mark - Cells

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    int row = [[[[_layout objectAtIndex:ip.section] objectAtIndex:1] objectAtIndex:ip.row] intValue];
    BOOL segmented = (row == RMode || row == RColour);
    UITableViewCell *cell = [[(segmented ? [LCSegmentCell class] : [UITableViewCell class]) alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    switch (row) {
        case RMode: {
            NSArray *items = _guest ? [NSArray arrayWithObjects:@"Offline AI", @"2 players", nil]
                                    : [NSArray arrayWithObjects:@"Online", @"Lichess AI", @"Offline AI", @"2 players", nil];
            UISegmentedControl *sc = [[UISegmentedControl alloc] initWithItems:items];
            sc.selectedSegmentIndex = _guest ? _mode - ModeOfflineAI : _mode;
            [sc addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
            ((LCSegmentCell *)cell).segmentedControl = sc;
            break;
        }
        case RClock: {
            cell.textLabel.text = @"Use a clock";
            UISwitch *sw = [[UISwitch alloc] init]; sw.on = _useClock;
            [sw addTarget:self action:@selector(clockToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            break;
        }
        case RMinutes: {
            cell.textLabel.text = @"Minutes";
            cell.detailTextLabel.text = MinutesText(kMinutes[_minIdx]); _minLabel = cell.detailTextLabel;
            UIStepper *st = [[UIStepper alloc] init]; st.minimumValue = 0; st.maximumValue = kMinCount - 1; st.value = _minIdx;
            [st addTarget:self action:@selector(minutesStep:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = st;
            break;
        }
        case RInc: {
            cell.textLabel.text = @"Increment";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d s", kIncs[_incIdx]]; _incLabel = cell.detailTextLabel;
            UIStepper *st = [[UIStepper alloc] init]; st.minimumValue = 0; st.maximumValue = kIncCount - 1; st.value = _incIdx;
            [st addTarget:self action:@selector(incStep:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = st;
            break;
        }
        case RType: {
            cell.textLabel.text = @"Type";
            _typeLabel = cell.detailTextLabel;
            [self updateTypeLabel];
            break;
        }
        case RRated: {
            cell.textLabel.text = @"Rated";
            UISwitch *sw = [[UISwitch alloc] init]; sw.on = _rated;
            [sw addTarget:self action:@selector(ratedToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            break;
        }
        case RColour: {
            UISegmentedControl *sc = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Random", @"White", @"Black", nil]];
            sc.selectedSegmentIndex = _colorIdx;
            [sc addTarget:self action:@selector(colourChanged:) forControlEvents:UIControlEventValueChanged];
            ((LCSegmentCell *)cell).segmentedControl = sc;
            break;
        }
        case RLevel: {
            cell.textLabel.text = @"Strength";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Level %d", _level]; _levelLabel = cell.detailTextLabel;
            UIStepper *st = [[UIStepper alloc] init]; st.minimumValue = 1; st.maximumValue = 8; st.value = _level;
            [st addTarget:self action:@selector(levelStep:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = st;
            break;
        }
        case RStart: {
            cell.textLabel.text = @"Start game";
            cell.textLabel.textAlignment = UITextAlignmentCenter;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:18];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            break;
        }
    }
    return cell;
}

- (void)updateTypeLabel {
    double m = kMinutes[_minIdx]; int inc = kIncs[_incIdx];
    NSString *mm = (m < 1) ? [NSString stringWithFormat:@"%g", m] : [NSString stringWithFormat:@"%g", m];
    _typeLabel.text = [NSString stringWithFormat:@"%@+%d · %@", mm, inc, Classify(m, inc)];
}

#pragma mark - Controls

- (void)modeChanged:(UISegmentedControl *)sc {
    _mode = _guest ? (int)sc.selectedSegmentIndex + ModeOfflineAI : (int)sc.selectedSegmentIndex;
    if (_mode == ModeOnline) _useClock = YES;
    [self rebuildLayout];
    [self.tableView reloadData];
}
- (void)clockToggled:(UISwitch *)sw { _useClock = sw.on; [self rebuildLayout]; [self.tableView reloadData]; }
- (void)ratedToggled:(UISwitch *)sw { _rated = sw.on; [self rebuildLayout]; [self.tableView reloadData]; }
- (void)colourChanged:(UISegmentedControl *)sc { _colorIdx = (int)sc.selectedSegmentIndex; }
- (void)minutesStep:(UIStepper *)st { _minIdx = (int)st.value; _minLabel.text = MinutesText(kMinutes[_minIdx]); [self updateTypeLabel]; }
- (void)incStep:(UIStepper *)st { _incIdx = (int)st.value; _incLabel.text = [NSString stringWithFormat:@"%d s", kIncs[_incIdx]]; [self updateTypeLabel]; }
- (void)levelStep:(UIStepper *)st { _level = (int)st.value; _levelLabel.text = [NSString stringWithFormat:@"Level %d", _level]; }

#pragma mark - Start

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    int row = [[[[_layout objectAtIndex:ip.section] objectAtIndex:1] objectAtIndex:ip.row] intValue];
    if (row == RStart) [self startTapped];
}

- (void)startTapped {
    double minutes = kMinutes[_minIdx];
    int inc = kIncs[_incIdx];
    NSString *colors[] = { @"random", @"white", @"black" };
    NSString *color = colors[_colorIdx];
    NSString *opponent = (_mode == ModeOnline) ? @"online" : (_mode == ModeLichessAI ? @"ai" : (_mode == ModeOfflineAI ? @"engine" : @"otb"));

    if (_mode == ModeOnline && minutes * 60 + 40 * inc < 480) {
        [[[UIAlertView alloc] initWithTitle:@"Too fast for online pairing"
                                    message:@"Lichess allows only rapid and classical games (about 8+ minutes in total) when pairing through the API. Increase the time, or play Lichess AI / offline."
                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    NSMutableDictionary *cfg = [NSMutableDictionary dictionary];
    [cfg setObject:opponent forKey:@"opponent"];
    [cfg setObject:[NSNumber numberWithBool:(_mode == ModeOnline) ? YES : _useClock] forKey:@"clock"];
    [cfg setObject:[NSNumber numberWithDouble:minutes] forKey:@"minutes"];
    [cfg setObject:[NSNumber numberWithInt:inc] forKey:@"increment"];
    [cfg setObject:[NSNumber numberWithBool:(_mode == ModeOnline) && _rated] forKey:@"rated"];
    [cfg setObject:((_mode == ModeOnline && _rated) ? @"random" : color) forKey:@"color"];
    [cfg setObject:[NSNumber numberWithInt:_level] forKey:@"level"];

    LCConfigBlock block = self.onStart;
    [self.navigationController popViewControllerAnimated:NO];   // return to Home, which then starts the game
    if (block) block(cfg);
}

@end
