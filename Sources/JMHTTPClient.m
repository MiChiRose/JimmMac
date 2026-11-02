#import "JMHTTPClient.h"

@interface JMHTTPClient () <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSMutableSet *tasks;
@property(nonatomic, readwrite) BOOL usesLegacyTransport;
@property(nonatomic) BOOL invalidated;
- (void)finishedTask:(JMHTTPTask *)task;
@end
@interface JMHTTPTask () <NSURLConnectionDataDelegate>
@property(nonatomic, strong) JMHTTPClient *owner;
@property(nonatomic, strong) NSURLRequest *request;
@property(nonatomic, copy) JMHTTPCompletion completion;
@property(nonatomic, strong) NSURLSessionDataTask *modern;
@property(nonatomic, strong) NSURLConnection *connection;
@property(nonatomic, strong) NSMutableData *buffer;
@property(nonatomic, strong) NSURLResponse *response;
@property(nonatomic, strong) NSTimer *deadline;
@property(nonatomic) BOOL started;
@property(nonatomic) BOOL finished;
@property(nonatomic) NSUInteger redirects;
- (void)receivedResponse:(NSURLResponse *)response;
- (void)receivedData:(NSData *)data;
- (void)finish:(NSError *)error;
- (BOOL)allowsRedirect:(NSURLRequest *)request;
@end
static NSError *JMHTTPError(NSInteger code) { return [NSError errorWithDomain:NSURLErrorDomain code:code userInfo:nil]; }
@implementation JMHTTPTask
- (void)resume {
    if (self.started || self.finished || !self.owner || self.owner.invalidated) return;
    self.started=YES; self.buffer=[NSMutableData data];
    self.deadline=[NSTimer timerWithTimeInterval:self.owner.resourceTimeout target:self selector:@selector(timedOut:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.deadline forMode:NSRunLoopCommonModes];
    if (self.owner.usesLegacyTransport) {
        self.connection=[[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        if (!self.connection) { [self finish:JMHTTPError(NSURLErrorUnknown)]; return; }
        [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes]; [self.connection start];
    } else {
        self.modern=[self.owner.session dataTaskWithRequest:self.request]; [self.modern resume];
    }
}
- (void)timedOut:(NSTimer *)timer { [self finish:JMHTTPError(NSURLErrorTimedOut)]; }
- (void)cancel { [self finish:JMHTTPError(NSURLErrorCancelled)]; }
- (void)finish:(NSError *)error {
    if (self.finished) return;
    self.finished=YES; [self.deadline invalidate]; self.deadline=nil;
    if (error) { [self.modern cancel]; [self.connection cancel]; }
    self.connection=nil; self.modern=nil;
    JMHTTPCompletion completion=self.completion; self.completion=nil;
    NSData *data=[self.buffer copy]; self.buffer=nil; NSURLResponse *response=self.response;
    [self.owner finishedTask:self]; self.owner=nil;
    if (completion) completion(data,response,error);
}
- (void)receivedResponse:(NSURLResponse *)response {
    if (self.finished) return;
    self.response=response; [self.buffer setLength:0];
    if (response.expectedContentLength>(long long)self.owner.maximumResponseBytes || (self.owner.responseValidator && !self.owner.responseValidator(response))) [self finish:JMHTTPError(NSURLErrorDataLengthExceedsMaximum)];
}
- (void)receivedData:(NSData *)data {
    if (self.finished) return;
    if (data.length>self.owner.maximumResponseBytes-self.buffer.length) { [self finish:JMHTTPError(NSURLErrorDataLengthExceedsMaximum)]; return; }
    [self.buffer appendData:data];
}
- (BOOL)allowsRedirect:(NSURLRequest *)request {
    if (!self.owner.allowsSameOriginRedirects || ++self.redirects>5) return NO;
    NSURL *a=self.request.URL, *b=request.URL;
    return [b.scheme isEqualToString:@"https"] && [a.host isEqualToString:b.host] &&
        (!b.port || b.port.integerValue==443) && !b.user.length && !b.password.length;
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (!response) return request;
    if ([self allowsRedirect:request]) return request;
    [self finish:JMHTTPError(NSURLErrorHTTPTooManyRedirects)]; return nil;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response { [self receivedResponse:response]; }
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data { [self receivedData:data]; }
- (void)connectionDidFinishLoading:(NSURLConnection *)connection { [self finish:nil]; }
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error { [self finish:error]; }
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse { return nil; }
- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection { return NO; }
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
    else [challenge.sender cancelAuthenticationChallenge:challenge];
}
@end
@implementation JMHTTPClient
- (id)initWithProtocolClasses:(NSArray *)classes legacy:(BOOL)legacy {
    self=[super init]; if (!self) return nil;
    self.tasks=[NSMutableSet set]; self.maximumResponseBytes=8*1024*1024; self.resourceTimeout=90;
    self.usesLegacyTransport=legacy || NSClassFromString(@"NSURLSession")==nil;
    if (!self.usesLegacyTransport) {
        NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];
        if (classes.count) config.protocolClasses=classes;
        config.timeoutIntervalForRequest=75; config.timeoutIntervalForResource=90; config.HTTPMaximumConnectionsPerHost=4;
        config.URLCache=nil; config.HTTPCookieStorage=nil; config.URLCredentialStorage=nil;
        self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}
- (JMHTTPTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(JMHTTPCompletion)completion {
    JMHTTPTask *task=[[JMHTTPTask alloc] init]; task.owner=self; task.completion=completion;
    NSMutableURLRequest *safe=[request mutableCopy]; safe.HTTPShouldHandleCookies=NO; safe.cachePolicy=NSURLRequestReloadIgnoringLocalCacheData; task.request=safe;
    if (self.invalidated) { [task cancel]; return task; }
    [self.tasks addObject:task]; return task;
}
- (void)finishedTask:(JMHTTPTask *)task {
    [self.tasks removeObject:task];
    if (self.invalidated && !self.tasks.count) { [self.session finishTasksAndInvalidate]; self.session=nil; }
}
- (void)invalidateAndCancel {
    self.invalidated=YES;
    for (JMHTTPTask *task in self.tasks.allObjects) [task cancel];
    [self.session invalidateAndCancel]; self.session=nil;
}
- (void)finishTasksAndInvalidate {
    self.invalidated=YES;
    if (!self.tasks.count) { [self.session finishTasksAndInvalidate]; self.session=nil; }
}
- (JMHTTPTask *)wrapperForTask:(NSURLSessionTask *)task { for (JMHTTPTask *wrapper in self.tasks) if (wrapper.modern==task) return wrapper; return nil; }
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    JMHTTPTask *wrapper=[self wrapperForTask:task]; [wrapper receivedResponse:response]; completionHandler(wrapper && !wrapper.finished ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data { [[self wrapperForTask:task] receivedData:data]; }
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error { [[self wrapperForTask:task] finish:error]; }
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    JMHTTPTask *wrapper=[self wrapperForTask:task];
    if (wrapper && [wrapper allowsRedirect:request]) completionHandler(request);
    else { [wrapper finish:JMHTTPError(NSURLErrorHTTPTooManyRedirects)]; completionHandler(nil); }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,NSURLCredential *))completionHandler {
    completionHandler([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] ? NSURLSessionAuthChallengePerformDefaultHandling : NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);
}
@end
