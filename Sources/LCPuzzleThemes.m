#import "LCPuzzleThemes.h"

static NSArray *T(NSString *key, NSString *name, NSString *desc) { return [NSArray arrayWithObjects:key, name, desc, nil]; }
static NSArray *G(NSString *title, NSArray *items) { return [NSArray arrayWithObjects:title, items, nil]; }

NSArray *LCPuzzleThemeGroups(void) {
    static NSArray *groups;
    if (groups) return groups;
    groups = [NSArray arrayWithObjects:
        G(@"Phases", [NSArray arrayWithObjects:
            T(@"opening", @"Opening", @"Tactics in the first moves of the game"),
            T(@"middlegame", @"Middlegame", @"Tactics in the middle of the game"),
            T(@"endgame", @"Endgame", @"Tactics with only a few pieces left"),
            T(@"rookEndgame", @"Rook endgame", @"Endgames with rooks and pawns only"),
            T(@"bishopEndgame", @"Bishop endgame", @"Endgames with bishops and pawns only"),
            T(@"pawnEndgame", @"Pawn endgame", @"Endgames with pawns only"),
            T(@"knightEndgame", @"Knight endgame", @"Endgames with knights and pawns only"),
            T(@"queenEndgame", @"Queen endgame", @"Endgames with queens and pawns only"),
            T(@"queenRookEndgame", @"Queen and rook", @"Endgames with queens, rooks and pawns"), nil]),
        G(@"Motifs", [NSArray arrayWithObjects:
            T(@"advancedPawn", @"Advanced pawn", @"A pawn close to promotion is the key"),
            T(@"attackingF2F7", @"Attacking f2 or f7", @"An attack on the f2 or f7 pawn"),
            T(@"capturingDefender", @"Capture the defender", @"Remove the piece that guards something"),
            T(@"discoveredAttack", @"Discovered attack", @"Move a piece to unleash another one behind it"),
            T(@"doubleCheck", @"Double check", @"Check with two pieces at once"),
            T(@"exposedKing", @"Exposed king", @"A king with few defenders is attacked"),
            T(@"fork", @"Fork", @"One piece attacks two or more at once"),
            T(@"hangingPiece", @"Hanging piece", @"An undefended or insufficiently defended piece"),
            T(@"kingsideAttack", @"Kingside attack", @"Attack against the king on the kingside"),
            T(@"pin", @"Pin", @"A piece cannot move without exposing a more valuable one"),
            T(@"queensideAttack", @"Queenside attack", @"Attack against the king on the queenside"),
            T(@"sacrifice", @"Sacrifice", @"Give up material for a bigger gain"),
            T(@"skewer", @"Skewer", @"A valuable piece is forced to move, exposing another"),
            T(@"trappedPiece", @"Trapped piece", @"A piece has no safe squares to escape"), nil]),
        G(@"Advanced", [NSArray arrayWithObjects:
            T(@"attraction", @"Attraction", @"Lure a piece onto a bad square"),
            T(@"clearance", @"Clearance", @"Move a piece to free a square or line"),
            T(@"defensiveMove", @"Defensive move", @"A precise move to avoid losing material"),
            T(@"deflection", @"Deflection", @"Distract a piece from an important duty"),
            T(@"interference", @"Interference", @"Block the line between two enemy pieces"),
            T(@"intermezzo", @"Intermezzo", @"An in-between move before the expected one"),
            T(@"quietMove", @"Quiet move", @"A move that makes no check or capture but sets up a threat"),
            T(@"xRayAttack", @"X-ray attack", @"A piece attacks or defends through an enemy piece"),
            T(@"zugzwang", @"Zugzwang", @"Every legal move makes the position worse"), nil]),
        G(@"Checkmates", [NSArray arrayWithObjects:
            T(@"mate", @"Checkmate", @"Win the game with a checkmate"),
            T(@"mateIn1", @"Mate in 1", @"Checkmate in one move"),
            T(@"mateIn2", @"Mate in 2", @"Checkmate in two moves"),
            T(@"mateIn3", @"Mate in 3", @"Checkmate in three moves"),
            T(@"mateIn4", @"Mate in 4", @"Checkmate in four moves"),
            T(@"mateIn5", @"Mate in 5 or more", @"Long forced checkmates"),
            T(@"anastasiaMate", @"Anastasia's mate", @"Knight and rook trap the king on the edge"),
            T(@"arabianMate", @"Arabian mate", @"Knight and rook trap the king in the corner"),
            T(@"backRankMate", @"Back rank mate", @"Mate on the back rank, the king blocked by its own pawns"),
            T(@"bodenMate", @"Boden's mate", @"Two bishops on crossing diagonals mate the king"),
            T(@"doubleBishopMate", @"Double bishop mate", @"Two bishops on adjacent diagonals mate the king"),
            T(@"dovetailMate", @"Dovetail mate", @"A queen mates a king whose escape squares are blocked"),
            T(@"hookMate", @"Hook mate", @"Rook, knight and pawn mate with a rook hook"),
            T(@"smotheredMate", @"Smothered mate", @"A knight mates a king surrounded by its own pieces"), nil]),
        G(@"Special moves", [NSArray arrayWithObjects:
            T(@"castling", @"Castling", @"Castle to defend or attack"),
            T(@"enPassant", @"En passant", @"A pawn captures a pawn that just passed it"),
            T(@"promotion", @"Promotion", @"Promote a pawn to a stronger piece"),
            T(@"underPromotion", @"Underpromotion", @"Promote to a knight, bishop or rook"), nil]),
        G(@"Goals", [NSArray arrayWithObjects:
            T(@"advantage", @"Advantage", @"Seize your chance to get a decisive advantage"),
            T(@"crushing", @"Crushing", @"Spot the opponent's blunder and crush them"),
            T(@"equality", @"Equality", @"Come back from a losing position to equal"), nil]),
        G(@"Length", [NSArray arrayWithObjects:
            T(@"oneMove", @"One-move puzzle", @"A puzzle that is only one move long"),
            T(@"short", @"Short puzzle", @"Two moves to win"),
            T(@"long", @"Long puzzle", @"Three moves to win"),
            T(@"veryLong", @"Very long puzzle", @"Four moves or more to win"), nil]),
        G(@"Origin", [NSArray arrayWithObjects:
            T(@"master", @"Master games", @"Puzzles from games played by titled players"),
            T(@"masterVsMaster", @"Master vs Master", @"Puzzles from games between two titled players"),
            T(@"superGM", @"Super GM games", @"Puzzles from games of the best players in the world"), nil]),
        nil];
    return groups;
}

NSString *LCPuzzleThemeName(NSString *key) {
    static NSDictionary *names;
    if (!names) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (NSArray *g in LCPuzzleThemeGroups())
            for (NSArray *t in [g objectAtIndex:1]) [d setObject:[t objectAtIndex:1] forKey:[t objectAtIndex:0]];
        names = d;
    }
    NSString *n = [names objectForKey:key];
    if (n) return n;
    // Fallback: "someTheme" -> "Some theme"
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < key.length; i++) {
        unichar ch = [key characterAtIndex:i];
        if (i > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:ch]) [s appendString:@" "];
        unichar out = (i == 0) ? (unichar)toupper(ch) : (unichar)tolower(ch);
        [s appendString:[NSString stringWithCharacters:&out length:1]];
    }
    return s;
}
