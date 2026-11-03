#import "JMAutoAway.h"
#import <math.h>
@interface JMAutoAway ()
@property(nonatomic,copy,readwrite) NSString *manualPresence;
@property(nonatomic,readwrite) BOOL automaticallyAway;
@property(nonatomic) BOOL waitForActivity;
@end
@implementation JMAutoAway
- (id)init { self=[super init]; if (self) _manualPresence=@"online"; return self; }
- (void)manualPresenceChanged:(NSString *)state {
    self.manualPresence=state ?: @"online"; self.automaticallyAway=NO; self.waitForActivity=YES;
}
- (NSString *)requestedPresenceForIdle:(NSTimeInterval)idle connected:(BOOL)connected {
    if (!isfinite(idle) || idle<0) return nil;
    if (idle<2) self.waitForActivity=NO;
    if (!connected) return nil;
    if (self.automaticallyAway && (self.interval<=0 || idle<2)) { self.automaticallyAway=NO; return self.manualPresence; }
    if (self.interval>=60 && idle>=self.interval && !self.waitForActivity && !self.automaticallyAway && [self.manualPresence isEqual:@"online"]) { self.automaticallyAway=YES; return @"away"; }
    return nil;
}
- (void)requestFailedForState:(NSString *)state { self.automaticallyAway=[state isEqual:@"online"]; }
@end
