#import <Foundation/Foundation.h>
@interface JMHistory : NSObject
@property(nonatomic, readonly) NSError *loadError;
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root;
- (NSArray *)messagesForPeer:(NSString *)peer;
- (NSArray *)peers;
- (NSDictionary *)searchSnapshot;
+ (NSArray *)searchSnapshot:(NSDictionary *)snapshot query:(NSString *)query peer:(NSString *)peer limit:(NSUInteger)limit;
- (BOOL)appendMessage:(NSDictionary *)message error:(NSError **)error;
@end
