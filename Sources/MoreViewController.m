#import "MoreViewController.h"
#import "LCUtil.h"
#import "AppDelegate.h"
#import "BoardAppearanceViewController.h"
#import "BoardEditorViewController.h"
#import "ClockViewController.h"
#import "PGNImportViewController.h"
#import "LCClient.h"

enum { SecTools, SecAccount, SecConnection, SecAbout };

@interface MoreViewController () <UIAlertViewDelegate>
@end

@implementation MoreViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"More";
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == SecTools ? 4 : 2; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    switch (s) { case SecTools: return @"Tools"; case SecAccount: return @"Account"; case SecConnection: return @"Connection"; default: return @"About"; }
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == SecConnection ? @"Use a proxy URL if iOS can't reach lichess.org directly (see README)." : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    LCClient *c = [LCClient shared];
    cell.accessoryView = nil; cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    switch (ip.section) {
        case SecTools:
            cell.textLabel.text = ip.row == 0 ? @"Board appearance" : (ip.row == 1 ? @"Board editor" : (ip.row == 2 ? @"Import PGN" : @"Clock"));
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case SecAccount: {
            BOOL guest = ![c.token length];
            if (ip.row == 0) { cell.textLabel.text = guest ? @"Mode" : @"Signed in as"; cell.detailTextLabel.text = guest ? @"Guest (offline)" : (c.username ?: @"-"); cell.selectionStyle = UITableViewCellSelectionStyleNone; }
            else if (guest) { cell.textLabel.text = @"Log in"; }
            else { cell.textLabel.text = @"Log out"; cell.textLabel.textColor = [UIColor redColor]; }
            break;
        }
        case SecConnection:
            if (ip.row == 0) { cell.textLabel.text = @"Server"; cell.detailTextLabel.text = c.baseURL; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
            else {
                cell.textLabel.text = @"Accept any TLS cert";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = c.insecureTLS;
                [sw addTarget:self action:@selector(tlsChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            break;
        default:
            if (ip.row == 0) { cell.textLabel.text = @"Open lichess.org"; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
            else { cell.textLabel.text = @"Version"; cell.detailTextLabel.text = @"1.0.0"; cell.selectionStyle = UITableViewCellSelectionStyleNone; }
            break;
    }
    return cell;
}

- (void)tlsChanged:(UISwitch *)sw { [LCClient shared].insecureTLS = sw.on; }

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == SecTools) {
        UIViewController *vc;
        switch (ip.row) {
            case 0: vc = [[BoardAppearanceViewController alloc] init]; break;
            case 1: vc = [[BoardEditorViewController alloc] init]; break;
            case 2: vc = [[PGNImportViewController alloc] init]; break;
            default: vc = [[ClockViewController alloc] init]; break;
        }
        [self.navigationController pushViewController:vc animated:YES];
    } else if (ip.section == SecAccount && ip.row == 1) {
        [[LCClient shared] logout];                  // also leaves guest mode
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] showLogin];
    } else if (ip.section == SecConnection && ip.row == 0) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Server" message:@"Base URL, e.g. https://lichess.org"
                                                   delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
        a.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *f = [a textFieldAtIndex:0];
        f.text = [LCClient shared].baseURL;
        f.keyboardType = UIKeyboardTypeURL;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        [a show];
    } else if (ip.section == SecAbout && ip.row == 0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://lichess.org"]];
    }
}

- (void)alertView:(UIAlertView *)av clickedButtonAtIndex:(NSInteger)idx {
    if (idx == av.cancelButtonIndex) return;
    NSString *t = [[av textFieldAtIndex:0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length) { [LCClient shared].baseURL = t; [self.tableView reloadData]; }
}

@end
