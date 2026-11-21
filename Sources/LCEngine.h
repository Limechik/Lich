// LCEngine.h - small alpha-beta chess engine for offline play (levels 1..8).
#ifndef LCENGINE_H
#define LCENGINE_H
#include "LCChess.h"
#ifdef __cplusplus
extern "C" {
#endif
// Returns 1 and fills *out with a legal move, 0 if the side to move has no legal moves.
// Thread-safe (no shared state). Seed with srand() for varied play at low levels.
int LCEngineBestMove(const LCPosition *p, int level, LCMove *out);
#ifdef __cplusplus
}
#endif
#endif
