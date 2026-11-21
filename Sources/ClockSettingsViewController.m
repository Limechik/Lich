#import "ClockSettingsViewController.h"
#import "LCUtil.h"

static const double kMinutes[] = { 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20, 25, 30, 45, 60, 90, 120, 180 };
static const int kMinCount = 23;
static const int kIncs[] = { 0, 1, 2, 3, 4, 5, 6, 7, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180 };
static const int kIncCount = 18;
static const int kPresets[][2] = { {1,0}, {2,1}, {3,0}, {3,2}, {5,0}, {5,3}, {10,0}, {10,5}, {15,10}, {30,0}, {30,20} };
static const int kPresetCount = 11;
static NSString *const kMinKey = @"lc.clock.min";
static NSString *const kIncKey = @"lc.clock.inc";

static NSString *MinutesText(double m) {
    if (m == 0.25) return @"¼ min";
    if (m == 0.5) return @"½ min";
    if (m == 0.75) return @"¾ min";
    if (m == (int)m) return [NSString stringWithFormat:@"%d min", (int)m];
    return [NSString stringWithFormat:@"%g min", m];
}

@implementation ClockSettingsViewController {
    int _minIdx, _incIdx;
    UILabel *_minLabel, *_incLabel;
}
@synthesize onChange;

+ (int)savedIndex:(NSString *)key count:(int)count fallback:(int)fb {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    int i = [d objectForKey:key] ? (int)[d integerForKey:key] : fb;
    return (i < 0 || i >= count) ? fb : i;
}
+ (double)savedMinutes { return kMinutes[[self savedIndex:kMinKey count:kMinCount fallback:8]]; }     // default 5 min
+ (int)savedIncrement { return kIncs[[self savedIndex:kIncKey count:kIncCount fallback:0]]; }

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Clock settings";
        _minIdx = [ClockSettingsViewController savedIndex:kMinKey count:kMinCount fallback:8];
        _incIdx = [ClockSettingsViewController savedIndex:kIncKey count:kIncCount fallback:0];
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)save {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:_minIdx forKey:kMinKey]; [d setInteger:_incIdx forKey:kIncKey];
    if (self.onChange) self.onChange();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 2 : kPresetCount; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Time per player" : @"Presets"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s { return s == 0 ? @"Changing the time resets the clock." : nil; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (ip.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UIStepper *st = [[UIStepper alloc] init];
        if (ip.row == 0) {
            cell.textLabel.text = @"Minutes"; cell.detailTextLabel.text = MinutesText(kMinutes[_minIdx]); _minLabel = cell.detailTextLabel;
            st.minimumValue = 0; st.maximumValue = kMinCount - 1; st.value = _minIdx;
            [st addTarget:self action:@selector(minutesStep:) forControlEvents:UIControlEventValueChanged];
        } else {
            cell.textLabel.text = @"Increment"; cell.detailTextLabel.text = [NSString stringWithFormat:@"%d s", kIncs[_incIdx]]; _incLabel = cell.detailTextLabel;
            st.minimumValue = 0; st.maximumValue = kIncCount - 1; st.value = _incIdx;
            [st addTarget:self action:@selector(incStep:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = st;
    } else {
        int m = kPresets[ip.row][0], inc = kPresets[ip.row][1];
        cell.textLabel.text = [NSString stringWithFormat:@"%d+%d", m, inc];
        BOOL current = (kMinutes[_minIdx] == m && kIncs[_incIdx] == inc);
        cell.accessoryType = current ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)minutesStep:(UIStepper *)st { _minIdx = (int)st.value; _minLabel.text = MinutesText(kMinutes[_minIdx]); [self save]; }
- (void)incStep:(UIStepper *)st { _incIdx = (int)st.value; _incLabel.text = [NSString stringWithFormat:@"%d s", kIncs[_incIdx]]; [self save]; }

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;
    int m = kPresets[ip.row][0], inc = kPresets[ip.row][1];
    for (int i = 0; i < kMinCount; i++) if (kMinutes[i] == m) _minIdx = i;
    for (int i = 0; i < kIncCount; i++) if (kIncs[i] == inc) _incIdx = i;
    [self save];
    [tv reloadData];
}

@end
