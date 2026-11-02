#import <Foundation/Foundation.h>
#import "JMHTTPClient.h"
@interface JMHTTPTask (PolicyProbe)
- (BOOL)allowsRedirect:(NSURLRequest *)request;
@end
static NSUInteger checks;
static void Check(BOOL condition, const char *message) { if (!condition) { fprintf(stderr,"FAIL: %s\n",message); exit(1); } checks++; }
static void Pump(NSTimeInterval seconds) { [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }
@interface HTTPFixture : NSURLProtocol
@end
@implementation HTTPFixture
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqualToString:@"transport.invalid"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    if (self.request.HTTPShouldHandleCookies || self.request.cachePolicy!=NSURLRequestReloadIgnoringLocalCacheData) { fprintf(stderr,"FAIL: cookies and shared cache must be disabled\n"); exit(1); }
    if ([self.request.URL.path isEqualToString:@"/hang"]) return;
    NSDictionary *headers=[self.request.URL.path isEqualToString:@"/length"] ? @{@"Content-Length":@"512",@"Content-Type":@"image/png"} : @{@"Content-Type":@"image/png"};
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[@"first chunk" dataUsingEncoding:NSUTF8StringEncoding]];
    if ([self.request.URL.path isEqualToString:@"/chunks"]) [self.client URLProtocol:self didLoadData:[NSMutableData dataWithLength:32]];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
static JMHTTPTask *Task(JMHTTPClient *client, NSString *path, JMHTTPCompletion completion) {
    return [client dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[@"https://transport.invalid" stringByAppendingString:path]]] completionHandler:completion];
}
int main(void) { @autoreleasepool {
    [NSURLProtocol registerClass:[HTTPFixture class]];
    for (NSNumber *legacy in @[@NO,@YES]) {
        JMHTTPClient *client=[[JMHTTPClient alloc] initWithProtocolClasses:@[[HTTPFixture class]] legacy:legacy.boolValue]; client.resourceTimeout=0.2; client.maximumResponseBytes=24;
        Check(client.usesLegacyTransport==(legacy.boolValue || !NSClassFromString(@"NSURLSession")),"transport selects explicit legacy or available modern implementation");
        __block NSUInteger completions=0; __block NSInteger code=0; __block NSUInteger length=0;
        JMHTTPCompletion result=^(NSData *data,NSURLResponse *response,NSError *error) { completions++; code=error.code; length=data.length; };
        [Task(client,@"/ok",result) resume]; Pump(0.3);
        Check(completions==1 && code==0 && length==11,"successful streaming request finishes once");
        completions=0; [Task(client,@"/chunks",result) resume]; Pump(0.3);
        Check(completions==1 && code==NSURLErrorDataLengthExceedsMaximum && length<=24,"unknown-size response is bounded while streaming");
        completions=0; [Task(client,@"/length",result) resume]; Pump(0.3);
        Check(completions==1 && code==NSURLErrorDataLengthExceedsMaximum,"oversized Content-Length is rejected before data delivery");
        client.responseValidator=^BOOL(NSURLResponse *response) { return [response.MIMEType isEqualToString:@"application/json"]; };
        completions=0; [Task(client,@"/ok",result) resume]; Pump(0.3);
        Check(completions==1 && code!=0,"response validator rejects wrong MIME type"); client.responseValidator=nil;
        completions=0; [Task(client,@"/hang",result) resume]; Pump(0.35);
        Check(completions==1 && code==NSURLErrorTimedOut,"resource deadline cancels a silent request");
        completions=0; JMHTTPTask *cancelled=Task(client,@"/hang",result); [cancelled resume]; [cancelled cancel]; [cancelled cancel]; Pump(0.3);
        Check(completions==1 && code==NSURLErrorCancelled,"cancellation delivers exactly one completion and clears deadline");
        JMHTTPTask *policy=Task(client,@"/ok",nil);
        Check(![policy allowsRedirect:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://transport.invalid/next"]]],"API requests reject even same-origin redirects");
        client.allowsSameOriginRedirects=YES;
        Check([policy allowsRedirect:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://transport.invalid/next"]]],"public avatar request may redirect within HTTPS origin");
        for (NSString *url in @[@"https://external.invalid/",@"http://transport.invalid/",@"https://transport.invalid:444/",@"https://user:secret@transport.invalid/"])
            Check(![policy allowsRedirect:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]],"redirect rejects external host, downgrade, port changes and URL credentials");
        [policy cancel]; completions=0; JMHTTPTask *pending=Task(client,@"/hang",result); [pending resume]; [client invalidateAndCancel]; Pump(0.3);
        Check(completions==1 && code==NSURLErrorCancelled,"invalidating client terminates pending request once");
        completions=0; [Task(client,@"/ok",result) resume]; Pump(0.3);
        Check(completions==1 && code==NSURLErrorCancelled,"invalidated client never starts new request");
    }
    [NSURLProtocol unregisterClass:[HTTPFixture class]];
    printf("PASS: %lu HTTP checks across NSURLSession and NSURLConnection\n",(unsigned long)checks);
} return 0; }
