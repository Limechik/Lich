#import "LCAtomParser.h"

@implementation LCAtomParser {
    NSMutableArray *_entries;
    NSMutableDictionary *_cur;
    NSMutableString *_text;
    BOOL _inAuthor;
    int _limit;
}

+ (NSArray *)parseEntries:(NSData *)data limit:(int)limit {
    LCAtomParser *p = [[LCAtomParser alloc] init];
    p->_entries = [NSMutableArray array];
    p->_limit = limit;
    NSXMLParser *x = [[NSXMLParser alloc] initWithData:data];
    x.delegate = p;
    [x parse];
    return p->_entries;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)ns
 qualifiedName:(NSString *)qn attributes:(NSDictionary *)attrs {
    if ([name isEqualToString:@"entry"]) { _cur = [NSMutableDictionary dictionary]; _inAuthor = NO; return; }
    if (!_cur) return;                                   // ignore the feed header
    if ([name isEqualToString:@"author"]) { _inAuthor = YES; return; }
    if ([name isEqualToString:@"link"]) {
        NSString *rel = [attrs objectForKey:@"rel"], *href = [attrs objectForKey:@"href"];
        if (href && (!rel || [rel isEqualToString:@"alternate"]) && ![_cur objectForKey:@"url"]) [_cur setObject:href forKey:@"url"];
    } else if ([name isEqualToString:@"media:thumbnail"] || [name hasSuffix:@":thumbnail"]) {
        NSString *u = [attrs objectForKey:@"url"];
        if (u.length && ![_cur objectForKey:@"image"]) [_cur setObject:u forKey:@"image"];   // cover picture
    } else if ([name isEqualToString:@"title"] || [name isEqualToString:@"published"] ||
               [name isEqualToString:@"updated"] || [name isEqualToString:@"id"] ||
               (_inAuthor && [name isEqualToString:@"name"])) {
        _text = [NSMutableString string];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)s { [_text appendString:s]; }

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name namespaceURI:(NSString *)ns qualifiedName:(NSString *)qn {
    if (_cur && _text) {
        NSString *t = [_text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([name isEqualToString:@"title"] && ![_cur objectForKey:@"title"]) [_cur setObject:t forKey:@"title"];
        else if ([name isEqualToString:@"published"]) [_cur setObject:t forKey:@"date"];
        else if ([name isEqualToString:@"updated"] && ![_cur objectForKey:@"date"]) [_cur setObject:t forKey:@"date"];
        else if ([name isEqualToString:@"id"]) [_cur setObject:t forKey:@"id"];
        else if (_inAuthor && [name isEqualToString:@"name"]) [_cur setObject:t forKey:@"author"];
    }
    _text = nil;
    if ([name isEqualToString:@"author"]) _inAuthor = NO;
    if ([name isEqualToString:@"entry"] && _cur) {
        if (![_cur objectForKey:@"url"] && [_cur objectForKey:@"id"]) [_cur setObject:[_cur objectForKey:@"id"] forKey:@"url"];
        if ([_cur objectForKey:@"title"] && [_cur objectForKey:@"url"]) [_entries addObject:_cur];
        _cur = nil;
        if ((int)_entries.count >= _limit) [parser abortParsing];
    }
}

@end
