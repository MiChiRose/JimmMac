#import <Foundation/Foundation.h>
// Pure policy: an explicit user choice wins until fresh activity occurs.
@interface JMAutoAway : NSObject
@property(nonatomic) NSTimeInterval interval;
@property(nonatomic,copy,readonly) NSString *manualPresence;
@property(nonatomic,readonly) BOOL automaticallyAway;
- (void)manualPresenceChanged:(NSString *)state;
- (NSString *)requestedPresenceForIdle:(NSTimeInterval)idle connected:(BOOL)connected;
- (void)requestFailedForState:(NSString *)state;
@end
