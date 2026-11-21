#import "LCConnection.h"

@interface LCConnection () <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    NSURLConnection *_conn;
    NSMutableData *_buffer;
    NSInteger _status;
    BOOL _insecure, _streaming, _finished;
    LCJSONBlock _onLine;
    LCDoneBlock _onDone;
    void (^_rawDone)(NSInteger, NSData *, NSError *);
}
@end

@implementation LCConnection

+ (LCConnection *)make:(NSURLRequest *)req insecure:(BOOL)insecure streaming:(BOOL)streaming
                  line:(LCJSONBlock)line done:(LCDoneBlock)done {
    LCConnection *c = [[LCConnection alloc] init];
    c->_insecure = insecure; c->_streaming = streaming;
    c->_onLine = [line copy]; c->_onDone = [done copy];
    c->_buffer = [NSMutableData data];
    c->_conn = [[NSURLConnection alloc] initWithRequest:req delegate:c startImmediately:NO];
    // Common modes so callbacks keep flowing while a table view is scrolling.
    [c->_conn scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [c->_conn start];
    return c;
}

+ (LCConnection *)send:(NSURLRequest *)request insecure:(BOOL)insecure onDone:(LCDoneBlock)done {
    return [self make:request insecure:insecure streaming:NO line:nil done:done];
}

+ (LCConnection *)stream:(NSURLRequest *)request insecure:(BOOL)insecure
                  onLine:(LCJSONBlock)line onDone:(LCDoneBlock)done {
    return [self make:request insecure:insecure streaming:YES line:line done:done];
}

+ (LCConnection *)sendRaw:(NSURLRequest *)request insecure:(BOOL)insecure
                  onDone:(void (^)(NSInteger, NSData *, NSError *))done {
    LCConnection *c = [self make:request insecure:insecure streaming:NO line:nil done:nil];
    c->_rawDone = [done copy];
    return c;
}

- (void)cancel {
    _finished = YES;
    _rawDone = nil;
    [_conn cancel];
    _conn = nil; _onLine = nil; _onDone = nil;
}

- (void)finishWithError:(NSError *)err {
    if (_finished) return;
    _finished = YES;
    if (_rawDone) {
        void (^blk)(NSInteger, NSData *, NSError *) = _rawDone;
        NSData *body = [_buffer copy];
        _rawDone = nil; _onLine = nil; _onDone = nil; _conn = nil;
        blk(_status, body, err);
        return;
    }
    id json = nil;
    if (_buffer.length) json = [NSJSONSerialization JSONObjectWithData:_buffer options:0 error:NULL];
    LCDoneBlock done = _onDone;
    _onDone = nil; _onLine = nil; _conn = nil;
    if (done) done(_status, json, err);
}

#pragma mark - TLS (optional trust override for old devices)

- (BOOL)connection:(NSURLConnection *)c canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)ps {
    return _insecure && [ps.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)c didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch {
    if (_insecure && [ch.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        [ch.sender useCredential:[NSURLCredential credentialForTrust:ch.protectionSpace.serverTrust]
      forAuthenticationChallenge:ch];
    } else {
        [ch.sender continueWithoutCredentialForAuthenticationChallenge:ch];
    }
}

#pragma mark - Data

- (void)connection:(NSURLConnection *)c didReceiveResponse:(NSURLResponse *)resp {
    _status = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
}

- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)data {
    [_buffer appendData:data];
    if (!_streaming || _status != 200) return;   // errors (4xx) are collected as a normal JSON body
    // Split complete lines.
    const uint8_t *bytes = _buffer.bytes;
    NSUInteger len = _buffer.length, start = 0;
    for (NSUInteger i = 0; i < len; i++) {
        if (bytes[i] != '\n') continue;
        if (i > start) {
            NSData *lineData = [NSData dataWithBytes:bytes + start length:i - start];
            id obj = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:NULL];
            if (obj && _onLine) _onLine(obj);
            if (_finished) return;                // callback cancelled us
            bytes = _buffer.bytes;                // buffer is not modified by callbacks, but stay safe
        }
        start = i + 1;
    }
    if (start > 0) [_buffer replaceBytesInRange:NSMakeRange(0, start) withBytes:NULL length:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)c {
    if (_streaming && _status == 200) [_buffer setLength:0];   // drop a trailing partial line
    [self finishWithError:nil];
}

- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)error {
    [self finishWithError:error];
}

@end
