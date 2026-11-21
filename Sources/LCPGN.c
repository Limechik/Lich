#include "LCPGN.h"
#include <ctype.h>
#include <string.h>

static void copyTo(char *dst, size_t cap, const char *src, size_t n) {
    if (n >= cap) n = cap - 1;
    memcpy(dst, src, n);
    dst[n] = 0;
}

static int isResultToken(const char *t) {
    if (!strcmp(t, "1-0") || !strcmp(t, "0-1") || !strcmp(t, "1/2-1/2") || !strcmp(t, "*")) return 1;
    if ((unsigned char)t[0] == 0xC2 && (unsigned char)t[1] == 0xBD) return 1;      // "½-½"
    return 0;
}

static size_t skipSpace(const char *t, size_t len, size_t i) {
    while (i < len && isspace((unsigned char)t[i])) i++;
    return i;
}

static size_t skipBraceComment(const char *t, size_t len, size_t i) {   // t[i] == '{'
    i++;
    while (i < len && t[i] != '}') i++;
    return i < len ? i + 1 : i;
}

static size_t skipToEol(const char *t, size_t len, size_t i) {
    while (i < len && t[i] != '\n') i++;
    return i;
}

int LCPGNReadGame(const char *text, size_t len, size_t *pos, LCPGNTags *tags, char *moves, size_t movesCap) {
    size_t i = *pos, mlen = 0;
    memset(tags, 0, sizeof(*tags));
    if (movesCap) moves[0] = 0;

    // BOM, blank space and %-escape lines before the game
    if (i == 0 && len >= 3 && (unsigned char)text[0] == 0xEF && (unsigned char)text[1] == 0xBB && (unsigned char)text[2] == 0xBF) i = 3;
    for (;;) {
        i = skipSpace(text, len, i);
        if (i < len && text[i] == '%' && (i == 0 || text[i - 1] == '\n')) { i = skipToEol(text, len, i); continue; }
        break;
    }
    if (i >= len) { *pos = i; return 0; }

    int any = 0;

    // ---- tag pairs
    while (i < len && text[i] == '[') {
        any = 1;
        i++;
        size_t ks = i;
        while (i < len && !isspace((unsigned char)text[i]) && text[i] != ']') i++;
        char key[32]; copyTo(key, sizeof key, text + ks, i - ks);
        while (i < len && (text[i] == ' ' || text[i] == '\t')) i++;
        char val[160]; size_t vl = 0;
        if (i < len && text[i] == '"') {
            i++;
            while (i < len && text[i] != '"' && text[i] != '\n') {
                if (text[i] == '\\' && i + 1 < len) i++;
                if (vl < sizeof val - 1) val[vl++] = text[i];
                i++;
            }
            if (i < len && text[i] == '"') i++;
        }
        val[vl] = 0;
        i = skipToEol(text, len, i);
        if (!strcmp(key, "White")) copyTo(tags->white, sizeof tags->white, val, vl);
        else if (!strcmp(key, "Black")) copyTo(tags->black, sizeof tags->black, val, vl);
        else if (!strcmp(key, "Event")) copyTo(tags->event, sizeof tags->event, val, vl);
        else if (!strcmp(key, "Site")) copyTo(tags->site, sizeof tags->site, val, vl);
        else if (!strcmp(key, "Date") || !strcmp(key, "UTCDate")) { if (!tags->date[0] || !strcmp(key, "Date")) copyTo(tags->date, sizeof tags->date, val, vl); }
        else if (!strcmp(key, "Result")) copyTo(tags->result, sizeof tags->result, val, vl);
        else if (!strcmp(key, "FEN")) copyTo(tags->fen, sizeof tags->fen, val, vl);
        else if (!strcmp(key, "Variant")) copyTo(tags->variant, sizeof tags->variant, val, vl);
        else if (!strcmp(key, "Termination")) copyTo(tags->termination, sizeof tags->termination, val, vl);
        else if (!strcmp(key, "WhiteElo")) copyTo(tags->whiteElo, sizeof tags->whiteElo, val, vl);
        else if (!strcmp(key, "BlackElo")) copyTo(tags->blackElo, sizeof tags->blackElo, val, vl);
        else if (!strcmp(key, "SetUp")) tags->setup = (val[0] == '1');
        i = skipSpace(text, len, i);
    }

    // ---- movetext
    for (;;) {
        i = skipSpace(text, len, i);
        if (i >= len) break;
        char c = text[i];
        if (c == '[' && (i == 0 || text[i - 1] == '\n')) break;               // the next game's tags: this one had no result marker
        if (c == '{') { i = skipBraceComment(text, len, i); continue; }
        if (c == ';') { i = skipToEol(text, len, i); continue; }
        if (c == '%' && (i == 0 || text[i - 1] == '\n')) { i = skipToEol(text, len, i); continue; }
        if (c == '(') {                                                        // variation, possibly nested
            int depth = 1; i++;
            while (i < len && depth > 0) {
                if (text[i] == '{') { i = skipBraceComment(text, len, i); continue; }
                if (text[i] == ';') { i = skipToEol(text, len, i); continue; }
                if (text[i] == '(') depth++;
                else if (text[i] == ')') depth--;
                i++;
            }
            continue;
        }
        if (c == ')') { i++; continue; }
        if (c == '$') { i++; while (i < len && isdigit((unsigned char)text[i])) i++; continue; }

        size_t ts = i;
        while (i < len && !isspace((unsigned char)text[i]) && text[i] != '{' && text[i] != ';' && text[i] != '(' && text[i] != ')' && text[i] != '$') i++;
        char tok[48]; copyTo(tok, sizeof tok, text + ts, i - ts);
        any = 1;

        if (isResultToken(tok)) {
            if (!tags->result[0]) {
                const char *r = ((unsigned char)tok[0] == 0xC2) ? "1/2-1/2" : tok;
                copyTo(tags->result, sizeof tags->result, r, strlen(r));
            }
            if (mlen && moves[mlen - 1] == ' ') moves[--mlen] = 0;
            *pos = i;
            return 1;
        }
        const char *p = tok;
        if (isdigit((unsigned char)*p)) {                                      // "12." / "12..." / "12.e4"
            const char *q = p;
            while (isdigit((unsigned char)*q)) q++;
            if (*q == '.') { while (*q == '.') q++; p = q; }
            else if (*q == 0) continue;                                        // a bare number
        }
        size_t pl = strlen(p);
        while (pl && (p[pl - 1] == '!' || p[pl - 1] == '?')) pl--;             // annotation marks
        if (!pl) continue;
        if (mlen + pl + 2 >= movesCap) continue;                               // would not fit: drop the rest
        memcpy(moves + mlen, p, pl); mlen += pl;
        moves[mlen++] = ' '; moves[mlen] = 0;
    }
    if (mlen && moves[mlen - 1] == ' ') moves[--mlen] = 0;
    *pos = i;
    return any;
}
