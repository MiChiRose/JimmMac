#import "JMHistory.h"
#import "JMProtocol.h"
#import <sys/stat.h>
@interface JMHistory ()
@property(nonatomic, strong) NSURL *file;
@property(nonatomic, strong) NSMutableDictionary *conversations;
@property(nonatomic, strong, readwrite) NSError *loadError;
@end
@implementation JMHistory
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root {
    self = [super init];
    if (!self) return nil;
    self.conversations = [NSMutableDictionary dictionary];
    if (!JMValidUIN(uin)) return nil;
    if (!root) root = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory = [[root URLByAppendingPathComponent:@"JimmMac/accounts" isDirectory:YES] URLByAppendingPathComponent:uin isDirectory:YES];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) self.loadError = error;
    self.file = [directory URLByAppendingPathComponent:@"history.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self.file path]]) {
        NSData *data = [NSData dataWithContentsOfURL:self.file options:0 error:&error];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error] : nil;
        if (![json isKindOfClass:[NSDictionary class]] || error) {
            self.loadError = error ?: [NSError errorWithDomain:JMAPIErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey:@"Файл истории повреждён. Он оставлен без изменений."}];
        } else {
            for (NSString *peer in json) {
                if (!JMValidUIN(peer) || ![json[peer] isKindOfClass:[NSArray class]]) continue;
                NSMutableArray *valid = [NSMutableArray array];
                for (id row in json[peer]) if ([row isKindOfClass:[NSDictionary class]] && [row[@"text"] isKindOfClass:[NSString class]] && [row[@"id"] isKindOfClass:[NSString class]]) [valid addObject:row];
                self.conversations[peer] = valid;
            }
        }
    }
    return self;
}
- (NSArray *)messagesForPeer:(NSString *)peer { return JMArray(self.conversations[peer]); }
- (NSArray *)peers { return [self.conversations allKeys]; }
- (NSDictionary *)searchSnapshot { return [self.conversations copy]; }
+ (NSArray *)searchSnapshot:(NSDictionary *)snapshot query:(NSString *)query peer:(NSString *)peer limit:(NSUInteger)limit {
    query=[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!query.length || !limit) return @[];
    NSMutableArray *hits=[NSMutableArray array];
    for (NSString *uin in snapshot) {
        if (peer.length && ![uin isEqualToString:peer]) continue;
        for (NSDictionary *row in JMArray(snapshot[uin])) {
            if ([JMString(row[@"text"]) rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location==NSNotFound) continue;
            NSMutableDictionary *hit=[row mutableCopy]; hit[@"peer"]=uin; [hits addObject:hit];
        }
    }
    [hits sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
        NSComparisonResult order=[@([b[@"timestamp"] doubleValue]) compare:@([a[@"timestamp"] doubleValue])];
        if (order!=NSOrderedSame) return order;
        order=[JMString(a[@"peer"]) compare:JMString(b[@"peer"])];
        return order!=NSOrderedSame ? order : [JMString(a[@"id"]) compare:JMString(b[@"id"])];
    }];
    return hits.count>limit ? [hits subarrayWithRange:NSMakeRange(0,limit)] : hits;
}
- (BOOL)appendMessage:(NSDictionary *)message error:(NSError **)error {
    if (self.loadError) { if (error) *error = self.loadError; return NO; }
    NSString *peer = JMString(message[@"peer"]);
    if (!JMValidUIN(peer)) return NO;
    NSMutableArray *rows = [self.conversations[peer] mutableCopy] ?: [NSMutableArray array];
    for (NSDictionary *row in rows) if ([row[@"id"] isEqual:message[@"id"]]) return YES;
    [rows addObject:message];
    [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"timestamp"] compare:b[@"timestamp"]]; }];
    NSMutableDictionary *updated = [self.conversations mutableCopy]; updated[peer] = rows;
    NSData *data = [NSJSONSerialization dataWithJSONObject:updated options:0 error:error];
    if (!data || ![data writeToURL:self.file options:NSDataWritingAtomic error:error]) return NO;
    chmod([[self.file path] fileSystemRepresentation], 0600);
    self.conversations = updated;
    return YES;
}
@end
