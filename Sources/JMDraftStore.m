#import "JMDraftStore.h"
#import "JMProtocol.h"
#import <sys/stat.h>
static const NSUInteger JMDraftFileLimit=8*1024*1024;
static NSError *DraftError(NSString *text) { return [NSError errorWithDomain:JMAPIErrorDomain code:-5 userInfo:@{NSLocalizedDescriptionKey:text}]; }
@interface JMDraftStore ()
@property(nonatomic, strong) NSURL *file;
@property(nonatomic, copy, readwrite) NSDictionary *drafts;
@property(nonatomic, strong, readwrite) NSError *loadError;
@end
@implementation JMDraftStore
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root {
    self=[super init]; if (!self || !JMValidUIN(uin)) return nil;
    self.drafts=@{};
    if (!root) root=[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory=[[root URLByAppendingPathComponent:@"JimmMac/accounts" isDirectory:YES] URLByAppendingPathComponent:uin isDirectory:YES];
    NSError *error=nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) self.loadError=error;
    self.file=[directory URLByAppendingPathComponent:@"drafts.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.file.path]) {
        NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:self.file.path error:&error];
        NSData *data=[attributes[NSFileSize] unsignedLongLongValue]<=JMDraftFileLimit ? [NSData dataWithContentsOfURL:self.file options:0 error:&error] : nil;
        NSDictionary *json=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
        if (![json isKindOfClass:[NSDictionary class]] || error) self.loadError=error ?: DraftError(@"Файл черновиков повреждён или слишком велик. Он оставлен без изменений.");
        else {
            NSMutableDictionary *valid=[NSMutableDictionary dictionary];
            for (NSString *peer in json) {
                if (!JMValidUIN(peer) || ![json[peer] isKindOfClass:[NSString class]]) { self.loadError=DraftError(@"Файл черновиков содержит неподдерживаемые данные. Он оставлен без изменений."); break; }
                if ([json[peer] length]) valid[peer]=json[peer];
            }
            if (!self.loadError) self.drafts=valid;
        }
    }
    return self;
}
- (BOOL)saveDrafts:(NSDictionary *)drafts error:(NSError **)error {
    if (self.loadError) { if (error) *error=self.loadError; return NO; }
    if (![drafts isKindOfClass:[NSDictionary class]]) { if (error) *error=DraftError(@"Не удалось сохранить черновик: неподдерживаемые данные."); return NO; }
    NSMutableDictionary *valid=[NSMutableDictionary dictionary];
    for (NSString *peer in drafts) {
        if (![peer isKindOfClass:[NSString class]] || !JMValidUIN(peer) || ![drafts[peer] isKindOfClass:[NSString class]]) { if (error) *error=DraftError(@"Не удалось сохранить черновик: неподдерживаемые данные."); return NO; }
        if ([drafts[peer] length]) valid[peer]=drafts[peer];
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:valid options:0 error:error];
    if (!data || data.length>JMDraftFileLimit) { if (data && error) *error=DraftError(@"Черновики занимают больше 8 МБ. Сократите их для сохранения на этом Mac."); return NO; }
    if (![data writeToURL:self.file options:NSDataWritingAtomic error:error]) return NO;
    chmod(self.file.path.fileSystemRepresentation,0600); self.drafts=valid; return YES;
}
@end
