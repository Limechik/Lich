# Lich — a Lichess client for iOS 5.1

A native Objective-C client for [Lichess](https://lichess.org), built with [Theos](https://theos.dev) for jailbroken devices running **iOS 5.x** (iPhone 3GS and newer, iPad 1 and newer).

It talks to the [Lichess Board API](https://github.com/lichess-org/api). Screens and behaviour follow [lichess-org/mobile](https://github.com/lichess-org/mobile) (Flutter, GPL-3.0), but the code is **written from scratch** for iOS 5.1, since Dart/Flutter does not run on iOS 5.

> Unofficial project. Not affiliated with or endorsed by Lichess.

## Features

### Playing
- **Online games** via quick pairing (seek). Time controls from 10+0 up, casual or rated. The Board API only allows rapid and classical for seeks (about 8+ minutes estimated), so the app checks this up front and shows the control type (Bullet / Blitz / Rapid …).
- **Custom game** (Home → Custom game…): choose opponent, time control, colour and strength.

  | Opponent | Description | Account needed |
  |---|---|---|
  | Online | Live player on lichess.org, custom control (¼–180 min, 0–180 s increment), rated or casual, colour | yes |
  | Lichess AI | Stockfish on lichess.org, levels 1–8, clock optional | yes |
  | Offline AI | Built-in engine, levels 1–8, clock optional | no |
  | 2 players | Two people on one device, clock optional | no |

- **Game board:** last-move, check and legal-move highlights, promotion, castling, en passant, local ticking clocks, resign / abort, draw offers, board flip, automatic reconnect of the game stream. Draw arrows and circles with two fingers.
- **Offline mode:** full rules (check, mate, stalemate, castling, en passant), draws by insufficient material, the 50-move rule and threefold repetition. SAN move recording, clocks with increment and flag, undo, resign, draw by agreement. The game is saved after every move and can be resumed.
- **Guest mode** ("Continue without account"): offline games, daily puzzle, Lichess TV and Learn links. You can sign in later.

### Home
Casual / Rated switch and a grid of time controls (1+0, 2+1, 3+0, 3+2, 5+0, 5+3, 10+0, 10+5, 15+10, 30+0, 30+20). Below it:
- **In progress:** resume the offline game and your ongoing online games
- **Open tournaments:** running and upcoming arenas (opens in Safari)
- **Blog:** swipeable cards from the Lichess community blog
- **Recent games:** your last 10 games with a replay viewer (|< < > >| and flip)

Bullet and blitz tiles (1+0 … 5+3) cannot be used for online pairing through the Board API, so they offer Lichess AI, the offline computer (level 3) or a two-player game instead.

### Puzzles
Daily puzzle, 60 puzzle themes (endless series per theme), **Puzzle Streak**, **Puzzle Storm**, dashboard (7 / 30 / 90 days) and history. Themes, Streak and Storm also work without an account.

### Watch and Learn
- **Watch:** Lichess TV (Top Rated, Bullet, Blitz, Rapid, Classical, UltraBullet, Bots, Computer) with a live board and clocks.
- **Learn:** links to Lichess lessons (open in Safari, since the lessons are web apps).

### Tools (More → Tools)
- **Board appearance:** 20 board styles (5 solid colours + 15 Lichess textures), 13 piece sets (Cburnett, Pirouetti, Merida, Chessnut, MPChess, Kiwen-suwi, RhosGFX, Fantasy, Spatial, Celtic, Pixel, Letter, Shapes), shape colour, coordinates and frame. Live preview; applies to every board in the app.
- **Board editor:** drag-and-drop piece placement, side to move, castling rights and en passant (only valid options are offered), load / copy FEN, analyse on lichess.org, and **Play from this position** against Lichess AI, the offline engine or a friend. The position is validated first and saved automatically.
- **Import PGN:** paste a PGN and open it in the viewer. Reads tags, comments, variations, NAGs, FEN / SetUp, up to 200 games at once. An unreadable move does not break the game: moves before it are shown together with the error. **Analyse** sends the game to Lichess (`POST /api/import`) and opens the analysis in Safari. `.pgn` files can also be opened from Safari, Mail and other apps via "Open in…".
- **Clock:** a two-player chess clock on one device. The top half is rotated for the opponent; tap your half after your move. Time from ¼ to 180 min per player, increment 0–180 s, presets from 1+0 to 30+20. The screen stays awake while the clock is open.

### Orientation and iPad
Every screen works in portrait and landscape (iPad also upside-down). In landscape the board moves to the left and the players, clocks, move list and buttons sit beside it. The login form scrolls so the keyboard never covers it.

### Theme
Tan navigation bars (`#DEB887`) and a dark wooden background behind the list screens. The bar colour is set once in `LCTheme.m` (`barColor`).

## Limitations
- Standard chess only; variants are rejected with a message.
- No chat, takebacks, Chess960 or in-app analysis (Analyse opens lichess.org in Safari).
- The public API has no endpoint for Streak / Storm runs or for submitting solved puzzles, so those modes are implemented on the client with rules close to the originals. Results are **not** sent to Lichess, and your puzzle rating and history are unaffected.
- The offline engine is not Stockfish: negamax with alpha-beta, quiescence search and iterative deepening. Levels 1–2 play with a lot of noise; 7–8 search 4–5 plies. A strong amateur can beat it.

## Requirements
- A jailbroken iPhone / iPad on iOS 5.x
- To build: [Theos](https://theos.dev) with `iPhoneOS5.1.sdk` in `$THEOS/sdks`

## Build
```sh
export THEOS=~/theos        # iPhoneOS5.1.sdk must be in $THEOS/sdks
make package
```
The `.deb` appears in `packages/`; install it with Cydia or `dpkg -i`.

Build settings: `ARCHS = armv7`, `TARGET = iphone:clang:5.1:5.0`, ARC enabled. The application name in the Makefile is `Lichess5`, so the executable and the `Lichess5.app` folder keep that name, while the name on the home screen is **Lich**.

Bundle ID: `org.lime.chess`. This is a **new app** as far as iOS is concerned: it does not see data from the earlier `org.example.lichess5` build, so you have to sign in again. If you see black bars or an old launch screen after updating, delete the old install and install again to clear the cached launch image.

## API token
Create a personal token with the scopes `board:play`, `challenge:write` and `puzzle:read`:

https://lichess.org/account/oauth/token/create?scopes[]=board:play&scopes[]=challenge:write&scopes[]=puzzle:read&description=iOS5

The "Open token page in Safari" button on the login screen opens this page. You can create the token on a computer and paste it on the device. It is stored in the Keychain (with a fallback to `NSUserDefaults`). The dashboard and history need `puzzle:read`; an older token without it gives an error, so create a new one.

## Project layout
| Path | Purpose |
|---|---|
| `Sources/LCChess.c/.h` | Chess rules in plain C (verified with perft: start position d4 = 197281, Kiwipete d3 = 97862, …) |
| `Sources/LCEngine.c` | Offline engine |
| `Sources/LCPGN.c` | PGN parser (tested) |
| `Sources/LCConnection` | `NSURLConnection` plus NDJSON stream parsing (there is no `NSURLSession` on iOS 5) |
| `Sources/LCClient` | REST client: account, event / game streams, seek, move, resign, abort, draw, challenge/ai, puzzles |
| `Sources/LCBoardView` | Core Graphics board and touch handling |
| `Sources/LCTheme.m`, `LCWoodTableViewController` | Bars, wooden background |
| `Sources/LCIcons.m` | Tab bar icons drawn in code |
| `Sources/LCSegmentCell` | Table cell that fits a segmented control to its width |
| `Resources/` | `Info.plist`, app icons, launch images, `styles.plist`, `boards/`, `pieces/`, `wood_background.jpg` |
| `control`, `Makefile` | Package metadata and Theos build file |

## License and credits
The project is intended to be distributed under **GPL-3.0**, like lichess-org/mobile.

Piece sets and board textures come from [lichess-org/lila](https://github.com/lichess-org/lila). Only sets with GPL-compatible licences are included; sets under CC BY-NC-SA or "personal use" terms (California, Maestro, Cardinal, Alpha, Leipzig, …) are not. Authors and licences are listed in [`ASSETS_LICENSES.md`](ASSETS_LICENSES.md).
