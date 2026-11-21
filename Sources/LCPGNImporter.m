#import "LCPGNImporter.h"
#import "LCChess.h"
#import "LCPGN.h"
#import "LCUtil.h"
#import <stdlib.h>

static NSString *Str(const char *s) { return [NSString stringWithUTF8String:s] ?: @""; }

static NSDictionary *Player(NSString *name, NSString *elo) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:[NSDictionary dictionaryWithObject:name.length ? name : @"?" forKey:@"name"] forKey:@"user"];
    if (elo.length && [elo intValue] > 0) [d setObject:[NSNumber numberWithInt:[elo intValue]] forKey:@"rating"];
    return d;
}

@implementation LCPGNImporter

+ (BOOL)isPlayable:(NSDictionary *)game {
    NSString *v = [[LCStr(game, @"variant") lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
    return !v.length || [v isEqualToString:@"standard"] || [v isEqualToString:@"fromposition"] || [v isEqualToString:@"chess"];
}

+ (NSArray *)gamesFromText:(NSString *)text {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *games = [NSMutableArray array];
    if (!data.length) return games;
    const char *bytes = data.bytes;
    size_t len = data.length, pos = 0;
    char *moves = malloc(65536);
    LCPGNTags t;

    while (games.count < 200) {
        size_t start = pos;
        if (!LCPGNReadGame(bytes, len, &pos, &t, moves, 65536)) break;
        NSString *movesStr = Str(moves);
        NSString *result = Str(t.result);

        // Replay to count readable plies and to notice unreadable moves.
        LCPosition p;
        NSString *fen = Str(t.fen);
        if (!(fen.length && LCPositionFromFEN(&p, [fen UTF8String]))) { LCPositionStart(&p); fen = nil; }
        int plies = 0; NSString *error = nil;
        for (NSString *san in [movesStr componentsSeparatedByString:@" "]) {
            if (!san.length) continue;
            if (!LCPositionApplySAN(&p, [san UTF8String])) { error = [NSString stringWithFormat:@"Can't read move “%@” (move %d)", san, plies / 2 + 1]; break; }
            plies++;
        }
        if (plies == 0 && !error && !movesStr.length && !t.white[0] && !t.black[0] && !t.event[0]) continue;   // stray text, not a game

        NSMutableDictionary *g = [NSMutableDictionary dictionary];
        [g setObject:[NSDictionary dictionaryWithObjectsAndKeys:Player(Str(t.white), Str(t.whiteElo)), @"white", Player(Str(t.black), Str(t.blackElo)), @"black", nil] forKey:@"players"];
        [g setObject:movesStr forKey:@"moves"];
        [g setObject:[NSNumber numberWithInt:plies] forKey:@"plies"];
        if (fen.length) [g setObject:fen forKey:@"initialFen"];
        if (error) [g setObject:error forKey:@"error"];
        [g setObject:result forKey:@"result"];
        [g setObject:Str(t.event) forKey:@"event"];
        [g setObject:Str(t.site) forKey:@"site"];
        [g setObject:Str(t.date) forKey:@"date"];
        if (t.variant[0]) [g setObject:Str(t.variant) forKey:@"variant"];

        // result -> winner / status in the vocabulary GameReplayViewController understands
        NSString *status = @"";
        if ([result isEqualToString:@"1-0"]) [g setObject:@"white" forKey:@"winner"];
        else if ([result isEqualToString:@"0-1"]) [g setObject:@"black" forKey:@"winner"];
        else if ([result isEqualToString:@"1/2-1/2"]) status = @"draw";
        if ([g objectForKey:@"winner"]) {
            NSString *lastMove = [[movesStr componentsSeparatedByString:@" "] lastObject];
            NSString *term = [Str(t.termination) lowercaseString];
            if ([term rangeOfString:@"time"].location != NSNotFound) status = @"timeout";
            else if ([lastMove hasSuffix:@"#"]) status = @"mate";
            else status = @"unknown";
        }
        [g setObject:status forKey:@"status"];

        NSString *raw = [[NSString alloc] initWithBytes:bytes + start length:pos - start encoding:NSUTF8StringEncoding];
        raw = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (raw.length) [g setObject:raw forKey:@"pgn"];
        [games addObject:g];
    }
    free(moves);
    return games;
}

@end
