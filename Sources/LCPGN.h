// LCPGN.h - PGN reader in plain C: tags + movetext of one game at a time.
#ifndef LCPGN_H
#define LCPGN_H
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char white[96], black[96], event[96], site[96], date[24], result[16];
    char fen[128], variant[32], termination[48], whiteElo[8], blackElo[8];
    int setup;                    // SetUp tag was "1"
} LCPGNTags;

// Reads the next game starting at *pos (advanced past it). Fills the tags and writes the moves as one
// space-separated SAN string: comments {..} ;.. , variations (..), NAGs $n, move numbers and !? marks removed.
// Returns 1 if a game was read, 0 when no more games.
int LCPGNReadGame(const char *text, size_t len, size_t *pos, LCPGNTags *tags, char *moves, size_t movesCap);

#ifdef __cplusplus
}
#endif
#endif
