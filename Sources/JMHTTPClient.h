#import <Foundation/Foundation.h>
@class JMHTTPTask;
typedef void (^JMHTTPCompletion)(NSData *, NSURLResponse *, NSError *);

// One request contract for 10.8's NSURLConnection and 10.9+'s NSURLSession.
@interface JMHTTPClient : NSObject
@property(nonatomic) NSUInteger maximumResponseBytes;
@property(nonatomic) NSTimeInterval resourceTimeout;
@property(nonatomic) BOOL allowsSameOriginRedirects;
@property(nonatomic, copy) BOOL (^responseValidator)(NSURLResponse *);
@property(nonatomic, readonly) BOOL usesLegacyTransport;
- (id)initWithProtocolClasses:(NSArray *)classes legacy:(BOOL)legacy;
- (JMHTTPTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(JMHTTPCompletion)completion;
- (void)invalidateAndCancel;
- (void)finishTasksAndInvalidate;
@end
@interface JMHTTPTask : NSObject
- (void)resume;
- (void)cancel;
@end
