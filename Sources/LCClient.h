// LCClient.h - Lichess HTTP API client (Board API + account), see https://lichess.org/api
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LCConnection.h"

typedef void (^LCResultBlock)(id json, NSString *errorMessage);

@interface LCClient : NSObject
+ (LCClient *)shared;

// Settings (persisted)
@property (nonatomic, copy) NSString *baseURL;        // default https://lichess.org
@property (nonatomic, assign) BOOL insecureTLS;       // accept any server certificate (see README)
@property (nonatomic, copy) NSString *token;          // personal API token / OAuth bearer (Keychain)
@property (nonatomic, copy) NSString *userId;         // lower-case account id
@property (nonatomic, copy) NSString *username;
@property (nonatomic, assign) BOOL guest;             // "continue without account" (offline modes + public endpoints)

- (void)logout;

// Account
- (void)fetchAccount:(LCResultBlock)done;                       // GET /api/account
- (void)fetchOngoing:(LCResultBlock)done;                       // GET /api/account/playing

// Streams (NDJSON). Keep the returned object and -cancel it when done.
- (LCConnection *)streamEvents:(LCJSONBlock)onEvent onEnd:(void (^)(NSString *err))onEnd;       // /api/stream/event
- (LCConnection *)streamGame:(NSString *)gameId onEvent:(LCJSONBlock)onEvent
                       onEnd:(void (^)(NSString *err))onEnd;                                     // /api/board/game/stream/{id}

// Playing
- (LCConnection *)seekMinutes:(double)minutes increment:(int)inc rated:(BOOL)rated color:(NSString *)color
                        onEnd:(void (^)(NSString *err))onEnd;                                    // POST /api/board/seek (held open)
- (void)challengeAILevel:(int)level limitSeconds:(int)limit increment:(int)inc
                   color:(NSString *)color done:(LCResultBlock)done;
- (void)challengeAILevel:(int)level limitSeconds:(int)limit increment:(int)inc
                   color:(NSString *)color fen:(NSString *)fen done:(LCResultBlock)done;               // fen: start from a custom position                             // POST /api/challenge/ai (limit < 0: no clock)
- (void)move:(NSString *)uci game:(NSString *)gameId done:(LCResultBlock)done;
- (void)resignGame:(NSString *)gameId done:(LCResultBlock)done;
- (void)abortGame:(NSString *)gameId done:(LCResultBlock)done;
- (void)drawGame:(NSString *)gameId accept:(BOOL)yes done:(LCResultBlock)done;

// Puzzles & TV (public endpoints)
- (void)fetchDailyPuzzle:(LCResultBlock)done;                                                   // GET /api/puzzle/daily
- (LCConnection *)streamTV:(NSString *)channel onEvent:(LCJSONBlock)onEvent
                     onEnd:(void (^)(NSString *err))onEnd;                                       // GET /api/tv/{channel}/feed

// Puzzles (all but the dashboard/activity work without an account)
- (void)fetchPuzzleById:(NSString *)pid done:(LCResultBlock)done;                                  // GET /api/puzzle/{id}
- (void)fetchNextPuzzleAngle:(NSString *)angle difficulty:(NSString *)difficulty done:(LCResultBlock)done;   // GET /api/puzzle/next
- (void)fetchPuzzleDashboardDays:(int)days done:(LCResultBlock)done;                              // GET /api/puzzle/dashboard/{days}   (puzzle:read)
- (void)fetchPuzzleActivity:(int)max done:(LCResultBlock)done;                                    // GET /api/puzzle/activity (NDJSON, puzzle:read)

- (void)importPGN:(NSString *)pgn done:(LCResultBlock)done;                                    // POST /api/import -> {id, url}

// Home feeds
- (void)fetchTournaments:(LCResultBlock)done;                       // GET /api/tournament   -> {created, started, finished}
- (void)fetchBlog:(LCResultBlock)done;                              // community blog Atom feed -> [ {title,url,date,author,image} ]
- (void)fetchImage:(NSString *)url done:(void (^)(UIImage *image))done;   // cover pictures (no auth header sent)
- (void)fetchRecentGames:(int)max done:(LCResultBlock)done;         // GET /api/games/user/{me} (NDJSON) -> [ game ]
@end
