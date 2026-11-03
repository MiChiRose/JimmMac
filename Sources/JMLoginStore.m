#import "JMLocalization.h"
#import "JMLoginStore.h"
#import "JMProtocol.h"
#import <math.h>
NSString * const JMLoginStoreErrorDomain=@"online.jimm.keychain";
static NSError *LoginStoreError(NSInteger code) {
    NSString *text=code==-2 ? JML(@"Срок сохранённого входа истёк. Введите пароль ещё раз.") : (code==-1 ? JML(@"Сохранённый вход повреждён. Введите пароль ещё раз.") : JML(@"Связка ключей недоступна. Войти можно вручную; сохранённый вход пока не изменён."));
    return [NSError errorWithDomain:JMLoginStoreErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:text}];
}
@interface JMLoginStore () {
    SecKeychainRef _keychain;
}
@property(nonatomic, copy) NSString *service;
@end
@implementation JMLoginStore
- (id)init { return [self initWithService:@"online.jimm.mavericks.login-token" keychain:NULL]; }
- (id)initWithService:(NSString *)service keychain:(SecKeychainRef)keychain {
    self=[super init]; if (self) { self.service=service; if (keychain) _keychain=(SecKeychainRef)CFRetain(keychain); } return self;
}
- (void)dealloc { if (_keychain) CFRelease(_keychain); }
- (NSMutableDictionary *)queryForUIN:(NSString *)uin {
    NSMutableDictionary *query=[@{(__bridge NSString *)kSecClass:(__bridge id)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrService:self.service,(__bridge NSString *)kSecAttrAccount:uin} mutableCopy];
    if (_keychain) query[(__bridge NSString *)kSecMatchSearchList]=@[(__bridge id)_keychain];
    return query;
}
- (NSDictionary *)loginForUIN:(NSString *)uin error:(NSError **)error {
    if (!JMValidUIN(uin)) { if (error) *error=LoginStoreError(-1); return nil; }
    NSMutableDictionary *query=[self queryForUIN:uin]; query[(__bridge NSString *)kSecReturnData]=@YES; query[(__bridge NSString *)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
    CFTypeRef value=NULL; OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&value);
    NSData *data=CFBridgingRelease(value);
    if (status==errSecItemNotFound) return nil;
    if (status!=errSecSuccess) { if (error) *error=LoginStoreError(status); return nil; }
    NSDictionary *record=JMDictionary(data.length<=32768 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);
    NSString *token=JMString(record[@"token"]); double expires=[JMString(record[@"expiresAt"]) doubleValue];
    if (![JMString(record[@"uin"]) isEqualToString:uin] || [JMString(record[@"version"]) integerValue]!=1 || !token.length || token.length>16384 || !isfinite(expires)) { if (error) *error=LoginStoreError(-1); return nil; }
    NSDate *expiration=[NSDate dateWithTimeIntervalSince1970:expires];
    if (expiration.timeIntervalSinceNow<=0) { if (error) *error=LoginStoreError(-2); return nil; }
    return @{@"token":token,@"expiresAt":expiration};
}
- (BOOL)saveToken:(NSString *)token expiresAt:(NSDate *)expiration forUIN:(NSString *)uin error:(NSError **)error {
    if (!JMValidUIN(uin) || ![token isKindOfClass:[NSString class]] || !token.length || token.length>16384 || ![expiration isKindOfClass:[NSDate class]] || !isfinite(expiration.timeIntervalSince1970) || expiration.timeIntervalSinceNow<=0) { if (error) *error=LoginStoreError(-1); return NO; }
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"uin":uin,@"token":token,@"expiresAt":@(expiration.timeIntervalSince1970)} options:0 error:NULL];
    NSMutableDictionary *query=[self queryForUIN:uin]; NSDictionary *attributes=@{(__bridge NSString *)kSecValueData:data};
    OSStatus status=SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attributes);
    if (status==errSecItemNotFound) {
        NSMutableDictionary *item=[query mutableCopy]; [item removeObjectForKey:(__bridge NSString *)kSecMatchSearchList];
        if (_keychain) item[(__bridge NSString *)kSecUseKeychain]=(__bridge id)_keychain;
        item[(__bridge NSString *)kSecAttrLabel]=JML(@"JimmMac — сохранённый вход"); [item addEntriesFromDictionary:attributes];
        status=SecItemAdd((__bridge CFDictionaryRef)item,NULL);
        if (status==errSecDuplicateItem) status=SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attributes);
    }
    if (status!=errSecSuccess && error) *error=LoginStoreError(status); return status==errSecSuccess;
}
- (BOOL)removeLoginForUIN:(NSString *)uin error:(NSError **)error {
    if (!JMValidUIN(uin)) { if (error) *error=LoginStoreError(-1); return NO; }
    OSStatus status=SecItemDelete((__bridge CFDictionaryRef)[self queryForUIN:uin]);
    BOOL success=status==errSecSuccess || status==errSecItemNotFound;
    if (!success && error) *error=LoginStoreError(status); return success;
}
@end
