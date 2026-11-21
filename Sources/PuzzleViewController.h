#import <UIKit/UIKit.h>

typedef enum {
    PuzzleModeDaily,     // GET /api/puzzle/daily
    PuzzleModeTheme,     // GET /api/puzzle/next?angle=<theme>, endless
    PuzzleModeById,      // GET /api/puzzle/{id} (from history)
    PuzzleModeStreak,    // client-side: harder and harder puzzles until the first mistake
    PuzzleModeStorm      // client-side: 3 minutes, as many puzzles as you can
} PuzzleMode;

@interface PuzzleViewController : UIViewController
- (id)initWithMode:(PuzzleMode)mode angle:(NSString *)angle puzzleId:(NSString *)pid title:(NSString *)title;
@end
