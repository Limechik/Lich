#import "PGNImportViewController.h"
#import "GameReplayViewController.h"
#import "LCPGNImporter.h"
#import "LCUtil.h"
#import "PGNGamesViewController.h"

@interface PGNImportViewController () <UITextViewDelegate> {
    UITextView *_text;
    UILabel *_placeholder;
    UIToolbar *_toolbar;
    NSString *_initial;
    BOOL _autoOpen;
    CGFloat _kb;
}
@end

@implementation PGNImportViewController

- (id)init { return [self initWithText:nil]; }

- (id)initWithText:(NSString *)text {
    if ((self = [super init])) {
        self.title = @"Import PGN";
        self.hidesBottomBarWhenPushed = YES;
        _initial = [text copy];
        _autoOpen = text.length > 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    _text = [[UITextView alloc] init];
    _text.font = [UIFont fontWithName:@"Courier" size:13];
    _text.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _text.autocorrectionType = UITextAutocorrectionTypeNo;
    _text.delegate = self;
    _text.text = _initial ?: @"";
    [self.view addSubview:_text];

    _placeholder = [[UILabel alloc] init];
    _placeholder.text = @"Paste a PGN here (one game or many),\nor tap Paste.";
    _placeholder.numberOfLines = 2;
    _placeholder.textColor = [UIColor colorWithWhite:0.55 alpha:1];
    _placeholder.backgroundColor = [UIColor clearColor];
    _placeholder.font = [UIFont systemFontOfSize:14];
    _placeholder.userInteractionEnabled = NO;
    _placeholder.hidden = _text.text.length > 0;
    [self.view addSubview:_placeholder];

    _toolbar = [[UIToolbar alloc] init];
    _toolbar.barStyle = UIBarStyleBlack;
    UIBarButtonItem *paste = [[UIBarButtonItem alloc] initWithTitle:@"Paste" style:UIBarButtonItemStyleBordered target:self action:@selector(pasteTapped)];
    UIBarButtonItem *clear = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStyleBordered target:self action:@selector(clearTapped)];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Hide keyboard" style:UIBarButtonItemStyleBordered target:self action:@selector(hideKeyboard)];
    UIBarButtonItem *sp = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    _toolbar.items = [NSArray arrayWithObjects:paste, clear, sp, done, nil];
    [self.view addSubview:_toolbar];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Open" style:UIBarButtonItemStyleBordered target:self action:@selector(openTapped)];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)layoutNow {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height, tb = 44;
    _toolbar.frame = CGRectMake(0, H - tb - _kb, W, tb);
    _text.frame = CGRectMake(0, 0, W, H - tb - _kb);
    _placeholder.frame = CGRectMake(14, 12, W - 28, 40);
}

- (void)viewDidLayoutSubviews { [self layoutNow]; }

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_autoOpen) { _autoOpen = NO; [self openTapped]; }
}

- (void)keyboardChanged:(NSNotification *)n {
    BOOL show = [n.name isEqualToString:UIKeyboardWillShowNotification];
    CGRect kb = [[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    kb = [self.view convertRect:kb fromView:nil];
    _kb = show ? MAX(0, CGRectGetMaxY(self.view.bounds) - kb.origin.y) : 0;
    [UIView animateWithDuration:0.25 animations:^{ [self layoutNow]; }];
}

- (void)textViewDidChange:(UITextView *)tv { _placeholder.hidden = tv.text.length > 0; }

- (void)pasteTapped {
    NSString *s = [UIPasteboard generalPasteboard].string;
    if (!s.length) { [self alert:@"Clipboard is empty" message:@"Copy a PGN first, then tap Paste."]; return; }
    _text.text = s; _placeholder.hidden = YES;
}

- (void)clearTapped { _text.text = @""; _placeholder.hidden = NO; }
- (void)hideKeyboard { [_text resignFirstResponder]; }

- (void)alert:(NSString *)t message:(NSString *)m {
    [[[UIAlertView alloc] initWithTitle:t message:m delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)openTapped {
    [_text resignFirstResponder];
    NSArray *games = [LCPGNImporter gamesFromText:_text.text];
    if (!games.count) { [self alert:@"No game found" message:@"The text doesn't contain a readable PGN."]; return; }
    if (games.count > 1) { [self.navigationController pushViewController:[[PGNGamesViewController alloc] initWithGames:games] animated:YES]; return; }
    NSDictionary *g = [games objectAtIndex:0];
    if (![LCPGNImporter isPlayable:g]) { [self alert:@"Variant not supported" message:@"Only standard chess games can be replayed here."]; return; }
    if ([LCGet(g, @"plies") intValue] == 0) { [self alert:@"No moves" message:LCStr(g, @"error") ?: @"This game has no readable moves."]; return; }
    [self.navigationController pushViewController:[[GameReplayViewController alloc] initWithGame:g] animated:YES];
}

@end
