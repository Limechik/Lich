// LCUtil.h - helpers. NOTE: no `dict[@"key"]` subscripting anywhere in this project:
// on an iOS 5 runtime it needs objectForKeyedSubscript: which only exists on iOS 6+.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Safe JSON accessor: returns nil for non-dictionaries, missing keys and JSON null.
static inline id LCGet(id dict, NSString *key) {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    id v = [(NSDictionary *)dict objectForKey:key];
    return (v == [NSNull null]) ? nil : v;
}
static inline NSString *LCStr(id dict, NSString *key) {
    id v = LCGet(dict, key);
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

// Orientation. Every screen allows portrait and both landscapes; upside-down only makes sense on iPad.
static inline BOOL LCIsPad(void) { return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad; }
static inline BOOL LCRotates(UIInterfaceOrientation o) {
    return LCIsPad() ? YES : (o != UIInterfaceOrientationPortraitUpsideDown);
}
// Height for a UIToolbar placed by hand: iPhone toolbars are shorter in landscape.
static inline CGFloat LCToolbarHeight(BOOL landscape) { return (landscape && !LCIsPad()) ? 32 : 44; }
