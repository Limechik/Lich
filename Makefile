ARCHS = armv7
TARGET = iphone:clang:5.1:5.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Lichess5
Lichess5_FILES = Sources/main.m Sources/AppDelegate.m Sources/LoginViewController.m \
	Sources/HomeViewController.m Sources/GameViewController.m Sources/LCBoardView.m \
	Sources/LCClient.m Sources/LCConnection.m Sources/LCChess.c Sources/LCEngine.c \
	Sources/LCIcons.m Sources/PuzzleViewController.m Sources/LearnViewController.m \
	Sources/WatchViewController.m Sources/TVViewController.m Sources/MoreViewController.m \
	Sources/LocalGameViewController.m Sources/CustomGameViewController.m \
	Sources/LCAtomParser.m Sources/GameReplayViewController.m \
	Sources/LCPuzzleThemes.m Sources/PuzzlesHomeViewController.m Sources/PuzzleThemesViewController.m \
	Sources/PuzzleDashboardViewController.m Sources/PuzzleHistoryViewController.m \
	Sources/BoardEditorViewController.m Sources/EditorOptionsViewController.m \
	Sources/LCBoardStyle.m Sources/BoardAppearanceViewController.m Sources/StylePickerViewController.m \
	Sources/LCTheme.m Sources/LCWoodTableViewController.m \
	Sources/LCPGN.c Sources/LCPGNImporter.m Sources/PGNImportViewController.m Sources/PGNGamesViewController.m \
	Sources/ClockViewController.m Sources/ClockSettingsViewController.m \
	Sources/LCSegmentCell.m
Lichess5_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore Security AudioToolbox
Lichess5_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk
