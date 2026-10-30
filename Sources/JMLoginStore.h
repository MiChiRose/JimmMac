#import <Foundation/Foundation.h>
#import <Security/Security.h>
extern NSString * const JMLoginStoreErrorDomain;
@interface JMLoginStore : NSObject
- (NSDictionary *)loginForUIN:(NSString *)uin error:(NSError **)error;
- (BOOL)saveToken:(NSString *)token expiresAt:(NSDate *)expiration forUIN:(NSString *)uin error:(NSError **)error;
- (BOOL)removeLoginForUIN:(NSString *)uin error:(NSError **)error;
// An explicit keychain keeps integration tests separate from the user's login keychain.
- (id)initWithService:(NSString *)service keychain:(SecKeychainRef)keychain;
@end
