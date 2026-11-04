#import "JMAppDelegate.h"
#import "JMProtocol.h"
#import "JMHistory.h"
#import "JMStyle.h"
#import "JMAvatarStore.h"
#import "JMAudioAlerts.h"
#import "JMTextTools.h"
#import "JMChatPreferences.h"
#import "JMNotificationAlerts.h"
#import "JMOwnProfileController.h"
#import "JMDraftStore.h"
#import "JMLoginStore.h"
#import "JMKeyboard.h"
#import "JMInformationController.h"
#import "JMUpdateChecker.h"
#import "JMEmoticons.h"
#import "JMAccountData.h"
#import "JMTheme.h"
#import "JMLocalization.h"
#import <float.h>
#import "JMDiagnostics.h"
#import "JMAutoAway.h"
#import <ApplicationServices/ApplicationServices.h>

@interface JMWindowView : NSView
@end
@implementation JMWindowView
- (void)drawRect:(NSRect)dirtyRect { [JMThemeBackground() setFill]; NSRectFill(dirtyRect); }
@end

static NSTextField *JMLabel(NSString *text, NSRect frame, CGFloat size, BOOL bold) {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    [label setStringValue:text]; [label setEditable:NO]; [label setSelectable:NO];
    [label setBordered:NO]; [label setDrawsBackground:NO];
    [label setFont:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size]];
    [[label cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [label setToolTip:text];
    return label;
}
static NSButton *JMButton(NSString *title, NSRect frame, id target, SEL action) {
    NSButton *button = [[JMThemedButton alloc] initWithFrame:frame];
    [button setTitle:title]; [button setBezelStyle:NSRoundedBezelStyle];
    [button setTarget:target]; [button setAction:action];
    [button setToolTip:title];
    return button;
}
static void JMSetLabel(NSTextField *label, NSString *text) { [label setStringValue:text ?: @""]; [label setToolTip:text]; }
static NSButton *JMCheckbox(NSString *title, NSRect frame, id target, SEL action) {
    NSButton *button=[[NSButton alloc] initWithFrame:frame]; [button setButtonType:NSSwitchButton];
    button.title=title; button.font=[NSFont systemFontOfSize:13]; button.target=target; button.action=action; button.toolTip=title; return button;
}
static NSString *JMName(NSDictionary *contact) {
    NSString *rosterName=JMString(contact[@"_rosterFriendly"]); if (rosterName.length) return rosterName;
    NSString *name = JMString(contact[@"friendly"]);
    return [name length] ? name : JMString(contact[@"aimId"]);
}
static NSString *JMState(NSDictionary *contact) {
    NSString *state = JMString(contact[@"state"]);
    if ([state isEqualToString:@"online"] || [state isEqualToString:@"freeForChat"]) return JML(@"В сети");
    if ([state isEqualToString:@"away"] || [state isEqualToString:@"na"]) return JML(@"Отошёл");
    if ([state isEqualToString:@"dnd"]) return JML(@"Не беспокоить");
    if ([state isEqualToString:@"occupied"]) return JML(@"Занят");
    if ([state isEqualToString:@"invisible"]) return JML(@"Невидимый");
    return JML(@"Не в сети");
}

@interface JMAppDelegate () <JMAvatarStoreDelegate, NSMenuDelegate, JMNotificationAlertsDelegate>
@property(nonatomic) BOOL changingPrivacy;
@property(nonatomic) BOOL restoringMessages;
@property(nonatomic) BOOL restoreAfterReconnect;
@property(nonatomic,strong) JMAutoAway *autoAway;
@property(nonatomic,strong) NSTimer *autoAwayTimer;
@property(nonatomic,strong) NSDate *autoAwayRetryDate;
@property(nonatomic) NSUInteger presenceRequestSerial;
@property(nonatomic) BOOL automaticPresenceRequest;
@property(nonatomic,strong) NSPopUpButton *autoAwayPopup;
@property(nonatomic,strong) NSWindow *storageWindow;
@property(nonatomic,strong) NSTextField *storageSummary;
@property(nonatomic,strong) NSTextField *storageFeedback;
@property(nonatomic,strong) NSPopUpButton *storageScopePopup;
@property(nonatomic,strong) NSDatePicker *storageFromDate;
@property(nonatomic,strong) NSDatePicker *storageUntilDate;
@property(nonatomic,strong) NSButton *storageBackupCheckbox;
@property(nonatomic,strong) NSButton *storageDeleteButton;
@property(nonatomic,strong) NSWindow *diagnosticsWindow;
@property(nonatomic,strong) NSTextView *diagnosticsText;
@property(nonatomic, strong) JMInformationController *aboutController;
@property(nonatomic,strong) NSButton *themeFavoriteButton;
@property(nonatomic,strong) NSTextField *themeUINTitle;
@property(nonatomic,strong) NSTextField *themeUINValue;
@property(nonatomic,strong) NSTextField *themeNickTitle;
@property(nonatomic,strong) NSTextField *themeNickValue;
@property(nonatomic,strong) NSImageView *themeRecipientState;
@property(nonatomic,strong) NSView *themeSendBar;
@property(nonatomic,strong) NSMenu *themeGroupMenu;
@property(nonatomic,strong) NSPopUpButton *themeMainMenu;
@property(nonatomic,strong) JMChromeView *mobileFooter;
@property(nonatomic,strong) NSButton *mobileFind;
@property(nonatomic,strong) NSButton *mobileSettings;
@property(nonatomic,strong) NSButton *mobileUnread;
@property(nonatomic,strong) NSTextField *mobileChatTitle;
@property(nonatomic,strong) NSSegmentedControl *themeConversationTabs;
@property(nonatomic,strong) NSPopUpButton *themeConversationPicker;
@property(nonatomic,strong) NSArray *themeTabPeers;
@property(nonatomic,strong) NSButton *themeCloseButton;
@property(nonatomic,strong) NSButton *themeSmileyButton;
@property(nonatomic,strong) NSButton *themeFontButton;
@property(nonatomic,strong) NSTextField *themeComposerCount;
@property(nonatomic,strong) NSWindow *rosterWindow;
@property(nonatomic,strong) JMChromeView *conversationHeader;
@property(nonatomic,strong) NSImageView *brandImage;
@property(nonatomic,strong) NSTextField *brandTitle;
@property(nonatomic,strong) NSTextField *brandSubtitle;
@property(nonatomic,strong) NSButton *writeConversationButton;
@property(nonatomic,copy) NSString *appliedAppearance;
@property(nonatomic) NSRect unifiedFrame;
@property(nonatomic, strong) JMInformationController *keyboardHelpController;
@property(nonatomic, strong) JMAPIClient *client;
@property(nonatomic, strong) JMUpdateChecker *updateChecker;
@property(nonatomic) BOOL checkingUpdates;
@property(nonatomic) BOOL manualUpdateRequested;
@property(nonatomic,strong) NSWindow *updateWindow;
@property(nonatomic,strong) NSTextField *updateHeading;
@property(nonatomic,strong) NSTextView *updateDetail;
@property(nonatomic,strong) NSProgressIndicator *updateProgress;
@property(nonatomic,strong) NSButton *updateAction;
@property(nonatomic,strong) NSURL *updateReleaseURL;
@property(nonatomic,strong) NSTimer *updateTimer;
@property(nonatomic,strong) NSDate *updateRetryDate;
@property(nonatomic,strong) NSDictionary *pendingUpdateRelease;
@property(nonatomic) BOOL exportingHistory;
@property(nonatomic) BOOL offlineMode;
@property(nonatomic) BOOL dataOperationInProgress;
@property(nonatomic) BOOL quitAfterDataOperation;
@property(nonatomic,strong) NSMutableSet *mutedPeers;
@property(nonatomic,strong) NSButton *offlineHistoryButton;
@property(nonatomic, strong) NSMutableSet *favoritePeers;
@property(nonatomic, strong) NSButton *onlineOnlyCheckbox;
@property(nonatomic, strong) NSButton *favoritesOnlyCheckbox;
@property(nonatomic, strong) NSButton *emoticonsCheckbox;
@property(nonatomic, strong) NSButton *olderMessagesButton;
@property(nonatomic, strong) NSButton *newerMessagesButton;
@property(nonatomic, strong) NSTextField *historyPageLabel;
@property(nonatomic) NSUInteger transcriptOffset;
@property(nonatomic) BOOL transcriptTail;
@property(nonatomic) BOOL renderingTranscript;
@property(nonatomic, copy) NSString *sendingLocalID;
@property(nonatomic, strong) JMHistory *history;
@property(nonatomic, strong) JMLoginStore *loginStore;
@property(nonatomic, strong) NSUserDefaults *loginDefaults;
@property(nonatomic, strong) dispatch_queue_t loginStoreQueue;
@property(nonatomic, strong) NSButton *rememberLoginCheckbox;
@property(nonatomic, strong) NSButton *cancelLoginButton;
@property(nonatomic) BOOL loginPending;
@property(nonatomic) BOOL resumingLogin;
@property(nonatomic) BOOL pendingRememberLogin;
@property(nonatomic) NSUInteger loginAttemptSerial;
@property(nonatomic) BOOL terminating;
@property(nonatomic, copy) NSString *quitCredentialError;
@property(nonatomic, strong) JMDraftStore *draftStore;
@property(nonatomic, strong) dispatch_queue_t draftSaveQueue;
@property(nonatomic, strong) NSTimer *draftSaveTimer;
@property(nonatomic, strong) NSError *draftSaveError;
@property(nonatomic) NSUInteger draftSaveSerial;
@property(nonatomic) BOOL draftsPending;
@property(nonatomic) NSUInteger conversationGeneration;
@property(nonatomic, copy) NSString *sendingPeer;
@property(nonatomic, copy) NSString *sendingText;
@property(nonatomic) BOOL sendingDraftWasEdited;
@property(nonatomic) BOOL sendingClearsDraft;
@property(nonatomic, strong) NSWindow *loginWindow;
@property(nonatomic, strong) NSWindow *chatWindow;
@property(nonatomic, strong) NSTextField *uinField;
@property(nonatomic, strong) NSSecureTextField *passwordField;
@property(nonatomic, strong) NSTextField *loginStatus;
@property(nonatomic, strong) NSButton *loginButton;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextField *peerLabel;
@property(nonatomic, strong) NSTextField *countLabel;
@property(nonatomic, strong) NSSegmentedControl *sectionControl;
@property(nonatomic, strong) NSTextField *emptyListLabel;
@property(nonatomic, strong) NSTextField *contactNotice;
@property(nonatomic, strong) NSButton *addContactButton;
@property(nonatomic, strong) NSButton *addPeerButton;
@property(nonatomic, strong) NSMutableArray *serverGroups;
@property(nonatomic, copy) NSString *selectedGroup;
@property(nonatomic, strong) NSPopUpButton *groupFilter;
@property(nonatomic, strong) NSMenu *contactMenu;
@property(nonatomic) BOOL changingRoster;
@property(nonatomic, strong) NSPanel *groupsWindow;
@property(nonatomic, strong) NSPopUpButton *groupManagerPopup;
@property(nonatomic, strong) NSTextField *groupCountLabel;
@property(nonatomic, strong) NSTextField *groupStatus;
@property(nonatomic, strong) NSButton *createGroupButton;
@property(nonatomic, strong) NSButton *renameGroupButton;
@property(nonatomic, strong) NSButton *removeGroupButton;
@property(nonatomic, strong) NSTextField *accountLabel;
@property(nonatomic, strong) NSTextField *peerDetail;
@property(nonatomic, strong) NSImageView *peerAvatar;
@property(nonatomic, strong) NSPopUpButton *presencePopup;
@property(nonatomic, strong) NSTextField *presenceFeedback;
@property(nonatomic, strong) NSButton *reconnectButton;
@property(nonatomic, strong) NSButton *profileButton;
@property(nonatomic, strong) NSButton *historySearchButton;
@property(nonatomic, strong) JMChatPreferences *chatPreferences;
@property(nonatomic, strong) NSPanel *preferencesWindow;
@property(nonatomic, strong) NSSegmentedControl *preferenceSections;
@property(nonatomic,strong) NSView *appearancePreferencesView;
@property(nonatomic,strong) NSView *statusPreferencesView;
@property(nonatomic,strong) NSPopUpButton *appearancePopup;
@property(nonatomic,strong) NSPopUpButton *densityPopup;
@property(nonatomic,strong) NSTextView *appearancePreview;
@property(nonatomic,strong) NSButton *appearanceResetButton;
@property(nonatomic, strong) NSView *fontPreferencesView;
@property(nonatomic, strong) NSView *notificationPreferencesView;
@property(nonatomic, strong) NSView *soundPreferencesView;
@property(nonatomic, strong) NSButton *fontResetButton;
@property(nonatomic, strong) NSButton *notificationsCheckbox;
@property(nonatomic, strong) NSPopUpButton *notificationContentPopup;
@property(nonatomic, strong) NSTextField *notificationPrivacyHelp;
@property(nonatomic, strong) NSTextField *notificationTestStatus;
@property(nonatomic, strong) NSButton *notificationTestButton;
@property(nonatomic, strong) NSButton *dockAttentionCheckbox;
@property(nonatomic, strong) NSButton *soundMasterCheckbox;
@property(nonatomic, strong) NSButton *presenceSoundCheckbox;
@property(nonatomic, strong) NSButton *typingSoundCheckbox;
@property(nonatomic, strong) NSButton *openConversationSoundCheckbox;
@property(nonatomic, strong) NSButton *latestMessagesButton;
@property(nonatomic, strong) JMNotificationAlerts *notificationAlerts;
@property(nonatomic, copy) NSString *pendingNotificationPeer;
@property(nonatomic, copy) NSString *pendingNotificationAccount;
@property(nonatomic, strong) NSPopUpButton *fontFamilyPopup;
@property(nonatomic, strong) NSPopUpButton *fontSizePopup;
@property(nonatomic, strong) NSPopUpButton *sendModePopup;
@property(nonatomic, strong) NSTextField *fontPreview;
@property(nonatomic,strong) NSButton *historyDateCheckbox;
@property(nonatomic,strong) NSDatePicker *historyFromDate;
@property(nonatomic,strong) NSDatePicker *historyUntilDate;
@property(nonatomic,strong) NSButton *historyBookmarkCheckbox;
@property(nonatomic, strong) NSWindow *historyWindow;
@property(nonatomic, strong) NSSearchField *historySearchField;
@property(nonatomic, strong) NSPopUpButton *historyScopePopup;
@property(nonatomic, strong) NSTableView *historyTable;
@property(nonatomic, strong) NSTextField *historySearchStatus;
@property(nonatomic, strong) NSButton *historyOpenButton;
@property(nonatomic, strong) NSArray *historyResults;
@property(nonatomic, copy) NSString *historyResultsQuery;
@property(nonatomic, strong) dispatch_queue_t historySearchQueue;
@property(nonatomic) NSUInteger historySearchGeneration;
@property(nonatomic, strong) NSMutableDictionary *transcriptRanges;
@property(nonatomic, copy) NSString *highlightedMessageID;
@property(nonatomic, copy) NSString *historyHighlightQuery;
@property(nonatomic, strong) NSButton *soundButton;
@property(nonatomic, strong) NSButton *logoutButton;
@property(nonatomic, strong) JMChromeView *toolbar;
@property(nonatomic, strong) JMChromeView *sidebar;
@property(nonatomic, strong) NSView *chatPane;
@property(nonatomic, strong) JMAudioAlerts *audioAlerts;
@property(nonatomic, strong) NSDate *connectedSince;
@property(nonatomic) BOOL wasConnected;
@property(nonatomic, strong) NSTextField *typingLabel;
@property(nonatomic, strong) NSMutableDictionary *ownInfo;
@property(nonatomic, strong) JMOwnProfileController *ownProfileController;
@property(nonatomic, strong) NSMutableDictionary *profileDates;
@property(nonatomic, strong) NSMutableDictionary *profileTexts;
@property(nonatomic, strong) NSMutableDictionary *incomingTyping;
@property(nonatomic, strong) NSTimer *outgoingTypingTimer;
@property(nonatomic, strong) NSTimer *incomingTypingTimer;
@property(nonatomic, strong) JMAvatarStore *avatars;
@property(nonatomic) BOOL changingPresence;
@property(nonatomic, strong) NSPanel *profileWindow;
@property(nonatomic, copy) NSString *profilePeer;
@property(nonatomic, strong) NSImageView *profileAvatar;
@property(nonatomic, strong) NSTextField *profileName;
@property(nonatomic, strong) NSTextField *profileDetail;
@property(nonatomic, strong) NSTextField *profileStatus;
@property(nonatomic, strong) NSTextView *profileAbout;
@property(nonatomic, strong) NSButton *profileRefresh;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSTableView *contactTable;
@property(nonatomic, strong) NSTextView *transcript;
@property(nonatomic, strong) JMConversationEmptyView *conversationEmptyView;
@property(nonatomic, strong) NSTextView *composer;
@property(nonatomic, strong) NSButton *sendButton;
@property(nonatomic, strong) NSTextField *composerHint;
@property(nonatomic, strong) NSMutableDictionary *contacts;
@property(nonatomic, strong) NSMutableSet *serverContactIDs;
@property(nonatomic, strong) NSMutableSet *conversationPeers;
@property(nonatomic, strong) NSMutableDictionary *drafts;
@property(nonatomic, strong) NSMutableDictionary *unread;
@property(nonatomic, strong) NSArray *visibleContacts;
@property(nonatomic) BOOL unreadOnly;
@property(nonatomic,strong) NSDictionary *visibleGroupCounts;
@property(nonatomic, copy) NSString *selectedPeer;
@property(nonatomic, copy) NSString *accountUIN;
@property(nonatomic) BOOL sending;
@property(nonatomic) BOOL reloadingContacts;
@property(nonatomic) BOOL showedHistoryError;
@property(nonatomic) BOOL addingContact;
@property(nonatomic, strong) NSDate *sendNotBefore;
@end

@implementation JMAppDelegate
- (void)updateHistoricalTabs {
    if (!self.themeConversationTabs || JMTheme()!=JMThemeMac2011) return;
    NSMutableArray *peers=[[self.conversationPeers allObjects] mutableCopy];
    [peers sortUsingComparator:^NSComparisonResult(NSString *a,NSString *b) { return [JMName(self.contacts[a] ?: @{@"aimId":a}) localizedCaseInsensitiveCompare:JMName(self.contacts[b] ?: @{@"aimId":b})]; }];
    if (self.selectedPeer.length && ![peers containsObject:self.selectedPeer]) [peers addObject:self.selectedPeer];
    NSMutableArray *tabs=[NSMutableArray arrayWithArray:[peers subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)4,peers.count))]];
    if (self.selectedPeer.length && ![tabs containsObject:self.selectedPeer]) { if (tabs.count==4) [tabs removeLastObject]; [tabs addObject:self.selectedPeer]; }
    self.themeTabPeers=tabs; self.themeConversationTabs.segmentCount=tabs.count;
    self.themeConversationPicker.hidden=peers.count<=4;
    CGFloat available=NSWidth(self.chatPane.bounds)-(peers.count>4 ? 125 : 10); CGFloat width=tabs.count ? MIN(100,available/tabs.count) : 0; NSRect frame=self.themeConversationTabs.frame; frame.size.width=width*tabs.count; self.themeConversationTabs.frame=frame;
    for (NSUInteger i=0;i<tabs.count;i++) { NSString *peer=tabs[i]; [self.themeConversationTabs setLabel:JMName(self.contacts[peer] ?: @{@"aimId":peer}) forSegment:i]; [self.themeConversationTabs setWidth:width forSegment:i]; [self.themeConversationTabs setImage:JMStatusImage(JMString(self.contacts[peer][@"state"])) forSegment:i]; [self.themeConversationTabs setSelected:[peer isEqual:self.selectedPeer] forSegment:i]; [(NSSegmentedCell *)self.themeConversationTabs.cell setToolTip:[NSString stringWithFormat:@"%@ · UIN %@",JMName(self.contacts[peer] ?: @{@"aimId":peer}),peer] forSegment:i]; }
    [self.themeConversationPicker removeAllItems]; [self.themeConversationPicker addItemWithTitle:JML(@"Все переписки")];
    [self.themeConversationPicker itemAtIndex:0].enabled=NO;
    for (NSString *peer in peers) { [self.themeConversationPicker addItemWithTitle:JMName(self.contacts[peer] ?: @{@"aimId":peer})]; NSMenuItem *item=self.themeConversationPicker.lastItem; item.representedObject=peer; item.target=self; item.action=@selector(openHistoricalConversation:); item.state=[peer isEqual:self.selectedPeer] ? NSOnState : NSOffState; }
}
- (void)changeHistoricalTab:(id)sender { NSInteger index=self.themeConversationTabs.selectedSegment; if (index>=0 && index<(NSInteger)self.themeTabPeers.count) [self selectPeer:self.themeTabPeers[(NSUInteger)index]]; }
- (void)openHistoricalConversation:(NSMenuItem *)sender { if (JMValidUIN(sender.representedObject)) [self selectPeer:sender.representedObject]; }
- (void)closeHistoricalConversation:(id)sender { [self.chatWindow performClose:nil]; }
- (void)filterHistoricalGroup:(NSMenuItem *)sender {
    id group=sender.representedObject; self.selectedGroup=[group isKindOfClass:[NSString class]] ? group : nil;
    [self.sectionControl setSelectedSegment:0]; [self refreshGroupChoices]; [self changeSection:nil];
}
- (void)showClassicFontMenu:(id)sender {
    NSMenu *menu=[[NSMenu alloc] initWithTitle:JML(@"Шрифт")];
    NSMenuItem *settings=[menu addItemWithTitle:JML(@"Настройки…") action:@selector(showPreferences:) keyEquivalent:@""]; settings.target=self; [menu addItem:[NSMenuItem separatorItem]];
    for (NSNumber *size in @[@11,@12,@13,@14,@16,@18,@24,@28]) { NSMenuItem *item=[menu addItemWithTitle:size.stringValue action:@selector(changeClassicFontSize:) keyEquivalent:@""]; item.target=self; item.representedObject=size; item.state=self.chatPreferences.size==size.doubleValue ? NSOnState : NSOffState; }
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSHeight(self.themeFontButton.bounds)) inView:self.themeFontButton];
}
- (void)changeClassicFontSize:(NSMenuItem *)sender { CGFloat size=[sender.representedObject doubleValue]; if (size<9 || size>28) return; [self.chatPreferences setFamily:self.chatPreferences.family size:size]; [self applyChatFont]; }
- (void)showClassicSmileys:(id)sender {
    NSMenu *menu=[[NSMenu alloc] initWithTitle:JML(@"Смайлики")];
    for (NSString *code in JMSmileyCodes()) {
        NSImage *image=JMSmileyImage(code);
        if (!image) continue;
        NSMenuItem *item=[menu addItemWithTitle:code action:@selector(insertClassicSmiley:) keyEquivalent:@""];
        item.target=self; item.representedObject=code; item.image=image;
    }
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSHeight(self.themeSmileyButton.bounds)) inView:self.themeSmileyButton];
}
- (void)insertClassicSmiley:(NSMenuItem *)sender {
    if (!self.composer.isEditable) return;
    [self.chatWindow makeKeyAndOrderFront:nil]; [self.chatWindow makeFirstResponder:self.composer];
    [self.composer insertText:sender.representedObject replacementRange:self.composer.selectedRange]; [self.composer didChangeText];
}
- (NSString *)historicalGroupForContact:(NSDictionary *)contact {
    if (contact[@"_collapsedGroup"]) return contact[@"_collapsedGroup"];
    if (self.sectionControl.selectedSegment==1) return JML(@"Переписки");
    if ([self.favoritePeers containsObject:contact[@"aimId"]]) return JML(@"Избранные");
    if (JMTheme()==JMThemePro2003) return [JMString(contact[@"state"]) isEqual:@"offline"] || !JMString(contact[@"state"]).length ? JML(@"Не в сети") : JML(@"В сети");
    return self.selectedGroup ?: [JMArray(contact[@"groups"]) firstObject] ?: JML(@"Контакты");
}
- (NSString *)collapsedGroupsKey {
    return [NSString stringWithFormat:@"CollapsedGroups.%@.%@",self.accountUIN ?: @"",JMThemeIdentifier()];
}
- (void)toggleGroup:(NSString *)group {
    if (!group.length || self.sectionControl.selectedSegment!=0 || self.searchField.stringValue.length) return;
    NSString *key=[self collapsedGroupsKey];
    NSMutableSet *collapsed=[NSMutableSet setWithArray:[self.loginDefaults arrayForKey:key] ?: @[]];
    if ([collapsed containsObject:group]) [collapsed removeObject:group]; else [collapsed addObject:group];
    [self.loginDefaults setObject:collapsed.allObjects forKey:key]; [self reloadContacts];
}
- (void)toggleSelectedGroup:(id)sender {
    NSInteger row=self.contactTable.selectedRow;
    if (row>=0 && row<(NSInteger)self.visibleContacts.count) [self toggleGroup:[self historicalGroupForContact:self.visibleContacts[(NSUInteger)row]]];
}
- (void)toggleUnreadFilter:(id)sender {
    self.unreadOnly=!(self.unreadOnly && self.sectionControl.selectedSegment==1);
    if (self.sectionControl.selectedSegment!=1) { self.sectionControl.selectedSegment=1; [self changeSection:nil]; }
    else [self reloadContacts];
    [[self listWindow] makeKeyAndOrderFront:nil];
}
- (NSString *)historicalHeaderForRow:(NSInteger)row {
    if (row<0 || row>=(NSInteger)self.visibleContacts.count) return nil;
    BOOL conversations=self.sectionControl.selectedSegment==1;
    if (conversations && JMTheme()==JMThemeCurrent) return nil;
    NSDictionary *contact=self.visibleContacts[(NSUInteger)row];
    NSString *group=[self historicalGroupForContact:contact];
    if (row>0 && [group isEqual:[self historicalGroupForContact:self.visibleContacts[(NSUInteger)row-1]]]) return nil;
    if (conversations) return group;
    return [NSString stringWithFormat:@"%@ %@  %@",contact[@"_collapsedGroup"] ? @"▸" : @"▾",group,self.visibleGroupCounts[group] ?: @""];
}
- (CGFloat)headerHeightForRow:(NSInteger)row {
    return [self historicalHeaderForRow:row].length ? (JMTheme()==JMThemePro2003 ? 17 : 23) : 0;
}
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView!=self.contactTable) return tableView.rowHeight;
    CGFloat header=[self headerHeightForRow:row];
    if (row>=0 && row<(NSInteger)self.visibleContacts.count && self.visibleContacts[(NSUInteger)row][@"_collapsedGroup"]) return header;
    if (JMTheme()==JMThemeCurrent || JMThemeIsMobile()) return tableView.rowHeight+header;
    BOOL detail=self.sectionControl.selectedSegment==1 || (row>=0 && row<(NSInteger)self.visibleContacts.count && JMString(self.visibleContacts[(NSUInteger)row][@"statusMsg"]).length);
    return (JMTheme()==JMThemePro2003 ? 18 : ([self.loginDefaults boolForKey:@"CompactContactList"] ? 28 : (detail ? 42 : 34)))+header;
}
- (NSWindow *)listWindow { return JMTheme()==JMThemeCurrent ? self.chatWindow : self.rosterWindow; }
- (void)showSessionWindows {
    if (JMTheme()==JMThemeCurrent) [self.chatWindow makeKeyAndOrderFront:nil];
    else { [self.rosterWindow makeKeyAndOrderFront:nil]; if (self.selectedPeer.length) [self.chatWindow orderFront:nil]; }
}
- (void)changeLanguage:(NSMenuItem *)sender {
    NSString *language=sender.representedObject; if (![@[@"ru",@"en",@"uk",@"be"] containsObject:language] || self.dataOperationInProgress) return;
    [self.loginDefaults setObject:language forKey:@"InterfaceLanguage"]; [self.loginDefaults synchronize];
    [self showError:JML(@"Язык сохранён") detail:JML(@"Язык интерфейса изменится после перезапуска JimmMac из Finder. История и черновики сохранятся.")];
}
- (void)changeAppearance:(NSMenuItem *)sender {
    if (self.dataOperationInProgress) return;
    NSString *identifier=sender.representedObject;
    if (![JMThemeIdentifiers() containsObject:identifier]) return;
    [self.loginDefaults setObject:identifier forKey:@"InterfaceAppearance"]; [self.loginDefaults synchronize]; [self applyAppearance];
}
- (void)applyAppearance {
    NSString *previous=self.appliedAppearance ?: @"current";
    NSString *choice=[self.loginDefaults stringForKey:@"InterfaceAppearance"] ?: @"current";
    BOOL wasVisible=self.chatWindow.isVisible || self.rosterWindow.isVisible;
    if ([previous isEqual:@"current"] && ![choice isEqual:@"current"]) self.unifiedFrame=self.chatWindow.frame;
    JMSetTheme(choice); self.appliedAppearance=JMThemeIdentifier();
    BOOL historic=JMTheme()!=JMThemeCurrent;
    CGFloat rosterWidth=JMThemeIsMobile() ? 302 : (JMTheme()==JMThemePro2003 ? 232 : 252);
    if (historic && !self.rosterWindow) {
        self.rosterWindow=[[JMWindow alloc] initWithContentRect:NSMakeRect(20,100,268,620) styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
        self.rosterWindow.title=JML(@"JimmMac — Контакты"); self.rosterWindow.releasedWhenClosed=NO; self.rosterWindow.delegate=self;
        self.rosterWindow.contentView=[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,268,620)]; self.rosterWindow.contentMinSize=NSMakeSize(268,580); self.rosterWindow.contentMaxSize=NSMakeSize(268,2000);
        NSRect screen=(self.chatWindow.screen ?: [NSScreen mainScreen]).visibleFrame;
        [self.rosterWindow setFrameTopLeftPoint:NSMakePoint(NSMinX(screen)+18,NSMaxY(screen)-36)];
    }
    if (historic) {
        NSSize size=[(NSView *)self.rosterWindow.contentView frame].size; self.rosterWindow.contentMinSize=NSMakeSize(rosterWidth,JMTheme()==JMThemePro2003 ? 440 : 520); self.rosterWindow.contentMaxSize=NSMakeSize(rosterWidth,2000);
        [self.rosterWindow setContentSize:NSMakeSize(rosterWidth,MAX(self.rosterWindow.contentMinSize.height,MIN(size.height,620)))];
        self.rosterWindow.title=JMThemeIsMobile() ? JML(@"JimmMac — Контакты") : (JMTheme()==JMThemePro2003 ? @"ICQ Pro 2003b — JimmMac" : @"ICQ for Mac — JimmMac");
    }
    NSView *parent=historic ? self.rosterWindow.contentView : self.chatWindow.contentView;
    for (NSView *view in @[self.toolbar,self.sidebar,self.statusLabel,self.soundButton,self.logoutButton]) {
        [view removeFromSuperview]; [parent addSubview:view];
    }
    BOOL pro=JMTheme()==JMThemePro2003 || JMThemeIsMobile();
    for (NSView *view in @[self.mobileFooter,self.mobileFind,self.mobileSettings]) {
        [view removeFromSuperview];
        if (JMThemeIsMobile()) [parent addSubview:view positioned:view==self.mobileFooter ? NSWindowBelow : NSWindowAbove relativeTo:nil];
        view.hidden=!JMThemeIsMobile();
    }
    for (NSView *view in @[self.addContactButton,self.writeConversationButton]) { [view removeFromSuperview]; [(pro ? parent : self.sidebar) addSubview:view]; }
    for (NSView *view in @[self.presencePopup,self.reconnectButton,self.presenceFeedback]) { [view removeFromSuperview]; [((view==self.presencePopup ? pro : historic) ? parent : self.toolbar) addSubview:view]; }
    [self.sectionControl removeFromSuperview]; [(JMTheme()==JMThemeMac2011 ? self.toolbar : self.sidebar) addSubview:self.sectionControl];
    [self.themeMainMenu removeFromSuperview];
    [(JMTheme()==JMThemeMac2011 ? self.toolbar : parent) addSubview:self.themeMainMenu];
    self.themeMainMenu.hidden=!historic;
    NSMenuItem *menuCaption=[self.themeMainMenu itemAtIndex:0];
    menuCaption.title=JMThemeIsMobile() ? JML(@"Меню") : JML(@"Главное");
    menuCaption.image=JMThemeIsMobile() ? JMRetroImage(@"menu") : nil;
    self.themeMainMenu.tag=JMTheme()==JMThemeMac2011 ? 902 : (JMTheme()==JMThemeJimm ? JMRetroFooterItemTag : 0);
    if (historic) {
        self.chatWindow.contentMinSize=pro ? NSMakeSize(480,320) : NSMakeSize(460,420);
        if (![previous isEqual:choice]) {
            [self.chatWindow setContentSize:pro ? NSMakeSize(540,360) : NSMakeSize(500,520)];
            NSRect screen=(self.rosterWindow.screen ?: [NSScreen mainScreen]).visibleFrame;
            [self.chatWindow setFrameTopLeftPoint:NSMakePoint(MIN(NSMaxX(self.rosterWindow.frame)+12,NSMaxX(screen)-NSWidth(self.chatWindow.frame)-12),NSMaxY(self.rosterWindow.frame))];
        }
    } else {
        [self.rosterWindow orderOut:nil]; self.chatWindow.contentMinSize=NSMakeSize(860,560);
        if (![previous isEqual:@"current"]) { if (!NSEqualRects(self.unifiedFrame,NSZeroRect)) [self.chatWindow setFrame:self.unifiedFrame display:YES]; else [self.chatWindow setContentSize:NSMakeSize(1000,650)]; }
    }
    self.toolbar.topColor=JMLegacyHeaderTopColor(); self.toolbar.bottomColor=JMLegacyHeaderBottomColor(); self.toolbar.needsDisplay=YES;
    self.conversationHeader.hidden=!historic; self.conversationHeader.topColor=JMLegacyHeaderTopColor(); self.conversationHeader.bottomColor=JMLegacyHeaderBottomColor(); self.conversationHeader.needsDisplay=YES;
    self.sidebar.topColor=historic ? JMThemeBackground() : [NSColor colorWithCalibratedWhite:0.94 alpha:1]; self.sidebar.bottomColor=self.sidebar.topColor; self.sidebar.needsDisplay=YES;
    self.contactTable.backgroundColor=JMThemeIsMobile() ? (JMTheme()==JMThemeQIP ? [NSColor colorWithCalibratedRed:0.86 green:0.92 blue:0.98 alpha:1] : JMThemeBackground()) : (historic ? [NSColor whiteColor] : self.sidebar.topColor);
    [(JMContactTable *)self.contactTable setBlueRosterGradient:JMTheme()==JMThemeQIP];
    self.contactTable.enclosingScrollView.borderType=JMTheme()==JMThemePro2003 ? NSBezelBorder : NSNoBorder;
    self.contactTable.rowHeight=JMTheme()==JMThemePro2003 ? 18 : (JMTheme()==JMThemeMac2011 ? 34 : 60); if ([self.loginDefaults boolForKey:@"CompactContactList"]) self.contactTable.rowHeight=JMTheme()==JMThemePro2003 ? 18 : (JMTheme()==JMThemeMac2011 ? 28 : 42);
    if (JMThemeIsMobile()) self.contactTable.rowHeight=[self.loginDefaults boolForKey:@"CompactContactList"] ? 34 : 40;
    self.sectionControl.segmentStyle=JMTheme()==JMThemePro2003 ? NSSegmentStyleSmallSquare : NSSegmentStyleRounded;
    for (NSMenuItem *item in self.presencePopup.itemArray) item.image=JMStatusImage(item.representedObject);
    self.presencePopup.tag=JMTheme()==JMThemeMac2011 ? 901 : 0; self.sectionControl.tag=JMTheme()==JMThemeMac2011 ? 903 : 0; self.themeConversationTabs.tag=904;
    self.themeFavoriteButton.hidden=JMTheme()!=JMThemeMac2011;
    for (NSInteger i=0;i<2;i++) { [self.sectionControl setLabel:JMTheme()==JMThemeMac2011 ? @"" : (i==0 ? JML(@"Контакты") : JML(@"Переписки")) forSegment:i]; [self.sectionControl setImage:JMTheme()==JMThemeMac2011 ? JMRetroImage(i==0 ? @"contacts" : @"conversations") : nil forSegment:i]; }
    for (NSButton *button in @[self.profileButton,self.historySearchButton]) {
        button.image=historic ? JMRetroImage(button==self.profileButton ? @"profile" : @"history") : nil;
        button.imagePosition=button.image ? NSImageOnly : NSNoImage;
    }
    self.themeFavoriteButton.image=JMRetroImage(@"favorites");
    self.themeSmileyButton.image=JMRetroImage(@"smiley-button") ?: JMClassicSmileyImage();
    self.themeFontButton.image=JMRetroImage(@"font");
    self.themeFontButton.imagePosition=self.themeFontButton.image ? NSImageOnly : NSNoImage;
    self.mobileFind.image=JMRetroImage(@"find");
    self.mobileSettings.image=JMRetroImage(@"settings");
    self.sectionControl.font=[NSFont systemFontOfSize:historic ? 11 : 13]; if (!historic) { [self.sectionControl setWidth:116 forSegment:0]; [self.sectionControl setWidth:116 forSegment:1]; } [self.sectionControl sizeToFit];
    self.brandTitle.hidden=NO; self.brandTitle.textColor=JMTheme()==JMThemePro2003 ? [NSColor whiteColor] : JMThemeHeaderInk(); self.accountLabel.textColor=JMThemeIsMobile() ? JMThemeHeaderInk() : [NSColor textColor]; self.brandTitle.stringValue=historic ? (pro ? @"ICQ Pro 2003b" : @"icq") : @"JimmMac";
    self.brandImage.image=historic && !pro ? ([self.avatars imageForUIN:self.accountUIN] ?: JMRetroImage(@"avatar") ?: [NSImage imageNamed:NSImageNameUser]) : JMFlowerImage();
    self.accountLabel.alignment=historic ? NSLeftTextAlignment : NSRightTextAlignment; self.accountLabel.font=historic ? (pro ? [NSFont systemFontOfSize:11] : [NSFont boldSystemFontOfSize:13]) : [NSFont systemFontOfSize:12];
    self.brandSubtitle.hidden=pro; self.brandSubtitle.font=[NSFont systemFontOfSize:historic ? 10 : 11]; self.brandSubtitle.textColor=historic ? [NSColor colorWithCalibratedWhite:0.22 alpha:1] : JMSecondaryTextColor();
    self.brandSubtitle.stringValue=historic ? (JMString(self.ownInfo[@"statusMsg"]).length ? self.ownInfo[@"statusMsg"] : @"Jimm.online") : @"ICQ · Jimm.online"; self.brandSubtitle.toolTip=self.brandSubtitle.stringValue;
    self.presencePopup.font=[NSFont systemFontOfSize:historic ? 11 : 13]; self.groupFilter.font=self.presencePopup.font;
    [(NSSearchFieldCell *)self.searchField.cell setBezelStyle:JMTheme()==JMThemeMac2011 ? NSTextFieldSquareBezel : NSTextFieldRoundedBezel];
    self.searchField.font=[NSFont systemFontOfSize:historic ? 11 : 13];
    self.transcript.backgroundColor=JMThemeTranscriptColor();
    self.transcript.enclosingScrollView.borderType=pro ? NSBezelBorder : NSNoBorder;
    self.transcript.textContainerInset=historic ? NSMakeSize(pro ? 5 : 9,pro ? 6 : 12) : NSMakeSize(18,16);
    for (NSButton *button in @[self.addContactButton,self.writeConversationButton,self.profileButton,self.historySearchButton,self.addPeerButton,self.olderMessagesButton,self.newerMessagesButton,self.sendButton,self.soundButton,self.logoutButton,self.reconnectButton,self.themeCloseButton,self.themeSmileyButton,self.themeFontButton,self.themeFavoriteButton]) {
        button.bezelStyle=NSRoundedBezelStyle;
        button.font=JMThemeFont([NSFont systemFontOfSize:historic ? 11 : 13],@"");
    }
    self.sendButton.image=nil; self.sendButton.imagePosition=NSNoImage;
    for (NSWindow *window in [NSApp windows]) { window.backgroundColor=JMThemeBackground(); [(NSView *)window.contentView setNeedsDisplay:YES]; if (window!=self.chatWindow && window!=self.rosterWindow && ([window isKindOfClass:[JMWindow class]] || [window isKindOfClass:[JMPanel class]])) JMRefreshUtilityWindow(window); }
    for (NSView *view in [(NSView *)self.loginWindow.contentView subviews]) {
        if ([view isKindOfClass:[NSTextField class]] && NSMinY(view.frame)>=258) [(NSTextField *)view setTextColor:JMThemeHeaderInk()];
    }
    for (NSView *view in [(NSView *)self.loginWindow.contentView subviews]) if ([view isKindOfClass:[JMChromeView class]]) { [(JMChromeView *)view setTopColor:JMLegacyHeaderTopColor()]; [(JMChromeView *)view setBottomColor:JMLegacyHeaderBottomColor()]; view.needsDisplay=YES; }
    NSArray *views=@[self.presencePopup,self.sectionControl,self.searchField,self.groupFilter,self.onlineOnlyCheckbox,self.favoritesOnlyCheckbox,self.contactTable,self.addContactButton,self.writeConversationButton,self.historySearchButton,self.profileButton,self.addPeerButton,self.conversationEmptyView.writeButton,self.olderMessagesButton,self.newerMessagesButton,self.transcript,self.latestMessagesButton,self.themeConversationTabs,self.themeConversationPicker,self.composer,self.themeSmileyButton,self.themeFontButton,self.sendButton,self.themeCloseButton,self.soundButton,self.logoutButton,self.reconnectButton,self.themeMainMenu,self.themeFavoriteButton,self.themeUINValue,self.themeNickValue];
    for (NSWindow *window in historic ? @[self.rosterWindow,self.chatWindow] : @[self.chatWindow]) {
        NSArray *ordered=views;
        if (historic && window==self.rosterWindow) ordered=JMTheme()==JMThemeMac2011 ? @[self.presencePopup,self.sectionControl,self.themeFavoriteButton,self.themeMainMenu,self.searchField,self.groupFilter,self.contactTable,self.addContactButton,self.writeConversationButton,self.soundButton,self.logoutButton,self.reconnectButton] : @[self.sectionControl,self.searchField,self.groupFilter,self.contactTable,self.addContactButton,self.writeConversationButton,self.soundButton,self.logoutButton,self.themeMainMenu,self.presencePopup,self.reconnectButton];
        else if (historic) ordered=JMTheme()==JMThemeMac2011 ? @[self.themeConversationTabs,self.themeConversationPicker,self.historySearchButton,self.profileButton,self.addPeerButton,self.olderMessagesButton,self.newerMessagesButton,self.transcript,self.latestMessagesButton,self.conversationEmptyView.writeButton,self.composer,self.themeSmileyButton,self.sendButton] : @[self.themeUINValue,self.themeNickValue,self.profileButton,self.historySearchButton,self.olderMessagesButton,self.newerMessagesButton,self.transcript,self.themeSmileyButton,self.themeFontButton,self.addPeerButton,self.conversationEmptyView.writeButton,self.composer,self.latestMessagesButton,self.sendButton,self.themeCloseButton];
        if (JMThemeIsMobile() && window==self.rosterWindow) ordered=@[self.presencePopup,self.sectionControl,self.searchField,self.groupFilter,self.mobileUnread,self.contactTable,self.mobileFind,self.themeMainMenu,self.mobileSettings,self.reconnectButton];
        NSMutableArray *loop=[NSMutableArray array]; for (NSView *view in ordered) if (view.window==window) [loop addObject:view];
        for (NSUInteger i=0;i<loop.count;i++) [loop[i] setNextKeyView:loop[(i+1)%loop.count]];
        window.autorecalculatesKeyViewLoop=NO; window.initialFirstResponder=window==[self listWindow] ? (NSView *)self.searchField : self.composer;
    }
    [self updateAccountLabel]; [self updatePeerLabel]; [self layoutChatWindow]; [self applyChatFont]; [self reloadContacts]; [self updateSendButton];
    if (historic && wasVisible) { [self.rosterWindow orderFront:nil]; if (!self.selectedPeer.length) [self.chatWindow orderOut:nil]; }
    if (!historic && wasVisible) [self.chatWindow makeKeyAndOrderFront:nil];
}
- (JMAccountData *)makeAccountDataForUIN:(NSString *)uin { return [[JMAccountData alloc] initWithUIN:uin root:nil]; }
- (NSArray *)storedAccountUINs { return JMStoredAccounts(nil); }
- (NSDictionary *)rosterSnapshot {
    return JMSafeRoster(@{@"uin":self.accountUIN ?: @"",@"contacts":self.contacts ?: @{},@"serverIDs":[self.serverContactIDs allObjects] ?: @[],@"groups":self.serverGroups ?: @[],@"ownInfo":self.ownInfo ?: @{},@"profiles":self.profileTexts ?: @{}});
}
- (void)persistRosterCache {
    if (self.offlineMode || !JMValidUIN(self.accountUIN)) return;
    NSError *error=nil; if (![[self makeAccountDataForUIN:self.accountUIN] saveRoster:[self rosterSnapshot] error:&error] && error) JMSetLabel(self.contactNotice,JML(@"Не удалось сохранить контакты для офлайн-просмотра."));
}
- (void)restoreRosterCache {
    NSDictionary *roster=[[self makeAccountDataForUIN:self.accountUIN] cachedRoster];
    [self.contacts removeAllObjects];
    for (NSString *peer in JMDictionary(roster[@"contacts"])) { NSMutableDictionary *contact=[roster[@"contacts"][peer] mutableCopy]; contact[@"state"]=@"offline"; self.contacts[peer]=contact; }
    [self.serverContactIDs addObjectsFromArray:JMArray(roster[@"serverIDs"])]; [self.serverGroups addObjectsFromArray:JMArray(roster[@"groups"])];
    [self.ownInfo addEntriesFromDictionary:JMDictionary(roster[@"ownInfo"])]; self.ownInfo[@"state"]=@"offline";
    [self.profileTexts addEntriesFromDictionary:JMDictionary(roster[@"profiles"])];
    for (NSString *peer in self.conversationPeers) if (!self.contacts[peer]) self.contacts[peer]=[@{@"aimId":peer,@"friendly":peer,@"state":@"offline"} mutableCopy];
}
- (void)openOfflineHistory:(id)sender {
    if (self.dataOperationInProgress || self.sending) return;
    NSArray *accounts=[self storedAccountUINs];
    NSString *uin=JMValidUIN(self.accountUIN) ? self.accountUIN : self.uinField.stringValue;
    if (![accounts containsObject:uin]) {
        if (!accounts.count) { [self showError:JML(@"Локальной истории пока нет") detail:JML(@"После первого входа переписка сохранится на этом Mac. Также можно восстановить резервную копию через меню «Файл».")]; return; }
        NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Открыть историю без подключения");
        NSPopUpButton *choice=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(0,0,290,30) pullsDown:NO]; [choice addItemsWithTitles:accounts]; alert.accessoryView=choice;
        [alert addButtonWithTitle:JML(@"Открыть")]; [alert addButtonWithTitle:JML(@"Отмена")].keyEquivalent=@"\e";
        if ([alert runModal]!=NSAlertFirstButtonReturn) return; uin=choice.titleOfSelectedItem;
    }
    [self openOfflineUIN:uin];
}
- (BOOL)openOfflineUIN:(NSString *)uin {
    [self flushDrafts]; if (![self canLeaveDrafts] || self.sending) return NO;
    self.loginAttemptSerial++; [self.client disconnect];
    if (![self prepareLoginUIForUIN:uin]) return NO;
    self.offlineMode=YES; self.loginPending=NO; self.resumingLogin=NO; self.pendingRememberLogin=NO;
    self.cancelLoginButton.hidden=YES; self.rememberLoginCheckbox.enabled=YES;
    [self.avatars invalidate]; self.avatars.delegate=self;
    [self restoreRosterCache]; self.onlineOnlyCheckbox.state=NSOffState; self.onlineOnlyCheckbox.enabled=NO;
    [self.presencePopup addItemWithTitle:JML(@"Офлайн · история")]; self.presencePopup.lastItem.representedObject=@"offline-local"; [self.presencePopup selectItem:self.presencePopup.lastItem];
    self.notificationAlerts.accountUIN=uin;
    [self refreshGroupChoices]; [self reloadContacts]; [self updateAccountLabel]; [self updatePeerLabel]; [self updateSendButton]; [self updateDockBadge];
    JMSetLabel(self.statusLabel,JML(@"Офлайн · История и черновики доступны, отправка после подключения"));
    [self.loginWindow orderOut:nil]; [self showSessionWindows]; return YES;
}
- (void)toggleMuteConversation:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (!self.history || !JMValidUIN(peer)) return;
    if ([self.mutedPeers containsObject:peer]) [self.mutedPeers removeObject:peer]; else { [self.mutedPeers addObject:peer]; [self.notificationAlerts clearPeer:peer]; }
    [self.loginDefaults setObject:self.mutedPeers.allObjects forKey:[@"MutedPeers." stringByAppendingString:self.accountUIN ?: @""]]; [self.loginDefaults synchronize];
    [self reloadContacts]; [self updatePeerLabel];
}
- (BOOL)finishDataOperation {
    self.dataOperationInProgress=NO; [self updateSendButton];
    if (self.quitAfterDataOperation) {
        self.quitAfterDataOperation=NO;
        NSApplicationTerminateReply reply=[self applicationShouldTerminate:NSApp];
        if (reply==NSTerminateCancel) [NSApp replyToApplicationShouldTerminate:NO];
        else if (reply==NSTerminateNow) [NSApp replyToApplicationShouldTerminate:YES];
        return NO;
    }
    return !self.terminating;
}
- (void)createBackup:(id)sender {
    if (!self.history || self.dataOperationInProgress || self.sending) return;
    [self flushDrafts]; if (![self canLeaveDrafts]) return;
    NSString *uin=self.accountUIN; JMHistory *history=self.history;
    NSDictionary *manifest=@{@"format":@"JimmMacBackup",@"version":@1,@"uin":uin,@"createdAt":@([NSDate date].timeIntervalSince1970),@"drafts":[self draftSnapshot],@"roster":[self rosterSnapshot],@"preferences":[JMAccountData preferencesForUIN:uin defaults:self.loginDefaults]};
    NSSavePanel *panel=[NSSavePanel savePanel]; panel.allowedFileTypes=@[@"jimmbackup"]; panel.canCreateDirectories=YES; panel.nameFieldStringValue=[NSString stringWithFormat:@"JimmMac-%@.jimmbackup",uin]; panel.title=JML(@"Сохранить резервную копию");
    [panel beginSheetModalForWindow:[self listWindow] completionHandler:^(NSInteger result) {
        if (result!=NSFileHandlingPanelOKButton) return;
        self.dataOperationInProgress=YES; [self updateSendButton]; JMSetLabel(self.statusLabel,JML(@"Создаём резервную копию…"));
        dispatch_async(self.historySearchQueue,^{ NSError *error=nil; BOOL saved=[history writeBackupToURL:panel.URL manifest:manifest error:&error];
            dispatch_async(dispatch_get_main_queue(),^{ if (![self finishDataOperation]) return;
                if (!saved) [self showError:JML(@"Не удалось создать резервную копию") detail:error.localizedDescription];
                else JMSetLabel(self.statusLabel,JML(@"Резервная копия сохранена. Для входа на другом Mac потребуется пароль."));
            });
        });
    }];
}
- (void)restoreBackup:(id)sender {
    if (self.dataOperationInProgress || self.sending) return;
    NSOpenPanel *panel=[NSOpenPanel openPanel]; panel.allowedFileTypes=@[@"jimmbackup"]; panel.allowsMultipleSelection=NO; panel.canChooseDirectories=NO; panel.title=JML(@"Восстановить резервную копию");
    NSWindow *window=self.accountUIN.length ? [self listWindow] : self.loginWindow;
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        if (result!=NSFileHandlingPanelOKButton) return;
        [self inspectBackupURL:panel.URL];
    }];
}
- (void)inspectBackupURL:(NSURL *)url {
    self.dataOperationInProgress=YES; [self updateSendButton];
    dispatch_async(self.historySearchQueue,^{ NSError *error=nil; NSDictionary *manifest=[JMHistory backupManifestAtURL:url error:&error];
        dispatch_async(dispatch_get_main_queue(),^{ if (![self finishDataOperation]) return;
            if (!manifest) { [self showError:JML(@"Не удалось прочитать резервную копию") detail:error.localizedDescription]; return; }
            NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=[NSString stringWithFormat:JML(@"Восстановить данные UIN %@?"),manifest[@"uin"]];
            alert.informativeText=JML(@"История объединится с уже сохранённой без дубликатов. Отличающиеся черновики будут сохранены вместе. Контакты и настройки восстановятся локально; серверный контакт-лист не изменится. После восстановления откроется офлайн-режим.");
            [alert addButtonWithTitle:JML(@"Восстановить")]; [alert addButtonWithTitle:JML(@"Отмена")].keyEquivalent=@"\e";
            if ([alert runModal]==NSAlertFirstButtonReturn) [self restoreBackupURL:url manifest:manifest];
        });
    });
}
- (void)restoreBackupURL:(NSURL *)url manifest:(NSDictionary *)manifest {
    if (self.sending || ![self openOfflineUIN:manifest[@"uin"]]) return;
    NSMutableDictionary *merged=[self.drafts mutableCopy];
    for (NSString *peer in manifest[@"drafts"]) {
        NSString *incoming=manifest[@"drafts"][peer], *existing=JMString(merged[peer]);
        if (!existing.length) merged[peer]=incoming;
        else if (incoming.length && [existing rangeOfString:incoming].location==NSNotFound) merged[peer]=[NSString stringWithFormat:JML(@"%@\n\n— Восстановленный черновик —\n%@"),existing,incoming];
    }
    NSData *draftData=[NSJSONSerialization dataWithJSONObject:merged options:0 error:NULL];
    if (!draftData || draftData.length>8*1024*1024) { [self showError:JML(@"Слишком много черновиков") detail:JML(@"Объединённые черновики превышают 8 МБ. Сократите текущие черновики и повторите восстановление.")]; return; }
    self.dataOperationInProgress=YES; [self updateSendButton]; JMSetLabel(self.statusLabel,JML(@"Восстанавливаем историю…")); JMHistory *history=self.history;
    dispatch_async(self.historySearchQueue,^{ NSError *error=nil; NSUInteger count=[history mergeBackupAtURL:url error:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            if (count==NSNotFound) { if ([self finishDataOperation]) [self showError:JML(@"Восстановление не выполнено") detail:error.localizedDescription]; return; }
            [JMAccountData applyPreferences:manifest[@"preferences"] uin:self.accountUIN defaults:self.loginDefaults];
            NSMutableDictionary *cached=[[self rosterSnapshot] mutableCopy]; NSDictionary *incoming=manifest[@"roster"];
            for (NSString *key in @[@"contacts",@"profiles",@"ownInfo"]) { NSMutableDictionary *values=[JMDictionary(cached[key]) mutableCopy]; [values addEntriesFromDictionary:JMDictionary(incoming[key])]; cached[key]=values; }
            for (NSString *key in @[@"groups",@"serverIDs"]) { NSMutableOrderedSet *values=[NSMutableOrderedSet orderedSetWithArray:JMArray(cached[key])]; [values addObjectsFromArray:JMArray(incoming[key])]; cached[key]=values.array; }
            NSError *cacheError=nil; [[self makeAccountDataForUIN:self.accountUIN] saveRoster:cached error:&cacheError];
            self.drafts=merged; [self persistDraftsNow];
            [self.serverContactIDs removeAllObjects]; [self.serverGroups removeAllObjects]; [self restoreRosterCache];
            [self.conversationPeers addObjectsFromArray:history.peers]; self.unread=[history.unreadCounts mutableCopy];
            NSDictionary *preferences=[JMAccountData preferencesForUIN:self.accountUIN defaults:self.loginDefaults];
            self.favoritePeers=[NSMutableSet setWithArray:JMArray(preferences[@"FavoritePeers"])]; self.mutedPeers=[NSMutableSet setWithArray:JMArray(preferences[@"MutedPeers"])];
            [self.conversationPeers addObjectsFromArray:JMArray(preferences[@"ConversationPeers"])]; [self persistConversationPeers];
            self.favoritesOnlyCheckbox.state=[preferences[@"FavoritesOnly"] boolValue] ? NSOnState : NSOffState;
            self.chatPreferences=[[JMChatPreferences alloc] initWithDefaults:self.loginDefaults]; [self applyChatFont];
            self.notificationAlerts.enabled=[self.loginDefaults boolForKey:@"NotificationsEnabled"]; self.notificationAlerts.contentStyle=[self.loginDefaults stringForKey:@"NotificationContentStyle"];
            self.audioAlerts.enabled=[self.loginDefaults boolForKey:@"SoundsEnabled"];
            self.audioAlerts.presenceEnabled=[self.loginDefaults boolForKey:@"PresenceSoundsEnabled"]; self.audioAlerts.typingEnabled=[self.loginDefaults boolForKey:@"TypingSoundsEnabled"];
            self.audioAlerts.soundInOpenConversation=[self.loginDefaults boolForKey:@"SoundInOpenConversation"]; self.notificationAlerts.dockAttentionEnabled=[self.loginDefaults boolForKey:@"DockAttentionEnabled"];
            [self applyAppearance]; [self updateSoundControls];
            [self refreshGroupChoices]; [self reloadContacts]; [self updateDockBadge]; [self updateSendButton];
            if ([self finishDataOperation]) JMSetLabel(self.statusLabel,cacheError ? JML(@"История восстановлена; контакты не удалось сохранить. Копия остаётся доступна для повтора.") : [NSString stringWithFormat:JML(@"Восстановлено сообщений: %lu. Язык изменится после перезапуска."),(unsigned long)count]);
        });
    });
}
- (void)setTranscriptAroundID:(NSString *)identifier {
    NSUInteger index=[self.history indexOfMessage:identifier peer:self.selectedPeer];
    if (index==NSNotFound) return;
    self.transcriptOffset=index>40 ? index-40 : 0; self.transcriptTail=NO;
}
- (void)loadEarlierMessages:(id)sender {
    self.transcriptTail=NO; self.transcriptOffset=self.transcriptOffset>200 ? self.transcriptOffset-200 : 0;
    self.transcript.selectedRange=NSMakeRange(0,0); [self renderTranscript]; [self.transcript scrollRangeToVisible:NSMakeRange(0,0)];
}
- (void)loadNewerMessages:(id)sender {
    NSUInteger count=[self.history countForPeer:self.selectedPeer ?: @""];
    self.transcriptOffset=MIN(self.transcriptOffset+200,count>200 ? count-200 : 0); self.transcriptTail=self.transcriptOffset+200>=count;
    self.transcript.selectedRange=NSMakeRange(0,0); [self renderTranscript]; [self.transcript scrollRangeToVisible:NSMakeRange(0,0)];
}
- (void)toggleFavorite:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (!self.history || !JMValidUIN(peer)) return;
    if ([self.favoritePeers containsObject:peer]) [self.favoritePeers removeObject:peer]; else [self.favoritePeers addObject:peer];
    if (self.accountUIN.length) { [self.loginDefaults setObject:[self.favoritePeers allObjects] forKey:[@"FavoritePeers." stringByAppendingString:self.accountUIN]]; [self.loginDefaults synchronize]; }
    [self reloadContacts];
}
- (void)toggleOnlineFilter:(id)sender {
    if (![sender isKindOfClass:[NSButton class]]) self.onlineOnlyCheckbox.state=self.onlineOnlyCheckbox.state==NSOnState ? NSOffState : NSOnState;
    if (self.accountUIN.length) [self.loginDefaults setBool:self.onlineOnlyCheckbox.state==NSOnState forKey:[@"OnlineOnly." stringByAppendingString:self.accountUIN]];
    [self reloadContacts];
}
- (void)toggleFavoritesFilter:(id)sender {
    if (![sender isKindOfClass:[NSButton class]]) self.favoritesOnlyCheckbox.state=self.favoritesOnlyCheckbox.state==NSOnState ? NSOffState : NSOnState;
    if (self.accountUIN.length) [self.loginDefaults setBool:self.favoritesOnlyCheckbox.state==NSOnState forKey:[@"FavoritesOnly." stringByAppendingString:self.accountUIN]];
    [self reloadContacts];
}
- (void)toggleEmoticons:(id)sender {
    self.chatPreferences.emoticonsEnabled=sender==self.emoticonsCheckbox ? self.emoticonsCheckbox.state==NSOnState : !self.chatPreferences.emoticonsEnabled;
    self.emoticonsCheckbox.state=self.chatPreferences.emoticonsEnabled ? NSOnState : NSOffState; [self renderTranscript]; [self syncAppearanceControls];
}
- (JMUpdateChecker *)makeUpdateChecker { return [[JMUpdateChecker alloc] init]; }
- (BOOL)automaticUpdatesEnabled {
    id value=[self.loginDefaults objectForKey:@"AutomaticallyCheckUpdates"];
    return !value || [value boolValue];
}
- (void)scheduleAutomaticUpdateChecks {
    [self.updateTimer invalidate]; self.updateTimer=nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(automaticUpdateTick:) object:nil];
    if (![self automaticUpdatesEnabled] || self.terminating) return;
    [self performSelector:@selector(automaticUpdateTick:) withObject:nil afterDelay:10];
    self.updateTimer=[NSTimer scheduledTimerWithTimeInterval:3600 target:self selector:@selector(automaticUpdateTick:) userInfo:nil repeats:YES];
}
- (void)toggleAutomaticUpdates:(id)sender {
    BOOL enabled=![self automaticUpdatesEnabled]; [self.loginDefaults setBool:enabled forKey:@"AutomaticallyCheckUpdates"];
    if (!enabled) self.pendingUpdateRelease=nil; [self scheduleAutomaticUpdateChecks];
}
- (BOOL)canPresentAutomaticUpdate {
    return !self.terminating && !self.loginPending && (self.client.connected || self.offlineMode) && [NSApp isActive] && (self.chatWindow.isKeyWindow || self.rosterWindow.isKeyWindow) && !self.chatWindow.attachedSheet && !self.rosterWindow.attachedSheet && ![NSApp modalWindow];
}
- (void)presentPendingUpdateIfPossible {
    dispatch_async(dispatch_get_main_queue(),^{
        NSDictionary *release=self.pendingUpdateRelease;
        if (!release || ![self automaticUpdatesEnabled] || ![self canPresentAutomaticUpdate]) return;
        self.pendingUpdateRelease=nil;
        NSString *version=release[@"version"];
        if ([[self.loginDefaults stringForKey:@"UpdateNoticeShownVersion"] isEqual:version]) return;
        [self.loginDefaults setObject:version forKey:@"UpdateNoticeShownVersion"]; [self.loginDefaults synchronize];
        [self presentUpdateRelease:release automatic:YES];
    });
}
- (void)automaticUpdateTick:(id)sender {
    if (![self automaticUpdatesEnabled] || self.terminating) return;
    [self presentPendingUpdateIfPossible];
    NSDate *last=[self.loginDefaults objectForKey:@"LastSuccessfulUpdateCheck"];
    NSTimeInterval age=[last isKindOfClass:[NSDate class]] ? -last.timeIntervalSinceNow : DBL_MAX;
    if ((age>=0 && age<6*3600) || self.updateRetryDate.timeIntervalSinceNow>0) return;
    [self checkUpdatesAutomatically:YES];
}
- (void)createUpdateWindow {
    NSRect frame=NSMakeRect(0,0,500,250);
    self.updateWindow=[[JMWindow alloc] initWithContentRect:frame styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
    self.updateWindow.title=JML(@"Проверка обновлений");
    self.updateWindow.releasedWhenClosed=NO;
    self.updateWindow.delegate=self;
    self.updateWindow.contentView=[[JMWindowView alloc] initWithFrame:frame];
    NSView *root=self.updateWindow.contentView;

    self.updateProgress=[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20,203,22,22)];
    self.updateProgress.style=NSProgressIndicatorSpinningStyle;
    self.updateProgress.indeterminate=YES;
    self.updateProgress.hidden=YES;
    [root addSubview:self.updateProgress];
    self.updateHeading=JMLabel(@"",NSMakeRect(52,199,428,28),16,YES);
    [root addSubview:self.updateHeading];

    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(19,57,462,134)];
    scroll.hasVerticalScroller=YES;
    scroll.autohidesScrollers=YES;
    scroll.borderType=NSBezelBorder;
    self.updateDetail=[[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
    self.updateDetail.editable=NO;
    self.updateDetail.selectable=YES;
    self.updateDetail.font=[NSFont systemFontOfSize:13];
    self.updateDetail.textContainerInset=NSMakeSize(9,8);
    self.updateDetail.autoresizingMask=NSViewWidthSizable;
    self.updateDetail.textContainer.widthTracksTextView=YES;
    scroll.documentView=self.updateDetail;
    [root addSubview:scroll];

    NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(20,13,117,29),self,@selector(closeUpdateWindow:));
    close.keyEquivalent=@"\e";
    [root addSubview:close];
    self.updateAction=JMButton(@"",NSMakeRect(310,13,171,29),self,@selector(updateWindowAction:));
    [root addSubview:self.updateAction];
    [self.updateWindow center];
}
- (void)closeUpdateWindow:(id)sender { [self.updateWindow close]; }
- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object==self.updateWindow) {
        [self.updateProgress stopAnimation:nil];
        self.updateProgress.hidden=YES;
    }
}
- (void)updateWindowAction:(id)sender {
    if (self.updateReleaseURL) [self openExternalURL:self.updateReleaseURL];
    else [self checkForUpdates:nil];
}
- (void)checkForUpdates:(id)sender {
    if (self.terminating) return;
    if (!self.updateWindow) [self createUpdateWindow];
    self.manualUpdateRequested=YES;
    self.updateReleaseURL=nil;
    self.updateAction.hidden=YES;
    JMSetLabel(self.updateHeading,JML(@"Проверяем обновления…"));
    self.updateDetail.string=JML(@"Запрашиваем последний релиз JimmMac на GitHub.");
    self.updateProgress.hidden=NO;
    JMRefreshUtilityWindow(self.updateWindow);
    [self.updateWindow makeKeyAndOrderFront:nil];
    [self.updateProgress startAnimation:nil];
    [self.updateWindow displayIfNeeded];
    [self checkUpdatesAutomatically:NO];
}
- (void)finishManualUpdateWithTitle:(NSString *)title detail:(NSString *)detail releaseURL:(NSURL *)url retry:(BOOL)retry {
    [self.updateProgress stopAnimation:nil];
    self.updateProgress.hidden=YES;
    JMSetLabel(self.updateHeading,title);
    self.updateDetail.string=detail;
    [self.updateDetail scrollRangeToVisible:NSMakeRange(0,0)];
    self.updateReleaseURL=url;
    self.updateAction.hidden=!url && !retry;
    if (url || retry) self.updateAction.title=url ? JML(@"Открыть релиз") : JML(@"Повторить");
}

- (void)checkUpdatesAutomatically:(BOOL)automatic {
    if (self.checkingUpdates || self.terminating) return; self.checkingUpdates=YES;
    if (!self.updateChecker) self.updateChecker=[self makeUpdateChecker];
    [self.updateChecker check:^(NSDictionary *release,NSError *error) {
        self.checkingUpdates=NO; if (self.terminating) return;
        BOOL manual=self.manualUpdateRequested;
        BOOL manualVisible=manual && self.updateWindow.isVisible;
        self.manualUpdateRequested=NO;
        if (error) {
            if (automatic) self.updateRetryDate=[NSDate dateWithTimeIntervalSinceNow:3600];
            if (manualVisible) [self finishManualUpdateWithTitle:JML(@"Не удалось проверить обновления")
                detail:JML(@"Проверьте подключение к интернету и повторите позже. Релизы также доступны на github.com/MiChiRose/JimmMac.")
                releaseURL:nil retry:YES];
            return;
        }
        self.updateRetryDate=nil;
        [self.loginDefaults setObject:[NSDate date] forKey:@"LastSuccessfulUpdateCheck"];
        NSString *current=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.16.0";
        BOOL newer=[JMUpdateChecker compareVersion:release[@"version"] to:current]==NSOrderedDescending;
        if (manualVisible) {
            if (newer) { self.pendingUpdateRelease=nil; [self.loginDefaults setObject:release[@"version"] forKey:@"UpdateNoticeShownVersion"]; }
            [self presentUpdateRelease:release automatic:NO];
        } else if (automatic && !manual) {
            if ([self automaticUpdatesEnabled] && newer && ![[self.loginDefaults stringForKey:@"UpdateNoticeShownVersion"] isEqual:release[@"version"]]) {
                self.pendingUpdateRelease=release; [self presentPendingUpdateIfPossible];
            }
        }
    }];
}
- (void)presentUpdateRelease:(NSDictionary *)release automatic:(BOOL)automatic {
    NSString *current=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.16.0";
    BOOL newer=[JMUpdateChecker compareVersion:release[@"version"] to:current]==NSOrderedDescending;
    NSString *title=newer ? [NSString stringWithFormat:JML(@"Доступен JimmMac %@"),release[@"version"]] : JML(@"У вас актуальная версия JimmMac");
    NSString *notes=JMString(release[@"notes"]); if (notes.length>1600) notes=[[notes substringToIndex:1600] stringByAppendingString:@"…"];
    NSString *detail=newer ? [NSString stringWithFormat:JML(@"Установлена версия %@.\n\n%@\n\nСкачайте обновление на GitHub. Установка выполняется вручную."),current,notes] : [NSString stringWithFormat:JML(@"Установлена %@. Последний опубликованный релиз — %@."),current,release[@"version"]];
    if (!automatic) {
        [self finishManualUpdateWithTitle:title detail:detail releaseURL:newer ? release[@"url"] : nil retry:NO];
        return;
    }
    NSAlert *alert=[[NSAlert alloc] init];
    alert.messageText=title; alert.informativeText=detail;
    [alert addButtonWithTitle:newer ? JML(@"Открыть релиз") : JML(@"Хорошо")];
    if (newer) { NSButton *cancel=[alert addButtonWithTitle:JML(@"Позже")]; cancel.keyEquivalent=@"\e"; }
    if ([alert runModal]==NSAlertFirstButtonReturn && newer) [self openExternalURL:release[@"url"]];
}
- (void)exportConversation:(NSMenuItem *)sender {
    if (!self.selectedPeer.length || !self.history || self.exportingHistory) return;
    NSString *peer=[self.selectedPeer copy], *account=[self.accountUIN copy], *name=JMName(self.contacts[peer] ?: @{@"aimId":peer});
    BOOL html=[sender.representedObject isEqual:@"html"]; JMHistory *history=self.history;
    NSSavePanel *panel=[NSSavePanel savePanel]; panel.title=JML(@"Экспорт переписки"); panel.allowedFileTypes=@[html ? @"html" : @"txt"]; panel.canCreateDirectories=YES;
    panel.nameFieldStringValue=[NSString stringWithFormat:@"JimmMac-%@.%@",peer,html ? @"html" : @"txt"];
    [panel beginSheetModalForWindow:[self listWindow] completionHandler:^(NSInteger result) {
        if (result!=NSFileHandlingPanelOKButton) return;
        NSURL *destination=panel.URL; self.exportingHistory=YES;
        dispatch_async(self.historySearchQueue,^{
            NSError *error=nil; BOOL saved=[history exportPeer:peer name:name account:account ?: @"" html:html toURL:destination error:&error];
            dispatch_async(dispatch_get_main_queue(),^{ self.exportingHistory=NO; if (self.terminating) return;
                if (!saved) [self showError:JML(@"Не удалось экспортировать переписку") detail:error.localizedDescription];
                else if (history==self.history) JMSetLabel(self.statusLabel,[NSString stringWithFormat:JML(@"Переписка сохранена: %@"),destination.lastPathComponent]);
            });
        });
    }];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.client = [[JMAPIClient alloc] init]; self.client.delegate = self;
    self.loginStore=[self makeLoginStore]; self.loginDefaults=[self makeLoginDefaults]; JMSetTheme([self.loginDefaults stringForKey:@"InterfaceAppearance"]); JMSetLanguage([self.loginDefaults stringForKey:@"InterfaceLanguage"]);
    self.loginStoreQueue=dispatch_queue_create("online.jimm.login-keychain",DISPATCH_QUEUE_SERIAL);
    self.audioAlerts=[self makeAudioAlerts]; self.notificationAlerts=[self makeNotificationAlerts]; self.notificationAlerts.delegate=self;
    self.chatPreferences=[[JMChatPreferences alloc] initWithDefaults:self.loginDefaults];
    self.historySearchQueue=dispatch_queue_create("online.jimm.history-search",DISPATCH_QUEUE_SERIAL);
    self.draftSaveQueue=dispatch_queue_create("online.jimm.drafts",DISPATCH_QUEUE_SERIAL);
    self.contacts = [NSMutableDictionary dictionary]; self.drafts = [NSMutableDictionary dictionary]; self.unread = [NSMutableDictionary dictionary];
    self.serverContactIDs = [NSMutableSet set]; self.conversationPeers = [NSMutableSet set];
    self.serverGroups=[NSMutableArray array]; self.favoritePeers=[NSMutableSet set]; self.mutedPeers=[NSMutableSet set]; self.transcriptTail=YES;
    self.ownInfo=[NSMutableDictionary dictionary]; self.profileDates=[NSMutableDictionary dictionary]; self.profileTexts=[NSMutableDictionary dictionary]; self.incomingTyping=[NSMutableDictionary dictionary];
    if (JMFlowerImage()) [NSApp setApplicationIconImage:JMFlowerImage()];
    [self createMenu]; [self createLoginWindow]; [self createChatWindow];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
    [self.loginWindow center]; [self.loginWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    NSUserNotification *launchNotification=notification.userInfo[NSApplicationLaunchUserNotificationKey];
    if ([launchNotification isKindOfClass:[NSUserNotification class]]) [self.notificationAlerts handleActivation:launchNotification];
    self.autoAway=[[JMAutoAway alloc] init];
    self.autoAwayTimer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(autoAwayTick:) userInfo:nil repeats:YES];
    [self startAutomaticLogin]; [self scheduleAutomaticUpdateChecks];
}
- (JMLoginStore *)makeLoginStore { return [[JMLoginStore alloc] init]; }
- (NSUserDefaults *)makeLoginDefaults { return [NSUserDefaults standardUserDefaults]; }
- (JMHistory *)makeHistoryForUIN:(NSString *)uin { return [[JMHistory alloc] initWithUIN:uin root:nil]; }
- (JMAvatarStore *)makeAvatarStore { return [[JMAvatarStore alloc] init]; }
- (JMAudioAlerts *)makeAudioAlerts { return [[JMAudioAlerts alloc] init]; }
- (JMNotificationAlerts *)makeNotificationAlerts { return [[JMNotificationAlerts alloc] init]; }
- (void)createMenu {
    NSMenu *bar = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"JimmMac" action:NULL keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"JimmMac"];
    [appMenu addItemWithTitle:JML(@"О JimmMac") action:@selector(about:) keyEquivalent:@""];
    NSMenuItem *updates=[appMenu addItemWithTitle:JML(@"Проверить обновления…") action:@selector(checkForUpdates:) keyEquivalent:@""]; updates.target=self;
    NSMenuItem *autoUpdates=[appMenu addItemWithTitle:JML(@"Автоматически проверять обновления") action:@selector(toggleAutomaticUpdates:) keyEquivalent:@""]; autoUpdates.target=self; autoUpdates.toolTip=JML(@"При запуске и каждые 6 часов. Окно появляется только для новой версии; установка вручную");
    NSMenuItem *storage=[appMenu addItemWithTitle:JML(@"Локальные данные…") action:@selector(showStorage:) keyEquivalent:@""]; storage.target=self;
    NSMenuItem *preferences=[appMenu addItemWithTitle:JML(@"Настройки…") action:@selector(showPreferences:) keyEquivalent:@","]; preferences.target=self;
    NSMenuItem *myProfile=[appMenu addItemWithTitle:JML(@"Мой профиль…") action:@selector(showOwnProfile:) keyEquivalent:@"i"]; myProfile.target=self;
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *logout = [appMenu addItemWithTitle:JML(@"Выйти из аккаунта") action:@selector(logout:) keyEquivalent:@"L"]; [logout setTarget:self]; logout.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:JML(@"Скрыть JimmMac") action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers=[appMenu addItemWithTitle:JML(@"Скрыть остальные") action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask];
    [appMenu addItemWithTitle:JML(@"Показать все") action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:JML(@"Завершить JimmMac") action:@selector(terminate:) keyEquivalent:@"q"];
    [appItem setSubmenu:appMenu]; [bar addItem:appItem];
    NSMenuItem *fileItem=[[NSMenuItem alloc] initWithTitle:JML(@"Файл") action:NULL keyEquivalent:@""];
    NSMenu *file=[[NSMenu alloc] initWithTitle:JML(@"Файл")];
    for (NSDictionary *entry in @[@{@"title":JML(@"Перейти к дню…"),@"action":@"showHistoryDay:"},@{@"title":JML(@"Закладки сообщений…"),@"action":@"showBookmarks:"}]) { NSMenuItem *item=[file addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self; }
    NSMenuItem *recover=[file addItemWithTitle:JML(@"Восстановить сообщения сессии…") action:@selector(restoreRecentMessages:) keyEquivalent:@""]; recover.target=self;
    NSMenuItem *write=[file addItemWithTitle:JML(@"Написать по UIN…") action:@selector(openConversation:) keyEquivalent:@"n"]; write.target=self;
    NSMenuItem *add=[file addItemWithTitle:JML(@"Добавить контакт…") action:@selector(addContact:) keyEquivalent:@"N"]; add.target=self; add.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    [file addItem:[NSMenuItem separatorItem]];
    for (NSDictionary *entry in @[@{@"title":JML(@"Экспорт переписки в TXT…"),@"format":@"txt"},@{@"title":JML(@"Экспорт переписки в HTML…"),@"format":@"html"}]) {
        NSMenuItem *item=[file addItemWithTitle:entry[@"title"] action:@selector(exportConversation:) keyEquivalent:@""]; item.target=self; item.representedObject=entry[@"format"];
    }
    [file addItem:[NSMenuItem separatorItem]];
    for (NSDictionary *entry in @[@{@"title":JML(@"Открыть историю офлайн…"),@"action":@"openOfflineHistory:"},@{@"title":JML(@"Создать резервную копию…"),@"action":@"createBackup:"},@{@"title":JML(@"Восстановить резервную копию…"),@"action":@"restoreBackup:"}]) { NSMenuItem *item=[file addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self; }
    fileItem.submenu=file; [bar addItem:fileItem];
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:JML(@"Правка") action:NULL keyEquivalent:@""];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:JML(@"Правка")];
    [edit addItemWithTitle:JML(@"Отменить") action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo=[edit addItemWithTitle:JML(@"Повторить") action:@selector(redo:) keyEquivalent:@"Z"]; redo.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    [edit addItem:[NSMenuItem separatorItem]];
    [edit addItemWithTitle:JML(@"Вырезать") action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:JML(@"Копировать") action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:JML(@"Вставить") action:@selector(paste:) keyEquivalent:@"v"];
    NSMenuItem *plain=[edit addItemWithTitle:JML(@"Вставить без оформления") action:@selector(pasteAsPlainText:) keyEquivalent:@"V"]; plain.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask;
    [edit addItemWithTitle:JML(@"Выбрать всё") action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenuItem *sendMessage=[edit addItemWithTitle:JML(@"Отправить сообщение") action:@selector(send:) keyEquivalent:@"\r"]; sendMessage.target=self;
    [edit addItem:[NSMenuItem separatorItem]];
    NSMenuItem *find=[edit addItemWithTitle:JML(@"Найти в истории…") action:@selector(showHistorySearch:) keyEquivalent:@"f"]; find.target=self;
    NSMenuItem *readAll=[edit addItemWithTitle:JML(@"Пометить всё прочитанным") action:@selector(markAllRead:) keyEquivalent:@""]; readAll.target=self;
    [editItem setSubmenu:edit]; [bar addItem:editItem];
    NSMenuItem *viewItem=[[NSMenuItem alloc] initWithTitle:JML(@"Вид") action:NULL keyEquivalent:@""];
    NSMenu *viewMenu=[[NSMenu alloc] initWithTitle:JML(@"Вид")];
    NSMenuItem *contactTab=[viewMenu addItemWithTitle:JML(@"Контакты") action:@selector(showContactsSection:) keyEquivalent:@"1"]; contactTab.target=self;
    NSMenuItem *chatTab=[viewMenu addItemWithTitle:JML(@"Переписки") action:@selector(showConversationsSection:) keyEquivalent:@"2"]; chatTab.target=self;
    [viewMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *filter=[viewMenu addItemWithTitle:JML(@"Поиск в списке") action:@selector(focusContactSearch:) keyEquivalent:@"l"]; filter.target=self;
    for (NSDictionary *entry in @[@{@"title":JML(@"Только в сети"),@"action":@"toggleOnlineFilter:"},@{@"title":JML(@"Только избранные"),@"action":@"toggleFavoritesFilter:"},@{@"title":JML(@"Классические смайлики"),@"action":@"toggleEmoticons:"}]) {
        NSMenuItem *item=[viewMenu addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    NSMenuItem *unreadFilter=[viewMenu addItemWithTitle:JML(@"Только непрочитанные") action:@selector(toggleUnreadFilter:) keyEquivalent:@"u"]; unreadFilter.target=self;
    unreadFilter.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    NSMenuItem *collapse=[viewMenu addItemWithTitle:JML(@"Свернуть или развернуть группу") action:@selector(toggleSelectedGroup:) keyEquivalent:@""]; collapse.target=self;
    NSMenuItem *appearanceItem=[[NSMenuItem alloc] initWithTitle:JML(@"Оформление") action:NULL keyEquivalent:@""]; NSMenu *appearance=[[NSMenu alloc] initWithTitle:JML(@"Оформление")];
    NSArray *themeNames=@[JML(@"Текущий"),JML(@"Ностальгия · ICQ для Mac 2011"),JML(@"Ностальгия · ICQ Pro 2003b"),@"QIP",@"Jimm"], *themeIDs=JMThemeIdentifiers();
    for (NSUInteger i=0;i<themeIDs.count;i++) { NSMenuItem *item=[appearance addItemWithTitle:themeNames[i] action:@selector(changeAppearance:) keyEquivalent:@""]; item.target=self; item.representedObject=themeIDs[i]; }
    appearanceItem.submenu=appearance; [viewMenu addItem:appearanceItem];
    NSMenuItem *languageItem=[[NSMenuItem alloc] initWithTitle:JML(@"Язык интерфейса") action:NULL keyEquivalent:@""]; NSMenu *languageMenu=[[NSMenu alloc] initWithTitle:JML(@"Язык интерфейса")];
    NSArray *languageNames=@[JML(@"Русский"),@"English",JML(@"Українська"),JML(@"Беларуская")], *languages=@[@"ru",@"en",@"uk",@"be"];
    for (NSUInteger i=0;i<languages.count;i++) { NSMenuItem *item=[languageMenu addItemWithTitle:languageNames[i] action:@selector(changeLanguage:) keyEquivalent:@""]; item.target=self; item.representedObject=languages[i]; }
    languageItem.submenu=languageMenu; [viewMenu addItem:languageItem];
    viewItem.submenu=viewMenu; [bar addItem:viewItem];
    NSMenuItem *contactsItem=[[NSMenuItem alloc] initWithTitle:JML(@"Контакты") action:NULL keyEquivalent:@""];
    NSMenu *contactsMenu=[[NSMenu alloc] initWithTitle:JML(@"Контакты")];
    for (NSDictionary *entry in @[@{@"title":JML(@"Добавить по UIN…"),@"action":@"addContact:"},@{@"title":JML(@"Переименовать контакт…"),@"action":@"renameContact:"},@{@"title":JML(@"Переместить в группу…"),@"action":@"moveContact:"},@{@"title":JML(@"Удалить из контактов…"),@"action":@"removeContact:"}]) {
        NSMenuItem *item=[contactsMenu addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    NSMenuItem *favorite=[contactsMenu addItemWithTitle:JML(@"Добавить в избранное") action:@selector(toggleFavorite:) keyEquivalent:@""]; favorite.target=self;
    NSMenuItem *mute=[contactsMenu addItemWithTitle:JML(@"Отключить уведомления") action:@selector(toggleMuteConversation:) keyEquivalent:@""]; mute.target=self;
    [contactsMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *block=[contactsMenu addItemWithTitle:JML(@"Блокировка контакта…") action:@selector(toggleContactBlock:) keyEquivalent:@""]; block.target=self;
    NSMenuItem *blocked=[contactsMenu addItemWithTitle:JML(@"Список блокировки…") action:@selector(showBlockedContacts:) keyEquivalent:@""]; blocked.target=self;
    NSMenuItem *groups=[contactsMenu addItemWithTitle:JML(@"Управление группами…") action:@selector(showGroups:) keyEquivalent:@""]; groups.target=self;
    [contactsItem setSubmenu:contactsMenu]; [bar addItem:contactsItem];
    NSMenuItem *soundsItem=[[NSMenuItem alloc] initWithTitle:JML(@"Звуки") action:NULL keyEquivalent:@""];
    NSMenu *sounds=[[NSMenu alloc] initWithTitle:JML(@"Звуки")];
    for (NSDictionary *item in @[@{@"title":JML(@"Звуковые оповещения"),@"key":@"enabled"},@{@"title":JML(@"Появление и выход контактов"),@"key":@"presenceEnabled"},@{@"title":JML(@"Набор текста"),@"key":@"typingEnabled"}]) {
        NSMenuItem *option=[sounds addItemWithTitle:item[@"title"] action:@selector(toggleSoundOption:) keyEquivalent:@""];
        option.target=self; option.representedObject=item[@"key"];
    }
    [sounds addItem:[NSMenuItem separatorItem]];
    NSArray *events=@[@"message",@"online",@"offline",@"typing"];
    NSArray *titles=@[JML(@"Прослушать: сообщение"),JML(@"Прослушать: в сети"),JML(@"Прослушать: отключился"),JML(@"Прослушать: печатает")];
    for (NSUInteger i=0;i<events.count;i++) {
        NSMenuItem *sample=[sounds addItemWithTitle:titles[i] action:@selector(previewSound:) keyEquivalent:@""];
        sample.target=self; sample.representedObject=events[i];
    }
    [soundsItem setSubmenu:sounds]; [bar addItem:soundsItem];
    NSMenuItem *windowItem=[[NSMenuItem alloc] initWithTitle:JML(@"Окно") action:NULL keyEquivalent:@""];
    NSMenu *windowMenu=[[NSMenu alloc] initWithTitle:JML(@"Окно")];
    [windowMenu addItemWithTitle:JML(@"Свернуть") action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:JML(@"Закрыть окно") action:@selector(performClose:) keyEquivalent:@"w"];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *show=[windowMenu addItemWithTitle:JML(@"Открыть JimmMac") action:@selector(showMainWindow:) keyEquivalent:@"0"]; show.target=self;
    [windowItem setSubmenu:windowMenu]; [bar addItem:windowItem];
    [NSApp setWindowsMenu:windowMenu];
    NSMenuItem *helpItem=[[NSMenuItem alloc] initWithTitle:JML(@"Справка") action:NULL keyEquivalent:@""];
    NSMenu *help=[[NSMenu alloc] initWithTitle:JML(@"Справка")];
    for (NSDictionary *entry in @[@{@"title":JML(@"Диагностика…"),@"action":@"showDiagnostics:"},@{@"title":JML(@"Сочетания клавиш…"),@"action":@"showKeyboardHelp:"},@{@"title":JML(@"Jimm.online — сайт и регистрация…"),@"action":@"openSite:"},@{@"title":JML(@"Telegraphica для Mac…"),@"action":@"openTelegraphica:"}]) {
        NSMenuItem *item=[help addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    helpItem.submenu=help; [bar addItem:helpItem]; [NSApp setHelpMenu:help];
    [NSApp setMainMenu:bar];
}
- (void)showStorage:(id)sender {
    if (!self.history) return;
    if (!self.storageWindow) {
        self.storageWindow=[[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,600,400) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO]; self.storageWindow.title=JML(@"Локальные данные — JimmMac"); self.storageWindow.releasedWhenClosed=NO; self.storageWindow.delegate=self; self.storageWindow.contentView=[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,600,400)]; NSView *root=self.storageWindow.contentView;
        self.storageSummary=JMLabel(@"",NSMakeRect(24,316,552,64),13,NO); [[self.storageSummary cell] setWraps:YES]; [root addSubview:self.storageSummary];
        NSButton *clear=JMButton(JML(@"Очистить кеш аватаров"),NSMakeRect(18,274,254,32),self,@selector(clearAvatarCache:)); clear.toolTip=JML(@"Удалить только скачанные изображения. При подключении они загрузятся снова"); [root addSubview:clear];
        [root addSubview:JMLabel(JML(@"Удаление локальной истории"),NSMakeRect(24,236,552,24),15,YES)];
        self.storageScopePopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(20,192,556,30) pullsDown:NO]; [self.storageScopePopup addItemsWithTitles:@[JML(@"Все переписки"),JML(@"Текущая переписка")]]; self.storageScopePopup.autoenablesItems=NO; [root addSubview:self.storageScopePopup];
        self.storageFromDate=[self datePickerAt:NSMakeRect(24,148,220,24) action:NULL]; self.storageFromDate.dateValue=[NSDate dateWithTimeIntervalSince1970:0]; [root addSubview:self.storageFromDate];
        [root addSubview:JMLabel(@"—",NSMakeRect(266,149,20,22),13,NO)]; self.storageUntilDate=[self datePickerAt:NSMakeRect(306,148,220,24) action:NULL]; [root addSubview:self.storageUntilDate];
        self.storageBackupCheckbox=JMCheckbox(JML(@"Сохранить резервную копию перед удалением"),NSMakeRect(24,108,552,24),nil,NULL); self.storageBackupCheckbox.state=NSOnState; [root addSubview:self.storageBackupCheckbox];
        self.storageFeedback=JMLabel(JML(@"Удаление затрагивает только этот Mac. Сохранённые копии и серверные контакты не меняются."),NSMakeRect(24,60,552,40),11,NO); [[self.storageFeedback cell] setWraps:YES]; [root addSubview:self.storageFeedback];
        self.storageDeleteButton=JMButton(JML(@"Удалить за период…"),NSMakeRect(18,14,252,32),self,@selector(confirmHistoryDeletion:)); [root addSubview:self.storageDeleteButton];
        NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(444,14,138,32),self,@selector(closeStorage:)); close.keyEquivalent=@"\e"; [root addSubview:close];
        JMDecorateUtilityWindow(self.storageWindow,JML(@"Локальные данные")); [self.storageWindow center];
    }
    [self.storageScopePopup itemAtIndex:1].enabled=self.selectedPeer.length>0; if (!self.selectedPeer.length) [self.storageScopePopup selectItemAtIndex:0];
    [self refreshStorage:nil]; JMRefreshUtilityWindow(self.storageWindow); [self.storageWindow makeKeyAndOrderFront:nil];
}
- (void)refreshStorage:(id)sender {
    NSDictionary *stats=[self.history storageStatistics];
    JMSetLabel(self.storageSummary,[NSString stringWithFormat:JML(@"Сообщений: %@\nИстория: %@ · Кеш аватаров: %@\nОригинал прежней JSON-истории: %@ (сохраняется отдельно)"),stats[@"messages"], [NSByteCountFormatter stringFromByteCount:[stats[@"bytes"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile],[NSByteCountFormatter stringFromByteCount:(long long)[self.avatars cacheBytes] countStyle:NSByteCountFormatterCountStyleFile],[NSByteCountFormatter stringFromByteCount:[stats[@"legacyBytes"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]]);
    if (self.history.loadError) JMSetLabel(self.storageSummary,JML(@"История недоступна: не удалось прочитать файл."));
    self.storageDeleteButton.enabled=self.history && !self.history.loadError && !self.dataOperationInProgress && !self.sending;
}
- (void)closeStorage:(id)sender { [self.storageWindow orderOut:nil]; }
- (void)clearAvatarCache:(id)sender {
    if (self.dataOperationInProgress) return; NSError *error=nil;
    if (![self.avatars clearCache:&error]) [self showError:JML(@"Не удалось очистить кеш") detail:error.localizedDescription];
    else JMSetLabel(self.storageFeedback,JML(@"Кеш аватаров очищен. История и контакты сохранены.")); [self refreshStorage:nil];
}
- (void)confirmHistoryDeletion:(id)sender {
    if (!self.history || self.dataOperationInProgress || self.sending) return;
    NSDate *from=[self startOfDay:self.storageFromDate.dateValue], *until=[self dayAfter:self.storageUntilDate.dateValue];
    if ([from compare:until]!=NSOrderedAscending) { JMSetLabel(self.storageFeedback,JML(@"Начальная дата должна быть не позже конечной.")); return; }
    NSString *peer=self.storageScopePopup.indexOfSelectedItem==1 ? self.selectedPeer : nil;
    NSUInteger count=[self.history countMessagesForPeer:peer from:from until:until]; if (!count) { JMSetLabel(self.storageFeedback,JML(@"За выбранный период сообщений нет.")); return; }
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=[NSString stringWithFormat:JML(@"Удалить сообщений: %lu?"),(unsigned long)count]; alert.informativeText=JML(@"Будут удалены сообщения и их закладки за выбранные даты включительно. Черновики и контакты останутся. Отменить удаление можно только восстановлением резервной копии.");
    [alert addButtonWithTitle:JML(@"Удалить")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
    if ([alert runModal]!=NSAlertFirstButtonReturn) return;
    if (self.storageBackupCheckbox.state==NSOnState) {
        JMHistory *originalHistory=self.history;
        NSSavePanel *panel=[NSSavePanel savePanel]; panel.allowedFileTypes=@[@"jimmbackup"]; panel.nameFieldStringValue=@"JimmMac-before-cleanup.jimmbackup"; panel.title=JML(@"Сохранить резервную копию");
        [panel beginSheetModalForWindow:self.storageWindow completionHandler:^(NSInteger result) { if (result==NSFileHandlingPanelOKButton && originalHistory==self.history) [self deleteHistoryPeer:peer from:from until:until backupURL:panel.URL]; }];
    } else [self deleteHistoryPeer:peer from:from until:until backupURL:nil];
}
- (void)deleteHistoryPeer:(NSString *)peer from:(NSDate *)from until:(NSDate *)until backupURL:(NSURL *)url {
    if (!self.history || self.dataOperationInProgress || self.sending) return; [self flushDrafts]; if (![self canLeaveDrafts]) return;
    JMHistory *history=self.history; NSString *account=[self.accountUIN copy];
    NSDictionary *manifest=@{@"format":@"JimmMacBackup",@"version":@1,@"uin":account,@"createdAt":@([NSDate date].timeIntervalSince1970),@"drafts":[self draftSnapshot],@"roster":[self rosterSnapshot],@"preferences":[JMAccountData preferencesForUIN:account defaults:self.loginDefaults]};
    self.dataOperationInProgress=YES; self.historySearchGeneration++; [self updateSendButton]; [self refreshStorage:nil]; JMSetLabel(self.storageFeedback,JML(@"Обрабатываем локальную историю…"));
    dispatch_async(self.historySearchQueue,^{ NSError *error=nil; BOOL ok=[history deleteMessagesForPeer:peer from:from until:until backupURL:url manifest:manifest error:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            if (history==self.history && [account isEqual:self.accountUIN]) {
                [self.unread removeAllObjects]; [self.unread addEntriesFromDictionary:self.history.unreadCounts]; [self.notificationAlerts clear]; self.transcriptTail=YES; self.highlightedMessageID=nil; self.transcript.selectedRange=NSMakeRange(0,0); [self renderTranscript]; [self reloadContacts]; [self updateDockBadge];
                self.historyResults=@[]; [self.historyTable reloadData]; self.historyOpenButton.enabled=NO;
                JMSetLabel(self.storageFeedback,ok ? JML(@"История за выбранный период удалена.") : JML(@"Операция не выполнена. Проверьте файл резервной копии и свободное место."));
            }
            if (![self finishDataOperation]) return; [self refreshStorage:nil]; if (!ok) [self showError:JML(@"Не удалось очистить историю") detail:error.localizedDescription];
        });
    });
}
- (void)finishBlockChangeForPeer:(NSString *)peer blocked:(BOOL)blocked enableDenyMode:(BOOL)enableMode {
    JMHistory *history=self.history;
    __weak JMAppDelegate *weakSelf=self;
    [self.client setBlocked:blocked peer:peer enableDenyMode:enableMode completion:^(NSDictionary *privacy, NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || self.history!=history) return;
        self.changingPrivacy=NO;
        if (error) [self showError:JML(@"Не удалось подтвердить блокировку") detail:error.localizedDescription];
        else [self showError:blocked ? JML(@"Контакт заблокирован") : JML(@"Контакт разблокирован") detail:[NSString stringWithFormat:@"UIN %@",peer]];
    }];
}
- (void)toggleContactBlock:(id)sender {
    NSString *peer=[self contactForAction:sender];
    if (!self.client.connected || self.changingPrivacy || !JMValidUIN(peer) || [peer isEqual:self.accountUIN]) return;
    self.changingPrivacy=YES;
    JMHistory *history=self.history;
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchPrivacy:^(NSDictionary *privacy, NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || self.history!=history) return;
        if (error) { self.changingPrivacy=NO; [self showError:JML(@"Не удалось загрузить список блокировки") detail:error.localizedDescription]; return; }
        BOOL blocked=[JMBlockedUINs(privacy) containsObject:peer];
        NSString *mode=JMString(privacy[@"pdMode"]);
        BOOL enableMode=!blocked && [mode isEqual:@"permitAll"];
        if (!blocked && !enableMode && ![mode isEqual:@"denySome"]) {
            self.changingPrivacy=NO;
            [self showError:JML(@"Действует другой режим приватности") detail:JML(@"Чтобы заблокировать отдельный контакт, выберите на сервере режим «Все, кроме заблокированных».")];
            return;
        }
        NSAlert *alert=[[NSAlert alloc] init];
        alert.messageText=blocked ? JML(@"Разблокировать контакт?") : JML(@"Заблокировать контакт?");
        alert.informativeText=[NSString stringWithFormat:@"UIN %@\n%@",peer,enableMode ? JML(@"Режим изменится на «Все, кроме заблокированных». Записи, уже находящиеся в списке блокировки, тоже вступят в силу.") : JML(@"Изменение применяется на сервере Jimm.online.")];
        [alert addButtonWithTitle:blocked ? JML(@"Разблокировать") : JML(@"Заблокировать")];
        [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
        if ([alert runModal]==NSAlertFirstButtonReturn && self.history==history) [self finishBlockChangeForPeer:peer blocked:!blocked enableDenyMode:enableMode];
        else self.changingPrivacy=NO;
    }];
}
- (void)showBlockedContacts:(id)sender {
    if (!self.client.connected || self.changingPrivacy) return;
    self.changingPrivacy=YES;
    JMHistory *history=self.history;
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchPrivacy:^(NSDictionary *privacy,NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || self.history!=history) return;
        if (error) { self.changingPrivacy=NO; [self showError:JML(@"Не удалось загрузить список блокировки") detail:error.localizedDescription]; return; }
        NSArray *peers=JMBlockedUINs(privacy);
        if (!peers.count) { self.changingPrivacy=NO; [self showError:JML(@"Список блокировки") detail:JML(@"Заблокированных контактов нет.")]; return; }
        NSAlert *alert=[[NSAlert alloc] init];
        alert.messageText=JML(@"Список блокировки");
        alert.informativeText=JML(@"Выберите UIN, чтобы убрать его из серверного списка.");
        NSPopUpButton *picker=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,320,28) pullsDown:NO];
        for (NSString *peer in peers) {
            NSString *name=JMName(self.contacts[peer] ?: @{@"aimId":peer});
            [picker addItemWithTitle:[NSString stringWithFormat:@"%@ · UIN %@",name,peer]];
            picker.lastItem.representedObject=peer;
        }
        alert.accessoryView=picker;
        [[alert addButtonWithTitle:JML(@"Закрыть")] setKeyEquivalent:@"\e"];
        [alert addButtonWithTitle:JML(@"Разблокировать")];
        if ([alert runModal]==NSAlertSecondButtonReturn && self.history==history) [self finishBlockChangeForPeer:picker.selectedItem.representedObject blocked:NO enableDenyMode:NO];
        else self.changingPrivacy=NO;
    }];
}
- (void)restoreRecentMessages:(id)sender {
    if (!self.client.connected || self.restoringMessages || !self.history || !JMValidUIN(self.selectedPeer)) return;
    BOOL manual=sender!=nil;
    NSString *peer=[self.selectedPeer copy], *uin=[self.accountUIN copy];
    JMHistory *history=self.history;
    self.restoringMessages=YES;
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchStoredMessagesForPeer:peer completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || self.history!=history) return;
        self.restoringMessages=NO;
        if (!error && ![data[@"msgs"] isKindOfClass:[NSArray class]]) {
            error=[NSError errorWithDomain:JMAPIErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер вернул неизвестный формат истории.")}];
        }
        if (error) { if (manual) [self showError:JML(@"Не удалось восстановить сообщения") detail:error.localizedDescription]; return; }
        NSUInteger added=0; BOOL saved=YES;
        for (id row in [JMArray(data[@"msgs"]) reverseObjectEnumerator]) {
            NSDictionary *message=JMMessageFromStoredIM(JMDictionary(row),peer,uin);
            if (!message) continue;
            BOOL inserted=NO;
            if (![self saveIncomingMessage:message quiet:YES inserted:&inserted]) { saved=NO; break; }
            if (inserted) added++;
        }
        if (added) {
            [self persistConversationPeers];
            if ([peer isEqual:self.selectedPeer]) [self renderTranscript];
            [self reloadContacts]; [self updateDockBadge];
        }
        if (manual && saved) [self showError:JML(@"История текущей сессии проверена") detail:[NSString stringWithFormat:JML(@"Добавлено сообщений: %lu"),(unsigned long)added]];
    }];
}
- (void)showDiagnostics:(id)sender {
    if (!self.diagnosticsWindow) {
        self.diagnosticsWindow=[[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,660,380) styleMask:NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
        self.diagnosticsWindow.title=JML(@"Диагностика — JimmMac"); self.diagnosticsWindow.releasedWhenClosed=NO; self.diagnosticsWindow.delegate=self;
        self.diagnosticsWindow.contentMinSize=NSMakeSize(580,320); self.diagnosticsWindow.contentView=[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,660,380)]; NSView *root=self.diagnosticsWindow.contentView;
        NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(20,60,620,300)]; scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable; scroll.hasVerticalScroller=YES; scroll.hasHorizontalScroller=NO; scroll.borderType=NSBezelBorder;
        self.diagnosticsText=[[NSTextView alloc] initWithFrame:scroll.contentView.bounds]; self.diagnosticsText.editable=NO; self.diagnosticsText.selectable=YES; self.diagnosticsText.font=[NSFont userFixedPitchFontOfSize:12]; self.diagnosticsText.textContainerInset=NSMakeSize(10,10); self.diagnosticsText.autoresizingMask=NSViewWidthSizable; self.diagnosticsText.textContainer.widthTracksTextView=YES; scroll.documentView=self.diagnosticsText; [root addSubview:scroll];
        NSButton *copy=JMButton(JML(@"Копировать отчёт"),NSMakeRect(14,14,190,32),self,@selector(copyDiagnostics:)); [root addSubview:copy];
        NSButton *refresh=JMButton(JML(@"Обновить"),NSMakeRect(210,14,140,32),self,@selector(refreshDiagnostics:)); [root addSubview:refresh];
        NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(514,14,132,32),self,@selector(closeDiagnostics:)); close.autoresizingMask=NSViewMinXMargin; close.keyEquivalent=@"\e"; [root addSubview:close];
        JMDecorateUtilityWindow(self.diagnosticsWindow,JML(@"Диагностика")); [self.diagnosticsWindow center];
    }
    [self refreshDiagnostics:nil]; JMRefreshUtilityWindow(self.diagnosticsWindow); [self.diagnosticsWindow makeKeyAndOrderFront:nil];
}
- (void)refreshDiagnostics:(id)sender {
    self.diagnosticsText.string=JMDiagnosticReport([[NSBundle mainBundle] infoDictionary],[[NSProcessInfo processInfo] operatingSystemVersionString],self.offlineMode ? @"offline" : (self.client.connected ? @"connected" : @"disconnected"),[self.client usesLegacyTransport],[self.client diagnosticSnapshot]);
}
- (void)copyDiagnostics:(id)sender { [self refreshDiagnostics:nil]; [self writeMessageToPasteboard:self.diagnosticsText.string]; }
- (void)closeDiagnostics:(id)sender { [self.diagnosticsWindow orderOut:nil]; }
- (void)about:(id)sender {
    if (!self.aboutController) self.aboutController=[[JMInformationController alloc] initWithKeyboardHelp:NO];
    [self.aboutController showWindow:nil]; [self.aboutController.window makeKeyAndOrderFront:nil];
}
- (void)showKeyboardHelp:(id)sender {
    if (!self.keyboardHelpController) self.keyboardHelpController=[[JMInformationController alloc] initWithKeyboardHelp:YES];
    [self.keyboardHelpController showWindow:nil]; [self.keyboardHelpController.window makeKeyAndOrderFront:nil];
}
- (void)openTelegraphica:(id)sender { [self openExternalURL:JMTelegraphicaURL()]; }
- (void)showContactsSection:(id)sender { [self showSection:0]; }
- (void)showConversationsSection:(id)sender { [self showSection:1]; }
- (void)showSection:(NSInteger)section {
    if (!self.history) return;
    [self.sectionControl setSelectedSegment:section]; [self changeSection:nil];
    [[self listWindow] makeKeyAndOrderFront:nil]; [[self listWindow] makeFirstResponder:self.contactTable];
}
- (void)focusContactSearch:(id)sender {
    if (!self.history) return;
    [[self listWindow] makeKeyAndOrderFront:nil]; [[self listWindow] makeFirstResponder:self.searchField]; [self.searchField selectText:nil];
}
- (void)activateContactSelection:(id)sender {
    NSInteger row=self.contactTable.selectedRow;
    if (row<0 || row>=(NSInteger)self.visibleContacts.count) return;
    NSDictionary *contact=self.visibleContacts[(NSUInteger)row];
    if (contact[@"_collapsedGroup"]) [self toggleGroup:contact[@"_collapsedGroup"]];
    else [self selectPeer:contact[@"aimId"]];
}
- (void)handleEscapeInWindow:(NSWindow *)window {
    if (window==self.rosterWindow) {
        if (self.searchField.stringValue.length) { self.searchField.stringValue=@""; [self reloadContacts]; }
        else [self.rosterWindow makeFirstResponder:self.contactTable]; return;
    }
    if (window==self.loginWindow) { if (self.loginPending) [self cancelLogin:nil]; return; }
    if (window==self.chatWindow) {
        if (window.firstResponder==self.searchField.currentEditor && self.searchField.stringValue.length) {
            self.searchField.stringValue=@""; [self reloadContacts];
        } else { [[self listWindow] makeKeyAndOrderFront:nil]; [[self listWindow] makeFirstResponder:self.contactTable]; }
    } else if (window==self.historyWindow) [self closeHistorySearch:nil];
    else [window performClose:nil];
}
- (void)createLoginWindow {
    self.loginWindow = [[JMWindow alloc] initWithContentRect:NSMakeRect(0, 0, 440, 430)
        styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask backing:NSBackingStoreBuffered defer:NO];
    [self.loginWindow setTitle:JML(@"JimmMac — вход")]; [self.loginWindow setReleasedWhenClosed:NO]; [self.loginWindow setDelegate:self];
    [self.loginWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,440,430)]];
    NSView *view = [self.loginWindow contentView];
    JMChromeView *banner=[[JMChromeView alloc] initWithFrame:NSMakeRect(0,258,440,172)];
    banner.topColor=JMLegacyHeaderTopColor(); banner.bottomColor=JMLegacyHeaderBottomColor(); [view addSubview:banner];
    NSImageView *flower = [[JMClassicAvatarView alloc] initWithFrame:NSMakeRect(182,334,76,76)];
    [flower setImage:JMFlowerImage()]; [flower setImageScaling:NSImageScaleProportionallyUpOrDown]; [view addSubview:flower];
    NSTextField *title = JMLabel(@"JimmMac",NSMakeRect(30,296,380,31),24,YES); [title setAlignment:NSCenterTextAlignment]; [view addSubview:title];
    NSTextField *subtitle = JMLabel(JML(@"Ваша аська на Mac · Jimm.online"),NSMakeRect(30,268,380,22),12,NO);
    [subtitle setAlignment:NSCenterTextAlignment]; [subtitle setTextColor:JMSecondaryTextColor()]; [view addSubview:subtitle];
    [view addSubview:JMLabel(@"UIN",NSMakeRect(35,222,76,22),13,NO)];
    self.uinField = [[NSTextField alloc] initWithFrame:NSMakeRect(119,220,285,25)];
    [self.uinField setToolTip:JML(@"Ваш числовой UIN, зарегистрированный в Jimm.online")];
    self.uinField.delegate=self;
    NSString *lastUIN = [self.loginDefaults stringForKey:@"LastUIN"];
    if (JMValidUIN(lastUIN)) [self.uinField setStringValue:lastUIN]; [view addSubview:self.uinField];
    [view addSubview:JMLabel(JML(@"Пароль"),NSMakeRect(35,178,76,22),13,NO)];
    self.passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(119,176,285,25)];
    [self.passwordField setToolTip:JML(@"Пароль ICQ-аккаунта Jimm.online. Пароль не сохраняется; для автовхода используется токен в Связке ключей.")];
    [self.passwordField setTarget:self]; [self.passwordField setAction:@selector(login:)]; [view addSubview:self.passwordField];
    self.rememberLoginCheckbox=JMCheckbox(JML(@"Запомнить меня"),NSMakeRect(119,143,285,22),self,@selector(rememberLoginChanged:));
    self.rememberLoginCheckbox.state=NSOnState; self.rememberLoginCheckbox.toolTip=JML(@"Сохранить токен в системной Связке ключей и автоматически входить при запуске. Пароль не сохраняется."); [view addSubview:self.rememberLoginCheckbox];
    self.cancelLoginButton=JMButton(JML(@"Отмена"),NSMakeRect(113,99,149,32),self,@selector(cancelLogin:)); self.cancelLoginButton.hidden=YES; self.cancelLoginButton.keyEquivalent=@"\e"; [view addSubview:self.cancelLoginButton];
    self.loginButton = JMButton(JML(@"Войти"),NSMakeRect(274,99,136,32),self,@selector(login:));
    [self.loginButton setKeyEquivalent:@"\r"]; [view addSubview:self.loginButton];
    self.loginStatus = JMLabel(JML(@"Введите UIN и пароль от Jimm.online."),NSMakeRect(35,42,370,48),12,NO);
    [[self.loginStatus cell] setWraps:YES]; [view addSubview:self.loginStatus];
    [view addSubview:JMButton(JML(@"Открыть Jimm.online"),NSMakeRect(27,5,183,29),self,@selector(openSite:))];
    self.offlineHistoryButton=JMButton(JML(@"История офлайн…"),NSMakeRect(222,5,188,29),self,@selector(openOfflineHistory:)); self.offlineHistoryButton.toolTip=JML(@"Читать локальную историю и писать черновики без подключения к серверу"); [view addSubview:self.offlineHistoryButton];
    [self.uinField setNextKeyView:self.passwordField]; [self.passwordField setNextKeyView:self.rememberLoginCheckbox]; [self.rememberLoginCheckbox setNextKeyView:self.loginButton];
    [self.loginWindow setInitialFirstResponder:[lastUIN length] ? self.passwordField : self.uinField];
}
- (void)createChatWindow {
    self.chatWindow = [[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,1000,650)
        styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
    [self.chatWindow setTitle:@"JimmMac"]; [self.chatWindow setContentMinSize:NSMakeSize(860,560)];
    [self.chatWindow setReleasedWhenClosed:NO]; [self.chatWindow setDelegate:self]; [self.chatWindow center];
    [self.chatWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,1000,650)]];
    NSView *root = [self.chatWindow contentView];
    JMChromeView *toolbar = [[JMRosterChrome alloc] initWithFrame:NSMakeRect(0,584,1000,66)];
    self.toolbar=toolbar; toolbar.topColor=JMLegacyHeaderTopColor(); toolbar.bottomColor=JMLegacyHeaderBottomColor();
    [toolbar setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin]; [root addSubview:toolbar];
    NSImageView *flower = [[JMClassicAvatarView alloc] initWithFrame:NSMakeRect(17,15,36,36)];
    self.brandImage=flower; [flower setImage:JMFlowerImage()]; [flower setImageScaling:NSImageScaleProportionallyUpOrDown]; [toolbar addSubview:flower];
    self.brandTitle=JMLabel(@"JimmMac",NSMakeRect(65,31,200,25),18,YES); [toolbar addSubview:self.brandTitle];
    NSTextField *subtitle = JMLabel(@"ICQ · Jimm.online",NSMakeRect(66,13,200,18),11,NO); self.brandSubtitle=subtitle; [subtitle setTextColor:JMSecondaryTextColor()]; [toolbar addSubview:subtitle];
    self.accountLabel = JMLabel(JML(@"Учётная запись"),NSMakeRect(400,36,570,21),12,NO);
    [self.accountLabel setAlignment:NSRightTextAlignment]; [self.accountLabel setAutoresizingMask:NSViewMinXMargin]; [toolbar addSubview:self.accountLabel];
    self.presencePopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(802,5,176,29) pullsDown:NO];
    NSArray *states=@[@"online",@"away",@"dnd",@"occupied",@"invisible"];
    NSArray *titles=@[JML(@"В сети"),JML(@"Отошёл"),JML(@"Не беспокоить"),JML(@"Занят"),JML(@"Невидимый")];
    for (NSUInteger i=0;i<states.count;i++) { [self.presencePopup addItemWithTitle:titles[i]]; [[self.presencePopup lastItem] setRepresentedObject:states[i]]; [[self.presencePopup lastItem] setImage:JMStatusImage(states[i])]; }
    [self.presencePopup setToolTip:JML(@"Ваш статус в сети. После изменения клиент проверит его на сервере.")];
    [self.presencePopup setAutoresizingMask:NSViewMinXMargin]; [self.presencePopup setTarget:self]; [self.presencePopup setAction:@selector(changePresence:)]; [toolbar addSubview:self.presencePopup];
    self.presenceFeedback=JMLabel(@"",NSMakeRect(400,11,392,18),11,NO);
    [self.presenceFeedback setTextColor:JMSecondaryTextColor()]; [self.presenceFeedback setAlignment:NSRightTextAlignment];
    [self.presenceFeedback setAutoresizingMask:NSViewMinXMargin]; [toolbar addSubview:self.presenceFeedback];
    self.reconnectButton=JMButton(JML(@"Подключиться"),NSMakeRect(666,5,130,29),self,@selector(reconnect:));
    [self.reconnectButton setToolTip:JML(@"Повторно подключиться к Jimm.online. Черновик сохранится.")];
    [self.reconnectButton setAutoresizingMask:NSViewMinXMargin]; [toolbar addSubview:self.reconnectButton];
    JMChromeView *sidebar = [[JMChromeView alloc] initWithFrame:NSMakeRect(0,26,268,558)];
    self.sidebar=sidebar;
    sidebar.topColor = [NSColor colorWithCalibratedWhite:0.94 alpha:1];
    sidebar.bottomColor = sidebar.topColor;
    [sidebar setAutoresizingMask:NSViewHeightSizable]; [root addSubview:sidebar];
    self.sectionControl = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(12,518,244,28)];
    self.sectionControl.cell=[[JMThemedSegmentedCell alloc] init]; [self.sectionControl setSegmentCount:2]; [self.sectionControl setLabel:JML(@"Контакты") forSegment:0];
    [self.sectionControl setLabel:JML(@"Переписки") forSegment:1];
    [self.sectionControl setSegmentStyle:NSSegmentStyleRounded]; [self.sectionControl setFont:[NSFont systemFontOfSize:13]];
    [self.sectionControl setWidth:116 forSegment:0]; [self.sectionControl setWidth:116 forSegment:1];
    // Let Mavericks include the bezel and cap insets instead of clipping them
    // with a hand-picked frame smaller than the native control's drawing size.
    [self.sectionControl sizeToFit];
    [[self.sectionControl cell] setToolTip:JML(@"Контакты, сохранённые в Jimm.online") forSegment:0];
    [[self.sectionControl cell] setToolTip:JML(@"Открытые разговоры и история сообщений") forSegment:1];
    [[self.sectionControl cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne]; [self.sectionControl setSelectedSegment:0];
    [self.sectionControl setTarget:self]; [self.sectionControl setAction:@selector(changeSection:)];
    [self.sectionControl setAutoresizingMask:NSViewMinYMargin]; [sidebar addSubview:self.sectionControl];
    self.searchField = [[JMThemedSearchField alloc] initWithFrame:NSMakeRect(12,480,244,25)];
    [[self.searchField cell] setPlaceholderString:JML(@"Поиск контактов")]; [(NSTextField *)self.searchField setDelegate:self];
    [self.searchField setToolTip:[JML(@"Поиск по имени или UIN в выбранном разделе") stringByAppendingString:@" · ⌘L"]];
    [self.searchField setAutoresizingMask:NSViewMinYMargin]; [sidebar addSubview:self.searchField];
    self.groupFilter=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(12,442,244,29) pullsDown:NO];
    self.groupFilter.target=self; self.groupFilter.action=@selector(groupFilterChanged:); [self.groupFilter setAutoenablesItems:NO];
    [self.groupFilter setToolTip:JML(@"Показать все контакты или выбранную группу. Здесь же доступно управление группами.")]; [sidebar addSubview:self.groupFilter];
    self.onlineOnlyCheckbox=JMCheckbox(JML(@"Только в сети"),NSMakeRect(12,409,136,24),self,@selector(toggleOnlineFilter:)); self.onlineOnlyCheckbox.font=[NSFont systemFontOfSize:11]; self.onlineOnlyCheckbox.toolTip=JML(@"Показывать только контакты с доступным сетевым статусом"); [sidebar addSubview:self.onlineOnlyCheckbox];
    self.favoritesOnlyCheckbox=JMCheckbox(JML(@"Избранные"),NSMakeRect(150,409,106,24),self,@selector(toggleFavoritesFilter:)); self.favoritesOnlyCheckbox.font=[NSFont systemFontOfSize:11]; self.favoritesOnlyCheckbox.toolTip=JML(@"Показывать только избранных. Добавление — через правый щелчок по контакту"); [sidebar addSubview:self.favoritesOnlyCheckbox];
    NSScrollView *list = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,85,268,385)];
    [list setAutoresizingMask:NSViewHeightSizable]; [list setHasVerticalScroller:YES]; [list setBorderType:NSNoBorder];
    self.contactTable = [[JMContactTable alloc] initWithFrame:[list bounds]];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"contact"]; [column setWidth:252]; [column setResizingMask:NSTableColumnAutoresizingMask];
    [self.contactTable addTableColumn:column]; [self.contactTable setHeaderView:nil]; [self.contactTable setRowHeight:60];
    [self.contactTable setBackgroundColor:sidebar.topColor]; [self.contactTable setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
    [self.contactTable setIntercellSpacing:NSMakeSize(0,0)];
    self.contactTable.target=self; self.contactTable.doubleAction=@selector(activateContactSelection:);
    [(JMContactTable *)self.contactTable setActivateAction:@selector(activateContactSelection:)];
    __weak JMAppDelegate *weakListOwner=self;
    [(JMContactTable *)self.contactTable setHandleHeaderClick:^BOOL(NSInteger row, CGFloat offset) {
        JMAppDelegate *self=weakListOwner;
        if (!self || self.sectionControl.selectedSegment!=0 || self.searchField.stringValue.length || offset>=[self headerHeightForRow:row]) return NO;
        [self toggleGroup:[self historicalGroupForContact:self.visibleContacts[(NSUInteger)row]]];
        return YES;
    }];
    self.contactTable.toolTip=JML(@"↑/↓ — выбрать собеседника; Enter — перейти к сообщению. Правый щелчок — действия с контактом.");
    [self.contactTable setDataSource:self]; [self.contactTable setDelegate:self];
    [self.contactTable setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    [self.contactTable setAllowsEmptySelection:YES]; [list setDocumentView:self.contactTable]; [sidebar addSubview:list];
    self.contactMenu=[[NSMenu alloc] initWithTitle:JML(@"Контакт")]; self.contactMenu.delegate=self;
    for (NSDictionary *entry in @[@{@"title":JML(@"Открыть переписку"),@"action":@"writeContact:"},@{@"title":JML(@"Профиль"),@"action":@"profileContact:"},@{@"title":JML(@"Переименовать…"),@"action":@"renameContact:"},@{@"title":JML(@"Переместить в группу…"),@"action":@"moveContact:"},@{@"title":JML(@"Удалить из контактов…"),@"action":@"removeContact:"}]) {
        NSMenuItem *item=[self.contactMenu addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    NSMenuItem *favoriteContext=[self.contactMenu addItemWithTitle:JML(@"Добавить в избранное") action:@selector(toggleFavorite:) keyEquivalent:@""]; favoriteContext.target=self;
    NSMenuItem *muteContext=[self.contactMenu addItemWithTitle:JML(@"Отключить уведомления") action:@selector(toggleMuteConversation:) keyEquivalent:@""]; muteContext.target=self;
    [self.contactTable setMenu:self.contactMenu];
    self.emptyListLabel = JMLabel(@"",NSMakeRect(20,245,228,100),12,NO); [[self.emptyListLabel cell] setWraps:YES];
    [self.emptyListLabel setAlignment:NSCenterTextAlignment]; [self.emptyListLabel setTextColor:JMSecondaryTextColor()];
    [self.emptyListLabel setAutoresizingMask:NSViewMinYMargin|NSViewMaxYMargin]; [sidebar addSubview:self.emptyListLabel];
    self.countLabel = JMLabel(JML(@"Контактов: 0"),NSMakeRect(13,63,240,19),11,NO); [self.countLabel setTextColor:JMSecondaryTextColor()]; [sidebar addSubview:self.countLabel];
    self.contactNotice = JMLabel(@"",NSMakeRect(13,33,241,27),11,NO); [[self.contactNotice cell] setWraps:YES]; [sidebar addSubview:self.contactNotice];
    self.addContactButton = JMButton(JML(@"Добавить…"),NSMakeRect(6,3,112,29),self,@selector(addContact:)); [sidebar addSubview:self.addContactButton];
    [self.addContactButton setToolTip:JML(@"Добавить UIN в контакт-лист на сервере Jimm.online")];
    NSButton *write=JMButton(JML(@"Написать…"),NSMakeRect(126,3,132,29),self,@selector(openConversation:)); self.writeConversationButton=write;
    [write setToolTip:JML(@"Открыть разговор по UIN, не добавляя его в контакты")]; [sidebar addSubview:write];
    NSView *chat = [[NSView alloc] initWithFrame:NSMakeRect(280,26,708,558)];
    self.chatPane=chat; self.conversationHeader=[[JMConversationChrome alloc] initWithFrame:NSZeroRect]; self.conversationHeader.hidden=YES; [chat addSubview:self.conversationHeader];
    [chat setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable]; [root addSubview:chat];
    self.peerAvatar=[[JMClassicAvatarView alloc] initWithFrame:NSMakeRect(6,500,44,44)];
    [self.peerAvatar setImageScaling:NSImageScaleProportionallyUpOrDown]; [self.peerAvatar setImage:(JMTheme()==JMThemeMac2011 ? JMRetroImage(@"avatar") : nil) ?: [NSImage imageNamed:NSImageNameUser]];
    [self.peerAvatar setAutoresizingMask:NSViewMinYMargin]; [chat addSubview:self.peerAvatar];
    self.peerLabel = JMLabel(JML(@"Выберите собеседника"),NSMakeRect(63,522,395,24),16,YES);
    [self.peerLabel setAutoresizingMask:NSViewMinYMargin|NSViewWidthSizable]; [chat addSubview:self.peerLabel];
    self.peerDetail = JMLabel(JML(@"Контакты и переписки в отдельных разделах"),NSMakeRect(64,498,395,19),11,NO);
    [self.peerDetail setTextColor:JMSecondaryTextColor()]; [self.peerDetail setAutoresizingMask:NSViewMinYMargin|NSViewWidthSizable]; [chat addSubview:self.peerDetail];
    self.addPeerButton = JMButton(JML(@"Добавить в контакты"),NSMakeRect(444,516,173,29),self,@selector(addSelectedPeer:));
    [self.addPeerButton setToolTip:JML(@"Сохранить этого собеседника в контакт-листе Jimm.online")];
    [self.addPeerButton setAutoresizingMask:NSViewMinXMargin|NSViewMinYMargin]; [self.addPeerButton setHidden:YES]; [chat addSubview:self.addPeerButton];
    NSButton *profile=JMButton(JML(@"Профиль"),NSMakeRect(624,516,83,29),self,@selector(showProfile:));
    self.profileButton=profile; [profile setEnabled:NO]; [profile setToolTip:JML(@"Открыть сведения о собеседнике и его фотографию")];
    [profile setAutoresizingMask:NSViewMinXMargin|NSViewMinYMargin]; [chat addSubview:profile];
    self.historySearchButton=JMButton(JML(@"Найти…"),NSMakeRect(520,516,96,29),self,@selector(showHistorySearch:));
    [self.historySearchButton setToolTip:JML(@"Поиск по локальной истории сообщений (Cmd+F)")]; [chat addSubview:self.historySearchButton];
    NSScrollView *log = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,149,708,341)];
    [log setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable]; [log setHasVerticalScroller:YES]; [log setBorderType:NSNoBorder];
    self.transcript = [[JMTranscriptView alloc] initWithFrame:[[log contentView] bounds]];
    [self.transcript setEditable:NO]; [self.transcript setSelectable:YES]; [self.transcript setRichText:YES]; [self.transcript setDelegate:self];
    [self.transcript setLinkTextAttributes:@{NSForegroundColorAttributeName:[NSColor colorWithCalibratedRed:0.08 green:0.29 blue:0.62 alpha:1],NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle),NSCursorAttributeName:[NSCursor pointingHandCursor]}];
    [self.transcript setTextContainerInset:NSMakeSize(18,16)]; [self.transcript setAutoresizingMask:NSViewWidthSizable]; [self.transcript setVerticallyResizable:YES];
    [self.transcript setHorizontallyResizable:NO]; [self.transcript setMaxSize:NSMakeSize(FLT_MAX,FLT_MAX)];
    [[self.transcript textContainer] setContainerSize:NSMakeSize(NSWidth([[log contentView] bounds]),FLT_MAX)];
    [[self.transcript textContainer] setWidthTracksTextView:YES]; [log setDocumentView:self.transcript]; [chat addSubview:log];
    self.olderMessagesButton=JMButton(JML(@"← Ранее"),NSZeroRect,self,@selector(loadEarlierMessages:)); self.olderMessagesButton.toolTip=JML(@"Предыдущие 200 сообщений. Полная история остаётся на диске"); [chat addSubview:self.olderMessagesButton];
    self.newerMessagesButton=JMButton(JML(@"Позже →"),NSZeroRect,self,@selector(loadNewerMessages:)); self.newerMessagesButton.toolTip=JML(@"Следующие 200 сообщений"); [chat addSubview:self.newerMessagesButton];
    self.historyPageLabel=JMLabel(@"",NSZeroRect,11,NO); self.historyPageLabel.alignment=NSCenterTextAlignment; [chat addSubview:self.historyPageLabel];
    self.conversationEmptyView=[[JMConversationEmptyView alloc] initWithFrame:log.frame];
    self.conversationEmptyView.writeButton.target=self; self.conversationEmptyView.writeButton.action=@selector(openConversation:); [chat addSubview:self.conversationEmptyView];
    [[log contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationDidScroll:) name:NSViewBoundsDidChangeNotification object:[log contentView]];
    self.typingLabel=JMLabel(@"",NSMakeRect(5,126,690,18),11,NO); [self.typingLabel setTextColor:JMSecondaryTextColor()];
    [self.typingLabel setAutoresizingMask:NSViewWidthSizable]; [chat addSubview:self.typingLabel];
    self.latestMessagesButton=JMButton(JML(@"Новые сообщения ↓"),NSMakeRect(528,122,180,26),self,@selector(jumpToLatest:));
    self.latestMessagesButton.toolTip=JML(@"Перейти к последним сообщениям и отметить открытую переписку прочитанной"); self.latestMessagesButton.hidden=YES; [chat addSubview:self.latestMessagesButton];
    NSScrollView *input = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,40,708,80)];
    [input setAutoresizingMask:NSViewWidthSizable]; [input setHasVerticalScroller:YES]; [input setBorderType:NSBezelBorder];
    self.composer = [[JMComposerView alloc] initWithFrame:[[input contentView] bounds]];
    [(JMComposerView *)self.composer setPlaceholder:JML(@"Сообщение…")];
    [self.composer setFont:JMThemeFont(self.chatPreferences.messageFont,self.chatPreferences.family)]; [self.composer setRichText:NO]; [self.composer setAllowsUndo:YES]; [self.composer setTextContainerInset:NSMakeSize(8,7)];
    [self.composer setDelegate:self]; [self.composer setAutoresizingMask:NSViewWidthSizable]; [[self.composer textContainer] setWidthTracksTextView:YES];
    [self.composer setVerticallyResizable:YES]; [self.composer setHorizontallyResizable:NO]; [self.composer setMaxSize:NSMakeSize(FLT_MAX,FLT_MAX)];
    [[self.composer textContainer] setContainerSize:NSMakeSize(NSWidth([[input contentView] bounds]),FLT_MAX)];
    [self.composer setToolTip:JML(@"Введите сообщение. Enter — отправить, Shift+Enter — новая строка.")];
    [input setDocumentView:self.composer]; [chat addSubview:input];
    self.sendButton = JMButton(JML(@"Отправить"),NSMakeRect(576,2,134,30),self,@selector(send:));
    [self.sendButton setToolTip:JML(@"Отправить сообщение выбранному собеседнику (Enter)")];
    [self.sendButton setAutoresizingMask:NSViewMinXMargin]; [chat addSubview:self.sendButton];
    self.composerHint = JMLabel(JML(@"Выберите контакт или нажмите «Написать…»"),NSMakeRect(4,7,555,19),11,NO);
    [self.composerHint setTextColor:JMSecondaryTextColor()]; [self.composerHint setAutoresizingMask:NSViewWidthSizable]; [chat addSubview:self.composerHint];
    self.statusLabel = JMLabel(JML(@"Не подключено"),NSMakeRect(12,3,820,20),11,NO);
    [self.statusLabel setAutoresizingMask:NSViewWidthSizable]; [root addSubview:self.statusLabel];
    NSButton *logout = JMButton(JML(@"Выйти"),NSMakeRect(900,0,91,26),self,@selector(logout:));
    self.logoutButton=logout; [logout setToolTip:JML(@"Выйти из аккаунта и отключиться от Jimm.online")];
    [logout setAutoresizingMask:NSViewMinXMargin]; [root addSubview:logout];
    self.soundButton=JMButton(@"",NSMakeRect(766,3,126,30),self,@selector(toggleSounds:)); [root addSubview:self.soundButton];
    self.themeSendBar=[[JMClassicSendBar alloc] initWithFrame:NSZeroRect]; [chat addSubview:self.themeSendBar positioned:NSWindowBelow relativeTo:self.sendButton];
    self.themeUINTitle=JMLabel(@"ICQ#:",NSZeroRect,10,NO); self.themeNickTitle=JMLabel(JML(@"Ник:"),NSZeroRect,10,NO);
    self.themeUINValue=JMLabel(@"",NSZeroRect,10,NO); self.themeUINValue.font=[NSFont userFixedPitchFontOfSize:10]; self.themeNickValue=JMLabel(@"",NSZeroRect,11,NO);
    for (NSTextField *field in @[self.themeUINValue,self.themeNickValue]) { field.selectable=YES; field.bezeled=YES; field.bezelStyle=NSTextFieldSquareBezel; field.drawsBackground=YES; field.backgroundColor=[NSColor colorWithSRGBRed:216.0/255 green:219.0/255 blue:231.0/255 alpha:1]; [chat addSubview:field]; }
    [chat addSubview:self.themeUINTitle]; [chat addSubview:self.themeNickTitle]; self.themeRecipientState=[[NSImageView alloc] initWithFrame:NSZeroRect]; [chat addSubview:self.themeRecipientState];
    self.themeFavoriteButton=JMButton(JML(@"Избранные"),NSZeroRect,self,@selector(toggleFavoritesFilter:)); self.themeFavoriteButton.image=JMRetroImage(@"favorites"); self.themeFavoriteButton.imagePosition=NSImageOnly; [self.themeFavoriteButton setButtonType:NSPushOnPushOffButton]; self.themeFavoriteButton.toolTip=JML(@"Показывать только избранных. Добавление — через правый щелчок по контакту"); [toolbar addSubview:self.themeFavoriteButton];
    self.themeCloseButton=JMButton(JML(@"Закрыть"),NSZeroRect,self,@selector(closeHistoricalConversation:)); [chat addSubview:self.themeCloseButton];
    self.themeSmileyButton=JMButton(JML(@"Смайлики"),NSZeroRect,self,@selector(showClassicSmileys:)); self.themeSmileyButton.image=JMClassicSmileyImage(); self.themeSmileyButton.imagePosition=NSImageOnly; self.themeSmileyButton.toolTip=JML(@"Вставить смайлик в черновик"); [chat addSubview:self.themeSmileyButton];
    self.themeFontButton=JMButton(@"T ▾",NSZeroRect,self,@selector(showClassicFontMenu:)); self.themeFontButton.tag=905; self.themeFontButton.toolTip=JML(@"Настройки шрифта переписки"); [chat addSubview:self.themeFontButton];
    self.themeComposerCount=JMLabel(@"",NSZeroRect,10,NO); [chat addSubview:self.themeComposerCount];
    self.themeConversationTabs=[[NSSegmentedControl alloc] initWithFrame:NSZeroRect]; self.themeConversationTabs.cell=[[JMThemedSegmentedCell alloc] init]; self.themeConversationTabs.target=self; self.themeConversationTabs.action=@selector(changeHistoricalTab:); self.themeConversationTabs.font=[NSFont systemFontOfSize:11]; [chat addSubview:self.themeConversationTabs];
    self.themeConversationPicker=[[JMThemedPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES]; self.themeConversationPicker.font=[NSFont systemFontOfSize:10]; self.themeConversationPicker.toolTip=JML(@"Открыть любую сохранённую переписку"); [chat addSubview:self.themeConversationPicker];
    self.mobileFooter=[[JMChromeView alloc] initWithFrame:NSZeroRect];
    self.mobileFind=JMButton(JML(@"Найти"),NSZeroRect,self,@selector(focusContactSearch:));
    self.mobileFind.image=JMRetroImage(@"find"); self.mobileFind.imagePosition=NSImageLeft; self.mobileFind.tag=JMRetroFooterItemTag;
    self.mobileFind.toolTip=JML(@"Поиск в списке · ⌘L");
    self.mobileSettings=JMButton(JML(@"Настройки"),NSZeroRect,self,@selector(showPreferences:));
    self.mobileSettings.image=JMRetroImage(@"settings");
    self.mobileSettings.imagePosition=NSImageLeft;
    self.mobileSettings.tag=JMRetroFooterItemTag;
    self.mobileSettings.toolTip=JML(@"Настройки · ⌘,");
    self.mobileUnread=JMButton(JML(@"Непрочитанные"),NSZeroRect,self,@selector(toggleUnreadFilter:));
    [self.mobileUnread setButtonType:NSPushOnPushOffButton];
    self.mobileUnread.toolTip=JML(@"Только непрочитанные · ⇧⌘U");
    self.mobileUnread.hidden=YES;
    [sidebar addSubview:self.mobileUnread];
    self.mobileChatTitle=JMLabel(@"",NSZeroRect,14,YES);
    [chat addSubview:self.mobileChatTitle];
    self.themeMainMenu=[[JMThemedPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES]; self.themeMainMenu.font=[NSFont systemFontOfSize:11]; self.themeMainMenu.toolTip=JML(@"Профиль, настройки и сведения о JimmMac"); [root addSubview:self.themeMainMenu];
    [self.themeMainMenu addItemWithTitle:JML(@"Меню")];
    for (NSDictionary *item in @[@{@"title":JML(@"Мой профиль…"),@"action":@"showOwnProfile:"},@{@"title":JML(@"Настройки…"),@"action":@"showPreferences:"},@{@"title":JML(@"О JimmMac"),@"action":@"about:"},@{@"title":JML(@"Добавить контакт…"),@"action":@"addContact:"},@{@"title":JML(@"Написать по UIN…"),@"action":@"openConversation:"},@{@"title":JML(@"Список блокировки…"),@"action":@"showBlockedContacts:"},@{@"title":JML(@"Выйти из аккаунта"),@"action":@"logout:"}]) { [self.themeMainMenu addItemWithTitle:item[@"title"]]; self.themeMainMenu.lastItem.target=self; self.themeMainMenu.lastItem.action=NSSelectorFromString(item[@"action"]); }
    NSMenuItem *groups=[self.themeMainMenu.menu addItemWithTitle:JML(@"Группы контактов") action:NULL keyEquivalent:@""]; self.themeGroupMenu=[[NSMenu alloc] initWithTitle:JML(@"Группы контактов")]; groups.submenu=self.themeGroupMenu;
    // Include every control in the loop. AppKit skips hidden/disabled controls
    // and follows the user's Full Keyboard Access preference for buttons.
    NSArray *keyViews=@[self.presencePopup,self.sectionControl,self.searchField,self.groupFilter,self.onlineOnlyCheckbox,self.favoritesOnlyCheckbox,self.contactTable,
        self.addContactButton,write,self.historySearchButton,self.profileButton,self.addPeerButton,
        self.conversationEmptyView.writeButton,self.olderMessagesButton,self.newerMessagesButton,self.transcript,self.latestMessagesButton,self.composer,
        self.sendButton,self.soundButton,self.logoutButton,self.reconnectButton];
    for (NSUInteger i=0;i<keyViews.count;i++) [keyViews[i] setNextKeyView:keyViews[(i+1)%keyViews.count]];
    self.chatWindow.autorecalculatesKeyViewLoop=NO;
    self.chatWindow.initialFirstResponder=self.searchField;
    [self refreshGroupChoices]; [self updateSoundControls]; [self updatePeerLabel]; [self layoutChatWindow]; [self updateSendButton]; [self reloadContacts]; [self applyAppearance];
}
- (void)layoutChatWindow {
    CGFloat width=NSWidth([(NSView *)self.chatWindow.contentView bounds]), height=NSHeight([(NSView *)self.chatWindow.contentView bounds]);
    BOOL mobile=JMThemeIsMobile(), historic=JMTheme()!=JMThemeCurrent, mac=JMTheme()==JMThemeMac2011, pro=JMTheme()==JMThemePro2003 || mobile;
    BOOL red=JMTheme()==JMThemeJimm;
    CGFloat mobileFooterHeight=red ? 47 : 36;
    CGFloat rosterWidth=historic ? NSWidth([(NSView *)self.rosterWindow.contentView bounds]) : 268;
    if (historic && self.rosterWindow) {
        CGFloat rh=NSHeight([(NSView *)self.rosterWindow.contentView bounds]), header=mobile ? 67 : (mac ? 119 : 48), footer=mobile ? mobileFooterHeight+27 : (pro ? 78 : 62);
        self.toolbar.frame=NSMakeRect(0,rh-header,rosterWidth,header); self.sidebar.frame=NSMakeRect(0,footer,rosterWidth,rh-header-footer);
        self.chatPane.frame=NSMakeRect(0,0,width,height);
        self.brandTitle.frame=NSMakeRect(29,header-21,rosterWidth-36,18); self.brandTitle.font=[NSFont boldSystemFontOfSize:pro ? 11 : 13];
        self.brandImage.frame=pro ? NSMakeRect(7,header-21,16,16) : NSMakeRect(8,header-81,52,52);
        self.accountLabel.frame=mac ? NSMakeRect(94,header-47,rosterWidth-102,20) : NSMakeRect(8,4,rosterWidth-16,17);
        self.brandSubtitle.frame=NSMakeRect(71,header-78,rosterWidth-80,28); [self.brandSubtitle.cell setWraps:mac];
        self.presencePopup.frame=mac ? NSMakeRect(68,header-47,24,20) : NSMakeRect(rosterWidth/2,3,rosterWidth/2-4,18);
        self.presencePopup.hidden=NO;
        self.presenceFeedback.frame=NSMakeRect(6,pro ? 59 : 37,rosterWidth-12,16); self.presenceFeedback.alignment=NSLeftTextAlignment;
        self.reconnectButton.frame=mac ? NSMakeRect(rosterWidth-101,34,95,21) : self.presencePopup.frame;
        self.statusLabel.frame=NSMakeRect(6,pro ? 59 : 34,rosterWidth-(mac && !self.client.connected ? 114 : 12),18); [self.statusLabel.cell setWraps:NO];
        self.soundButton.frame=pro ? NSMakeRect(4,21,rosterWidth/2-4,18) : NSMakeRect(6,5,rosterWidth/2-10,23);
        self.logoutButton.frame=pro ? NSMakeRect(rosterWidth/2,21,rosterWidth/2-4,18) : NSMakeRect(rosterWidth/2+2,5,rosterWidth/2-8,23);
        self.themeMainMenu.frame=mac ? NSMakeRect(rosterWidth-30,3,24,24) : NSMakeRect(4,3,rosterWidth/2-4,18); self.themeFavoriteButton.frame=NSMakeRect(126,3,54,24);
        if (pro) { self.addContactButton.frame=NSMakeRect(4,39,rosterWidth/2-4,18); self.writeConversationButton.frame=NSMakeRect(rosterWidth/2,39,rosterWidth/2-4,18); }
    } else {
        self.toolbar.frame=NSMakeRect(0,height-66,width,66); self.sidebar.frame=NSMakeRect(0,36,268,height-102); self.chatPane.frame=NSMakeRect(280,36,width-292,height-102);
        self.brandImage.frame=NSMakeRect(17,15,36,36); self.brandTitle.frame=NSMakeRect(65,31,200,25); self.brandTitle.font=[NSFont boldSystemFontOfSize:18]; self.brandSubtitle.frame=NSMakeRect(66,13,200,18);
        self.accountLabel.frame=NSMakeRect(280,36,width-302,21); self.presencePopup.frame=NSMakeRect(width-192,5,176,29); self.presencePopup.hidden=NO;
        self.presenceFeedback.frame=NSMakeRect(280,11,width-482,18); self.presenceFeedback.alignment=NSRightTextAlignment; self.reconnectButton.frame=NSMakeRect(width-328,5,130,29);
        self.statusLabel.frame=NSMakeRect(12,8,width-260,20); [self.statusLabel.cell setWraps:NO]; self.soundButton.frame=NSMakeRect(width-238,3,132,30); self.logoutButton.frame=NSMakeRect(width-102,3,94,30);
    }
    BOOL groups=self.sectionControl.selectedSegment==0;
    self.mobileUnread.hidden=!mobile || groups;
    CGFloat sh=NSHeight(self.sidebar.bounds), sideTop=mac ? 30 : (historic ? 35 : 82);
    self.groupFilter.hidden=mac || !groups; self.groupFilter.frame=NSMakeRect(historic ? 5 : 12,sh-(historic ? 61 : 116),rosterWidth-(historic ? 10 : 24),historic ? 22 : 29);
    self.onlineOnlyCheckbox.hidden=historic; self.favoritesOnlyCheckbox.hidden=historic;
    self.onlineOnlyCheckbox.frame=NSMakeRect(12,sh-(groups ? 148 : 112),136,24); self.favoritesOnlyCheckbox.frame=NSMakeRect(150,NSMinY(self.onlineOnlyCheckbox.frame),106,24);
    self.searchField.frame=NSMakeRect(historic ? 6 : 12,sh-sideTop,rosterWidth-(historic ? 12 : 24),historic ? 24 : 25);
    BOOL notice=self.contactNotice.stringValue.length>0;
    CGFloat footer=historic ? (pro ? (notice ? 43 : 21) : (notice ? 74 : 49)) : (notice ? 94 : 62);
    CGFloat listTop=mac ? sh-36 : (historic ? sh-(groups ? 66 : 39) : sh-(groups ? 159 : 123)), listHeight=MAX(50,listTop-footer);
    self.contactTable.enclosingScrollView.frame=NSMakeRect(historic ? 4 : 0,footer,rosterWidth-(historic ? 8 : 0),listHeight);
    self.countLabel.frame=NSMakeRect(8,footer-19,rosterWidth-16,17); self.contactNotice.frame=NSMakeRect(8,pro ? 1 : 26,rosterWidth-16,historic ? 22 : 32); self.contactNotice.hidden=!notice;
    if (!pro) { self.addContactButton.frame=NSMakeRect(6,3,rosterWidth/2-10,historic ? 23 : 29); self.writeConversationButton.frame=NSMakeRect(rosterWidth/2+2,3,rosterWidth/2-8,historic ? 23 : 29); }
    if (historic) {
        [self.sectionControl setWidth:(rosterWidth-12)/2 forSegment:0]; [self.sectionControl setWidth:(rosterWidth-12)/2 forSegment:1];
        self.sectionControl.frame=NSMakeRect(5,mac ? 3 : 0,rosterWidth-10,25);
        if (mac) { [self.sectionControl setWidth:54 forSegment:0]; [self.sectionControl setWidth:54 forSegment:1]; self.sectionControl.frame=NSMakeRect(6,3,112,25); }
        if (pro) { self.sectionControl.frame=NSMakeRect(5,sh-28,rosterWidth-10,24); self.searchField.frame=NSMakeRect(6,sh-57,rosterWidth-12,23); self.groupFilter.frame=NSMakeRect(5,sh-82,rosterWidth-10,21); self.contactTable.enclosingScrollView.frame=NSMakeRect(4,footer,rosterWidth-8,MAX(50,sh-(groups ? 87 : 62)-footer)); }
    } else { NSSize tabs=self.sectionControl.frame.size; [self.sectionControl setFrameOrigin:NSMakePoint(floor((268-tabs.width)/2),sh-12-tabs.height)]; }
    CGFloat cw=NSWidth(self.chatPane.bounds), ch=NSHeight(self.chatPane.bounds);
    CGFloat header=mac ? 125 : (pro ? 31 : 82), pages=[self.history countForPeer:self.selectedPeer ?: @""]>200 ? (historic ? 24 : 30) : 0;
    self.conversationHeader.frame=NSMakeRect(0,ch-header,cw,header);
    BOOL hasPeer=self.selectedPeer.length>0;
    self.peerAvatar.frame=mac ? NSMakeRect(cw-79,ch-91,48,48) : NSMakeRect(8,ch-61,44,44); self.peerAvatar.hidden=!hasPeer || pro;
    self.peerLabel.frame=mac ? NSMakeRect(14,ch-62,cw-109,24) : (pro ? NSMakeRect(8,ch-26,cw-198,19) : NSMakeRect(hasPeer ? 64 : 16,ch-35,hasPeer ? cw-270 : cw-32,24));
    self.peerDetail.frame=mac ? NSMakeRect(10,ch-120,cw-20,18) : (pro ? NSMakeRect(8,ch-48,cw-16,17) : NSMakeRect(hasPeer ? 64 : 16,ch-60,hasPeer ? cw-74-(self.addPeerButton.isHidden ? 0 : 180) : cw-32,19));
    self.peerDetail.hidden=pro; self.peerLabel.hidden=pro;
    self.peerDetail.alignment=mac ? NSCenterTextAlignment : NSLeftTextAlignment;
    self.peerDetail.font=mac ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    self.peerDetail.textColor=mac ? [NSColor colorWithSRGBRed:0.13 green:0.28 blue:0.42 alpha:1] : JMSecondaryTextColor();
    self.themeUINTitle.hidden=!pro; self.themeUINValue.hidden=!pro; self.themeNickTitle.hidden=!pro; self.themeNickValue.hidden=!pro; self.themeRecipientState.hidden=!pro;
    self.themeUINTitle.frame=NSMakeRect(6,ch-25,36,17); self.themeRecipientState.frame=NSMakeRect(46,ch-25,16,16); self.themeUINValue.frame=NSMakeRect(66,ch-25,128,19); self.themeNickTitle.frame=NSMakeRect(200,ch-25,30,17); self.themeNickValue.frame=NSMakeRect(236,ch-25,cw-292,19);
    self.peerLabel.font=JMThemeFont([NSFont boldSystemFontOfSize:historic ? (pro ? 11 : 15) : 16],@"");
    self.profileButton.frame=NSMakeRect(cw-(historic ? 83 : 90),ch-(mac ? 65 : (pro ? 27 : 42)),historic ? 76 : 90,historic ? 22 : 32);
    self.historySearchButton.frame=NSMakeRect(cw-(historic ? 165 : 196),NSMinY(self.profileButton.frame),historic ? 76 : 100,historic ? 22 : 32);
    if (historic) { self.profileButton.frame=NSMakeRect(cw-(mac ? 24 : 48),ch-(mac ? 85 : 25),pro ? 19 : 21,pro ? 19 : 21); self.historySearchButton.frame=NSMakeRect(cw-24,ch-(mac ? 61 : 25),pro ? 19 : 21,pro ? 19 : 21); }
    self.addPeerButton.frame=NSMakeRect(cw-193,ch-(mac ? 119 : (pro ? 58 : 72)),185,historic ? 21 : 30);
    if (pro) self.addPeerButton.frame=NSMakeRect(cw-193,117,185,20);
    else if (mac) self.addPeerButton.frame=NSMakeRect(10,ch-90,185,22);
    else self.addPeerButton.frame=NSMakeRect(cw-181,ch-72,181,30);
    self.olderMessagesButton.frame=NSMakeRect(historic ? 6 : 0,ch-header-(historic ? 23 : 29),historic ? 94 : 108,historic ? 21 : 27);
    self.newerMessagesButton.frame=NSMakeRect(cw-(historic ? 100 : 108),NSMinY(self.olderMessagesButton.frame),historic ? 94 : 108,historic ? 21 : 27);
    self.historyPageLabel.frame=NSMakeRect(106,NSMinY(self.olderMessagesButton.frame)+3,cw-212,17);
    CGFloat transcriptBottom=mac ? 116 : (pro ? 140 : 149);
    self.transcript.enclosingScrollView.frame=NSMakeRect(historic ? 6 : 0,transcriptBottom,cw-(historic ? 12 : 0),MAX(80,ch-header-pages-transcriptBottom-(historic ? 2 : 2)));
    self.conversationEmptyView.frame=self.transcript.enclosingScrollView.frame;
    self.composer.enclosingScrollView.frame=NSMakeRect(historic ? 7 : 0,mac ? 36 : (pro ? 55 : 40),cw-(historic ? (mac ? 42 : 14) : 0),mac ? 54 : (pro ? 60 : 80));
    self.composerHint.frame=NSMakeRect(historic ? (pro ? 91 : 8) : 4,7,cw-(historic ? (pro ? 193 : 123) : 156),18);
    self.sendButton.frame=NSMakeRect(cw-(historic ? 100 : 134),historic ? 5 : 2,historic ? 93 : 134,historic ? 24 : 30);
    self.themeCloseButton.frame=NSMakeRect(8,7,70,19); self.themeCloseButton.hidden=!pro; self.themeSendBar.hidden=JMTheme()!=JMThemePro2003; self.themeSendBar.frame=NSMakeRect(4,3,cw-8,30); if (pro) { self.sendButton.frame=NSMakeRect(cw-92,7,83,19); self.composerHint.frame=NSMakeRect(119,8,cw-218,17); }
    self.themeSmileyButton.frame=mac ? NSMakeRect(cw-29,49,22,24) : NSMakeRect(105,117,25,20); self.themeSmileyButton.hidden=!historic;
    self.themeFontButton.frame=NSMakeRect(134,117,27,20); self.themeFontButton.hidden=!pro;
    self.themeComposerCount.frame=NSMakeRect(8,119,91,17); self.themeComposerCount.hidden=!pro;
    self.typingLabel.frame=NSMakeRect(historic ? 8 : 5,mac ? 94 : (pro ? 37 : 126),cw-(self.latestMessagesButton.isHidden ? 16 : 200),17);
    self.latestMessagesButton.frame=NSMakeRect(cw-185,mac ? 92 : (pro ? 36 : 122),178,pro ? 18 : (mac ? 21 : 26));
    self.themeConversationTabs.frame=NSMakeRect(5,ch-28,cw-125,25); self.themeConversationTabs.hidden=!mac;
    self.themeConversationPicker.frame=NSMakeRect(cw-115,ch-27,109,23); self.themeConversationPicker.hidden=!mac;
    self.mobileChatTitle.hidden=!mobile;
    if (mobile) {
        CGFloat rh=NSHeight([(NSView *)self.rosterWindow.contentView bounds]);
        self.brandTitle.stringValue=groups ? JML(@"Список контактов") : JML(@"Переписки");
        self.brandTitle.frame=NSMakeRect(32,39,rosterWidth-(red ? 64 : 40),21);
        self.brandTitle.font=[NSFont boldSystemFontOfSize:15];
        self.brandTitle.alignment=red ? NSCenterTextAlignment : NSLeftTextAlignment;
        self.brandImage.frame=NSMakeRect(8,39,18,18);
        self.accountLabel.frame=NSMakeRect(9,10,rosterWidth-166,20);
        self.accountLabel.textColor=red ? JMThemeHeaderInk() : [NSColor colorWithSRGBRed:0.05 green:0.14 blue:0.25 alpha:1];
        self.presencePopup.frame=NSMakeRect(rosterWidth-151,rh-59,143,23);
        self.presencePopup.font=[NSFont systemFontOfSize:10];
        self.reconnectButton.frame=self.presencePopup.frame;
        self.presencePopup.hidden=!self.client.connected;
        self.statusLabel.frame=NSMakeRect(8,mobileFooterHeight+4,rosterWidth-16,18);
        self.presenceFeedback.frame=self.statusLabel.frame;
        BOOL showPresence=self.client.connected && self.presenceFeedback.stringValue.length>0;
        self.presenceFeedback.hidden=!showPresence; self.statusLabel.hidden=showPresence;
        if (notice) { self.countLabel.frame=NSMakeRect(8,25,rosterWidth-16,17); self.contactNotice.frame=NSMakeRect(8,0,rosterWidth-16,24); }
        self.mobileFooter.frame=NSMakeRect(0,0,rosterWidth,mobileFooterHeight);
        self.mobileFooter.topColor=red ? JMThemeHeaderTop() : JMThemeBackground();
        self.mobileFooter.bottomColor=self.mobileFooter.topColor;
        CGFloat available=rosterWidth-16;
        CGFloat settingsWidth=red ? floor(available/3) : 112;
        CGFloat otherWidth=floor((available-settingsWidth)/2);
        CGFloat buttonHeight=red ? 40 : 26;
        self.mobileFind.frame=NSMakeRect(4,5,otherWidth,buttonHeight);
        self.themeMainMenu.frame=NSMakeRect(8+otherWidth,5,otherWidth,buttonHeight);
        self.mobileSettings.frame=NSMakeRect(12+otherWidth*2,5,settingsWidth,buttonHeight);
        if (!groups) {
            NSRect searchFrame=self.searchField.frame;
            CGFloat filterHeight=22, gap=4;
            CGFloat filterY=NSMinY(searchFrame)-gap-filterHeight;
            self.mobileUnread.frame=NSMakeRect(NSMinX(searchFrame),filterY,NSWidth(searchFrame),filterHeight);
            self.mobileUnread.state=self.unreadOnly ? NSOnState : NSOffState;
            self.contactTable.enclosingScrollView.frame=NSMakeRect(4,footer,rosterWidth-8,MAX(0,filterY-gap-footer));
        }
        CGFloat titleInset=red ? 62 : 12;
        self.mobileChatTitle.frame=NSMakeRect(titleInset,ch-26,cw-titleInset-62,20);
        self.mobileChatTitle.alignment=red ? NSCenterTextAlignment : NSLeftTextAlignment;
        self.mobileChatTitle.textColor=JMThemeHeaderInk();
        JMSetLabel(self.mobileChatTitle,self.selectedPeer.length ? JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer}) : JML(@"Переписки"));
        self.themeUINTitle.hidden=YES; self.themeUINValue.hidden=YES; self.themeNickTitle.hidden=YES; self.themeNickValue.hidden=YES; self.themeRecipientState.hidden=YES;
    } else {
        self.brandTitle.alignment=JMTheme()==JMThemePro2003 ? NSCenterTextAlignment : NSLeftTextAlignment;
        if (JMTheme()==JMThemePro2003) self.brandTitle.frame=NSMakeRect(29,27,rosterWidth-58,18);
    }
    NSRect listFrame=self.contactTable.enclosingScrollView.frame;
    CGFloat emptyHeight=MIN(100,NSHeight(listFrame));
    self.emptyListLabel.frame=NSMakeRect(12,floor(NSMidY(listFrame)-emptyHeight/2),rosterWidth-24,emptyHeight);
    self.soundButton.hidden=mobile; self.logoutButton.hidden=mobile;
    self.addContactButton.hidden=mobile; self.writeConversationButton.hidden=mobile;
    [self updateHistoricalTabs];
}
- (void)windowDidResize:(NSNotification *)notification { if (notification.object==self.chatWindow || notification.object==self.rosterWindow) [self layoutChatWindow]; if (notification.object==self.chatWindow && JMTheme()==JMThemeMac2011) [self renderTranscript]; }
- (BOOL)canChangeRoster { return !self.dataOperationInProgress && self.client.connected && !self.changingRoster && !self.addingContact; }
- (NSString *)contactForAction:(id)sender {
    if ([sender isKindOfClass:[NSMenuItem class]] && [sender representedObject]==[NSNull null]) return @"";
    if ([sender isKindOfClass:[NSMenuItem class]] && JMValidUIN(JMString([sender representedObject]))) return [sender representedObject];
    if (JMTheme()!=JMThemeCurrent && self.rosterWindow.isKeyWindow && self.contactTable.selectedRow>=0 && self.contactTable.selectedRow<(NSInteger)self.visibleContacts.count) return self.visibleContacts[(NSUInteger)self.contactTable.selectedRow][@"aimId"];
    return self.selectedPeer ?: @"";
}
- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu!=self.contactMenu) return;
    if (![menu itemWithTitle:JML(@"Блокировка контакта…")]) {
        NSMenuItem *block=[menu addItemWithTitle:JML(@"Блокировка контакта…") action:@selector(toggleContactBlock:) keyEquivalent:@""];
        block.target=self;
    }
    NSInteger row=self.contactTable.clickedRow;
    // A keyboard context menu acts on the selection. A mouse click in empty
    // space must not silently reuse the previously selected conversation.
    if ([[NSApp currentEvent] type]==NSKeyDown) row=self.contactTable.selectedRow;
    NSString *peer=row>=0 && row<(NSInteger)self.visibleContacts.count ? self.visibleContacts[(NSUInteger)row][@"aimId"] : nil;
    for (NSMenuItem *item in menu.itemArray) item.representedObject=peer ?: (id)[NSNull null];
}
- (void)writeContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (!JMValidUIN(peer)) return;
    [self.sectionControl setSelectedSegment:1]; [self changeSection:nil]; [self selectPeer:peer];
}
- (void)profileContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (!JMValidUIN(peer)) return;
    [self createProfileWindow]; self.profilePeer=peer;
    [self.profileAbout setString:self.profileTexts[peer] ?: JML(@"Загружаем профиль…")];
    [self updateProfileCard]; [self.profileWindow makeKeyAndOrderFront:nil]; [self refreshProfile:nil];
}
- (NSUInteger)contactsInGroup:(NSString *)group {
    NSUInteger count=0; for (NSString *peer in self.serverContactIDs) if ([JMArray(self.contacts[peer][@"groups"]) containsObject:group]) count++;
    return count;
}
- (void)refreshGroupChoices {
    NSArray *names=[self.serverGroups sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (self.selectedGroup && ![names containsObject:self.selectedGroup]) self.selectedGroup=nil;
    [self.groupFilter removeAllItems]; [self.groupFilter addItemWithTitle:JML(@"Все группы")];
    for (NSString *name in names) { [self.groupFilter addItemWithTitle:name]; self.groupFilter.lastItem.representedObject=name; }
    [[self.groupFilter menu] addItem:[NSMenuItem separatorItem]];
    [self.groupFilter addItemWithTitle:JML(@"Управление группами…")]; self.groupFilter.lastItem.tag=10001;
    [self.groupFilter selectItemAtIndex:0];
    for (NSMenuItem *item in self.groupFilter.itemArray) if ([item.representedObject isEqual:self.selectedGroup]) [self.groupFilter selectItem:item];
    self.groupFilter.toolTip=self.selectedGroup.length ? [NSString stringWithFormat:JML(@"Группа: %@\nВыберите «Все группы», чтобы увидеть весь контакт-лист."),self.selectedGroup] : JML(@"Все группы контактов. Здесь же доступно управление группами.");
    [self.themeGroupMenu removeAllItems];
    NSMenuItem *all=[self.themeGroupMenu addItemWithTitle:JML(@"Все группы") action:@selector(filterHistoricalGroup:) keyEquivalent:@""]; all.target=self; all.representedObject=[NSNull null]; all.state=self.selectedGroup ? NSOffState : NSOnState;
    for (NSString *name in names) { NSMenuItem *item=[self.themeGroupMenu addItemWithTitle:name action:@selector(filterHistoricalGroup:) keyEquivalent:@""]; item.target=self; item.representedObject=name; item.state=[name isEqual:self.selectedGroup] ? NSOnState : NSOffState; }
    [self.themeGroupMenu addItem:[NSMenuItem separatorItem]]; NSMenuItem *manage=[self.themeGroupMenu addItemWithTitle:JML(@"Управление группами…") action:@selector(showGroups:) keyEquivalent:@""]; manage.target=self;
    [self updateGroupWindow];
}
- (void)groupFilterChanged:(id)sender {
    if (self.groupFilter.selectedItem.tag==10001) { [self refreshGroupChoices]; [self showGroups:nil]; return; }
    self.selectedGroup=self.groupFilter.selectedItem.representedObject; [self refreshGroupChoices]; [self reloadContacts];
}
- (void)showGroups:(id)sender {
    if (!self.groupsWindow) {
        self.groupsWindow=[[JMPanel alloc] initWithContentRect:NSMakeRect(0,0,480,270) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
        self.groupsWindow.title=JML(@"Группы — JimmMac"); self.groupsWindow.releasedWhenClosed=NO; self.groupsWindow.delegate=self;
        self.groupsWindow.contentView=[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,480,270)]; NSView *root=self.groupsWindow.contentView;
        [root addSubview:JMLabel(JML(@"Группы контактов"),NSMakeRect(24,222,432,24),16,YES)];
        NSTextField *help=JMLabel(JML(@"Создавайте группы и распределяйте контакты. Изменения сохраняются в Jimm.online."),NSMakeRect(24,184,432,32),11,NO); [[help cell] setWraps:YES]; [root addSubview:help];
        self.groupManagerPopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(20,145,440,32) pullsDown:NO];
        self.groupManagerPopup.target=self; self.groupManagerPopup.action=@selector(groupManagerChanged:); [self.groupManagerPopup setToolTip:JML(@"Выберите группу для переименования или удаления")]; [root addSubview:self.groupManagerPopup];
        self.groupCountLabel=JMLabel(@"",NSMakeRect(24,111,432,23),12,NO); [root addSubview:self.groupCountLabel];
        self.createGroupButton=JMButton(JML(@"Создать…"),NSMakeRect(16,64,132,32),self,@selector(createGroup:)); [root addSubview:self.createGroupButton];
        self.renameGroupButton=JMButton(JML(@"Переименовать…"),NSMakeRect(152,64,174,32),self,@selector(renameGroup:)); [root addSubview:self.renameGroupButton];
        self.removeGroupButton=JMButton(JML(@"Удалить…"),NSMakeRect(330,64,134,32),self,@selector(removeGroup:)); [self.removeGroupButton setToolTip:JML(@"Удалить выбранную группу. Доступно только для пустой группы.")]; [root addSubview:self.removeGroupButton];
        self.groupStatus=JMLabel(JML(@"Удаляется только пустая группа."),NSMakeRect(24,14,308,36),11,NO); [[self.groupStatus cell] setWraps:YES]; [root addSubview:self.groupStatus];
        NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(348,14,116,32),self,@selector(closeGroups:)); close.keyEquivalent=@"\e"; [root addSubview:close]; JMDecorateUtilityWindow(self.groupsWindow,JML(@"Управление группами")); [self.groupsWindow center];
    }
    [self updateGroupWindow]; [self.groupsWindow makeKeyAndOrderFront:nil];
}
- (void)closeGroups:(id)sender { [self.groupsWindow orderOut:nil]; }
- (void)groupManagerChanged:(id)sender { [self updateGroupWindow]; }
- (void)updateGroupWindow {
    if (!self.groupsWindow) return;
    NSString *selection=self.groupManagerPopup.selectedItem.representedObject;
    [self.groupManagerPopup removeAllItems];
    for (NSString *name in [self.serverGroups sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) { [self.groupManagerPopup addItemWithTitle:name]; self.groupManagerPopup.lastItem.representedObject=name; }
    if (!self.serverGroups.count) [self.groupManagerPopup addItemWithTitle:JML(@"Нет групп")];
    for (NSMenuItem *item in self.groupManagerPopup.itemArray) if ([item.representedObject isEqual:selection]) [self.groupManagerPopup selectItem:item];
    NSString *group=self.groupManagerPopup.selectedItem.representedObject;
    self.groupManagerPopup.toolTip=group ?: JML(@"Нет групп. Нажмите «Создать…».");
    JMSetLabel(self.groupCountLabel,group ? [NSString stringWithFormat:JML(@"Контактов в группе: %lu"),(unsigned long)[self contactsInGroup:group]] : JML(@"Создайте первую группу или добавьте контакт.")); [self updateGroupControls];
}
- (void)updateGroupControls {
    BOOL ready=[self canChangeRoster]; NSString *group=self.groupManagerPopup.selectedItem.representedObject;
    self.groupManagerPopup.enabled=self.serverGroups.count>0 && !self.changingRoster;
    self.createGroupButton.enabled=ready; self.renameGroupButton.enabled=ready && group.length;
    self.removeGroupButton.enabled=ready && group.length && [self contactsInGroup:group]==0;
}
- (NSAlert *)namePrompt:(NSString *)title detail:(NSString *)detail value:(NSString *)value {
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=title; alert.informativeText=detail;
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,330,25)]; field.stringValue=value ?: @""; field.toolTip=JML(@"До 128 символов, без переносов строки");
    alert.accessoryView=field; [alert addButtonWithTitle:JML(@"Сохранить")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"]; [alert.window setInitialFirstResponder:field]; return alert;
}
- (BOOL)beginRosterChange:(NSString *)status {
    if (![self canChangeRoster]) return NO;
    self.changingRoster=YES; JMSetLabel(self.contactNotice,status); JMSetLabel(self.groupStatus,status); [self updateSendButton]; return YES;
}
- (void)finishRosterChange:(NSError *)error status:(NSString *)status {
    self.changingRoster=NO;
    NSString *message=error ? JML(@"Изменение не подтверждено сервером.") : status;
    JMSetLabel(self.contactNotice,message); JMSetLabel(self.groupStatus,message);
    [self refreshGroupChoices]; [self reloadContacts]; [self updatePeerLabel]; [self updateProfileCard]; [self renderTranscript]; [self.historyTable reloadData]; [self updateSendButton];
    if (error) [self showError:JML(@"Не удалось изменить контакт-лист") detail:error.localizedDescription];
}
- (void)renameContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (![self canChangeRoster] || ![self.serverContactIDs containsObject:peer]) return;
    NSAlert *prompt=[self namePrompt:JML(@"Имя контакта") detail:JML(@"Личное имя контакта в Jimm.online. Пустое поле возвращает имя пользователя. До 128 символов.") value:JMName(self.contacts[peer])];
    if ([prompt runModal]!=NSAlertFirstButtonReturn) return;
    [self renameContactUIN:peer name:[[(NSTextField *)prompt.accessoryView stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
- (void)renameContactUIN:(NSString *)peer name:(NSString *)name {
    if (![self.serverContactIDs containsObject:peer] || ![self beginRosterChange:JML(@"Сохраняем имя…")]) return;
    [self.client renameContactWithUIN:peer name:name completion:^(NSDictionary *data,NSError *error) {
        if (!error) {
            if (name.length) { self.contacts[peer][@"_rosterFriendly"]=name; self.contacts[peer][@"friendly"]=name; }
            else { [self.contacts[peer] removeObjectForKey:@"_rosterFriendly"]; self.contacts[peer][@"friendly"]=peer; [self refreshPresenceForPeer:peer force:YES]; }
        }
        [self finishRosterChange:error status:JML(@"Имя сохранено в Jimm.online.")];
    }];
}
- (NSAlert *)removeContactPrompt:(NSString *)peer {
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Удалить контакт?");
    alert.informativeText=[NSString stringWithFormat:JML(@"%@ · UIN %@\nКонтакт будет удалён из всех групп Jimm.online. Переписка и локальная история сохранятся."),JMName(self.contacts[peer] ?: @{@"aimId":peer}),peer];
    [alert addButtonWithTitle:JML(@"Удалить из контактов")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"]; return alert;
}
- (void)removeContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (![self canChangeRoster] || ![self.serverContactIDs containsObject:peer]) return;
    if ([[self removeContactPrompt:peer] runModal]==NSAlertFirstButtonReturn) [self removeContactUIN:peer];
}
- (void)removeContactUIN:(NSString *)peer {
    if (![self.serverContactIDs containsObject:peer] || ![self beginRosterChange:JML(@"Удаляем контакт…")]) return;
    [self.client removeContactWithUIN:peer completion:^(NSDictionary *data,NSError *error) {
        if (!error) { [self.serverContactIDs removeObject:peer]; self.contacts[peer][@"groups"]=@[]; self.contacts[peer][@"group"]=@""; [self.contacts[peer] removeObjectForKey:@"_rosterFriendly"]; }
        [self finishRosterChange:error status:JML(@"Контакт удалён. История сохранена.")];
    }];
}
- (void)moveContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (![self canChangeRoster] || ![self.serverContactIDs containsObject:peer]) return;
    NSArray *sources=JMArray(self.contacts[peer][@"groups"]);
    if (!sources.count || self.serverGroups.count<2) { [self showGroups:nil]; JMSetLabel(self.groupStatus,JML(@"Сначала создайте другую группу для переноса.")); return; }
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Переместить контакт"); alert.informativeText=[NSString stringWithFormat:@"%@ · UIN %@",JMName(self.contacts[peer]),peer];
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,100)];
    [view addSubview:JMLabel(JML(@"Из группы"),NSMakeRect(0,65,85,23),12,NO)]; [view addSubview:JMLabel(JML(@"В группу"),NSMakeRect(0,21,85,23),12,NO)];
    NSPopUpButton *source=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(89,61,271,32) pullsDown:NO]; [source addItemsWithTitles:sources]; [view addSubview:source];
    NSPopUpButton *destination=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(89,17,271,32) pullsDown:NO]; [destination addItemsWithTitles:self.serverGroups];
    for (NSString *name in self.serverGroups) if (![name isEqualToString:source.titleOfSelectedItem]) { [destination selectItemWithTitle:name]; break; } [view addSubview:destination];
    source.toolTip=JML(@"Текущая группа контакта"); destination.toolTip=JML(@"Группа назначения"); alert.accessoryView=view; [alert addButtonWithTitle:JML(@"Переместить")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
    if ([alert runModal]==NSAlertFirstButtonReturn) [self moveContactUIN:peer from:source.titleOfSelectedItem to:destination.titleOfSelectedItem];
}
- (void)moveContactUIN:(NSString *)peer from:(NSString *)source to:(NSString *)destination {
    if (![self.serverContactIDs containsObject:peer] || ![JMArray(self.contacts[peer][@"groups"]) containsObject:source] || ![self.serverGroups containsObject:destination]) return;
    if ([source isEqualToString:destination]) { JMSetLabel(self.contactNotice,JML(@"Выберите другую группу.")); return; }
    if (![self beginRosterChange:JML(@"Перемещаем контакт…")]) return;
    [self.client moveContactWithUIN:peer fromGroup:source toGroup:destination completion:^(NSDictionary *data,NSError *error) {
        if (!error) { NSMutableArray *groups=[JMArray(self.contacts[peer][@"groups"]) mutableCopy]; [groups removeObject:source]; if (![groups containsObject:destination]) [groups addObject:destination]; self.contacts[peer][@"groups"]=groups; self.contacts[peer][@"group"]=[groups firstObject] ?: @""; }
        [self finishRosterChange:error status:JML(@"Контакт перемещён в Jimm.online.")];
    }];
}
- (void)createGroup:(id)sender {
    if (![self canChangeRoster]) return;
    NSAlert *prompt=[self namePrompt:JML(@"Создать группу") detail:JML(@"Название группы в Jimm.online. До 128 символов.") value:@""];
    if ([prompt runModal]==NSAlertFirstButtonReturn) [self createGroupNamed:[[(NSTextField *)prompt.accessoryView stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
- (void)createGroupNamed:(NSString *)name {
    if (![self beginRosterChange:JML(@"Создаём группу…")]) return;
    [self.client createGroup:name completion:^(NSDictionary *data,NSError *error) {
        if (!error && ![self.serverGroups containsObject:name]) [self.serverGroups addObject:name];
        [self finishRosterChange:error status:JML(@"Группа создана в Jimm.online.")]; if (!error) [self.groupManagerPopup selectItemWithTitle:name]; [self updateGroupWindow];
    }];
}
- (void)renameGroup:(id)sender {
    NSString *name=self.groupManagerPopup.selectedItem.representedObject; if (![self canChangeRoster] || !name.length) return;
    NSAlert *prompt=[self namePrompt:JML(@"Переименовать группу") detail:JML(@"Новое название группы в Jimm.online. До 128 символов.") value:name];
    if ([prompt runModal]==NSAlertFirstButtonReturn) [self renameGroupNamed:name to:[[(NSTextField *)prompt.accessoryView stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
- (void)renameGroupNamed:(NSString *)name to:(NSString *)newName {
    if (![self.serverGroups containsObject:name]) return;
    if (![name isEqualToString:newName] && [self.serverGroups containsObject:newName]) { JMSetLabel(self.groupStatus,JML(@"Группа с таким именем уже существует.")); return; }
    if (![self beginRosterChange:JML(@"Переименовываем группу…")]) return;
    [self.client renameGroup:name to:newName completion:^(NSDictionary *data,NSError *error) {
        if (!error) {
            [self.serverGroups removeObject:name]; if (![self.serverGroups containsObject:newName]) [self.serverGroups addObject:newName];
            for (NSString *peer in self.serverContactIDs) { NSMutableArray *groups=[JMArray(self.contacts[peer][@"groups"]) mutableCopy]; NSUInteger index=[groups indexOfObject:name]; if (index!=NSNotFound) groups[index]=newName; self.contacts[peer][@"groups"]=groups; self.contacts[peer][@"group"]=[groups firstObject] ?: @""; }
            if ([self.selectedGroup isEqualToString:name]) self.selectedGroup=newName;
        }
        [self finishRosterChange:error status:JML(@"Название группы сохранено.")]; if (!error) [self.groupManagerPopup selectItemWithTitle:newName]; [self updateGroupWindow];
    }];
}
- (void)removeGroup:(id)sender {
    NSString *name=self.groupManagerPopup.selectedItem.representedObject; if (![self canChangeRoster] || !name.length || [self contactsInGroup:name]) return;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Удалить пустую группу?"); alert.informativeText=name; [alert addButtonWithTitle:JML(@"Удалить")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
    if ([alert runModal]==NSAlertFirstButtonReturn) [self removeGroupNamed:name];
}
- (void)removeGroupNamed:(NSString *)name {
    if (![self.serverGroups containsObject:name] || [self contactsInGroup:name]) { JMSetLabel(self.groupStatus,JML(@"Сначала перенесите контакты из группы.")); return; }
    if (![self beginRosterChange:JML(@"Удаляем пустую группу…")]) return;
    [self.client removeGroup:name completion:^(NSDictionary *data,NSError *error) {
        if (!error) [self.serverGroups removeObject:name]; [self finishRosterChange:error status:JML(@"Пустая группа удалена.")];
    }];
}
- (void)showPreferences:(id)sender {
    if (!self.preferencesWindow) {
        self.preferencesWindow=[[JMPanel alloc] initWithContentRect:NSMakeRect(0,0,600,380) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
        [self.preferencesWindow setTitle:JML(@"Настройки — JimmMac")]; [self.preferencesWindow setReleasedWhenClosed:NO]; [self.preferencesWindow setDelegate:self];
        [self.preferencesWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,600,380)]];
        NSView *windowRoot=self.preferencesWindow.contentView;
        self.preferenceSections=[[NSSegmentedControl alloc] initWithFrame:NSZeroRect]; [self.preferenceSections setCell:[[JMThemedSegmentedCell alloc] init]]; [self.preferenceSections setSegmentCount:5];
        NSArray *sections=@[JML(@"Переписка"),JML(@"Уведомления"),JML(@"Звуки"),JML(@"Оформление"),JML(@"Статус")];
        for (NSUInteger i=0;i<sections.count;i++) { [self.preferenceSections setLabel:sections[i] forSegment:i]; [self.preferenceSections setWidth:110 forSegment:i]; [[self.preferenceSections cell] setToolTip:sections[i] forSegment:i]; }
        [self.preferenceSections setSegmentStyle:NSSegmentStyleRounded]; [self.preferenceSections sizeToFit];
        [self.preferenceSections setFrameOrigin:NSMakePoint(floor((600-NSWidth(self.preferenceSections.frame))/2),340)];
        [self.preferenceSections setSelectedSegment:0]; self.preferenceSections.target=self; self.preferenceSections.action=@selector(changePreferenceSection:); [windowRoot addSubview:self.preferenceSections];
        self.fontPreferencesView=[[NSView alloc] initWithFrame:NSMakeRect(60,56,480,268)]; [windowRoot addSubview:self.fontPreferencesView];
        self.notificationPreferencesView=[[NSView alloc] initWithFrame:self.fontPreferencesView.frame]; [windowRoot addSubview:self.notificationPreferencesView];
        self.soundPreferencesView=[[NSView alloc] initWithFrame:self.fontPreferencesView.frame]; [windowRoot addSubview:self.soundPreferencesView];
        NSView *root=self.fontPreferencesView;
        [root addSubview:JMLabel(JML(@"Шрифт переписки"),NSMakeRect(24,223,432,24),16,YES)];
        NSTextField *description=JMLabel(JML(@"Применяется к сообщениям и полю ввода. Изменения сохраняются сразу."),NSMakeRect(24,185,432,33),11,NO);
        [[description cell] setWraps:YES]; [root addSubview:description];
        [root addSubview:JMLabel(JML(@"Шрифт"),NSMakeRect(24,153,80,22),13,NO)];
        self.fontFamilyPopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(108,149,350,29) pullsDown:NO];
        [self.fontFamilyPopup addItemWithTitle:JML(@"Системный")]; self.fontFamilyPopup.lastItem.representedObject=@"";
        for (NSString *family in [[[NSFontManager sharedFontManager] availableFontFamilies] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
            [self.fontFamilyPopup addItemWithTitle:family]; self.fontFamilyPopup.lastItem.representedObject=family;
        }
        self.fontFamilyPopup.target=self; self.fontFamilyPopup.action=@selector(fontSettingsChanged:);
        [self.fontFamilyPopup setToolTip:JML(@"Семейство шрифта для текста сообщений и черновиков")]; [root addSubview:self.fontFamilyPopup];
        [root addSubview:JMLabel(JML(@"Размер"),NSMakeRect(24,114,80,22),13,NO)];
        self.fontSizePopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(108,110,92,29) pullsDown:NO];
        for (NSInteger size=9;size<=28;size++) { [self.fontSizePopup addItemWithTitle:[NSString stringWithFormat:@"%ld",(long)size]]; self.fontSizePopup.lastItem.representedObject=@(size); }
        self.fontSizePopup.target=self; self.fontSizePopup.action=@selector(fontSettingsChanged:); [self.fontSizePopup setToolTip:JML(@"Размер шрифта от 9 до 28 пунктов")]; [root addSubview:self.fontSizePopup];
        self.fontPreview=JMLabel(JML(@"Привет из JimmMac!"),NSMakeRect(24,65,432,44),13,NO);
        self.fontPreview.tag=515; [[self.fontPreview cell] setWraps:YES]; [self.fontPreview setBordered:YES]; [self.fontPreview setDrawsBackground:YES]; [self.fontPreview setBackgroundColor:[NSColor textBackgroundColor]]; [root addSubview:self.fontPreview];
        [root addSubview:JMLabel(JML(@"Отправка"),NSMakeRect(24,15,80,22),13,NO)];
        self.sendModePopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(108,10,350,29) pullsDown:NO];
        [self.sendModePopup addItemsWithTitles:@[@"Enter",@"⌘Enter (Command+Enter)"]];
        self.sendModePopup.target=self; self.sendModePopup.action=@selector(sendModeChanged:);
        self.sendModePopup.toolTip=JML(@"При выборе ⌘Enter обычный Enter добавляет строку. Shift+Enter всегда добавляет строку"); [root addSubview:self.sendModePopup];
        self.emoticonsCheckbox=JMCheckbox(JML(@"Классические смайлики в сообщениях"),NSMakeRect(24,39,432,24),self,@selector(toggleEmoticons:)); self.emoticonsCheckbox.toolTip=JML(@"Показывать :) :( ;) как картинки. Текст при отправке, копировании и экспорте сохраняется"); [root addSubview:self.emoticonsCheckbox];
        [self createAlertPreferenceViews]; [self createAppearancePreferenceViews];
        self.fontResetButton=JMButton(JML(@"Сбросить шрифт"),NSMakeRect(20,13,154,32),self,@selector(resetChatFont:)); [windowRoot addSubview:self.fontResetButton];
        NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(466,13,114,32),self,@selector(closePreferences:)); close.keyEquivalent=@"\e"; [windowRoot addSubview:close];
        [self.preferencesWindow center];
    }
    JMDecorateUtilityWindow(self.preferencesWindow,JML(@"Настройки")); [self syncFontControls]; self.emoticonsCheckbox.state=self.chatPreferences.emoticonsEnabled ? NSOnState : NSOffState; [self syncAlertControls]; [self changePreferenceSection:nil]; [self.preferencesWindow makeKeyAndOrderFront:nil];
}
- (void)createAlertPreferenceViews {
    NSView *root=self.notificationPreferencesView;
    [root addSubview:JMLabel(JML(@"Уведомления о сообщениях"),NSMakeRect(24,223,432,24),16,YES)];
    NSTextField *help=JMLabel(JML(@"Для сообщений вне открытой переписки. Вид баннера задаётся в «Системные настройки → Уведомления» OS X."),NSMakeRect(24,184,432,34),11,NO); [[help cell] setWraps:YES]; [root addSubview:help];
    self.notificationsCheckbox=JMCheckbox(JML(@"Показывать системные уведомления"),NSMakeRect(24,146,432,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.notificationsCheckbox];
    [root addSubview:JMLabel(JML(@"В уведомлении"),NSMakeRect(24,110,136,23),13,NO)];
    self.notificationContentPopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(164,105,292,32) pullsDown:NO];
    NSArray *titles=@[JML(@"Только имя отправителя"),JML(@"Имя и текст сообщения"),JML(@"Без имени и текста")], *styles=@[@"sender",@"preview",@"private"];
    for (NSUInteger i=0;i<titles.count;i++) { [self.notificationContentPopup addItemWithTitle:titles[i]]; self.notificationContentPopup.lastItem.representedObject=styles[i]; }
    self.notificationContentPopup.target=self; self.notificationContentPopup.action=@selector(alertPreferencesChanged:); self.notificationContentPopup.toolTip=JML(@"Какие сведения видны в баннере и Центре уведомлений"); [root addSubview:self.notificationContentPopup];
    self.notificationPrivacyHelp=JMLabel(@"",NSMakeRect(24,66,432,34),11,NO); [[self.notificationPrivacyHelp cell] setWraps:YES]; [root addSubview:self.notificationPrivacyHelp];
    self.dockAttentionCheckbox=JMCheckbox(JML(@"Привлекать внимание значком Dock"),NSMakeRect(24,36,432,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.dockAttentionCheckbox];
    self.notificationTestButton=JMButton(JML(@"Проверить уведомление"),NSMakeRect(18,0,228,32),self,@selector(testNotification:)); self.notificationTestButton.toolTip=JML(@"Показать тестовый баннер JimmMac. Сообщения собеседникам не отправляются."); [root addSubview:self.notificationTestButton];
    self.notificationTestStatus=JMLabel(@"",NSMakeRect(252,5,208,24),11,NO); [root addSubview:self.notificationTestStatus];
    root=self.soundPreferencesView;
    [root addSubview:JMLabel(JML(@"Звуковые оповещения"),NSMakeRect(24,223,432,24),16,YES)];
    help=JMLabel(JML(@"Оригинальные звуки Jimm.online. Кнопки внизу позволяют прослушать каждый сигнал."),NSMakeRect(24,184,432,34),11,NO); [[help cell] setWraps:YES]; [root addSubview:help];
    self.soundMasterCheckbox=JMCheckbox(JML(@"Включить звуковые оповещения"),NSMakeRect(24,148,432,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.soundMasterCheckbox];
    self.presenceSoundCheckbox=JMCheckbox(JML(@"Появление и выход контактов"),NSMakeRect(44,114,412,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.presenceSoundCheckbox];
    self.typingSoundCheckbox=JMCheckbox(JML(@"Набор текста собеседником"),NSMakeRect(44,80,412,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.typingSoundCheckbox];
    self.openConversationSoundCheckbox=JMCheckbox(JML(@"Звук в открытой переписке"),NSMakeRect(44,46,412,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.openConversationSoundCheckbox];
    NSArray *soundTitles=@[JML(@"Сообщение"),JML(@"В сети"),JML(@"Вышел"),JML(@"Печатает")];
    for (NSUInteger i=0;i<soundTitles.count;i++) { NSButton *sample=JMButton(soundTitles[i],NSMakeRect(18+i*114,4,110,32),self,@selector(previewSoundButton:)); sample.tag=i; sample.toolTip=[JML(@"Прослушать: ") stringByAppendingString:soundTitles[i]]; [root addSubview:sample]; }
}
- (void)changePreferenceSection:(id)sender {
    NSInteger section=self.preferenceSections.selectedSegment;
    self.fontPreferencesView.hidden=section!=0; self.notificationPreferencesView.hidden=section!=1; self.soundPreferencesView.hidden=section!=2; self.fontResetButton.hidden=section!=0; self.appearancePreferencesView.hidden=section!=3; self.statusPreferencesView.hidden=section!=4; self.appearanceResetButton.hidden=section!=3;
}
- (void)createAppearancePreferenceViews {
    NSView *root=self.preferencesWindow.contentView;
    self.appearancePreferencesView=[[NSView alloc] initWithFrame:self.fontPreferencesView.frame]; [root addSubview:self.appearancePreferencesView];
    self.statusPreferencesView=[[NSView alloc] initWithFrame:self.fontPreferencesView.frame]; [root addSubview:self.statusPreferencesView];
    NSView *view=self.appearancePreferencesView;
    [view addSubview:JMLabel(JML(@"Оформление"),NSMakeRect(24,234,100,22),13,YES)];
    self.appearancePopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(136,230,320,30) pullsDown:NO];
    NSArray *titles=@[JML(@"Текущий JimmMac"),@"ICQ for Mac 2011",@"ICQ Pro 2003b",@"QIP",@"Jimm"], *identifiers=JMThemeIdentifiers();
    for (NSUInteger i=0;i<titles.count;i++) { [self.appearancePopup addItemWithTitle:titles[i]]; self.appearancePopup.lastItem.representedObject=identifiers[i]; }
    self.appearancePopup.target=self; self.appearancePopup.action=@selector(appearancePreferencesChanged:); self.appearancePopup.toolTip=JML(@"Оформление применяется сразу; черновики сохраняются"); [view addSubview:self.appearancePopup];
    [view addSubview:JMLabel(JML(@"Список"),NSMakeRect(24,194,100,22),13,NO)];
    self.densityPopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(136,190,320,30) pullsDown:NO];
    [self.densityPopup addItemsWithTitles:@[JML(@"Обычный"),JML(@"Компактный")]]; self.densityPopup.target=self; self.densityPopup.action=@selector(appearancePreferencesChanged:); self.densityPopup.toolTip=JML(@"Компактный список показывает больше контактов"); [view addSubview:self.densityPopup];
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,44,432,134)]; scroll.hasVerticalScroller=YES; scroll.borderType=NSBezelBorder;
    self.appearancePreview=[[JMTranscriptView alloc] initWithFrame:scroll.contentView.bounds]; self.appearancePreview.editable=NO; self.appearancePreview.selectable=YES; self.appearancePreview.textContainerInset=NSMakeSize(10,10); self.appearancePreview.autoresizingMask=NSViewWidthSizable; self.appearancePreview.textContainer.widthTracksTextView=YES; scroll.documentView=self.appearancePreview; [view addSubview:scroll];
    [view addSubview:JMLabel(JML(@"Образец переписки · настройки сохраняются сразу"),NSMakeRect(24,12,432,22),11,NO)];
    self.appearanceResetButton=JMButton(JML(@"Стандартные настройки…"),NSMakeRect(14,13,244,32),self,@selector(resetPreferences:)); self.appearanceResetButton.toolTip=JML(@"Вернуть стандартные настройки без удаления истории и входа"); [root addSubview:self.appearanceResetButton];
    view=self.statusPreferencesView;
    [view addSubview:JMLabel(JML(@"Автоматический статус"),NSMakeRect(24,223,432,24),16,YES)];
    NSTextField *help=JMLabel(JML(@"Переключаться на «Отошёл» при бездействии и возвращаться после активности. Ручной выбор статуса имеет приоритет."),NSMakeRect(24,160,432,54),12,NO); [[help cell] setWraps:YES]; [view addSubview:help];
    [view addSubview:JMLabel(JML(@"Бездействие"),NSMakeRect(24,120,140,22),13,NO)];
    self.autoAwayPopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(172,116,284,30) pullsDown:NO];
    for (NSNumber *minutes in @[@0,@5,@10,@15,@30,@60]) { [self.autoAwayPopup addItemWithTitle:minutes.integerValue ? [NSString stringWithFormat:JML(@"%ld мин."),(long)minutes.integerValue] : JML(@"Выключено")]; self.autoAwayPopup.lastItem.representedObject=minutes; }
    self.autoAwayPopup.target=self; self.autoAwayPopup.action=@selector(autoAwaySettingsChanged:); self.autoAwayPopup.toolTip=JML(@"Учитывается активность на Mac, а не только в JimmMac"); [view addSubview:self.autoAwayPopup];
    help=JMLabel(JML(@"«Не беспокоить», «Невидимый» и другие выбранные вручную статусы автоматически не меняются."),NSMakeRect(24,54,432,50),11,NO); [[help cell] setWraps:YES]; [view addSubview:help];
}
- (void)syncAppearanceControls {
    for (NSMenuItem *item in self.appearancePopup.itemArray) if ([item.representedObject isEqual:JMThemeIdentifier()]) [self.appearancePopup selectItem:item];
    [self.densityPopup selectItemAtIndex:[self.loginDefaults boolForKey:@"CompactContactList"] ? 1 : 0];
    for (NSMenuItem *item in self.autoAwayPopup.itemArray) if ([item.representedObject integerValue]==[self.loginDefaults integerForKey:@"AutoAwayMinutes"]) [self.autoAwayPopup selectItem:item];
    if (!self.appearancePreview) return;
    NSFont *font=JMThemeFont(self.chatPreferences.messageFont,self.chatPreferences.family);
    NSMutableAttributedString *text=[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@  12:34\n%@\n\n%@  12:35\n%@",JML(@"Собеседник"),JML(@"Привет! Рада снова видеть тебя :)"),JML(@"Вы"),JML(@"Привет из JimmMac! ;)" )] attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:[NSColor textColor]}];
    if (self.chatPreferences.emoticonsEnabled) JMApplyEmoticons(text);
    [self.appearancePreview.textStorage setAttributedString:text]; self.appearancePreview.backgroundColor=JMThemeTranscriptColor();
    self.fontPreview.attributedStringValue=[[NSAttributedString alloc] initWithString:JML(@"Привет из JimmMac! :)") attributes:@{NSFontAttributeName:font}];
    if (self.chatPreferences.emoticonsEnabled) { NSMutableAttributedString *sample=[self.fontPreview.attributedStringValue mutableCopy]; JMApplyEmoticons(sample); self.fontPreview.attributedStringValue=sample; }
}
- (void)appearancePreferencesChanged:(id)sender {
    if (sender==self.appearancePopup) [self.loginDefaults setObject:self.appearancePopup.selectedItem.representedObject forKey:@"InterfaceAppearance"];
    if (sender==self.densityPopup) [self.loginDefaults setBool:self.densityPopup.indexOfSelectedItem==1 forKey:@"CompactContactList"];
    [self applyAppearance]; [self syncAppearanceControls];
}
- (void)resetPreferences:(id)sender {
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Вернуть стандартные настройки?"); alert.informativeText=JML(@"Шрифт, оформление, звуки, уведомления и автоматический статус будут сброшены. История, контакты, черновики и сохранённый вход останутся.");
    [alert addButtonWithTitle:JML(@"Сбросить")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
    if ([alert runModal]!=NSAlertFirstButtonReturn) return; [self restoreStandardPreferences];
}
- (void)restoreStandardPreferences {
    [self.chatPreferences reset]; self.chatPreferences.emoticonsEnabled=YES; self.chatPreferences.sendWithCommandReturn=NO;
    [self.loginDefaults setObject:@"current" forKey:@"InterfaceAppearance"]; [self.loginDefaults setBool:NO forKey:@"CompactContactList"]; [self.loginDefaults setInteger:0 forKey:@"AutoAwayMinutes"];
    self.audioAlerts.enabled=YES; self.audioAlerts.presenceEnabled=YES; self.audioAlerts.typingEnabled=NO; self.audioAlerts.soundInOpenConversation=YES;
    self.notificationAlerts.enabled=YES; self.notificationAlerts.dockAttentionEnabled=YES; self.notificationAlerts.contentStyle=@"sender";
    [self applyAppearance]; [self syncFontControls]; [self syncAlertControls]; [self syncAppearanceControls]; [self updateSoundControls]; [self updateSendButton]; self.emoticonsCheckbox.state=NSOnState; [self autoAwayTick:nil];
}
- (void)syncAlertControls {
    self.notificationsCheckbox.state=self.notificationAlerts.enabled ? NSOnState : NSOffState;
    self.dockAttentionCheckbox.state=self.notificationAlerts.dockAttentionEnabled ? NSOnState : NSOffState;
    for (NSMenuItem *item in self.notificationContentPopup.itemArray) if ([item.representedObject isEqualToString:self.notificationAlerts.contentStyle]) [self.notificationContentPopup selectItem:item];
    self.notificationContentPopup.enabled=self.notificationAlerts.enabled; self.notificationTestButton.enabled=self.notificationAlerts.enabled;
    NSString *privacy=[self.notificationAlerts.contentStyle isEqualToString:@"private"] ? JML(@"Имя отправителя и текст сообщения скрыты.") : ([self.notificationAlerts.contentStyle isEqualToString:@"preview"] ? JML(@"Видны имя отправителя и начало сообщения.") : JML(@"Видно имя отправителя. Текст сообщения скрыт.")); JMSetLabel(self.notificationPrivacyHelp,privacy);
    self.soundMasterCheckbox.state=self.audioAlerts.enabled ? NSOnState : NSOffState;
    self.presenceSoundCheckbox.state=self.audioAlerts.presenceEnabled ? NSOnState : NSOffState;
    self.typingSoundCheckbox.state=self.audioAlerts.typingEnabled ? NSOnState : NSOffState;
    self.openConversationSoundCheckbox.state=self.audioAlerts.soundInOpenConversation ? NSOnState : NSOffState;
    self.presenceSoundCheckbox.enabled=self.audioAlerts.enabled; self.typingSoundCheckbox.enabled=self.audioAlerts.enabled; self.openConversationSoundCheckbox.enabled=self.audioAlerts.enabled;
}
- (void)alertPreferencesChanged:(id)sender {
    if (sender==self.notificationsCheckbox) self.notificationAlerts.enabled=self.notificationsCheckbox.state==NSOnState;
    if (sender==self.notificationContentPopup) self.notificationAlerts.contentStyle=self.notificationContentPopup.selectedItem.representedObject;
    if (sender==self.dockAttentionCheckbox) self.notificationAlerts.dockAttentionEnabled=self.dockAttentionCheckbox.state==NSOnState;
    if (sender==self.soundMasterCheckbox) self.audioAlerts.enabled=self.soundMasterCheckbox.state==NSOnState;
    if (sender==self.presenceSoundCheckbox) self.audioAlerts.presenceEnabled=self.presenceSoundCheckbox.state==NSOnState;
    if (sender==self.typingSoundCheckbox) self.audioAlerts.typingEnabled=self.typingSoundCheckbox.state==NSOnState;
    if (sender==self.openConversationSoundCheckbox) self.audioAlerts.soundInOpenConversation=self.openConversationSoundCheckbox.state==NSOnState;
    JMSetLabel(self.notificationTestStatus,@""); [self updateSoundControls];
}
- (void)testNotification:(id)sender { JMSetLabel(self.notificationTestStatus,[self.notificationAlerts sendTestNotification] ? JML(@"Отправлено в систему.") : JML(@"Уведомления недоступны.")); }
- (void)previewSoundButton:(NSButton *)sender { NSArray *events=@[@"message",@"online",@"offline",@"typing"]; if (sender.tag>=0 && sender.tag<(NSInteger)events.count) [self.audioAlerts previewEvent:events[(NSUInteger)sender.tag]]; }
- (void)syncFontControls {
    [self.sendModePopup selectItemAtIndex:self.chatPreferences.sendWithCommandReturn ? 1 : 0];
    for (NSMenuItem *item in self.fontFamilyPopup.itemArray) if ([item.representedObject isEqual:self.chatPreferences.family]) { [self.fontFamilyPopup selectItem:item]; break; }
    for (NSMenuItem *item in self.fontSizePopup.itemArray) if ([item.representedObject doubleValue]==self.chatPreferences.size) { [self.fontSizePopup selectItem:item]; break; }
    self.fontPreview.font=self.chatPreferences.messageFont; [self syncAppearanceControls];
}
- (void)applyChatFont {
    self.composer.font=JMThemeFont(self.chatPreferences.messageFont,self.chatPreferences.family);
    self.composer.typingAttributes=@{NSFontAttributeName:JMThemeFont(self.chatPreferences.messageFont,self.chatPreferences.family),NSForegroundColorAttributeName:[NSColor textColor]};
    [self renderTranscript]; [self syncFontControls];
}
- (void)fontSettingsChanged:(id)sender {
    [self.chatPreferences setFamily:self.fontFamilyPopup.selectedItem.representedObject size:[self.fontSizePopup.selectedItem.representedObject doubleValue]];
    [self applyChatFont];
}
- (void)resetChatFont:(id)sender { [self.chatPreferences reset]; [self applyChatFont]; }
- (void)sendModeChanged:(id)sender { self.chatPreferences.sendWithCommandReturn=self.sendModePopup.indexOfSelectedItem==1; [self updateSendButton]; }
- (void)closePreferences:(id)sender { [self.preferencesWindow orderOut:nil]; }
- (NSDate *)startOfDay:(NSDate *)date {
    NSDate *start=nil; [[NSCalendar currentCalendar] rangeOfUnit:NSDayCalendarUnit startDate:&start interval:NULL forDate:date]; return start ?: date;
}
- (NSDate *)dayAfter:(NSDate *)date { NSDateComponents *day=[[NSDateComponents alloc] init]; day.day=1; return [[NSCalendar currentCalendar] dateByAddingComponents:day toDate:[self startOfDay:date] options:0]; }
- (NSDatePicker *)datePickerAt:(NSRect)frame action:(SEL)action {
    NSDatePicker *picker=[[NSDatePicker alloc] initWithFrame:frame]; picker.datePickerStyle=NSTextFieldAndStepperDatePickerStyle; picker.datePickerElements=NSYearMonthDayDatePickerElementFlag; picker.dateValue=[NSDate date]; picker.target=self; picker.action=action; picker.toolTip=JML(@"Дата по местному времени Mac"); return picker;
}
- (void)createHistoryWindow {
    if (self.historyWindow) return;
    self.historyWindow=[[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,720,540) styleMask:NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
    self.historyWindow.title=JML(@"Поиск по истории — JimmMac"); self.historyWindow.releasedWhenClosed=NO; self.historyWindow.delegate=self; self.historyWindow.contentMinSize=NSMakeSize(720,440);
    self.historyWindow.contentView=[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,720,540)]; NSView *root=self.historyWindow.contentView;
    self.historySearchField=[[JMThemedSearchField alloc] initWithFrame:NSMakeRect(20,496,416,28)];
    [[self.historySearchField cell] setPlaceholderString:JML(@"Слово или фраза в сообщениях")]; self.historySearchField.delegate=self; self.historySearchField.target=self; self.historySearchField.action=@selector(searchHistory:); self.historySearchField.autoresizingMask=NSViewWidthSizable|NSViewMinYMargin;
    self.historySearchField.toolTip=JML(@"Поиск по сохранённым сообщениям текущего аккаунта. Регистр букв не важен."); [root addSubview:self.historySearchField];
    self.historyScopePopup=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(448,493,252,32) pullsDown:NO];
    [self.historyScopePopup addItemsWithTitles:@[JML(@"Все переписки"),JML(@"Текущая переписка")]]; self.historyScopePopup.autoenablesItems=NO;
    self.historyScopePopup.target=self; self.historyScopePopup.action=@selector(searchHistory:); self.historyScopePopup.autoresizingMask=NSViewMinXMargin|NSViewMinYMargin; self.historyScopePopup.toolTip=JML(@"Все переписки или выбранный собеседник"); [root addSubview:self.historyScopePopup];
    self.historyDateCheckbox=JMCheckbox(JML(@"Период"),NSMakeRect(20,452,96,24),self,@selector(searchHistory:)); [root addSubview:self.historyDateCheckbox];
    self.historyFromDate=[self datePickerAt:NSMakeRect(120,452,142,24) action:@selector(searchHistory:)]; [root addSubview:self.historyFromDate];
    NSTextField *dash=JMLabel(@"—",NSMakeRect(270,453,20,22),13,NO); [root addSubview:dash];
    self.historyUntilDate=[self datePickerAt:NSMakeRect(298,452,142,24) action:@selector(searchHistory:)]; [root addSubview:self.historyUntilDate];
    NSButton *jump=JMButton(JML(@"К дню"),NSMakeRect(448,448,104,32),self,@selector(jumpToHistoryDay:)); jump.toolTip=JML(@"Открыть первое сообщение выбранной переписки за начальную дату периода"); [root addSubview:jump];
    self.historyBookmarkCheckbox=JMCheckbox(JML(@"Закладки"),NSMakeRect(566,452,134,24),self,@selector(searchHistory:)); [root addSubview:self.historyBookmarkCheckbox];
    for (NSView *view in @[self.historyDateCheckbox,self.historyFromDate,dash,self.historyUntilDate,jump,self.historyBookmarkCheckbox]) view.autoresizingMask=NSViewMinYMargin;
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(20,66,680,368)]; scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable; scroll.hasVerticalScroller=YES; scroll.borderType=NSBezelBorder;
    self.historyTable=[[JMContactTable alloc] initWithFrame:scroll.contentView.bounds]; NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"history"]; column.width=660; column.resizingMask=NSTableColumnAutoresizingMask;
    [self.historyTable addTableColumn:column]; self.historyTable.headerView=nil; self.historyTable.rowHeight=54; self.historyTable.delegate=self; self.historyTable.dataSource=self; self.historyTable.target=self; self.historyTable.doubleAction=@selector(openHistoryResult:); [(JMContactTable *)self.historyTable setActivateAction:@selector(openHistoryResult:)]; self.historyTable.columnAutoresizingStyle=NSTableViewLastColumnOnlyAutoresizingStyle;
    self.historyTable.toolTip=JML(@"Двойной щелчок — перейти к сообщению в переписке"); scroll.documentView=self.historyTable; [root addSubview:scroll];
    self.historySearchStatus=JMLabel(JML(@"Введите слово или фразу для поиска."),NSMakeRect(20,20,380,28),12,NO); self.historySearchStatus.autoresizingMask=NSViewWidthSizable; [root addSubview:self.historySearchStatus];
    NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(448,17,112,32),self,@selector(closeHistorySearch:)); close.keyEquivalent=@"\e"; close.autoresizingMask=NSViewMinXMargin; [root addSubview:close];
    self.historyOpenButton=JMButton(JML(@"Открыть"),NSMakeRect(566,17,134,32),self,@selector(openHistoryResult:)); self.historyOpenButton.keyEquivalent=@"\r"; self.historyOpenButton.autoresizingMask=NSViewMinXMargin; self.historyOpenButton.enabled=NO; [root addSubview:self.historyOpenButton];
    JMDecorateUtilityWindow(self.historyWindow,JML(@"История сообщений")); self.historyWindow.initialFirstResponder=self.historySearchField; [self.historyWindow center];
}
- (void)jumpToHistoryDay:(id)sender {
    NSString *peer=self.historyScopePopup.indexOfSelectedItem>1 ? self.historyScopePopup.selectedItem.representedObject : self.selectedPeer;
    if (!peer.length || !self.history) { JMSetLabel(self.historySearchStatus,JML(@"Сначала откройте переписку.")); return; }
    if (self.historyScopePopup.indexOfSelectedItem==0) [self.historyScopePopup selectItemAtIndex:1];
    NSDictionary *first=[self.history firstMessageForPeer:peer from:[self startOfDay:self.historyFromDate.dateValue] until:[self dayAfter:self.historyFromDate.dateValue]]; NSArray *hits=first ? @[first] : @[];
    if (!hits.count) { JMSetLabel(self.historySearchStatus,JML(@"В этот день сообщений нет.")); return; }
    self.historyResults=hits; self.historyResultsQuery=@""; [self.historyTable reloadData]; [self.historyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO]; [self openHistoryResult:nil];
}
- (void)showHistoryDay:(id)sender { [self showHistorySearch:nil]; self.historyDateCheckbox.state=NSOnState; self.historySearchField.stringValue=@""; if (self.selectedPeer.length) [self.historyScopePopup selectItemAtIndex:1]; [self searchHistory:nil]; }
- (void)showBookmarks:(id)sender { [self showHistorySearch:nil]; self.historyDateCheckbox.state=NSOffState; self.historyBookmarkCheckbox.state=NSOnState; self.historySearchField.stringValue=@""; [self.historyScopePopup selectItemAtIndex:0]; [self searchHistory:nil]; }
- (void)showHistorySearch:(id)sender {
    if (!self.history) return;
    [self createHistoryWindow];
    NSString *previousScopePeer=self.historyScopePopup.selectedItem.representedObject;
    while (self.historyScopePopup.numberOfItems>2) [self.historyScopePopup removeItemAtIndex:2];
    for (NSString *peer in [[self.history peers] sortedArrayUsingSelector:@selector(compare:)]) { [self.historyScopePopup addItemWithTitle:[NSString stringWithFormat:@"%@ · %@",JMName(self.contacts[peer] ?: @{@"aimId":peer}),peer]]; self.historyScopePopup.lastItem.representedObject=peer; self.historyScopePopup.lastItem.toolTip=self.historyScopePopup.lastItem.title; if ([previousScopePeer isEqual:peer]) [self.historyScopePopup selectItem:self.historyScopePopup.lastItem]; }
    [[self.historyScopePopup itemAtIndex:1] setEnabled:self.selectedPeer.length>0];
    if (!self.selectedPeer.length) [self.historyScopePopup selectItemAtIndex:0];
    [self.historyWindow makeKeyAndOrderFront:nil]; [self.historyWindow makeFirstResponder:self.historySearchField]; [self.historySearchField selectText:nil]; [self searchHistory:nil];
}
- (void)closeHistorySearch:(id)sender { [self.historyWindow orderOut:nil]; self.historySearchGeneration++; }
- (void)searchHistory:(id)sender {
    NSUInteger serial=++self.historySearchGeneration;
    NSString *query=[[self.historySearchField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (self.historyScopePopup.indexOfSelectedItem==1 && !self.selectedPeer.length) [self.historyScopePopup selectItemAtIndex:0];
    NSString *peer=self.historyScopePopup.indexOfSelectedItem==1 ? self.selectedPeer : (self.historyScopePopup.indexOfSelectedItem>1 ? self.historyScopePopup.selectedItem.representedObject : nil);
    BOOL dated=self.historyDateCheckbox.state==NSOnState, bookmarked=self.historyBookmarkCheckbox.state==NSOnState;
    self.historyFromDate.enabled=YES; self.historyUntilDate.enabled=dated;
    NSDate *from=dated ? [self startOfDay:self.historyFromDate.dateValue] : nil, *until=dated ? [self dayAfter:self.historyUntilDate.dateValue] : nil;
    self.historyResults=@[]; self.historyResultsQuery=query; [self.historyTable reloadData]; [self.historyOpenButton setEnabled:NO];
    if (!self.history || (!query.length && !dated && !bookmarked)) { JMSetLabel(self.historySearchStatus,JML(@"Введите слово, выберите период или закладки.")); return; }
    if (dated && [from compare:until]!=NSOrderedAscending) { JMSetLabel(self.historySearchStatus,JML(@"Начальная дата должна быть не позже конечной.")); return; }
    if (self.history.loadError) { JMSetLabel(self.historySearchStatus,JML(@"История недоступна: не удалось прочитать файл.")); return; }
    JMSetLabel(self.historySearchStatus,JML(@"Ищем в локальной истории…"));
    // A separate read connection searches a consistent SQLite snapshot off the UI thread.
    JMHistory *history=self.history;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.18*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if (serial!=self.historySearchGeneration || history!=self.history) return;
        dispatch_async(self.historySearchQueue,^{
            @autoreleasepool {
              NSArray *hits=[history searchQuery:query peer:peer from:from until:until bookmarked:bookmarked limit:201];
              dispatch_async(dispatch_get_main_queue(),^{
                if (serial!=self.historySearchGeneration || history!=self.history) return;
                BOOL limited=hits.count>200;
                self.historyResults=limited ? [hits subarrayWithRange:NSMakeRange(0,200)] : hits;
                [self.historyTable reloadData];
                JMSetLabel(self.historySearchStatus,limited ? JML(@"Первые 200 результатов. Уточните запрос.") : (hits.count ? [NSString stringWithFormat:JML(@"Найдено сообщений: %lu"),(unsigned long)hits.count] : JML(@"Совпадений нет. Попробуйте другую фразу.")));
                if (hits.count) [self.historyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                [self.historyOpenButton setEnabled:self.historyResults.count>0];
              });
            }
        });
    });
}
- (void)openHistoryResult:(id)sender {
    NSInteger row=self.historyTable.selectedRow;
    if (row<0 || row>=(NSInteger)self.historyResults.count) return;
    NSDictionary *message=self.historyResults[(NSUInteger)row]; NSString *peer=message[@"peer"];
    [self.sectionControl setSelectedSegment:1]; [self changeSection:nil]; [self selectPeer:peer];
    self.highlightedMessageID=message[@"id"]; self.historyHighlightQuery=self.historyResultsQuery;
    [self setTranscriptAroundID:message[@"id"]];
    [self renderTranscript];
    NSValue *value=self.transcriptRanges[self.highlightedMessageID];
    if (value) {
        NSRange body=value.rangeValue;
        NSRange match=self.historyHighlightQuery.length ? [self.transcript.string rangeOfString:self.historyHighlightQuery options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch range:body] : NSMakeRange(NSNotFound,0);
        NSRange target=match.location==NSNotFound ? body : match;
        [self.transcript setSelectedRange:target]; [self.transcript scrollRangeToVisible:target];
    }
    [self closeHistorySearch:nil]; [self.chatWindow makeKeyAndOrderFront:nil]; [self.chatWindow makeFirstResponder:self.transcript];
}
- (BOOL)openExternalURL:(NSURL *)url { return [[NSWorkspace sharedWorkspace] openURL:url]; }
- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex {
    if (textView!=self.transcript) return NO;
    NSURL *url=JMExternalURL(link); if (url) [self openExternalURL:url];
    return YES;
}
- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)index {
    if (view!=self.transcript || index>=view.textStorage.length || !self.history) return menu;
    if (event && (event.type==NSRightMouseDown || event.type==NSLeftMouseDown || event.type==NSOtherMouseDown)) {
        NSPoint point=[view convertPoint:event.locationInWindow fromView:nil];
        NSUInteger glyph=[view.layoutManager glyphIndexForCharacterAtIndex:index];
        NSRect line=[view.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyph effectiveRange:NULL];
        line.origin.x+=view.textContainerOrigin.x; line.origin.y+=view.textContainerOrigin.y;
        if (!NSPointInRect(point,NSInsetRect(line,-3,-2))) return menu;
    }
    NSString *identifier=[view.textStorage attribute:@"JMMessageID" atIndex:index effectiveRange:NULL];
    if (!identifier.length) return menu;
    NSMenu *result=[menu copy] ?: [[NSMenu alloc] initWithTitle:JML(@"Сообщение")];
    NSDictionary *context=@{@"account":self.accountUIN ?: @"",@"peer":self.selectedPeer ?: @"",@"id":identifier,@"generation":@(self.conversationGeneration)};
    [result insertItem:[NSMenuItem separatorItem] atIndex:0];
    NSMenuItem *copy=[[NSMenuItem alloc] initWithTitle:JML(@"Копировать сообщение целиком") action:@selector(copyWholeMessage:) keyEquivalent:@""]; copy.target=self; copy.representedObject=context;
    [result insertItem:copy atIndex:0];
    NSMenuItem *quote=[[NSMenuItem alloc] initWithTitle:JML(@"Ответить цитатой") action:@selector(quoteMessage:) keyEquivalent:@""]; quote.target=self; quote.representedObject=context;
    [result insertItem:quote atIndex:0];
    NSDictionary *message=[self.history messageWithID:identifier peer:self.selectedPeer];
    NSMenuItem *bookmark=[[NSMenuItem alloc] initWithTitle:[self.history isBookmarkedID:identifier peer:self.selectedPeer] ? JML(@"Удалить закладку") : JML(@"Добавить закладку") action:@selector(toggleMessageBookmark:) keyEquivalent:@""]; bookmark.target=self; bookmark.representedObject=context; [result insertItem:bookmark atIndex:0];
    if ([@[@"failed",@"unknown"] containsObject:JMString(message[@"delivery"])]) {
        NSMenuItem *retry=[[NSMenuItem alloc] initWithTitle:JML(@"Повторить отправку…") action:@selector(retryMessage:) keyEquivalent:@""]; retry.target=self; retry.representedObject=context; [result insertItem:retry atIndex:0];
    }
    return result;
}
- (NSDictionary *)messageForAction:(NSMenuItem *)item {
    NSDictionary *context=JMDictionary(item.representedObject);
    if (!self.history || [context[@"generation"] unsignedIntegerValue]!=self.conversationGeneration || ![JMString(context[@"account"]) isEqualToString:self.accountUIN ?: @""] || ![JMString(context[@"peer"]) isEqualToString:self.selectedPeer]) return nil;
    return [self.history messageWithID:JMString(context[@"id"]) peer:self.selectedPeer];
}
- (void)writeMessageToPasteboard:(NSString *)text {
    NSPasteboard *board=[NSPasteboard generalPasteboard]; [board clearContents]; [board setString:text forType:NSPasteboardTypeString];
}
- (void)toggleMessageBookmark:(NSMenuItem *)sender {
    NSDictionary *message=[self messageForAction:sender]; if (!message) return;
    NSError *error=nil; BOOL value=![self.history isBookmarkedID:message[@"id"] peer:message[@"peer"]];
    if (![self.history setBookmarked:value identifier:message[@"id"] peer:message[@"peer"] error:&error]) [self showError:JML(@"Не удалось сохранить закладку") detail:error.localizedDescription];
    else { [self renderTranscript]; if (self.historyWindow.isVisible) [self searchHistory:nil]; }
}
- (void)copyWholeMessage:(NSMenuItem *)sender { NSDictionary *message=[self messageForAction:sender]; if (message) [self writeMessageToPasteboard:JMString(message[@"text"])]; }
- (void)quoteMessage:(NSMenuItem *)sender {
    NSDictionary *message=[self messageForAction:sender]; if (!message || !self.composer.isEditable) return;
    NSString *name=[message[@"outgoing"] boolValue] ? (JMString(self.ownInfo[@"friendly"]).length ? JMString(self.ownInfo[@"friendly"]) : self.accountUIN ?: JML(@"Я")) : JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer});
    [self.chatWindow makeKeyAndOrderFront:nil]; [self.chatWindow makeFirstResponder:self.composer];
    [self.composer insertText:JMQuotedMessage(message,name) replacementRange:NSMakeRange(0,0)];
    [self.composer setSelectedRange:NSMakeRange(self.composer.string.length,0)]; [self.composer scrollRangeToVisible:self.composer.selectedRange];
}
- (JMDraftStore *)makeDraftStoreForUIN:(NSString *)uin { return [[JMDraftStore alloc] initWithUIN:uin root:nil]; }
- (void)restoreDraftsForUIN:(NSString *)uin {
    self.draftStore=[self makeDraftStoreForUIN:uin]; self.draftSaveSerial++;
    self.drafts=[self.draftStore.drafts mutableCopy] ?: [NSMutableDictionary dictionary];
    self.draftSaveError=self.draftStore.loadError; self.draftsPending=NO;
    [self.conversationPeers addObjectsFromArray:self.drafts.allKeys];
}
- (void)rememberDraftForPeer:(NSString *)peer text:(NSString *)text {
    if (!JMValidUIN(peer)) return;
    if (text.length) self.drafts[peer]=[text copy]; else [self.drafts removeObjectForKey:peer];
    if (!self.draftStore) return;
    self.draftSaveSerial++;
    self.draftsPending=YES; [self.draftSaveTimer invalidate];
    self.draftSaveTimer=[NSTimer scheduledTimerWithTimeInterval:0.6 target:self selector:@selector(draftSaveTimerFired:) userInfo:nil repeats:NO];
}
- (void)draftSaveTimerFired:(NSTimer *)timer { [self persistDraftsNow]; }
- (NSDictionary *)draftSnapshot {
    NSMutableDictionary *snapshot=[self.drafts mutableCopy];
    // Preserve the unacknowledged text on disk even if the user has already
    // replaced the editor contents, then quits or loses the process.
    if (self.sending && self.sendingClearsDraft && self.sendingPeer.length && self.sendingText.length) {
        NSString *current=JMString(snapshot[self.sendingPeer]);
        if (![current hasPrefix:self.sendingText]) snapshot[self.sendingPeer]=current.length ? [NSString stringWithFormat:@"%@\n\n%@",self.sendingText,current] : self.sendingText;
    }
    return [snapshot copy];
}
- (void)persistDraftsNow {
    [self.draftSaveTimer invalidate]; self.draftSaveTimer=nil;
    JMDraftStore *store=self.draftStore; if (!store) return;
    NSDictionary *snapshot=[self draftSnapshot]; NSUInteger serial=++self.draftSaveSerial;
    __weak JMAppDelegate *weakSelf=self;
    dispatch_async(self.draftSaveQueue,^{
        NSError *error=nil; [store saveDrafts:snapshot error:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            JMAppDelegate *self=weakSelf; if (!self || self.draftStore!=store || self.draftSaveSerial!=serial) return;
            self.draftSaveError=error; self.draftsPending=NO; [self updateSendButton]; [self reloadContacts];
        });
    });
}
- (void)flushDrafts {
    [self.draftSaveTimer invalidate]; self.draftSaveTimer=nil;
    JMDraftStore *store=self.draftStore; if (!store) return;
    if (self.selectedPeer) { NSString *text=self.composer.string; if (text.length) self.drafts[self.selectedPeer]=[text copy]; else [self.drafts removeObjectForKey:self.selectedPeer]; }
    NSDictionary *snapshot=[self draftSnapshot]; self.draftSaveSerial++;
    __block NSError *error=nil;
    dispatch_sync(self.draftSaveQueue,^{ [store saveDrafts:snapshot error:&error]; });
    self.draftSaveError=error; self.draftsPending=NO;
    [self updateSendButton];
}
- (BOOL)canLeaveDrafts {
    if (!self.draftSaveError || !self.drafts.count) return YES;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Не удалось сохранить черновики");
    alert.informativeText=[NSString stringWithFormat:JML(@"%@\n\nЧерновики пока находятся в памяти. Вернитесь и скопируйте нужный текст перед выходом."),self.draftSaveError.localizedDescription];
    [[alert addButtonWithTitle:JML(@"Вернуться")] setKeyEquivalent:@"\e"]; [alert addButtonWithTitle:JML(@"Продолжить без сохранения")];
    return [alert runModal]==NSAlertSecondButtonReturn;
}
- (void)updateSoundControls {
    [self.soundButton setTitle:self.audioAlerts.enabled ? JML(@"Звуки: вкл.") : JML(@"Звуки: выкл.")];
    [self.soundButton setToolTip:JML(@"Включить или отключить все звуки. Отдельные события и прослушивание — в меню «Звуки».")];
    [self syncAlertControls];
}
- (void)toggleSounds:(id)sender {
    self.audioAlerts.enabled=!self.audioAlerts.enabled;
    if (!self.audioAlerts.enabled) [self.audioAlerts stop]; [self updateSoundControls];
}
- (void)toggleSoundOption:(NSMenuItem *)sender {
    NSString *key=sender.representedObject;
    if ([key isEqualToString:@"enabled"]) { [self toggleSounds:sender]; return; }
    if ([key isEqualToString:@"presenceEnabled"]) {
        self.audioAlerts.presenceEnabled=!self.audioAlerts.presenceEnabled;
    } else if ([key isEqualToString:@"typingEnabled"]) {
        self.audioAlerts.typingEnabled=!self.audioAlerts.typingEnabled;
    }
    [self syncAlertControls];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (self.dataOperationInProgress && item.target==self && item.action!=@selector(copyWholeMessage:)) return NO;
    if (item.action==@selector(send:)) return self.chatWindow.isKeyWindow && self.chatWindow.firstResponder==self.composer && !self.composer.hasMarkedText && self.sendButton.isEnabled;
    if (item.action==@selector(copyWholeMessage:) || item.action==@selector(quoteMessage:)) return [self messageForAction:item]!=nil && (item.action!=@selector(quoteMessage:) || self.composer.isEditable);
    if (item.action==@selector(openConversation:) || item.action==@selector(focusContactSearch:) || item.action==@selector(showContactsSection:) || item.action==@selector(showConversationsSection:)) return self.history!=nil;
    if (item.action==@selector(showOwnProfile:)) return self.accountUIN.length>0 && !self.offlineMode;
    if (item.action==@selector(renameContact:) || item.action==@selector(removeContact:) || item.action==@selector(moveContact:)) return [self canChangeRoster] && [self.serverContactIDs containsObject:[self contactForAction:item]];
    if (item.action==@selector(writeContact:) || item.action==@selector(profileContact:)) return JMValidUIN([self contactForAction:item]);
    if (item.action==@selector(addContact:)) return [self canChangeRoster];
    if (item.action==@selector(toggleUnreadFilter:)) { item.state=(self.unreadOnly && self.sectionControl.selectedSegment==1) ? NSOnState : NSOffState; return self.history!=nil; }
    if (item.action==@selector(toggleSelectedGroup:)) return self.sectionControl.selectedSegment==0 && self.contactTable.selectedRow>=0 && !self.searchField.stringValue.length;
    if (item.action==@selector(toggleContactBlock:)) {
        NSString *peer=[self contactForAction:item];
        return self.client.connected && !self.changingPrivacy && JMValidUIN(peer) && ![peer isEqual:self.accountUIN];
    }
    if (item.action==@selector(showBlockedContacts:)) return self.client.connected && !self.changingPrivacy;
    if (item.action==@selector(restoreRecentMessages:)) return self.client.connected && self.history && !self.restoringMessages && JMValidUIN(self.selectedPeer);
    if (item.action==@selector(showStorage:) || item.action==@selector(showHistoryDay:) || item.action==@selector(showBookmarks:)) return self.history && !self.dataOperationInProgress;
    if (item.action==@selector(showGroups:)) return self.history!=nil;
    if (item.action==@selector(filterHistoricalGroup:)) return self.history!=nil;
    if (item.action==@selector(toggleSoundOption:)) {
        [item setState:[[self.audioAlerts valueForKey:item.representedObject] boolValue] ? NSOnState : NSOffState];
        return [item.representedObject isEqualToString:@"enabled"] || self.audioAlerts.enabled;
    }
    if (item.action==@selector(logout:)) return self.accountUIN.length>0 && !self.dataOperationInProgress;
    if (item.action==@selector(createBackup:)) return self.history && !self.dataOperationInProgress && !self.sending;
    if (item.action==@selector(restoreBackup:) || item.action==@selector(openOfflineHistory:)) return !self.dataOperationInProgress && !self.sending;
    if (item.action==@selector(toggleMuteConversation:)) { NSString *peer=[self contactForAction:item]; BOOL muted=[self.mutedPeers containsObject:peer]; item.title=muted ? JML(@"Включить уведомления") : JML(@"Отключить уведомления"); item.state=muted ? NSOnState : NSOffState; return self.history && JMValidUIN(peer); }
    if (item.action==@selector(changeLanguage:)) { item.state=[item.representedObject isEqual:[self.loginDefaults stringForKey:@"InterfaceLanguage"] ?: @"ru"] ? NSOnState : NSOffState; return !self.dataOperationInProgress; }
    if (item.action==@selector(changeAppearance:)) { item.state=[item.representedObject isEqual:JMThemeIdentifier()] ? NSOnState : NSOffState; return !self.dataOperationInProgress; }
    if (item.action==@selector(toggleAutomaticUpdates:)) { item.state=[self automaticUpdatesEnabled] ? NSOnState : NSOffState; return YES; }
    if (item.action==@selector(checkForUpdates:)) return !self.terminating;
    if (item.action==@selector(exportConversation:)) return !self.exportingHistory && self.selectedPeer.length && [self.history countForPeer:self.selectedPeer]>0;
    if (item.action==@selector(retryMessage:)) { NSDictionary *message=[self messageForAction:item]; return self.client.connected && !self.sending && self.sendNotBefore.timeIntervalSinceNow<=0 && [@[@"failed",@"unknown"] containsObject:JMString(message[@"delivery"])]; }
    if (item.action==@selector(toggleFavorite:)) { NSString *peer=[self contactForAction:item]; BOOL favorite=[self.favoritePeers containsObject:peer]; item.title=favorite ? JML(@"Убрать из избранного") : JML(@"Добавить в избранное"); item.state=favorite ? NSOnState : NSOffState; return self.history && JMValidUIN(peer); }
    if (item.action==@selector(toggleOnlineFilter:)) { item.state=self.onlineOnlyCheckbox.state; return self.history!=nil; }
    if (item.action==@selector(toggleFavoritesFilter:)) { item.state=self.favoritesOnlyCheckbox.state; return self.history!=nil; }
    if (item.action==@selector(toggleEmoticons:)) { item.state=self.chatPreferences.emoticonsEnabled ? NSOnState : NSOffState; return YES; }
    if (item.action==@selector(showHistorySearch:)) return self.history!=nil;
    if (item.action==@selector(markAllRead:)) return self.unread.count>0;
    return YES;
}
- (void)previewSound:(NSMenuItem *)sender { [self.audioAlerts previewEvent:sender.representedObject]; }
- (void)openSite:(id)sender { [self openExternalURL:[NSURL URLWithString:@"https://jimm.online/"]]; }
- (void)showError:(NSString *)title detail:(NSString *)detail {
    NSAlert *alert = [[NSAlert alloc] init]; [alert setMessageText:title]; [alert setInformativeText:detail ?: @""]; [alert runModal];
}
- (void)beginLoginControls {
    self.loginPending=YES; self.loginButton.enabled=NO; self.uinField.enabled=NO; self.passwordField.enabled=NO;
    self.rememberLoginCheckbox.enabled=NO; self.cancelLoginButton.hidden=NO; self.cancelLoginButton.enabled=YES;
}
- (BOOL)prepareLoginUIForUIN:(NSString *)uin {
    self.loginAttemptSerial++; self.unreadOnly=NO; self.changingPrivacy=NO; self.restoringMessages=NO; self.restoreAfterReconnect=NO;
    [self.historyWindow orderOut:nil]; self.historySearchGeneration++; self.historyResults=@[]; [self.historyTable reloadData]; [self.historySearchField setStringValue:@""];
    self.offlineMode=NO; self.onlineOnlyCheckbox.enabled=YES;
    if ([self.presencePopup.lastItem.representedObject isEqual:@"offline-local"]) [self.presencePopup removeItemAtIndex:self.presencePopup.numberOfItems-1];
    self.history = [self makeHistoryForUIN:uin]; self.showedHistoryError = NO;
    self.changingRoster=NO; self.selectedGroup=nil; [self.serverGroups removeAllObjects]; [self.groupsWindow orderOut:nil]; [self refreshGroupChoices];
    if (self.history.loadError) { [self showError:JML(@"История недоступна") detail:[self.history.loadError localizedDescription]]; return NO; }
    [self flushDrafts]; self.draftStore=nil; self.conversationGeneration++;
    [self.contacts removeAllObjects]; [self.drafts removeAllObjects]; [self.unread removeAllObjects]; self.selectedPeer = nil; self.sending = NO;
    [self.unread addEntriesFromDictionary:self.history.unreadCounts];
    self.accountUIN = uin; [self.mutedPeers removeAllObjects]; [self.mutedPeers addObjectsFromArray:JMArray([self.loginDefaults objectForKey:[@"MutedPeers." stringByAppendingString:uin]])]; [self.favoritePeers removeAllObjects];
    for (id value in JMArray([self.loginDefaults objectForKey:[@"FavoritePeers." stringByAppendingString:uin]])) if (JMValidUIN(JMString(value))) [self.favoritePeers addObject:value];
    self.onlineOnlyCheckbox.state=[self.loginDefaults boolForKey:[@"OnlineOnly." stringByAppendingString:uin]] ? NSOnState : NSOffState;
    self.favoritesOnlyCheckbox.state=[self.loginDefaults boolForKey:[@"FavoritesOnly." stringByAppendingString:uin]] ? NSOnState : NSOffState;
    [self updateDockBadge];
    [self.serverContactIDs removeAllObjects]; [self.conversationPeers removeAllObjects]; self.addingContact = NO; self.sendNotBefore = nil;
    [self restoreDraftsForUIN:uin];
    [self.avatars invalidate]; self.avatars=[self makeAvatarStore]; self.avatars.delegate=self;
    [self.ownInfo removeAllObjects]; [self.profileDates removeAllObjects]; [self.profileTexts removeAllObjects]; [self.incomingTyping removeAllObjects]; self.changingPresence=NO; self.presenceRequestSerial++; self.autoAway=[[JMAutoAway alloc] init];
    JMSetLabel(self.presenceFeedback,@""); self.connectedSince=nil; self.wasConnected=NO;
    for (id peer in JMArray([self.loginDefaults objectForKey:[@"ConversationPeers." stringByAppendingString:uin]]))
        if (JMValidUIN(JMString(peer))) [self.conversationPeers addObject:JMString(peer)];
    [self.conversationPeers addObjectsFromArray:[self.history peers]];
    [self.contactNotice setStringValue:@""];
    [self.composer setString:@""]; [self.composer.undoManager removeAllActions]; [self.transcript setString:@""];
    for (NSString *peer in self.conversationPeers) self.contacts[peer] = [@{@"aimId":peer, @"friendly":peer, @"state":@"offline"} mutableCopy];
    [self.loginDefaults setObject:uin forKey:@"LastUIN"];
    [self.loginButton setEnabled:NO]; [self.uinField setEnabled:NO]; [self.passwordField setEnabled:NO];
    [self.passwordField setStringValue:@""];
    [self beginLoginControls]; [self reloadContacts]; return YES;
}
- (void)login:(id)sender {
    if (!self.loginButton.isEnabled || self.loginPending) return;
    NSString *uin=[self.uinField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password=[self.passwordField.stringValue copy];
    if (!JMValidUIN(uin) || !password.length) { self.loginStatus.stringValue=JML(@"Укажите числовой UIN и пароль."); return; }
    BOOL remember=self.rememberLoginCheckbox.state==NSOnState;
    if (![self prepareLoginUIForUIN:uin]) return;
    self.pendingRememberLogin=remember; self.resumingLogin=NO;
    if (!remember) [self forgetSavedLoginForUIN:[self.loginDefaults stringForKey:@"RememberedAccountUIN"]];
    [self.client loginWithUIN:uin password:password longTerm:remember];
}
- (void)startAutomaticLogin {
    NSString *uin=[self.loginDefaults stringForKey:@"RememberedAccountUIN"];
    if (!JMValidUIN(uin) || self.loginPending || self.client.connected || self.terminating) return;
    if (self.pendingNotificationAccount.length && ![self.pendingNotificationAccount isEqualToString:uin]) return;
    self.uinField.stringValue=uin; self.rememberLoginCheckbox.state=NSOnState;
    [self beginLoginControls]; self.resumingLogin=YES;
    self.loginStatus.stringValue=JML(@"Открываем сохранённый вход…");
    NSUInteger serial=++self.loginAttemptSerial; JMLoginStore *store=self.loginStore;
    __weak JMAppDelegate *weakSelf=self;
    dispatch_async(self.loginStoreQueue,^{
        NSError *error=nil; NSDictionary *record=[store loginForUIN:uin error:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            JMAppDelegate *self=weakSelf; if (!self || self.terminating || self.loginAttemptSerial!=serial) return;
            if (!record) {
                if (!error || ([error.domain isEqualToString:JMLoginStoreErrorDomain] && (error.code==-1 || error.code==-2))) [self forgetSavedLoginForUIN:uin];
                self.resumingLogin=NO; [self resetLogin:error.localizedDescription ?: JML(@"Сохранённый вход не найден. Введите пароль.")]; return;
            }
            if (![self prepareLoginUIForUIN:uin]) { self.resumingLogin=NO; [self resetLogin:JML(@"Не удалось открыть локальные данные аккаунта.")]; return; }
            self.pendingRememberLogin=YES; self.resumingLogin=YES;
            [self.client resumeWithUIN:uin token:JMString(record[@"token"])];
        });
    });
}
- (void)forgetSavedLoginForUIN:(NSString *)uin {
    if (!JMValidUIN(uin)) return;
    if ([[self.loginDefaults stringForKey:@"RememberedAccountUIN"] isEqualToString:uin]) { [self.loginDefaults removeObjectForKey:@"RememberedAccountUIN"]; [self.loginDefaults synchronize]; }
    JMLoginStore *store=self.loginStore; __weak JMAppDelegate *weakSelf=self;
    dispatch_async(self.loginStoreQueue,^{
        NSError *error=nil; [store removeLoginForUIN:uin error:&error];
        if (error) dispatch_async(dispatch_get_main_queue(),^{
            JMAppDelegate *self=weakSelf; if (self && !self.terminating) [self showError:JML(@"Автовход отключён") detail:JML(@"Не удалось удалить запись JimmMac из Связки ключей. Автоматический вход отключён. Запись можно удалить в системной программе «Связка ключей».")];
        });
    });
}
- (void)rememberLoginChanged:(id)sender {
    if (self.rememberLoginCheckbox.state==NSOffState) [self forgetSavedLoginForUIN:[self.loginDefaults stringForKey:@"RememberedAccountUIN"]];
}
- (void)cancelLogin:(id)sender {
    [self logoutForgettingSavedLogin:NO]; self.loginStatus.stringValue=JML(@"Подключение отменено. Можно войти вручную.");
}
- (void)client:(JMAPIClient *)client authenticatedWithToken:(NSString *)token expiresAt:(NSDate *)expiration {
    if (!self.pendingRememberLogin || ![self.accountUIN isEqualToString:client.uin]) return;
    NSString *uin=[self.accountUIN copy], *previous=[self.loginDefaults stringForKey:@"RememberedAccountUIN"];
    if (JMValidUIN(previous) && ![previous isEqualToString:uin]) [self forgetSavedLoginForUIN:previous];
    JMLoginStore *store=self.loginStore; NSUInteger serial=self.loginAttemptSerial;
    __weak JMAppDelegate *weakSelf=self;
    dispatch_async(self.loginStoreQueue,^{
        NSError *error=nil; BOOL saved=[store saveToken:token expiresAt:expiration forUIN:uin error:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            JMAppDelegate *self=weakSelf; if (!self || self.loginAttemptSerial!=serial) return;
            if (!saved) {
                NSString *detail=error.localizedDescription ?: JML(@"Сервер не сообщил срок действия токена. Вход придётся повторить при следующем запуске.");
                if (self.terminating) self.quitCredentialError=detail; else [self showError:JML(@"Вход не сохранён") detail:detail]; return;
            }
            [self.loginDefaults setObject:uin forKey:@"RememberedAccountUIN"]; [self.loginDefaults synchronize];
            if (!self.terminating) JMSetLabel(self.statusLabel,JML(@"Подключено · Вход сохранён в Связке ключей"));
        });
    });
}
- (void)logout:(id)sender { [self logoutForgettingSavedLogin:YES]; }
- (void)logoutForgettingSavedLogin:(BOOL)forget {
    if (self.dataOperationInProgress) return; self.presenceRequestSerial++; self.automaticPresenceRequest=NO; self.autoAway=[[JMAutoAway alloc] init]; [self.storageWindow orderOut:nil];
    [self flushDrafts]; if (![self canLeaveDrafts]) return;
    self.loginAttemptSerial++; self.resumingLogin=NO; self.pendingRememberLogin=NO;
    if (forget) [self forgetSavedLoginForUIN:self.accountUIN ?: [self.loginDefaults stringForKey:@"RememberedAccountUIN"]];
    self.draftStore=nil; self.draftSaveSerial++; self.conversationGeneration++; self.draftSaveError=nil; self.draftsPending=NO;
    self.sendingPeer=nil; self.sendingText=nil;
    [self.ownProfileController invalidate]; self.ownProfileController=nil;
    self.notificationAlerts.accountUIN=nil; [self.notificationAlerts clear]; self.pendingNotificationAccount=nil; self.pendingNotificationPeer=nil;
    [self.groupsWindow orderOut:nil]; self.changingRoster=NO; self.selectedGroup=nil; [self.serverGroups removeAllObjects]; [self refreshGroupChoices];
    [self.historyWindow orderOut:nil]; self.historySearchGeneration++; self.historyResults=@[]; [self.historyTable reloadData];
    [self.historySearchField setStringValue:@""]; self.highlightedMessageID=nil; self.historyHighlightQuery=nil;
    [self stopOutgoingTyping]; [self.incomingTypingTimer invalidate]; [self.incomingTyping removeAllObjects];
    [self.avatars invalidate]; self.avatars=nil; [self.profileWindow orderOut:nil]; self.profilePeer=nil; [self.ownInfo removeAllObjects];
    [self.client disconnect]; self.sending = NO; self.sendNotBefore = nil;
    self.accountUIN = nil; self.addingContact = NO; [self.serverContactIDs removeAllObjects]; [self.conversationPeers removeAllObjects];
    self.history = nil; self.offlineMode=NO; self.selectedPeer = nil; [self.mutedPeers removeAllObjects]; [self.favoritePeers removeAllObjects]; self.onlineOnlyCheckbox.state=NSOffState; self.favoritesOnlyCheckbox.state=NSOffState; self.sendingLocalID=nil;
    [self.contacts removeAllObjects]; [self.drafts removeAllObjects]; [self.unread removeAllObjects];
    [self.composer setString:@""]; [self.composer.undoManager removeAllActions]; [self.transcript setString:@""]; [self reloadContacts];
    [self updateDockBadge]; [self.audioAlerts stop];
    [self.chatWindow orderOut:nil]; [self.rosterWindow orderOut:nil]; [self resetLogin:JML(@"Вы вышли из аккаунта.")];
}
- (void)resetLogin:(NSString *)status {
    self.loginPending=NO; self.cancelLoginButton.hidden=YES; self.rememberLoginCheckbox.enabled=YES;
    [self.loginButton setEnabled:YES]; [self.uinField setEnabled:YES]; [self.passwordField setEnabled:YES];
    [self.loginStatus setStringValue:status]; [self.loginWindow makeKeyAndOrderFront:nil];
    [self.loginWindow makeFirstResponder:self.passwordField];
}
- (void)client:(JMAPIClient *)client changedStatus:(NSString *)status connected:(BOOL)connected {
    [self.ownProfileController connectionChanged];
    if (connected) { self.loginPending=NO; self.resumingLogin=NO; self.cancelLoginButton.hidden=YES; self.rememberLoginCheckbox.enabled=YES; self.notificationAlerts.accountUIN=self.accountUIN ?: client.uin; }
    if (connected && !self.wasConnected) self.connectedSince=[NSDate date];
    if (!connected) { self.connectedSince=nil; JMSetLabel(self.presenceFeedback,@""); }
    if (!connected && self.wasConnected) self.restoreAfterReconnect=YES;
    BOOL restore=connected && self.restoreAfterReconnect;
    self.wasConnected=connected;
    JMSetLabel(self.statusLabel,status); JMSetLabel(self.loginStatus,status); if (self.diagnosticsWindow.isVisible) [self refreshDiagnostics:nil];
    [self updateAccountLabel];
    if (connected && [self.loginWindow isVisible]) { [self.loginWindow orderOut:nil]; [self showSessionWindows]; }
    [self updateSendButton]; [self updateTypingIndicator];
    if (restore) { self.restoreAfterReconnect=NO; [self restoreRecentMessages:nil]; }
    if (connected) { [self openPendingNotification]; [self presentPendingUpdateIfPossible]; }
}
- (void)updateAccountLabel {
    NSString *uin=JMValidUIN(self.accountUIN) ? self.accountUIN : self.client.uin;
    NSString *name=JMString(self.ownInfo[@"friendly"]);
    NSString *identity=JMValidUIN(uin) ? (name.length ? [NSString stringWithFormat:@"%@ · UIN %@",name,uin] : [@"UIN " stringByAppendingString:uin]) : (name.length ? name : JML(@"Учётная запись"));
    JMSetLabel(self.accountLabel,JMTheme()==JMThemeCurrent ? identity : (name.length ? name : [@"UIN " stringByAppendingString:uin ?: @""])); self.accountLabel.toolTip=identity;
}
- (void)client:(JMAPIClient *)client failedLogin:(NSError *)error {
    BOOL savedAccount=[[self.loginDefaults stringForKey:@"RememberedAccountUIN"] isEqualToString:self.accountUIN];
    if ((self.resumingLogin || (!self.loginPending && savedAccount)) && [error.domain isEqualToString:JMAPIErrorDomain] && (error.code==401 || error.code==330)) [self forgetSavedLoginForUIN:self.accountUIN];
    self.resumingLogin=NO; self.pendingRememberLogin=NO;
    [self.ownProfileController invalidate]; self.ownProfileController=nil;
    self.notificationAlerts.accountUIN=nil;
    [self stopOutgoingTyping]; [self.profileWindow orderOut:nil];
    [self.chatWindow orderOut:nil]; [self.rosterWindow orderOut:nil]; [self resetLogin:[error localizedDescription]];
}
- (void)client:(JMAPIClient *)client receivedBuddyList:(NSDictionary *)buddyList {
    NSMutableDictionary *newContacts = [NSMutableDictionary dictionary];
    [self.serverContactIDs removeAllObjects];
    [self.serverGroups removeAllObjects];
    for (id value in JMArray(buddyList[@"groups"])) { NSString *name=JMString(JMDictionary(value)[@"name"]); if (name.length && ![self.serverGroups containsObject:name]) [self.serverGroups addObject:name]; }
    for (NSDictionary *buddy in JMContactsFromBuddyList(buddyList)) {
        newContacts[buddy[@"aimId"]] = [buddy mutableCopy]; [self.serverContactIDs addObject:buddy[@"aimId"]];
        if (JMString(buddy[@"friendly"]).length) newContacts[buddy[@"aimId"]][@"_rosterFriendly"]=buddy[@"friendly"];
    }
    // Profiles of old conversations remain cached, without becoming server contacts.
    for (NSString *peer in self.conversationPeers) if (!newContacts[peer]) newContacts[peer] = [@{@"aimId":peer, @"friendly":JMName(self.contacts[peer] ?: @{@"aimId":peer}), @"state":@"offline"} mutableCopy];
    if (self.selectedPeer && !newContacts[self.selectedPeer]) newContacts[self.selectedPeer] = self.contacts[self.selectedPeer];
    self.contacts = newContacts; [self refreshGroupChoices]; [self reloadContacts]; [self updatePeerLabel]; [self updateProfileCard]; [self persistRosterCache];
}
- (void)client:(JMAPIClient *)client receivedPresence:(NSDictionary *)presence {
    NSString *peer = JMString(presence[@"aimId"]);
    NSMutableDictionary *contact = self.contacts[peer]; if (!contact) return;
    NSString *oldState=JMString(contact[@"state"]);
    BOOL changedAvatar=presence[@"buddyIcon"] && ![presence[@"buddyIcon"] isEqual:contact[@"buddyIcon"]];
    for (NSString *key in presence) {
        if ([key isEqualToString:@"state"] && ![JMString(presence[key]) length]) continue;
        if (presence[key] != [NSNull null]) contact[key] = presence[key];
    }
    [self reloadContacts]; [self updatePeerLabel];
    NSString *newState=JMString(contact[@"state"]);
    if (oldState.length && newState.length && ![oldState isEqualToString:newState] && [self.serverContactIDs containsObject:peer] && client.connected && ![self.mutedPeers containsObject:peer] && self.connectedSince && -[self.connectedSince timeIntervalSinceNow]>3) {
        BOOL wasOnline=![oldState isEqualToString:@"offline"], isOnline=![newState isEqualToString:@"offline"];
        if (wasOnline!=isOnline) [self.audioAlerts playEvent:isOnline ? @"online" : @"offline"];
    }
    if (changedAvatar) [self.avatars refreshUIN:peer];
}
- (BOOL)client:(JMAPIClient *)client receivedMessage:(NSDictionary *)message {
    BOOL inserted=NO;
    if (![self saveIncomingMessage:message quiet:NO inserted:&inserted]) return NO;
    if (!inserted) return YES;
    [self persistConversationPeers];
    if ([message[@"peer"] isEqual:self.selectedPeer]) [self renderTranscript];
    [self reloadContacts]; [self updateDockBadge]; return YES;
}
- (BOOL)saveIncomingMessage:(NSDictionary *)message quiet:(BOOL)quiet inserted:(BOOL *)inserted {
    if (!self.history) return NO;
    NSString *peer=message[@"peer"];
    BOOL reading=[peer isEqual:self.selectedPeer] && [self isReadingConversation];
    NSError *error=nil;
    if (![self.history appendMessage:message unread:!reading inserted:inserted error:&error]) {
        if (!self.showedHistoryError) { self.showedHistoryError=YES; [self showError:JML(@"Не удалось сохранить историю") detail:error.localizedDescription]; }
        return NO;
    }
    if (!*inserted) return YES;
    if (!self.contacts[peer]) {
        NSString *name=JMString(message[@"name"]);
        self.contacts[peer]=[@{@"aimId":peer,@"friendly":name.length ? name : peer,@"state":@"offline"} mutableCopy];
    }
    [self.conversationPeers addObject:peer];
    BOOL incoming=![message[@"outgoing"] boolValue];
    if (incoming && !reading) self.unread[peer]=@([self.unread[peer] integerValue]+1);
    if (incoming && !quiet && ![self.mutedPeers containsObject:peer]) {
        if (!reading || self.audioAlerts.soundInOpenConversation) [self.audioAlerts playEvent:@"message"];
        if (!reading) [self.notificationAlerts queueMessageFrom:peer name:JMName(self.contacts[peer]) text:JMString(message[@"text"])];
        if (!reading && self.notificationAlerts.dockAttentionEnabled && ![NSApp isActive]) [NSApp requestUserAttention:NSInformationalRequest];
    }
    return YES;
}
- (BOOL)isReadingConversation {
    NSClipView *clip=self.transcript.enclosingScrollView.contentView;
    BOOL atBottom=NSMaxY(clip.bounds)>=NSHeight(self.transcript.bounds)-24;
    return !self.renderingTranscript && self.transcriptOffset+200>=[self.history countForPeer:self.selectedPeer ?: @""] && atBottom && [NSApp isActive] && self.chatWindow.isKeyWindow && self.chatWindow.isVisible && !self.chatWindow.isMiniaturized;
}
- (void)updateDockBadge {
    NSInteger total=0; for (NSNumber *count in [self.unread allValues]) total+=[count integerValue];
    [[NSApp dockTile] setBadgeLabel:total>0 ? [NSString stringWithFormat:@"%ld",(long)total] : nil];
    [self updateUnreadControls];
}
- (void)markSelectedRead {
    if (self.selectedPeer && self.unread[self.selectedPeer] && [self isReadingConversation]) {
        NSError *error=nil; if (![self.history markReadPeer:self.selectedPeer error:&error]) { JMSetLabel(self.statusLabel,error.localizedDescription); return; }
        [self.notificationAlerts clearPeer:self.selectedPeer];
        if (self.unread[self.selectedPeer]) { [self.unread removeObjectForKey:self.selectedPeer]; [self reloadContacts]; [self updateDockBadge]; }
    }
}
- (void)updateUnreadControls {
    NSInteger count=[self.unread[self.selectedPeer ?: @""] integerValue];
    self.latestMessagesButton.hidden=count==0 && self.transcriptOffset+200>=[self.history countForPeer:self.selectedPeer ?: @""];
    self.latestMessagesButton.title=count ? [NSString stringWithFormat:JML(@"Новые: %ld ↓"),(long)count] : JML(@"К последним ↓");
    [self layoutChatWindow];
}
- (void)jumpToLatest:(id)sender {
    self.transcript.selectedRange=NSMakeRange(0,0); self.transcriptTail=YES; [self renderTranscript]; [self.transcript scrollRangeToVisible:NSMakeRange(self.transcript.string.length,0)]; [self markSelectedRead]; [self updateUnreadControls];
}
- (void)markAllRead:(id)sender { NSError *error=nil; if (![self.history markReadPeer:nil error:&error]) { [self showError:JML(@"Не удалось сохранить прочтение") detail:error.localizedDescription]; return; } [self.unread removeAllObjects]; [self.notificationAlerts clear]; [self reloadContacts]; [self updateDockBadge]; }
- (BOOL)notificationAlerts:(JMNotificationAlerts *)alerts shouldNotifyPeer:(NSString *)peer {
    return self.history!=nil && ![self.mutedPeers containsObject:peer] && JMValidUIN(peer) && !([peer isEqualToString:self.selectedPeer] && [self isReadingConversation]);
}
- (void)notificationAlertsShowApplication:(JMNotificationAlerts *)alerts { [self showMainWindow:nil]; }
- (void)notificationAlerts:(JMNotificationAlerts *)alerts openPeer:(NSString *)peer account:(NSString *)account {
    NSString *active=self.notificationAlerts.accountUIN;
    if (active.length && ![active isEqualToString:account]) { [self showMainWindow:nil]; [self showError:JML(@"Уведомление другого аккаунта") detail:[NSString stringWithFormat:JML(@"Уведомление для UIN %@. Чтобы открыть переписку, выйдите из текущего аккаунта и войдите в этот UIN."),account]]; return; }
    self.pendingNotificationAccount=account; self.pendingNotificationPeer=peer;
    if (active.length && self.client.connected) [self openPendingNotification];
    else if (active.length) [self showMainWindow:nil];
    else {
        if (![self.uinField.stringValue isEqualToString:account]) self.passwordField.stringValue=@"";
        self.uinField.stringValue=account; [self.loginWindow makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    }
}
- (void)openPendingNotification {
    if (!self.pendingNotificationPeer.length || !self.client.connected) return;
    NSString *peer=self.pendingNotificationPeer, *account=self.pendingNotificationAccount;
    self.pendingNotificationPeer=nil; self.pendingNotificationAccount=nil;
    if (![self.notificationAlerts.accountUIN isEqualToString:account]) return;
    if (!self.contacts[peer]) self.contacts[peer]=[@{@"aimId":peer,@"friendly":peer,@"state":@"offline"} mutableCopy];
    [self.sectionControl setSelectedSegment:1]; [self changeSection:nil]; [self selectPeer:peer];
    [self showMainWindow:nil]; if (JMTheme()!=JMThemeCurrent) [self.chatWindow makeKeyAndOrderFront:nil]; [self jumpToLatest:nil];
    dispatch_async(dispatch_get_main_queue(),^{ [self markSelectedRead]; });
}
- (void)conversationDidScroll:(NSNotification *)notification { [self markSelectedRead]; }
- (void)windowDidBecomeKey:(NSNotification *)notification { if (notification.object==self.chatWindow || notification.object==self.rosterWindow) { [self markSelectedRead]; [self presentPendingUpdateIfPossible]; } }
- (void)applicationDidBecomeActive:(NSNotification *)notification { [self markSelectedRead]; [self presentPendingUpdateIfPossible]; }
- (void)reloadContacts {
    NSString *query = [self.searchField stringValue] ?: @"";
    NSString *selectionPeer=self.selectedPeer;
    if (JMTheme()!=JMThemeCurrent && self.contactTable.selectedRow>=0 && self.contactTable.selectedRow<(NSInteger)self.visibleContacts.count) selectionPeer=self.visibleContacts[(NSUInteger)self.contactTable.selectedRow][@"aimId"];
    NSMutableArray *contacts = [NSMutableArray array];
    BOOL conversations = [self.sectionControl selectedSegment] == 1;
    NSSet *ids = conversations ? self.conversationPeers : self.serverContactIDs;
    for (NSString *peer in ids) {
        if (conversations && self.unreadOnly && ![self.unread[peer] integerValue]) continue;
        NSDictionary *contact = self.contacts[peer] ?: @{@"aimId":peer, @"friendly":peer, @"state":@"offline"};
        if (self.onlineOnlyCheckbox.state==NSOnState && ![@[@"online",@"freeForChat",@"away",@"na",@"dnd",@"occupied"] containsObject:JMString(contact[@"state"])]) continue;
        if (self.favoritesOnlyCheckbox.state==NSOnState && ![self.favoritePeers containsObject:peer]) continue;
        if (!conversations && self.selectedGroup.length && ![JMArray(contact[@"groups"]) containsObject:self.selectedGroup]) continue;
        if (![query length] || [JMName(contact) rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound || [JMString(contact[@"aimId"]) rangeOfString:query].location != NSNotFound) [contacts addObject:contact];
    }
    [contacts sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        BOOL favoriteA=[self.favoritePeers containsObject:a[@"aimId"]],favoriteB=[self.favoritePeers containsObject:b[@"aimId"]];
        if (favoriteA!=favoriteB) return favoriteA ? NSOrderedAscending : NSOrderedDescending;
        if (!conversations) {
            NSString *aGroup=[self historicalGroupForContact:a], *bGroup=[self historicalGroupForContact:b];
            NSComparisonResult group=[aGroup localizedCaseInsensitiveCompare:bGroup];
            if (group!=NSOrderedSame) return group;
            if (![aGroup isEqual:bGroup]) return [aGroup compare:bGroup];
        }
        if (conversations) {
            NSDictionary *lastA = [self.history lastMessageForPeer:a[@"aimId"]];
            NSDictionary *lastB = [self.history lastMessageForPeer:b[@"aimId"]];
            NSComparisonResult recency = [@([lastB[@"timestamp"] doubleValue]) compare:@([lastA[@"timestamp"] doubleValue])];
            if (recency != NSOrderedSame) return recency;
            return [JMName(a) localizedCaseInsensitiveCompare:JMName(b)];
        }
        BOOL aOnline = ![JMState(a) isEqualToString:JML(@"Не в сети")], bOnline = ![JMState(b) isEqualToString:JML(@"Не в сети")];
        if (aOnline != bOnline) return aOnline ? NSOrderedAscending : NSOrderedDescending;
        return [JMName(a) localizedCaseInsensitiveCompare:JMName(b)];
    }];
    NSUInteger contactCount=contacts.count;
    NSMutableDictionary *totals=[NSMutableDictionary dictionary], *online=[NSMutableDictionary dictionary], *counts=[NSMutableDictionary dictionary];
    if (!conversations) {
        for (NSDictionary *contact in contacts) {
            NSString *group=[self historicalGroupForContact:contact];
            totals[group]=@([totals[group] integerValue]+1);
            if (![JMState(contact) isEqual:JML(@"Не в сети")]) online[group]=@([online[group] integerValue]+1);
        }
        for (NSString *group in totals) counts[group]=[NSString stringWithFormat:@"%ld/%ld",(long)[online[group] integerValue],(long)[totals[group] integerValue]];
        NSArray *collapsed=query.length ? @[] : ([self.loginDefaults arrayForKey:[self collapsedGroupsKey]] ?: @[]);
        NSMutableSet *represented=[NSMutableSet set];
        NSMutableArray *rows=[NSMutableArray arrayWithCapacity:contacts.count];
        for (NSDictionary *contact in contacts) {
            NSString *group=[self historicalGroupForContact:contact];
            if (![collapsed containsObject:group]) [rows addObject:contact];
            else if (![represented containsObject:group]) { [rows addObject:@{@"_collapsedGroup":group,@"aimId":@""}]; [represented addObject:group]; }
        }
        contacts=rows;
    }
    self.visibleGroupCounts=counts;
    self.visibleContacts = contacts; self.reloadingContacts = YES; [self.contactTable reloadData];
    NSInteger selected = -1;
    for (NSUInteger i = 0; i < [contacts count]; i++) if ([contacts[i][@"aimId"] isEqual:selectionPeer]) { selected = (NSInteger)i; break; }
    if (selected >= 0) [self.contactTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selected] byExtendingSelection:NO];
    else [self.contactTable deselectAll:nil];
    self.reloadingContacts = NO;
    [self.countLabel setStringValue:[NSString stringWithFormat:@"%@: %lu", conversations ? JML(@"Переписок") : JML(@"Контактов"), (unsigned long)contactCount]];
    NSString *empty = [query length] ? JML(@"Ничего не найдено.\nПопробуйте другое имя или UIN.") : (conversations ? JML(@"Переписок пока нет.\nВыберите контакт или нажмите «Написать…».") : (self.selectedGroup.length ? JML(@"В этой группе пока нет контактов.\nДобавьте контакт или перенесите его из другой группы.") : JML(@"Контактов пока нет.\nНажмите «Добавить…», чтобы сохранить UIN на сервере.")));
    if (!contacts.count && (self.onlineOnlyCheckbox.state==NSOnState || self.favoritesOnlyCheckbox.state==NSOnState)) empty=JML(@"По выбранным фильтрам никого нет.\nОтключите «Только в сети» или «Избранные».");
    if (!contacts.count && conversations && self.unreadOnly) empty=JML(@"Нет непрочитанных сообщений.");
    [self.emptyListLabel setStringValue:empty]; [self.emptyListLabel setHidden:[contacts count] > 0];
    [self layoutChatWindow];
}
- (void)persistConversationPeers {
    if ([self.accountUIN length]) [self.loginDefaults setObject:[self.conversationPeers allObjects] forKey:[@"ConversationPeers." stringByAppendingString:self.accountUIN]];
}
- (void)changeSection:(id)sender {
    [self.searchField setStringValue:@""];
    [[self.searchField cell] setPlaceholderString:[self.sectionControl selectedSegment] == 1 ? JML(@"Поиск переписок") : JML(@"Поиск контактов")];
    [self layoutChatWindow]; [self reloadContacts];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return tableView==self.historyTable ? self.historyResults.count : self.visibleContacts.count; }
- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row { return [[JMContactRowView alloc] initWithFrame:NSZeroRect]; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView==self.historyTable) return JMString(self.historyResults[(NSUInteger)row][@"text"]);
    NSDictionary *contact = self.visibleContacts[(NSUInteger)row]; NSString *peer = contact[@"aimId"];
    if (contact[@"_collapsedGroup"]) return [self historicalHeaderForRow:row];
    NSInteger unread = [self.unread[peer] integerValue];
    NSString *name = [NSString stringWithFormat:@"%@%@", JMName(contact), unread ? [NSString stringWithFormat:@" (%ld)", (long)unread] : @""];
    NSString *state = [NSString stringWithFormat:@"%@ · %@", JMState(contact), peer];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", name, state]
        attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12]}];
    [text addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:13] range:NSMakeRange(0, [name length])];
    return text;
}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView==self.historyTable) {
        JMListCell *cell=[tableView makeViewWithIdentifier:@"historyResult" owner:self];
        if (!cell) { cell=[[JMListCell alloc] initWithFrame:NSMakeRect(0,0,NSWidth(tableView.bounds),54)]; cell.identifier=@"historyResult"; }
        NSDictionary *message=self.historyResults[(NSUInteger)row]; NSString *peer=message[@"peer"];
        NSString *name=JMName(self.contacts[peer] ?: @{@"aimId":peer});
        NSDateFormatter *format=[[NSDateFormatter alloc] init]; format.dateFormat=@"dd.MM.yyyy HH:mm";
        NSString *date=[format stringFromDate:[NSDate dateWithTimeIntervalSince1970:[message[@"timestamp"] doubleValue]]];
        NSString *title=[NSString stringWithFormat:@"%@%@ · %@",[message[@"outgoing"] boolValue] ? JML(@"Вы → ") : @"",name,date];
        NSString *snippet=JMHistorySnippet(JMString(message[@"text"]),self.historyResultsQuery);
        [cell configureName:title detail:snippet state:JMString(self.contacts[peer][@"state"]) unread:0]; [cell setAvatar:nil];
        [cell setToolTip:[NSString stringWithFormat:@"%@\nUIN %@ · %@\n%@",name,peer,date,snippet]]; return cell;
    }
    JMListCell *cell = [tableView makeViewWithIdentifier:@"person" owner:self];
    if (!cell) { cell = [[JMListCell alloc] initWithFrame:NSMakeRect(0,0,NSWidth([tableView bounds]),54)]; [cell setIdentifier:@"person"]; }
    NSDictionary *contact = self.visibleContacts[(NSUInteger)row]; NSString *peer = contact[@"aimId"];
    cell.groupTitle=[self historicalHeaderForRow:row];
    cell.groupOnly=contact[@"_collapsedGroup"]!=nil;
    if (cell.groupOnly) { cell.toolTip=JML(@"Нажмите, чтобы развернуть группу."); cell.textField.stringValue=cell.groupTitle; return cell; }
    NSString *detail = [NSString stringWithFormat:@"%@ · %@", JMState(contact), peer];
    if ([self.sectionControl selectedSegment] == 1) {
        NSDictionary *last = [self.history lastMessageForPeer:peer];
        NSString *draft = JMString(self.drafts[peer]);
        if ([draft length]) detail = [JML(@"Черновик: ") stringByAppendingString:draft];
        else if (last) detail = [NSString stringWithFormat:@"%@%@", [last[@"outgoing"] boolValue] ? JML(@"Вы: ") : @"", JMString(last[@"text"])];
        else detail = JML(@"Новая переписка");
        detail = [detail stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }
    if (JMTheme()==JMThemeMac2011 && self.sectionControl.selectedSegment==0) detail=JMString(contact[@"statusMsg"]);
    [cell configureName:[self.favoritePeers containsObject:peer] ? [@"★ " stringByAppendingString:JMName(contact)] : JMName(contact) detail:detail state:JMString(contact[@"state"]) unread:[self.unread[peer] integerValue]];
    if (self.sectionControl.selectedSegment==1) {
        NSDictionary *last=[self.history lastMessageForPeer:peer];
        [cell setTimestamp:last ? [self listTimestamp:[NSDate dateWithTimeIntervalSince1970:[last[@"timestamp"] doubleValue]]] : nil draft:JMString(self.drafts[peer]).length>0];
        if (last) [cell setTimestampTooltip:[NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:[last[@"timestamp"] doubleValue]] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle]];
    }
    [cell setToolTip:[NSString stringWithFormat:@"%@\nUIN %@ · %@%@",JMName(contact),peer,JMState(contact),[self.sectionControl selectedSegment]==1 ? [@"\n" stringByAppendingString:detail] : @""]];
    [cell setAvatar:JMTheme()==JMThemePro2003 ? nil : [self.avatars imageForUIN:peer]];
    return cell;
}
- (NSString *)listTimestamp:(NSDate *)date {
    NSDateFormatter *format=[[NSDateFormatter alloc] init]; format.locale=JMLocale(); format.dateFormat=@"yyyy-MM-dd";
    NSDate *now=[NSDate date]; NSString *day=[format stringFromDate:date];
    if ([day isEqualToString:[format stringFromDate:now]]) format.dateFormat=@"HH:mm";
    else {
        NSDateComponents *offset=[[NSDateComponents alloc] init]; offset.day=-1;
        NSDate *yesterday=[[NSCalendar currentCalendar] dateByAddingComponents:offset toDate:now options:0];
        if ([day isEqualToString:[format stringFromDate:yesterday]]) return JML(@"Вчера");
        format.dateFormat=@"dd.MM";
    }
    return [format stringFromDate:date];
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (notification.object==self.historyTable) { [self.historyOpenButton setEnabled:self.historyTable.selectedRow>=0]; return; }
    if (self.reloadingContacts || JMTheme()!=JMThemeCurrent) return;
    NSInteger row = [self.contactTable selectedRow]; if (row < 0 || row >= (NSInteger)[self.visibleContacts count]) return;
    BOOL navigatingList=self.chatWindow.firstResponder==self.contactTable;
    [self selectPeer:self.visibleContacts[(NSUInteger)row][@"aimId"]];
    if (navigatingList) [self.chatWindow makeFirstResponder:self.contactTable];
}
- (void)selectPeer:(NSString *)peer {
    if (self.dataOperationInProgress || !JMValidUIN(peer)) return;
    self.highlightedMessageID=nil; self.historyHighlightQuery=nil;
    if (self.selectedPeer && ![self.selectedPeer isEqualToString:peer]) [self stopOutgoingTyping];
    if (self.selectedPeer) [self rememberDraftForPeer:self.selectedPeer text:self.composer.string];
    BOOL changed=![self.selectedPeer isEqualToString:peer];
    self.selectedPeer = peer; [self updateDockBadge];
    [self.conversationPeers addObject:peer]; [self persistConversationPeers];
    [self.composer setString:self.drafts[peer] ?: @""];
    if (changed) { self.transcriptTail=YES; self.transcriptOffset=0; [self.transcript setString:@""]; [self.composer.undoManager removeAllActions]; }
    [self.composer setSelectedRange:NSMakeRange(self.composer.string.length,0)];
    NSString *firstUnread=changed ? [self.history firstUnreadIDForPeer:peer] : nil;
    if (firstUnread) [self setTranscriptAroundID:firstUnread];
    [self updatePeerLabel]; [self renderTranscript]; [self updateSendButton]; [self reloadContacts];
    if (firstUnread && self.transcriptRanges[firstUnread]) { self.renderingTranscript=YES; [self.transcript scrollRangeToVisible:[self.transcriptRanges[firstUnread] rangeValue]]; self.renderingTranscript=NO; }
    [self.chatWindow makeFirstResponder:self.composer];
    [self updateTypingIndicator]; [self refreshPresenceForPeer:peer force:NO];
    if (JMTheme()!=JMThemeCurrent) [self.chatWindow makeKeyAndOrderFront:nil];
    [self markSelectedRead];
}
- (void)updatePeerLabel {
    NSDictionary *contact = self.contacts[self.selectedPeer ?: @""];
    [self.peerLabel setStringValue:contact ? JMName(contact) : JML(@"Личные сообщения")];
    if (JMTheme()==JMThemePro2003 && contact) self.peerLabel.stringValue=[NSString stringWithFormat:JML(@"ICQ#: %@   Имя: %@"),self.selectedPeer,JMName(contact)];
    self.chatWindow.title=JMTheme()==JMThemeCurrent ? @"JimmMac" : (contact ? (JMTheme()==JMThemePro2003 ? [NSString stringWithFormat:@"[%@] %@ — JimmMac",JMState(contact),JMName(contact)] : [NSString stringWithFormat:@"%@ — %@ — JimmMac",JMName(contact),JMState(contact)]) : JML(@"JimmMac — Сообщения"));
    [self.peerDetail setStringValue:contact ? [NSString stringWithFormat:@"UIN %@ · %@%@", self.selectedPeer, JMState(contact), [self.serverContactIDs containsObject:self.selectedPeer] ? JML(@" · В контактах") : @""] : JML(@"Контакты и переписки Jimm.online")];
    if ([self.mutedPeers containsObject:self.selectedPeer ?: @""]) self.peerDetail.stringValue=[self.peerDetail.stringValue stringByAppendingString:JML(@" · Без уведомлений")];
    [self.addPeerButton setHidden:!contact || [self.serverContactIDs containsObject:self.selectedPeer]];
    self.themeUINValue.stringValue=self.selectedPeer ?: @""; self.themeNickValue.stringValue=contact ? JMName(contact) : @""; self.themeUINValue.toolTip=self.themeUINValue.stringValue; self.themeNickValue.toolTip=self.themeNickValue.stringValue; self.themeRecipientState.image=JMStatusImage(contact[@"state"]); self.themeRecipientState.toolTip=JMState(contact);
    [self.peerAvatar setImage:[self.avatars imageForUIN:self.selectedPeer] ?: (JMTheme()==JMThemeMac2011 ? JMRetroImage(@"avatar") : nil) ?: [NSImage imageNamed:NSImageNameUser]];
    [self.peerLabel setToolTip:self.peerLabel.stringValue]; [self.peerDetail setToolTip:self.peerDetail.stringValue];
    [self.profileButton setEnabled:contact!=nil];
    self.profileButton.hidden=!contact; self.historySearchButton.hidden=!contact; self.peerAvatar.hidden=!contact;
    [self layoutChatWindow];
}
- (void)renderTranscript {
    self.renderingTranscript=YES;
    NSClipView *clip=self.transcript.enclosingScrollView.contentView;
    NSPoint position=clip.bounds.origin;
    NSRange selection=self.transcript.selectedRange;
    NSString *previousText=[self.transcript.string copy];
    if (selection.length && self.transcriptTail && [self.history countForPeer:self.selectedPeer ?: @""]>200) self.transcriptTail=NO;
    NSUInteger count=[self.history countForPeer:self.selectedPeer ?: @""];
    if (self.transcriptTail || self.transcriptOffset>=count) self.transcriptOffset=count>200 ? count-200 : 0;
    NSArray *page=[self.history messagesForPeer:self.selectedPeer ?: @"" offset:self.transcriptOffset limit:200];
    self.olderMessagesButton.hidden=count<=200; self.newerMessagesButton.hidden=count<=200;
    self.olderMessagesButton.enabled=self.transcriptOffset>0; self.newerMessagesButton.enabled=self.transcriptOffset+page.count<count;
    self.historyPageLabel.hidden=count<=200;
    JMSetLabel(self.historyPageLabel,count ? [NSString stringWithFormat:JML(@"%lu–%lu из %lu"),(unsigned long)self.transcriptOffset+1,(unsigned long)(self.transcriptOffset+page.count),(unsigned long)count] : @"");
    BOOL follow=self.transcriptTail && !selection.length && (!previousText.length || NSMaxY(clip.bounds)>=NSHeight(self.transcript.bounds)-24);
    self.transcriptRanges=[NSMutableDictionary dictionary];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
    NSDateFormatter *date=[[NSDateFormatter alloc] init]; date.dateFormat=@"HH:mm";
    NSDateFormatter *dayFormat=[[NSDateFormatter alloc] init]; dayFormat.locale=JMLocale(); dayFormat.dateFormat=@"d MMMM yyyy";
    NSDateFormatter *fullDate=[[NSDateFormatter alloc] init]; fullDate.dateFormat=@"dd.MM.yyyy HH:mm";
    NSString *previousDay=nil;
    NSMutableParagraphStyle *bodyStyle=[[NSMutableParagraphStyle alloc] init]; bodyStyle.lineSpacing=JMTheme()==JMThemePro2003 ? 0 : 2; bodyStyle.paragraphSpacing=JMTheme()==JMThemeMac2011 ? 5 : 0;
    NSMutableParagraphStyle *headingStyle=[[NSMutableParagraphStyle alloc] init]; headingStyle.paragraphSpacing=3;
    if (JMTheme()==JMThemeMac2011) headingStyle.tabStops=@[[[NSTextTab alloc] initWithType:NSRightTabStopType location:MAX(100,NSWidth(self.transcript.enclosingScrollView.contentView.bounds)-32)]];
    NSString *firstUnread=[self.history firstUnreadIDForPeer:self.selectedPeer ?: @""];
    for (NSDictionary *message in page) {
        NSDate *sentAt=[NSDate dateWithTimeIntervalSince1970:[message[@"timestamp"] doubleValue]];
        NSString *day=[dayFormat stringFromDate:sentAt];
        if (![day isEqualToString:previousDay]) {
            NSMutableParagraphStyle *dayStyle=[[NSMutableParagraphStyle alloc] init]; dayStyle.alignment=NSCenterTextAlignment; dayStyle.paragraphSpacingBefore=previousDay ? 10 : 0; dayStyle.paragraphSpacing=12;
            [text appendAttributedString:[[NSAttributedString alloc] initWithString:[day stringByAppendingString:@"\n"] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:MAX(11,self.chatPreferences.size*0.8)],NSForegroundColorAttributeName:JMSecondaryTextColor(),NSParagraphStyleAttributeName:dayStyle}]];
            previousDay=day;
        }
        if ([message[@"id"] isEqual:firstUnread]) [text appendAttributedString:[[NSAttributedString alloc] initWithString:JML(@"— Непрочитанные сообщения —\n\n") attributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:11],NSForegroundColorAttributeName:JMSecondaryTextColor()}]];
        NSUInteger messageStart=text.length;
        BOOL outgoing=[message[@"outgoing"] boolValue];
        NSString *name=outgoing ? JML(@"Вы") : JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer ?: @""});
        NSString *delivery=JMString(message[@"delivery"]), *deliveryText=@"";
        if (outgoing) { if ([delivery isEqual:@"pending"]) deliveryText=JML(@" · Отправляется…"); else if ([delivery isEqual:@"accepted"]) deliveryText=JML(@" · Принято сервером"); else if ([delivery isEqual:@"failed"]) deliveryText=JML(@" · Не отправлено · правый щелчок для повтора"); else if ([delivery isEqual:@"unknown"]) deliveryText=JML(@" · Подтверждение не получено · возможен повтор"); }
        if ([self.history isBookmarkedID:message[@"id"] peer:self.selectedPeer]) deliveryText=[@" ★" stringByAppendingString:deliveryText];
        NSString *heading=[NSString stringWithFormat:JMTheme()==JMThemeMac2011 ? @"%@\t%@%@\n" : @"%@  %@%@\n",name,[date stringFromDate:sentAt],deliveryText];
        NSMutableAttributedString *header=[[NSMutableAttributedString alloc] initWithString:heading attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:MAX(10,self.chatPreferences.size-2)],NSForegroundColorAttributeName:JMSecondaryTextColor(),NSParagraphStyleAttributeName:headingStyle,NSToolTipAttributeName:[NSString stringWithFormat:@"%@ · %@",name,[fullDate stringFromDate:sentAt]]}];
        [header addAttributes:@{NSFontAttributeName:self.chatPreferences.headingFont,NSForegroundColorAttributeName:outgoing ? [NSColor colorWithCalibratedRed:0.25 green:0.35 blue:0.5 alpha:1] : (JMTheme()==JMThemePro2003 ? [NSColor colorWithCalibratedRed:0.55 green:0.05 blue:0.05 alpha:1] : [NSColor colorWithCalibratedRed:0.16 green:0.42 blue:0.17 alpha:1])} range:NSMakeRange(0,name.length)];
        if (JMTheme()==JMThemeMac2011) [header addAttributes:@{NSFontAttributeName:JMThemeFont(self.chatPreferences.headingFont,self.chatPreferences.family),NSForegroundColorAttributeName:outgoing ? [NSColor colorWithCalibratedRed:0.15 green:0.39 blue:0.12 alpha:1] : [NSColor colorWithCalibratedWhite:0.19 alpha:1]} range:NSMakeRange(0,name.length)];
        [text appendAttributedString:header];
        NSString *plain=JMString(message[@"text"]);

        NSMutableAttributedString *body=[[NSMutableAttributedString alloc] initWithString:[plain stringByAppendingString:@"\n\n"] attributes:@{NSFontAttributeName:JMThemeFont(self.chatPreferences.messageFont,self.chatPreferences.family),NSForegroundColorAttributeName:[NSColor textColor],NSParagraphStyleAttributeName:bodyStyle}];
        for (NSTextCheckingResult *link in JMLinksInText(plain)) [body addAttributes:@{NSLinkAttributeName:link.URL,NSToolTipAttributeName:link.URL.absoluteString} range:link.range];
        if ([JMString(message[@"id"]) isEqualToString:self.highlightedMessageID] && self.historyHighlightQuery.length) {
            NSRange remaining=NSMakeRange(0,plain.length);
            while (remaining.length) {
                NSRange hit=[plain rangeOfString:self.historyHighlightQuery options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch range:remaining];
                if (hit.location==NSNotFound) break;
                [body addAttribute:NSBackgroundColorAttributeName value:[NSColor colorWithCalibratedRed:1 green:0.94 blue:0.55 alpha:1] range:hit];
                remaining=NSMakeRange(NSMaxRange(hit),plain.length-NSMaxRange(hit));
            }
        }
        if (self.chatPreferences.emoticonsEnabled) JMApplyEmoticons(body);
        if (JMString(message[@"id"]).length) self.transcriptRanges[message[@"id"]]=[NSValue valueWithRange:NSMakeRange(text.length,body.length>=2 ? body.length-2 : 0)];
        [text appendAttributedString:body];
        if (JMString(message[@"id"]).length) [text addAttribute:@"JMMessageID" value:message[@"id"] range:NSMakeRange(messageStart,text.length-messageStart-2)];
    }
    self.conversationEmptyView.hidden=text.length>0; [self.conversationEmptyView setHasPeer:self.selectedPeer.length>0];
    // New events and presence/profile refreshes must not erase a copy selection.
    // Restore only if every character before its end is still in the same place.
    BOOL preserveSelection=selection.length && selection.location!=NSNotFound && NSMaxRange(selection)<=MIN(previousText.length,text.length) &&
        [[previousText substringToIndex:NSMaxRange(selection)] isEqualToString:[text.string substringToIndex:NSMaxRange(selection)]];
    [[self.transcript textStorage] setAttributedString:text];
    if (preserveSelection) [self.transcript setSelectedRange:selection];
    [[self.transcript layoutManager] ensureLayoutForTextContainer:self.transcript.textContainer];
    NSRect used=[[self.transcript layoutManager] usedRectForTextContainer:self.transcript.textContainer];
    [self.transcript setFrameSize:NSMakeSize(NSWidth(clip.bounds),MAX(NSHeight(clip.bounds),ceil(NSMaxY(used)+2*self.transcript.textContainerInset.height)))];
    if (follow) [self.transcript scrollRangeToVisible:NSMakeRange([text length], 0)];
    else { [clip scrollToPoint:[clip constrainScrollPoint:position]]; [self.transcript.enclosingScrollView reflectScrolledClipView:clip]; }
    self.renderingTranscript=NO; [self updateUnreadControls];
}
- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object==self.searchField) [self reloadContacts];
    else if (notification.object==self.historySearchField) [self searchHistory:nil];
}
- (void)textDidChange:(NSNotification *)notification {
    if ([notification object] == self.composer) {
        if (self.selectedPeer) [self rememberDraftForPeer:self.selectedPeer text:self.composer.string]; [self updateSendButton];
        [self.outgoingTypingTimer invalidate];
        if ([[self.composer string] length] && self.selectedPeer) {
            [self.client setTypingStatus:@"typing" forUIN:self.selectedPeer];
            self.outgoingTypingTimer=[NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(typingIdle:) userInfo:nil repeats:NO];
        } else [self stopOutgoingTyping];
    }
}
- (void)updateSendButton {
    BOOL hasPeer = [self.selectedPeer length] > 0;
    // Network availability controls sending, never the ability to prepare a draft.
    [self.composer setSelectable:YES];
    [self.composer setEditable:hasPeer && !self.dataOperationInProgress];
    self.contactTable.enabled=!self.dataOperationInProgress; self.sectionControl.enabled=!self.dataOperationInProgress;
    self.searchField.enabled=!self.dataOperationInProgress; self.groupFilter.enabled=!self.dataOperationInProgress;
    self.onlineOnlyCheckbox.enabled=!self.offlineMode && !self.dataOperationInProgress; self.favoritesOnlyCheckbox.enabled=!self.dataOperationInProgress;
    self.logoutButton.enabled=!self.dataOperationInProgress; self.offlineHistoryButton.enabled=!self.dataOperationInProgress;
    BOOL ready = self.client.connected && hasPeer && !self.sending && !self.dataOperationInProgress;
    [self.presencePopup setEnabled:self.client.connected && (!self.changingPresence || self.automaticPresenceRequest) && !self.dataOperationInProgress];
    self.presencePopup.toolTip=[NSString stringWithFormat:@"%@\n%@",self.presencePopup.titleOfSelectedItem ?: @"",JML(@"Ваш статус в сети. После изменения клиент проверит его на сервере.")];
    [self.historySearchButton setEnabled:self.history!=nil];
    [self.presenceFeedback setHidden:!self.client.connected];
    self.statusLabel.hidden=JMTheme()!=JMThemeCurrent && self.client.connected && self.presenceFeedback.stringValue.length>0;
    if (JMThemeIsMobile()) self.presencePopup.hidden=!self.client.connected;
    [self.reconnectButton setHidden:self.client.connected]; [self.reconnectButton setEnabled:!self.client.connected && !self.dataOperationInProgress];
    [self.addContactButton setEnabled:[self canChangeRoster]];
    [self.addContactButton setTitle:self.addingContact ? JML(@"Добавляем…") : JML(@"Добавить…")];
    [self.addPeerButton setEnabled:[self canChangeRoster]]; [self updateGroupControls];
    BOOL hasText = [[[self.composer string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
    BOOL coolingDown = [self.sendNotBefore timeIntervalSinceNow] > 0;
    NSUInteger bytes=[self.composer.string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    self.themeComposerCount.stringValue=[NSString stringWithFormat:JML(@"Символов: %lu"),(unsigned long)self.composer.string.length];
    self.themeSmileyButton.enabled=self.composer.isEditable; self.themeFavoriteButton.state=self.favoritesOnlyCheckbox.state; self.themeFavoriteButton.enabled=self.history!=nil && !self.dataOperationInProgress; self.themeFontButton.enabled=!self.dataOperationInProgress; self.themeConversationTabs.enabled=!self.dataOperationInProgress; self.themeConversationPicker.enabled=!self.dataOperationInProgress; self.themeMainMenu.enabled=!self.dataOperationInProgress;
    [self.sendButton setEnabled:ready && hasText && bytes<=4000 && !coolingDown];
    [self.sendButton setTitle:self.sending ? JML(@"Отправляем…") : (coolingDown ? JML(@"Подождите…") : JML(@"Отправить"))];
    NSString *shortcut=self.chatPreferences.sendWithCommandReturn ? @"⌘Enter" : @"Enter";
    NSString *hint=[NSString stringWithFormat:JML(@"%@ — отправить · Shift+Enter — новая строка"),shortcut];
    if (!hasPeer) hint=JML(@"Выберите контакт или нажмите «Написать…»");
    else if (self.draftSaveError) hint=JML(@"Не удалось сохранить черновики на этом Mac");
    else if (self.sending) hint=JML(@"Отправляем… Новый текст останется в черновике");
    else if (bytes>4000) hint=[NSString stringWithFormat:JML(@"Текст: %lu / 4000 байт UTF-8 — разделите сообщение"),(unsigned long)bytes];
    else if (!self.client.connected) hint=hasText && self.draftStore ? (self.draftsPending ? JML(@"Нет связи · Сохраняем черновик…") : JML(@"Нет связи · Черновик сохранён на этом Mac")) : JML(@"Можно писать черновик. Отправка — после подключения.");
    else if (hasText && self.draftStore) hint=self.draftsPending ? JML(@"Сохраняем черновик…") : [NSString stringWithFormat:JML(@"Черновик сохранён · %@ — отправить"),shortcut];
    self.composerHint.stringValue=hint;
    self.composerHint.textColor=self.draftSaveError || bytes>4000 ? [NSColor redColor] : JMSecondaryTextColor();
    self.composerHint.toolTip=self.draftSaveError ? [NSString stringWithFormat:JML(@"%@. Текст остаётся в окне; скопируйте его перед выходом. %@"),hint,self.draftSaveError.localizedDescription] : hint;
    self.composer.toolTip=[NSString stringWithFormat:JML(@"%@ — отправить. %@ Черновики автоматически сохраняются на этом Mac. Лимит сообщения — 4000 байт UTF-8."),shortcut,self.chatPreferences.sendWithCommandReturn ? JML(@"Enter — новая строка.") : JML(@"Shift+Enter — новая строка.")];
    self.sendButton.toolTip=[NSString stringWithFormat:JML(@"Отправить сообщение выбранному собеседнику (%@)"),shortcut];
}
- (BOOL)textView:(NSTextView *)view shouldChangeTextInRange:(NSRange)range replacementString:(NSString *)text {
    if (view==self.composer && self.sending && [self.selectedPeer isEqualToString:self.sendingPeer] && range.location<self.sendingText.length) self.sendingDraftWasEdited=YES;
    return YES;
}
- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (textView==self.composer && (commandSelector==@selector(insertTab:) || commandSelector==@selector(insertBacktab:)) && !textView.hasMarkedText) {
        if (commandSelector==@selector(insertTab:)) [self.chatWindow selectNextKeyView:nil]; else [self.chatWindow selectPreviousKeyView:nil];
        return YES;
    }
    if (textView == self.composer && commandSelector == @selector(insertNewline:)) {
        NSUInteger flags=[[NSApp currentEvent] modifierFlags];
        if ([textView hasMarkedText] || (flags & (NSShiftKeyMask|NSAlternateKeyMask|NSControlKeyMask))) return NO;
        if (self.chatPreferences.sendWithCommandReturn && !(flags & NSCommandKeyMask)) return NO;
        [self send:nil]; return YES;
    }
    return NO;
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (textView.hasMarkedText) return NO;
    if (control==self.uinField && command==@selector(insertNewline:)) { [self.loginWindow makeFirstResponder:self.passwordField]; return YES; }
    if (control==self.searchField && (command==@selector(moveDown:) || command==@selector(insertNewline:))) {
        if (self.visibleContacts.count) {
            if (self.contactTable.selectedRow<0) [self.contactTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
            if (command==@selector(insertNewline:)) [self activateContactSelection:nil];
            else [self.chatWindow makeFirstResponder:self.contactTable];
        }
        return YES;
    }
    return NO;
}
- (void)send:(id)sender {
    if (![self.sendButton isEnabled] || self.composer.hasMarkedText) return;
    NSString *text=[self.composer.string copy], *peer=[self.selectedPeer copy];
    if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>4000) return;
    [self rememberDraftForPeer:peer text:text]; [self persistDraftsNow];
    NSDictionary *record=@{@"peer":peer,@"id":[@"local-" stringByAppendingString:[[NSUUID UUID] UUIDString]],@"text":text,@"timestamp":@([[NSDate date] timeIntervalSince1970]),@"outgoing":@YES,@"delivery":@"pending"};
    NSError *error=nil;
    if (![self.history appendMessage:record error:&error]) { [self showError:JML(@"Не удалось сохранить сообщение") detail:error.localizedDescription]; return; }
    [self.conversationPeers addObject:peer]; [self persistConversationPeers];
    [self transmitRecord:record clearsDraft:YES];
}
- (void)retryMessage:(NSMenuItem *)sender {
    NSDictionary *message=[self messageForAction:sender];
    if (!message || self.sending || !self.client.connected || self.sendNotBefore.timeIntervalSinceNow>0 || ![@[@"failed",@"unknown"] containsObject:JMString(message[@"delivery"])]) return;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Повторить отправку сообщения?");
    alert.informativeText=[message[@"delivery"] isEqual:@"unknown"] ? JML(@"Предыдущее сообщение могло дойти до собеседника. Сначала проверьте переписку: повторная отправка может создать дубликат.") : JML(@"Сообщение будет отправлено ещё раз. Текущий черновик останется без изменений.");
    [alert addButtonWithTitle:JML(@"Отправить ещё раз")]; NSButton *cancel=[alert addButtonWithTitle:JML(@"Отмена")]; cancel.keyEquivalent=@"\e";
    if ([alert runModal]==NSAlertFirstButtonReturn) [self transmitRecord:message clearsDraft:NO];
}
- (void)transmitRecord:(NSDictionary *)record clearsDraft:(BOOL)clearsDraft {
    if (self.sending || !self.client.connected || self.sendNotBefore.timeIntervalSinceNow>0) return;
    NSString *text=record[@"text"], *peer=record[@"peer"], *identifier=record[@"id"];
    NSError *writeError=nil;
    if (![self.history setDelivery:@"pending" forID:identifier peer:peer error:&writeError]) { [self showError:JML(@"Не удалось сохранить отправку") detail:writeError.localizedDescription]; return; }
    self.sending=YES; self.sendingPeer=peer; self.sendingText=text; self.sendingLocalID=identifier; self.sendingDraftWasEdited=NO; self.sendingClearsDraft=clearsDraft;
    NSUInteger generation=self.conversationGeneration; JMHistory *history=self.history;
    if (clearsDraft && [self.selectedPeer isEqual:peer]) { self.transcriptTail=YES; self.transcript.selectedRange=NSMakeRange(0,0); }
    [self updateSendButton]; [self stopOutgoingTyping]; [self renderTranscript];
    if (clearsDraft && [self.selectedPeer isEqual:peer]) [self.transcript scrollRangeToVisible:NSMakeRange(self.transcript.string.length,0)];
    [self reloadContacts];
    __weak JMAppDelegate *weakSelf=self;
    [self.client sendText:text to:peer completion:^(NSDictionary *data,NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self || generation!=self.conversationGeneration || history!=self.history) return;
        BOOL edited=self.sendingDraftWasEdited;
        self.sending=NO; self.sendingPeer=nil; self.sendingText=nil; self.sendingLocalID=nil;
        if (clearsDraft && [self.selectedPeer isEqualToString:peer]) [self rememberDraftForPeer:peer text:self.composer.string];
        NSString *current=JMString(self.drafts[peer]);
        if (error) {
            BOOL uncertain=[error.domain isEqualToString:NSURLErrorDomain];
            NSError *saveError=nil; [history setDelivery:uncertain ? @"unknown" : @"failed" forID:identifier peer:peer error:&saveError];
            if ([error.domain isEqualToString:JMAPIErrorDomain] && (error.code==430 || error.code==429)) {
                NSTimeInterval delay=MAX(1,[error.userInfo[@"retryAfter"] doubleValue]); self.sendNotBefore=[NSDate dateWithTimeIntervalSinceNow:delay];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((delay+0.1)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ if (generation==self.conversationGeneration) [self updateSendButton]; });
            }
            NSString *detail=uncertain ? JML(@"Подтверждение не получено. Сообщение могло дойти; проверьте переписку перед повторной отправкой.") : error.localizedDescription;
            if (clearsDraft && ![current hasPrefix:text]) {
                NSString *recovered=current.length ? [NSString stringWithFormat:@"%@\n\n%@",text,current] : text; [self rememberDraftForPeer:peer text:recovered];
                if ([self.selectedPeer isEqualToString:peer]) { self.composer.string=recovered; [self.composer.undoManager removeAllActions]; }
                detail=[detail stringByAppendingString:JML(@" Неотправленный текст возвращён в начало черновика.")];
            }
            [self persistDraftsNow]; [self updateSendButton]; [self renderTranscript]; [self reloadContacts];
            [self showError:JML(@"Не удалось подтвердить отправку") detail:saveError ? saveError.localizedDescription : detail]; return;
        }
        NSString *msgID=JMString(data[@"msgId"]); if (!msgID.length) msgID=identifier;
        NSTimeInterval timestamp=[JMString(data[@"timestamp"]) doubleValue];
        NSDictionary *message=@{@"peer":peer,@"outgoing":@YES,@"text":text,@"id":msgID,@"timestamp":@(timestamp>0 ? timestamp : [record[@"timestamp"] doubleValue]),@"name":@""};
        NSError *saveError=nil;
        if ([history confirmLocalID:identifier peer:peer message:message error:&saveError]) {
            if (clearsDraft) {
                NSString *remaining=current; if ([current isEqualToString:text]) remaining=@""; else if (!edited && [current hasPrefix:text]) remaining=[current substringFromIndex:text.length];
                [self rememberDraftForPeer:peer text:remaining];
                if ([self.selectedPeer isEqualToString:peer]) { self.composer.string=remaining; [self.composer.undoManager removeAllActions]; }
                [self persistDraftsNow];
            }
        } else [self showError:JML(@"Сервер принял сообщение, но история не сохранена") detail:saveError.localizedDescription];
        [self updateSendButton]; [self renderTranscript]; [self reloadContacts];
    }];
}
- (NSAlert *)newConversationPrompt {
    NSAlert *alert = [[NSAlert alloc] init]; [alert setMessageText:JML(@"Написать по UIN")];
    [alert setInformativeText:JML(@"Введите UIN собеседника в Jimm.online. Это откроет разговор; контакт-лист на сервере не изменится.")];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 25)];
    [field setEditable:YES]; [field setSelectable:YES]; [field setEnabled:YES];
    [field setToolTip:JML(@"Числовой UIN собеседника в Jimm.online")];
    [alert setAccessoryView:field];
    [alert addButtonWithTitle:JML(@"Открыть")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
    [[alert window] setInitialFirstResponder:field];
    return alert;
}
- (void)openConversation:(id)sender {
    NSAlert *alert = [self newConversationPrompt];
    NSTextField *field = (NSTextField *)[alert accessoryView];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *peer = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!JMValidUIN(peer)) { [self showError:JML(@"Проверьте UIN") detail:JML(@"UIN должен состоять из цифр.")]; return; }
    if (!self.contacts[peer]) self.contacts[peer] = [@{@"aimId":peer, @"friendly":peer, @"state":@"offline"} mutableCopy];
    [self.sectionControl setSelectedSegment:1];
    [self.searchField setStringValue:@""]; [self selectPeer:peer];
}
- (NSAlert *)newAddContactPrompt {
    NSAlert *alert = [self newConversationPrompt]; [alert setMessageText:JML(@"Добавить контакт")];
    [alert setInformativeText:JML(@"Укажите UIN в Jimm.online. Контакт сохранится на сервере и будет доступен в других клиентах.")];
    [[[alert buttons] firstObject] setTitle:JML(@"Добавить")];
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,88)];
    [view addSubview:JMLabel(@"UIN",NSMakeRect(0,55,60,22),13,NO)];
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(68,53,292,25)]; field.tag=101; field.toolTip=JML(@"Числовой UIN контакта в Jimm.online"); [view addSubview:field];
    [view addSubview:JMLabel(JML(@"Группа"),NSMakeRect(0,15,60,22),13,NO)];
    NSPopUpButton *groups=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(68,11,292,32) pullsDown:NO]; groups.tag=102;
    [groups addItemsWithTitles:self.serverGroups.count ? self.serverGroups : @[@"Buddies"]];
    if (self.selectedGroup.length) [groups selectItemWithTitle:self.selectedGroup];
    else if ([self.serverGroups containsObject:@"Buddies"]) [groups selectItemWithTitle:@"Buddies"];
    groups.toolTip=JML(@"Группа, в которой контакт будет сохранён на сервере"); [view addSubview:groups];
    alert.accessoryView=view; [alert.window setInitialFirstResponder:field]; return alert;
}
- (void)addContact:(id)sender {
    if (![self canChangeRoster]) return;
    NSAlert *alert = [self newAddContactPrompt];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *uin=[[(NSTextField *)[alert.accessoryView viewWithTag:101] stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *group=[(NSPopUpButton *)[alert.accessoryView viewWithTag:102] titleOfSelectedItem];
    [self addContactUIN:uin group:group];
}
- (void)addSelectedPeer:(id)sender { if (self.selectedPeer) [self addContactUIN:self.selectedPeer]; }
- (void)addContactUIN:(NSString *)uin {
    [self addContactUIN:uin group:self.selectedGroup ?: @"Buddies"];
}
- (void)addContactUIN:(NSString *)uin group:(NSString *)group {
    if (!JMValidUIN(uin)) { [self showError:JML(@"Проверьте UIN") detail:JML(@"UIN должен состоять из цифр.")]; return; }
    if (![self canChangeRoster]) return;
    if ([self.serverContactIDs containsObject:uin]) { [self.contactNotice setStringValue:JML(@"Этот UIN уже в контактах.")]; return; }
    self.addingContact = YES; [self.contactNotice setStringValue:JML(@"Сохраняем контакт на сервере…")]; [self updateSendButton];
    __weak JMAppDelegate *weakSelf = self;
    [self.client addContactWithUIN:uin group:group completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self = weakSelf; if (!self) return;
        self.addingContact = NO; [self updateSendButton];
        if (error) { [self.contactNotice setStringValue:JML(@"Контакт не добавлен. Повторите попытку.")]; [self showError:JML(@"Не удалось добавить контакт") detail:[error localizedDescription]]; return; }
        if (!self.contacts[uin]) self.contacts[uin] = [@{@"aimId":uin, @"friendly":uin, @"state":@"offline"} mutableCopy];
        if (![JMString(data[@"resultCode"]) isEqualToString:@"alreadyExists"] && group.length) {
            NSMutableArray *groups=[JMArray(self.contacts[uin][@"groups"]) mutableCopy]; if (![groups containsObject:group]) [groups addObject:group];
            self.contacts[uin][@"groups"]=groups; self.contacts[uin][@"group"]=[groups firstObject] ?: @"";
            if (![self.serverGroups containsObject:group]) [self.serverGroups addObject:group];
            if (self.selectedGroup.length && ![self.selectedGroup isEqualToString:group]) self.selectedGroup=group;
        }
        [self.serverContactIDs addObject:uin];
        [self.contactNotice setStringValue:[JMString(data[@"resultCode"]) isEqualToString:@"alreadyExists"] ? JML(@"Этот UIN уже был на сервере.") : JML(@"Контакт добавлен в Jimm.online.")];
        [self refreshGroupChoices]; [self.sectionControl setSelectedSegment:0]; [self changeSection:nil]; [self updatePeerLabel];
    }];
}
- (void)avatarStore:(JMAvatarStore *)store updatedUIN:(NSString *)uin {
    if ([uin isEqualToString:self.accountUIN]) [self.ownProfileController avatarUpdated];
    [self reloadContacts]; if ([uin isEqualToString:self.selectedPeer]) [self updatePeerLabel];
    if ([uin isEqualToString:self.profilePeer]) [self updateProfileCard];
}
- (void)refreshPresenceForPeer:(NSString *)peer force:(BOOL)force {
    if (!JMValidUIN(peer) || !self.client.connected) return;
    if (!force && [self.profileDates[peer] timeIntervalSinceNow]>-30 && self.profileDates[peer]) return;
    self.profileDates[peer]=[NSDate date];
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchPresenceForUIN:peer completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self || error) return;
        for (id value in JMArray(data[@"users"])) {
            NSDictionary *person=JMDictionary(value); if (![JMString(person[@"aimId"]) isEqualToString:peer]) continue;
            NSMutableDictionary *contact=[self.contacts[peer] mutableCopy] ?: [@{@"aimId":peer} mutableCopy];
            for (NSString *key in person) {
                if (person[key]==[NSNull null]) continue;
                if (([key isEqualToString:@"state"] || [key isEqualToString:@"friendly"]) && ![JMString(person[key]) length]) continue;
                contact[key]=person[key];
            }
            NSString *fullName=[[NSString stringWithFormat:@"%@ %@",JMString(person[@"firstName"]),JMString(person[@"lastName"])] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ((!JMString(contact[@"friendly"]).length || [JMString(contact[@"friendly"]) isEqualToString:peer]) && fullName.length) contact[@"friendly"]=fullName;
            self.contacts[peer]=contact;
        }
        [self reloadContacts]; if ([peer isEqualToString:self.selectedPeer]) [self updatePeerLabel];
        if ([peer isEqualToString:self.profilePeer]) [self updateProfileCard];
    }];
}
- (void)createProfileWindow {
    if (self.profileWindow) return;
    self.profileWindow=[[JMPanel alloc] initWithContentRect:NSMakeRect(0,0,430,400) styleMask:NSTitledWindowMask|NSClosableWindowMask|NSUtilityWindowMask backing:NSBackingStoreBuffered defer:NO];
    [self.profileWindow setTitle:JML(@"Профиль — JimmMac")]; [self.profileWindow setReleasedWhenClosed:NO];
    [self.profileWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,430,400)]];
    NSView *root=[self.profileWindow contentView];
    self.profileAvatar=[[NSImageView alloc] initWithFrame:NSMakeRect(24,306,64,64)]; [self.profileAvatar setImageScaling:NSImageScaleProportionallyUpOrDown]; [root addSubview:self.profileAvatar];
    self.profileName=JMLabel(@"",NSMakeRect(104,340,300,27),18,YES); [self.profileName setSelectable:YES]; [root addSubview:self.profileName];
    self.profileDetail=JMLabel(@"",NSMakeRect(105,308,300,25),12,NO); [self.profileDetail setSelectable:YES]; [root addSubview:self.profileDetail];
    self.profileStatus=JMLabel(@"",NSMakeRect(24,246,380,46),12,NO); [[self.profileStatus cell] setWraps:YES]; [self.profileStatus setTextColor:JMSecondaryTextColor()]; [root addSubview:self.profileStatus];
    [root addSubview:JMLabel(JML(@"О себе"),NSMakeRect(24,216,380,21),12,YES)];
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,65,382,147)]; [scroll setHasVerticalScroller:YES]; [scroll setBorderType:NSBezelBorder];
    self.profileAbout=[[NSTextView alloc] initWithFrame:[[scroll contentView] bounds]]; [self.profileAbout setEditable:NO]; [self.profileAbout setRichText:NO];
    [self.profileAbout setVerticallyResizable:YES]; [self.profileAbout setHorizontallyResizable:NO]; [self.profileAbout setMaxSize:NSMakeSize(FLT_MAX,FLT_MAX)];
    [[self.profileAbout textContainer] setContainerSize:NSMakeSize(NSWidth([[scroll contentView] bounds]),FLT_MAX)];
    [self.profileAbout setFont:[NSFont systemFontOfSize:13]]; [self.profileAbout setTextContainerInset:NSMakeSize(8,8)]; [self.profileAbout setAutoresizingMask:NSViewWidthSizable];
    [[self.profileAbout textContainer] setWidthTracksTextView:YES]; [scroll setDocumentView:self.profileAbout]; [root addSubview:scroll];
    self.profileRefresh=JMButton(JML(@"Обновить"),NSMakeRect(294,16,115,30),self,@selector(refreshProfile:)); [root addSubview:self.profileRefresh];
    [self.profileRefresh setToolTip:JML(@"Заново загрузить профиль, статус и фотографию из Jimm.online")];
    [root addSubview:JMButton(JML(@"Закрыть"),NSMakeRect(16,16,105,30),self,@selector(closeProfile:))];
    JMDecorateUtilityWindow(self.profileWindow,JML(@"Профиль контакта")); [self.profileWindow center];
}
- (void)updateProfileCard {
    if (!self.profilePeer) return;
    NSDictionary *person=self.contacts[self.profilePeer] ?: @{@"aimId":self.profilePeer};
    [self.profileName setStringValue:JMName(person)];
    [self.profileName setToolTip:self.profileName.stringValue];
    [self.profileDetail setStringValue:[NSString stringWithFormat:@"UIN %@ · %@",self.profilePeer,JMState(person)]];
    NSString *status=JMString(person[@"statusMsg"]); [self.profileStatus setStringValue:status.length ? status : JML(@"Статус без подписи")];
    [self.profileStatus setToolTip:self.profileStatus.stringValue]; [self.profileDetail setToolTip:self.profileDetail.stringValue];
    [self.profileAvatar setImage:[self.avatars imageForUIN:self.profilePeer] ?: (JMTheme()==JMThemeMac2011 ? JMRetroImage(@"avatar") : nil) ?: [NSImage imageNamed:NSImageNameUser]];
    if (self.profileTexts[self.profilePeer]) [self.profileAbout setString:self.profileTexts[self.profilePeer]];
}
- (void)showProfile:(id)sender {
    if (!self.selectedPeer) return;
    [self createProfileWindow]; self.profilePeer=self.selectedPeer;
    [self.profileAbout setString:self.profileTexts[self.profilePeer] ?: JML(@"Загружаем профиль…")];
    [self updateProfileCard]; [self.profileWindow makeKeyAndOrderFront:nil]; [self refreshProfile:nil];
}
- (void)refreshProfile:(id)sender {
    NSString *peer=self.profilePeer; if (!peer) return;
    if (!self.client.connected) { [self.profileAbout setString:self.profileTexts[peer] ?: JML(@"Нет соединения. Подключитесь и нажмите «Обновить».")]; return; }
    [self.avatars refreshUIN:peer];
    [self refreshPresenceForPeer:peer force:YES]; [self.profileRefresh setEnabled:NO];
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchProfileForUIN:peer completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self) return;
        if (!error) {
            NSString *text=JMString(data[@"profile"]);
            BOOL html=[text rangeOfString:@"<HTML" options:NSCaseInsensitiveSearch].location!=NSNotFound;
            self.profileTexts[peer]=text.length ? JMPlainText(text,html) : JML(@"Пользователь пока ничего не написал о себе.");
        }
        if (![peer isEqualToString:self.profilePeer]) return;
        [self.profileRefresh setEnabled:YES];
        if (error) [self.profileAbout setString:[NSString stringWithFormat:JML(@"Не удалось загрузить профиль.\n%@\nНажмите «Обновить», чтобы повторить."),error.localizedDescription]];
        else [self updateProfileCard];
    }];
}
- (void)closeProfile:(id)sender { [self.profileWindow orderOut:nil]; }
- (void)client:(JMAPIClient *)client receivedOwnInfo:(NSDictionary *)info {
    BOOL changedAvatar=info[@"buddyIcon"] && ![info[@"buddyIcon"] isEqual:self.ownInfo[@"buddyIcon"]];
    [self.ownInfo addEntriesFromDictionary:[info copy]];
    if (changedAvatar) [self.avatars refreshUIN:self.accountUIN];
    [self.ownProfileController updateOwnInfo:self.ownInfo];
    NSString *state=JMString(self.ownInfo[@"state"]);
    if (!self.changingPresence && !self.automaticPresenceRequest && state.length && ![state isEqual:(self.autoAway.automaticallyAway ? @"away" : self.autoAway.manualPresence)]) [self.autoAway manualPresenceChanged:state];
    for (NSMenuItem *item in [self.presencePopup itemArray]) if ([[item representedObject] isEqualToString:state]) { [self.presencePopup selectItem:item]; break; }
    [self updateAccountLabel];
    if (JMTheme()==JMThemeMac2011) { self.brandImage.image=[self.avatars imageForUIN:self.accountUIN] ?: JMRetroImage(@"avatar") ?: [NSImage imageNamed:NSImageNameUser]; self.brandSubtitle.stringValue=JMString(self.ownInfo[@"statusMsg"]).length ? self.ownInfo[@"statusMsg"] : @"Jimm.online"; }
    [self persistRosterCache];
}
- (void)showOwnProfile:(id)sender {
    if (!JMValidUIN(self.accountUIN)) return;
    if (!self.ownProfileController) self.ownProfileController=[[JMOwnProfileController alloc] initWithClient:self.client avatars:self.avatars account:self.accountUIN];
    [self.ownProfileController openWithInfo:self.ownInfo];
}
- (void)changePresence:(id)sender {
    NSString *state=[[self.presencePopup selectedItem] representedObject]; if (!state || (self.changingPresence && !self.automaticPresenceRequest)) return;
    [self.autoAway manualPresenceChanged:state]; self.automaticPresenceRequest=NO; NSUInteger serial=++self.presenceRequestSerial; NSString *account=[self.accountUIN copy];
    self.changingPresence=YES; [self.presenceFeedback setStringValue:JML(@"Меняем статус и проверяем…")]; [self updateSendButton]; __weak JMAppDelegate *weakSelf=self;
    [self.client setPresenceState:state completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self || serial!=self.presenceRequestSerial || (account!=self.accountUIN && ![account isEqual:self.accountUIN])) return;
        self.changingPresence=NO; [self updateSendButton];
        if (error) { [self.presenceFeedback setStringValue:JML(@"Не удалось сменить статус")]; [self client:self.client receivedOwnInfo:self.ownInfo]; [self showError:JML(@"Не удалось сменить статус") detail:error.localizedDescription]; }
        else {
            [self client:self.client receivedOwnInfo:data];
            NSString *verification=JMString(data[@"_presenceVerification"]);
            if ([verification isEqualToString:@"confirmed"]) [self.presenceFeedback setStringValue:JML(@"Статус подтверждён сервером")];
            else if ([verification isEqualToString:@"different"]) [self.presenceFeedback setStringValue:[NSString stringWithFormat:JML(@"Сервер вернул: %@"),JMState(data)]];
            else [self.presenceFeedback setStringValue:JML(@"Статус принят; проверить пока не удалось")];
        }
        [self.presenceFeedback setToolTip:self.presenceFeedback.stringValue];
    }];
}
- (void)client:(JMAPIClient *)client receivedTyping:(NSDictionary *)typing {
    NSString *peer=JMString(typing[@"aimId"]); if (!JMValidUIN(peer)) return;
    BOOL wasTyping=[self.incomingTyping[peer] timeIntervalSinceNow]>0;
    if ([JMString(typing[@"typingStatus"]) isEqualToString:@"typing"]) {
        self.incomingTyping[peer]=[NSDate dateWithTimeIntervalSinceNow:8];
        if (!wasTyping && [peer isEqualToString:self.selectedPeer] && client.connected && ![self.mutedPeers containsObject:peer]) [self.audioAlerts playEvent:@"typing"];
    }
    else [self.incomingTyping removeObjectForKey:peer];
    if ([peer isEqualToString:self.selectedPeer]) [self updateTypingIndicator];
}
- (void)updateTypingIndicator {
    [self.incomingTypingTimer invalidate]; self.incomingTypingTimer=nil;
    NSDate *expiry=self.incomingTyping[self.selectedPeer ?: @""]; NSTimeInterval remaining=[expiry timeIntervalSinceNow];
    NSString *text=@"";
    if (remaining>0 && self.client.connected) {
        text=[NSString stringWithFormat:JML(@"%@ печатает…"),JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer})];
        self.incomingTypingTimer=[NSTimer scheduledTimerWithTimeInterval:remaining+0.1 target:self selector:@selector(typingExpired:) userInfo:nil repeats:NO];
    }
    JMSetLabel(self.typingLabel,text);
}
- (void)typingExpired:(NSTimer *)timer { [self updateTypingIndicator]; }
- (void)typingIdle:(NSTimer *)timer { [self stopOutgoingTyping]; }
- (void)stopOutgoingTyping {
    [self.outgoingTypingTimer invalidate]; self.outgoingTypingTimer=nil;
    if (self.selectedPeer) [self.client setTypingStatus:@"none" forUIN:self.selectedPeer];
}
- (void)reconnect:(id)sender {
    if (self.offlineMode) {
        self.uinField.stringValue=self.accountUIN ?: @""; [self.loginWindow makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
        if ([[self.loginDefaults stringForKey:@"RememberedAccountUIN"] isEqual:self.accountUIN]) [self startAutomaticLogin]; else [self resetLogin:JML(@"Введите пароль для подключения. Локальные черновики сохранены.")];
        return;
    }
    [self stopOutgoingTyping]; [self.incomingTyping removeAllObjects]; [self updateTypingIndicator]; [self.client reconnect];
}
- (NSTimeInterval)systemIdleSeconds { return CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState,kCGAnyInputEventType); }
- (void)autoAwayTick:(id)sender {
    if (self.terminating || self.offlineMode || self.changingPresence || self.autoAwayRetryDate.timeIntervalSinceNow>0) return;
    NSInteger minutes=[self.loginDefaults integerForKey:@"AutoAwayMinutes"]; self.autoAway.interval=minutes>=1 && minutes<=120 ? minutes*60 : 0;
    NSString *state=[self.autoAway requestedPresenceForIdle:[self systemIdleSeconds] connected:self.client.connected]; if (!state) return;
    NSString *account=[self.accountUIN copy]; NSUInteger serial=++self.presenceRequestSerial;
    self.changingPresence=YES; self.automaticPresenceRequest=YES; [self updateSendButton]; __weak JMAppDelegate *weakSelf=self;
    [self.client setPresenceState:state completion:^(NSDictionary *data,NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self || serial!=self.presenceRequestSerial || (account!=self.accountUIN && ![account isEqual:self.accountUIN])) return;
        self.changingPresence=NO;
        BOOL different=[JMString(data[@"_presenceVerification"]) isEqual:@"different"];
        if (different) { [self.autoAway manualPresenceChanged:JMString(data[@"state"])]; [self client:self.client receivedOwnInfo:data]; JMSetLabel(self.presenceFeedback,[NSString stringWithFormat:JML(@"Сервер вернул: %@"),JMState(data)]); }
        else if (error) { [self.autoAway requestFailedForState:state]; self.autoAwayRetryDate=[NSDate dateWithTimeIntervalSinceNow:30]; }
        else { [self client:self.client receivedOwnInfo:data]; JMSetLabel(self.presenceFeedback,self.autoAway.automaticallyAway ? JML(@"Автоматический статус: отошёл") : JML(@"Статус восстановлен после активности")); }
        self.automaticPresenceRequest=NO; [self updateSendButton];
    }];
}
- (void)autoAwaySettingsChanged:(id)sender { [self.loginDefaults setInteger:[self.autoAwayPopup.selectedItem.representedObject integerValue] forKey:@"AutoAwayMinutes"]; self.autoAwayRetryDate=nil; [self autoAwayTick:nil]; }
- (void)workspaceDidWake:(NSNotification *)notification {
    if (![NSThread isMainThread]) { [self performSelectorOnMainThread:@selector(workspaceDidWake:) withObject:nil waitUntilDone:NO]; return; }
    if (self.terminating) return;
    if (self.accountUIN.length && !self.offlineMode) [self reconnect:nil]; [self automaticUpdateTick:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (self.dataOperationInProgress) { self.quitAfterDataOperation=YES; JMSetLabel(self.statusLabel,JML(@"Завершим копирование и закроем приложение…")); return NSTerminateLater; }
    [self flushDrafts]; [self persistRosterCache]; if (![self canLeaveDrafts]) return NSTerminateCancel;
    self.terminating=YES; [self.autoAwayTimer invalidate]; self.autoAwayTimer=nil; self.conversationGeneration++; [self.updateTimer invalidate]; self.updateTimer=nil; [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(automaticUpdateTick:) object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self]; [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [self stopOutgoingTyping]; [self.incomingTypingTimer invalidate]; [self.avatars invalidate]; [self.audioAlerts stop]; [self.notificationAlerts invalidate]; [self.client disconnect];
    // Finish this app's queued credentials and export before exit. Never block
    // the main thread, and don't leave a half-written export on Cmd+Q.
    dispatch_async(self.loginStoreQueue,^{ dispatch_async(self.historySearchQueue,^{ dispatch_async(dispatch_get_main_queue(),^{
        if (self.quitCredentialError.length) [self showError:JML(@"Вход не сохранён") detail:self.quitCredentialError];
        [self completeTermination];
    }); }); });
    return NSTerminateLater;
}
- (void)completeTermination { [NSApp replyToApplicationShouldTerminate:YES]; }
- (BOOL)windowShouldClose:(id)sender {
    if (sender==self.chatWindow || sender==self.rosterWindow) [self flushDrafts];
    // Closing a chat window keeps long polling and sound alerts alive, as on Mac.
    [sender orderOut:nil]; return NO;
}
- (void)showMainWindow:(id)sender {
    if (self.notificationAlerts.accountUIN.length || self.client.connected || self.offlineMode) { [self showSessionWindows]; NSWindow *window=[self listWindow]; if (window.isMiniaturized) [window deminiaturize:nil]; }
    else [self.loginWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self showMainWindow:nil]; return YES;
}
@end
