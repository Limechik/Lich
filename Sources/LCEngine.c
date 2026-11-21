#include "LCEngine.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#define INF 1000000
#define MATE 30000

typedef struct { unsigned long nodes; clock_t deadline; int stop; } Ctx;

static int val(char c) {
    switch (toupper(c)) { case 'P': return 100; case 'N': return 320; case 'B': return 330; case 'R': return 500; case 'Q': return 900; }
    return 0;
}

// Score from the point of view of the side to move.
static int evaluate(const LCPosition *p) {
    int score = 0, nonPawn = 0, bishops[2] = {0, 0};
    for (int sq = 0; sq < 64; sq++) {
        char c = p->board[sq];
        if (c && toupper(c) != 'P' && toupper(c) != 'K') nonPawn += val(c);
    }
    int endgame = nonPawn < 2400;
    for (int sq = 0; sq < 64; sq++) {
        char c = p->board[sq];
        if (!c) continue;
        int w = (c >= 'A' && c <= 'Z'), f = sq & 7, r = sq >> 3;
        int cf = f < 4 ? f : 7 - f, cr = r < 4 ? r : 7 - r, cen = cf + cr, rel = w ? r : 7 - r;
        int s = val(c);
        switch (toupper(c)) {
            case 'P': s += rel * 6; if (f == 3 || f == 4) s += rel >= 2 ? 8 : 0; break;
            case 'N': s += cen * 7; if (f == 0 || f == 7) s -= 10; break;
            case 'B': s += cen * 3; bishops[w]++; break;
            case 'R': if (rel == 6) s += 15; break;
            case 'Q': s += cen; break;
            case 'K':
                if (endgame) s += cen * 8;
                else { s -= 20 * rel; if (f <= 2 || f >= 6) s += 20; }
                break;
        }
        score += w ? s : -s;
    }
    if (bishops[1] >= 2) score += 30;
    if (bishops[0] >= 2) score -= 30;
    return p->whiteToMove ? score : -score;
}

static int moveScore(const LCPosition *p, LCMove m) {
    char pc = p->board[(int)m.from], cap = p->board[(int)m.to];
    int s = 0;
    if (cap) s = 10000 + 10 * val(cap) - val(pc);
    else if (toupper(pc) == 'P' && m.to == p->ep && (m.from & 7) != (m.to & 7)) s = 10100;
    if (m.promo) s += 9000 + val(m.promo);
    return s;
}

static void order(const LCPosition *p, LCMove *mv, int n) {
    int sc[256];
    for (int i = 0; i < n; i++) sc[i] = moveScore(p, mv[i]);
    for (int i = 1; i < n; i++) {
        LCMove m = mv[i]; int s = sc[i], j = i - 1;
        while (j >= 0 && sc[j] < s) { mv[j + 1] = mv[j]; sc[j + 1] = sc[j]; j--; }
        mv[j + 1] = m; sc[j + 1] = s;
    }
}

static int tick(Ctx *c) {
    c->nodes++;
    if ((c->nodes & 1023) == 0 && clock() >= c->deadline) c->stop = 1;
    return c->stop;
}

static int quiesce(const LCPosition *p, int alpha, int beta, int ply, Ctx *c) {
    if (tick(c)) return 0;
    LCMove mv[256];
    int n = LCLegalMoves(p, mv);
    if (n == 0) return LCInCheck(p, p->whiteToMove) ? -MATE + ply : 0;
    int stand = evaluate(p);
    if (stand >= beta) return beta;
    if (stand > alpha) alpha = stand;
    if (ply >= 16) return alpha;
    LCMove caps[256]; int k = 0;
    for (int i = 0; i < n; i++)
        if (moveScore(p, mv[i]) >= 9000) caps[k++] = mv[i];
    order(p, caps, k);
    for (int i = 0; i < k; i++) {
        LCPosition q = *p;
        LCPositionMakeMove(&q, caps[i]);
        int s = -quiesce(&q, -beta, -alpha, ply + 1, c);
        if (c->stop) return 0;
        if (s >= beta) return beta;
        if (s > alpha) alpha = s;
    }
    return alpha;
}

static int negamax(const LCPosition *p, int depth, int alpha, int beta, int ply, Ctx *c) {
    if (c->stop) return 0;
    int inCheck = LCInCheck(p, p->whiteToMove);
    if (inCheck && ply < 8) depth++;
    if (depth <= 0) return quiesce(p, alpha, beta, ply, c);
    if (tick(c)) return 0;
    LCMove mv[256];
    int n = LCLegalMoves(p, mv);
    if (n == 0) return inCheck ? -MATE + ply : 0;
    order(p, mv, n);
    int best = -INF;
    for (int i = 0; i < n; i++) {
        LCPosition q = *p;
        LCPositionMakeMove(&q, mv[i]);
        int s = -negamax(&q, depth - 1, -beta, -alpha, ply + 1, c);
        if (c->stop) return 0;
        if (s > best) best = s;
        if (best > alpha) alpha = best;
        if (alpha >= beta) break;
    }
    return best;
}

int LCEngineBestMove(const LCPosition *p, int level, LCMove *out) {
    static const int depthFor[9]  = {0, 1, 1, 2, 2, 3, 3, 4, 5};
    static const int msFor[9]     = {0, 150, 150, 300, 400, 800, 1200, 2000, 3500};
    static const int noiseFor[9]  = {0, 350, 200, 120, 60, 30, 10, 0, 0};
    if (level < 1) level = 1;
    if (level > 8) level = 8;
    int maxDepth = depthFor[level], noise = noiseFor[level];

    LCMove mv[256];
    int n = LCLegalMoves(p, mv);
    if (n == 0) return 0;
    order(p, mv, n);
    *out = mv[0];
    if (n == 1) return 1;

    Ctx ctx; ctx.nodes = 0; ctx.stop = 0;
    ctx.deadline = clock() + (clock_t)((double)msFor[level] * CLOCKS_PER_SEC / 1000.0);

    for (int d = 1; d <= maxDepth; d++) {
        int scores[256], alpha = -INF, complete = 1;
        for (int i = 0; i < n; i++) {
            LCPosition q = *p;
            LCPositionMakeMove(&q, mv[i]);
            int s = (noise > 0) ? -negamax(&q, d - 1, -INF, INF, 1, &ctx)
                                : -negamax(&q, d - 1, -INF, -alpha, 1, &ctx);
            if (ctx.stop) { complete = 0; break; }
            scores[i] = s;
            if (s > alpha) alpha = s;
        }
        if (!complete) break;                       // keep the previous iteration's choice
        int bi = 0, bs = -INF * 2;
        for (int i = 0; i < n; i++) {
            int s = scores[i] + (noise > 0 ? (rand() % (2 * noise + 1)) - noise : 0);
            if (s > bs) { bs = s; bi = i; }
        }
        *out = mv[bi];
        if (noise == 0) {                           // search the best move first next time
            LCMove t = mv[0]; mv[0] = mv[bi]; mv[bi] = t;
            if (alpha > MATE - 100) break;          // forced mate found
        }
    }
    return 1;
}
