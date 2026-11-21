// LCConnection.h - NSURLConnection wrapper (iOS 5 has no NSURLSession).
// Supports buffered responses and NDJSON streaming. All callbacks run on the main thread.
#import <Foundation/Foundation.h>

typedef void (^LCJSONBlock)(id json);
typedef void (^LCDoneBlock)(NSInteger status, id json, NSError *error);

@interface LCConnection : NSObject
// Buffered: onDone gets parsed JSON (or nil) when the response completes.
+ (LCConnection *)send:(NSURLRequest *)request insecure:(BOOL)insecure onDone:(LCDoneBlock)done;
// Streaming NDJSON: onLine is called per JSON line; onDone when the stream ends/fails.
+ (LCConnection *)stream:(NSURLRequest *)request insecure:(BOOL)insecure
                  onLine:(LCJSONBlock)line onDone:(LCDoneBlock)done;
// Raw body (no JSON parsing), e.g. for Atom/XML.
+ (LCConnection *)sendRaw:(NSURLRequest *)request insecure:(BOOL)insecure
                  onDone:(void (^)(NSInteger status, NSData *body, NSError *error))done;
- (void)cancel;
@end
