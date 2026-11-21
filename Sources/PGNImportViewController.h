#import <UIKit/UIKit.h>

// Paste (or open from a .pgn file) one or many games, then step through them.
@interface PGNImportViewController : UIViewController
- (id)initWithText:(NSString *)text;     // opens the result straight away when the text holds games
@end
