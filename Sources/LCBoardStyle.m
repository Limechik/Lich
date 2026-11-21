#import "LCBoardStyle.h"

NSString *const LCBoardStyleDidChangeNotification = @"LCBoardStyleDidChange";

static NSString *const kBoard = @"lc.style.board";
static NSString *const kPieces = @"lc.style.pieces";
static NSString *const kCoords = @"lc.style.coords";
static NSString *const kFrame = @"lc.style.frame";
static NSString *const kShape = @"lc.style.shape";

static UIColor *HexColor(NSString *hex) {
    unsigned v = 0;
    [[NSScanner scannerWithString:[hex hasPrefix:@"#"] ? [hex substringFromIndex:1] : hex] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 255) / 255.0 green:((v >> 8) & 255) / 255.0 blue:(v & 255) / 255.0 alpha:1];
}

@implementation LCBoardStyle {
    NSArray *_boards, *_pieceSets, *_shapeColors;
    NSString *_boardId, *_pieceSetId;
    BOOL _coords, _frame;
    int _shape;
    NSMutableDictionary *_pieceCache;
    UIImage *_textureCache;
    NSString *_textureCacheId;
}

+ (LCBoardStyle *)shared {
    static LCBoardStyle *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[LCBoardStyle alloc] init]; });
    return s;
}

- (id)init {
    if ((self = [super init])) {
        NSDictionary *cat = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"styles" ofType:@"plist"]];
        _boards = [cat objectForKey:@"boards"] ?: [NSArray array];
        _pieceSets = [cat objectForKey:@"pieces"] ?: [NSArray array];
        _shapeColors = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"Green", @"name", HexColor(@"#15781B"), @"color", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:@"Red", @"name", HexColor(@"#882020"), @"color", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:@"Blue", @"name", HexColor(@"#003088"), @"color", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:@"Yellow", @"name", HexColor(@"#E68F00"), @"color", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:@"Purple", @"name", HexColor(@"#6A1B9A"), @"color", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:@"Orange", @"name", HexColor(@"#E65100"), @"color", nil], nil];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _boardId = [d stringForKey:kBoard] ?: @"brown";
        _pieceSetId = [d stringForKey:kPieces] ?: @"cburnett";
        _coords = [d objectForKey:kCoords] ? [d boolForKey:kCoords] : YES;
        _frame = [d boolForKey:kFrame];
        _shape = (int)[d integerForKey:kShape];
        if (_shape < 0 || _shape >= (int)_shapeColors.count) _shape = 0;
        _pieceCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)changed { [[NSNotificationCenter defaultCenter] postNotificationName:LCBoardStyleDidChangeNotification object:self]; }

#pragma mark - Settings

- (NSArray *)boards { return _boards; }
- (NSArray *)pieceSets { return _pieceSets; }
- (NSArray *)shapeColors { return _shapeColors; }

- (NSString *)boardId { return _boardId; }
- (void)setBoardId:(NSString *)b {
    _boardId = [b copy]; _textureCache = nil; _textureCacheId = nil;
    [[NSUserDefaults standardUserDefaults] setObject:_boardId forKey:kBoard];
    [self changed];
}
- (NSString *)pieceSetId { return _pieceSetId; }
- (void)setPieceSetId:(NSString *)p {
    _pieceSetId = [p copy];
    [[NSUserDefaults standardUserDefaults] setObject:_pieceSetId forKey:kPieces];
    [self changed];
}
- (BOOL)showCoordinates { return _coords; }
- (void)setShowCoordinates:(BOOL)v { _coords = v; [[NSUserDefaults standardUserDefaults] setBool:v forKey:kCoords]; [self changed]; }
- (BOOL)showFrame { return _frame; }
- (void)setShowFrame:(BOOL)v { _frame = v; [[NSUserDefaults standardUserDefaults] setBool:v forKey:kFrame]; [self changed]; }
- (int)shapeColorIndex { return _shape; }
- (void)setShapeColorIndex:(int)i { _shape = i; [[NSUserDefaults standardUserDefaults] setInteger:i forKey:kShape]; [self changed]; }

#pragma mark - Lookups

- (NSDictionary *)boardEntry:(NSString *)bid {
    for (NSDictionary *b in _boards) if ([[b objectForKey:@"id"] isEqualToString:bid]) return b;
    return [_boards count] ? [_boards objectAtIndex:0] : nil;
}

- (NSString *)boardName { return [[self boardEntry:_boardId] objectForKey:@"name"] ?: @"Brown"; }

- (NSString *)pieceSetName {
    for (NSDictionary *p in _pieceSets) if ([[p objectForKey:@"id"] isEqualToString:_pieceSetId]) return [p objectForKey:@"name"];
    return @"Cburnett";
}

- (UIColor *)lightColor { NSString *h = [[self boardEntry:_boardId] objectForKey:@"light"]; return h ? HexColor(h) : [UIColor colorWithRed:0.94 green:0.85 blue:0.71 alpha:1]; }
- (UIColor *)darkColor { NSString *h = [[self boardEntry:_boardId] objectForKey:@"dark"]; return h ? HexColor(h) : [UIColor colorWithRed:0.71 green:0.53 blue:0.39 alpha:1]; }
- (UIColor *)shapeColor { return [[_shapeColors objectAtIndex:_shape] objectForKey:@"color"]; }

- (UIImage *)loadTexture:(NSString *)file {
    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"jpg" inDirectory:@"boards"];
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

- (UIImage *)boardTexture {
    NSString *file = [[self boardEntry:_boardId] objectForKey:@"file"];
    if (!file) return nil;
    if (!_textureCache || ![_textureCacheId isEqualToString:file]) { _textureCache = [self loadTexture:file]; _textureCacheId = file; }
    return _textureCache;
}

- (UIImage *)imageForPiece:(char)c { return [self imageForPiece:c inSet:_pieceSetId]; }

- (UIImage *)imageForPiece:(char)c inSet:(NSString *)setId {
    NSString *name = [NSString stringWithFormat:@"%c%c", (c >= 'a' ? 'b' : 'w'), (c >= 'a' ? c - 32 : c)];
    NSString *key = [NSString stringWithFormat:@"%@/%@", setId, name];
    UIImage *img = [_pieceCache objectForKey:key];
    if (img) return img;
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"png" inDirectory:[@"pieces/" stringByAppendingString:setId]];
    if (!path && ![setId isEqualToString:@"cburnett"]) return [self imageForPiece:c inSet:@"cburnett"];
    img = path ? [UIImage imageWithContentsOfFile:path] : nil;
    if (img) [_pieceCache setObject:img forKey:key];
    return img;
}

#pragma mark - Swatches

- (UIImage *)swatchForBoard:(NSDictionary *)board size:(CGFloat)side {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, 0);
    CGContextRef g = UIGraphicsGetCurrentContext();
    NSString *file = [board objectForKey:@"file"];
    UIImage *tex = file ? [self loadTexture:file] : nil;
    if (tex) {                                                   // top-left 2x2 squares of the texture
        CGFloat q = tex.size.width / 4;
        CGImageRef part = CGImageCreateWithImageInRect(tex.CGImage, CGRectMake(0, 0, q * tex.scale, q * tex.scale));
        if (part) { [[UIImage imageWithCGImage:part] drawInRect:CGRectMake(0, 0, side, side)]; CGImageRelease(part); }
    } else {
        UIColor *l = HexColor([board objectForKey:@"light"]), *d = HexColor([board objectForKey:@"dark"]);
        CGFloat h = side / 2;
        CGContextSetFillColorWithColor(g, l.CGColor); CGContextFillRect(g, CGRectMake(0, 0, h, h)); CGContextFillRect(g, CGRectMake(h, h, h, h));
        CGContextSetFillColorWithColor(g, d.CGColor); CGContextFillRect(g, CGRectMake(h, 0, h, h)); CGContextFillRect(g, CGRectMake(0, h, h, h));
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)swatchForSet:(NSString *)setId height:(CGFloat)h {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(h * 2, h), NO, 0);
    [[self imageForPiece:'N' inSet:setId] drawInRect:CGRectMake(0, 0, h, h)];
    [[self imageForPiece:'n' inSet:setId] drawInRect:CGRectMake(h, 0, h, h)];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)swatchForColor:(UIColor *)color size:(CGFloat)side {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
    CGContextRef g = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(g, color.CGColor);
    CGContextFillEllipseInRect(g, CGRectMake(2, 2, side - 4, side - 4));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
