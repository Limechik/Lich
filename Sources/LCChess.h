// LCChess.h - minimal standard-chess rules engine in plain C.
// Square index: sq = rank*8 + file, a1 = 0, h8 = 63.
#ifndef LCCHESS_H
#define LCCHESS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char board[64];   // 'P','N','B','R','Q','K' white; lowercase black; 0 = empty
    int  whiteToMove; // 1 = white
    int  castle;      // bit0 K, bit1 Q, bit2 k, bit3 q
    int  ep;          // en-passant target square or -1
    int  lastFrom;    // last move squares for highlighting, -1 if none
    int  lastTo;
} LCPosition;

typedef struct {
    signed char from;
    signed char to;
    char promo;       // 0 or one of 'q','r','b','n'
} LCMove;

void LCPositionStart(LCPosition *p);
int  LCPositionFromFEN(LCPosition *p, const char *fen);               // 1 on success
int  LCPositionApplyUCI(LCPosition *p, const char *uci);              // 1 on success
int  LCPositionApplySAN(LCPosition *p, const char *san);              // e.g. "Nbd7", "exd5", "O-O", "e8=Q+"; 1 on success
int  LCLegalMoves(const LCPosition *p, LCMove *out);                  // returns count (<=256)
int  LCInCheck(const LCPosition *p, int white);
int  LCKingSquare(const LCPosition *p, int white);                    // -1 if absent
void LCMoveToUCI(LCMove m, char out[6]);
unsigned long long LCPerft(const LCPosition *p, int depth);
void LCPositionMakeMove(LCPosition *p, LCMove m);                     // no legality check (use moves from LCLegalMoves)
void LCMoveToSAN(const LCPosition *p, LCMove m, char out[16]);        // SAN of a legal move in position p
int  LCInsufficientMaterial(const LCPosition *p);                     // K v K, K+minor v K, same-colour bishops
void LCPositionKey(const LCPosition *p, char out[80]);                // repetition key (board, side, castling, ep)

// --- board editor helpers ---
void LCPositionToFEN(const LCPosition *p, char *out, int outSize);    // halfmove 0, fullmove 1
int  LCPositionValidate(const LCPosition *p, const char **reason);    // 1 = legal to play from; else *reason explains
int  LCCastlingAvailable(const LCPosition *p);                        // castling bits whose king and rook stand on their home squares
int  LCEnPassantFiles(const LCPosition *p);                           // bitmask of files where an en-passant target is plausible
void LCPositionClear(LCPosition *p);                                  // empty board, white to move, no rights

#ifdef __cplusplus
}
#endif
#endif
