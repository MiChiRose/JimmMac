#import <Cocoa/Cocoa.h>
#import "JMAppDelegate.h"
#import "JMHistory.h"
#import "JMAPIClient.h"
#import "JMStyle.h"
#import "JMAvatarStore.h"
#import "JMAudioAlerts.h"
#import "JMChatPreferences.h"
#import "JMProtocol.h"
#import "JMNotificationAlerts.h"
#import "JMOwnProfileController.h"
#import "JMDraftStore.h"
#import "JMLoginStore.h"
#import "JMInformationController.h"
#import "JMKeyboard.h"
#import "JMHTTPClient.h"
#import "JMEmoticons.h"
#import "JMUpdateChecker.h"
#import "JMAccountData.h"
#import "JMTheme.h"
#import "JMAutoAway.h"
#import "JMLocalization.h"
@interface JMHTTPTask (TransportProbe)
- (BOOL)allowsRedirect:(NSURLRequest *)request;
@end
@interface JMAvatarStore (DownloadProbe)
- (void)completeDownloadForUIN:(NSString *)uin task:(JMHTTPTask *)task data:(NSData *)data error:(NSError *)error;
@end
#import <ImageIO/ImageIO.h>
#import <math.h>

@interface JMAppDelegate (SmokeAccess)
- (void)toggleGroup:(NSString *)group;
- (void)toggleUnreadFilter:(id)sender;
- (void)restoreRecentMessages:(id)sender;
- (NSTimeInterval)systemIdleSeconds;
- (void)autoAwayTick:(id)sender;
- (void)workspaceDidWake:(NSNotification *)notification;
- (void)showDiagnostics:(id)sender;
- (void)copyDiagnostics:(id)sender;
- (NSDate *)startOfDay:(NSDate *)date;
- (NSDate *)dayAfter:(NSDate *)date;
- (void)jumpToHistoryDay:(id)sender;
- (void)showBookmarks:(id)sender;
- (void)toggleMessageBookmark:(NSMenuItem *)sender;
- (void)appearancePreferencesChanged:(id)sender;
- (void)restoreStandardPreferences;
- (void)showStorage:(id)sender;
- (void)closeStorage:(id)sender;
- (void)clearAvatarCache:(id)sender;
- (void)deleteHistoryPeer:(NSString *)peer from:(NSDate *)from until:(NSDate *)until backupURL:(NSURL *)url;
- (void)loadEarlierMessages:(id)sender;
- (void)loadNewerMessages:(id)sender;
- (void)setTranscriptAroundID:(NSString *)identifier;
- (void)renderTranscript;
- (void)toggleFavorite:(id)sender;
- (void)togglePinConversation:(id)sender;
- (void)showQuickChat:(id)sender;
- (void)toggleOnlineFilter:(id)sender;
- (void)toggleFavoritesFilter:(id)sender;
- (void)toggleEmoticons:(id)sender;
- (void)transmitRecord:(NSDictionary *)record clearsDraft:(BOOL)clearsDraft;
- (NSDictionary *)draftSnapshot;
- (void)scheduleAutomaticUpdateChecks;
- (void)toggleAutomaticUpdates:(id)sender;
- (void)automaticUpdateTick:(id)sender;
- (void)checkUpdatesAutomatically:(BOOL)automatic;
- (void)checkForUpdates:(id)sender;
- (void)closeUpdateWindow:(id)sender;
- (void)presentPendingUpdateIfPossible;
- (BOOL)canPresentAutomaticUpdate;
- (void)presentUpdateRelease:(NSDictionary *)release automatic:(BOOL)automatic;
- (void)selectPeer:(NSString *)peer;
- (void)about:(id)sender;
- (void)showKeyboardHelp:(id)sender;
- (void)openTelegraphica:(id)sender;
- (NSAlert *)newConversationPrompt;
- (NSAlert *)newAddContactPrompt;
- (void)changeSection:(id)sender;
- (void)addContactUIN:(NSString *)uin;
- (void)showProfile:(id)sender;
- (void)closeProfile:(id)sender;
- (void)changePresence:(id)sender;
- (void)updateTypingIndicator;
- (void)showMainWindow:(id)sender;
- (BOOL)openExternalURL:(NSURL *)url;
- (void)showHistorySearch:(id)sender;
- (void)searchHistory:(id)sender;
- (void)openHistoryResult:(id)sender;
- (void)closeHistorySearch:(id)sender;
- (void)showPreferences:(id)sender;
- (void)closePreferences:(id)sender;
- (void)fontSettingsChanged:(id)sender;
- (void)resetChatFont:(id)sender;
- (void)applyChatFont;
- (void)showGroups:(id)sender;
- (void)closeGroups:(id)sender;
- (void)groupFilterChanged:(id)sender;
- (void)groupManagerChanged:(id)sender;
- (void)renameContactUIN:(NSString *)peer name:(NSString *)name;
- (void)removeContactUIN:(NSString *)peer;
- (void)moveContactUIN:(NSString *)peer from:(NSString *)source to:(NSString *)destination;
- (void)createGroupNamed:(NSString *)name;
- (void)renameGroupNamed:(NSString *)name to:(NSString *)newName;
- (void)removeGroupNamed:(NSString *)name;
- (void)profileContact:(id)sender;
- (NSString *)contactForAction:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
- (void)showError:(NSString *)title detail:(NSString *)detail;
- (NSAlert *)removeContactPrompt:(NSString *)peer;
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (JMAudioAlerts *)makeAudioAlerts;
- (JMNotificationAlerts *)makeNotificationAlerts;
- (BOOL)isReadingConversation;
- (void)persistConversationPeers;
- (void)markAllRead:(id)sender;
- (void)markSelectedRead;
- (void)jumpToLatest:(id)sender;
- (void)changePreferenceSection:(id)sender;
- (void)alertPreferencesChanged:(id)sender;
- (void)testNotification:(id)sender;
- (void)toggleSounds:(id)sender;
- (void)logout:(id)sender;
- (void)showOwnProfile:(id)sender;
- (void)restoreDraftsForUIN:(NSString *)uin;
- (JMDraftStore *)makeDraftStoreForUIN:(NSString *)uin;
- (void)persistDraftsNow;
- (void)flushDrafts;
- (void)sendModeChanged:(id)sender;
- (void)send:(id)sender;
- (void)copyWholeMessage:(NSMenuItem *)item;
- (void)quoteMessage:(NSMenuItem *)item;
- (void)writeMessageToPasteboard:(NSString *)text;
- (BOOL)canLeaveDrafts;
- (JMLoginStore *)makeLoginStore;
- (NSUserDefaults *)makeLoginDefaults;
- (JMHistory *)makeHistoryForUIN:(NSString *)uin;
- (JMAccountData *)makeAccountDataForUIN:(NSString *)uin;
- (NSArray *)storedAccountUINs;
- (BOOL)openOfflineUIN:(NSString *)uin;
- (void)toggleMuteConversation:(id)sender;
- (void)changeAppearance:(id)sender;
- (void)restoreBackupURL:(NSURL *)url manifest:(NSDictionary *)manifest;
- (void)handleEscapeInWindow:(NSWindow *)window;
- (void)insertClassicSmiley:(NSMenuItem *)sender;
- (void)changeClassicFontSize:(NSMenuItem *)sender;
- (void)filterHistoricalGroup:(NSMenuItem *)sender;
- (BOOL)notificationAlerts:(JMNotificationAlerts *)alerts shouldNotifyPeer:(NSString *)peer;
- (JMAvatarStore *)makeAvatarStore;
- (void)startAutomaticLogin;
- (void)cancelLogin:(id)sender;
- (void)login:(id)sender;
- (void)rememberLoginChanged:(id)sender;
- (void)reloadContacts;
- (void)openConversation:(id)sender;
@end
@interface JMOwnProfileController (SmokeAccess)
- (void)loadProfile:(id)sender;
- (void)saveProfile:(id)sender;
- (void)stageAvatar:(NSData *)data;
- (void)revertAvatar:(id)sender;
- (void)edited;
@end
@interface UIUpdateChecker : JMUpdateChecker
@property(nonatomic,strong) NSDictionary *releaseInfo;
@property(nonatomic,strong) NSError *error;
@property(nonatomic) NSUInteger checks;
@property(nonatomic) BOOL holdResponse;
@property(nonatomic,copy) void (^pending)(NSDictionary *,NSError *);
- (void)finish;
@end
@implementation UIUpdateChecker
- (void)check:(void (^)(NSDictionary *,NSError *))completion {
    self.checks++;
    if (self.holdResponse) self.pending=completion;
    else completion(self.releaseInfo,self.error);
}
- (void)finish {
    void (^completion)(NSDictionary *,NSError *)=self.pending;
    self.pending=nil;
    if (completion) completion(self.releaseInfo,self.error);
}
@end
static NSUserDefaults *testAlertDefaults;
static NSURL *testDraftRoot;
@interface FakeLoginStore : JMLoginStore
@property(nonatomic, strong) NSMutableDictionary *records;
@property(nonatomic, strong) NSError *failure;
@property(nonatomic) NSUInteger saves;
@property(nonatomic) NSUInteger reads;
@property(nonatomic) NSUInteger removals;
@property(nonatomic, strong) NSError *readFailure;
@property(nonatomic, strong) dispatch_semaphore_t readGate;
@property(nonatomic, strong) dispatch_semaphore_t readStarted;
@end
@implementation FakeLoginStore
- (id)init { self=[super init]; if (self) self.records=[NSMutableDictionary dictionary]; return self; }
- (NSDictionary *)loginForUIN:(NSString *)uin error:(NSError **)error {
    self.reads++; if (self.readGate) { dispatch_semaphore_signal(self.readStarted); dispatch_semaphore_wait(self.readGate,DISPATCH_TIME_FOREVER); }
    NSError *failure=self.readFailure ?: self.failure; if (failure) { if (error) *error=failure; return nil; } return self.records[uin];
}
- (BOOL)saveToken:(NSString *)token expiresAt:(NSDate *)expiration forUIN:(NSString *)uin error:(NSError **)error {
    self.saves++; if (self.failure) { if (error) *error=self.failure; return NO; }
    self.records[uin]=@{@"token":token,@"expiresAt":expiration}; return YES;
}
- (BOOL)removeLoginForUIN:(NSString *)uin error:(NSError **)error { self.removals++; if (self.failure) { if (error) *error=self.failure; return NO; } [self.records removeObjectForKey:uin]; return YES; }
@end
@interface SmokeDelegate : JMAppDelegate
@property(nonatomic,strong) NSNumber *fixtureIdle;
@property(nonatomic) NSUInteger terminationReplies;
@property(nonatomic,strong) NSNumber *allowUpdatePresentation;
@property(nonatomic,copy) NSString *presentedUpdateVersion;
@property(nonatomic) NSUInteger automaticUpdateNotices;
@property(nonatomic, strong) NSURL *openedURL;
@property(nonatomic, copy) NSString *lastError;
@property(nonatomic, strong) NSNumber *forcedReading;
@property(nonatomic) NSUInteger showWindowCount;
@property(nonatomic, copy) NSString *copiedMessage;
@property(nonatomic) BOOL refuseDraftLoss;
@end
@interface JMAudioAlerts (TestPlayback)
- (BOOL)playSound:(NSSound *)sound;
@end
@interface SilentAudioAlerts : JMAudioAlerts
@property(nonatomic, strong) NSMutableArray *events;
@property(nonatomic) NSUInteger playCount;
@end
@implementation SilentAudioAlerts
- (id)init { self=[super initWithDefaults:testAlertDefaults]; if (self) self.events=[NSMutableArray array]; return self; }
- (BOOL)playSound:(NSSound *)sound { self.playCount++; return YES; } // Never play audio in automated tests.
- (BOOL)playEvent:(NSString *)event { [self.events addObject:event]; return [super playEvent:event]; }
@end
@interface JMNotificationAlerts (TestDelivery)
- (BOOL)postNotification:(NSUserNotification *)notification;
- (NSArray *)deliveredNotifications;
- (void)removeNotification:(NSUserNotification *)notification;
- (void)clearDeliveredNotifications;
- (void)flushPeer:(NSString *)peer;
- (BOOL)supportsNotificationIdentifiers;
@end
@interface FakeNotificationAlerts : JMNotificationAlerts
@property(nonatomic, strong) NSMutableArray *posted;
@property(nonatomic) BOOL legacyIdentifiers;
@end
@implementation FakeNotificationAlerts
- (BOOL)supportsNotificationIdentifiers { return !self.legacyIdentifiers && [super supportsNotificationIdentifiers]; }
- (id)initWithDefaults:(NSUserDefaults *)defaults center:(NSUserNotificationCenter *)center {
    self=[super initWithDefaults:defaults center:nil]; if (self) self.posted=[NSMutableArray array]; return self;
}
- (BOOL)postNotification:(NSUserNotification *)notification {
    for (NSUserNotification *old in [self.posted copy]) if (notification.identifier.length && [old.identifier isEqualToString:notification.identifier]) [self.posted removeObject:old];
    [self.posted addObject:notification]; return YES; // No real system banners in automated tests.
}
- (NSArray *)deliveredNotifications { return [self.posted copy]; }
- (void)removeNotification:(NSUserNotification *)notification {
    [self.posted removeObjectIdenticalTo:notification];
}
- (void)clearDeliveredNotifications { [self.posted removeAllObjects]; }
@end
@interface FixtureAvatarStore : JMAvatarStore
@property(nonatomic, strong) NSImage *fixtureImage;
@property(nonatomic) NSUInteger savedImages;
@end
@implementation FixtureAvatarStore
- (id)init { self=[super init]; [self invalidate]; NSURL *cache=[testDraftRoot URLByAppendingPathComponent:@"fixture-avatars"]; if (cache) { [self setValue:cache forKey:@"cacheDirectory"]; [[NSFileManager defaultManager] createDirectoryAtURL:cache withIntermediateDirectories:YES attributes:nil error:NULL]; } return self; }
- (NSImage *)imageForUIN:(NSString *)uin { return self.fixtureImage; }
- (void)refreshUIN:(NSString *)uin {}
- (void)storeUploadedAvatar:(NSData *)data forUIN:(NSString *)uin { self.fixtureImage=JMDecodeAvatar(data); self.savedImages++; }
@end
@implementation SmokeDelegate
- (NSTimeInterval)systemIdleSeconds { return self.fixtureIdle ? self.fixtureIdle.doubleValue : [super systemIdleSeconds]; }
- (void)completeTermination { self.terminationReplies++; }
- (void)scheduleAutomaticUpdateChecks {} // No real update requests during fictional UI tests.
- (BOOL)canPresentAutomaticUpdate { return self.allowUpdatePresentation ? self.allowUpdatePresentation.boolValue : [super canPresentAutomaticUpdate]; }
- (void)presentUpdateRelease:(NSDictionary *)release automatic:(BOOL)automatic { self.presentedUpdateVersion=release[@"version"]; if (automatic) self.automaticUpdateNotices++; else [super presentUpdateRelease:release automatic:NO]; }
- (BOOL)openExternalURL:(NSURL *)url { self.openedURL=url; return YES; }
- (void)showError:(NSString *)title detail:(NSString *)detail { self.lastError=detail; }
- (JMLoginStore *)makeLoginStore { return [[FakeLoginStore alloc] init]; }
- (NSUserDefaults *)makeLoginDefaults { return testAlertDefaults; }
- (JMHistory *)makeHistoryForUIN:(NSString *)uin { return [[JMHistory alloc] initWithUIN:uin root:testDraftRoot]; }
- (JMAccountData *)makeAccountDataForUIN:(NSString *)uin { return [[JMAccountData alloc] initWithUIN:uin root:testDraftRoot]; }
- (NSArray *)storedAccountUINs { return testDraftRoot ? JMStoredAccounts(testDraftRoot) : @[]; }
- (JMAvatarStore *)makeAvatarStore { return [[FixtureAvatarStore alloc] init]; }
- (JMAudioAlerts *)makeAudioAlerts { return [[SilentAudioAlerts alloc] init]; }
- (JMNotificationAlerts *)makeNotificationAlerts { return [[FakeNotificationAlerts alloc] initWithDefaults:testAlertDefaults center:nil]; }
- (void)persistConversationPeers {} // Fixture UINs never enter the user's account preferences.
- (JMDraftStore *)makeDraftStoreForUIN:(NSString *)uin { return [[JMDraftStore alloc] initWithUIN:uin root:testDraftRoot]; }
- (void)writeMessageToPasteboard:(NSString *)text { self.copiedMessage=text; } // Never replace user's clipboard in automated tests.
- (BOOL)canLeaveDrafts { return self.refuseDraftLoss ? NO : [super canLeaveDrafts]; }
- (BOOL)isReadingConversation {
    if (!self.forcedReading) return [super isReadingConversation];
    NSWindow *window=[self valueForKey:@"chatWindow"]; NSTextView *view=[self valueForKey:@"transcript"];
    return self.forcedReading.boolValue && ![[self valueForKey:@"renderingTranscript"] boolValue] && [[self valueForKey:@"transcriptOffset"] unsignedIntegerValue]+200>=[(JMHistory *)[self valueForKey:@"history"] countForPeer:[self valueForKey:@"selectedPeer"] ?: @""] && window.isVisible && !window.isMiniaturized && NSMaxY(view.enclosingScrollView.contentView.bounds)>=NSHeight(view.bounds)-24;
}
- (void)showMainWindow:(id)sender { self.showWindowCount++; [super showMainWindow:sender]; }
@end
@interface UIClient : JMAPIClient
@property(nonatomic,strong) NSArray *storedRows;
@property(nonatomic) BOOL holdPresence;
@property(nonatomic,copy) void (^pendingPresence)(NSDictionary *,NSError *);
@property(nonatomic) NSUInteger reconnects;
@property(nonatomic) BOOL fixtureConnected;
@property(nonatomic, copy) NSString *addedUIN;
@property(nonatomic, copy) NSString *chosenState;
@property(nonatomic, copy) NSString *lastTyping;
@property(nonatomic, strong) NSMutableArray *rosterCalls;
@property(nonatomic) BOOL rejectRoster;
@property(nonatomic) BOOL holdRoster;
@property(nonatomic, copy) void (^pendingRoster)(NSDictionary *,NSError *);
@property(nonatomic, copy) NSString *ownAbout;
@property(nonatomic, copy) NSString *ownCaption;
@property(nonatomic, strong) NSMutableDictionary *ownNames;
@property(nonatomic, strong) NSDictionary *lastNameFields;
@property(nonatomic, strong) NSMutableArray *ownCalls;
@property(nonatomic, copy) NSString *rejectOwnAction;
@property(nonatomic) BOOL rejectOwnRead;
@property(nonatomic) BOOL mismatchOwnRead;
@property(nonatomic) BOOL holdOwnAction;
@property(nonatomic, copy) void (^pendingOwn)(NSDictionary *,NSError *);
@property(nonatomic, copy) void (^pendingSend)(NSDictionary *,NSError *);
@property(nonatomic, copy) NSString *sentText;
@property(nonatomic) NSUInteger sendCount;
@property(nonatomic) NSUInteger passwordLogins;
@property(nonatomic) NSUInteger tokenLogins;
@property(nonatomic) BOOL requestedLongTerm;
@property(nonatomic, copy) NSString *loginUIN;
@end
@implementation UIClient
- (void)fetchStoredMessagesForPeer:(NSString *)peer completion:(void (^)(NSDictionary *,NSError *))completion { completion(@{@"msgs":self.storedRows ?: @[]},nil); }
- (void)reconnect { self.reconnects++; }
- (id)init { self=[super init]; if (self) { self.rosterCalls=[NSMutableArray array]; self.ownCalls=[NSMutableArray array]; self.ownNames=[@{@"firstName":@"Иван",@"lastName":@"Тестовый"} mutableCopy]; self.ownAbout=@"Люблю старые Mac и простые мессенджеры."; self.ownCaption=@"На связи со старого Mac"; } return self; }
- (void)rosterReply:(NSString *)action completion:(void (^)(NSDictionary *,NSError *))completion {
    [self.rosterCalls addObject:action];
    if (self.holdRoster) { self.pendingRoster=completion; return; }
    completion(self.rejectRoster ? nil : @{},self.rejectRoster ? [NSError errorWithDomain:JMAPIErrorDomain code:500 userInfo:@{NSLocalizedDescriptionKey:@"Fixture failure"}] : nil);
}
- (BOOL)connected { return self.fixtureConnected; }
- (NSString *)uin { return self.loginUIN ?: @"111"; }
- (void)loginWithUIN:(NSString *)uin password:(NSString *)password longTerm:(BOOL)longTerm { self.loginUIN=uin; self.passwordLogins++; self.requestedLongTerm=longTerm; }
- (void)resumeWithUIN:(NSString *)uin token:(NSString *)token { self.loginUIN=uin; self.tokenLogins++; }
- (void)addContactWithUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion { self.addedUIN=uin; completion(@{},nil); }
- (void)addContactWithUIN:(NSString *)uin group:(NSString *)group completion:(void (^)(NSDictionary *, NSError *))completion { self.addedUIN=uin; completion(@{},nil); }
- (void)renameContactWithUIN:(NSString *)uin name:(NSString *)name completion:(void (^)(NSDictionary *,NSError *))completion { [self rosterReply:@"alias" completion:completion]; }
- (void)removeContactWithUIN:(NSString *)uin completion:(void (^)(NSDictionary *,NSError *))completion { [self rosterReply:@"removeContact" completion:completion]; }
- (void)moveContactWithUIN:(NSString *)uin fromGroup:(NSString *)source toGroup:(NSString *)destination completion:(void (^)(NSDictionary *,NSError *))completion { [self rosterReply:@"move" completion:completion]; }
- (void)createGroup:(NSString *)name completion:(void (^)(NSDictionary *,NSError *))completion { [self rosterReply:@"createGroup" completion:completion]; }
- (void)renameGroup:(NSString *)name to:(NSString *)newName completion:(void (^)(NSDictionary *,NSError *))completion { [self rosterReply:@"renameGroup" completion:completion]; }
- (void)removeGroup:(NSString *)name completion:(void (^)(NSDictionary *,NSError *))completion { [self rosterReply:@"removeGroup" completion:completion]; }
- (void)fetchPresenceForUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion {
    completion(@{@"users":@[@{@"aimId":uin,@"friendly":[uin isEqualToString:@"222"] ? @"Тестовый контакт" : uin,@"state":@"online",@"statusMsg":[uin isEqualToString:@"111"] ? self.ownCaption : @"На связи со старого Mac"}]},nil);
}
- (void)fetchProfileForUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion {
    if ([uin isEqualToString:@"111"]) completion(self.rejectOwnRead ? nil : @{@"profile":self.mismatchOwnRead ? @"Другое значение сервера" : self.ownAbout},self.rejectOwnRead ? [NSError errorWithDomain:JMAPIErrorDomain code:500 userInfo:nil] : nil);
    else completion(@{@"profile":@"Тестовый профиль. Люблю старые Mac и простые мессенджеры."},nil);
}
- (void)ownAction:(NSString *)action completion:(void (^)(NSDictionary *,NSError *))completion {
    [self.ownCalls addObject:action];
    if (self.holdOwnAction) { self.pendingOwn=completion; return; }
    completion([self.rejectOwnAction isEqualToString:action] ? nil : @{@"id":@"fixture-avatar"},[self.rejectOwnAction isEqualToString:action] ? [NSError errorWithDomain:JMAPIErrorDomain code:500 userInfo:@{NSLocalizedDescriptionKey:@"Тестовый сбой загрузки"}] : nil);
}
- (void)setOwnProfileText:(NSString *)text completion:(void (^)(NSDictionary *,NSError *))completion {
    __weak UIClient *weakSelf=self; [self ownAction:@"about" completion:^(NSDictionary *d,NSError *e) { if (!e) weakSelf.ownAbout=text; completion(d,e); }];
}
- (void)setOwnStatusMessage:(NSString *)text completion:(void (^)(NSDictionary *,NSError *))completion {
    __weak UIClient *weakSelf=self; [self ownAction:@"caption" completion:^(NSDictionary *d,NSError *e) { if (!e) weakSelf.ownCaption=text; completion(d,e); }];
}
- (void)uploadOwnAvatar:(NSData *)jpeg completion:(void (^)(NSDictionary *,NSError *))completion { [self ownAction:@"avatar" completion:completion]; }
- (void)fetchOwnDirectoryProfile:(void (^)(NSDictionary *,NSError *))completion { completion([self.ownNames copy],nil); }
- (void)setOwnNameFields:(NSDictionary *)fields completion:(void (^)(NSDictionary *,NSError *))completion {
    self.lastNameFields=[fields copy]; __weak UIClient *weakSelf=self;
    [self ownAction:@"names" completion:^(NSDictionary *d,NSError *e) { if (!e) [weakSelf.ownNames addEntriesFromDictionary:fields]; completion(d,e); }];
}
- (void)setPresenceState:(NSString *)state completion:(void (^)(NSDictionary *, NSError *))completion { self.chosenState=state; if (self.holdPresence) { self.pendingPresence=completion; return; } completion(@{@"state":state,@"_presenceVerification":@"confirmed"},nil); }
- (void)setTypingStatus:(NSString *)status forUIN:(NSString *)uin { self.lastTyping=status; }
- (void)sendText:(NSString *)text to:(NSString *)peer completion:(void (^)(NSDictionary *,NSError *))completion {
    self.sentText=text; self.sendCount++; self.pendingSend=completion;
}
@end
static NSUInteger uiChecks=0;
static NSDictionary *Incoming(NSString *identifier, NSString *peer, NSString *text) {
    return @{@"id":identifier,@"peer":peer,@"name":@"Тестовый отправитель",@"text":text,@"timestamp":@1793346000,@"outgoing":@NO};
}
static void PumpUI(NSTimeInterval seconds) {
    NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow>0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}
static void CheckUI(BOOL condition, const char *message) {
    uiChecks++;
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
static CGFloat Contrast(NSColor *first, NSColor *second) {
    CGFloat values[2]; NSArray *colors=@[first,second];
    for (NSUInteger i=0;i<2;i++) {
        NSColor *rgb=[colors[i] colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; CGFloat channels[]={rgb.redComponent,rgb.greenComponent,rgb.blueComponent};
        for (NSUInteger c=0;c<3;c++) channels[c]=channels[c]<=0.04045 ? channels[c]/12.92 : pow((channels[c]+0.055)/1.055,2.4);
        values[i]=channels[0]*0.2126+channels[1]*0.7152+channels[2]*0.0722;
    }
    return (MAX(values[0],values[1])+0.05)/(MIN(values[0],values[1])+0.05);
}
static void TypeInWindow(NSWindow *window, NSString *characters) {
    // Deliver a key event inside this test application's own NSWindow.
    NSEvent *key = [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:0
        timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[window windowNumber]
        context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:0];
    [window sendEvent:key];
}
static void ReturnInWindow(NSWindow *window, NSUInteger flags) {
    // Process this fixture application's own activation events, as NSApplication.run
    // normally does. This makes key-window validation real, without faking OS state.
    [NSApp activateIgnoringOtherApps:YES]; [window makeKeyAndOrderFront:nil];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:0.15];
    while (deadline.timeIntervalSinceNow>0) {
        NSEvent *queued=[NSApp nextEventMatchingMask:NSAnyEventMask untilDate:deadline inMode:NSDefaultRunLoopMode dequeue:YES];
        if (queued) [NSApp sendEvent:queued];
    }
    [window makeKeyWindow];
    for (NSMenuItem *item in [[NSApp mainMenu] itemArray]) [item.submenu update];
    NSEvent *key=[NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:flags timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:window.windowNumber context:nil characters:@"\r" charactersIgnoringModifiers:@"\r" isARepeat:NO keyCode:36];
    [NSApp sendEvent:key];
}
static void KeyInWindow(NSWindow *window, NSString *key, NSUInteger flags, unsigned short code) {
    [NSApp activateIgnoringOtherApps:YES]; [window makeKeyAndOrderFront:nil];
    PumpUI(0.05); [window makeKeyWindow];
    for (NSMenuItem *item in [[NSApp mainMenu] itemArray]) [item.submenu update];
    NSEvent *event=[NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:flags timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil characters:([key isEqualToString:@"\t"] && (flags & NSShiftKeyMask)) ? @"\031" : key charactersIgnoringModifiers:([key isEqualToString:@"\t"] && (flags & NSShiftKeyMask)) ? @"\031" : key isARepeat:NO keyCode:code];
    [NSApp sendEvent:event]; PumpUI(0.05);
}
static NSArray *PreserveClipboard(void) {
    NSMutableArray *saved=[NSMutableArray array];
    for (NSPasteboardItem *item in NSPasteboard.generalPasteboard.pasteboardItems) {
        NSMutableDictionary *values=[NSMutableDictionary dictionary];
        for (NSString *type in item.types) { NSData *data=[item dataForType:type]; if (data) values[type]=data; }
        [saved addObject:values];
    }
    return saved;
}
static void RestoreClipboard(NSArray *saved) {
    NSMutableArray *items=[NSMutableArray array];
    for (NSDictionary *values in saved) {
        NSPasteboardItem *item=[[NSPasteboardItem alloc] init];
        for (NSString *type in values) [item setData:values[type] forType:type]; [items addObject:item];
    }
    [NSPasteboard.generalPasteboard clearContents]; [NSPasteboard.generalPasteboard writeObjects:items];
}
static void Draft(SmokeDelegate *delegate, NSTextView *composer, NSString *text) {
    composer.string=text; [composer setSelectedRange:NSMakeRange(text.length,0)];
    [delegate textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:composer]];
}
static void LoginQueue(SmokeDelegate *delegate) {
    dispatch_sync((dispatch_queue_t)[delegate valueForKey:@"loginStoreQueue"],^{}); PumpUI(0.15);
    dispatch_sync((dispatch_queue_t)[delegate valueForKey:@"loginStoreQueue"],^{}); PumpUI(0.05);
}
static void FinishSend(UIClient *client, NSString *identifier, NSError *error) {
    void (^completion)(NSDictionary *,NSError *)=client.pendingSend; client.pendingSend=nil;
    CheckUI(completion!=nil,"fixture has one pending send completion");
    completion(error ? nil : @{@"msgId":identifier,@"timestamp":@1793347000},error);
}
@interface PromptFixture : NSObject
@property(nonatomic, strong) NSAlert *alert;
@property(nonatomic, copy) NSString *snapshotPath;
- (void)edit:(NSTimer *)timer;
- (void)timeout:(NSTimer *)timer;
@end
@implementation PromptFixture
- (void)timeout:(NSTimer *)timer { if ([NSApp modalWindow]==self.alert.window) { fprintf(stderr,"FAIL: Escape did not close fixture modal within deadline\n"); exit(1); } }
- (void)edit:(NSTimer *)timer {
    NSView *accessory=self.alert.accessoryView;
    NSTextField *recipient=[accessory isKindOfClass:[NSTextField class]] ? (NSTextField *)accessory : (NSTextField *)[accessory viewWithTag:101];
    NSWindow *window = [self.alert window];
    CheckUI([recipient isEditable] && [recipient isEnabled] && [window makeFirstResponder:recipient], "UIN prompt accepts keyboard focus");
    TypeInWindow(window, @"11114");
    CheckUI([[[recipient currentEditor] string] isEqualToString:@"11114"], "key event inserts UIN into modal field editor");
    [window makeFirstResponder:nil];
    CheckUI([[recipient stringValue] isEqualToString:@"11114"], "UIN edit commits before opening conversation");
    if (self.snapshotPath) {
        NSView *content=window.contentView; NSView *view=content.superview ?: content;
        NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
        [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap]; [[bitmap representationUsingType:NSPNGFileType properties:@{}] writeToFile:self.snapshotPath atomically:YES];
    }
    NSTimer *watchdog=[NSTimer timerWithTimeInterval:5 target:self selector:@selector(timeout:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:watchdog forMode:NSModalPanelRunLoopMode];
    NSArray *clipboard=PreserveClipboard();
    @try {
        [window makeFirstResponder:recipient];
        KeyInWindow(window,@"a",NSCommandKeyMask,0); KeyInWindow(window,@"c",NSCommandKeyMask,8); KeyInWindow(window,@"x",NSCommandKeyMask,7);
        CheckUI([[recipient currentEditor] string].length==0,"Cmd+X edits UIN in application-modal alert");
        KeyInWindow(window,@"v",NSCommandKeyMask,9);
        CheckUI([[[recipient currentEditor] string] isEqualToString:@"11114"],"Cmd+V restores UIN in application-modal alert");
        KeyInWindow(window,@"\e",0,53);
    } @finally { RestoreClipboard(clipboard); }
}
@end
static void Capture(NSWindow *window, NSString *path) {
    [window makeKeyAndOrderFront:nil]; [window display];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
    NSView *view = [window contentView];
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:[view bounds]];
    [view cacheDisplayInRect:[view bounds] toBitmapImageRep:bitmap];
    NSData *png = [bitmap representationUsingType:NSPNGFileType properties:@{}];
    if (![png writeToFile:path atomically:YES]) { fprintf(stderr, "Cannot write UI snapshot\n"); exit(1); }
}
#include "ImprovementUI.inc"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *output = [NSString stringWithUTF8String:argv[1]];
        NSApplication *app = [JMApplication sharedApplication]; [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSString *suite=[@"online.jimm.tests." stringByAppendingString:[[NSUUID UUID] UUIDString]];
        NSUserDefaults *fontDefaults=[[NSUserDefaults alloc] initWithSuiteName:suite]; testAlertDefaults=fontDefaults;
        SmokeDelegate *delegate = [[SmokeDelegate alloc] init]; [app setDelegate:delegate];
        [delegate applicationDidFinishLaunching:nil];
        delegate.forcedReading=@YES;
        JMChatPreferences *fontPreferences=[[JMChatPreferences alloc] initWithDefaults:fontDefaults];
        [delegate setValue:fontPreferences forKey:@"chatPreferences"]; [delegate applyChatFont];
        SilentAudioAlerts *audio=[[SilentAudioAlerts alloc] init]; audio.enabled=YES; audio.presenceEnabled=YES;
        [delegate setValue:audio forKey:@"audioAlerts"];
        NSWindow *login = [delegate valueForKey:@"loginWindow"];
        NSTextField *uin = [delegate valueForKey:@"uinField"]; [uin setStringValue:@""];
        Capture(login, [output stringByAppendingPathComponent:@"UI-login.png"]);
        [login orderOut:nil];
        Capture([delegate valueForKey:@"chatWindow"],[output stringByAppendingPathComponent:@"UI-empty.png"]);
        JMConversationEmptyView *emptyView=[delegate valueForKey:@"conversationEmptyView"];
        CheckUI(!emptyView.hidden && emptyView.writeButton.action==@selector(openConversation:) && [[delegate valueForKey:@"transcript"] string].length==0,"empty conversation offers a native action without adding fake messages to transcript");
        BOOL emptyFits=YES; for (NSView *view in emptyView.subviews) if (!NSContainsRect(emptyView.bounds,view.frame)) emptyFits=NO;
        CheckUI(emptyFits,"empty conversation illustration, text and action fit inside history area");
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
        testDraftRoot=root;
        [delegate setValue:[[JMHistory alloc] initWithUIN:@"111" root:root] forKey:@"history"];
        UIClient *client = [[UIClient alloc] init]; [delegate setValue:client forKey:@"client"];
        NSTextView *composer = [delegate valueForKey:@"composer"];
        NSButton *send = [delegate valueForKey:@"sendButton"];
        CheckUI(![composer isEditable] && ![send isEnabled], "no recipient blocks sending and shows guidance");
        [delegate client:client receivedBuddyList:@{@"groups":@[@{@"name":@"Тестовые контакты", @"buddies":@[
            @{@"aimId":@"222", @"friendly":@"Тестовый контакт", @"state":@"online"},
            @{@"aimId":@"333", @"friendly":@"Второй контакт", @"state":@"away"}]}]}];
        CheckUI([[delegate valueForKey:@"serverContactIDs"] count] == 2 && [[delegate valueForKey:@"conversationPeers"] count] == 0, "contacts do not automatically create conversations");
        [delegate client:client receivedMessage:@{@"id":@"ui-unknown", @"peer":@"555", @"name":@"Незнакомый UIN", @"text":@"Привет! Меня пока нет в контактах.", @"timestamp":@1793343550, @"outgoing":@NO}];
        CheckUI(![[delegate valueForKey:@"serverContactIDs"] containsObject:@"555"] && [[delegate valueForKey:@"conversationPeers"] containsObject:@"555"], "incoming stranger appears only in conversations");
        [delegate client:client receivedMessage:@{@"id":@"ui-1", @"peer":@"222", @"name":@"Тестовый контакт", @"text":@"Привет! Это проверка интерфейса на Mavericks.", @"timestamp":@1793343600, @"outgoing":@NO}];
        [delegate client:client receivedMessage:@{@"id":@"ui-2", @"peer":@"222", @"name":@"", @"text":@"Русский текст, +, &, перенос строки:\nвсё отображается как обычный текст.", @"timestamp":@1793343660, @"outgoing":@YES}];
        [delegate client:client receivedMessage:@{@"id":@"ui-links",@"peer":@"222",@"name":@"",@"text":@"Ссылка https://jimm.online/developers и test@example.com. Тест поиска — Mavericks.",@"timestamp":@1793343800,@"outgoing":@NO}];
        [delegate selectPeer:@"222"];
        NSSegmentedControl *sections = [delegate valueForKey:@"sectionControl"];
        CheckUI([[delegate valueForKey:@"visibleContacts"] count] == 2, "contacts tab lists server contacts only");
        NSWindow *chat = [delegate valueForKey:@"chatWindow"];
        CheckUI(NSContainsRect([[sections superview] bounds],sections.frame) && NSHeight(sections.frame)>=[sections.cell cellSize].height && NSWidth(sections.frame)>=[sections.cell cellSize].width, "native tab bezel fits without clipping");
        CheckUI([[sections.cell toolTipForSegment:0] length]>0 && [[sections.cell toolTipForSegment:1] length]>0, "each tab has a system tooltip");
        client.fixtureConnected = YES;
        [delegate client:client receivedOwnInfo:@{@"friendly":@"Тестовый пользователь",@"state":@"online"}];
        [delegate client:client changedStatus:@"В сети · тестовые данные" connected:YES];
        if (getenv("JIMMMAC_IMPROVEMENTS_ONLY")) {
            [delegate setValue:@"111" forKey:@"accountUIN"]; [delegate setValue:[[FixtureAvatarStore alloc] init] forKey:@"avatars"];
            ImprovementUI(delegate,output); RetroUpgradeUI(delegate,output); ConversationNavigationUI(delegate,output);
            [[NSFileManager defaultManager] removeItemAtURL:root error:NULL]; printf("PASS: %lu focused improvement UI checks\n",(unsigned long)uiChecks); return 0;
        }
        {
            NSTextField *account=[delegate valueForKey:@"accountLabel"], *connection=[delegate valueForKey:@"statusLabel"];
            NSString *identity=[account.stringValue copy];
            CheckUI([identity rangeOfString:@"UIN"].location!=NSNotFound && ![identity isEqualToString:connection.stringValue],"account header and network footer show separate information");
            [delegate client:client changedStatus:@"Нет соединения. Повтор через 2 с…" connected:NO];
            CheckUI([account.stringValue isEqualToString:identity] && [connection.stringValue hasPrefix:@"Нет соединения"],"reconnection keeps account identity in header and network reason only in footer");
            NSDictionary *own=[[delegate valueForKey:@"ownInfo"] copy]; [[delegate valueForKey:@"ownInfo"] removeAllObjects];
            [delegate client:client changedStatus:@"Подключено" connected:YES];
            CheckUI([account.stringValue hasPrefix:@"UIN "] && [connection.stringValue isEqualToString:@"Подключено"],"missing profile name shows UIN in header without repeating connection status");
            [[delegate valueForKey:@"ownInfo"] addEntriesFromDictionary:own]; [delegate client:client changedStatus:@"Подключено" connected:YES];
        }
        Capture(chat, [output stringByAppendingPathComponent:@"UI-contacts.png"]);
        [sections setSelectedSegment:1]; [delegate changeSection:nil];
        CheckUI([[delegate valueForKey:@"visibleContacts"] count] == 2, "conversations tab lists message peers only");
        Capture(chat, [output stringByAppendingPathComponent:@"UI-chat.png"]);
        NSTextView *linkedTranscript=[delegate valueForKey:@"transcript"];
        NSRange webRange=[linkedTranscript.string rangeOfString:@"https://jimm.online/developers"];
        NSURL *webLink=[linkedTranscript.textStorage attribute:NSLinkAttributeName atIndex:webRange.location effectiveRange:NULL];
        CheckUI([webLink.host isEqualToString:@"jimm.online"] && [linkedTranscript.textStorage attribute:NSToolTipAttributeName atIndex:webRange.location effectiveRange:NULL]!=nil,"message web address has native link and URL tooltip attributes");
        [linkedTranscript clickedOnLink:webLink atIndex:webRange.location];
        CheckUI([delegate.openedURL isEqual:webLink],"native NSTextView link action reaches default-browser opener");
        delegate.openedURL=nil; [delegate textView:linkedTranscript clickedOnLink:@"file:///tmp/test" atIndex:0];
        CheckUI(delegate.openedURL==nil,"unapproved link schemes never reach workspace opener");
        [[delegate valueForKey:@"historySearchButton"] performClick:nil];
        NSWindow *historyWindow=[delegate valueForKey:@"historyWindow"];
        CheckUI(historyWindow.isVisible,"chat search button opens native history window");
        NSSearchField *historyQuery=[delegate valueForKey:@"historySearchField"]; NSPopUpButton *scope=[delegate valueForKey:@"historyScopePopup"];
        historyQuery.stringValue=@"привет"; [delegate controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:historyQuery]]; PumpUI(0.55);
        CheckUI([[delegate valueForKey:@"historyResults"] count]==2,"history window searches all conversations in current account");
        Capture(historyWindow,[output stringByAppendingPathComponent:@"UI-history-search.png"]);
        [historyWindow setContentSize:historyWindow.contentMinSize]; Capture(historyWindow,[output stringByAppendingPathComponent:@"UI-history-search-small.png"]);
        CheckUI(NSMaxX(historyQuery.frame)+8<=NSMinX(scope.frame),"history query and scope remain separate at minimum size");
        [scope selectItemAtIndex:1]; [delegate searchHistory:nil]; PumpUI(0.55);
        CheckUI([[delegate valueForKey:@"historyResults"] count]==1,"current-conversation history scope filters results");
        [delegate openHistoryResult:nil];
        NSRange selected=linkedTranscript.selectedRange;
        CheckUI(!historyWindow.isVisible && selected.length>0 && [[[linkedTranscript.string substringWithRange:selected] lowercaseString] isEqualToString:@"привет"],"opening result selects matching text in full conversation");
        CheckUI([linkedTranscript.textStorage attribute:NSBackgroundColorAttributeName atIndex:selected.location effectiveRange:NULL]!=nil,"search result has a persistent highlight");
        [delegate showHistorySearch:nil]; [scope selectItemAtIndex:0]; historyQuery.stringValue=@"привет"; [delegate searchHistory:nil]; PumpUI(0.55);
        NSTableView *historyTable=[delegate valueForKey:@"historyTable"]; [historyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
        [delegate openHistoryResult:nil];
        CheckUI([[delegate valueForKey:@"selectedPeer"] isEqualToString:@"555"] && ![[delegate valueForKey:@"serverContactIDs"] containsObject:@"555"] && [[linkedTranscript.string substringWithRange:linkedTranscript.selectedRange] isEqualToString:@"Привет"],"search opens a different conversation without adding a server contact");
        [delegate selectPeer:@"222"];
        [delegate showHistorySearch:nil]; historyQuery.stringValue=@"привет"; [delegate searchHistory:nil];
        historyQuery.stringValue=@"нет-такого-совпадения"; [delegate searchHistory:nil]; PumpUI(0.55);
        CheckUI([[delegate valueForKey:@"historyResults"] count]==0 && ![[delegate valueForKey:@"historyOpenButton"] isEnabled],"new query invalidates stale asynchronous search results");
        [delegate closeHistorySearch:nil];
        [fontPreferences setFamily:@"Menlo" size:18]; [fontDefaults synchronize];
        JMChatPreferences *reloaded=[[JMChatPreferences alloc] initWithDefaults:[[NSUserDefaults alloc] initWithSuiteName:suite]];
        CheckUI([reloaded.family isEqualToString:@"Menlo"] && reloaded.size==18,"font family and size persist in an isolated preferences domain");
        [delegate applyChatFont];
        NSRange linkedFontRange=[linkedTranscript.string rangeOfString:@"https://jimm.online/developers"];
        NSFont *bodyFont=[linkedTranscript.textStorage attribute:NSFontAttributeName atIndex:linkedFontRange.location effectiveRange:NULL];
        CheckUI(composer.font.pointSize==18 && bodyFont.pointSize==18,"font applies immediately to composer and stored messages");
        CheckUI([linkedTranscript.textStorage attribute:NSLinkAttributeName atIndex:linkedFontRange.location effectiveRange:NULL]!=nil,"changing font preserves clickable link attributes");
        [delegate showPreferences:nil]; NSPopUpButton *fontSize=[delegate valueForKey:@"fontSizePopup"];
        [fontSize selectItemWithTitle:@"28"]; [delegate fontSettingsChanged:nil];
        CheckUI(composer.font.pointSize==28 && [[delegate valueForKey:@"fontPreview"] font].pointSize==28,"settings control applies largest supported font and preview");
        CheckUI([(NSFont *)[[[delegate valueForKey:@"transcript"] textStorage] attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] pointSize]>=20,"history date separators scale with large message font");
        Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:@"UI-font-settings.png"]);
        [delegate closePreferences:nil]; [chat setContentSize:NSMakeSize(860,560)]; Capture(chat,[output stringByAppendingPathComponent:@"UI-font-chat.png"]);
        CheckUI(!NSIntersectsRect([[delegate valueForKey:@"peerLabel"] frame],[[delegate valueForKey:@"historySearchButton"] frame]),"search action does not overlap title at minimum width");
        [delegate resetChatFont:nil]; CheckUI(composer.font.pointSize==13 && fontPreferences.family.length==0,"reset restores standard Mavericks chat font");
        [fontPreferences setFamily:@"Font-That-Does-Not-Exist" size:NAN];
        CheckUI(fontPreferences.size==13 && fontPreferences.family.length==0,"unavailable family and invalid size fall back to readable defaults");
        [chat setContentSize:NSMakeSize(1000,650)]; [delegate selectPeer:@"222"];
        [delegate showProfile:nil];
        NSWindow *card=[delegate valueForKey:@"profileWindow"];
        CheckUI([[[delegate valueForKey:@"profileAbout"] string] rangeOfString:@"Тестовый профиль"].location!=NSNotFound, "profile card resolves about text asynchronously");
        Capture(card,[output stringByAppendingPathComponent:@"UI-profile.png"]); [delegate closeProfile:nil];
        NSTextView *about=[delegate valueForKey:@"profileAbout"];
        [about setString:[@"Многострочные сведения из профиля собеседника.\n" stringByPaddingToLength:4000 withString:@"Полный текст доступен при прокрутке.\n" startingAtIndex:0]];
        [about scrollRangeToVisible:NSMakeRange(about.string.length,0)];
        CheckUI(NSHeight(about.bounds)>NSHeight(about.enclosingScrollView.contentView.bounds),"long profile text scrolls instead of clipping");
        [delegate client:client receivedTyping:@{@"aimId":@"222",@"typingStatus":@"typing"}];
        CheckUI([[[delegate valueForKey:@"typingLabel"] stringValue] rangeOfString:@"печатает"].location!=NSNotFound, "incoming typing shown for selected conversation");
        [delegate client:client receivedTyping:@{@"aimId":@"222",@"typingStatus":@"none"}];
        CheckUI([[[delegate valueForKey:@"typingLabel"] stringValue] length]==0, "typing clears on none event");
        [[delegate valueForKey:@"incomingTyping"] setObject:[NSDate dateWithTimeIntervalSinceNow:-1] forKey:@"222"]; [delegate updateTypingIndicator];
        CheckUI([[[delegate valueForKey:@"typingLabel"] stringValue] length]==0, "stale typing expires");
        NSPopUpButton *statePopup=[delegate valueForKey:@"presencePopup"]; [statePopup selectItemAtIndex:1]; [delegate changePresence:nil];
        CheckUI([client.chosenState isEqualToString:@"away"] && [[[[delegate valueForKey:@"presencePopup"] selectedItem] representedObject] isEqualToString:@"away"], "presence picker persists acknowledged state");
        CheckUI([[[delegate valueForKey:@"presenceFeedback"] stringValue] isEqualToString:@"Статус подтверждён сервером"], "status confirmation is visible to user");
        [chat setContentSize:NSMakeSize(860, 560)];
        Capture(chat, [output stringByAppendingPathComponent:@"UI-chat-small.png"]);
        NSButton *addPeer=[delegate valueForKey:@"addPeerButton"], *profileButton=[delegate valueForKey:@"profileButton"];
        [delegate selectPeer:@"555"]; Capture(chat, [output stringByAppendingPathComponent:@"UI-stranger.png"]); [delegate selectPeer:@"222"];
        CheckUI(!NSIntersectsRect(addPeer.frame,profileButton.frame), "profile and add-contact actions have separate rows");
        NSString *longName=@"Очень длинное имя собеседника, которое должно корректно сокращаться многоточием";
        NSMutableDictionary *longContact=[[delegate valueForKey:@"contacts"] objectForKey:@"555"];
        longContact[@"friendly"]=longName;
        [delegate selectPeer:@"555"];
        // The fixture presence refresh can replace the name; set it after selection.
        [[[delegate valueForKey:@"contacts"] objectForKey:@"555"] setObject:longName forKey:@"friendly"];
        [delegate client:client receivedPresence:@{@"aimId":@"555",@"friendly":longName}];
        [delegate client:client receivedOwnInfo:@{@"friendly":longName,@"state":@"away"}];
        NSTextField *peerName=[delegate valueForKey:@"peerLabel"], *peerDetail=[delegate valueForKey:@"peerDetail"];
        CheckUI(!NSIntersectsRect(peerName.frame,profileButton.frame) && !NSIntersectsRect(peerDetail.frame,addPeer.frame), "long header labels cannot overlap actions at minimum width");
        CheckUI([peerName.toolTip isEqualToString:longName] && [peerName.cell lineBreakMode]==NSLineBreakByTruncatingTail, "long names use an ellipsis and expose full name in tooltip");
        Capture(chat,[output stringByAppendingPathComponent:@"UI-long-names.png"]);
        [chat setContentSize:NSMakeSize(1280,780)]; Capture(chat,[output stringByAppendingPathComponent:@"UI-chat-large.png"]);
        [chat setContentSize:NSMakeSize(860,560)]; [delegate selectPeer:@"222"];
        client.fixtureConnected = NO; [delegate client:client changedStatus:@"Проверка переподключения" connected:NO];
        if ([send isEnabled] || NSWidth([composer bounds]) < 200) { fprintf(stderr, "UI smoke failed\n"); return 1; }
        CheckUI([composer isEditable], "selected conversation allows drafting while disconnected");
        CheckUI([chat makeFirstResponder:composer], "composer accepts keyboard focus");
        TypeInWindow(chat, @"Черновик + &");
        CheckUI([[composer string] isEqualToString:@"Черновик + &"], "key event inserts text in offline composer");
        CheckUI(![send isEnabled], "draft cannot be sent without connection");
        Capture(chat,[output stringByAppendingPathComponent:@"UI-offline.png"]);
        NSString *shortDraft=[composer.string copy];
        [composer setString:[@"Длинный черновик.\n" stringByPaddingToLength:2000 withString:@"Следующая строка не обрезается.\n" startingAtIndex:0]];
        [composer scrollRangeToVisible:NSMakeRange(composer.string.length,0)];
        CheckUI(NSHeight(composer.bounds)>NSHeight(composer.enclosingScrollView.contentView.bounds),"multiline composer grows and scrolls to final line");
        [composer setString:shortDraft];
        client.fixtureConnected = YES;
        [delegate client:client changedStatus:@"Тестовое соединение" connected:YES];
        CheckUI([composer isEditable] && [send isEnabled], "online recipient and draft enable sending");
        TypeInWindow(chat, @" готов");
        CheckUI([[composer string] isEqualToString:@"Черновик + & готов"], "key event inserts text in online composer");
        client.fixtureConnected = NO;
        [delegate client:client changedStatus:@"Тестовый обрыв" connected:NO];
        CheckUI([composer isEditable] && ![send isEnabled] && [[composer string] length] > 0, "reconnect keeps draft editable and disables only sending");
        [delegate selectPeer:@"333"]; [delegate selectPeer:@"222"];
        CheckUI([[composer string] isEqualToString:@"Черновик + & готов"], "switching conversations preserves draft");
        client.fixtureConnected = YES;
        [delegate client:client changedStatus:@"Тестовое соединение" connected:YES];
        [delegate addContactUIN:@"444"];
        CheckUI([client.addedUIN isEqualToString:@"444"] && [[delegate valueForKey:@"serverContactIDs"] containsObject:@"444"], "Add contact invokes API and updates contacts section");
        CheckUI(![[delegate valueForKey:@"conversationPeers"] containsObject:@"444"], "adding contact does not open an empty conversation");
        NSUInteger soundEvents=audio.events.count;
        NSDictionary *fresh=@{@"id":@"auto-new",@"peer":@"222",@"text":@"Автоматически полученное сообщение",@"timestamp":@1793344000,@"outgoing":@NO};
        [delegate client:client receivedMessage:fresh];
        CheckUI([[[delegate valueForKey:@"transcript"] string] rangeOfString:@"Автоматически полученное сообщение"].location!=NSNotFound && audio.events.count==soundEvents+1, "incoming message updates visible transcript and requests sound automatically");
        [delegate client:client receivedMessage:fresh];
        CheckUI(audio.events.count==soundEvents+1, "duplicate delivery does not replay message sound");
        for (NSUInteger i=0;i<35;i++) [delegate client:client receivedMessage:@{@"id":[NSString stringWithFormat:@"scroll-%lu",(unsigned long)i],@"peer":@"222",@"text":@"Тестовая длинная история для проверки сохранения позиции прокрутки.\nВторая строка сообщения.",@"timestamp":@(1793344001+i),@"outgoing":@YES}];
        NSTextView *transcript=[delegate valueForKey:@"transcript"];
        NSClipView *clip=transcript.enclosingScrollView.contentView;
        CheckUI(NSMaxY(clip.bounds)>=NSHeight(transcript.bounds)-24,"new messages automatically follow the end when reading latest messages");
        [clip scrollToPoint:NSZeroPoint];
        [delegate client:client receivedMessage:@{@"id":@"scroll-arrival",@"peer":@"222",@"text":@"Новое сообщение во время чтения истории",@"timestamp":@1793344100,@"outgoing":@NO}];
        CheckUI(NSMinY(clip.bounds)<2 && [transcript.string rangeOfString:@"Новое сообщение во время чтения истории"].location!=NSNotFound, "automatic updates preserve position while reading older messages");
        NSMenu *windowMenu=[[[NSApp mainMenu] itemWithTitle:@"Окно"] submenu];
        NSMenuItem *closeItem=[windowMenu itemWithTitle:@"Закрыть окно"];
        CheckUI([closeItem.keyEquivalent isEqualToString:@"w"] && closeItem.action==@selector(performClose:),"Cmd+W is wired to the native window close action");
        // This executable does not enter NSApplication.run, so it has no active
        // responder chain. Exercise NSWindow's real close action directly.
        [chat performClose:nil];
        CheckUI(!chat.isVisible && client.connected && ![delegate applicationShouldTerminateAfterLastWindowClosed:app], "closing chat keeps the application connected in background");
        NSInteger unreadBefore=[[[delegate valueForKey:@"unread"] objectForKey:@"222"] integerValue];
        [delegate client:client receivedMessage:@{@"id":@"hidden-arrival",@"peer":@"222",@"text":@"Сообщение при закрытом окне",@"timestamp":@1793344200,@"outgoing":@NO}];
        CheckUI([[[delegate valueForKey:@"unread"] objectForKey:@"222"] integerValue]==unreadBefore+1 && [[[NSApp dockTile] badgeLabel] length]>0, "background incoming messages increment unread and Dock badge");
        [delegate showMainWindow:nil]; CheckUI(chat.isVisible,"Dock/menu action reopens chat without login");
        [delegate setValue:[NSDate dateWithTimeIntervalSinceNow:-5] forKey:@"connectedSince"];
        soundEvents=audio.events.count;
        [delegate client:client receivedPresence:@{@"aimId":@"333",@"state":@"offline"}];
        [delegate client:client receivedPresence:@{@"aimId":@"333",@"state":@"offline"}];
        CheckUI(audio.events.count==soundEvents+1 && [[audio.events lastObject] isEqualToString:@"offline"], "contact leaving online sounds once for a real state transition");
        NSAlert *addPrompt = [delegate newAddContactPrompt];
        CheckUI([[addPrompt messageText] isEqualToString:@"Добавить контакт"], "contact and conversation prompts are distinct");
        [delegate client:client receivedBuddyList:@{@"groups":@[@{@"name":@"Friends",@"buddies":@[@{@"aimId":@"333",@"friendly":@"Второй контакт"}]}]}];
        CheckUI(![[delegate valueForKey:@"serverContactIDs"] containsObject:@"222"] && [[delegate valueForKey:@"conversationPeers"] containsObject:@"222"], "server contact removal preserves existing conversation");
        {
            [delegate client:client receivedBuddyList:@{@"groups":@[
                @{@"name":@"Друзья",@"buddies":@[@{@"aimId":@"222",@"friendly":@"Тестовый контакт",@"state":@"online"},@{@"aimId":@"333",@"friendly":@"Второй контакт",@"state":@"away"},@{@"aimId":@"777",@"friendly":@"Новый контакт",@"state":@"offline"}]},
                @{@"name":@"Работа",@"buddies":@[@{@"aimId":@"222",@"friendly":@"Тестовый контакт",@"state":@"online"}]},
                @{@"name":@"Пустая",@"buddies":@[]}]}];
            CheckUI([[delegate valueForKey:@"serverGroups"] count]==3 && [[[[delegate valueForKey:@"contacts"] objectForKey:@"222"] objectForKey:@"groups"] count]==2,"server roster includes empty groups and multiple memberships");
            [delegate selectPeer:@"222"]; [sections setSelectedSegment:0]; [delegate changeSection:nil];
            NSPopUpButton *filter=[delegate valueForKey:@"groupFilter"]; [filter selectItemWithTitle:@"Работа"]; [delegate groupFilterChanged:filter];
            CheckUI([[delegate valueForKey:@"visibleContacts"] count]==1 && !filter.isHidden,"group filter limits contacts without hiding the selected conversation");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-group-filter.png"]);
            NSRect filterFrame=filter.frame, listFrame=[[[delegate valueForKey:@"contactTable"] enclosingScrollView] frame];
            CheckUI(NSMaxY(listFrame)+6<=NSMinY(filterFrame),"group filter has space above contact list at minimum height");
            [sections setSelectedSegment:1]; [delegate changeSection:nil]; CheckUI(filter.isHidden && [[delegate valueForKey:@"visibleContacts"] count]>=2,"conversation list ignores contact group filter");
            [sections setSelectedSegment:0]; [delegate changeSection:nil];
            [delegate renameContactUIN:@"222" name:@"Мой друг на Mavericks"];
            [delegate client:client receivedPresence:@{@"aimId":@"222",@"friendly":@"Public name",@"state":@"online"}];
            CheckUI([[[delegate valueForKey:@"peerLabel"] stringValue] isEqualToString:@"Мой друг на Mavericks"],"personal contact alias survives public presence updates");
            [delegate showGroups:nil]; NSWindow *groupsWindow=[delegate valueForKey:@"groupsWindow"];
            [delegate createGroupNamed:@"Коллеги & друзья"];
            CheckUI([[delegate valueForKey:@"serverGroups"] containsObject:@"Коллеги & друзья"],"successful group creation updates choices");
            [delegate moveContactUIN:@"222" from:@"Друзья" to:@"Коллеги & друзья"];
            NSArray *memberships=[[[delegate valueForKey:@"contacts"] objectForKey:@"222"] objectForKey:@"groups"];
            CheckUI([memberships containsObject:@"Работа"] && [memberships containsObject:@"Коллеги & друзья"] && ![memberships containsObject:@"Друзья"],"moving contact changes source membership and preserves other groups");
            [delegate renameGroupNamed:@"Работа" to:@"Рабочие контакты"];
            CheckUI([[delegate valueForKey:@"selectedGroup"] isEqualToString:@"Рабочие контакты"] && [[delegate valueForKey:@"visibleContacts"] count]==1,"renaming a group preserves active filter and memberships");
            NSPopUpButton *groupChoice=[delegate valueForKey:@"groupManagerPopup"]; [groupChoice selectItemWithTitle:@"Рабочие контакты"]; [delegate groupManagerChanged:nil];
            CheckUI(![[delegate valueForKey:@"removeGroupButton"] isEnabled],"nonempty group deletion is disabled");
            NSUInteger calls=client.rosterCalls.count; [delegate removeGroupNamed:@"Рабочие контакты"];
            CheckUI(client.rosterCalls.count==calls,"nonempty group cannot reach delete API even via direct action");
            Capture(groupsWindow,[output stringByAppendingPathComponent:@"UI-groups.png"]);
            [groupChoice selectItemWithTitle:@"Пустая"]; [delegate groupManagerChanged:nil];
            CheckUI([[delegate valueForKey:@"removeGroupButton"] isEnabled],"empty group can be removed");
            Capture(groupsWindow,[output stringByAppendingPathComponent:@"UI-groups-empty.png"]);
            [delegate removeGroupNamed:@"Пустая"]; CheckUI(![[delegate valueForKey:@"serverGroups"] containsObject:@"Пустая"],"successful empty-group removal updates group list");
            NSMenuItem *context=[[NSMenuItem alloc] initWithTitle:@"Rename" action:NSSelectorFromString(@"renameContact:") keyEquivalent:@""]; context.representedObject=@"333";
            CheckUI([[delegate contactForAction:context] isEqualToString:@"333"],"context action targets clicked UIN rather than open conversation");
            context.representedObject=[NSNull null]; CheckUI(![delegate validateMenuItem:context],"context actions on empty space cannot target old selection");
            NSMenu *contactMenu=[delegate valueForKey:@"contactMenu"]; [delegate menuNeedsUpdate:contactMenu];
            CheckUI([contactMenu.itemArray[0] representedObject]==[NSNull null],"empty-space menu update does not fall back to previously selected contact");
            context.representedObject=@"777"; [delegate profileContact:context];
            CheckUI(![[delegate valueForKey:@"conversationPeers"] containsObject:@"777"] && [[delegate valueForKey:@"profilePeer"] isEqualToString:@"777"],"context profile lookup does not create conversation"); [delegate closeProfile:nil];
            NSUInteger savedMessages=[[[delegate valueForKey:@"history"] messagesForPeer:@"222"] count];
            CheckUI([[[delegate removeContactPrompt:@"222"] informativeText] rangeOfString:@"сохранятся"].location!=NSNotFound,"contact deletion confirmation explains history preservation");
            [delegate removeContactUIN:@"222"];
            CheckUI(![[delegate valueForKey:@"serverContactIDs"] containsObject:@"222"] && [[delegate valueForKey:@"conversationPeers"] containsObject:@"222"] && [[[delegate valueForKey:@"history"] messagesForPeer:@"222"] count]==savedMessages,"removing contact preserves all saved conversation messages");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-empty-group.png"]);
            client.rejectRoster=YES; delegate.lastError=nil;
            [delegate renameContactUIN:@"333" name:@"Rejected name"];
            CheckUI(![[[[delegate valueForKey:@"contacts"] objectForKey:@"333"] objectForKey:@"_rosterFriendly"] isEqualToString:@"Rejected name"] && delegate.lastError!=nil && ![[delegate valueForKey:@"changingRoster"] boolValue],"failed server mutation keeps old roster and releases busy state");
            client.rejectRoster=NO; client.holdRoster=YES; [delegate createGroupNamed:@"Ожидание"];
            calls=client.rosterCalls.count; [delegate createGroupNamed:@"Не должна создаться"];
            CheckUI([[delegate valueForKey:@"changingRoster"] boolValue] && ![[delegate valueForKey:@"addContactButton"] isEnabled] && client.rosterCalls.count==calls,"pending roster operation blocks duplicate mutations");
            client.holdRoster=NO; void (^done)(NSDictionary *,NSError *)=client.pendingRoster; client.pendingRoster=nil; done(@{},nil);
            CheckUI([[delegate valueForKey:@"serverGroups"] containsObject:@"Ожидание"] && ![[delegate valueForKey:@"changingRoster"] boolValue],"completed operation restores contact controls");
            client.fixtureConnected=NO; [delegate client:client changedStatus:@"Тестовый офлайн" connected:NO]; context.representedObject=@"333";
            CheckUI(![delegate validateMenuItem:context] && ![[delegate valueForKey:@"createGroupButton"] isEnabled],"offline roster actions are disabled while history remains available");
            client.fixtureConnected=YES; [delegate client:client changedStatus:@"Тестовое подключение" connected:YES]; [delegate closeGroups:nil];
        }
        CheckUI(JMFlowerImage() != nil, "classic ICQ resource loads on Mavericks");
        for (NSString *state in @[@"online",@"away",@"dnd",@"occupied",@"invisible",@"offline"])
            CheckUI(NSEqualSizes(JMStatusImage(state).size,NSMakeSize(16,16)),"original Jimm status sprite decodes into 16px icons");
        SilentAudioAlerts *soundChecks=[[SilentAudioAlerts alloc] init]; soundChecks.enabled=YES; soundChecks.presenceEnabled=YES; soundChecks.typingEnabled=NO;
        for (NSString *event in @[@"message",@"online",@"offline",@"typing"]) CheckUI([soundChecks soundForEvent:event].duration>0,"bundled Jimm MP3 decodes on Mavericks");
        CheckUI([soundChecks playEvent:@"message"] && ![soundChecks playEvent:@"message"] && soundChecks.playCount==1,"message bursts are coalesced without overlapping audio");
        CheckUI(![soundChecks playEvent:@"typing"],"typing sound is optional and disabled by default");
        soundChecks.enabled=NO; CheckUI(![soundChecks playEvent:@"online"] && [soundChecks previewEvent:@"online"],"mute blocks notifications and explicit preview remains available");
        NSString *iconPath = [[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"../Resources/JimmMac.icns"];
        CheckUI([[NSImage alloc] initWithContentsOfFile:iconPath] != nil, "Dock ICNS container decodes on Mavericks");
        CheckUI(JMDecodeAvatar([JMFlowerImage() TIFFRepresentation])!=nil, "valid avatar is decoded");
        CheckUI(JMDecodeAvatar([NSMutableData dataWithLength:1024*1024+1])==nil, "oversized avatar rejected before decoding");
        NSBitmapImageRep *tiny=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1 pixelsHigh:1 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        CheckUI(JMDecodeAvatar([tiny representationUsingType:NSPNGFileType properties:@{}])==nil, "server 1px avatar placeholder uses system fallback");
        unsigned char emptyGIF[]={0x47,0x49,0x46,0x38,0x39,0x61,0x32,0x00,0x32,0x00,0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x21,0xf9,0x04,0x01,0x00,0x00,0x00,0x00,0x2c,0x00,0x00,0x00,0x00,0x32,0x00,0x32,0x00,0x00,0x02,0x02,0x44,0x01,0x00,0x3b};
        CheckUI(JMDecodeAvatar([NSData dataWithBytes:emptyGIF length:sizeof(emptyGIF)])==nil, "public bot empty GIF uses visible system fallback");
        NSBitmapImageRep *transparent=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:20 pixelsHigh:20 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:80 bitsPerPixel:32];
        memset([transparent bitmapData],0,1600);
        CheckUI(JMDecodeAvatar([transparent representationUsingType:NSPNGFileType properties:@{}])==nil, "fully transparent avatar uses visible system fallback");
        JMHTTPClient *redirectClient=[[JMHTTPClient alloc] initWithProtocolClasses:nil legacy:YES]; redirectClient.allowsSameOriginRedirects=YES;
        JMHTTPTask *redirectTask=[redirectClient dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://jimm.online/avatar"]] completionHandler:nil];
        CheckUI(![redirectTask allowsRedirect:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://external.invalid/avatar"]]],"avatar redirect cannot disclose request to another origin");
        [redirectClient invalidateAndCancel];
        {
            NSBitmapImageRep *photo=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:640 pixelsHigh:400 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:2560 bitsPerPixel:32];
            unsigned char *pixels=photo.bitmapData;
            for (NSUInteger y=0;y<400;y++) for (NSUInteger x=0;x<640;x++) {
                NSUInteger offset=y*photo.bytesPerRow+x*4;
                pixels[offset]=(unsigned char)(x*255/640); pixels[offset+1]=(unsigned char)(y*255/400); pixels[offset+2]=100; pixels[offset+3]=255;
            }
            NSError *photoError=nil; NSData *jpeg=JMPrepareAvatar([photo representationUsingType:NSPNGFileType properties:@{}],&photoError);
            NSBitmapImageRep *prepared=[NSBitmapImageRep imageRepWithData:jpeg];
            CheckUI(jpeg.length>0 && jpeg.length<=65536 && prepared.pixelsWide==256 && prepared.pixelsHigh==256 && !photoError,"photo import produces a square 256-pixel JPEG within server limit");
            [jpeg writeToFile:[output stringByAppendingPathComponent:@"fixture-avatar.jpg"] atomically:YES];
            CheckUI(JMPrepareAvatar([@"broken" dataUsingEncoding:NSUTF8StringEncoding],&photoError)==nil && photoError!=nil,"broken photograph is rejected before upload");
            CheckUI(JMPrepareAvatar([NSMutableData dataWithLength:20*1024*1024+1],NULL)==nil,"photo import bounds input bytes before ImageIO decoding");
            NSBitmapImageRep *stripe=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:16 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:128 bitsPerPixel:32];
            for (NSUInteger y=0;y<16;y++) for (NSUInteger x=0;x<32;x++) { unsigned char *p=stripe.bitmapData+y*128+x*4; p[0]=x<16 ? 255 : 0; p[1]=0; p[2]=x<16 ? 0 : 255; p[3]=255; }
            NSMutableData *rotated=[NSMutableData data]; CGImageDestinationRef destination=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)rotated,CFSTR("public.jpeg"),1,NULL);
            CGImageDestinationAddImage(destination,stripe.CGImage,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImagePropertyOrientation:@6}); CGImageDestinationFinalize(destination); CFRelease(destination);
            NSBitmapImageRep *upright=[NSBitmapImageRep imageRepWithData:JMPrepareAvatar(rotated,NULL)];
            NSColor *top=[[upright colorAtX:8 y:2] colorUsingColorSpaceName:NSDeviceRGBColorSpace], *bottom=[[upright colorAtX:8 y:13] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
            CheckUI(upright.pixelsWide==16 && upright.pixelsHigh==16 && fabs(top.redComponent-bottom.redComponent)>0.7,"photo import applies EXIF orientation before the centre crop");
            JMAvatarStore *raceStore=[[JMAvatarStore alloc] init];
            NSURL *cache=[root URLByAppendingPathComponent:@"avatar-cache" isDirectory:YES]; [[NSFileManager defaultManager] createDirectoryAtURL:cache withIntermediateDirectories:YES attributes:nil error:NULL];
            [raceStore setValue:cache forKey:@"cacheDirectory"];
            JMHTTPClient *inert=[[JMHTTPClient alloc] initWithProtocolClasses:nil legacy:YES];
            JMHTTPTask *old=[inert dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://fixture.invalid/old-avatar"]] completionHandler:nil];
            [[raceStore valueForKey:@"pending"] setObject:old forKey:@"111"];
            [raceStore storeUploadedAvatar:jpeg forUIN:@"111"]; NSImage *newImage=[raceStore imageForUIN:@"111"];
            [raceStore completeDownloadForUIN:@"111" task:old data:rotated error:nil];
            CheckUI(newImage!=nil && [raceStore imageForUIN:@"111"]==newImage && [[[raceStore valueForKey:@"pending"] allKeys] count]==0,"stale avatar download cannot replace a successful upload");
            [inert invalidateAndCancel]; [raceStore invalidate];
            FixtureAvatarStore *ownAvatars=[[FixtureAvatarStore alloc] init];
            JMOwnProfileController *editor=[[JMOwnProfileController alloc] initWithClient:client avatars:ownAvatars account:@"111"];
            client.fixtureConnected=YES; client.delegate=delegate;
            [editor openWithInfo:@{@"friendly":@"Тестовый пользователь"}];
            NSTextView *ownAbout=[editor valueForKey:@"about"]; NSTextField *caption=[editor valueForKey:@"statusField"];
            NSButton *save=[editor valueForKey:@"saveButton"]; NSTextField *feedback=[editor valueForKey:@"feedback"];
            CheckUI(ownAbout.editable && [ownAbout.string isEqualToString:client.ownAbout] && [caption.stringValue isEqualToString:client.ownCaption] && !save.enabled,"own profile loads before enabling edits and does not save unchanged fields");
            [editor saveProfile:nil]; CheckUI(client.ownCalls.count==0,"unchanged profile produces no mutations");
            NSTextField *first=[editor valueForKey:@"firstNameField"], *last=[editor valueForKey:@"lastNameField"];
            CheckUI([first.stringValue isEqualToString:@"Иван"] && [last.stringValue isEqualToString:@"Тестовый"],"own directory first and last name load into separate native fields");
            BOOL contained=YES, buttonTitlesFit=YES;
            NSView *editorRoot=editor.window.contentView;
            for (NSView *view in editorRoot.subviews) {
                if (!NSContainsRect(editorRoot.bounds,view.frame)) contained=NO;
                if ([view isKindOfClass:[NSButton class]] && [[(NSButton *)view attributedTitle] size].width+26>NSWidth(view.frame)) buttonTitlesFit=NO;
            }
            CheckUI(contained && buttonTitlesFit && caption.toolTip.length>0 && ownAbout.toolTip.length>0,"profile controls and complete button titles fit Mavericks window with native tooltips");
            Capture(editor.window,[output stringByAppendingPathComponent:@"UI-own-profile.png"]);
            [editor.window makeFirstResponder:caption]; [[caption currentEditor] selectAll:nil]; TypeInWindow(editor.window,@"Mavericks + ICQ"); [editor.window makeFirstResponder:nil];
            CheckUI([caption.stringValue isEqualToString:@"Mavericks + ICQ"] && save.enabled,"own status caption accepts and commits native keyboard input");
            ownAbout.string=@"Привет! Пишу из JimmMac на OS X Mavericks.\nЛюблю старые Mac."; [editor edited];
            [editor updateOwnInfo:@{@"friendly":@"Длинное имя, которое должно сокращаться только многоточием и иметь полную подсказку",@"statusMsg":@"Старое значение"}];
            CheckUI([caption.stringValue isEqualToString:@"Mavericks + ICQ"] && [ownAbout.string hasPrefix:@"Привет!"],"incoming own-info events preserve unsaved profile text");
            [editor stageAvatar:jpeg]; CheckUI([[editor valueForKey:@"revertButton"] isEnabled] && ownAvatars.savedImages==0,"choosing avatar previews it without uploading");
            [editor revertAvatar:nil]; CheckUI([editor valueForKey:@"pendingAvatar"]==nil && ownAvatars.savedImages==0,"cancel photo selection keeps server avatar unchanged");
            [editor stageAvatar:jpeg]; Capture(editor.window,[output stringByAppendingPathComponent:@"UI-own-profile-preview.png"]);
            client.fixtureConnected=NO; [editor connectionChanged]; NSUInteger ownCallCount=client.ownCalls.count; [editor saveProfile:nil];
            CheckUI(!save.enabled && ownAbout.editable && client.ownCalls.count==ownCallCount,"offline profile remains a draft and cannot mutate server");
            client.fixtureConnected=YES; [editor connectionChanged]; client.rejectOwnAction=@"avatar";
            [editor saveProfile:nil];
            CheckUI([client.ownCalls isEqual:@[@"about",@"caption",@"avatar"]] && [feedback.stringValue rangeOfString:@"Часть"].location!=NSNotFound && save.enabled && ownAvatars.savedImages==0,"partial save keeps failed avatar staged and reports successful text writes");
            Capture(editor.window,[output stringByAppendingPathComponent:@"UI-own-profile-error.png"]);
            client.rejectOwnAction=nil; [editor saveProfile:nil];
            CheckUI(client.ownCalls.count==4 && [client.ownCalls.lastObject isEqualToString:@"avatar"] && ownAvatars.savedImages==1 && !save.enabled,"retry uploads only the failed avatar and caches the accepted photo");
            first.stringValue=@"Юра & + ="; [editor edited]; [editor saveProfile:nil];
            CheckUI([client.ownNames[@"firstName"] isEqualToString:first.stringValue] && client.lastNameFields.count==1 && client.lastNameFields[@"lastName"]==nil && !save.enabled,"editing first name sends only changed directory field and verifies the result");
            last.stringValue=@""; [editor edited]; [editor saveProfile:nil];
            CheckUI(client.ownNames[@"lastName"]!=nil && [client.ownNames[@"lastName"] length]==0 && !save.enabled,"empty surname is saved explicitly without overwriting first name");
            first.stringValue=[@"я" stringByPaddingToLength:129 withString:@"я" startingAtIndex:0]; [editor edited];
            CheckUI(!save.enabled && [feedback.stringValue rangeOfString:@"128"].location!=NSNotFound,"name length validation explains unavailable save action");
            first.stringValue=client.ownNames[@"firstName"]; [editor edited];
            [editor loadProfile:nil]; CheckUI([ownAbout.string isEqualToString:client.ownAbout] && [caption.stringValue isEqualToString:client.ownCaption],"profile reload returns saved server fields");
            ownAbout.string=[@"я" stringByPaddingToLength:2049 withString:@"я" startingAtIndex:0]; [editor edited];
            CheckUI(!save.enabled && [[[editor valueForKey:@"counter"] stringValue] rangeOfString:@"4098"].location!=NSNotFound,"profile byte counter explains why Cyrillic text exceeds server limit");
            ownAbout.string=@"Проверка чтения"; [editor edited]; client.mismatchOwnRead=YES; [editor saveProfile:nil];
            CheckUI(save.enabled && [feedback.stringValue rangeOfString:@"другие"].location!=NSNotFound && [ownAbout.string isEqualToString:@"Проверка чтения"],"read-back mismatch does not claim confirmation or replace user's text");
            client.mismatchOwnRead=NO; [editor saveProfile:nil]; CheckUI(!save.enabled && [feedback.stringValue rangeOfString:@"сохранены"].location!=NSNotFound,"text edits are confirmed by fresh server read-back");
            ownAbout.string=@"Ещё одна проверка"; [editor edited]; client.rejectOwnRead=YES; [editor saveProfile:nil];
            CheckUI(!save.enabled && [feedback.stringValue rangeOfString:@"проверка"].location!=NSNotFound,"read-back failure does not turn an accepted write into a retry");
            client.rejectOwnRead=NO; [editor loadProfile:nil];
            ownAbout.string=@""; caption.stringValue=@""; [editor edited]; [editor saveProfile:nil];
            CheckUI(client.ownAbout.length==0 && client.ownCaption.length==0 && !save.enabled,"empty fields clear own profile and caption");
            ownAbout.string=@"Поздний ответ"; [editor edited]; client.holdOwnAction=YES; [editor saveProfile:nil];
            CheckUI(!ownAbout.editable && !save.enabled,"pending profile save blocks duplicate writes");
            [editor invalidate]; client.pendingOwn(@{},nil); client.pendingOwn=nil; client.holdOwnAction=NO;
            CheckUI(!editor.window.visible && ownAbout.string.length==0 && [editor valueForKey:@"pendingAvatar"]==nil,"late completion after logout cannot revive profile or retain a photo draft");
            client.rejectOwnRead=YES; editor=[[JMOwnProfileController alloc] initWithClient:client avatars:ownAvatars account:@"111"]; [editor openWithInfo:@{}];
            CheckUI(![[editor valueForKey:@"about"] isEditable] && ![[editor valueForKey:@"saveButton"] isEnabled] && [[editor valueForKey:@"reloadButton"] isEnabled],"failed initial read cannot overwrite unknown server fields with empty text");
            [editor invalidate]; client.rejectOwnRead=NO;
            id previousAccount=[delegate valueForKey:@"accountUIN"]; id previousAvatars=[delegate valueForKey:@"avatars"];
            [delegate setValue:@"111" forKey:@"accountUIN"]; [delegate setValue:ownAvatars forKey:@"avatars"]; [delegate showOwnProfile:nil];
            JMOwnProfileController *integrated=[delegate valueForKey:@"ownProfileController"];
            CheckUI(integrated.window.visible,"application menu opens own editor independently of selected peer");
            [integrated invalidate]; [delegate setValue:nil forKey:@"ownProfileController"]; [delegate setValue:previousAccount forKey:@"accountUIN"]; [delegate setValue:previousAvatars forKey:@"avatars"];
        }
        {
            FakeNotificationAlerts *alerts=[delegate valueForKey:@"notificationAlerts"];
            [delegate markAllRead:nil]; alerts.enabled=YES; alerts.accountUIN=@"111"; alerts.contentStyle=@"sender"; alerts.dockAttentionEnabled=NO;
            audio.enabled=YES; audio.soundInOpenConversation=YES; delegate.forcedReading=@NO;
            for (NSUInteger i=0;i<3;i++) [delegate client:client receivedMessage:Incoming([NSString stringWithFormat:@"banner-%lu",(unsigned long)i],@"888",@"Тестовое личное сообщение")];
            PumpUI(0.8);
            NSUserNotification *note=[alerts.posted lastObject];
            CheckUI(alerts.posted.count==1 && [note.informativeText isEqualToString:@"Новых сообщений: 3"],"burst of incoming messages becomes one native notification");
            CheckUI([note.title isEqualToString:@"Тестовый отправитель"] && [note.informativeText rangeOfString:@"личное"].location==NSNotFound && note.soundName==nil,"default notification hides message text and avoids duplicate system sound");
            CheckUI(note.userInfo[@"text"]==nil && note.userInfo[@"token"]==nil && [note.userInfo[@"peer"] isEqualToString:@"888"],"notification routing payload has no message text or credentials");
            NSUInteger soundsBefore=audio.events.count;
            [delegate client:client receivedMessage:Incoming(@"banner-0",@"888",@"Тестовое личное сообщение")];
            [alerts flushPeer:@"888"];
            CheckUI(alerts.posted.count==1 && audio.events.count==soundsBefore && [[[delegate valueForKey:@"unread"] objectForKey:@"888"] integerValue]==3,"duplicate delivery cannot add unread, sound or notification");
            NSString *identifier=note.identifier;
            [delegate client:client receivedMessage:Incoming(@"banner-next",@"888",@"Следующее сообщение")]; PumpUI(0.15);
            CheckUI([[[alerts.posted lastObject] informativeText] isEqualToString:note.informativeText],"notification cooldown does not immediately show another banner");
            [alerts flushPeer:@"888"];
            CheckUI(alerts.posted.count==1 && [[[alerts.posted lastObject] identifier] isEqualToString:identifier],"new notification replaces existing entry for same account and peer");
            alerts.contentStyle=@"preview"; [alerts queueMessageFrom:@"888" name:@"Имя" text:@"Текст для предпросмотра"]; [alerts flushPeer:@"888"];
            CheckUI([[[alerts.posted lastObject] informativeText] isEqualToString:@"Текст для предпросмотра"],"opt-in preview includes message text");
            NSUserNotification *oldPreview=[alerts.posted lastObject]; alerts.contentStyle=@"private";
            [alerts postNotification:oldPreview]; [alerts userNotificationCenter:nil didDeliverNotification:oldPreview];
            CheckUI(alerts.posted.count==0 && ![alerts userNotificationCenter:nil shouldPresentNotification:oldPreview],"privacy change rejects stale preview still in OS delivery");
            [alerts queueMessageFrom:@"888" name:@"Скрытое имя" text:@"Скрытый текст"]; [alerts flushPeer:@"888"];
            note=[alerts.posted lastObject]; CheckUI([note.title isEqualToString:@"JimmMac"] && [note.informativeText isEqualToString:@"Новое сообщение"],"private notification hides both sender and text");
            [fontDefaults synchronize]; JMNotificationAlerts *reload=[[JMNotificationAlerts alloc] initWithDefaults:[[NSUserDefaults alloc] initWithSuiteName:suite] center:nil];
            CheckUI([reload.contentStyle isEqualToString:@"private"] && !reload.dockAttentionEnabled,"notification privacy and Dock settings persist"); [reload invalidate];
            alerts.contentStyle=@"sender"; [alerts queueMessageFrom:@"888" name:@"Имя" text:@"Отложенное"]; alerts.enabled=NO; [alerts flushPeer:@"888"];
            CheckUI(alerts.posted.count==0,"disabling notifications cancels pending and delivered entries");
            alerts.enabled=YES; [alerts queueMessageFrom:@"888" name:@"Имя" text:@"Старый аккаунт"]; alerts.accountUIN=@"444"; [alerts flushPeer:@"888"];
            CheckUI(alerts.posted.count==0,"account switch cancels stale notifications"); alerts.accountUIN=@"111";
            [delegate markAllRead:nil]; [delegate selectPeer:@"222"]; [delegate jumpToLatest:nil]; delegate.forcedReading=@YES;
            audio.soundInOpenConversation=NO; soundsBefore=audio.events.count;
            [delegate client:client receivedMessage:Incoming(@"reading-active",@"222",@"Сообщение в открытой переписке")]; [alerts flushPeer:@"222"];
            CheckUI(alerts.posted.count==0 && [[delegate valueForKey:@"unread"] objectForKey:@"222"]==nil && audio.events.count==soundsBefore,"reading latest messages suppresses banner, unread and optional foreground sound");
            audio.soundInOpenConversation=YES;
            [delegate client:client receivedMessage:Incoming(@"other-chat",@"999",@"Сообщение в другой переписке")]; [alerts flushPeer:@"999"];
            note=[alerts.posted lastObject];
            CheckUI(alerts.posted.count==1 && [alerts userNotificationCenter:nil shouldPresentNotification:note],"other conversation can notify while application is active");
            [delegate selectPeer:@"999"];
            CheckUI(alerts.posted.count==0 && [[delegate valueForKey:@"unread"] objectForKey:@"999"]==nil,"reading conversation removes its delivered notification");
            [delegate selectPeer:@"222"]; NSClipView *historyClip=linkedTranscript.enclosingScrollView.contentView; [historyClip scrollToPoint:NSZeroPoint];
            [delegate client:client receivedMessage:Incoming(@"reading-history",@"222",@"Новое сообщение, пока открыта старая история")]; [alerts flushPeer:@"222"];
            NSButton *latest=[delegate valueForKey:@"latestMessagesButton"];
            CheckUI(!latest.isHidden && [[[delegate valueForKey:@"unread"] objectForKey:@"222"] integerValue]==1 && NSMinY(historyClip.bounds)<2,"reading history keeps position and shows new-message jump button");
            CheckUI(!NSIntersectsRect(latest.frame,[[delegate valueForKey:@"typingLabel"] frame]),"new-message button leaves typing indicator enough room");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-unread.png"]);
            [latest performClick:nil]; CheckUI(latest.isHidden && alerts.posted.count==0 && [[delegate valueForKey:@"unread"] objectForKey:@"222"]==nil,"jump to latest clears unread and notification once visible");
            NSUserNotification *late=[[NSUserNotification alloc] init]; late.identifier=@"late-race"; late.userInfo=@{@"kind":@"message",@"account":@"111",@"peer":@"222"};
            [alerts postNotification:late]; [alerts userNotificationCenter:nil didDeliverNotification:late];
            CheckUI(alerts.posted.count==0,"late OS delivery is removed after conversation became read");
            late.userInfo=@{@"kind":@"message",@"account":@"444",@"peer":@"222"}; [alerts postNotification:late]; [alerts userNotificationCenter:nil didDeliverNotification:late];
            CheckUI(alerts.posted.count==0,"late delivery from another account is removed");
            delegate.forcedReading=@NO; [delegate client:client receivedMessage:Incoming(@"click-route",@"222",@"Уведомление с переходом")]; [alerts flushPeer:@"222"];
            note=[alerts.posted lastObject]; NSUserNotification *clicked=[[NSUserNotification alloc] init]; clicked.userInfo=note.userInfo; clicked.identifier=note.identifier;
            [delegate selectPeer:@"999"]; composer.string=@"Черновик перед уведомлением"; [delegate textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:composer]];
            // activationType is read-only and supplied by Notification Center.
            // Exercise the shared launch/click handler without faking OS internals.
            [alerts userNotificationCenter:nil didActivateNotification:clicked];
            CheckUI([[delegate valueForKey:@"selectedPeer"] isEqualToString:@"999"],"notification without OS activation is ignored by click delegate");
            delegate.forcedReading=@YES; [alerts handleActivation:clicked];
            CheckUI([[delegate valueForKey:@"selectedPeer"] isEqualToString:@"222"] && [[[delegate valueForKey:@"drafts"] objectForKey:@"999"] isEqualToString:@"Черновик перед уведомлением"],"notification click opens correct conversation and preserves other draft");
            CheckUI([[delegate valueForKey:@"unread"] objectForKey:@"222"]==nil && alerts.posted.count==0,"notification click marks newly visible latest messages read");
            delegate.lastError=nil; clicked.userInfo=@{@"kind":@"message",@"account":@"444",@"peer":@"555"}; [alerts handleActivation:clicked];
            CheckUI(delegate.lastError!=nil && [[delegate valueForKey:@"selectedPeer"] isEqualToString:@"222"] && [alerts.accountUIN isEqualToString:@"111"],"foreign-account notification cannot switch current session");
            client.fixtureConnected=NO; clicked.userInfo=@{@"kind":@"message",@"account":@"111",@"peer":@"999"}; [alerts handleActivation:clicked];
            CheckUI([[delegate valueForKey:@"pendingNotificationPeer"] isEqualToString:@"999"],"notification navigation waits for reconnect");
            client.fixtureConnected=YES; [delegate client:client changedStatus:@"Тестовое подключение" connected:YES];
            CheckUI([[delegate valueForKey:@"selectedPeer"] isEqualToString:@"999"] && [delegate valueForKey:@"pendingNotificationPeer"]==nil,"reconnect completes deferred notification navigation");
            [delegate showPreferences:nil]; NSSegmentedControl *preferencesTabs=[delegate valueForKey:@"preferenceSections"];
            [preferencesTabs setSelectedSegment:1]; [delegate changePreferenceSection:nil];
            NSButton *enabled=[delegate valueForKey:@"notificationsCheckbox"]; NSPopUpButton *content=[delegate valueForKey:@"notificationContentPopup"];
            enabled.state=NSOffState; [delegate alertPreferencesChanged:enabled];
            CheckUI(!alerts.enabled && !content.isEnabled && ![[delegate valueForKey:@"notificationTestButton"] isEnabled],"notification settings disable dependent controls");
            enabled.state=NSOnState; [delegate alertPreferencesChanged:enabled]; [content selectItemAtIndex:2]; [delegate alertPreferencesChanged:content];
            CheckUI([alerts.contentStyle isEqualToString:@"private"],"privacy popup controls actual notification content mode");
            [content selectItemAtIndex:0]; [delegate alertPreferencesChanged:content];
            [delegate testNotification:nil]; note=[alerts.posted lastObject];
            CheckUI([note.userInfo[@"kind"] isEqualToString:@"test"] && [alerts userNotificationCenter:nil shouldPresentNotification:note],"built-in notification check can present while preferences are frontmost");
            Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:@"UI-notification-settings.png"]);
            NSUInteger shows=delegate.showWindowCount; clicked.userInfo=note.userInfo; clicked.identifier=note.identifier; [alerts handleActivation:clicked];
            CheckUI(delegate.showWindowCount==shows+1,"test notification click opens application without a conversation route");
            [delegate showPreferences:nil]; [preferencesTabs setSelectedSegment:2]; [delegate changePreferenceSection:nil];
            NSButton *typing=[delegate valueForKey:@"typingSoundCheckbox"]; typing.state=NSOnState; [delegate alertPreferencesChanged:typing];
            [fontDefaults synchronize]; JMAudioAlerts *audioReload=[[JMAudioAlerts alloc] initWithDefaults:[[NSUserDefaults alloc] initWithSuiteName:suite]];
            CheckUI(audioReload.typingEnabled && audioReload.soundInOpenConversation,"sound settings persist through a new preferences instance");
            typing.state=NSOffState; [delegate alertPreferencesChanged:typing];
            Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:@"UI-sound-settings.png"]);
            [delegate toggleSounds:nil]; CheckUI(!audio.enabled && ![[delegate valueForKey:@"presenceSoundCheckbox"] isEnabled] && [[delegate valueForKey:@"soundMasterCheckbox"] state]==NSOffState,"footer mute stays synchronized with sound preferences"); [delegate toggleSounds:nil];
            [delegate closePreferences:nil];
            JMHistory *savedHistory=[delegate valueForKey:@"history"]; delegate.forcedReading=@NO;
            [delegate client:client receivedMessage:Incoming(@"logout-pending",@"333",@"Ожидающее уведомление")]; client.fixtureConnected=NO; [delegate logout:nil]; [alerts flushPeer:@"333"];
            CheckUI(alerts.accountUIN==nil && alerts.posted.count==0 && [[delegate valueForKey:@"unread"] count]==0,"logout clears pending notifications and badge state");
            clicked.userInfo=@{@"kind":@"message",@"account":@"111",@"peer":@"333"}; [alerts handleActivation:clicked];
            CheckUI([[[delegate valueForKey:@"uinField"] stringValue] isEqualToString:@"111"] && [[delegate valueForKey:@"pendingNotificationPeer"] isEqualToString:@"333"],"launch notification waits at login for intended account");
            [delegate setValue:savedHistory forKey:@"history"]; delegate.forcedReading=@YES; client.fixtureConnected=YES;
            [delegate client:client changedStatus:@"Тестовый вход" connected:YES];
            CheckUI([[delegate valueForKey:@"selectedPeer"] isEqualToString:@"333"] && [delegate valueForKey:@"pendingNotificationPeer"]==nil,"successful login opens deferred notification conversation");
            [delegate markAllRead:nil]; CheckUI([[[NSApp dockTile] badgeLabel] length]==0,"mark all read clears Dock badge"); [alerts invalidate];
        }
        {
            [delegate client:client receivedBuddyList:@{@"groups":@[@{@"name":@"Тестовые контакты",@"buddies":@[@{@"aimId":@"222",@"friendly":@"Тестовый контакт",@"state":@"online"},@{@"aimId":@"333",@"friendly":@"Другой контакт",@"state":@"away"}]}]}];
            [delegate setValue:@"111" forKey:@"accountUIN"]; [delegate restoreDraftsForUIN:@"111"]; [delegate selectPeer:@"222"];
            [chat makeKeyAndOrderFront:nil]; [chat makeFirstResponder:composer]; client.fixtureConnected=YES;
            Draft(delegate,composer,@"Черновик между запусками + &\nЕщё строка"); PumpUI(0.9);
            JMDraftStore *disk=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
            CheckUI([disk.drafts[@"222"] isEqualToString:composer.string] && ![[delegate valueForKey:@"draftsPending"] boolValue],"typing automatically persists per-peer draft after debounce");
            [delegate selectPeer:@"333"]; Draft(delegate,composer,@"Другой черновик"); [delegate flushDrafts];
            [delegate setValue:nil forKey:@"selectedPeer"]; [delegate restoreDraftsForUIN:@"999"];
            CheckUI([[delegate valueForKey:@"drafts"] count]==0,"switching account never restores another account's draft");
            [delegate restoreDraftsForUIN:@"111"]; [delegate selectPeer:@"222"];
            CheckUI([composer.string isEqualToString:@"Черновик между запусками + &\nЕщё строка"],"recreated account store restores complete multiline draft");
            CheckUI([[[delegate valueForKey:@"composerHint"] stringValue] rangeOfString:@"сохранён"].location!=NSNotFound,"saved draft has visible feedback");
            NSMenu *base=[[NSMenu alloc] initWithTitle:@"Native"]; [base addItemWithTitle:@"Копировать" action:@selector(copy:) keyEquivalent:@""];
            NSRange clicked=[linkedTranscript.string rangeOfString:@"Ссылка https://jimm.online/developers"];
            NSMenu *messageMenu=[delegate textView:linkedTranscript menu:base forEvent:nil atIndex:clicked.location];
            CheckUI(messageMenu.numberOfItems==5 && base.numberOfItems==1 && [messageMenu itemAtIndex:1].action==@selector(quoteMessage:),"message context menu adds quote and whole-message copy without replacing native actions");
            NSMenuItem *quoteItem=[messageMenu itemAtIndex:1], *copyItem=[messageMenu itemAtIndex:2];
            [delegate copyWholeMessage:copyItem];
            CheckUI([delegate.copiedMessage isEqualToString:@"Ссылка https://jimm.online/developers и test@example.com. Тест поиска — Mavericks."],"copy whole message excludes timestamp and sender heading");
            Draft(delegate,composer,@"Мой ответ уже набран"); NSUInteger sends=client.sendCount; [delegate quoteMessage:quoteItem];
            CheckUI([composer.string rangeOfString:@"> Ссылка https://jimm.online/developers"].location!=NSNotFound && [composer.string hasSuffix:@"Мой ответ уже набран"] && client.sendCount==sends,"quote prepends plain text and preserves reply draft without sending");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-message-quote.png"]);
            [delegate flushDrafts]; CheckUI([[[[JMDraftStore alloc] initWithUIN:@"111" root:root] drafts][@"222"] isEqualToString:composer.string],"quoted reply survives account store recreation");
            CheckUI([delegate textView:linkedTranscript menu:base forEvent:nil atIndex:linkedTranscript.string.length-1]==base,"empty space between messages has no stale message action");
            [delegate selectPeer:@"333"]; delegate.copiedMessage=nil; [delegate copyWholeMessage:copyItem];
            CheckUI(delegate.copiedMessage==nil,"stale context action cannot copy from a different conversation");
            [delegate selectPeer:@"222"]; Draft(delegate,composer,@"Первое сообщение");
            ReturnInWindow(chat,0);
            CheckUI(client.sendCount==sends+1 && [client.sentText isEqualToString:@"Первое сообщение"] && composer.editable && !send.enabled,"Enter sends once and keeps composer editable during confirmation");
            TypeInWindow(chat,@" + следующий текст"); ReturnInWindow(chat,0);
            CheckUI(client.sendCount==sends+1,"second Enter cannot duplicate a pending send");
            FinishSend(client,@"compose-send-1",nil);
            CheckUI([composer.string isEqualToString:@" + следующий текст"] && !composer.undoManager.canUndo,"confirmation removes sent prefix, preserves new text and cannot undo into sent content");
            Draft(delegate,composer,@"Сообщение для замены"); ReturnInWindow(chat,0);
            [composer setSelectedRange:NSMakeRange(0,composer.string.length)]; TypeInWindow(chat,@"Новый отдельный черновик");
            [delegate flushDrafts]; disk=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
            CheckUI([disk.drafts[@"222"] isEqualToString:@"Сообщение для замены\n\nНовый отдельный черновик"] && [composer.string isEqualToString:@"Новый отдельный черновик"],"unacknowledged text and replaced draft are both recoverable from disk before confirmation");
            FinishSend(client,@"compose-send-2",nil);
            CheckUI([composer.string isEqualToString:@"Новый отдельный черновик"],"confirmation preserves a completely replaced draft");
            Draft(delegate,composer,@"Неотправленный текст"); ReturnInWindow(chat,0);
            [composer setSelectedRange:NSMakeRange(0,composer.string.length)]; TypeInWindow(chat,@"Следующий черновик");
            NSError *timeout=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:@{NSLocalizedDescriptionKey:@"Test timeout"}];
            sends=client.sendCount; FinishSend(client,nil,timeout); PumpUI(0.7);
            CheckUI([composer.string isEqualToString:@"Неотправленный текст\n\nСледующий черновик"] && client.sendCount==sends && [delegate.lastError rangeOfString:@"могло"].location!=NSNotFound,"failed ambiguous send recovers old text, keeps new draft and never retries automatically");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-recovered-draft.png"]);
            Draft(delegate,composer,@"Первому собеседнику"); ReturnInWindow(chat,0);
            [delegate selectPeer:@"333"]; Draft(delegate,composer,@"Второму собеседнику"); FinishSend(client,@"compose-send-3",nil);
            [delegate flushDrafts]; disk=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
            CheckUI([composer.string isEqualToString:@"Второму собеседнику"] && disk.drafts[@"222"]==nil && [disk.drafts[@"333"] isEqualToString:composer.string],"successful send clears only its own draft on disk after conversation switch");
            [delegate showPreferences:nil]; NSPopUpButton *mode=[delegate valueForKey:@"sendModePopup"];
            [[delegate valueForKey:@"preferenceSections"] setSelectedSegment:0]; [delegate changePreferenceSection:nil];
            [mode selectItemAtIndex:1]; [delegate sendModeChanged:mode]; [fontDefaults synchronize];
            CheckUI([[[JMChatPreferences alloc] initWithDefaults:[[NSUserDefaults alloc] initWithSuiteName:suite]] sendWithCommandReturn],"Command-Enter preference persists independently of font settings");
            Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:@"UI-composer-settings.png"]);
            [delegate closePreferences:nil]; [chat makeKeyAndOrderFront:nil]; [chat makeFirstResponder:composer];
            Draft(delegate,composer,@"Строка"); sends=client.sendCount; ReturnInWindow(chat,0);
            CheckUI([composer.string isEqualToString:@"Строка\n"] && client.sendCount==sends,"Enter inserts newline in Command-Enter mode");
            ReturnInWindow(chat,NSShiftKeyMask);
            CheckUI(client.sendCount==sends && [composer.string hasSuffix:@"\n\n"],"Shift-Enter remains a newline in Command-Enter mode");
            ReturnInWindow(chat,NSCommandKeyMask);
            CheckUI(client.sendCount==sends+1,"native Command-Enter menu equivalent sends focused composer");
            FinishSend(client,@"compose-cmd-send",nil);
            CheckUI(composer.string.length==0,"successful Command-Enter send removes complete draft");
            Draft(delegate,composer,[@"я" stringByPaddingToLength:2001 withString:@"я" startingAtIndex:0]);
            CheckUI(!send.enabled && [[[delegate valueForKey:@"composerHint"] stringValue] rangeOfString:@"4002"].location!=NSNotFound,"long Unicode draft stays editable with visible UTF-8 size limit");
            Draft(delegate,composer,@"Текст с вводом"); [composer setMarkedText:@"文" selectedRange:NSMakeRange(1,0) replacementRange:NSMakeRange(composer.string.length,0)];
            sends=client.sendCount; [delegate send:nil]; CheckUI(composer.hasMarkedText && client.sendCount==sends,"uncommitted input method composition is never sent"); [composer unmarkText];
            [delegate showHistorySearch:nil]; Draft(delegate,composer,@"Не отправлять из поиска");
            ReturnInWindow([delegate valueForKey:@"historyWindow"],NSCommandKeyMask);
            CheckUI(client.sendCount==sends,"Command-Enter cannot send a draft from another window"); [delegate closeHistorySearch:nil];
            JMDraftStore *healthyStore=[delegate valueForKey:@"draftStore"];
            (void)[[JMDraftStore alloc] initWithUIN:@"777" root:root];
            NSURL *brokenFile=[root URLByAppendingPathComponent:@"JimmMac/accounts/777/drafts.json"];
            [@"broken" writeToURL:brokenFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            [delegate setValue:[[JMDraftStore alloc] initWithUIN:@"777" root:root] forKey:@"draftStore"];
            [delegate flushDrafts]; delegate.refuseDraftLoss=YES; [delegate logout:nil];
            CheckUI([[delegate valueForKey:@"accountUIN"] isEqualToString:@"111"] && composer.string.length>0 && [[[delegate valueForKey:@"composerHint"] stringValue] rangeOfString:@"Не удалось"].location!=NSNotFound,"failed draft persistence keeps text visible and can cancel account logout");
            [delegate setValue:healthyStore forKey:@"draftStore"]; delegate.refuseDraftLoss=NO; [delegate flushDrafts];
            [delegate showPreferences:nil]; [mode selectItemAtIndex:0]; [delegate sendModeChanged:mode]; [delegate closePreferences:nil];
            [chat makeKeyAndOrderFront:nil]; [chat makeFirstResponder:composer]; Draft(delegate,composer,@"Последний черновик"); ReturnInWindow(chat,0);
            void (^lateSend)(NSDictionary *,NSError *)=client.pendingSend; client.pendingSend=nil;
            [delegate logout:nil]; lateSend(@{@"msgId":@"late-after-logout"},nil);
            disk=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
            CheckUI([disk.drafts[@"333"] isEqualToString:@"Последний черновик"] && [delegate valueForKey:@"history"]==nil && composer.string.length==0,"logout flushes unsent draft and ignores late send completion");
            [delegate copyWholeMessage:copyItem]; CheckUI(delegate.copiedMessage==nil,"logout invalidates a previously opened message menu");
        }
        {
            FakeLoginStore *store=[delegate valueForKey:@"loginStore"]; client.fixtureConnected=NO;
            NSButton *remember=[delegate valueForKey:@"rememberLoginCheckbox"], *cancel=[delegate valueForKey:@"cancelLoginButton"];
            NSTextField *loginUIN=[delegate valueForKey:@"uinField"], *password=[delegate valueForKey:@"passwordField"];
            CheckUI(remember.state==NSOnState && remember.enabled && remember.toolTip.length>0 && store.reads==0,"remember-me choice is visible without reading any keychain item on first launch");
            loginUIN.stringValue=@"111"; password.stringValue=@"fixture-password-only"; [delegate login:nil];
            CheckUI(client.passwordLogins==1 && client.requestedLongTerm && password.stringValue.length==0 && !cancel.hidden,"remembered manual login requests long-term token and clears password field");
            [delegate client:client authenticatedWithToken:@"fixture-ui-token" expiresAt:[NSDate dateWithTimeIntervalSinceNow:3600]];
            client.fixtureConnected=YES; [delegate client:client changedStatus:@"Подключено · тестовый вход" connected:YES]; LoginQueue(delegate);
            CheckUI(store.saves==1 && [store.records[@"111"][@"token"] isEqualToString:@"fixture-ui-token"] && [[fontDefaults stringForKey:@"RememberedAccountUIN"] isEqualToString:@"111"] && cancel.hidden,"successful remembered login stores only token and enables next launch");
            NSString *savedPreferences=[[fontDefaults persistentDomainForName:suite] description];
            CheckUI([savedPreferences rangeOfString:@"fixture-ui-token"].location==NSNotFound && [savedPreferences rangeOfString:@"fixture-password-only"].location==NSNotFound && store.records[@"111"][@"password"]==nil,"password and token never enter preferences or draft data");
            client.fixtureConnected=NO; [delegate setValue:@NO forKey:@"loginPending"]; NSUInteger passwordCount=client.passwordLogins;
            [delegate setValue:@"222" forKey:@"pendingNotificationAccount"]; NSUInteger keychainReads=store.reads;
            [delegate startAutomaticLogin]; LoginQueue(delegate);
            CheckUI(store.reads==keychainReads && client.tokenLogins==0,"notification for another account cannot silently start remembered UIN");
            [delegate setValue:nil forKey:@"pendingNotificationAccount"];
            [delegate startAutomaticLogin]; LoginQueue(delegate);
            CheckUI(client.tokenLogins==1 && client.passwordLogins==passwordCount && !password.enabled && !cancel.hidden,"saved login restores by token without password entry and offers cancellation");
            Capture([delegate valueForKey:@"loginWindow"],[output stringByAppendingPathComponent:@"UI-auto-login.png"]);
            [delegate cancelLogin:nil]; LoginQueue(delegate);
            CheckUI(password.enabled && cancel.hidden && store.records[@"111"]!=nil && [[fontDefaults stringForKey:@"RememberedAccountUIN"] isEqualToString:@"111"],"cancel interrupts this connection without forgetting the saved login");
            [delegate startAutomaticLogin]; LoginQueue(delegate);
            [delegate client:client failedLogin:[NSError errorWithDomain:JMAPIErrorDomain code:401 userInfo:@{NSLocalizedDescriptionKey:@"Сохранённый вход больше не действует. Введите пароль."}]]; LoginQueue(delegate);
            CheckUI(store.records[@"111"]==nil && [fontDefaults objectForKey:@"RememberedAccountUIN"]==nil && password.enabled,"server rejection forgets invalid saved token and returns editable password login");
            store.records[@"111"]=@{@"token":@"fixture-ui-token",@"expiresAt":[NSDate dateWithTimeIntervalSinceNow:3600]}; [fontDefaults setObject:@"111" forKey:@"RememberedAccountUIN"];
            store.readFailure=[NSError errorWithDomain:JMLoginStoreErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Срок сохранённого входа истёк. Введите пароль ещё раз."}];
            [delegate startAutomaticLogin]; LoginQueue(delegate);
            CheckUI(store.records[@"111"]==nil && [fontDefaults objectForKey:@"RememberedAccountUIN"]==nil && password.enabled,"locally expired credential is removed without attempting server login"); store.readFailure=nil;
            store.records[@"111"]=@{@"token":@"fixture-ui-token",@"expiresAt":[NSDate dateWithTimeIntervalSinceNow:3600]}; [fontDefaults setObject:@"111" forKey:@"RememberedAccountUIN"];
            store.failure=[NSError errorWithDomain:JMLoginStoreErrorDomain code:errSecInteractionNotAllowed userInfo:@{NSLocalizedDescriptionKey:@"Связка ключей недоступна."}];
            NSUInteger removals=store.removals; [delegate startAutomaticLogin]; LoginQueue(delegate);
            CheckUI(store.removals==removals && store.records[@"111"]!=nil && password.enabled,"unavailable keychain preserves credential and offers manual login"); store.failure=nil;
            store.readGate=dispatch_semaphore_create(0); store.readStarted=dispatch_semaphore_create(0);
            NSUInteger tokenLogins=client.tokenLogins; [delegate startAutomaticLogin];
            CheckUI(dispatch_semaphore_wait(store.readStarted,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,"keychain read can remain in progress without blocking UI");
            [delegate cancelLogin:nil]; dispatch_semaphore_signal(store.readGate); LoginQueue(delegate); store.readGate=nil; store.readStarted=nil;
            CheckUI(client.tokenLogins==tokenLogins && password.enabled,"late keychain read after cancel cannot reconnect the account");
            remember.state=NSOffState; [delegate rememberLoginChanged:remember]; LoginQueue(delegate);
            CheckUI(store.records[@"111"]==nil && [fontDefaults objectForKey:@"RememberedAccountUIN"]==nil,"disabling remember-me removes saved login");
            loginUIN.stringValue=@"111"; password.stringValue=@"fixture-password-only"; [delegate login:nil];
            NSUInteger saves=store.saves; [delegate client:client authenticatedWithToken:@"session-only-fixture" expiresAt:[NSDate dateWithTimeIntervalSinceNow:3600]]; LoginQueue(delegate);
            CheckUI(!client.requestedLongTerm && store.saves==saves,"unchecked remember-me keeps token in memory only");
            [delegate cancelLogin:nil]; remember.state=NSOnState;
            loginUIN.stringValue=@"111"; password.stringValue=@"fixture-password-only"; [delegate login:nil];
            store.failure=[NSError errorWithDomain:JMLoginStoreErrorDomain code:errSecAuthFailed userInfo:@{NSLocalizedDescriptionKey:@"Связка ключей недоступна."}];
            [delegate client:client authenticatedWithToken:@"fixture-ui-token" expiresAt:[NSDate dateWithTimeIntervalSinceNow:3600]]; LoginQueue(delegate);
            CheckUI([fontDefaults objectForKey:@"RememberedAccountUIN"]==nil && [delegate.lastError rangeOfString:@"недоступна"].location!=NSNotFound,"failed keychain save does not claim persistent login"); store.failure=nil;
            [delegate cancelLogin:nil]; loginUIN.stringValue=@"111"; password.stringValue=@"fixture-password-only"; [delegate login:nil];
            [delegate client:client authenticatedWithToken:@"fixture-ui-token" expiresAt:[NSDate dateWithTimeIntervalSinceNow:3600]];
            [delegate logout:nil]; LoginQueue(delegate);
            CheckUI(store.records[@"111"]==nil && [fontDefaults objectForKey:@"RememberedAccountUIN"]==nil,"logout waits behind a pending save and cannot resurrect remembered login");
            CheckUI(NSContainsRect([[remember superview] bounds],remember.frame) && !NSIntersectsRect(remember.frame,[[delegate valueForKey:@"loginButton"] frame]) && !NSIntersectsRect(remember.frame,password.frame),"remember-me control and login buttons fit native Mavericks layout");
            Capture([delegate valueForKey:@"loginWindow"],[output stringByAppendingPathComponent:@"UI-remember-login.png"]);
        }
        {
            JMListCell *cell=[[JMListCell alloc] initWithFrame:NSMakeRect(0,0,220,60)];
            NSString *longTitle=@"Очень длинное имя контакта для проверки подсказки";
            [cell configureName:longTitle detail:@"Черновик: важное сообщение" state:@"online" unread:500]; [cell setTimestamp:@"Вчера" draft:YES]; [cell setTimestampTooltip:@"29.10.2026 12:00"];
            NSTextField *time=[cell valueForKey:@"timestampLabel"], *detail=[cell valueForKey:@"detailLabel"]; NSView *badge=[cell valueForKey:@"badge"];
            CheckUI(NSContainsRect(cell.bounds,cell.textField.frame) && NSContainsRect(cell.bounds,time.frame) && !NSIntersectsRect(cell.textField.frame,time.frame) && !NSIntersectsRect(detail.frame,badge.frame),"long contact name, timestamp, preview and unread badge have separate bounded areas");
            CheckUI(NSWidth(time.frame)>=[[time cell] cellSize].width,"timestamp reserves native text-cell insets and never truncates short time");
            CheckUI([[badge valueForKey:@"text"] isEqualToString:@"99+"] && [badge.toolTip rangeOfString:@"500"].location!=NSNotFound && [cell.toolTip rangeOfString:longTitle].location!=NSNotFound && time.toolTip.length>0,"compact unread count and timestamps retain complete information in native tooltips");
            id accessibleBadge=[(NSTextField *)badge cell];
            CheckUI([[accessibleBadge accessibilityAttributeNames] containsObject:NSAccessibilityValueAttribute] && [[accessibleBadge accessibilityAttributeValue:NSAccessibilityValueAttribute] isEqualToString:@"Непрочитанных сообщений: 500"],"native accessibility exposes exact unread count behind compact badge");
            [cell setBackgroundStyle:NSBackgroundStyleDark];
            CheckUI(Contrast(cell.textField.textColor,JMSelectionColor(YES))>=4.5 && Contrast(detail.textColor,JMSelectionColor(YES))>=4.5,"active selected contact text meets 4.5 contrast ratio");
            [cell setBackgroundStyle:NSBackgroundStyleLight];
            CheckUI(Contrast(cell.textField.textColor,JMSelectionColor(NO))>=4.5 && Contrast(detail.textColor,JMSelectionColor(NO))>=4.5,"inactive selected contact and draft text remain readable");
            [cell configureName:@"Контакт" detail:@"В сети" state:@"online" unread:0];
            CheckUI(badge.hidden && time.hidden && Contrast(detail.textColor,[NSColor colorWithCalibratedWhite:0.94 alpha:1])>=4.5,"cell reuse removes old timestamp, unread badge and draft appearance");
            JMContactRowView *row=[[JMContactRowView alloc] initWithFrame:NSMakeRect(0,0,268,60)]; row.selected=YES; row.emphasized=NO;
            CheckUI(row.interiorBackgroundStyle==NSBackgroundStyleLight,"inactive source-list selection uses dark text"); row.emphasized=YES;
            CheckUI(row.interiorBackgroundStyle==NSBackgroundStyleDark,"active source-list selection uses light text on blue");
            [chat setContentSize:NSMakeSize(1000,650)]; client.fixtureConnected=NO;
            JMHistory *visualHistory=[[JMHistory alloc] initWithUIN:@"555" root:root];
            for (NSDictionary *message in @[
                @{@"id":@"visual-1",@"peer":@"666",@"text":@"Привет! Как продвигается JimmMac?",@"timestamp":@1793257200,@"outgoing":@NO},
                @{@"id":@"visual-2",@"peer":@"666",@"text":@"Уже переписываюсь со старого Mac. Проверяю оформление.",@"timestamp":@1793257260,@"outgoing":@YES},
                @{@"id":@"visual-3",@"peer":@"666",@"text":@"Посмотри ссылку: https://jimm.online",@"timestamp":@1793343600,@"outgoing":@NO},
                @{@"id":@"visual-unread-1",@"peer":@"888",@"text":@"Привет!",@"timestamp":@1793343538,@"outgoing":@NO},
                @{@"id":@"visual-unread-2",@"peer":@"888",@"text":@"Я тоже вошла со старого Mac.",@"timestamp":@1793343539,@"outgoing":@NO},
                @{@"id":@"visual-unread-3",@"peer":@"888",@"text":@"Напиши, когда освободишься.",@"timestamp":@1793343540,@"outgoing":@NO}]) [visualHistory appendMessage:message error:NULL];
            [delegate setValue:visualHistory forKey:@"history"];
            {
                id reading=delegate.forcedReading; delegate.forcedReading=@NO;
                FakeNotificationAlerts *legacy=[[FakeNotificationAlerts alloc] initWithDefaults:fontDefaults center:nil]; legacy.legacyIdentifiers=YES; legacy.delegate=(id<JMNotificationAlertsDelegate>)delegate; legacy.accountUIN=@"111"; legacy.enabled=YES;
                [legacy queueMessageFrom:@"222" name:@"Тест A" text:@"Первое"]; [legacy flushPeer:@"222"];
                [legacy queueMessageFrom:@"333" name:@"Тест B" text:@"Второе"]; [legacy flushPeer:@"333"];
                CheckUI(legacy.posted.count==2 && [[legacy.posted lastObject] identifier]==nil,"Mountain Lion notifications work without identifier property and retain separate peers");
                [legacy queueMessageFrom:@"222" name:@"Тест A" text:@"Замена"]; [legacy flushPeer:@"222"];
                CheckUI(legacy.posted.count==2,"Mountain Lion coalescing replaces only matching account and peer");
                [legacy clearPeer:@"222"]; CheckUI(legacy.posted.count==1 && [[[legacy.posted lastObject] userInfo][@"peer"] isEqualToString:@"333"],"Mountain Lion clear-peer preserves other delivered notification");
                [legacy invalidate]; delegate.forcedReading=reading;
            }
 [delegate setValue:@"555" forKey:@"accountUIN"];
            [delegate client:client receivedBuddyList:@{@"groups":@[@{@"name":@"Друзья",@"buddies":@[@{@"aimId":@"666",@"friendly":@"Иван",@"state":@"online"},@{@"aimId":@"777",@"friendly":@"Анна",@"state":@"away"},@{@"aimId":@"888",@"friendly":@"Мария",@"state":@"away"}]}]}];
            [[delegate valueForKey:@"conversationPeers"] addObject:@"888"]; [[delegate valueForKey:@"unread"] setObject:@3 forKey:@"888"];
            [delegate client:client receivedOwnInfo:@{@"friendly":@"Тестовый пользователь",@"state":@"online"}];
            [delegate selectPeer:@"666"]; client.fixtureConnected=YES; [delegate client:client changedStatus:@"Подключено · тестовые данные" connected:YES];
            NSTextView *history=[delegate valueForKey:@"transcript"];
            CheckUI([history.string rangeOfString:@"29 октября 2026"].location!=NSNotFound && [history.string rangeOfString:@"30 октября 2026"].location!=NSNotFound && [history.string componentsSeparatedByString:@"29 октября 2026"].count==2,"history shows one date separator per day");
            CheckUI([history.textStorage attribute:@"JMMessageID" atIndex:0 effectiveRange:NULL]==nil,"date separator cannot be mistaken for a message context action");
            CheckUI(composer.string.length==0 && !send.enabled && [[(JMComposerView *)composer placeholder] length]>0,"composer placeholder is visual and cannot become a sent message");
            NSRange visualLink=[history.string rangeOfString:@"https://jimm.online"];
            CheckUI([history.textStorage attribute:NSLinkAttributeName atIndex:visualLink.location effectiveRange:NULL]!=nil,"date-grouped history preserves clickable links");
            [delegate flushDrafts]; [[delegate valueForKey:@"contactNotice"] setStringValue:@""]; [delegate reloadContacts];
            CGFloat compactFooter=NSMinY([[delegate valueForKey:@"contactTable"] enclosingScrollView].frame);
            [[delegate valueForKey:@"contactNotice"] setStringValue:@"Контакт добавлен"]; [delegate reloadContacts];
            CheckUI(NSMinY([[delegate valueForKey:@"contactTable"] enclosingScrollView].frame)>compactFooter,"roster feedback expands footer only while a message is shown");
            [[delegate valueForKey:@"contactNotice"] setStringValue:@""]; [delegate reloadContacts];
            NSSegmentedControl *tabs=[delegate valueForKey:@"sectionControl"]; [tabs setSelectedSegment:1]; [delegate changeSection:nil];
            JMListCell *unreadCell=(JMListCell *)[[delegate valueForKey:@"contactTable"] viewAtColumn:0 row:1 makeIfNecessary:YES];
            CheckUI(![[unreadCell valueForKey:@"badge"] isHidden] && [[[unreadCell valueForKey:@"badge"] valueForKey:@"text"] isEqualToString:@"3"],"visible conversation row displays unread count alongside last-message preview");
            [history scrollRangeToVisible:NSMakeRange(0,0)]; Capture(chat,[output stringByAppendingPathComponent:@"UI-chat-polished.png"]);
            {
                NSArray *clipboard=PreserveClipboard();
                @try {
                    [chat makeKeyAndOrderFront:nil]; [chat makeFirstResponder:composer]; Draft(delegate,composer,@""); [composer.undoManager removeAllActions];
                    TypeInWindow(chat,@"Проверка клавиатуры"); PumpUI(0.1);
                    KeyInWindow(chat,@"a",NSCommandKeyMask,0);
                    CheckUI(composer.selectedRange.length==composer.string.length,"Cmd+A selects composer text through native menu");
                    KeyInWindow(chat,@"c",NSCommandKeyMask,8);
                    CheckUI([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqualToString:@"Проверка клавиатуры"],"Cmd+C copies real composer selection");
                    [NSPasteboard.generalPasteboard clearContents]; [NSPasteboard.generalPasteboard setString:@"clipboard-fixture" forType:NSPasteboardTypeString];
                    KeyInWindow(chat,@"с",NSCommandKeyMask,8);
                    CheckUI([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqualToString:@"Проверка клавиатуры"],"Cmd+C works with Cyrillic characters on Russian keyboard layout");
                    KeyInWindow(chat,@"x",NSCommandKeyMask,7);
                    CheckUI(composer.string.length==0,"Cmd+X cuts editable text");
                    KeyInWindow(chat,@"v",NSCommandKeyMask,9);
                    CheckUI([composer.string isEqualToString:@"Проверка клавиатуры"],"Cmd+V pastes Unicode text");
                    KeyInWindow(chat,@"z",NSCommandKeyMask,6);
                    CheckUI(composer.string.length==0,"Cmd+Z undoes actual paste");
                    KeyInWindow(chat,@"Z",NSCommandKeyMask|NSShiftKeyMask,6);
                    CheckUI([composer.string isEqualToString:@"Проверка клавиатуры"],"Shift+Cmd+Z redoes actual paste");
                    [composer setSelectedRange:NSMakeRange(composer.string.length,0)];
                    KeyInWindow(chat,@"\t",NSAlternateKeyMask,48);
                    CheckUI([composer.string hasSuffix:@"\t"],"Option+Tab inserts a literal tab when explicitly requested");
                    KeyInWindow(chat,@"\177",0,51);
                    CheckUI(![composer.string hasSuffix:@"\t"],"Delete removes previous character in composer");
                    [delegate selectPeer:@"777"];
                    CheckUI(!composer.undoManager.canUndo && !composer.undoManager.canRedo,"switching peer resets undo and redo so another draft cannot leak");
                    [delegate selectPeer:@"666"]; Draft(delegate,composer,@"Не отправлять"); NSUInteger sends=client.sendCount;
                    KeyInWindow(chat,@"\e",0,53);
                    NSTableView *list=[delegate valueForKey:@"contactTable"];
                    CheckUI(chat.firstResponder==list && [composer.string isEqualToString:@"Не отправлять"] && client.sendCount==sends,"Escape returns composer focus to list without clearing or sending draft");
                    KeyInWindow(chat,@"1",NSCommandKeyMask,18);
                    CheckUI(tabs.selectedSegment==0 && chat.firstResponder==list,"Cmd+1 opens contacts and focuses native list");
                    [list selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                    NSInteger row=list.selectedRow; KeyInWindow(chat,[NSString stringWithFormat:@"%C",(unichar)NSDownArrowFunctionKey],NSFunctionKeyMask,125);
                    CheckUI(list.selectedRow==row+1 && chat.firstResponder==list,"Down arrow selects next contact and keeps keyboard navigation in list");
                    KeyInWindow(chat,[NSString stringWithFormat:@"%C",(unichar)NSUpArrowFunctionKey],NSFunctionKeyMask,126);
                    CheckUI(list.selectedRow==row && chat.firstResponder==list,"Up arrow selects previous contact without stealing focus");
                    KeyInWindow(chat,@"\r",0,36);
                    CheckUI(chat.firstResponder==composer && client.sendCount==sends,"Enter in contact list focuses composer without sending");
                    KeyInWindow(chat,@"\t",0,48);
                    CheckUI(chat.firstResponder!=composer && [composer.string rangeOfString:@"\t"].location==NSNotFound,"Tab navigates out of composer instead of modifying draft");
                    KeyInWindow(chat,@"\t",NSShiftKeyMask,48);
                    CheckUI(chat.firstResponder==composer,"Shift+Tab returns to previous editable element");
                    KeyInWindow(chat,@"l",NSCommandKeyMask,37);
                    NSSearchField *filter=[delegate valueForKey:@"searchField"];
                    CheckUI(chat.firstResponder==filter.currentEditor && [delegate valueForKey:@"accountUIN"]!=nil,"Cmd+L focuses list search and never logs out");
                    TypeInWindow(chat,@"Нет совпадений"); PumpUI(0.1); KeyInWindow(chat,@"\e",0,53);
                    CheckUI(filter.stringValue.length==0 && list.numberOfRows>0,"Escape clears contact filter and restores list");
                    KeyInWindow(chat,@"\e",0,53); CheckUI(chat.firstResponder==list,"second Escape returns search focus to contact list");
                    KeyInWindow(chat,@"2",NSCommandKeyMask,19); CheckUI(tabs.selectedSegment==1,"Cmd+2 switches to conversations");
                    KeyInWindow(chat,@"f",NSCommandKeyMask,3);
                    NSWindow *search=[delegate valueForKey:@"historyWindow"];
                    CheckUI(search.isVisible && search.isKeyWindow,"Cmd+F opens history search with focus");
                    KeyInWindow(search,@"\e",0,53); CheckUI(!search.visible,"Escape closes focused history search");
                    KeyInWindow(chat,@",",NSCommandKeyMask,43); NSWindow *prefs=[delegate valueForKey:@"preferencesWindow"];
                    CheckUI(prefs.visible,"Cmd+comma opens preferences"); KeyInWindow(prefs,@"\e",0,53); CheckUI(!prefs.visible,"Escape closes native preferences panel");
                    [delegate about:nil]; NSWindow *aboutWindow=[[delegate valueForKey:@"aboutController"] window];
                    Capture(aboutWindow,[output stringByAppendingPathComponent:@"UI-about.png"]); KeyInWindow(aboutWindow,@"\e",0,53);
                    CheckUI(!aboutWindow.visible,"Escape closes About window");
                    [delegate showKeyboardHelp:nil]; NSWindow *helpWindow=[[delegate valueForKey:@"keyboardHelpController"] window];
                    Capture(helpWindow,[output stringByAppendingPathComponent:@"UI-keyboard-help.png"]); KeyInWindow(helpWindow,@"w",NSCommandKeyMask,13);
                    CheckUI(!helpWindow.visible,"Cmd+W closes keyboard help through native window menu");
                    // Test fields and panels use only fixture values, never the user's account.
                    NSTextField *loginUIN=[delegate valueForKey:@"uinField"], *password=[delegate valueForKey:@"passwordField"];
                    loginUIN.stringValue=@""; [login makeKeyAndOrderFront:nil]; [login makeFirstResponder:loginUIN]; TypeInWindow(login,@"11114");
                    NSUInteger logins=client.passwordLogins; KeyInWindow(login,@"\r",0,36);
                    CheckUI(login.firstResponder==password.currentEditor && client.passwordLogins==logins,"Enter in UIN field advances to password without attempting login");
                    KeyInWindow(login,@"\t",NSShiftKeyMask,48);
                    CheckUI(login.firstResponder==loginUIN.currentEditor,"Shift+Tab returns from secure password to UIN");
                    KeyInWindow(login,@"a",NSCommandKeyMask,0); KeyInWindow(login,@"c",NSCommandKeyMask,8);
                    CheckUI([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqualToString:@"11114"],"login UIN supports native select-all and copy");
                    [login makeFirstResponder:password]; KeyInWindow(login,@"v",NSCommandKeyMask,9);
                    CheckUI([[password.currentEditor string] isEqualToString:@"11114"],"secure password field accepts native paste");
                    [login makeFirstResponder:nil]; password.stringValue=@""; loginUIN.stringValue=@""; [login orderOut:nil];
                    JMOwnProfileController *profile=[[JMOwnProfileController alloc] initWithClient:client avatars:[delegate valueForKey:@"avatars"] account:@"111"];
                    [profile showWindow:nil]; [profile loadProfile:nil]; PumpUI(0.2);
                    NSTextField *firstName=[profile valueForKey:@"firstNameField"]; NSTextView *bio=[profile valueForKey:@"about"];
                    [profile.window makeFirstResponder:firstName]; KeyInWindow(profile.window,@"a",NSCommandKeyMask,0); KeyInWindow(profile.window,@"v",NSCommandKeyMask,9);
                    [profile.window makeFirstResponder:bio]; TypeInWindow(profile.window,@"Тест клавиатуры");
                    [bio setMarkedText:@"文" selectedRange:NSMakeRange(1,0) replacementRange:NSMakeRange(bio.string.length,0)];
                    NSEvent *imeEscape=[NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:profile.window.windowNumber context:nil characters:@"\e" charactersIgnoringModifiers:@"\e" isARepeat:NO keyCode:53];
                    CheckUI(![profile.window performKeyEquivalent:imeEscape] && profile.window.visible,"Escape is left to input method before profile close button while text is marked"); [bio unmarkText];
                    KeyInWindow(profile.window,@"\t",0,48);
                    CheckUI(profile.window.firstResponder!=bio && [bio.string rangeOfString:@"\t"].location==NSNotFound,"Tab navigates out of multiline profile without adding invisible tab");
                    NSUInteger writes=client.ownCalls.count; KeyInWindow(profile.window,@"ы",NSCommandKeyMask,1); PumpUI(0.3);
                    CheckUI(client.ownCalls.count>writes && ![[profile valueForKey:@"saveButton"] isEnabled],"Cmd+S button shortcut works with Cyrillic layout and confirms profile read-back");
                    KeyInWindow(profile.window,@"\e",0,53); CheckUI(!profile.window.visible,"Escape closes saved profile without dropping edits"); [profile invalidate];
                    [delegate selectPeer:@"666"]; [chat makeKeyAndOrderFront:nil]; [chat makeFirstResponder:linkedTranscript];
                    [linkedTranscript setSelectedRange:NSMakeRange(0,MIN((NSUInteger)10,linkedTranscript.string.length))]; NSString *transcriptCopy=[linkedTranscript.string substringWithRange:linkedTranscript.selectedRange];
                    NSRange beforeArrival=linkedTranscript.selectedRange;
                    [delegate client:client receivedMessage:@{@"id":@"keyboard-copy-arrival",@"peer":@"666",@"text":@"Фиктивное обновление во время выделения",@"timestamp":@1793344000,@"outgoing":@NO}];
                    CheckUI(NSEqualRanges(beforeArrival,linkedTranscript.selectedRange),"automatic incoming message preserves copy selection in existing text");
                    KeyInWindow(chat,@"c",NSCommandKeyMask,8);
                    CheckUI([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqualToString:transcriptCopy],"Cmd+C copies selection from read-only transcript");
                    [delegate openTelegraphica:nil]; CheckUI([delegate.openedURL isEqual:JMTelegraphicaURL()] && [delegate.openedURL.absoluteString isEqualToString:@"https://github.com/MiChiRose/telegraphica"],"Telegraphica action opens verified public project URL, never private sources");
                    [delegate selectPeer:@"666"]; Draft(delegate,composer,@""); [delegate selectPeer:@"777"]; Draft(delegate,composer,@"");
                } @finally { RestoreClipboard(clipboard); }
            }
            // 0.13: isolated durable history, bounded pages and local display preferences.
            JMHistory *daily=[[JMHistory alloc] initWithUIN:@"12345" root:root];
            for (NSUInteger i=0;i<450;i++) [daily appendMessage:@{@"peer":@"666",@"id":[NSString stringWithFormat:@"page-%03lu",(unsigned long)i],@"text":[NSString stringWithFormat:@"Сообщение %lu :)",(unsigned long)i],@"timestamp":@(1793340000+i),@"outgoing":@NO} unread:i>=120 error:NULL];
            [delegate setValue:daily forKey:@"history"]; [delegate setValue:@"12345" forKey:@"accountUIN"]; [delegate setValue:nil forKey:@"selectedPeer"]; [delegate restoreDraftsForUIN:@"12345"];
            [[delegate valueForKey:@"unread"] removeAllObjects]; [[delegate valueForKey:@"unread"] addEntriesFromDictionary:daily.unreadCounts];
            [[delegate valueForKey:@"favoritePeers"] removeAllObjects];
            [delegate client:client receivedBuddyList:@{@"groups":@[@{@"name":@"Тест",@"buddies":@[@{@"aimId":@"666",@"friendly":@"Анна",@"state":@"online"},@{@"aimId":@"777",@"friendly":@"Борис",@"state":@"offline"},@{@"aimId":@"888",@"friendly":@"Вера",@"state":@"away"}]}]}];
            [sections setSelectedSegment:0]; [delegate changeSection:nil];
            delegate.forcedReading=@YES; client.fixtureConnected=YES; [chat makeKeyAndOrderFront:nil]; [delegate selectPeer:@"666"];
            CheckUI([[delegate valueForKey:@"transcriptRanges"] count]==200 && [[delegate valueForKey:@"transcriptOffset"] unsignedIntegerValue]==80,"first unread opens correct bounded page instead of rendering 450 messages");
            CheckUI([daily.unreadCounts[@"666"] integerValue]==330 && [linkedTranscript.string rangeOfString:@"Непрочитанные"].location!=NSNotFound,"opening first unread does not clear unseen later messages");
            CheckUI([[delegate valueForKey:@"olderMessagesButton"] isEnabled] && [[delegate valueForKey:@"newerMessagesButton"] isEnabled],"history page controls expose earlier and later ranges");
            [delegate loadEarlierMessages:nil]; CheckUI([[delegate valueForKey:@"transcriptOffset"] unsignedIntegerValue]==0 && [[delegate valueForKey:@"transcriptRanges"] count]==200,"earlier page stays bounded");
            [delegate loadNewerMessages:nil]; CheckUI([[delegate valueForKey:@"transcriptOffset"] unsignedIntegerValue]==200,"later page advances without loading entire transcript");
            [linkedTranscript setSelectedRange:NSMakeRange(0,10)]; [delegate jumpToLatest:nil]; CheckUI([[delegate valueForKey:@"transcriptOffset"] unsignedIntegerValue]==250 && !daily.unreadCounts.count,"jump to latest loads tail and persists read flags");
            NSMenuItem *favoriteItem=[[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleFavorite:) keyEquivalent:@""]; favoriteItem.representedObject=@"777";
            [delegate toggleFavorite:favoriteItem]; [delegate reloadContacts];
            CheckUI([[[delegate valueForKey:@"visibleContacts"] firstObject][@"aimId"] isEqual:@"777"] && [[testAlertDefaults arrayForKey:@"FavoritePeers.12345"] containsObject:@"777"],"favorite sorts first and persists per account even while offline");
            [delegate toggleFavoritesFilter:nil]; CheckUI([[delegate valueForKey:@"visibleContacts"] count]==1,"favorites filter shows only selected local favorite");
            [delegate toggleOnlineFilter:nil]; CheckUI([[delegate valueForKey:@"visibleContacts"] count]==0 && [[[delegate valueForKey:@"emptyListLabel"] stringValue] rangeOfString:@"фильтрам"].location!=NSNotFound,"combined filters explain an empty result");
            [delegate toggleFavoritesFilter:nil]; CheckUI([[delegate valueForKey:@"visibleContacts"] count]==2,"online filter includes away and excludes offline"); [delegate toggleOnlineFilter:nil];
            [delegate setTranscriptAroundID:@"page-010"]; [delegate renderTranscript]; CheckUI([delegate valueForKey:@"transcriptRanges"][@"page-010"]!=nil,"indexed jump can reveal a message outside loaded tail");
            [delegate toggleEmoticons:nil]; // Restore plain text first, regardless of previous visual preference.
            if (fontPreferences.emoticonsEnabled) [delegate toggleEmoticons:nil];
            CheckUI([linkedTranscript.string rangeOfString:@":)"].location!=NSNotFound,"disabled emoticons show original text");
            [delegate toggleEmoticons:nil];
            __block BOOL foundAttachment=NO;
            [linkedTranscript.textStorage enumerateAttribute:@"JMSmileyText" inRange:NSMakeRange(0,linkedTranscript.string.length) options:0 usingBlock:^(id value,NSRange range,BOOL *stop) { if (value) foundAttachment=YES; }];
            CheckUI(foundAttachment && fontPreferences.emoticonsEnabled,"enabled classic smileys use native inline image attachments");
            NSArray *savedBoard=PreserveClipboard();
            @try { [linkedTranscript setSelectedRange:NSMakeRange(0,linkedTranscript.string.length)]; [linkedTranscript copy:nil]; NSString *copied=[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString]; CheckUI([copied rangeOfString:@":)"].location!=NSNotFound && [copied rangeOfString:@"\uFFFC"].location==NSNotFound,"copying rendered smileys restores original text"); } @finally { RestoreClipboard(savedBoard); }
            [linkedTranscript setSelectedRange:NSMakeRange(0,0)];
            Capture(chat,[output stringByAppendingPathComponent:@"UI-daily-history.png"]);
            [chat setContentSize:NSMakeSize(860,560)];
            for (NSString *key in @[@"onlineOnlyCheckbox",@"favoritesOnlyCheckbox",@"olderMessagesButton",@"newerMessagesButton",@"historyPageLabel"]) { NSView *view=[delegate valueForKey:key]; CheckUI(NSContainsRect(view.superview.bounds,view.frame),"new filter and page controls fit smallest window"); }
            [delegate selectPeer:@"666"]; Draft(delegate,composer,@"Новая отправка :)"); NSUInteger sendsBefore=client.sendCount; [delegate send:nil];
            NSString *localID=[delegate valueForKey:@"sendingLocalID"];
            CheckUI(client.sendCount==sendsBefore+1 && [[[daily messageWithID:localID peer:@"666"] objectForKey:@"delivery"] isEqual:@"pending"],"message is stored with sending state before network confirmation");
            FinishSend(client,nil,[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]);
            CheckUI([[[daily messageWithID:localID peer:@"666"] objectForKey:@"delivery"] isEqual:@"unknown"] && client.sendCount==sendsBefore+1,"ambiguous network failure becomes unknown and is never automatically resent");
            NSDictionary *unknown=[daily messageWithID:localID peer:@"666"];
            Draft(delegate,composer,@"Другой черновик"); [delegate transmitRecord:unknown clearsDraft:NO];
            CheckUI([[[delegate draftSnapshot] objectForKey:@"666"] isEqual:@"Другой черновик"],"manual retry never prepends old outgoing text to independent persisted draft");
            FinishSend(client,@"retry-confirmed",nil);
            CheckUI([composer.string isEqual:@"Другой черновик"] && [daily messageWithID:localID peer:@"666"]==nil && [[[daily messageWithID:@"retry-confirmed" peer:@"666"] objectForKey:@"delivery"] isEqual:@"accepted"],"explicit retry reconciles message and keeps independently typed draft");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-daily-send-state.png"]);
            [delegate showPreferences:nil]; NSString *previousFamily=fontPreferences.family; CGFloat previousSize=fontPreferences.size;
            [fontPreferences setFamily:@"" size:28]; [delegate applyChatFont];
            NSTextField *largePreview=[delegate valueForKey:@"fontPreview"]; NSButton *smileSetting=[delegate valueForKey:@"emoticonsCheckbox"];
            CheckUI(NSHeight(largePreview.frame)>=40 && !NSIntersectsRect(largePreview.frame,smileSetting.frame),"largest font preview and smiley preference have separate readable areas");
            Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:@"UI-daily-preferences.png"]);
            [fontPreferences setFamily:previousFamily size:previousSize]; [delegate applyChatFont]; [delegate closePreferences:nil];
            UIUpdateChecker *updates=[[UIUpdateChecker alloc] init]; updates.releaseInfo=@{@"version":@"0.17.0",@"url":[NSURL URLWithString:@"https://github.com/MiChiRose/JimmMac/releases/tag/v0.17.0"],@"notes":@"Fixture release"};
            [delegate setValue:updates forKey:@"updateChecker"]; delegate.allowUpdatePresentation=@NO;
            [testAlertDefaults removeObjectForKey:@"UpdateNoticeShownVersion"]; [testAlertDefaults removeObjectForKey:@"LastSuccessfulUpdateCheck"];
            [delegate checkUpdatesAutomatically:YES]; PumpUI(0.05);
            CheckUI(updates.checks==1 && delegate.automaticUpdateNotices==0 && [delegate valueForKey:@"pendingUpdateRelease"]!=nil,"automatic update defers popup while login, sheet or auxiliary window has focus");
            delegate.allowUpdatePresentation=@YES; [delegate presentPendingUpdateIfPossible]; PumpUI(0.05);
            CheckUI(delegate.automaticUpdateNotices==1 && [delegate.presentedUpdateVersion isEqual:@"0.17.0"],"available update opens automatically when main conversation is ready");
            [delegate presentPendingUpdateIfPossible]; [delegate automaticUpdateTick:nil]; PumpUI(0.05);
            CheckUI(delegate.automaticUpdateNotices==1 && updates.checks==1,"same update is shown once and network is not polled again within six hours");
            [testAlertDefaults setObject:[NSDate dateWithTimeIntervalSinceNow:-7*3600] forKey:@"LastSuccessfulUpdateCheck"]; updates.releaseInfo=@{@"version":@"0.13.0"}; [delegate automaticUpdateTick:nil]; PumpUI(0.05);
            CheckUI(updates.checks==2 && delegate.automaticUpdateNotices==1,"automatic check for current version remains silent");
            [testAlertDefaults setObject:[NSDate dateWithTimeIntervalSinceNow:-7*3600] forKey:@"LastSuccessfulUpdateCheck"]; updates.error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]; updates.releaseInfo=nil;
            NSString *previousError=delegate.lastError; [delegate automaticUpdateTick:nil]; [delegate automaticUpdateTick:nil]; PumpUI(0.05);
            CheckUI(updates.checks==3 && delegate.lastError==previousError && delegate.automaticUpdateNotices==1,"automatic network failure stays silent and applies retry delay");
            [delegate toggleAutomaticUpdates:nil]; [delegate setValue:nil forKey:@"updateRetryDate"]; [delegate automaticUpdateTick:nil];
            CheckUI(updates.checks==3 && ![testAlertDefaults boolForKey:@"AutomaticallyCheckUpdates"],"automatic update menu setting disables background checks");


            // Offline access, conversation mute and all three presentations share one account.
            [delegate client:client receivedOwnInfo:@{@"friendly":@"Мария",@"state":@"online",@"statusMsg":@"На связи с друзьями"}];
            [delegate selectPeer:@"666"]; Draft(delegate,composer,@"Черновик для трёх оформлений");
            NSMenuItem *muteItem=[[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleMuteConversation:) keyEquivalent:@""]; muteItem.representedObject=@"666";
            [delegate toggleMuteConversation:muteItem];
            CheckUI([[testAlertDefaults arrayForKey:@"MutedPeers.12345"] containsObject:@"666"],"muted conversation persists per account");
            delegate.forcedReading=@NO; [delegate selectPeer:@"777"];
            SilentAudioAlerts *muteAudio=[delegate valueForKey:@"audioAlerts"]; NSUInteger beforeMuteEvents=muteAudio.events.count;
            [delegate client:client receivedMessage:Incoming(@"muted-fixture",@"666",@"Тихое сообщение")];
            CheckUI(muteAudio.events.count==beforeMuteEvents && ![delegate notificationAlerts:[delegate valueForKey:@"notificationAlerts"] shouldNotifyPeer:@"666"],"muted conversation suppresses sound and banner eligibility");
            CheckUI([daily.unreadCounts[@"666"] integerValue]>0,"muting keeps incoming message and unread state");
            [delegate selectPeer:@"666"]; Draft(delegate,composer,@"Черновик для трёх оформлений");
            for (NSString *theme in @[@"mac2011",@"pro2003",@"current"]) {
                NSMenuItem *choice=[[NSMenuItem alloc] initWithTitle:@"" action:@selector(changeAppearance:) keyEquivalent:@""]; choice.representedObject=theme; [delegate changeAppearance:choice];
                NSWindow *roster=[delegate valueForKey:@"rosterWindow"]; BOOL historic=![theme isEqual:@"current"];
                CheckUI([JMThemeIdentifier() isEqual:theme] && [composer.string isEqual:@"Черновик для трёх оформлений"],"theme switch preserves active account draft");
                CheckUI([delegate valueForKey:@"contactTable"]!=nil && [(NSView *)[delegate valueForKey:@"contactTable"] window]==(historic ? roster : chat),"same native contact table is reparented to correct window");
                [chat setContentSize:chat.contentMinSize];
                if (historic) [roster setContentSize:roster.contentMinSize];
                NSView *pane=[delegate valueForKey:@"chatPane"];
                for (NSString *key in @[@"composer",@"sendButton",@"profileButton",@"historySearchButton",@"peerLabel",@"peerDetail"]) {
                    NSView *view=[delegate valueForKey:key]; NSRect frame=[pane convertRect:view.bounds fromView:view];
                    CheckUI(NSContainsRect(pane.bounds,frame),"conversation controls fit minimum themed window");
                }
                NSView *side=[delegate valueForKey:@"sidebar"];
                CheckUI(NSContainsRect(sections.superview.bounds,sections.frame),"all contact and conversation tab labels fit historical roster");
                (void)side;
                if (historic) {
                    for (NSString *key in @[@"themeSmileyButton",@"themeFontButton",@"themeCloseButton",@"themeComposerCount",@"themeConversationTabs",@"themeConversationPicker"]) { NSView *view=[delegate valueForKey:key]; if (!view.isHidden) CheckUI(NSContainsRect(pane.bounds,view.frame),"historical controls fit minimum chat size"); }
                    CheckUI(!NSIntersectsRect([[delegate valueForKey:@"themeSmileyButton"] frame],composer.enclosingScrollView.frame),"smiley button is separate from editable text area");
                    NSBitmapImageRep *buttonPixels=[send bitmapImageRepForCachingDisplayInRect:send.bounds]; [send cacheDisplayInRect:send.bounds toBitmapImageRep:buttonPixels];
                    NSColor *buttonTop=[[buttonPixels colorAtX:7 y:3] colorUsingColorSpaceName:NSCalibratedRGBColorSpace], *buttonBottom=[[buttonPixels colorAtX:7 y:buttonPixels.pixelsHigh-4] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
                    CGFloat topLight=buttonTop.redComponent+buttonTop.greenComponent+buttonTop.blueComponent, bottomLight=buttonBottom.redComponent+buttonBottom.greenComponent+buttonBottom.blueComponent;
                    CheckUI(topLight>bottomLight+0.06,"reference button highlight is above its shadow in AppKit flipped coordinates");
                    if ([theme isEqual:@"pro2003"]) {
                        NSTextField *number=[delegate valueForKey:@"themeUINValue"], *nick=[delegate valueForKey:@"themeNickValue"], *numberTitle=[delegate valueForKey:@"themeUINTitle"];
                        CheckUI([number.stringValue isEqual:@"666"] && !number.isEditable && number.isSelectable && [nick.stringValue isEqual:@"Анна"],"classic recipient fields expose real selectable read-only values");
                        CheckUI(NSWidth(numberTitle.frame)>=[numberTitle.cell cellSize].width && !NSIntersectsRect(number.frame,nick.frame),"ICQ label and sunken recipient fields fit without clipping or overlap");
                        NSArray *saved=PreserveClipboard();
                        @try { [chat makeFirstResponder:number]; [number selectText:nil]; KeyInWindow(chat,@"c",NSCommandKeyMask,8); CheckUI([[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqual:@"666"],"Cmd+C copies the full UIN from classic recipient field"); } @finally { RestoreClipboard(saved); }
                        [chat makeFirstResponder:composer];
                        JMChatPreferences *preferences=[delegate valueForKey:@"chatPreferences"]; CGFloat oldSize=preferences.size; NSMenuItem *size=[[NSMenuItem alloc] init]; size.representedObject=@16; [delegate changeClassicFontSize:size];
                        CheckUI(preferences.size==16 && composer.font.pointSize==16 && [composer.string isEqual:@"Черновик для трёх оформлений"],"classic font menu changes real font without altering draft"); size.representedObject=@(oldSize); [delegate changeClassicFontSize:size];
                    }
                    NSMenuItem *smiley=[[NSMenuItem alloc] initWithTitle:@":)" action:@selector(insertClassicSmiley:) keyEquivalent:@""]; smiley.representedObject=@":)";
                    [composer.undoManager removeAllActions]; [delegate insertClassicSmiley:smiley];
                    CheckUI([composer.string hasSuffix:@":)"] && composer.undoManager.canUndo,"classic smiley action inserts editable text with native undo");
                    [app sendAction:@selector(undo:) to:nil from:nil]; CheckUI([composer.string isEqual:@"Черновик для трёх оформлений"],"native Cmd+Z restores draft after themed smiley insertion");
                    if ([theme isEqual:@"mac2011"]) {
                        NSMenu *groups=[delegate valueForKey:@"themeGroupMenu"]; NSMenuItem *chosen=nil; for (NSMenuItem *item in groups.itemArray) if ([item.representedObject isEqual:@"Тест"]) chosen=item;
                        CheckUI(chosen!=nil,"Mac 2011 compact menu exposes actual server contact groups"); [app sendAction:chosen.action to:chosen.target from:chosen];
                        CheckUI([[delegate valueForKey:@"selectedGroup"] isEqual:@"Тест"] && [composer.string isEqual:@"Черновик для трёх оформлений"],"compact group menu filters contacts without changing draft"); NSMenuItem *all=[groups itemAtIndex:0]; [app sendAction:all.action to:all.target from:all];
                        NSSegmentedControl *tabs=[delegate valueForKey:@"themeConversationTabs"]; NSArray *tabPeers=[delegate valueForKey:@"themeTabPeers"]; NSUInteger index=[tabPeers indexOfObject:@"777"];
                        CheckUI(index!=NSNotFound && tabs.segmentCount==3,"Mac 2011 tabs expose actual open conversations");
                        [tabs setSelectedSegment:index]; [app sendAction:tabs.action to:tabs.target from:tabs];
                        CheckUI([[delegate valueForKey:@"selectedPeer"] isEqual:@"777"],"Mac 2011 conversation tab opens its actual peer"); [delegate selectPeer:@"666"];
                        [chat setContentSize:NSMakeSize(680,560)]; [chat setContentSize:chat.contentMinSize];
                        CheckUI([linkedTranscript.textStorage attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL]!=nil && [composer.string isEqual:@"Черновик для трёх оформлений"],"resizing the Mac 2011 message blocks preserves editable draft");
                    } else {
                        NSButton *close=[delegate valueForKey:@"themeCloseButton"]; [chat makeFirstResponder:close]; KeyInWindow(chat,@" ",0,49);
                        CheckUI(!chat.isVisible && [composer.string isEqual:@"Черновик для трёх оформлений"],"Space activates skinned Close button and preserves draft"); [delegate selectPeer:@"666"];
                        NSView *latest=[delegate valueForKey:@"latestMessagesButton"];
                        CheckUI(!NSIntersectsRect(latest.frame,composer.enclosingScrollView.frame),"classic new-message action does not cover input field");
                    }
                }
                NSView *next=[delegate valueForKey:@"presencePopup"];
                for (NSUInteger j=0;j<20 && next;j++,next=next.nextKeyView) CheckUI(next.window==(historic ? roster : chat),"Tab loop stays within the roster window");
                if (historic) {
                    [chat makeKeyAndOrderFront:nil]; [chat makeFirstResponder:composer]; [delegate handleEscapeInWindow:chat];
                    CheckUI(roster.isKeyWindow && roster.firstResponder==[delegate valueForKey:@"contactTable"],"Escape from historic chat focuses roster without losing draft");
                    Capture(roster,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-%@-contacts.png",theme]]);
                }
                NSClipView *themeClip=linkedTranscript.enclosingScrollView.contentView; NSPoint themeOrigin=linkedTranscript.textContainerOrigin;
                NSRange visibleGlyphs=[linkedTranscript.layoutManager glyphRangeForBoundingRect:NSOffsetRect(themeClip.bounds,-themeOrigin.x,-themeOrigin.y) inTextContainer:linkedTranscript.textContainer];
                CheckUI(visibleGlyphs.length>0,"resizing and switching themes keeps actual message glyphs in the viewport");
                Capture(chat,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-%@-conversation.png",theme]]);
            }
            [delegate flushDrafts]; client.fixtureConnected=NO; FakeLoginStore *offlineLogin=[delegate valueForKey:@"loginStore"]; NSUInteger offlineReads=offlineLogin.reads, offlineRemovals=offlineLogin.removals;
            CheckUI([delegate openOfflineUIN:@"12345"],"offline session opens local account without authentication");
            CheckUI(offlineLogin.reads==offlineReads && offlineLogin.removals==offlineRemovals,"offline access neither reads nor removes saved credentials");
            CheckUI([[[delegate valueForKey:@"contacts"] objectForKey:@"666"][@"friendly"] isEqual:@"Анна"] && [[[delegate valueForKey:@"contacts"] objectForKey:@"666"][@"state"] isEqual:@"offline"],"offline roster retains names while clearly showing stale presence as offline");
            [delegate selectPeer:@"666"];
            CheckUI(composer.isEditable && !send.isEnabled && [composer.string isEqual:@"Черновик для трёх оформлений"],"offline history restores editable draft while blocking transmission");
            CheckUI([[delegate valueForKey:@"mutedPeers"] containsObject:@"666"] && [[delegate valueForKey:@"transcriptRanges"] count]>0,"offline session restores mute preference and message pages");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-offline.png"]);
            [delegate toggleMuteConversation:muteItem];
            CheckUI(![[testAlertDefaults arrayForKey:@"MutedPeers.12345"] containsObject:@"666"],"unmute is available while offline");
            NSURL *portableRoot=[root URLByAppendingPathComponent:@"portable-source"];
            JMHistory *portable=[[JMHistory alloc] initWithUIN:@"12345" root:portableRoot];
            [portable appendMessage:Incoming(@"restored-fixture",@"888",@"Перенесённое сообщение") error:NULL];
            NSDictionary *portableManifest=@{@"format":@"JimmMacBackup",@"version":@1,@"uin":@"12345",@"drafts":@{@"666":@"Черновик с другого Mac"},@"roster":@{@"uin":@"12345",@"contacts":@{@"888":@{@"friendly":@"Вера из копии"}},@"serverIDs":@[@"888"],@"groups":@[@"Restored"]},@"preferences":@{@"MutedPeers":@[@"888"],@"SoundsEnabled":@NO,@"ChatFontSize":@14,@"InterfaceAppearance":@"pro2003"}};
            NSURL *portableURL=[root URLByAppendingPathComponent:@"UI-fixture.jimmbackup"];
            CheckUI([portable writeBackupToURL:portableURL manifest:portableManifest error:NULL],"UI fixture creates portable backup from separate account storage");
            [delegate restoreBackupURL:portableURL manifest:[JMHistory backupManifestAtURL:portableURL error:NULL]];
            CheckUI(!composer.isEditable && [[delegate valueForKey:@"dataOperationInProgress"] boolValue],"restoration freezes editor until account data is applied");
            dispatch_sync((dispatch_queue_t)[delegate valueForKey:@"historySearchQueue"],^{}); PumpUI(0.2);
            [delegate selectPeer:@"666"];
            CheckUI([composer.string rangeOfString:@"Черновик для трёх оформлений"].location!=NSNotFound && [composer.string rangeOfString:@"Черновик с другого Mac"].location!=NSNotFound,"restore retains both differing drafts without losing local text");
            CheckUI([[(JMHistory *)[delegate valueForKey:@"history"] messageWithID:@"restored-fixture" peer:@"888"] count]>0 && [[delegate valueForKey:@"contacts"] objectForKey:@"666"]!=nil,"restoration merges history and cached contacts into existing account");
            CheckUI(![(JMAudioAlerts *)[delegate valueForKey:@"audioAlerts"] enabled] && [[delegate valueForKey:@"mutedPeers"] containsObject:@"888"] && JMTheme()==JMThemePro2003,"restored notification and appearance preferences take effect immediately");
            CheckUI(![[delegate valueForKey:@"dataOperationInProgress"] boolValue] && composer.isEditable && !send.isEnabled,"restoration ends in usable offline draft mode");
            NSMenuItem *restoreCurrent=[[NSMenuItem alloc] initWithTitle:@"" action:@selector(changeAppearance:) keyEquivalent:@""]; restoreCurrent.representedObject=@"current"; [delegate changeAppearance:restoreCurrent];

            JMSetLanguage(@"en");
            CheckUI([JML(@"Ностальгия · ICQ для Mac 2011") isEqual:@"Nostalgia · ICQ for Mac 2011"],"English localization includes historical appearance names");
            [testAlertDefaults setObject:@"en" forKey:@"InterfaceLanguage"];
            SmokeDelegate *english=[[SmokeDelegate alloc] init]; [english applicationDidFinishLaunching:nil];
            NSWindow *englishLogin=[english valueForKey:@"loginWindow"];
            CheckUI([[[english valueForKey:@"loginButton"] title] isEqual:@"Sign In"] || [[[english valueForKey:@"loginButton"] title] isEqual:@"Sign in"],"English launch translates sign-in button");
            NSSegmentedControl *englishSections=[english valueForKey:@"sectionControl"];
            CheckUI([[englishSections labelForSegment:0] isEqual:@"Contacts"] && [[englishSections labelForSegment:1] isEqual:@"Conversations"],"English launch translates both main tabs");
            Capture(englishLogin,[output stringByAppendingPathComponent:@"UI-English-login.png"]);
            CheckUI([english openOfflineUIN:@"12345"],"English launch can open existing offline history"); [english selectPeer:@"666"];
            NSWindow *englishChat=[english valueForKey:@"chatWindow"]; [englishChat setContentSize:NSMakeSize(860,560)];
            CheckUI(NSWidth(englishSections.frame)>=[[englishSections cell] cellSize].width,"English tab labels fit the smallest window");
            Capture(englishChat,[output stringByAppendingPathComponent:@"UI-English-offline.png"]);
            for (NSString *mode in @[@"pro2003",@"mac2011"]) {
                NSMenuItem *item=[[NSMenuItem alloc] init]; item.representedObject=mode; [english changeAppearance:item]; [englishChat setContentSize:englishChat.contentMinSize];
                if ([mode isEqual:@"pro2003"]) { NSTextField *nick=[english valueForKey:@"themeNickTitle"]; CheckUI([nick.stringValue isEqual:@"Nick:"] && NSWidth(nick.frame)>=[nick.cell cellSize].width,"English classic nickname label fits without truncating First name"); }
                Capture(englishChat,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-English-%@.png",mode]]);
            }
            ImprovementEnglishUI(english,output);
            NSMenuItem *back=[[NSMenuItem alloc] init]; back.representedObject=@"current"; [english changeAppearance:back]; [[english valueForKey:@"rosterWindow"] orderOut:nil];
            [englishLogin orderOut:nil]; [[english valueForKey:@"chatWindow"] orderOut:nil];
            for (NSString *language in @[@"uk",@"be"]) {
                [testAlertDefaults setObject:language forKey:@"InterfaceLanguage"];
                SmokeDelegate *localized=[[SmokeDelegate alloc] init]; [localized applicationDidFinishLaunching:nil];
                CheckUI([JMLanguage() isEqual:language],"launch restores the selected Cyrillic language");
                NSWindow *login=[localized valueForKey:@"loginWindow"];
                CheckUI([[[localized valueForKey:@"loginButton"] title] isEqual:([language isEqual:@"uk"] ? @"Увійти" : @"Увайсці")],"login uses the selected Cyrillic language");
                CheckUtilityBounds(login);
                Capture(login,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-016-%@-login.png",language]]);
                [localized showPreferences:nil]; NSSegmentedControl *sections=[localized valueForKey:@"preferenceSections"];
                for (NSInteger i=0;i<5;i++) { sections.selectedSegment=i; [localized changePreferenceSection:nil]; CheckUtilityBounds([localized valueForKey:@"preferencesWindow"]); }
                [localized closePreferences:nil]; [login orderOut:nil];
            }
            JMSetLanguage(@"ru"); [testAlertDefaults setObject:@"ru" forKey:@"InterfaceLanguage"]; [app setDelegate:delegate];

            ImprovementUI(delegate,output); RetroUpgradeUI(delegate,output); ConversationNavigationUI(delegate,output);
            [delegate selectPeer:@"777"]; [chat setContentSize:NSMakeSize(860,560)];
            emptyView=[delegate valueForKey:@"conversationEmptyView"]; emptyFits=YES;
            for (NSView *view in emptyView.subviews) if (!view.hidden && !NSContainsRect(emptyView.bounds,view.frame)) emptyFits=NO;
            CheckUI(!emptyView.hidden && emptyView.writeButton.hidden && emptyFits,"new peer empty state fits the smallest window and points to composer");
            Capture(chat,[output stringByAppendingPathComponent:@"UI-peer-empty.png"]); [delegate logout:nil]; LoginQueue(delegate);
        }
        NSAlert *prompt = [delegate newConversationPrompt];
        PromptFixture *promptFixture = [[PromptFixture alloc] init]; promptFixture.alert = prompt;
        NSTimer *timer = [NSTimer timerWithTimeInterval:0.1 target:promptFixture selector:@selector(edit:) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
        CheckUI([prompt.buttons[1] keyEquivalent].length>0,"Russian cancel button has explicit Escape independent of OS language");
        CheckUI([prompt runModal]==NSAlertSecondButtonReturn,"Escape cancels native conversation prompt");
        [[prompt window] orderOut:nil];
        NSAlert *addDialog=[delegate newAddContactPrompt]; promptFixture.alert=addDialog; promptFixture.snapshotPath=[output stringByAppendingPathComponent:@"UI-add-contact.png"];
        CheckUI([addDialog.accessoryView viewWithTag:102]!=nil,"add contact dialog includes server group chooser");
        timer=[NSTimer timerWithTimeInterval:0.1 target:promptFixture selector:@selector(edit:) userInfo:nil repeats:NO]; [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
        CheckUI([addDialog runModal]==NSAlertSecondButtonReturn,"Escape cancels native add-contact prompt"); [addDialog.window orderOut:nil];
        dispatch_semaphore_t exportGate=dispatch_semaphore_create(0); __block BOOL exportFinished=NO;
        dispatch_async((dispatch_queue_t)[delegate valueForKey:@"historySearchQueue"],^{ dispatch_semaphore_wait(exportGate,DISPATCH_TIME_FOREVER); exportFinished=YES; });
        CheckUI([delegate applicationShouldTerminate:app]==NSTerminateLater,"Cmd+Q waits asynchronously for queued export work"); PumpUI(0.1);
        CheckUI(delegate.terminationReplies==0,"application does not exit while an export is still writing");
        dispatch_semaphore_signal(exportGate); LoginQueue(delegate); PumpUI(0.2);
        CheckUI(exportFinished && delegate.terminationReplies==1,"application completes termination after export and credentials finish");
        [[NSFileManager defaultManager] removeItemAtURL:root error:NULL];
        [fontDefaults removePersistentDomainForName:suite]; [fontDefaults synchronize];
        [chat orderOut:nil];
        printf("PASS: %lu UI checks: layout, tooltips, text entry, scrolling, automatic rendering, background unread, sound decoding and throttling\n",(unsigned long)uiChecks);
    }
    return 0;
}
