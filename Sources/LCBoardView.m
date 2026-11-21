#import "LCBoardView.h"
#import "LCBoardStyle.h"

@implementation LCBoardView {
    int _selected;
    LCMove _moves[256];
    int _moveCount;
    int _dragFrom, _lastPaint;
    CGPoint _dragPoint;
    NSMutableArray *_arrows;        // NSNumber: from * 64 + to
    NSMutableArray *_circles;       // NSNumber: square
    int _shapeFrom;
    CGPoint _shapePoint;
    UIPanGestureRecognizer *_shapePan;
    UITapGestureRecognizer *_shapeTap;
}
@synthesize position = _position;

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor colorWithRed:0.71 green:0.53 blue:0.39 alpha:1];
        self.opaque = YES;
        self.contentMode = UIViewContentModeRedraw;
        self.multipleTouchEnabled = YES;
        _selected = -1; _dragFrom = -1; _lastPaint = -1; _shapeFrom = -1; _editTool = -2;
        _arrows = [NSMutableArray array]; _circles = [NSMutableArray array];
        LCPositionStart(&_position);
        [self recompute];

        _shapePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(shapePan:)];
        _shapePan.minimumNumberOfTouches = 2; _shapePan.maximumNumberOfTouches = 2;
        _shapeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(shapeTap:)];
        _shapeTap.numberOfTouchesRequired = 2;
        [self addGestureRecognizer:_shapePan];
        [self addGestureRecognizer:_shapeTap];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(styleChanged) name:LCBoardStyleDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)styleChanged { [self setNeedsDisplay]; }

- (void)recompute {
    _moveCount = _editMode ? 0 : LCLegalMoves(&_position, _moves);
}

- (void)setPosition:(LCPosition)p {
    _position = p;
    _selected = -1;
    [_arrows removeAllObjects]; [_circles removeAllObjects];    // annotations belong to one position
    [self recompute];
    [self setNeedsDisplay];
}

- (void)setFlipped:(BOOL)f { _flipped = f; [self setNeedsDisplay]; }
- (void)setInteractive:(BOOL)i { _interactive = i; if (!i) _selected = -1; [self setNeedsDisplay]; }
- (void)setEditMode:(BOOL)e {
    _editMode = e; _selected = -1; _dragFrom = -1;
    _shapePan.enabled = !e; _shapeTap.enabled = !e;
    [self recompute]; [self setNeedsDisplay];
}
- (void)setEditTool:(int)t { _editTool = t; _dragFrom = -1; [self setNeedsDisplay]; }

- (void)setArrows:(NSArray *)arrows circles:(NSArray *)circles {
    [_arrows setArray:arrows ?: [NSArray array]];
    [_circles setArray:circles ?: [NSArray array]];
    [self setNeedsDisplay];
}

- (void)clearShapes {
    if (!_arrows.count && !_circles.count) return;
    [_arrows removeAllObjects]; [_circles removeAllObjects];
    [self setNeedsDisplay];
}

#pragma mark - Geometry

// The squares area: the whole view, or inset when the frame is shown.
- (CGRect)boardRect {
    CGFloat w = self.bounds.size.width;
    CGFloat f = [LCBoardStyle shared].showFrame ? floor(w * 0.03) : 0;
    return CGRectMake(f, f, w - 2 * f, w - 2 * f);
}

- (CGRect)rectForSquare:(int)sq {
    CGRect b = [self boardRect];
    CGFloat s = b.size.width / 8.0;
    int f = sq & 7, r = sq >> 3;
    int col = _flipped ? 7 - f : f;
    int row = _flipped ? r : 7 - r;
    return CGRectMake(b.origin.x + col * s, b.origin.y + row * s, s, s);
}

- (int)squareAtPoint:(CGPoint)pt {
    CGRect b = [self boardRect];
    CGFloat s = b.size.width / 8.0;
    CGFloat x = pt.x - b.origin.x, y = pt.y - b.origin.y;
    if (x < 0 || y < 0 || x >= b.size.width || y >= b.size.width) return -1;
    int col = (int)(x / s), row = (int)(y / s);
    if (col < 0 || col > 7 || row < 0 || row > 7) return -1;
    int f = _flipped ? 7 - col : col;
    int r = _flipped ? row : 7 - row;
    return r * 8 + f;
}

#pragma mark - Drawing

+ (UIImage *)imageForPiece:(char)c { return [[LCBoardStyle shared] imageForPiece:c]; }

static NSString *GlyphForPiece(char c) {
    switch (c) {
        case 'K': return @"\u2654"; case 'Q': return @"\u2655"; case 'R': return @"\u2656";
        case 'B': return @"\u2657"; case 'N': return @"\u2658"; case 'P': return @"\u2659";
        case 'k': return @"\u265A"; case 'q': return @"\u265B"; case 'r': return @"\u265C";
        case 'b': return @"\u265D"; case 'n': return @"\u265E"; case 'p': return @"\u265F";
    }
    return @"";
}

- (void)drawPiece:(char)c inRect:(CGRect)r alpha:(CGFloat)alpha {
    UIImage *img = [LCBoardView imageForPiece:c];
    if (img) { [img drawInRect:r blendMode:kCGBlendModeNormal alpha:alpha]; return; }
    [[(c >= 'a' ? [UIColor blackColor] : [UIColor whiteColor]) colorWithAlphaComponent:alpha] set];
    [GlyphForPiece(c) drawInRect:r withFont:[UIFont systemFontOfSize:r.size.width * 0.85] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
}

// Arrow between two points, tip at `to`. `s` is the square size (scales the shaft and head).
static void DrawArrow(CGContextRef g, CGPoint from, CGPoint to, CGFloat s, UIColor *color) {
    CGFloat dx = to.x - from.x, dy = to.y - from.y, len = sqrt(dx * dx + dy * dy);
    if (len < s * 0.3) return;
    CGFloat ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
    CGFloat shaft = s * 0.16 / 2, headW = s * 0.30, headL = s * 0.40;
    CGPoint start = CGPointMake(from.x + ux * s * 0.15, from.y + uy * s * 0.15);
    CGPoint tip = CGPointMake(to.x - ux * s * 0.08, to.y - uy * s * 0.08);
    CGPoint base = CGPointMake(tip.x - ux * headL, tip.y - uy * headL);
    CGContextSetFillColorWithColor(g, [color colorWithAlphaComponent:0.85].CGColor);
    CGContextMoveToPoint(g, start.x + nx * shaft, start.y + ny * shaft);
    CGContextAddLineToPoint(g, base.x + nx * shaft, base.y + ny * shaft);
    CGContextAddLineToPoint(g, base.x + nx * headW, base.y + ny * headW);
    CGContextAddLineToPoint(g, tip.x, tip.y);
    CGContextAddLineToPoint(g, base.x - nx * headW, base.y - ny * headW);
    CGContextAddLineToPoint(g, base.x - nx * shaft, base.y - ny * shaft);
    CGContextAddLineToPoint(g, start.x - nx * shaft, start.y - ny * shaft);
    CGContextClosePath(g);
    CGContextFillPath(g);
}

static CGPoint CenterOf(CGRect r) { return CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)); }

- (void)drawRect:(CGRect)rect {
    CGContextRef g = UIGraphicsGetCurrentContext();
    LCBoardStyle *style = [LCBoardStyle shared];
    CGRect board = [self boardRect];
    CGFloat s = board.size.width / 8.0;
    UIColor *light = [style lightColor], *dark = [style darkColor];
    UIImage *texture = [style boardTexture];
    int king = (!_editMode && LCInCheck(&_position, _position.whiteToMove)) ? LCKingSquare(&_position, _position.whiteToMove) : -1;
    int hover = (_dragFrom >= 0) ? [self squareAtPoint:_dragPoint] : -1;

    if (style.showFrame) {                                       // frame: the dark square colour, darkened
        CGFloat comp[4]; [dark getRed:&comp[0] green:&comp[1] blue:&comp[2] alpha:&comp[3]];
        CGContextSetFillColorWithColor(g, [UIColor colorWithRed:comp[0] * 0.55 green:comp[1] * 0.55 blue:comp[2] * 0.55 alpha:1].CGColor);
        CGContextFillRect(g, self.bounds);
    }
    if (texture) [texture drawInRect:board];

    for (int sq = 0; sq < 64; sq++) {
        CGRect r = [self rectForSquare:sq];
        if (!texture) {
            BOOL isLight = (((sq >> 3) + (sq & 7)) % 2) == 1;
            CGContextSetFillColorWithColor(g, (isLight ? light : dark).CGColor);
            CGContextFillRect(g, r);
        }
        if (sq == _position.lastFrom || sq == _position.lastTo) {
            CGContextSetFillColorWithColor(g, [UIColor colorWithRed:0.61 green:0.78 blue:0 alpha:0.41].CGColor);
            CGContextFillRect(g, r);
        }
        if (sq == king) {
            CGContextSetFillColorWithColor(g, [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.65].CGColor);
            CGContextFillEllipseInRect(g, CGRectInset(r, s * 0.08, s * 0.08));
        }
        if (sq == _selected || sq == hover) {
            CGContextSetFillColorWithColor(g, [UIColor colorWithRed:0.08 green:0.33 blue:0.12 alpha:0.5].CGColor);
            CGContextFillRect(g, r);
        }
    }
    // coordinates
    if (style.showCoordinates) {
        UIFont *cf = [UIFont boldSystemFontOfSize:MAX(8, s * 0.2)];
        for (int i = 0; i < 8; i++) {
            int f = _flipped ? 7 - i : i;
            CGRect rf = [self rectForSquare:(_flipped ? 56 + f : f)];
            BOOL lightF = ((( _flipped ? 7 : 0) + f) % 2) == 1;
            [(lightF ? dark : light) set];
            [[NSString stringWithFormat:@"%c", 'a' + f] drawInRect:CGRectMake(rf.origin.x + s * 0.8, rf.origin.y + s * 0.74, s * 0.2, s * 0.25)
                                                          withFont:cf lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];
            int rk = _flipped ? 7 - i : i;
            CGRect rr = [self rectForSquare:(_flipped ? rk * 8 + 7 : rk * 8)];
            BOOL lightR = ((rk + (_flipped ? 7 : 0)) % 2) == 1;
            [(lightR ? dark : light) set];
            [[NSString stringWithFormat:@"%d", rk + 1] drawInRect:CGRectMake(rr.origin.x + s * 0.04, rr.origin.y + s * 0.02, s * 0.25, s * 0.25)
                                                          withFont:cf lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];
        }
    }
    // pieces (the one being dragged stays faintly on its square)
    for (int sq = 0; sq < 64; sq++) {
        char c = _position.board[sq];
        if (!c) continue;
        [self drawPiece:c inRect:[self rectForSquare:sq] alpha:(sq == _dragFrom ? 0.3 : 1.0)];
    }
    // legal destinations of the selected piece
    if (_selected >= 0) {
        for (int i = 0; i < _moveCount; i++) {
            if (_moves[i].from != _selected || (_moves[i].promo && _moves[i].promo != 'q')) continue;
            CGRect r = [self rectForSquare:_moves[i].to];
            BOOL capture = _position.board[_moves[i].to] != 0 ||
                           ((_position.board[_selected] | 0x20) == 'p' && _moves[i].to == _position.ep);
            if (capture) {
                CGContextSetStrokeColorWithColor(g, [UIColor colorWithRed:0.08 green:0.33 blue:0.12 alpha:0.6].CGColor);
                CGContextSetLineWidth(g, s * 0.09);
                CGContextStrokeEllipseInRect(g, CGRectInset(r, s * 0.08, s * 0.08));
            } else {
                CGContextSetFillColorWithColor(g, [UIColor colorWithRed:0.08 green:0.33 blue:0.12 alpha:0.5].CGColor);
                CGContextFillEllipseInRect(g, CGRectInset(r, s * 0.37, s * 0.37));
            }
        }
    }
    // hand-drawn annotations
    UIColor *shapeColor = [style shapeColor];
    for (NSNumber *c in _circles) {
        CGRect r = CGRectInset([self rectForSquare:[c intValue]], s * 0.07, s * 0.07);
        CGContextSetStrokeColorWithColor(g, [shapeColor colorWithAlphaComponent:0.85].CGColor);
        CGContextSetLineWidth(g, s * 0.07);
        CGContextStrokeEllipseInRect(g, r);
    }
    for (NSNumber *a in _arrows) {
        int code = [a intValue];
        DrawArrow(g, CenterOf([self rectForSquare:code / 64]), CenterOf([self rectForSquare:code % 64]), s, shapeColor);
    }
    if (_shapeFrom >= 0) DrawArrow(g, CenterOf([self rectForSquare:_shapeFrom]), _shapePoint, s, shapeColor);   // while dragging
    // the piece under the finger, enlarged and lifted so it stays visible
    if (_dragFrom >= 0) {
        char c = _position.board[_dragFrom];
        if (c) [self drawPiece:c inRect:CGRectMake(_dragPoint.x - s * 0.75, _dragPoint.y - s * 1.15, s * 1.5, s * 1.5) alpha:1.0];
    }
}

#pragma mark - Two-finger annotations

- (void)toggleArrowFrom:(int)a to:(int)b {
    NSNumber *k = [NSNumber numberWithInt:a * 64 + b];
    if ([_arrows containsObject:k]) [_arrows removeObject:k]; else [_arrows addObject:k];
}

- (void)toggleCircle:(int)sq {
    NSNumber *k = [NSNumber numberWithInt:sq];
    if ([_circles containsObject:k]) [_circles removeObject:k]; else [_circles addObject:k];
}

- (void)shapePan:(UIPanGestureRecognizer *)pan {
    if (_editMode) return;
    CGPoint pt = [pan locationInView:self];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint tr = [pan translationInView:self];               // the gesture starts after some movement: go back to where the fingers landed
            _shapeFrom = [self squareAtPoint:CGPointMake(pt.x - tr.x, pt.y - tr.y)];
            _shapePoint = pt;
            break;
        }
        case UIGestureRecognizerStateChanged: _shapePoint = pt; break;
        case UIGestureRecognizerStateEnded: {
            int from = _shapeFrom, to = [self squareAtPoint:pt];
            _shapeFrom = -1;
            if (from >= 0 && to >= 0) { if (from == to) [self toggleCircle:from]; else [self toggleArrowFrom:from to:to]; }
            break;
        }
        default: _shapeFrom = -1; break;
    }
    [self setNeedsDisplay];
}

- (void)shapeTap:(UITapGestureRecognizer *)tap {
    if (_editMode) return;
    int sq = [self squareAtPoint:[tap locationInView:self]];
    if (sq >= 0) { [self toggleCircle:sq]; [self setNeedsDisplay]; }
}

#pragma mark - Touch

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_editMode) { [super touchesBegan:touches withEvent:event]; return; }
    CGPoint pt = [[touches anyObject] locationInView:self];
    int sq = [self squareAtPoint:pt];
    _dragFrom = -1; _lastPaint = -1;
    if (sq < 0) return;
    if (_editTool == -2) {
        if (_position.board[sq]) { _dragFrom = sq; _dragPoint = pt; }
    } else {
        _lastPaint = sq;
        [self.editDelegate boardView:self paintSquare:sq];
    }
    [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_editMode) { [super touchesMoved:touches withEvent:event]; return; }
    CGPoint pt = [[touches anyObject] locationInView:self];
    if (_dragFrom >= 0) { _dragPoint = pt; [self setNeedsDisplay]; return; }
    if (_editTool != -2) {
        int sq = [self squareAtPoint:pt];
        if (sq >= 0 && sq != _lastPaint) { _lastPaint = sq; [self.editDelegate boardView:self paintSquare:sq]; }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    _dragFrom = -1; _lastPaint = -1;
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint pt = [[touches anyObject] locationInView:self];
    int sq = [self squareAtPoint:pt];

    if (_editMode) {
        if (_dragFrom >= 0) {
            int from = _dragFrom;
            _dragFrom = -1;
            [self setNeedsDisplay];
            if (sq != from) [self.editDelegate boardView:self movePieceFrom:from to:sq];   // sq == -1: dropped outside
        }
        _lastPaint = -1;
        return;
    }

    if ([[event allTouches] count] > 1) return;       // part of a two-finger gesture
    [self clearShapes];                               // a plain tap wipes the annotations
    if (!_interactive) return;
    if (sq < 0) return;
    char pc = _position.board[sq];
    BOOL own = pc && ((pc >= 'A' && pc <= 'Z') == (_position.whiteToMove != 0));

    if (_selected >= 0) {
        BOOL found = NO, promo = NO;
        for (int i = 0; i < _moveCount; i++)
            if (_moves[i].from == _selected && _moves[i].to == sq) { found = YES; if (_moves[i].promo) promo = YES; }
        if (found) {
            int from = _selected;
            _selected = -1;
            [self setNeedsDisplay];
            [self.delegate boardView:self moveFrom:from to:sq needsPromotion:promo];
            return;
        }
    }
    _selected = (own && sq != _selected) ? sq : -1;
    [self setNeedsDisplay];
}

@end
