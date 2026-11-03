#import "JMLocalization.h"
#import "JMHistory.h"
#import "JMProtocol.h"
#import "JMAccountData.h"
#import <sqlite3.h>
#import <sys/stat.h>
#import <math.h>

static NSString *SQLText(sqlite3_stmt *s,int col) { const unsigned char *p=sqlite3_column_text(s,col); return p ? [NSString stringWithUTF8String:(const char *)p] : @""; }
static void Bind(sqlite3_stmt *s,int col,NSString *text) { sqlite3_bind_text(s,col,[text ?: @"" UTF8String],(int)[text ?: @"" lengthOfBytesUsingEncoding:NSUTF8StringEncoding],SQLITE_TRANSIENT); }
static NSError *HistoryError(void) { return [NSError errorWithDomain:@"online.jimm.history" code:1 userInfo:@{NSLocalizedDescriptionKey:JML(@"Не удалось прочитать или сохранить историю. Исходные файлы оставлены на месте. Проверьте свободное место и права доступа.")}]; }
static NSDictionary *ReadMessage(sqlite3_stmt *s) {
    NSData *data=[SQLText(s,0) dataUsingEncoding:NSUTF8StringEncoding];
    id decoded=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
    if (![decoded isKindOfClass:[NSDictionary class]]) return nil;
    NSMutableDictionary *row=[decoded mutableCopy]; row[@"delivery"]=SQLText(s,1); return row;
}
static NSString *EscapeHTML(NSString *s) {
    return [[[[[s ?: @"" stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"] stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"] stringByReplacingOccurrencesOfString:@"'" withString:@"&#39;"];
}
static void Contains(sqlite3_context *context,int argc,sqlite3_value **values) {
    @autoreleasepool {
        const char *a=(const char *)sqlite3_value_text(values[0]), *b=(const char *)sqlite3_value_text(values[1]);
        NSString *text=a ? [NSString stringWithUTF8String:a] : @"", *query=b ? [NSString stringWithUTF8String:b] : @"";
        sqlite3_result_int(context,[text rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound);
    }
}
@interface JMHistory () {
    sqlite3 *_database;
}
@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *accountUIN;
@property(nonatomic, strong, readwrite) NSError *loadError;
@end
@implementation JMHistory
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root {
    self=[super init]; if (!self || !JMValidUIN(uin)) return nil; self.accountUIN=uin;
    if (!root) root=[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory=[[root URLByAppendingPathComponent:@"JimmMac/accounts" isDirectory:YES] URLByAppendingPathComponent:uin isDirectory:YES];
    NSError *error=nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) { self.loadError=error; return self; }
    self.path=[[directory URLByAppendingPathComponent:@"history.sqlite"] path];
    if (sqlite3_open_v2(self.path.fileSystemRepresentation,&_database,SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FULLMUTEX,NULL)!=SQLITE_OK) { self.loadError=HistoryError(); return self; }
    chmod(self.path.fileSystemRepresentation,0600); sqlite3_busy_timeout(_database,3000);
    sqlite3_stmt *check=NULL;
    BOOL valid=sqlite3_prepare_v2(_database,"PRAGMA quick_check",-1,&check,NULL)==SQLITE_OK && sqlite3_step(check)==SQLITE_ROW && [SQLText(check,0) isEqualToString:@"ok"];
    sqlite3_finalize(check);
    if (!valid || ![self execute:@"PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT); CREATE TABLE IF NOT EXISTS messages(peer TEXT NOT NULL,id TEXT NOT NULL,ts REAL NOT NULL,outgoing INTEGER NOT NULL,unread INTEGER NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT '',text TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(peer,id)); CREATE INDEX IF NOT EXISTS message_order ON messages(peer,ts,id); CREATE INDEX IF NOT EXISTS unread_order ON messages(unread,peer,ts,id);" error:&error]) { self.loadError=error ?: HistoryError(); return self; }
    sqlite3_stmt *marker=NULL; sqlite3_prepare_v2(_database,"SELECT value FROM metadata WHERE key='migration'",-1,&marker,NULL);
    BOOL migrated=sqlite3_step(marker)==SQLITE_ROW; sqlite3_finalize(marker);
    if (!migrated) {
        NSURL *legacy=[directory URLByAppendingPathComponent:@"history.json"]; NSDictionary *json=@{};
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacy.path]) {
            NSData *data=[NSData dataWithContentsOfURL:legacy options:0 error:&error];
            id decoded=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
            if (![decoded isKindOfClass:[NSDictionary class]] || error) { self.loadError=error ?: HistoryError(); return self; }
            json=decoded;
        }
        BOOL ok=[self execute:@"BEGIN IMMEDIATE" error:&error];
        for (NSString *peer in json) {
            if (!ok || !JMValidUIN(peer) || ![json[peer] isKindOfClass:[NSArray class]]) continue;
            for (id row in json[peer]) {
                if (![row isKindOfClass:[NSDictionary class]] || ![row[@"text"] isKindOfClass:[NSString class]] || ![row[@"id"] isKindOfClass:[NSString class]]) continue;
                NSMutableDictionary *message=[row mutableCopy]; message[@"peer"]=peer;
                if (![self appendMessage:message error:&error]) { ok=NO; break; }
            }
        }
        if (ok) ok=[self execute:@"INSERT INTO metadata VALUES('migration','1'); COMMIT" error:&error];
        if (!ok) { [self execute:@"ROLLBACK" error:NULL]; self.loadError=error ?: HistoryError(); return self; }
        // The old JSON is deliberately retained as a migration backup.
    }
    if (![self execute:@"UPDATE messages SET state='unknown' WHERE state='pending'" error:&error]) self.loadError=error;
    return self;
}
- (void)dealloc { if (_database) sqlite3_close(_database); }
- (BOOL)execute:(NSString *)sql error:(NSError **)error {
    if (!_database || sqlite3_exec(_database,sql.UTF8String,NULL,NULL,NULL)!=SQLITE_OK) { if (error) *error=HistoryError(); return NO; } return YES;
}
- (NSArray *)query:(NSString *)sql strings:(NSArray *)strings database:(sqlite3 *)db {
    sqlite3_stmt *s=NULL; NSMutableArray *rows=[NSMutableArray array];
    if (sqlite3_prepare_v2(db,sql.UTF8String,-1,&s,NULL)==SQLITE_OK) {
        for (NSUInteger i=0;i<strings.count;i++) Bind(s,(int)i+1,strings[i]);
        while (sqlite3_step(s)==SQLITE_ROW) { NSDictionary *row=ReadMessage(s); if (row) [rows addObject:row]; }
    }
    sqlite3_finalize(s); return rows;
}
- (NSArray *)messagesForPeer:(NSString *)peer { return [self messagesForPeer:peer offset:0 limit:NSUIntegerMax]; }
- (NSArray *)messagesForPeer:(NSString *)peer offset:(NSUInteger)offset limit:(NSUInteger)limit {
    return [self query:[NSString stringWithFormat:@"SELECT payload,state FROM messages WHERE peer=? ORDER BY ts,id LIMIT %lld OFFSET %llu",limit==NSUIntegerMax ? -1LL : (long long)limit,(unsigned long long)offset] strings:@[peer ?: @""] database:_database];
}
- (NSUInteger)countForPeer:(NSString *)peer {
    sqlite3_stmt *s=NULL; NSUInteger n=0;
    if (sqlite3_prepare_v2(_database,"SELECT count(*) FROM messages WHERE peer=?",-1,&s,NULL)==SQLITE_OK) { Bind(s,1,peer); if (sqlite3_step(s)==SQLITE_ROW) n=(NSUInteger)sqlite3_column_int64(s,0); } sqlite3_finalize(s); return n;
}
- (NSDictionary *)lastMessageForPeer:(NSString *)peer { return [[self query:@"SELECT payload,state FROM messages WHERE peer=? ORDER BY ts DESC,id DESC LIMIT 1" strings:@[peer ?: @""] database:_database] firstObject]; }
- (NSDictionary *)messageWithID:(NSString *)identifier peer:(NSString *)peer { return [[self query:@"SELECT payload,state FROM messages WHERE peer=? AND id=?" strings:@[peer ?: @"",identifier ?: @""] database:_database] firstObject]; }
- (NSUInteger)indexOfMessage:(NSString *)identifier peer:(NSString *)peer {
    NSDictionary *message=[self messageWithID:identifier peer:peer]; if (!message) return NSNotFound;
    sqlite3_stmt *s=NULL; NSUInteger index=NSNotFound;
    if (sqlite3_prepare_v2(_database,"SELECT count(*) FROM messages WHERE peer=? AND (ts<? OR (ts=? AND id<?))",-1,&s,NULL)==SQLITE_OK) {
        Bind(s,1,peer); sqlite3_bind_double(s,2,[message[@"timestamp"] doubleValue]); sqlite3_bind_double(s,3,[message[@"timestamp"] doubleValue]); Bind(s,4,identifier);
        if (sqlite3_step(s)==SQLITE_ROW) index=(NSUInteger)sqlite3_column_int64(s,0);
    } sqlite3_finalize(s); return index;
}
- (NSArray *)peers {
    NSMutableArray *peers=[NSMutableArray array]; sqlite3_stmt *s=NULL;
    if (sqlite3_prepare_v2(_database,"SELECT DISTINCT peer FROM messages",-1,&s,NULL)==SQLITE_OK) while (sqlite3_step(s)==SQLITE_ROW) [peers addObject:SQLText(s,0)]; sqlite3_finalize(s); return peers;
}
- (NSDictionary *)searchSnapshot { NSMutableDictionary *result=[NSMutableDictionary dictionary]; for (NSString *peer in self.peers) result[peer]=[self messagesForPeer:peer]; return result; }
+ (NSArray *)searchSnapshot:(NSDictionary *)snapshot query:(NSString *)query peer:(NSString *)peer limit:(NSUInteger)limit {
    query=[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (!query.length || !limit) return @[];
    NSMutableArray *hits=[NSMutableArray array];
    for (NSString *uin in snapshot) if (!peer.length || [peer isEqual:uin]) for (NSDictionary *row in snapshot[uin]) if ([JMString(row[@"text"]) rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound) { NSMutableDictionary *hit=[row mutableCopy]; hit[@"peer"]=uin; [hits addObject:hit]; }
    [hits sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) { NSComparisonResult order=[b[@"timestamp"] compare:a[@"timestamp"]]; if (order==NSOrderedSame) order=[JMString(a[@"peer"]) compare:JMString(b[@"peer"])]; return order==NSOrderedSame ? [JMString(a[@"id"]) compare:JMString(b[@"id"])] : order; }];
    return hits.count>limit ? [hits subarrayWithRange:NSMakeRange(0,limit)] : hits;
}
- (NSArray *)searchQuery:(NSString *)query peer:(NSString *)peer limit:(NSUInteger)limit {
    if (!query.length || !limit || self.loadError) return @[]; sqlite3 *reader=NULL;
    if (sqlite3_open_v2(self.path.fileSystemRepresentation,&reader,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,NULL)!=SQLITE_OK) { if (reader) sqlite3_close(reader); return @[]; }
    sqlite3_create_function(reader,"jm_contains",2,SQLITE_UTF8,NULL,Contains,NULL,NULL);
    NSString *sql=[NSString stringWithFormat:@"SELECT payload,state FROM messages WHERE %@jm_contains(text,?) ORDER BY ts DESC,peer,id LIMIT %llu",peer.length ? @"peer=? AND " : @"",(unsigned long long)limit];
    NSArray *rows=[self query:sql strings:peer.length ? @[peer,query] : @[query] database:reader]; sqlite3_close(reader); return rows;
}
- (BOOL)appendMessage:(NSDictionary *)message error:(NSError **)error { return [self appendMessage:message unread:NO error:error]; }
- (BOOL)appendMessage:(NSDictionary *)message unread:(BOOL)unread error:(NSError **)error {
    if (self.loadError) { if (error) *error=self.loadError; return NO; }
    NSString *peer=JMString(message[@"peer"]), *identifier=JMString(message[@"id"]);
    if (!JMValidUIN(peer) || !identifier.length || ![message[@"id"] isKindOfClass:[NSString class]] || ![message[@"text"] isKindOfClass:[NSString class]] || ![message[@"outgoing"] isKindOfClass:[NSNumber class]] || !([message[@"timestamp"] isKindOfClass:[NSNumber class]] || [message[@"timestamp"] isKindOfClass:[NSString class]])) { if (error) *error=HistoryError(); return NO; }
    NSMutableDictionary *canonical=[message mutableCopy]; double timestamp=[message[@"timestamp"] doubleValue]; if (!isfinite(timestamp)) timestamp=0; canonical[@"timestamp"]=@(timestamp);
    NSData *data=[NSJSONSerialization dataWithJSONObject:canonical options:0 error:error]; if (!data) return NO;
    sqlite3_stmt *s=NULL; BOOL ok=sqlite3_prepare_v2(_database,"INSERT OR IGNORE INTO messages(peer,id,ts,outgoing,unread,state,text,payload) VALUES(?,?,?,?,?,?,?,?)",-1,&s,NULL)==SQLITE_OK;
    if (ok) { Bind(s,1,peer); Bind(s,2,identifier); sqlite3_bind_double(s,3,timestamp); sqlite3_bind_int(s,4,[message[@"outgoing"] boolValue]); sqlite3_bind_int(s,5,unread && ![message[@"outgoing"] boolValue]); Bind(s,6,JMString(message[@"delivery"]).length ? message[@"delivery"] : ([message[@"outgoing"] boolValue] ? @"accepted" : @"")); Bind(s,7,message[@"text"]); Bind(s,8,[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]); ok=sqlite3_step(s)==SQLITE_DONE; }
    sqlite3_finalize(s); if (!ok && error) *error=HistoryError(); return ok;
}
- (NSDictionary *)unreadCounts {
    NSMutableDictionary *counts=[NSMutableDictionary dictionary]; sqlite3_stmt *s=NULL;
    if (sqlite3_prepare_v2(_database,"SELECT peer,count(*) FROM messages WHERE unread=1 GROUP BY peer",-1,&s,NULL)==SQLITE_OK) while (sqlite3_step(s)==SQLITE_ROW) counts[SQLText(s,0)]=@(sqlite3_column_int64(s,1)); sqlite3_finalize(s); return counts;
}
- (NSString *)firstUnreadIDForPeer:(NSString *)peer {
    sqlite3_stmt *s=NULL; NSString *identifier=nil;
    if (sqlite3_prepare_v2(_database,"SELECT id FROM messages WHERE peer=? AND unread=1 ORDER BY ts,id LIMIT 1",-1,&s,NULL)==SQLITE_OK) { Bind(s,1,peer); if (sqlite3_step(s)==SQLITE_ROW) identifier=SQLText(s,0); } sqlite3_finalize(s); return identifier;
}
- (BOOL)markReadPeer:(NSString *)peer error:(NSError **)error {
    sqlite3_stmt *s=NULL; BOOL ok=!self.loadError && sqlite3_prepare_v2(_database,peer ? "UPDATE messages SET unread=0 WHERE peer=? AND unread=1" : "UPDATE messages SET unread=0 WHERE unread=1",-1,&s,NULL)==SQLITE_OK;
    if (ok) { if (peer) Bind(s,1,peer); ok=sqlite3_step(s)==SQLITE_DONE; } sqlite3_finalize(s); if (!ok && error) *error=self.loadError ?: HistoryError(); return ok;
}
- (BOOL)setDelivery:(NSString *)state forID:(NSString *)identifier peer:(NSString *)peer error:(NSError **)error {
    sqlite3_stmt *s=NULL; BOOL ok=!self.loadError && sqlite3_prepare_v2(_database,"UPDATE messages SET state=? WHERE peer=? AND id=?",-1,&s,NULL)==SQLITE_OK;
    if (ok) { Bind(s,1,state); Bind(s,2,peer); Bind(s,3,identifier); ok=sqlite3_step(s)==SQLITE_DONE && sqlite3_changes(_database)>0; } sqlite3_finalize(s); if (!ok && error) *error=self.loadError ?: HistoryError(); return ok;
}
- (BOOL)confirmLocalID:(NSString *)identifier peer:(NSString *)peer message:(NSDictionary *)message error:(NSError **)error {
    if (![self execute:@"BEGIN IMMEDIATE" error:error]) return NO;
    sqlite3_stmt *s=NULL; BOOL ok=sqlite3_prepare_v2(_database,"DELETE FROM messages WHERE peer=? AND id=?",-1,&s,NULL)==SQLITE_OK;
    if (ok) { Bind(s,1,peer); Bind(s,2,identifier); ok=sqlite3_step(s)==SQLITE_DONE; } sqlite3_finalize(s);
    NSMutableDictionary *confirmed=[message mutableCopy]; confirmed[@"delivery"]=@"accepted";
    if (ok) ok=[self appendMessage:confirmed error:error];
    if (ok) ok=[self setDelivery:@"accepted" forID:message[@"id"] peer:peer error:error];
    if (ok) ok=[self execute:@"COMMIT" error:error]; if (!ok) { [self execute:@"ROLLBACK" error:NULL]; if (error && !*error) *error=HistoryError(); } return ok;
}
- (BOOL)exportPeer:(NSString *)peer name:(NSString *)name account:(NSString *)account html:(BOOL)html toURL:(NSURL *)url error:(NSError **)error {
    // Export uses its own SQLite snapshot and a temporary sibling file; no partial destination.
    sqlite3 *reader=NULL; sqlite3_stmt *s=NULL;
    if (sqlite3_open_v2(self.path.fileSystemRepresentation,&reader,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,NULL)!=SQLITE_OK) { if (reader) sqlite3_close(reader); if (error) *error=HistoryError(); return NO; }
    NSURL *temp=[[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:[@".jimmmac-export-" stringByAppendingString:[[NSUUID UUID] UUIDString]]];
    BOOL ok=[[NSFileManager defaultManager] createFileAtPath:temp.path contents:nil attributes:@{NSFilePosixPermissions:@0600}];
    NSFileHandle *handle=ok ? [NSFileHandle fileHandleForWritingAtPath:temp.path] : nil;
    NSDateFormatter *date=[[NSDateFormatter alloc] init]; date.dateFormat=@"dd.MM.yyyy HH:mm:ss";
    NSString *title=[NSString stringWithFormat:JML(@"Переписка с %@ · UIN %@"),name,peer];
    @try {
        if (!handle) @throw [NSException exceptionWithName:@"Export" reason:nil userInfo:nil];
        NSString *header=html ? [NSString stringWithFormat:JML(@"<!doctype html><html lang=\"ru\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><title>%@</title><style>body{max-width:800px;margin:40px auto;padding:0 20px;font:15px/1.5 sans-serif;background:#f5f6f2;color:#222}article{border-bottom:1px solid #ddd;padding:12px 0}header{color:#426b37}p{white-space:pre-wrap;overflow-wrap:break-word}</style><h1>%@</h1><p>Аккаунт: UIN %@</p>"),EscapeHTML(title),EscapeHTML(title),EscapeHTML(account)] : [NSString stringWithFormat:JML(@"%@\nАккаунт: UIN %@\n\n"),title,account];
        [handle writeData:[header dataUsingEncoding:NSUTF8StringEncoding]];
        ok=sqlite3_prepare_v2(reader,"SELECT payload,state FROM messages WHERE peer=? ORDER BY ts,id",-1,&s,NULL)==SQLITE_OK;
        if (ok) { Bind(s,1,peer); int result;
            while ((result=sqlite3_step(s))==SQLITE_ROW) { @autoreleasepool {
                NSDictionary *message=ReadMessage(s); NSString *who=[message[@"outgoing"] boolValue] ? JML(@"Вы") : name;
                NSString *when=[date stringFromDate:[NSDate dateWithTimeIntervalSince1970:[message[@"timestamp"] doubleValue]]];
                NSString *state=JMString(message[@"delivery"]), *note=@"";
                if ([state isEqual:@"unknown"]) note=JML(@" · Подтверждение не получено"); else if ([state isEqual:@"failed"]) note=JML(@" · Не отправлено"); else if ([state isEqual:@"pending"]) note=JML(@" · Отправляется");
                NSString *row=html ? [NSString stringWithFormat:@"<article><header>%@ · %@%@</header><p>%@</p></article>\n",EscapeHTML(who),EscapeHTML(when),EscapeHTML(note),EscapeHTML(message[@"text"])] : [NSString stringWithFormat:@"[%@] %@%@\n%@\n\n",when,who,note,message[@"text"]];
                [handle writeData:[row dataUsingEncoding:NSUTF8StringEncoding]];
            }} if (result!=SQLITE_DONE) ok=NO;
        }
        if (html) [handle writeData:[@"</html>" dataUsingEncoding:NSUTF8StringEncoding]];
        [handle synchronizeFile]; [handle closeFile];
    } @catch (NSException *exception) { ok=NO; [handle closeFile]; }
    sqlite3_finalize(s); sqlite3_close(reader);
    if (ok) { if (rename(temp.path.fileSystemRepresentation,url.path.fileSystemRepresentation)!=0) ok=NO; }
    if (!ok) { [[NSFileManager defaultManager] removeItemAtURL:temp error:NULL]; if (error) *error=HistoryError(); } return ok;
}
- (BOOL)writeBackupToURL:(NSURL *)url manifest:(NSDictionary *)manifest error:(NSError **)error {
    if (!url.isFileURL || !url.path.length || [url.path.stringByStandardizingPath isEqual:self.path.stringByStandardizingPath]) { if (error) *error=HistoryError(); return NO; }
    NSDictionary *safe=JMBackupManifest(manifest,error); if (!safe || ![safe[@"uin"] isEqual:self.accountUIN] || self.loadError) { if (error && self.loadError) *error=self.loadError; return NO; }
    NSData *metadata=[NSJSONSerialization dataWithJSONObject:safe options:0 error:error]; if (!metadata || metadata.length>24*1024*1024) return NO;
    NSURL *temporary=[[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:[@".jimmbackup-" stringByAppendingString:[[NSUUID UUID] UUIDString]]];
    sqlite3 *reader=NULL,*writer=NULL;
    BOOL ok=sqlite3_open_v2(self.path.fileSystemRepresentation,&reader,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,NULL)==SQLITE_OK && sqlite3_open_v2(temporary.path.fileSystemRepresentation,&writer,SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FULLMUTEX,NULL)==SQLITE_OK;
    if (ok) ok=sqlite3_exec(reader,"BEGIN; SELECT count(*) FROM messages",NULL,NULL,NULL)==SQLITE_OK;
    if (ok) { chmod(temporary.path.fileSystemRepresentation,0600); sqlite3_backup *copy=sqlite3_backup_init(writer,"main",reader,"main");
        if (!copy) ok=NO;
        else { int result; NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:30];
            do { result=sqlite3_backup_step(copy,128); if (result==SQLITE_OK) deadline=[NSDate dateWithTimeIntervalSinceNow:30]; if (result==SQLITE_BUSY || result==SQLITE_LOCKED) [NSThread sleepForTimeInterval:0.01]; } while ((result==SQLITE_OK || result==SQLITE_BUSY || result==SQLITE_LOCKED) && deadline.timeIntervalSinceNow>0);
            ok=sqlite3_backup_finish(copy)==SQLITE_OK && result==SQLITE_DONE;
        }
    }
    sqlite3_stmt *s=NULL;
    if (ok) ok=sqlite3_exec(writer,"DELETE FROM metadata WHERE key!='migration'",NULL,NULL,NULL)==SQLITE_OK && sqlite3_prepare_v2(writer,"INSERT INTO metadata(key,value) VALUES('backupManifest',?)",-1,&s,NULL)==SQLITE_OK;
    if (ok) { Bind(s,1,[[NSString alloc] initWithData:metadata encoding:NSUTF8StringEncoding]); ok=sqlite3_step(s)==SQLITE_DONE; } sqlite3_finalize(s);
    // A portable backup must not depend on WAL sidecars, especially on pre-3.22 SQLite.
    if (ok) ok=sqlite3_exec(writer,"PRAGMA journal_mode=DELETE",NULL,NULL,NULL)==SQLITE_OK;
    if (reader) sqlite3_close(reader); if (writer) sqlite3_close(writer);
    if (ok) ok=rename(temporary.path.fileSystemRepresentation,url.path.fileSystemRepresentation)==0;
    if (!ok) { [[NSFileManager defaultManager] removeItemAtURL:temporary error:NULL]; [[NSFileManager defaultManager] removeItemAtPath:[temporary.path stringByAppendingString:@"-journal"] error:NULL]; if (error && !*error) *error=HistoryError(); } return ok;
}
+ (NSDictionary *)backupManifestAtURL:(NSURL *)url error:(NSError **)error {
    if (!url.isFileURL || !url.path.length) { if (error) *error=HistoryError(); return nil; }
    sqlite3 *reader=NULL; sqlite3_stmt *s=NULL; NSDictionary *manifest=nil;
    if (sqlite3_open_v2(url.path.fileSystemRepresentation,&reader,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,NULL)==SQLITE_OK) {
        BOOL ok=sqlite3_prepare_v2(reader,"PRAGMA quick_check",-1,&s,NULL)==SQLITE_OK && sqlite3_step(s)==SQLITE_ROW && [SQLText(s,0) isEqual:@"ok"]; sqlite3_finalize(s); s=NULL;
        for (NSString *table in @[@"messages",@"metadata"]) {
            if (ok) ok=sqlite3_prepare_v2(reader,"SELECT type,sql FROM sqlite_master WHERE name=?",-1,&s,NULL)==SQLITE_OK;
            if (ok) { Bind(s,1,table); ok=sqlite3_step(s)==SQLITE_ROW && [SQLText(s,0) isEqual:@"table"] && [[SQLText(s,1) uppercaseString] rangeOfString:@"CREATE VIRTUAL"].location==NSNotFound; }
            sqlite3_finalize(s); s=NULL;
        }
        if (ok && sqlite3_prepare_v2(reader,"SELECT value FROM metadata WHERE key='backupManifest'",-1,&s,NULL)==SQLITE_OK && sqlite3_step(s)==SQLITE_ROW && sqlite3_column_bytes(s,0)<=24*1024*1024) {
            NSData *data=[SQLText(s,0) dataUsingEncoding:NSUTF8StringEncoding]; id decoded=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if ([decoded isKindOfClass:[NSDictionary class]]) manifest=JMBackupManifest(decoded,error);
        }
        sqlite3_finalize(s);
    }
    if (reader) sqlite3_close(reader);
    if (!manifest && error && !*error) *error=HistoryError(); return manifest;
}
- (NSUInteger)mergeBackupAtURL:(NSURL *)url error:(NSError **)error {
    NSDictionary *manifest=[[self class] backupManifestAtURL:url error:error];
    if (!manifest || ![manifest[@"uin"] isEqual:self.accountUIN] || self.loadError) { if (error && !*error) *error=HistoryError(); return NSNotFound; }
    sqlite3 *reader=NULL; sqlite3_stmt *s=NULL;
    BOOL ok=sqlite3_open_v2(url.path.fileSystemRepresentation,&reader,SQLITE_OPEN_READONLY|SQLITE_OPEN_FULLMUTEX,NULL)==SQLITE_OK;
    if (ok) { ok=sqlite3_prepare_v2(reader,"SELECT payload,state,unread FROM messages ORDER BY ts,id",-1,&s,NULL)==SQLITE_OK; }
    if (ok) ok=[self execute:@"BEGIN IMMEDIATE" error:error];
    NSUInteger count=0; int result=SQLITE_DONE;
    while (ok && (result=sqlite3_step(s))==SQLITE_ROW) { @autoreleasepool {
        if (sqlite3_column_bytes(s,0)>8*1024*1024) { ok=NO; break; }
        NSMutableDictionary *message=[ReadMessage(s) mutableCopy];
        if (!message || !JMValidUIN(JMString(message[@"peer"])) || ![message[@"id"] isKindOfClass:[NSString class]] || ![message[@"id"] length] || ![message[@"text"] isKindOfClass:[NSString class]] || ![message[@"outgoing"] isKindOfClass:[NSNumber class]] || !([message[@"timestamp"] isKindOfClass:[NSNumber class]] || [message[@"timestamp"] isKindOfClass:[NSString class]])) { ok=NO; break; }
        if ([message[@"delivery"] isEqual:@"pending"]) message[@"delivery"]=@"unknown";
        if (![self messageWithID:message[@"id"] peer:message[@"peer"]]) {
            ok=[self appendMessage:message unread:sqlite3_column_int(s,2)!=0 error:error]; if (ok) count++;
        }
    }}
    if (result!=SQLITE_DONE) ok=NO;
    sqlite3_finalize(s); if (reader) sqlite3_close(reader);
    if (ok) ok=[self execute:@"COMMIT" error:error];
    if (!ok) { [self execute:@"ROLLBACK" error:NULL]; if (error && !*error) *error=HistoryError(); return NSNotFound; } return count;
}
@end
