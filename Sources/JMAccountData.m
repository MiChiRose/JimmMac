#import "JMLocalization.h"
#import "JMAccountData.h"
#import "JMProtocol.h"
#import <sys/stat.h>
#import <math.h>
NSURL *JMAccountDirectory(NSString *uin,NSURL *root) {
    if (!JMValidUIN(uin)) return nil;
    if (!root) root=[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    return [[root URLByAppendingPathComponent:@"JimmMac/accounts" isDirectory:YES] URLByAppendingPathComponent:uin isDirectory:YES];
}
NSArray *JMStoredAccounts(NSURL *root) {
    NSURL *parent=[JMAccountDirectory(@"1",root) URLByDeletingLastPathComponent]; NSMutableArray *accounts=[NSMutableArray array];
    for (NSURL *file in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:parent includingPropertiesForKeys:nil options:0 error:NULL]) {
        if (!JMValidUIN(file.lastPathComponent)) continue;
        for (NSString *name in @[@"history.sqlite",@"history.json",@"drafts.json"]) if ([[NSFileManager defaultManager] fileExistsAtPath:[[file URLByAppendingPathComponent:name] path]]) { [accounts addObject:file.lastPathComponent]; break; }
    }
    return [accounts sortedArrayUsingSelector:@selector(compare:)];
}
static NSArray *UINs(id value) { NSMutableOrderedSet *set=[NSMutableOrderedSet orderedSet]; for (id item in JMArray(value)) if (JMValidUIN(JMString(item))) [set addObject:JMString(item)]; return set.array; }
static NSDictionary *SafeContact(NSDictionary *value,NSString *uin) {
    NSMutableDictionary *result=[NSMutableDictionary dictionary]; result[@"aimId"]=uin;
    for (NSString *key in @[@"friendly",@"_rosterFriendly",@"state",@"statusMsg",@"firstName",@"lastName"]) {
        NSString *text=JMString(value[key]); if (text.length && text.length<=4096) result[key]=text;
    }
    NSMutableArray *groups=[NSMutableArray array]; for (id group in JMArray(value[@"groups"])) if ([group isKindOfClass:[NSString class]] && [group length]<=128) [groups addObject:group];
    result[@"groups"]=groups; return result;
}
NSDictionary *JMSafeRoster(NSDictionary *roster) {
    NSMutableDictionary *contacts=[NSMutableDictionary dictionary];
    for (NSString *uin in JMDictionary(roster[@"contacts"])) if (JMValidUIN(uin)) contacts[uin]=SafeContact(JMDictionary(roster[@"contacts"][uin]),uin);
    NSMutableArray *groups=[NSMutableArray array]; for (id group in JMArray(roster[@"groups"])) if ([group isKindOfClass:[NSString class]] && [group length]<=128) [groups addObject:group];
    NSMutableDictionary *profiles=[NSMutableDictionary dictionary];
    for (NSString *uin in JMDictionary(roster[@"profiles"])) if (JMValidUIN(uin) && [roster[@"profiles"][uin] isKindOfClass:[NSString class]] && [roster[@"profiles"][uin] length]<=65536) profiles[uin]=roster[@"profiles"][uin];
    return @{@"contacts":contacts,@"groups":groups,@"serverIDs":UINs(roster[@"serverIDs"]),@"profiles":profiles,@"ownInfo":SafeContact(JMDictionary(roster[@"ownInfo"]),JMString(roster[@"uin"])),@"uin":JMString(roster[@"uin"])};
}
static NSArray *GlobalKeys(void) { return @[@"ChatFontFamily",@"ChatFontSize",@"ChatSendWithCommandReturn",@"ChatEmoticonsEnabled",@"InterfaceLanguage",@"InterfaceAppearance",@"NotificationsEnabled",@"NotificationContentStyle",@"DockAttentionEnabled",@"SoundsEnabled",@"PresenceSoundsEnabled",@"TypingSoundsEnabled",@"SoundInOpenConversation",@"AutomaticallyCheckUpdates"]; }
static NSArray *AccountKeys(void) { return @[@"FavoritePeers",@"MutedPeers",@"ConversationPeers",@"OnlineOnly",@"FavoritesOnly"]; }
NSDictionary *JMSafePreferences(NSDictionary *preferences) {
    NSMutableDictionary *safe=[NSMutableDictionary dictionary];
    for (NSString *key in GlobalKeys()) {
        id value=preferences[key]; if (!value) continue;
        if ([key isEqual:@"ChatFontFamily"]) { if ([value isKindOfClass:[NSString class]] && [value length]<=256) safe[key]=value; }
        else if ([key isEqual:@"ChatFontSize"]) { if ([value isKindOfClass:[NSNumber class]] && isfinite([value doubleValue]) && [value doubleValue]>=9 && [value doubleValue]<=28) safe[key]=value; }
        else if ([key isEqual:@"InterfaceLanguage"]) { if ([@[@"ru",@"en"] containsObject:value]) safe[key]=value; }
        else if ([key isEqual:@"InterfaceAppearance"]) { if ([@[@"current",@"mac2011",@"pro2003"] containsObject:value]) safe[key]=value; }
        else if ([key isEqual:@"NotificationContentStyle"]) { if ([@[@"sender",@"preview",@"private"] containsObject:value]) safe[key]=value; }
        else if ([value isKindOfClass:[NSNumber class]]) safe[key]=@([value boolValue]);
    }
    for (NSString *key in AccountKeys()) { id value=preferences[key]; if ([key hasSuffix:@"Only"]) { if ([value isKindOfClass:[NSNumber class]]) safe[key]=@([value boolValue]); } else if ([value isKindOfClass:[NSArray class]]) safe[key]=UINs(value); }
    return safe;
}
NSDictionary *JMBackupManifest(NSDictionary *value,NSError **error) {
    if (![value isKindOfClass:[NSDictionary class]]) { if (error) *error=[NSError errorWithDomain:@"online.jimm.backup" code:1 userInfo:nil]; return nil; }
    NSDictionary *drafts=JMDictionary(value[@"drafts"]); BOOL valid=[value[@"format"] isEqual:@"JimmMacBackup"] && [value[@"version"] isKindOfClass:[NSNumber class]] && [value[@"version"] integerValue]==1 && JMValidUIN(JMString(value[@"uin"])) && [value[@"drafts"] isKindOfClass:[NSDictionary class]];
    for (NSString *peer in drafts) if (!JMValidUIN(peer) || ![drafts[peer] isKindOfClass:[NSString class]]) valid=NO;
    NSData *draftData=valid ? [NSJSONSerialization dataWithJSONObject:drafts options:0 error:NULL] : nil;
    if (!valid || !draftData || draftData.length>8*1024*1024) { if (error) *error=[NSError errorWithDomain:@"online.jimm.backup" code:1 userInfo:@{NSLocalizedDescriptionKey:JML(@"Резервная копия повреждена или имеет неподдерживаемый формат.")}]; return nil; }
    NSMutableDictionary *roster=[JMDictionary(value[@"roster"]) mutableCopy]; roster[@"uin"]=value[@"uin"];
    return @{@"format":@"JimmMacBackup",@"version":@1,@"uin":value[@"uin"],@"createdAt":[value[@"createdAt"] isKindOfClass:[NSNumber class]] ? value[@"createdAt"] : @0,@"drafts":drafts,@"roster":JMSafeRoster(roster),@"preferences":JMSafePreferences(JMDictionary(value[@"preferences"]))};
}
@interface JMAccountData ()
@property(nonatomic,strong,readwrite) NSURL *directory;
@end
@implementation JMAccountData
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root { self=[super init]; if (self) { self.directory=JMAccountDirectory(uin,root); if (!self.directory) return nil; } return self; }
- (NSDictionary *)cachedRoster {
    NSURL *file=[self.directory URLByAppendingPathComponent:@"roster.json"]; NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:NULL];
    NSData *data=[attributes[NSFileSize] unsignedLongLongValue]<=16*1024*1024 ? [NSData dataWithContentsOfURL:file] : nil;
    id decoded=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil; return [decoded isKindOfClass:[NSDictionary class]] ? JMSafeRoster(decoded) : @{};
}
- (BOOL)saveRoster:(NSDictionary *)roster error:(NSError **)error {
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]) return NO;
    NSData *data=[NSJSONSerialization dataWithJSONObject:JMSafeRoster(roster) options:0 error:error];
    if (!data || data.length>16*1024*1024) return NO;
    NSURL *file=[self.directory URLByAppendingPathComponent:@"roster.json"];
    if (![data writeToURL:file options:NSDataWritingAtomic error:error]) return NO; chmod(file.path.fileSystemRepresentation,0600); return YES;
}
+ (NSDictionary *)preferencesForUIN:(NSString *)uin defaults:(NSUserDefaults *)defaults {
    NSMutableDictionary *preferences=[NSMutableDictionary dictionary];
    for (NSString *key in GlobalKeys()) { id value=[defaults objectForKey:key]; if (value) preferences[key]=value; }
    for (NSString *key in AccountKeys()) { id value=[defaults objectForKey:[NSString stringWithFormat:@"%@.%@",key,uin]]; if (value) preferences[key]=value; }
    return JMSafePreferences(preferences);
}
+ (void)applyPreferences:(NSDictionary *)preferences uin:(NSString *)uin defaults:(NSUserDefaults *)defaults {
    if (!JMValidUIN(uin)) return;
    NSDictionary *safe=JMSafePreferences(preferences);
    for (NSString *key in safe) [defaults setObject:safe[key] forKey:[AccountKeys() containsObject:key] ? [NSString stringWithFormat:@"%@.%@",key,uin] : key]; [defaults synchronize];
}
@end
