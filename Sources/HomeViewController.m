#import "HomeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"
#import "CustomGameViewController.h"
#import "GameReplayViewController.h"
#import "GameViewController.h"
#import "LocalGameViewController.h"
#import "LCClient.h"
#import "LCUtil.h"

// 3 x 4 grid: 11 time controls + "Custom game".
static const int kGrid[][2] = { {1,0}, {2,1}, {3,0}, {3,2}, {5,0}, {5,3}, {10,0}, {10,5}, {15,10}, {30,0}, {30,20} };
static const int kGridCount = 11;
static const CGFloat kTileH = 56, kGap = 6;

enum { SecGrid, SecProgress, SecTourn, SecBlog, SecRecent };
enum { SheetPreset = 2 };
enum { ChoiceLichessAI = 0, ChoiceOffline = 1, ChoiceTwoPlayers = 2 };

#pragma mark - Helpers

static NSString *Classify(double minutes, int inc) {
    double est = minutes * 60 + 40 * inc;
    if (est < 30) return @"UltraBullet";
    if (est < 180) return @"Bullet";
    if (est < 480) return @"Blitz";
    if (est < 1500) return @"Rapid";
    return @"Classical";
}

static NSString *ClockText(int limitSeconds, int inc) {
    if (limitSeconds % 60 == 0) return [NSString stringWithFormat:@"%d+%d", limitSeconds / 60, inc];
    return [NSString stringWithFormat:@"%g+%d", limitSeconds / 60.0, inc];
}

static NSString *Cap(NSString *s) {
    return s.length ? [[[s substringToIndex:1] uppercaseString] stringByAppendingString:[s substringFromIndex:1]] : @"";
}

static NSString *AgoText(double seconds) {
    if (seconds < 60) return @"just now";
    if (seconds < 3600) return [NSString stringWithFormat:@"%d min ago", (int)(seconds / 60)];
    if (seconds < 86400) return [NSString stringWithFormat:@"%d h ago", (int)(seconds / 3600)];
    return [NSString stringWithFormat:@"%d d ago", (int)(seconds / 86400)];
}

static NSString *InText(int seconds) {
    if (seconds < 60) return @"starts soon";
    if (seconds < 3600) return [NSString stringWithFormat:@"starts in %d min", seconds / 60];
    if (seconds < 86400) return [NSString stringWithFormat:@"starts in %dh %dm", seconds / 3600, (seconds % 3600) / 60];
    return [NSString stringWithFormat:@"starts in %d d", seconds / 86400];
}

static UIImage *ColorImage(UIColor *c) {
    UIGraphicsBeginImageContext(CGSizeMake(1, 1));
    [c setFill]; UIRectFill(CGRectMake(0, 0, 1, 1));
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

static NSString *PlayerLabel(id p) {
    id ai = LCGet(p, @"aiLevel");
    if ([ai isKindOfClass:[NSNumber class]]) return [NSString stringWithFormat:@"Stockfish level %@", ai];
    NSString *name = LCStr(LCGet(p, @"user"), @"name") ?: @"Anonymous";
    id r = LCGet(p, @"rating");
    return [r isKindOfClass:[NSNumber class]] ? [NSString stringWithFormat:@"%@ (%@)", name, r] : name;
}

#pragma mark - Grid views

@interface LCTile : UIButton { UILabel *_big, *_small; }
- (void)setBig:(NSString *)big small:(NSString *)small;
@end

@implementation LCTile
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.layer.cornerRadius = 6; self.layer.masksToBounds = YES;
        [self setBackgroundImage:ColorImage([UIColor colorWithWhite:0.20 alpha:1]) forState:UIControlStateNormal];
        [self setBackgroundImage:ColorImage([UIColor colorWithRed:0.35 green:0.55 blue:0.25 alpha:1]) forState:UIControlStateHighlighted];
        _big = [[UILabel alloc] init]; _small = [[UILabel alloc] init];
        for (UILabel *l in [NSArray arrayWithObjects:_big, _small, nil]) {
            l.backgroundColor = [UIColor clearColor]; l.textAlignment = UITextAlignmentCenter;
            l.userInteractionEnabled = NO; [self addSubview:l];
        }
        _big.textColor = [UIColor whiteColor]; _big.font = [UIFont boldSystemFontOfSize:22];
        _big.adjustsFontSizeToFitWidth = YES; _big.minimumFontSize = 12; _big.numberOfLines = 2;
        _small.textColor = [UIColor colorWithWhite:0.7 alpha:1]; _small.font = [UIFont systemFontOfSize:12];
    }
    return self;
}
- (void)setBig:(NSString *)big small:(NSString *)small { _big.text = big; _small.text = small; [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (_small.text.length) { _big.frame = CGRectMake(2, h * 0.10, w - 4, h * 0.50); _small.frame = CGRectMake(2, h * 0.62, w - 4, h * 0.28); }
    else { _big.frame = CGRectMake(6, 0, w - 12, h); _big.font = [UIFont boldSystemFontOfSize:16]; _small.frame = CGRectZero; }
}
@end

@interface LCGridCell : UITableViewCell
@property (nonatomic, strong) NSArray *tiles;
@end

@implementation LCGridCell
@synthesize tiles;
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    CGFloat w = (b.size.width - kGap * 4) / 3;
    for (NSUInteger i = 0; i < self.tiles.count; i++) {
        int r = (int)(i / 3), c = (int)(i % 3);
        ((UIView *)[self.tiles objectAtIndex:i]).frame = CGRectMake(kGap + c * (w + kGap), kGap + r * (kTileH + kGap), w, kTileH);
    }
}
@end

#pragma mark - Blog carousel

static NSString *ShortDate(NSString *iso) {
    if (iso.length < 19) return iso ?: @"";
    static NSDateFormatter *in, *out;
    if (!in) {
        in = [[NSDateFormatter alloc] init];
        in.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        in.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        in.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
        out = [[NSDateFormatter alloc] init];
        out.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"dMMM" options:0 locale:[NSLocale currentLocale]];
    }
    NSDate *d = [in dateFromString:[iso substringToIndex:19]];
    return d ? [out stringFromDate:d] : [iso substringToIndex:10];
}

static const CGFloat kCardH = 253, kCardGap = 10, kBlogRowH = 265;

@interface LCBlogCard : UIControl { UIImageView *_img; UILabel *_author, *_date, *_title; }
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *imageURL;
- (void)configure:(NSDictionary *)entry;
- (void)setCover:(UIImage *)image;
@end

@implementation LCBlogCard
@synthesize url, imageURL;
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.layer.cornerRadius = 14; self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.20 alpha:1];
        _img = [[UIImageView alloc] init];
        _img.contentMode = UIViewContentModeScaleAspectFill; _img.clipsToBounds = YES;
        _img.backgroundColor = [UIColor colorWithWhite:0.32 alpha:1];
        _author = [[UILabel alloc] init]; _date = [[UILabel alloc] init]; _title = [[UILabel alloc] init];
        for (UILabel *l in [NSArray arrayWithObjects:_author, _date, _title, nil]) l.backgroundColor = [UIColor clearColor];
        _author.font = [UIFont systemFontOfSize:13]; _author.textColor = [UIColor colorWithWhite:0.65 alpha:1];
        _date.font = [UIFont systemFontOfSize:13]; _date.textColor = [UIColor colorWithWhite:0.65 alpha:1]; _date.textAlignment = UITextAlignmentRight;
        _title.font = [UIFont boldSystemFontOfSize:16]; _title.textColor = [UIColor whiteColor]; _title.numberOfLines = 2;
        for (UIView *v in [NSArray arrayWithObjects:_img, _author, _date, _title, nil]) { v.userInteractionEnabled = NO; [self addSubview:v]; }
    }
    return self;
}
- (void)configure:(NSDictionary *)e {
    _author.text = LCStr(e, @"author") ?: @"";
    _date.text = ShortDate(LCStr(e, @"date"));
    _title.text = LCStr(e, @"title") ?: @"";
    self.url = LCStr(e, @"url");
    self.imageURL = LCStr(e, @"image");
}
- (void)setCover:(UIImage *)image { _img.image = image; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; self.alpha = h ? 0.8 : 1; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height, imgH = floor(w / 1.6);
    _img.frame = CGRectMake(0, 0, w, imgH);
    _author.frame = CGRectMake(12, imgH + 8, w - 100, 18);
    _date.frame = CGRectMake(w - 88, imgH + 8, 76, 18);
    _title.frame = CGRectMake(12, imgH + 30, w - 24, h - imgH - 36);
}
@end

@interface LCBlogCell : UITableViewCell <UIScrollViewDelegate> {
    UIScrollView *_scroll;
    CGFloat _pitch;
}
@property (nonatomic, strong) NSArray *cards;
@property (nonatomic, assign) int version;
@end

@implementation LCBlogCell
@synthesize cards, version;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:style reuseIdentifier:rid])) {
        self.backgroundView = [[UIView alloc] init];
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _scroll = [[UIScrollView alloc] init];
        _scroll.showsHorizontalScrollIndicator = NO;
        _scroll.delegate = self;
        _scroll.decelerationRate = UIScrollViewDecelerationRateFast;
        _scroll.clipsToBounds = NO;
        [self.contentView addSubview:_scroll];
    }
    return self;
}
- (void)setCards:(NSArray *)c {
    for (UIView *v in [_scroll.subviews copy]) [v removeFromSuperview];
    cards = c;
    for (UIView *v in c) [_scroll addSubview:v];
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    _scroll.frame = b;
    CGFloat cardW = MIN(280, b.size.width * 0.84);
    _pitch = cardW + kCardGap;
    for (NSUInteger i = 0; i < cards.count; i++)
        ((UIView *)[cards objectAtIndex:i]).frame = CGRectMake(i * _pitch, 6, cardW, kCardH);
    _scroll.contentSize = CGSizeMake(MAX(b.size.width, cards.count * _pitch - kCardGap), b.size.height);
}
// Snap to whole cards, so the next one always peeks in from the right.
- (void)scrollViewWillEndDragging:(UIScrollView *)sv withVelocity:(CGPoint)vel targetContentOffset:(inout CGPoint *)target {
    if (_pitch <= 0) return;
    CGFloat maxX = MAX(0, sv.contentSize.width - sv.bounds.size.width);
    CGFloat x = target->x + (vel.x > 0.3 ? _pitch * 0.4 : (vel.x < -0.3 ? -_pitch * 0.4 : 0));
    CGFloat snapped = floor(x / _pitch + 0.5) * _pitch;
    target->x = MIN(MAX(0, snapped), maxX);
}
@end

#pragma mark - Home


@interface HomeViewController () <UIActionSheetDelegate> {
    NSArray *_ongoing, *_tournaments, *_blog, *_recent;
    NSString *_tournStatus, *_blogStatus, *_recentStatus;
    BOOL _hasResume, _blogLoaded;
    int _blogVersion;
    NSMutableDictionary *_imageCache;
    NSArray *_secs, *_sheetChoices;
    int _presetMin, _presetInc;
    NSMutableSet *_knownIds;
    UISegmentedControl *_ratedSeg;
    UILabel *_footer;
    LCConnection *_events, *_seek;
    UIView *_overlay;
    UILabel *_overlayLabel;
    UIButton *_overlayCancel;
    BOOL _searching, _opening;
    int _serial;
}
@end

@implementation HomeViewController

- (BOOL)isGuest { return ![[LCClient shared].token length]; }

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _ongoing = _tournaments = _blog = _recent = [NSArray array];
        _tournStatus = @"Loading…"; _blogStatus = @"Loading…"; _recentStatus = @"Loading…";
        _knownIds = [NSMutableSet set];
        _imageCache = [NSMutableDictionary dictionary];
        self.title = [self isGuest] ? @"Lich" : ([LCClient shared].username ?: @"Lich");
        [self rebuildSections];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    if (![self isGuest]) {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
        _ratedSeg = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Casual", @"Rated", nil]];
        _ratedSeg.frame = CGRectMake(20, 10, 280, 32);
        _ratedSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _ratedSeg.selectedSegmentIndex = 0;
        [header addSubview:_ratedSeg];
        self.tableView.tableHeaderView = header;
    }
    _footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
    _footer.backgroundColor = [UIColor clearColor]; _footer.textAlignment = UITextAlignmentCenter;
    _footer.font = [UIFont systemFontOfSize:12]; _footer.textColor = [UIColor colorWithRed:1 green:0.72 blue:0.62 alpha:1]; _footer.numberOfLines = 2;
    self.tableView.tableFooterView = _footer;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _opening = NO;
    [self rebuildSections];
    [self.tableView reloadData];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self cancelSearch];
}

#pragma mark - Data

- (void)rebuildSections {
    _hasResume = [LocalGameViewController savedGame] != nil;
    NSMutableArray *s = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:SecGrid]];
    if (_hasResume || _ongoing.count) [s addObject:[NSNumber numberWithInt:SecProgress]];
    [s addObject:[NSNumber numberWithInt:SecTourn]];
    [s addObject:[NSNumber numberWithInt:SecBlog]];
    if (![self isGuest]) [s addObject:[NSNumber numberWithInt:SecRecent]];
    _secs = s;
}

- (int)secAt:(NSInteger)i { return [[_secs objectAtIndex:i] intValue]; }
- (int)progressCount { return (_hasResume ? 1 : 0) + (int)_ongoing.count; }

- (void)refresh {
    [self loadTournaments];
    if (!_blogLoaded) [self loadBlog];
    if ([self isGuest]) return;
    LCClient *c = [LCClient shared];
    [c fetchAccount:^(id json, NSString *err) {
        if (err && [err rangeOfString:@"authorized"].location != NSNotFound) { [self logout]; return; }
        _footer.text = err;
        if (!err) {
            NSString *name = LCStr(json, @"username");
            id blitz = LCGet(LCGet(LCGet(json, @"perfs"), @"blitz"), @"rating");
            self.title = [blitz isKindOfClass:[NSNumber class]] ? [NSString stringWithFormat:@"%@ (%@)", name, blitz] : name;
        }
        [self loadRecent];
    }];
    [c fetchOngoing:^(id json, NSString *err) {
        if (err) return;
        id list = LCGet(json, @"nowPlaying");
        _ongoing = [list isKindOfClass:[NSArray class]] ? list : [NSArray array];
        [_knownIds removeAllObjects];
        for (id g in _ongoing) { NSString *gid = LCStr(g, @"gameId"); if (gid) [_knownIds addObject:gid]; }
        [self rebuildSections];
        [self.tableView reloadData];
    }];
}

- (void)loadTournaments {
    [[LCClient shared] fetchTournaments:^(id json, NSString *err) {
        if (err) { _tournaments = [NSArray array]; _tournStatus = err; [self.tableView reloadData]; return; }
        NSMutableArray *started = [NSMutableArray array], *created = [NSMutableArray array];
        for (id t in ([LCGet(json, @"started") isKindOfClass:[NSArray class]] ? LCGet(json, @"started") : [NSArray array])) [started addObject:t];
        for (id t in ([LCGet(json, @"created") isKindOfClass:[NSArray class]] ? LCGet(json, @"created") : [NSArray array])) [created addObject:t];
        // Prefer standard chess; fall back to everything if there is none.
        NSPredicate *std = [NSPredicate predicateWithBlock:^BOOL(id t, NSDictionary *b) { return [LCStr(LCGet(t, @"variant"), @"key") isEqualToString:@"standard"]; }];
        NSArray *s2 = [started filteredArrayUsingPredicate:std], *c2 = [created filteredArrayUsingPredicate:std];
        if (s2.count + c2.count) { started = [s2 mutableCopy]; created = [c2 mutableCopy]; }
        [started sortUsingComparator:^NSComparisonResult(id a, id b) {
            return [[LCGet(b, @"nbPlayers") ?: [NSNumber numberWithInt:0] description] intValue] - [[LCGet(a, @"nbPlayers") ?: [NSNumber numberWithInt:0] description] intValue] > 0 ? NSOrderedDescending : NSOrderedAscending;
        }];
        [created sortUsingComparator:^NSComparisonResult(id a, id b) {
            return [[LCGet(a, @"secondsToStart") ?: [NSNumber numberWithInt:0] description] intValue] > [[LCGet(b, @"secondsToStart") ?: [NSNumber numberWithInt:0] description] intValue] ? NSOrderedDescending : NSOrderedAscending;
        }];
        NSMutableArray *all = [NSMutableArray array];
        for (id t in started) if (all.count < 4) [all addObject:t];
        for (id t in created) if (all.count < 8) [all addObject:t];
        _tournaments = all;
        _tournStatus = all.count ? nil : @"No open tournaments";
        [self.tableView reloadData];
    }];
}

- (void)loadBlog {
    [[LCClient shared] fetchBlog:^(id json, NSString *err) {
        if (err) { _blog = [NSArray array]; _blogStatus = err; }
        else { _blog = json; _blogStatus = nil; _blogLoaded = YES; _blogVersion++; }
        [self.tableView reloadData];
    }];
}

- (void)loadRecent {
    [[LCClient shared] fetchRecentGames:10 done:^(id json, NSString *err) {
        if (err) { _recent = [NSArray array]; _recentStatus = err; }
        else { _recent = json; _recentStatus = _recent.count ? nil : @"No games yet"; }
        [self.tableView reloadData];
    }];
}

- (void)logout {
    [self cancelSearch];
    [[LCClient shared] logout];
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] showLogin];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _secs.count; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch ([self secAt:s]) {
        case SecGrid: return 1;
        case SecProgress: return [self progressCount];
        case SecTourn: return MAX(1, (NSInteger)_tournaments.count);
        case SecBlog: return 1;
        default: return MAX(1, (NSInteger)_recent.count);
    }
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    switch ([self secAt:s]) {
        case SecProgress: return @"In progress";
        case SecTourn: return @"Open tournaments";
        case SecBlog: return @"Blog";
        case SecRecent: return @"Recent games";
        default: return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    int sec = [self secAt:ip.section];
    if (sec == SecGrid) return 4 * kTileH + 5 * kGap;
    if (sec == SecBlog && _blog.count) return kBlogRowH;
    return 50;
}

- (UITableViewCell *)gridCellForTable:(UITableView *)tv {
    LCGridCell *cell = [tv dequeueReusableCellWithIdentifier:@"grid"];
    if (cell) return cell;
    cell = [[LCGridCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"grid"];
    cell.backgroundView = [[UIView alloc] init];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSMutableArray *tiles = [NSMutableArray array];
    for (int i = 0; i < 12; i++) {
        LCTile *t = [[LCTile alloc] initWithFrame:CGRectMake(0, 0, 90, kTileH)];
        t.tag = i;
        if (i < kGridCount) [t setBig:[NSString stringWithFormat:@"%d+%d", kGrid[i][0], kGrid[i][1]] small:Classify(kGrid[i][0], kGrid[i][1])];
        else [t setBig:@"Custom game" small:nil];
        [t addTarget:self action:@selector(tileTapped:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:t];
        [tiles addObject:t];
    }
    cell.tiles = tiles;
    return cell;
}

- (UITableViewCell *)plainCell:(UITableView *)tv text:(NSString *)text detail:(NSString *)detail disclosure:(BOOL)disc {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    cell.textLabel.text = text; cell.detailTextLabel.text = detail;
    cell.accessoryType = disc ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = disc ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = disc ? [UIColor blackColor] : [UIColor grayColor];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    switch ([self secAt:ip.section]) {
        case SecGrid:
            return [self gridCellForTable:tv];

        case SecProgress: {
            if (_hasResume && ip.row == 0) {
                NSDictionary *sv = [LocalGameViewController savedGame];
                BOOL eng = [LCStr(sv, @"opponent") isEqualToString:@"engine"];
                id mv = LCGet(sv, @"moves");
                return [self plainCell:tv text:@"Resume offline game"
                                detail:[NSString stringWithFormat:@"%@ • %lu moves", eng ? @"vs computer" : @"two players", (unsigned long)([mv isKindOfClass:[NSArray class]] ? [mv count] : 0)]
                            disclosure:YES];
            }
            id g = [_ongoing objectAtIndex:ip.row - (_hasResume ? 1 : 0)];
            id opp = LCGet(g, @"opponent");
            NSString *name = LCStr(opp, @"username") ?: @"Anonymous";
            id rating = LCGet(opp, @"rating");
            if ([rating isKindOfClass:[NSNumber class]]) name = [NSString stringWithFormat:@"%@ (%@)", name, rating];
            return [self plainCell:tv text:[@"vs " stringByAppendingString:name]
                            detail:[NSString stringWithFormat:@"%@ • %@", LCStr(g, @"speed") ?: @"", [LCGet(g, @"isMyTurn") boolValue] ? @"your turn" : @"opponent's turn"]
                        disclosure:YES];
        }

        case SecTourn: {
            if (!_tournaments.count) return [self plainCell:tv text:_tournStatus ?: @"" detail:nil disclosure:NO];
            id t = [_tournaments objectAtIndex:ip.row];
            id clk = LCGet(t, @"clock");
            NSString *clock = ClockText([LCGet(clk, @"limit") intValue], [LCGet(clk, @"increment") intValue]);
            id st = LCGet(t, @"secondsToStart");
            NSString *when = [st isKindOfClass:[NSNumber class]] ? InText([st intValue]) : @"in progress";
            NSString *vk = LCStr(LCGet(t, @"variant"), @"key");
            NSString *variant = (vk && ![vk isEqualToString:@"standard"]) ? [LCStr(LCGet(t, @"variant"), @"name") stringByAppendingString:@" · "] : @"";
            return [self plainCell:tv text:LCStr(t, @"fullName") ?: @"Tournament"
                            detail:[NSString stringWithFormat:@"%@%@ · %@ min · %@ players · %@", variant, clock, LCGet(t, @"minutes") ?: @"?", LCGet(t, @"nbPlayers") ?: @"0", when]
                        disclosure:YES];
        }

        case SecBlog: {
            if (!_blog.count) return [self plainCell:tv text:_blogStatus ?: @"" detail:nil disclosure:NO];
            return [self blogCellForTable:tv];
        }

        default: {
            if (!_recent.count) return [self plainCell:tv text:_recentStatus ?: @"" detail:nil disclosure:NO];
            return [self recentCell:tv game:[_recent objectAtIndex:ip.row]];
        }
    }
}

- (UITableViewCell *)recentCell:(UITableView *)tv game:(id)g {
    id players = LCGet(g, @"players"), white = LCGet(players, @"white"), black = LCGet(players, @"black");
    NSString *me = [LCClient shared].userId;
    BOOL iAmWhite = me.length && [[LCStr(LCGet(white, @"user"), @"id") lowercaseString] isEqualToString:me];
    BOOL iAmBlack = me.length && [[LCStr(LCGet(black, @"user"), @"id") lowercaseString] isEqualToString:me];
    NSString *title = (iAmWhite || iAmBlack) ? [@"vs " stringByAppendingString:PlayerLabel(iAmWhite ? black : white)]
                                             : [NSString stringWithFormat:@"%@ vs %@", PlayerLabel(white), PlayerLabel(black)];
    NSString *status = LCStr(g, @"status") ?: @"", *winner = LCStr(g, @"winner"), *outcome;
    if ([status isEqualToString:@"created"] || [status isEqualToString:@"started"]) outcome = @"In progress";
    else if ([status isEqualToString:@"aborted"] || [status isEqualToString:@"noStart"]) outcome = @"Aborted";
    else if (!winner) outcome = @"Draw";
    else if (iAmWhite || iAmBlack) outcome = ([winner isEqualToString:@"white"] == iAmWhite) ? @"Won" : @"Lost";
    else outcome = [Cap(winner) stringByAppendingString:@" won"];
    id clk = LCGet(g, @"clock");
    NSString *tc = clk ? [@" " stringByAppendingString:ClockText([LCGet(clk, @"initial") intValue], [LCGet(clk, @"increment") intValue])] : @"";
    double created = [LCGet(g, @"createdAt") doubleValue] / 1000.0;
    NSString *ago = created > 0 ? AgoText([[NSDate date] timeIntervalSince1970] - created) : @"";
    return [self plainCell:tv text:title
                    detail:[NSString stringWithFormat:@"%@ · %@%@ · %@", outcome, Cap(LCStr(g, @"speed") ?: @""), tc, ago] disclosure:YES];
}

- (UITableViewCell *)blogCellForTable:(UITableView *)tv {
    LCBlogCell *cell = [tv dequeueReusableCellWithIdentifier:@"blog"];
    if (!cell) { cell = [[LCBlogCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"blog"]; cell.version = -1; }
    if (cell.version != _blogVersion) {            // rebuild only when the data changed (keeps the scroll position)
        NSMutableArray *cards = [NSMutableArray array];
        for (id e in _blog) {
            LCBlogCard *c = [[LCBlogCard alloc] initWithFrame:CGRectMake(0, 0, 270, kCardH)];
            [c configure:e];
            [c addTarget:self action:@selector(blogCardTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self loadCoverFor:c];
            [cards addObject:c];
        }
        cell.cards = cards;
        cell.version = _blogVersion;
    }
    return cell;
}

- (void)loadCoverFor:(LCBlogCard *)card {
    NSString *u = card.imageURL;
    if (!u.length) return;
    UIImage *cached = [_imageCache objectForKey:u];
    if (cached) { [card setCover:cached]; return; }
    [[LCClient shared] fetchImage:u done:^(UIImage *img) {
        if (!img) return;
        [_imageCache setObject:img forKey:u];
        [card setCover:img];
    }];
}

- (void)blogCardTapped:(LCBlogCard *)card {
    if (card.url.length) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:card.url]];
}

- (void)openWeb:(NSString *)path {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://lichess.org" stringByAppendingString:path]]];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (_searching || _opening) return;
    switch ([self secAt:ip.section]) {
        case SecProgress: {
            if (_hasResume && ip.row == 0) {
                _opening = YES;
                [self.navigationController pushViewController:[[LocalGameViewController alloc] initWithSavedGame:[LocalGameViewController savedGame]] animated:YES];
            } else {
                id g = [_ongoing objectAtIndex:ip.row - (_hasResume ? 1 : 0)];
                [self openGame:LCStr(g, @"gameId") color:LCStr(g, @"color")];
            }
            break;
        }
        case SecTourn: {
            if (!_tournaments.count) return;
            NSString *tid = LCStr([_tournaments objectAtIndex:ip.row], @"id");
            if (tid) [self openWeb:[@"/tournament/" stringByAppendingString:tid]];
            break;
        }
        case SecBlog: break;
        case SecRecent: {
            if (!_recent.count) return;
            id g = [_recent objectAtIndex:ip.row];
            NSString *variant = LCStr(g, @"variant");
            BOOL standard = !variant || [variant isEqualToString:@"standard"] || [variant isEqualToString:@"fromPosition"];
            if (standard && [LCStr(g, @"moves") length]) [self.navigationController pushViewController:[[GameReplayViewController alloc] initWithGame:g] animated:YES];
            else if (LCStr(g, @"id")) [self openWeb:[@"/" stringByAppendingString:LCStr(g, @"id")]];
            break;
        }
        default: break;
    }
}

#pragma mark - Grid actions

- (void)tileTapped:(UIButton *)b {
    if (_searching || _opening) return;
    if (b.tag >= kGridCount) {
        CustomGameViewController *vc = [[CustomGameViewController alloc] initAsGuest:[self isGuest]];
        vc.onStart = ^(NSDictionary *cfg) { [self startFromConfig:cfg]; };
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    int m = kGrid[b.tag][0], inc = kGrid[b.tag][1];
    BOOL guest = [self isGuest];
    // Board API pairing accepts only rapid / classical (estimated duration >= 8 min).
    if (!guest && m * 60 + 40 * inc >= 480) {
        [self startSeekMinutes:m increment:inc rated:_ratedSeg.selectedSegmentIndex == 1 color:@"random"];
        return;
    }
    _presetMin = m; _presetInc = inc;
    NSMutableArray *titles = [NSMutableArray array], *choices = [NSMutableArray array];
    if (!guest) { [titles addObject:@"Lichess AI"]; [choices addObject:[NSNumber numberWithInt:ChoiceLichessAI]]; }
    [titles addObject:@"Offline computer"]; [choices addObject:[NSNumber numberWithInt:ChoiceOffline]];
    [titles addObject:@"Two players (offline)"]; [choices addObject:[NSNumber numberWithInt:ChoiceTwoPlayers]];
    _sheetChoices = choices;
    NSString *head = guest ? [NSString stringWithFormat:@"%d+%d: play offline", m, inc]
                           : [NSString stringWithFormat:@"%d+%d: bullet and blitz pairing isn't available through the Lichess API. Play it against:", m, inc];
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:head delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *t in titles) [as addButtonWithTitle:t];
    as.cancelButtonIndex = [as addButtonWithTitle:@"Cancel"];
    as.tag = SheetPreset;
    [as showInView:self.tabBarController.view ?: self.view];
}

- (void)actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)idx {
    if (as.tag != SheetPreset || idx == as.cancelButtonIndex || idx < 0 || idx >= (NSInteger)_sheetChoices.count) return;
    int choice = [[_sheetChoices objectAtIndex:idx] intValue];
    NSString *opp = choice == ChoiceLichessAI ? @"ai" : (choice == ChoiceOffline ? @"engine" : @"otb");
    NSDictionary *cfg = [NSDictionary dictionaryWithObjectsAndKeys:
        opp, @"opponent", [NSNumber numberWithBool:YES], @"clock",
        [NSNumber numberWithDouble:_presetMin], @"minutes", [NSNumber numberWithInt:_presetInc], @"increment",
        [NSNumber numberWithBool:NO], @"rated", @"random", @"color", [NSNumber numberWithInt:3], @"level", nil];
    [self startFromConfig:cfg];
}

#pragma mark - Starting games

- (void)startFromConfig:(NSDictionary *)cfg {
    NSString *opp = LCStr(cfg, @"opponent");
    double minutes = [LCGet(cfg, @"minutes") doubleValue];
    int inc = [LCGet(cfg, @"increment") intValue];
    NSString *color = LCStr(cfg, @"color") ?: @"random";
    if ([opp isEqualToString:@"online"]) {
        [self startSeekMinutes:minutes increment:inc rated:[LCGet(cfg, @"rated") boolValue] color:color];
    } else if ([opp isEqualToString:@"ai"]) {
        BOOL clock = [LCGet(cfg, @"clock") boolValue];
        [self startAILevel:[LCGet(cfg, @"level") intValue] limitSeconds:clock ? (int)(minutes * 60 + 0.5) : -1 increment:inc color:color];
    } else {
        _opening = YES;
        [self.navigationController pushViewController:[[LocalGameViewController alloc] initWithConfig:cfg] animated:YES];
    }
}

- (void)openGame:(NSString *)gid color:(NSString *)color {
    if (!gid || _opening) return;
    _opening = YES;
    [self cancelSearch];
    [self.navigationController pushViewController:[[GameViewController alloc] initWithGameId:gid colorHint:color] animated:YES];
}

- (void)startSeekMinutes:(double)m increment:(int)inc rated:(BOOL)rated color:(NSString *)color {
    LCClient *c = [LCClient shared];
    _searching = YES;
    [self showOverlay:[NSString stringWithFormat:@"Looking for an opponent…\n%g+%d %@", m, inc, rated ? @"rated" : @"casual"] cancellable:YES];
    // gameStart arrives on the event stream; games already in progress are replayed there too, so we skip known ids.
    _events = [c streamEvents:^(id e) {
        if (![LCStr(e, @"type") isEqualToString:@"gameStart"] || !_searching) return;
        id game = LCGet(e, @"game");
        NSString *gid = LCStr(game, @"gameId") ?: LCStr(game, @"id");
        if (!gid || [_knownIds containsObject:gid]) return;
        [self openGame:gid color:LCStr(game, @"color")];
    } onEnd:^(NSString *err) {
        if (_searching && err) [self searchFailed:err];
    }];
    _seek = [c seekMinutes:m increment:inc rated:rated color:color onEnd:^(NSString *err) {
        if (_searching && err) [self searchFailed:err];
    }];
}

- (void)searchFailed:(NSString *)err {
    [self cancelSearch];
    [[[UIAlertView alloc] initWithTitle:@"Pairing failed" message:err delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)startAILevel:(int)level limitSeconds:(int)limit increment:(int)inc color:(NSString *)color {
    int serial = ++_serial;
    [self showOverlay:@"Starting game…" cancellable:YES];
    [[LCClient shared] challengeAILevel:level limitSeconds:limit increment:inc color:color done:^(id json, NSString *err) {
        if (serial != _serial) return;                  // cancelled meanwhile
        [self hideOverlay];
        if (err) {
            [[[UIAlertView alloc] initWithTitle:@"Can't start game" message:err delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        [self openGame:LCStr(json, @"id") color:LCStr(json, @"player")];
    }];
}

- (void)cancelSearch {
    _serial++;
    [_events cancel]; _events = nil;
    [_seek cancel]; _seek = nil;
    _searching = NO;
    [self hideOverlay];
}

#pragma mark - Overlay

- (void)showOverlay:(NSString *)text cancellable:(BOOL)cancellable {
    UIView *host = self.tabBarController.view ?: self.navigationController.view ?: self.view;
    if (!_overlay) {
        _overlay = [[UIView alloc] init];
        _overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
        _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        sp.tag = 9; [sp startAnimating]; [_overlay addSubview:sp];
        UIViewAutoresizing centred = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        sp.autoresizingMask = centred;
        _overlayLabel = [[UILabel alloc] init];
        _overlayLabel.numberOfLines = 0; _overlayLabel.textAlignment = UITextAlignmentCenter;
        _overlayLabel.textColor = [UIColor whiteColor]; _overlayLabel.backgroundColor = [UIColor clearColor];
        _overlayLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [_overlay addSubview:_overlayLabel];
        _overlayCancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [_overlayCancel setTitle:@"Cancel" forState:UIControlStateNormal];
        [_overlayCancel addTarget:self action:@selector(cancelSearch) forControlEvents:UIControlEventTouchUpInside];
        _overlayCancel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [_overlay addSubview:_overlayCancel];
    }
    _overlay.frame = host.bounds;
    CGFloat W = host.bounds.size.width, cy = host.bounds.size.height / 2;
    [_overlay viewWithTag:9].center = CGPointMake(W / 2, cy - 50);
    _overlayLabel.frame = CGRectMake(20, cy - 20, W - 40, 60);
    _overlayLabel.text = text;
    _overlayCancel.frame = CGRectMake(W / 2 - 60, cy + 55, 120, 40);
    _overlayCancel.hidden = !cancellable;
    [host addSubview:_overlay];
}

- (void)hideOverlay { [_overlay removeFromSuperview]; }

@end
