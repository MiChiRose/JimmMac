@interface JMBackupLockFixture : JMHistory
@property(nonatomic,strong) dispatch_semaphore_t snapshotStarted;
@property(nonatomic,strong) dispatch_semaphore_t allowSnapshot;
@end
@implementation JMBackupLockFixture
- (BOOL)writeBackupToURL:(NSURL *)url manifest:(NSDictionary *)manifest error:(NSError **)error {
    if (self.snapshotStarted) { dispatch_semaphore_signal(self.snapshotStarted); if (dispatch_semaphore_wait(self.allowSnapshot,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))!=0) return NO; }
    return [super writeBackupToURL:url manifest:manifest error:error];
}
@end
static void ImprovementChecks(void) {
    NSString *secret=@"PRIVATE-SECRET";
    NSArray *entries=@[@{@"endpoint":@"/aim/fetchEvents",@"http":@503,@"api":@0,@"errorCode":@(-1009),@"errorDomain":NSURLErrorDomain,@"time":@1700000000,@"token":secret,@"message":secret},@{@"endpoint":@"/im/sendIM",@"http":@200,@"api":@200,@"errorDomain":secret,@"errorCode":@0,@"time":@1700000001},@{@"endpoint":secret,@"time":@0}];
    NSArray *safe=JMSafeDiagnosticEntries(entries);
    NSString *report=JMDiagnosticReport(@{@"CFBundleShortVersionString":@"0.15.0",@"CFBundleVersion":@"24"},@"10.9.5",secret,YES,entries);
    Check(safe.count==2 && [safe[1][@"errorDomain"] isEqual:@"other"],@"diagnostic snapshot allowlists routes and error domains");
    Check([report rangeOfString:secret].location==NSNotFound && [report rangeOfString:@"Last error:"].location!=NSNotFound && [report rangeOfString:@"NSURLConnection"].location!=NSNotFound,@"copyable diagnostic report contains codes but excludes arbitrary account data");
    Check([safe[0] count]==6 && !safe[0][@"token"],@"diagnostic report only exposes six approved metadata fields");
    NSMutableArray *many=[NSMutableArray array]; for (NSUInteger i=0;i<100;i++) [many addObject:entries[0]];
    Check(JMSafeDiagnosticEntries(many).count==20,@"diagnostic report is bounded");
    JMAutoAway *policy=[[JMAutoAway alloc] init]; policy.interval=300;
    Check(![policy requestedPresenceForIdle:299 connected:YES],@"auto-away does not trigger before threshold");
    Check(![policy requestedPresenceForIdle:301 connected:NO],@"auto-away does not change a disconnected account");
    Check([[policy requestedPresenceForIdle:301 connected:YES] isEqual:@"away"] && policy.automaticallyAway,@"idle online session requests away once");
    Check(![policy requestedPresenceForIdle:500 connected:YES],@"idle polls do not repeatedly change server status");
    Check([[policy requestedPresenceForIdle:0 connected:YES] isEqual:@"online"] && !policy.automaticallyAway,@"activity restores online only after automatic away");
    for (NSString *state in @[@"away",@"dnd",@"invisible",@"occupied"]) { [policy manualPresenceChanged:state]; [policy requestedPresenceForIdle:0 connected:YES]; Check(![policy requestedPresenceForIdle:900 connected:YES],@"manual non-online status survives idle and activity"); }
    [policy manualPresenceChanged:@"online"];
    Check(![policy requestedPresenceForIdle:900 connected:YES],@"manual online choice holds until fresh input");
    [policy requestedPresenceForIdle:0 connected:YES]; [policy requestedPresenceForIdle:901 connected:YES]; [policy requestFailedForState:@"away"];
    Check(!policy.automaticallyAway && [[policy requestedPresenceForIdle:902 connected:YES] isEqual:@"away"],@"failed automatic away can be retried without losing manual preference");
    policy.interval=0; Check([[policy requestedPresenceForIdle:902 connected:YES] isEqual:@"online"],@"disabling automatic away restores the prior online state");
    NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]] isDirectory:YES];
    JMHistory *history=[[JMHistory alloc] initWithUIN:@"123" root:root];
    for (NSUInteger i=0;i<5;i++) { NSString *peer=i==4 ? @"333" : @"222";
        Check([history appendMessage:@{@"id":[NSString stringWithFormat:@"m%lu",(unsigned long)i],@"peer":peer,@"text":@"Date search HELLO :)",@"timestamp":@(100+i*100),@"outgoing":@NO} unread:YES error:NULL],@"date-filter fixture saved"); }
    NSDate *from=[NSDate dateWithTimeIntervalSince1970:200], *until=[NSDate dateWithTimeIntervalSince1970:400];
    Check([history searchQuery:@"hello" peer:@"222" from:from until:until bookmarked:NO limit:200].count==2,@"history combines Unicode text, peer and half-open date range");
    Check([history searchQuery:@"" peer:nil from:from until:until bookmarked:NO limit:200].count==2,@"date-only search does not require a phrase");
    Check([history searchQuery:@"hello" peer:nil from:until until:from bookmarked:NO limit:200].count==0,@"reversed date range cannot match history");
    Check([history setBookmarked:YES identifier:@"m1" peer:@"222" error:NULL] && [history isBookmarkedID:@"m1" peer:@"222"],@"bookmark stored for exact peer and message ID");
    Check(![history setBookmarked:YES identifier:@"missing" peer:@"222" error:NULL],@"missing message cannot create an orphan bookmark");
    Check([history searchQuery:@"" peer:nil from:nil until:nil bookmarked:YES limit:200].count==1,@"bookmarks can be browsed without query or date");
    JMHistory *reopened=[[JMHistory alloc] initWithUIN:@"123" root:root]; Check([reopened isBookmarkedID:@"m1" peer:@"222"],@"bookmarks survive closing and reopening history");
    Check([[history firstMessageForPeer:@"222" from:from until:until][@"id"] isEqual:@"m1"],@"jump-to-day chooses earliest matching message");
    Check([history countMessagesForPeer:@"222" from:from until:until]==2 && [[history storageStatistics][@"messages"] integerValue]==5 && [[history storageStatistics][@"bytes"] unsignedLongLongValue]>0,@"storage summary and deletion preview report real database counts and bytes");
    NSURL *backup=[root URLByAppendingPathComponent:@"cleanup.jimmbackup"];
    NSDictionary *manifest=@{@"format":@"JimmMacBackup",@"version":@1,@"uin":@"123",@"createdAt":@1700000000,@"drafts":@{},@"roster":@{},@"preferences":@{}};
    Check([history writeBackupToURL:backup manifest:manifest error:NULL],@"pre-cleanup backup saved");
    Check(![history deleteMessagesForPeer:nil from:until until:from error:NULL] && [history countForPeer:@"222"]==4,@"invalid deletion range leaves all messages intact");
    Check([history deleteMessagesForPeer:@"222" from:from until:until error:NULL],@"selected-period deletion succeeds");
    Check([history countForPeer:@"222"]==2 && [history countForPeer:@"333"]==1 && [history messageWithID:@"m3" peer:@"222"] && ![history isBookmarkedID:@"m1" peer:@"222"],@"deletion preserves other peers and upper-bound message, removing deleted bookmarks");
    Check([[history unreadCounts][@"222"] integerValue]==2,@"unread counts follow surviving history");
    Check([history mergeBackupAtURL:backup error:NULL]==2 && [history isBookmarkedID:@"m1" peer:@"222"],@"portable backup restores deleted messages and their bookmarks");
    Check([history mergeBackupAtURL:backup error:NULL]==0,@"bookmark backup restore remains idempotent");
    Check([history setBookmarked:NO identifier:@"m1" peer:@"222" error:NULL] && ![history isBookmarkedID:@"m1" peer:@"222"],@"bookmark can be removed without deleting message");
    NSDictionary *prefs=JMSafePreferences(@{@"AutoAwayMinutes":@15,@"CompactContactList":@YES,@"password":secret});
    Check([prefs[@"AutoAwayMinutes"] integerValue]==15 && [prefs[@"CompactContactList"] boolValue] && !prefs[@"password"],@"portable preferences preserve auto-away minutes and density without credentials");
    Check(!JMSafePreferences(@{@"AutoAwayMinutes":@(-5)})[@"AutoAwayMinutes"],@"invalid imported idle threshold is ignored");
    JMBackupLockFixture *locked=[[JMBackupLockFixture alloc] initWithUIN:@"123" root:root]; locked.snapshotStarted=dispatch_semaphore_create(0); locked.allowSnapshot=dispatch_semaphore_create(0);
    dispatch_semaphore_t finished=dispatch_semaphore_create(0); __block BOOL cleaned=NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{ cleaned=[locked deleteMessagesForPeer:@"222" from:from until:until backupURL:backup manifest:manifest error:NULL]; dispatch_semaphore_signal(finished); });
    Check(dispatch_semaphore_wait(locked.snapshotStarted,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0,@"cleanup reaches backup while holding its write reservation");
    sqlite3 *incoming=NULL; NSString *databasePath=[[JMAccountDirectory(@"123",root) URLByAppendingPathComponent:@"history.sqlite"] path];
    sqlite3_open_v2(databasePath.fileSystemRepresentation,&incoming,SQLITE_OPEN_READWRITE,NULL);
    int writeResult=sqlite3_exec(incoming,"UPDATE messages SET text='concurrent update' WHERE peer='222'",NULL,NULL,NULL); sqlite3_close(incoming);
    Check(writeResult==SQLITE_BUSY,@"concurrent incoming writes cannot cross the backup/deletion snapshot boundary");
    dispatch_semaphore_signal(locked.allowSnapshot);
    Check(dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0 && cleaned,@"atomic backup and deletion finish without UI-thread work");
    Check([history mergeBackupAtURL:backup error:NULL]==2,@"atomic pre-deletion backup includes every removed message");
    [[NSFileManager defaultManager] removeItemAtURL:root error:NULL];
}
