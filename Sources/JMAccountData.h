#import <Foundation/Foundation.h>
NSURL *JMAccountDirectory(NSString *uin,NSURL *root);
NSArray *JMStoredAccounts(NSURL *root);
NSDictionary *JMSafeRoster(NSDictionary *roster);
NSDictionary *JMSafePreferences(NSDictionary *preferences);
NSDictionary *JMBackupManifest(NSDictionary *value,NSError **error);
@interface JMAccountData : NSObject
@property(nonatomic,strong,readonly) NSURL *directory;
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root;
- (NSDictionary *)cachedRoster;
- (BOOL)saveRoster:(NSDictionary *)roster error:(NSError **)error;
+ (NSDictionary *)preferencesForUIN:(NSString *)uin defaults:(NSUserDefaults *)defaults;
+ (void)applyPreferences:(NSDictionary *)preferences uin:(NSString *)uin defaults:(NSUserDefaults *)defaults;
@end
