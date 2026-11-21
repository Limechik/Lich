#import <Foundation/Foundation.h>

// Puzzle theme catalogue. Groups: [ [ groupTitle, [ [key, name, description] ... ] ] ... ]
NSArray *LCPuzzleThemeGroups(void);
NSString *LCPuzzleThemeName(NSString *key);   // display name; falls back to a prettified key
