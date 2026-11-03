#import <Foundation/Foundation.h>
@interface JMUpdateChecker : NSObject
+ (NSComparisonResult)compareVersion:(NSString *)a to:(NSString *)b;
+ (NSDictionary *)releaseFromData:(NSData *)data error:(NSError **)error;
- (id)initWithProtocolClasses:(NSArray *)classes legacy:(BOOL)legacy;
- (void)check:(void (^)(NSDictionary *,NSError *))completion;
@end
