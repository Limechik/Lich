#import <UIKit/UIKit.h>
#import "LCChess.h"

@class LCBoardView;
@protocol LCBoardViewDelegate <NSObject>
// Called with a legal move chosen by tapping. needsPromotion = the move is a pawn promotion.
- (void)boardView:(LCBoardView *)view moveFrom:(int)from to:(int)to needsPromotion:(BOOL)promo;
@end

// Used in edit mode (board editor).
@protocol LCBoardEditDelegate <NSObject>
- (void)boardView:(LCBoardView *)view paintSquare:(int)sq;                  // piece / erase tool touched a square (also while dragging over)
- (void)boardView:(LCBoardView *)view movePieceFrom:(int)from to:(int)to;   // move tool: piece dragged; to == -1 means dropped outside the board
@end

@interface LCBoardView : UIView
@property (nonatomic, weak) id<LCBoardViewDelegate> delegate;
@property (nonatomic, weak) id<LCBoardEditDelegate> editDelegate;
@property (nonatomic, assign) BOOL flipped;        // YES = black at the bottom
@property (nonatomic, assign) BOOL interactive;    // only when it's the user's turn
@property (nonatomic, assign) BOOL editMode;       // free editing instead of legal-move play
@property (nonatomic, assign) int editTool;        // -2: drag pieces around, any other value: "paint" (the editor interprets it)
@property (nonatomic, assign) LCPosition position;
+ (UIImage *)imageForPiece:(char)c;                 // from the current piece set
// Hand-drawn annotations (two-finger drag = arrow, two-finger tap = circle). Codes: arrow = from*64+to, circle = square.
- (void)setArrows:(NSArray *)arrows circles:(NSArray *)circles;
- (void)clearShapes;
@end
