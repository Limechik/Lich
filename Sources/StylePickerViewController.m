#import "StylePickerViewController.h"
#import "LCUtil.h"

@implementation StylePickerViewController
@synthesize items, selectedId, onSelect;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return LCRotates(o); }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    NSDictionary *it = [self.items objectAtIndex:ip.row];
    cell.textLabel.text = [it objectForKey:@"title"];
    cell.imageView.image = [it objectForKey:@"image"];
    cell.accessoryType = [[it objectForKey:@"id"] isEqualToString:self.selectedId] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 52; }

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSString *chosen = [[self.items objectAtIndex:ip.row] objectForKey:@"id"];
    self.selectedId = chosen;
    if (self.onSelect) self.onSelect(chosen);
    [self.navigationController popViewControllerAnimated:YES];
}

@end
