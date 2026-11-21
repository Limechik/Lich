#import <Foundation/Foundation.h>

// Turns PGN text into game dictionaries shaped like the ones from /api/games/user, so GameReplayViewController can show them.
// Keys: players {white,black}{user{name},rating}, moves (SAN), status, winner, initialFen, variant,
//       pgn (raw text of this game), event, site, date, result, plies (readable half-moves), error (if replay stopped early)
@interface LCPGNImporter : NSObject
+ (NSArray *)gamesFromText:(NSString *)text;           // up to 200 games
+ (BOOL)isPlayable:(NSDictionary *)game;               // standard chess / from position
@end
