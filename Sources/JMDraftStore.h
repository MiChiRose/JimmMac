#import <Foundation/Foundation.h>
@interface JMDraftStore : NSObject
@property(nonatomic, copy, readonly) NSDictionary *drafts;
@property(nonatomic, strong, readonly) NSError *loadError;
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root;
// Call on one serial queue. A damaged file is never overwritten.
- (BOOL)saveDrafts:(NSDictionary *)drafts error:(NSError **)error;
@end
