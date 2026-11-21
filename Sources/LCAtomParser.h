#import <Foundation/Foundation.h>

// Minimal Atom reader: returns [ { title, url, date } ] for the first `limit` entries.
@interface LCAtomParser : NSObject <NSXMLParserDelegate>
+ (NSArray *)parseEntries:(NSData *)data limit:(int)limit;
@end
