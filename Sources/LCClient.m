#import "LCClient.h"
#import <Security/Security.h>
#import "LCUtil.h"
#import "LCAtomParser.h"

static NSString *const kService = @"org.lichess.ios5";
static NSString *const kTokenAccount = @"api-token";

static NSString *Escape(NSString *s) {
    CFStringRef e = CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)s, NULL,
                                                           CFSTR("!*'();:@&=+$,/?%#[]\" "), kCFStringEncodingUTF8);
    return (__bridge_transfer NSString *)e;
}

static NSString *FormEncode(NSDictionary *d) {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *k in d) [parts addObject:[NSString stringWithFormat:@"%@=%@", Escape(k), Escape([[d objectForKey:k] description])]];
    return [parts componentsJoinedByString:@"&"];
}

#pragma mark - Keychain (falls back to NSUserDefaults if the keychain is unavailable)

static NSMutableDictionary *KCQuery(void) {
    return [@{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
               (__bridge id)kSecAttrService: kService,
               (__bridge id)kSecAttrAccount: kTokenAccount } mutableCopy];
}

static NSString *KCRead(void) {
    NSMutableDictionary *q = KCQuery();
    [q setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [q setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    CFTypeRef out = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &out) == errSecSuccess && out) {
        NSData *d = (__bridge_transfer NSData *)out;
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    }
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"lc.token.fallback"];
}

static void KCWrite(NSString *token) {
    SecItemDelete((__bridge CFDictionaryRef)KCQuery());
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lc.token.fallback"];
    if (!token.length) return;
    NSMutableDictionary *q = KCQuery();
    [q setObject:[token dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    if (SecItemAdd((__bridge CFDictionaryRef)q, NULL) != errSecSuccess)
        [[NSUserDefaults standardUserDefaults] setObject:token forKey:@"lc.token.fallback"];
}

@implementation LCClient {
    NSString *_token;
}

+ (LCClient *)shared {
    static LCClient *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[LCClient alloc] init]; });
    return c;
}

- (id)init {
    if ((self = [super init])) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _baseURL = [d stringForKey:@"lc.baseURL"] ?: @"https://lichess.org";
        _insecureTLS = [d boolForKey:@"lc.insecureTLS"];
        _userId = [d stringForKey:@"lc.userId"];
        _username = [d stringForKey:@"lc.username"];
        _token = KCRead();
    }
    return self;
}

- (NSString *)token { return _token; }
- (void)setToken:(NSString *)t { _token = [t copy]; KCWrite(_token); }

- (void)setBaseURL:(NSString *)u {
    while ([u hasSuffix:@"/"]) u = [u substringToIndex:u.length - 1];
    _baseURL = [u copy];
    [[NSUserDefaults standardUserDefaults] setObject:_baseURL forKey:@"lc.baseURL"];
}
- (void)setInsecureTLS:(BOOL)b { _insecureTLS = b; [[NSUserDefaults standardUserDefaults] setBool:b forKey:@"lc.insecureTLS"]; }
- (void)setUserId:(NSString *)u { _userId = [u copy]; [[NSUserDefaults standardUserDefaults] setObject:u forKey:@"lc.userId"]; }
- (void)setUsername:(NSString *)u { _username = [u copy]; [[NSUserDefaults standardUserDefaults] setObject:u forKey:@"lc.username"]; }
- (BOOL)guest { return [[NSUserDefaults standardUserDefaults] boolForKey:@"lc.guest"]; }
- (void)setGuest:(BOOL)g { [[NSUserDefaults standardUserDefaults] setBool:g forKey:@"lc.guest"]; }

- (void)logout {
    self.token = nil; self.userId = nil; self.username = nil; self.guest = NO;
}

#pragma mark - Requests

- (NSMutableURLRequest *)request:(NSString *)path method:(NSString *)method form:(NSDictionary *)form
                         timeout:(NSTimeInterval)timeout {
    NSURL *url = [NSURL URLWithString:[_baseURL stringByAppendingString:path]];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:url
                                                     cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                 timeoutInterval:timeout];
    r.HTTPMethod = method;
    if (_token.length) [r setValue:[@"Bearer " stringByAppendingString:_token] forHTTPHeaderField:@"Authorization"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if ([method isEqualToString:@"POST"]) {
        NSString *body = form ? FormEncode(form) : @"";
        r.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
        [r setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    return r;
}

static NSString *ErrorText(NSInteger status, id json, NSError *err) {
    if (err) {
        NSString *u = [[err.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey] description];
        return [NSString stringWithFormat:@"%@\n[%@ %ld]\n%@", err.localizedDescription, err.domain, (long)err.code, u ?: @""];
    }
    if (status >= 200 && status < 300) return nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        id e = LCGet(json, @"error");
        if ([e isKindOfClass:[NSString class]]) return e;
        if (e) return [e description];
    }
    if (status == 401) return @"Not authorized (check your token and its scopes)";
    if (status == 429) return @"Rate limited by Lichess, wait a minute";
    return [NSString stringWithFormat:@"HTTP %ld", (long)status];
}

- (void)call:(NSString *)path method:(NSString *)method form:(NSDictionary *)form done:(LCResultBlock)done {
    NSURLRequest *r = [self request:path method:method form:form timeout:30];
    [LCConnection send:r insecure:_insecureTLS onDone:^(NSInteger status, id json, NSError *err) {
        NSString *msg = ErrorText(status, json, err);
        if (done) done(msg ? nil : (json ?: @{}), msg);
    }];
}

- (LCConnection *)open:(NSString *)path method:(NSString *)method form:(NSDictionary *)form
                  line:(LCJSONBlock)line end:(void (^)(NSString *))end {
    NSURLRequest *r = [self request:path method:method form:form timeout:90];
    return [LCConnection stream:r insecure:_insecureTLS onLine:line onDone:^(NSInteger status, id json, NSError *err) {
        if (end) end(ErrorText(status, json, err));
    }];
}

#pragma mark - API

- (void)fetchAccount:(LCResultBlock)done {
    [self call:@"/api/account" method:@"GET" form:nil done:^(id json, NSString *err) {
        if (json && [json isKindOfClass:[NSDictionary class]]) {
            self.userId = [LCStr(json, @"id") lowercaseString];
            self.username = LCStr(json, @"username");
        }
        if (done) done(json, err);
    }];
}

- (void)fetchOngoing:(LCResultBlock)done { [self call:@"/api/account/playing" method:@"GET" form:nil done:done]; }

- (LCConnection *)streamEvents:(LCJSONBlock)onEvent onEnd:(void (^)(NSString *))onEnd {
    return [self open:@"/api/stream/event" method:@"GET" form:nil line:onEvent end:onEnd];
}

- (LCConnection *)streamGame:(NSString *)gameId onEvent:(LCJSONBlock)onEvent onEnd:(void (^)(NSString *))onEnd {
    return [self open:[@"/api/board/game/stream/" stringByAppendingString:gameId]
               method:@"GET" form:nil line:onEvent end:onEnd];
}

- (LCConnection *)seekMinutes:(double)minutes increment:(int)inc rated:(BOOL)rated color:(NSString *)color onEnd:(void (^)(NSString *))onEnd {
    NSMutableDictionary *f = [NSMutableDictionary dictionary];
    [f setObject:rated ? @"true" : @"false" forKey:@"rated"];
    [f setObject:[NSNumber numberWithDouble:minutes] forKey:@"time"];
    [f setObject:[NSNumber numberWithInt:inc] forKey:@"increment"];
    if (!rated && color.length && ![color isEqualToString:@"random"]) [f setObject:color forKey:@"color"];   // rated seeks are always random
    // The seek stays open (keep-alive newlines) until it is paired or cancelled by closing the connection.
    return [self open:@"/api/board/seek" method:@"POST" form:f line:nil end:onEnd];
}

- (void)challengeAILevel:(int)level limitSeconds:(int)limit increment:(int)inc color:(NSString *)color done:(LCResultBlock)done {
    [self challengeAILevel:level limitSeconds:limit increment:inc color:color fen:nil done:done];
}

- (void)challengeAILevel:(int)level limitSeconds:(int)limit increment:(int)inc color:(NSString *)color fen:(NSString *)fen done:(LCResultBlock)done {
    NSMutableDictionary *f = [NSMutableDictionary dictionary];
    [f setObject:[NSNumber numberWithInt:level] forKey:@"level"];
    if (limit >= 0) {
        [f setObject:[NSNumber numberWithInt:limit] forKey:@"clock.limit"];
        [f setObject:[NSNumber numberWithInt:inc] forKey:@"clock.increment"];
    }
    [f setObject:color ?: @"random" forKey:@"color"];
    if (fen.length) { [f setObject:fen forKey:@"fen"]; [f setObject:@"fromPosition" forKey:@"variant"]; }
    [self call:@"/api/challenge/ai" method:@"POST" form:f done:done];
}

- (void)move:(NSString *)uci game:(NSString *)gid done:(LCResultBlock)done {
    [self call:[NSString stringWithFormat:@"/api/board/game/%@/move/%@", gid, uci] method:@"POST" form:nil done:done];
}
- (void)resignGame:(NSString *)gid done:(LCResultBlock)done {
    [self call:[NSString stringWithFormat:@"/api/board/game/%@/resign", gid] method:@"POST" form:nil done:done];
}
- (void)abortGame:(NSString *)gid done:(LCResultBlock)done {
    [self call:[NSString stringWithFormat:@"/api/board/game/%@/abort", gid] method:@"POST" form:nil done:done];
}
- (void)drawGame:(NSString *)gid accept:(BOOL)yes done:(LCResultBlock)done {
    [self call:[NSString stringWithFormat:@"/api/board/game/%@/draw/%@", gid, yes ? @"yes" : @"no"]
        method:@"POST" form:nil done:done];
}


- (void)fetchDailyPuzzle:(LCResultBlock)done { [self call:@"/api/puzzle/daily" method:@"GET" form:nil done:done]; }

- (LCConnection *)streamTV:(NSString *)channel onEvent:(LCJSONBlock)onEvent onEnd:(void (^)(NSString *))onEnd {
    return [self open:[NSString stringWithFormat:@"/api/tv/%@/feed", channel] method:@"GET" form:nil line:onEvent end:onEnd];
}

- (void)fetchTournaments:(LCResultBlock)done { [self call:@"/api/tournament" method:@"GET" form:nil done:done]; }

- (void)fetchBlog:(LCResultBlock)done {
    NSString *lang = @"en";
    NSString *pref = [[NSLocale preferredLanguages] count] ? [[NSLocale preferredLanguages] objectAtIndex:0] : nil;
    if (pref.length >= 2) lang = [[pref substringToIndex:2] lowercaseString];
    NSMutableArray *paths = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"/blog/community.atom?lang=%@", lang]];
    if (![lang isEqualToString:@"en"]) [paths addObject:@"/blog/community.atom?lang=en"];
    [paths addObject:@"/@/Lichess/blog.atom"];                // last resort: official blog
    [self fetchFeedPaths:paths index:0 done:done];
}

- (void)fetchFeedPaths:(NSArray *)paths index:(NSUInteger)i done:(LCResultBlock)done {
    NSMutableURLRequest *r = [self request:[paths objectAtIndex:i] method:@"GET" form:nil timeout:30];
    [r setValue:@"application/atom+xml" forHTTPHeaderField:@"Accept"];
    [LCConnection sendRaw:r insecure:_insecureTLS onDone:^(NSInteger status, NSData *body, NSError *err) {
        NSString *msg = ErrorText(status, nil, err);
        NSArray *entries = msg ? nil : [LCAtomParser parseEntries:body limit:10];
        if (entries.count) { if (done) done(entries, nil); return; }
        if (i + 1 < paths.count) { [self fetchFeedPaths:paths index:i + 1 done:done]; return; }
        if (done) done(nil, msg ?: @"No posts found");
    }];
}

- (void)fetchImage:(NSString *)url done:(void (^)(UIImage *))done {
    NSMutableArray *candidates = [NSMutableArray array];
    // Covers are WebP, which iOS can only decode from iOS 14: ask for JPEG first, fall back to the original URL.
    if ([url rangeOfString:@"fmt=webp"].location != NSNotFound)
        [candidates addObject:[url stringByReplacingOccurrencesOfString:@"fmt=webp" withString:@"fmt=jpg"]];
    [candidates addObject:url];
    [self tryImages:candidates index:0 done:done];
}

- (void)tryImages:(NSArray *)c index:(NSUInteger)i done:(void (^)(UIImage *))done {
    if (i >= c.count) { if (done) done(nil); return; }
    NSURL *u = [NSURL URLWithString:[c objectAtIndex:i]];
    if (!u) { [self tryImages:c index:i + 1 done:done]; return; }
    NSURLRequest *r = [NSURLRequest requestWithURL:u cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    [LCConnection sendRaw:r insecure:_insecureTLS onDone:^(NSInteger status, NSData *body, NSError *err) {
        UIImage *img = (status == 200 && !err && body.length) ? [UIImage imageWithData:body] : nil;
        if (img) { if (done) done(img); }
        else [self tryImages:c index:i + 1 done:done];
    }];
}

- (void)fetchRecentGames:(int)max done:(LCResultBlock)done {
    if (!_username.length) { if (done) done(nil, @"Not signed in"); return; }
    NSString *path = [NSString stringWithFormat:@"/api/games/user/%@?max=%d&moves=true", Escape(_username), max];
    NSMutableURLRequest *r = [self request:path method:@"GET" form:nil timeout:60];
    [r setValue:@"application/x-ndjson" forHTTPHeaderField:@"Accept"];
    NSMutableArray *games = [NSMutableArray array];
    [LCConnection stream:r insecure:_insecureTLS
        onLine:^(id obj) { if ([obj isKindOfClass:[NSDictionary class]]) [games addObject:obj]; }
        onDone:^(NSInteger status, id json, NSError *err) {
            NSString *msg = ErrorText(status, json, err);
            if (done) done(msg ? nil : games, msg);
        }];
}

#pragma mark - Puzzles

// Tries with the token first; if the server refuses (e.g. a token without puzzle scopes), retries anonymously.
- (void)fetchPuzzlePath:(NSString *)path done:(LCResultBlock)done {
    [self call:path method:@"GET" form:nil done:^(id json, NSString *err) {
        BOOL network = err && [err rangeOfString:@"NSURLErrorDomain"].location != NSNotFound;
        if (err && _token.length && !network) {
            NSMutableURLRequest *r = [self request:path method:@"GET" form:nil timeout:30];
            [r setValue:nil forHTTPHeaderField:@"Authorization"];
            [LCConnection send:r insecure:_insecureTLS onDone:^(NSInteger status, id j, NSError *e) {
                NSString *m = ErrorText(status, j, e);
                if (done) done(m ? nil : (j ?: [NSDictionary dictionary]), m);
            }];
            return;
        }
        if (done) done(json, err);
    }];
}

- (void)fetchPuzzleById:(NSString *)pid done:(LCResultBlock)done {
    [self fetchPuzzlePath:[@"/api/puzzle/" stringByAppendingString:Escape(pid)] done:done];
}

- (void)fetchNextPuzzleAngle:(NSString *)angle difficulty:(NSString *)difficulty done:(LCResultBlock)done {
    NSMutableArray *q = [NSMutableArray array];
    if (angle.length) [q addObject:[@"angle=" stringByAppendingString:Escape(angle)]];
    if (difficulty.length) [q addObject:[@"difficulty=" stringByAppendingString:Escape(difficulty)]];
    NSString *path = @"/api/puzzle/next";
    if (q.count) path = [path stringByAppendingFormat:@"?%@", [q componentsJoinedByString:@"&"]];
    [self fetchPuzzlePath:path done:done];
}

- (void)fetchPuzzleDashboardDays:(int)days done:(LCResultBlock)done {
    [self call:[NSString stringWithFormat:@"/api/puzzle/dashboard/%d", days] method:@"GET" form:nil done:done];
}

- (void)fetchPuzzleActivity:(int)max done:(LCResultBlock)done {
    NSMutableURLRequest *r = [self request:[NSString stringWithFormat:@"/api/puzzle/activity?max=%d", max] method:@"GET" form:nil timeout:60];
    [r setValue:@"application/x-ndjson" forHTTPHeaderField:@"Accept"];
    NSMutableArray *rows = [NSMutableArray array];
    [LCConnection stream:r insecure:_insecureTLS
        onLine:^(id obj) { if ([obj isKindOfClass:[NSDictionary class]]) [rows addObject:obj]; }
        onDone:^(NSInteger status, id json, NSError *err) {
            NSString *msg = ErrorText(status, json, err);
            if (msg && (status == 401 || status == 403)) msg = @"Your token needs the puzzle:read scope. Create a new token (see the login screen).";
            if (done) done(msg ? nil : rows, msg);
        }];
}

- (void)importPGN:(NSString *)pgn done:(LCResultBlock)done {
    [self call:@"/api/import" method:@"POST" form:[NSDictionary dictionaryWithObject:pgn forKey:@"pgn"] done:done];
}

@end
