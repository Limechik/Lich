#import "LoginViewController.h"
#import "LCUtil.h"
#import "AppDelegate.h"
#import "LCClient.h"

@interface LoginViewController () <UITextFieldDelegate> {
    UITextField *_token, *_server;
    UISwitch *_insecure;
    UIButton *_loginButton;
    UIActivityIndicatorView *_spinner;
    UIScrollView *_scroll;       // the form scrolls, because a landscape iPhone is too short to show all of it
    UIView *_form;               // fixed-width column, centred
    UITextField *_active;
}
@end

static const CGFloat kFormWidth = 360, kFormHeight = 420;

@implementation LoginViewController

- (UITextField *)fieldAt:(CGFloat)y placeholder:(NSString *)ph {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(20, y, kFormWidth - 40, 36)];
    f.borderStyle = UITextBorderStyleRoundedRect;
    f.placeholder = ph;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    f.delegate = self;
    return f;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Lich";
    self.view.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1];
    CGFloat W = kFormWidth;
    LCClient *c = [LCClient shared];

    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.view addSubview:_scroll];
    _form = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kFormWidth, kFormHeight)];
    [_scroll addSubview:_form];
    UIView *host = _form;                              // everything below goes into the form column

    UILabel *help = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, W - 40, 80)];
    help.numberOfLines = 0; help.backgroundColor = [UIColor clearColor]; help.font = [UIFont systemFontOfSize:13];
    help.textColor = [UIColor darkGrayColor];
    help.text = @"Sign in with a Lichess personal API token. Create one with the scopes “board:play”, “challenge:write” and “puzzle:read” (tap the button below).";
    [host addSubview:help];

    UIButton *open = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    open.frame = CGRectMake(20, 90, W - 40, 36);
    [open setTitle:@"Open token page in Safari" forState:UIControlStateNormal];
    [open addTarget:self action:@selector(openTokenPage) forControlEvents:UIControlEventTouchUpInside];
    [host addSubview:open];

    _token = [self fieldAt:136 placeholder:@"API token (lip_…)"];
    _token.secureTextEntry = YES;
    _token.returnKeyType = UIReturnKeyNext;
    [host addSubview:_token];

    _server = [self fieldAt:180 placeholder:@"Server (default https://lichess.org)"];
    _server.keyboardType = UIKeyboardTypeURL;
    _server.returnKeyType = UIReturnKeyDone;
    _server.text = c.baseURL;
    [host addSubview:_server];

    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(20, 228, W - 100, 30)];
    sl.backgroundColor = [UIColor clearColor]; sl.font = [UIFont systemFontOfSize:14];
    sl.text = @"Accept any TLS certificate";
    [host addSubview:sl];
    _insecure = [[UISwitch alloc] initWithFrame:CGRectMake(W - 99, 228, 79, 27)];
    _insecure.on = c.insecureTLS;
    [host addSubview:_insecure];

    _loginButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _loginButton.frame = CGRectMake(20, 272, W - 40, 44);
    [_loginButton setTitle:@"Log in" forState:UIControlStateNormal];
    [_loginButton addTarget:self action:@selector(login) forControlEvents:UIControlEventTouchUpInside];
    [host addSubview:_loginButton];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.center = CGPointMake(W / 2, 336); _spinner.hidesWhenStopped = YES;
    [host addSubview:_spinner];

    UIButton *guest = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    guest.frame = CGRectMake(20, 360, W - 40, 40);
    [guest setTitle:@"Continue without account" forState:UIControlStateNormal];
    [guest addTarget:self action:@selector(continueAsGuest) forControlEvents:UIControlEventTouchUpInside];
    [host addSubview:guest];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    CGFloat W = _scroll.bounds.size.width;
    _form.frame = CGRectMake(floor((W - kFormWidth) / 2), 0, kFormWidth, kFormHeight);
    _scroll.contentSize = CGSizeMake(W, kFormHeight);
}

- (void)keyboardWillShow:(NSNotification *)n {
    CGRect kb = [[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    kb = [self.view convertRect:kb fromView:nil];
    CGFloat covered = MAX(0, CGRectGetMaxY(self.view.bounds) - kb.origin.y);
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, covered, 0);
    _scroll.contentInset = insets; _scroll.scrollIndicatorInsets = insets;
    if (_active) [_scroll scrollRectToVisible:CGRectInset([_form convertRect:_active.frame toView:_scroll], 0, -24) animated:YES];
}

- (void)keyboardWillHide:(NSNotification *)n {
    _scroll.contentInset = UIEdgeInsetsZero; _scroll.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)textFieldDidBeginEditing:(UITextField *)f {
    _active = f;
    [_scroll scrollRectToVisible:CGRectInset(f.frame, 0, -24) animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)f { if (_active == f) _active = nil; }

- (void)continueAsGuest {
    [self.view endEditing:YES];
    [LCClient shared].guest = YES;
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] showHome];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (BOOL)textFieldShouldReturn:(UITextField *)f {
    if (f == _token) [_server becomeFirstResponder]; else [f resignFirstResponder];
    return NO;
}

- (void)openTokenPage {
    NSString *base = [LCClient shared].baseURL;
    NSString *u = [base stringByAppendingString:@"/account/oauth/token/create?scopes%5B%5D=board%3Aplay&scopes%5B%5D=challenge%3Awrite&scopes%5B%5D=puzzle%3Aread&description=Lichess+iOS+5"];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:u]];
}

- (void)login {
    [self.view endEditing:YES];
    NSString *tok = [_token.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!tok.length) {
        [[[UIAlertView alloc] initWithTitle:@"Token required" message:@"Paste your Lichess API token." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    LCClient *c = [LCClient shared];
    NSString *srv = [_server.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    c.baseURL = srv.length ? srv : @"https://lichess.org";
    c.insecureTLS = _insecure.on;
    c.token = tok;
    _loginButton.enabled = NO; [_spinner startAnimating];
    [c fetchAccount:^(id json, NSString *err) {
        [_spinner stopAnimating]; _loginButton.enabled = YES;
        if (err) {
            [LCClient shared].token = nil;
            NSString *msg = err;
            if ([err rangeOfString:@"authorized"].location == NSNotFound)
                msg = [err stringByAppendingString:@"\n\nIf this is an SSL/TLS error: iOS 5 can't talk to lichess.org directly. See README (proxy / TLS option)."];
            [[[UIAlertView alloc] initWithTitle:@"Login failed" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] showHome];
    }];
}

@end
