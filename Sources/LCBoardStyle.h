#import <UIKit/UIKit.h>

// Posted (on the main thread) whenever any board appearance setting changes.
extern NSString *const LCBoardStyleDidChangeNotification;

// Board appearance: board theme, piece set, coordinates, frame and the colour of hand-drawn shapes.
// Catalogue lives in Resources/styles.plist, images in Resources/boards and Resources/pieces/<set>.
@interface LCBoardStyle : NSObject
+ (LCBoardStyle *)shared;

@property (nonatomic, copy) NSString *boardId;
@property (nonatomic, copy) NSString *pieceSetId;
@property (nonatomic, assign) BOOL showCoordinates;
@property (nonatomic, assign) BOOL showFrame;
@property (nonatomic, assign) int shapeColorIndex;

@property (nonatomic, readonly) NSArray *boards;        // [ {id, name, file?, light, dark} ]
@property (nonatomic, readonly) NSArray *pieceSets;     // [ {id, name} ]
@property (nonatomic, readonly) NSArray *shapeColors;   // [ {name, color} ]

- (NSString *)boardName;
- (NSString *)pieceSetName;
- (UIColor *)lightColor;                                // current board's squares (also used for coordinates)
- (UIColor *)darkColor;
- (UIImage *)boardTexture;                              // nil for plain two-colour themes
- (UIColor *)shapeColor;

- (UIImage *)imageForPiece:(char)c;                     // 'K','q',... in the current set
- (UIImage *)imageForPiece:(char)c inSet:(NSString *)setId;
- (UIImage *)swatchForBoard:(NSDictionary *)board size:(CGFloat)side;   // 2x2 squares preview
- (UIImage *)swatchForSet:(NSString *)setId height:(CGFloat)h;          // white knight + black knight
- (UIImage *)swatchForColor:(UIColor *)color size:(CGFloat)side;
@end
