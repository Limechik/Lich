#include "LCChess.h"
#include <string.h>
#include <ctype.h>

static int isWhitePiece(char c) { return c >= 'A' && c <= 'Z'; }
static int isBlackPiece(char c) { return c >= 'a' && c <= 'z'; }

void LCPositionStart(LCPosition *p) {
    LCPositionFromFEN(p, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
}

int LCPositionFromFEN(LCPosition *p, const char *fen) {
    memset(p, 0, sizeof(*p));
    p->ep = -1; p->lastFrom = -1; p->lastTo = -1;
    int rank = 7, file = 0;
    const char *s = fen;
    for (; *s && *s != ' '; s++) {
        char c = *s;
        if (c == '/') { rank--; file = 0; if (rank < 0) return 0; }
        else if (c >= '1' && c <= '8') { file += c - '0'; }
        else if (strchr("PNBRQKpnbrqk", c)) {
            if (file > 7 || rank < 0) return 0;
            p->board[rank * 8 + file++] = c;
        } else return 0;
    }
    if (rank != 0) return 0;
    if (*s != ' ') { p->whiteToMove = 1; return 1; }
    s++;
    p->whiteToMove = (*s != 'b');
    while (*s && *s != ' ') s++;
    if (*s) s++;
    p->castle = 0;
    for (; *s && *s != ' '; s++) {
        if (*s == 'K') p->castle |= 1;
        else if (*s == 'Q') p->castle |= 2;
        else if (*s == 'k') p->castle |= 4;
        else if (*s == 'q') p->castle |= 8;
    }
    if (*s) s++;
    if (*s && *s != '-' && s[1] >= '1' && s[1] <= '8' && s[0] >= 'a' && s[0] <= 'h')
        p->ep = (s[1] - '1') * 8 + (s[0] - 'a');
    return 1;
}

int LCKingSquare(const LCPosition *p, int white) {
    char k = white ? 'K' : 'k';
    for (int i = 0; i < 64; i++) if (p->board[i] == k) return i;
    return -1;
}

static int attackedBy(const LCPosition *p, int sq, int byWhite) {
    int f = sq & 7, r = sq >> 3;
    // pawns
    int pr = byWhite ? r - 1 : r + 1;
    char pawn = byWhite ? 'P' : 'p';
    if (pr >= 0 && pr < 8) {
        if (f > 0 && p->board[pr * 8 + f - 1] == pawn) return 1;
        if (f < 7 && p->board[pr * 8 + f + 1] == pawn) return 1;
    }
    // knights
    static const int kn[8][2] = {{1,2},{2,1},{2,-1},{1,-2},{-1,-2},{-2,-1},{-2,1},{-1,2}};
    char knight = byWhite ? 'N' : 'n';
    for (int i = 0; i < 8; i++) {
        int nf = f + kn[i][0], nr = r + kn[i][1];
        if (nf >= 0 && nf < 8 && nr >= 0 && nr < 8 && p->board[nr * 8 + nf] == knight) return 1;
    }
    // king
    char king = byWhite ? 'K' : 'k';
    for (int df = -1; df <= 1; df++) for (int dr = -1; dr <= 1; dr++) {
        if (!df && !dr) continue;
        int nf = f + df, nr = r + dr;
        if (nf >= 0 && nf < 8 && nr >= 0 && nr < 8 && p->board[nr * 8 + nf] == king) return 1;
    }
    // sliders
    char rook = byWhite ? 'R' : 'r', bishop = byWhite ? 'B' : 'b', queen = byWhite ? 'Q' : 'q';
    static const int dirs[8][2] = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}};
    for (int d = 0; d < 8; d++) {
        int nf = f + dirs[d][0], nr = r + dirs[d][1];
        while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
            char c = p->board[nr * 8 + nf];
            if (c) {
                if (c == queen) return 1;
                if (d < 4 && c == rook) return 1;
                if (d >= 4 && c == bishop) return 1;
                break;
            }
            nf += dirs[d][0]; nr += dirs[d][1];
        }
    }
    return 0;
}

int LCInCheck(const LCPosition *p, int white) {
    int k = LCKingSquare(p, white);
    if (k < 0) return 0;
    return attackedBy(p, k, !white);
}

// Executes a move without legality checks (handles ep, castling, promotion, rights).
static void makeMove(LCPosition *p, int from, int to, char promo) {
    char piece = p->board[from];
    char captured = p->board[to];
    int white = isWhitePiece(piece);
    int newEp = -1;

    if ((piece == 'P' || piece == 'p') && to == p->ep && (from & 7) != (to & 7) && !captured) {
        int capSq = white ? to - 8 : to + 8;
        p->board[capSq] = 0;
    }
    if ((piece == 'P' || piece == 'p') && (to - from == 16 || from - to == 16))
        newEp = (from + to) / 2;

    p->board[to] = piece;
    p->board[from] = 0;

    if (piece == 'P' && (to >> 3) == 7) p->board[to] = promo ? (char)toupper(promo) : 'Q';
    if (piece == 'p' && (to >> 3) == 0) p->board[to] = promo ? (char)tolower(promo) : 'q';

    if (piece == 'K' || piece == 'k') {
        if (to - from == 2) { p->board[from + 1] = p->board[from + 3]; p->board[from + 3] = 0; }
        else if (from - to == 2) { p->board[from - 1] = p->board[from - 4]; p->board[from - 4] = 0; }
    }
    // castling rights
    if (piece == 'K') p->castle &= ~3;
    if (piece == 'k') p->castle &= ~12;
    if (from == 0 || to == 0) p->castle &= ~2;
    if (from == 7 || to == 7) p->castle &= ~1;
    if (from == 56 || to == 56) p->castle &= ~8;
    if (from == 63 || to == 63) p->castle &= ~4;

    p->ep = newEp;
    p->whiteToMove = !p->whiteToMove;
    p->lastFrom = from;
    p->lastTo = to;
}

static void addMove(LCMove *out, int *n, int from, int to, char promo) {
    out[*n].from = (signed char)from; out[*n].to = (signed char)to; out[*n].promo = promo; (*n)++;
}

static int pseudoMoves(const LCPosition *p, LCMove *out) {
    int n = 0, white = p->whiteToMove;
    for (int sq = 0; sq < 64; sq++) {
        char c = p->board[sq];
        if (!c || (white ? !isWhitePiece(c) : !isBlackPiece(c))) continue;
        int f = sq & 7, r = sq >> 3;
        char t = (char)toupper(c);
        if (t == 'P') {
            int dir = white ? 1 : -1, startRank = white ? 1 : 6, lastRank = white ? 7 : 0;
            int nr = r + dir;
            if (nr < 0 || nr > 7) continue;
            int to = nr * 8 + f;
            if (!p->board[to]) {
                if (nr == lastRank) { addMove(out,&n,sq,to,'q'); addMove(out,&n,sq,to,'r'); addMove(out,&n,sq,to,'b'); addMove(out,&n,sq,to,'n'); }
                else {
                    addMove(out,&n,sq,to,0);
                    int to2 = (r + 2 * dir) * 8 + f;
                    if (r == startRank && !p->board[to2]) addMove(out,&n,sq,to2,0);
                }
            }
            for (int df = -1; df <= 1; df += 2) {
                int nf = f + df;
                if (nf < 0 || nf > 7) continue;
                int cs = nr * 8 + nf;
                char tc = p->board[cs];
                int isCap = tc && (white ? isBlackPiece(tc) : isWhitePiece(tc));
                if (isCap || cs == p->ep) {
                    if (nr == lastRank) { addMove(out,&n,sq,cs,'q'); addMove(out,&n,sq,cs,'r'); addMove(out,&n,sq,cs,'b'); addMove(out,&n,sq,cs,'n'); }
                    else addMove(out,&n,sq,cs,0);
                }
            }
        } else if (t == 'N' || t == 'K') {
            static const int kn[8][2] = {{1,2},{2,1},{2,-1},{1,-2},{-1,-2},{-2,-1},{-2,1},{-1,2}};
            static const int kg[8][2] = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}};
            const int (*d)[2] = (t == 'N') ? kn : kg;
            for (int i = 0; i < 8; i++) {
                int nf = f + d[i][0], nr = r + d[i][1];
                if (nf < 0 || nf > 7 || nr < 0 || nr > 7) continue;
                char tc = p->board[nr * 8 + nf];
                if (tc && (white ? isWhitePiece(tc) : isBlackPiece(tc))) continue;
                addMove(out,&n,sq,nr*8+nf,0);
            }
            if (t == 'K') {
                int home = white ? 4 : 60;
                if (sq == home && !attackedBy(p, home, !white)) {
                    int ks = white ? 1 : 4, qs = white ? 2 : 8;
                    char rk = white ? 'R' : 'r';
                    if ((p->castle & ks) && p->board[home+3] == rk && !p->board[home+1] && !p->board[home+2]
                        && !attackedBy(p, home+1, !white) && !attackedBy(p, home+2, !white))
                        addMove(out,&n,sq,home+2,0);
                    if ((p->castle & qs) && p->board[home-4] == rk && !p->board[home-1] && !p->board[home-2] && !p->board[home-3]
                        && !attackedBy(p, home-1, !white) && !attackedBy(p, home-2, !white))
                        addMove(out,&n,sq,home-2,0);
                }
            }
        } else {
            static const int dirs[8][2] = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}};
            int d0 = (t == 'B') ? 4 : 0, d1 = (t == 'R') ? 4 : 8;
            for (int d = d0; d < d1; d++) {
                int nf = f + dirs[d][0], nr = r + dirs[d][1];
                while (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) {
                    char tc = p->board[nr * 8 + nf];
                    if (tc) {
                        if (white ? isBlackPiece(tc) : isWhitePiece(tc)) addMove(out,&n,sq,nr*8+nf,0);
                        break;
                    }
                    addMove(out,&n,sq,nr*8+nf,0);
                    nf += dirs[d][0]; nr += dirs[d][1];
                }
            }
        }
    }
    return n;
}

int LCLegalMoves(const LCPosition *p, LCMove *out) {
    LCMove pm[256];
    int pn = pseudoMoves(p, pm), n = 0;
    for (int i = 0; i < pn; i++) {
        LCPosition q = *p;
        makeMove(&q, pm[i].from, pm[i].to, pm[i].promo);
        if (!LCInCheck(&q, p->whiteToMove)) out[n++] = pm[i];
    }
    return n;
}

int LCPositionApplyUCI(LCPosition *p, const char *uci) {
    if (!uci || strlen(uci) < 4) return 0;
    if (uci[0] < 'a' || uci[0] > 'h' || uci[2] < 'a' || uci[2] > 'h') return 0;
    if (uci[1] < '1' || uci[1] > '8' || uci[3] < '1' || uci[3] > '8') return 0;
    int from = (uci[1] - '1') * 8 + (uci[0] - 'a');
    int to = (uci[3] - '1') * 8 + (uci[2] - 'a');
    char promo = (strlen(uci) >= 5) ? (char)tolower(uci[4]) : 0;
    if (!p->board[from]) return 0;
    makeMove(p, from, to, promo);
    return 1;
}

void LCMoveToUCI(LCMove m, char out[6]) {
    out[0] = 'a' + (m.from & 7); out[1] = '1' + (m.from >> 3);
    out[2] = 'a' + (m.to & 7);   out[3] = '1' + (m.to >> 3);
    if (m.promo) { out[4] = m.promo; out[5] = 0; } else out[4] = 0;
}

unsigned long long LCPerft(const LCPosition *p, int depth) {
    if (depth == 0) return 1;
    LCMove mv[256];
    int n = LCLegalMoves(p, mv);
    if (depth == 1) return (unsigned long long)n;
    unsigned long long total = 0;
    for (int i = 0; i < n; i++) {
        LCPosition q = *p;
        makeMove(&q, mv[i].from, mv[i].to, mv[i].promo);
        total += LCPerft(&q, depth - 1);
    }
    return total;
}

int LCPositionApplySAN(LCPosition *p, const char *san) {
    char s[24]; size_t n = 0;
    for (const char *q = san; q && *q && n < sizeof(s) - 1; q++) {
        if (*q == '+' || *q == '#' || *q == '!' || *q == '?' || *q == 'x' || *q == ':') continue;
        s[n++] = *q;
    }
    s[n] = 0;
    if (!n) return 0;
    LCMove mv[256];
    int cnt = LCLegalMoves(p, mv), pick = -1;

    if (!strncmp(s, "O-O", 3) || !strncmp(s, "0-0", 3)) {
        int queenSide = (n >= 5 && s[3] == '-');
        for (int i = 0; i < cnt; i++) {
            char pc = (char)toupper(p->board[(int)mv[i].from]);
            int d = mv[i].to - mv[i].from;
            if (pc == 'K' && d == (queenSide ? -2 : 2)) { pick = i; break; }
        }
    } else {
        char piece = 'P';
        char *c = s;
        if (strchr("NBRQK", *c)) piece = *c++;
        char promo = 0;
        char *eq = strchr(c, '=');
        if (eq) { promo = (char)tolower(eq[1]); *eq = 0; }
        size_t L = strlen(c);
        if (!eq && L >= 3 && strchr("QRBNqrbn", c[L - 1]) && c[L - 2] >= '1' && c[L - 2] <= '8') {
            promo = (char)tolower(c[L - 1]); c[--L] = 0;
        }
        if (L < 2) return 0;
        int tf = c[L - 2] - 'a', tr = c[L - 1] - '1';
        if (tf < 0 || tf > 7 || tr < 0 || tr > 7) return 0;
        int to = tr * 8 + tf, ff = -1, fr = -1;
        for (size_t i = 0; i + 2 < L; i++) {
            if (c[i] >= 'a' && c[i] <= 'h') ff = c[i] - 'a';
            else if (c[i] >= '1' && c[i] <= '8') fr = c[i] - '1';
        }
        for (int i = 0; i < cnt; i++) {
            int from = mv[i].from;
            if (mv[i].to != to) continue;
            if (toupper(p->board[from]) != piece) continue;
            if (ff >= 0 && (from & 7) != ff) continue;
            if (fr >= 0 && (from >> 3) != fr) continue;
            char want = promo;
            if (mv[i].promo && !want) want = 'q';
            if (mv[i].promo != want) continue;
            pick = i; break;
        }
    }
    if (pick < 0) return 0;
    char u[6];
    LCMoveToUCI(mv[pick], u);
    return LCPositionApplyUCI(p, u);
}

void LCPositionMakeMove(LCPosition *p, LCMove m) { makeMove(p, m.from, m.to, m.promo); }

void LCMoveToSAN(const LCPosition *p, LCMove m, char out[16]) {
    char piece = p->board[(int)m.from];
    char t = (char)toupper(piece);
    int n = 0;
    int capture = p->board[(int)m.to] != 0 || (t == 'P' && m.to == p->ep && (m.from & 7) != (m.to & 7));
    if (t == 'K' && (m.to - m.from == 2 || m.from - m.to == 2)) {
        const char *s = (m.to > m.from) ? "O-O" : "O-O-O";
        while (*s) out[n++] = *s++;
    } else {
        if (t == 'P') {
            if (capture) { out[n++] = (char)('a' + (m.from & 7)); }
        } else {
            out[n++] = t;
            LCMove all[256];
            int cnt = LCLegalMoves(p, all), sameFile = 0, sameRank = 0, other = 0;
            for (int i = 0; i < cnt; i++) {
                if (all[i].to != m.to || all[i].from == m.from || p->board[(int)all[i].from] != piece) continue;
                other = 1;
                if ((all[i].from & 7) == (m.from & 7)) sameFile = 1;
                if ((all[i].from >> 3) == (m.from >> 3)) sameRank = 1;
            }
            if (other) {
                if (!sameFile) out[n++] = (char)('a' + (m.from & 7));
                else if (!sameRank) out[n++] = (char)('1' + (m.from >> 3));
                else { out[n++] = (char)('a' + (m.from & 7)); out[n++] = (char)('1' + (m.from >> 3)); }
            }
        }
        if (capture) out[n++] = 'x';
        out[n++] = (char)('a' + (m.to & 7));
        out[n++] = (char)('1' + (m.to >> 3));
        if (m.promo) { out[n++] = '='; out[n++] = (char)toupper(m.promo); }
    }
    LCPosition q = *p;
    makeMove(&q, m.from, m.to, m.promo);
    if (LCInCheck(&q, q.whiteToMove)) {
        LCMove tmp[256];
        out[n++] = LCLegalMoves(&q, tmp) == 0 ? '#' : '+';
    }
    out[n] = 0;
}

int LCInsufficientMaterial(const LCPosition *p) {
    int minors = 0, bishopsW = 0, bishopsB = 0, bishopColorW = -1, bishopColorB = -1;
    for (int i = 0; i < 64; i++) {
        char c = p->board[i];
        if (!c) continue;
        char t = (char)toupper(c);
        if (t == 'P' || t == 'R' || t == 'Q') return 0;
        if (t == 'N' || t == 'B') minors++;
        if (t == 'B') {
            int col = ((i >> 3) + (i & 7)) & 1;
            if (c == 'B') { bishopsW++; bishopColorW = col; } else { bishopsB++; bishopColorB = col; }
        }
    }
    if (minors <= 1) return 1;
    if (minors == 2 && bishopsW == 1 && bishopsB == 1 && bishopColorW == bishopColorB) return 1;
    return 0;
}

void LCPositionKey(const LCPosition *p, char out[80]) {
    int n = 0;
    for (int i = 0; i < 64; i++) out[n++] = p->board[i] ? p->board[i] : '.';
    out[n++] = p->whiteToMove ? 'w' : 'b';
    out[n++] = (char)('A' + p->castle);
    out[n++] = (char)('a' + (p->ep < 0 ? 26 : (p->ep & 7)));   // ep file only (enough for repetition purposes)
    out[n] = 0;
}

void LCPositionClear(LCPosition *p) {
    memset(p, 0, sizeof(*p));
    p->whiteToMove = 1; p->ep = -1; p->lastFrom = -1; p->lastTo = -1;
}

void LCPositionToFEN(const LCPosition *p, char *out, int outSize) {
    char buf[96]; int n = 0;
    for (int r = 7; r >= 0; r--) {
        int empty = 0;
        for (int f = 0; f < 8; f++) {
            char c = p->board[r * 8 + f];
            if (!c) { empty++; continue; }
            if (empty) { buf[n++] = (char)('0' + empty); empty = 0; }
            buf[n++] = c;
        }
        if (empty) buf[n++] = (char)('0' + empty);
        if (r > 0) buf[n++] = '/';
    }
    buf[n++] = ' '; buf[n++] = p->whiteToMove ? 'w' : 'b'; buf[n++] = ' ';
    if (!p->castle) buf[n++] = '-';
    else {
        if (p->castle & 1) buf[n++] = 'K';
        if (p->castle & 2) buf[n++] = 'Q';
        if (p->castle & 4) buf[n++] = 'k';
        if (p->castle & 8) buf[n++] = 'q';
    }
    buf[n++] = ' ';
    if (p->ep >= 0) { buf[n++] = (char)('a' + (p->ep & 7)); buf[n++] = (char)('1' + (p->ep >> 3)); }
    else buf[n++] = '-';
    const char *tail = " 0 1";
    while (*tail) buf[n++] = *tail++;
    buf[n] = 0;
    strncpy(out, buf, (size_t)outSize);
    out[outSize - 1] = 0;
}

int LCCastlingAvailable(const LCPosition *p) {
    int m = 0;
    if (p->board[4] == 'K' && p->board[7] == 'R') m |= 1;
    if (p->board[4] == 'K' && p->board[0] == 'R') m |= 2;
    if (p->board[60] == 'k' && p->board[63] == 'r') m |= 4;
    if (p->board[60] == 'k' && p->board[56] == 'r') m |= 8;
    return m;
}

int LCEnPassantFiles(const LCPosition *p) {
    int mask = 0;
    for (int f = 0; f < 8; f++) {
        if (p->whiteToMove) {          // black pawn just made a double step: it stands on rank 5, target on rank 6
            if (p->board[4 * 8 + f] == 'p' && !p->board[5 * 8 + f] && !p->board[6 * 8 + f]) mask |= 1 << f;
        } else {                       // white pawn on rank 4, target on rank 3
            if (p->board[3 * 8 + f] == 'P' && !p->board[2 * 8 + f] && !p->board[1 * 8 + f]) mask |= 1 << f;
        }
    }
    return mask;
}

int LCPositionValidate(const LCPosition *p, const char **reason) {
    int wk = 0, bk = 0, wp = 0, bp = 0, wn = 0, bn = 0;
    for (int i = 0; i < 64; i++) {
        char c = p->board[i];
        if (!c) continue;
        if (c >= 'A' && c <= 'Z') wn++; else bn++;
        if (c == 'K') wk++; else if (c == 'k') bk++;
        else if (c == 'P') { wp++; if ((i >> 3) == 0 || (i >> 3) == 7) { *reason = "Pawns can't stand on the first or last rank"; return 0; } }
        else if (c == 'p') { bp++; if ((i >> 3) == 0 || (i >> 3) == 7) { *reason = "Pawns can't stand on the first or last rank"; return 0; } }
    }
    if (wk != 1 || bk != 1) { *reason = "Each side needs exactly one king"; return 0; }
    if (wp > 8 || bp > 8) { *reason = "A side can't have more than 8 pawns"; return 0; }
    if (wn > 16 || bn > 16) { *reason = "A side can't have more than 16 pieces"; return 0; }
    int a = LCKingSquare(p, 1), b = LCKingSquare(p, 0);
    int df = (a & 7) - (b & 7), dr = (a >> 3) - (b >> 3);
    if (df >= -1 && df <= 1 && dr >= -1 && dr <= 1) { *reason = "The kings can't be next to each other"; return 0; }
    if (LCInCheck(p, !p->whiteToMove)) { *reason = "The side that is not to move can't be in check"; return 0; }
    return 1;
}
