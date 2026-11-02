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
#import <float.h>

@interface JMWindowView : NSView
@end
@implementation JMWindowView
- (void)drawRect:(NSRect)dirtyRect { [[NSColor windowBackgroundColor] setFill]; NSRectFill(dirtyRect); }
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
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
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
    if ([state isEqualToString:@"online"] || [state isEqualToString:@"freeForChat"]) return @"В сети";
    if ([state isEqualToString:@"away"] || [state isEqualToString:@"na"]) return @"Отошёл";
    if ([state isEqualToString:@"dnd"]) return @"Не беспокоить";
    if ([state isEqualToString:@"occupied"]) return @"Занят";
    if ([state isEqualToString:@"invisible"]) return @"Невидимый";
    return @"Не в сети";
}

@interface JMAppDelegate () <JMAvatarStoreDelegate, NSMenuDelegate, JMNotificationAlertsDelegate>
@property(nonatomic, strong) JMInformationController *aboutController;
@property(nonatomic, strong) JMInformationController *keyboardHelpController;
@property(nonatomic, strong) JMAPIClient *client;
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
@property(nonatomic, copy) NSString *selectedPeer;
@property(nonatomic, copy) NSString *accountUIN;
@property(nonatomic) BOOL sending;
@property(nonatomic) BOOL reloadingContacts;
@property(nonatomic) BOOL showedHistoryError;
@property(nonatomic) BOOL addingContact;
@property(nonatomic, strong) NSDate *sendNotBefore;
@end

@implementation JMAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.client = [[JMAPIClient alloc] init]; self.client.delegate = self;
    self.loginStore=[self makeLoginStore]; self.loginDefaults=[self makeLoginDefaults];
    self.loginStoreQueue=dispatch_queue_create("online.jimm.login-keychain",DISPATCH_QUEUE_SERIAL);
    self.audioAlerts=[self makeAudioAlerts]; self.notificationAlerts=[self makeNotificationAlerts]; self.notificationAlerts.delegate=self;
    self.chatPreferences=[[JMChatPreferences alloc] initWithDefaults:nil];
    self.historySearchQueue=dispatch_queue_create("online.jimm.history-search",DISPATCH_QUEUE_SERIAL);
    self.draftSaveQueue=dispatch_queue_create("online.jimm.drafts",DISPATCH_QUEUE_SERIAL);
    self.contacts = [NSMutableDictionary dictionary]; self.drafts = [NSMutableDictionary dictionary]; self.unread = [NSMutableDictionary dictionary];
    self.serverContactIDs = [NSMutableSet set]; self.conversationPeers = [NSMutableSet set];
    self.serverGroups=[NSMutableArray array];
    self.ownInfo=[NSMutableDictionary dictionary]; self.profileDates=[NSMutableDictionary dictionary]; self.profileTexts=[NSMutableDictionary dictionary]; self.incomingTyping=[NSMutableDictionary dictionary];
    if (JMFlowerImage()) [NSApp setApplicationIconImage:JMFlowerImage()];
    [self createMenu]; [self createLoginWindow]; [self createChatWindow];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
    [self.loginWindow center]; [self.loginWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    NSUserNotification *launchNotification=notification.userInfo[NSApplicationLaunchUserNotificationKey];
    if ([launchNotification isKindOfClass:[NSUserNotification class]]) [self.notificationAlerts handleActivation:launchNotification];
    [self startAutomaticLogin];
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
    [appMenu addItemWithTitle:@"О JimmMac" action:@selector(about:) keyEquivalent:@""];
    NSMenuItem *preferences=[appMenu addItemWithTitle:@"Настройки…" action:@selector(showPreferences:) keyEquivalent:@","]; preferences.target=self;
    NSMenuItem *myProfile=[appMenu addItemWithTitle:@"Мой профиль…" action:@selector(showOwnProfile:) keyEquivalent:@"i"]; myProfile.target=self;
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *logout = [appMenu addItemWithTitle:@"Выйти из аккаунта" action:@selector(logout:) keyEquivalent:@"L"]; [logout setTarget:self]; logout.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Скрыть JimmMac" action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers=[appMenu addItemWithTitle:@"Скрыть остальные" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask];
    [appMenu addItemWithTitle:@"Показать все" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Завершить JimmMac" action:@selector(terminate:) keyEquivalent:@"q"];
    [appItem setSubmenu:appMenu]; [bar addItem:appItem];
    NSMenuItem *fileItem=[[NSMenuItem alloc] initWithTitle:@"Файл" action:NULL keyEquivalent:@""];
    NSMenu *file=[[NSMenu alloc] initWithTitle:@"Файл"];
    NSMenuItem *write=[file addItemWithTitle:@"Написать по UIN…" action:@selector(openConversation:) keyEquivalent:@"n"]; write.target=self;
    NSMenuItem *add=[file addItemWithTitle:@"Добавить контакт…" action:@selector(addContact:) keyEquivalent:@"N"]; add.target=self; add.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    fileItem.submenu=file; [bar addItem:fileItem];
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Правка" action:NULL keyEquivalent:@""];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Правка"];
    [edit addItemWithTitle:@"Отменить" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo=[edit addItemWithTitle:@"Повторить" action:@selector(redo:) keyEquivalent:@"Z"]; redo.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask;
    [edit addItem:[NSMenuItem separatorItem]];
    [edit addItemWithTitle:@"Вырезать" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Копировать" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Вставить" action:@selector(paste:) keyEquivalent:@"v"];
    NSMenuItem *plain=[edit addItemWithTitle:@"Вставить без оформления" action:@selector(pasteAsPlainText:) keyEquivalent:@"V"]; plain.keyEquivalentModifierMask=NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask;
    [edit addItemWithTitle:@"Выбрать всё" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenuItem *sendMessage=[edit addItemWithTitle:@"Отправить сообщение" action:@selector(send:) keyEquivalent:@"\r"]; sendMessage.target=self;
    [edit addItem:[NSMenuItem separatorItem]];
    NSMenuItem *find=[edit addItemWithTitle:@"Найти в истории…" action:@selector(showHistorySearch:) keyEquivalent:@"f"]; find.target=self;
    NSMenuItem *readAll=[edit addItemWithTitle:@"Пометить всё прочитанным" action:@selector(markAllRead:) keyEquivalent:@""]; readAll.target=self;
    [editItem setSubmenu:edit]; [bar addItem:editItem];
    NSMenuItem *viewItem=[[NSMenuItem alloc] initWithTitle:@"Вид" action:NULL keyEquivalent:@""];
    NSMenu *viewMenu=[[NSMenu alloc] initWithTitle:@"Вид"];
    NSMenuItem *contactTab=[viewMenu addItemWithTitle:@"Контакты" action:@selector(showContactsSection:) keyEquivalent:@"1"]; contactTab.target=self;
    NSMenuItem *chatTab=[viewMenu addItemWithTitle:@"Переписки" action:@selector(showConversationsSection:) keyEquivalent:@"2"]; chatTab.target=self;
    [viewMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *filter=[viewMenu addItemWithTitle:@"Поиск в списке" action:@selector(focusContactSearch:) keyEquivalent:@"l"]; filter.target=self;
    viewItem.submenu=viewMenu; [bar addItem:viewItem];
    NSMenuItem *contactsItem=[[NSMenuItem alloc] initWithTitle:@"Контакты" action:NULL keyEquivalent:@""];
    NSMenu *contactsMenu=[[NSMenu alloc] initWithTitle:@"Контакты"];
    for (NSDictionary *entry in @[@{@"title":@"Добавить по UIN…",@"action":@"addContact:"},@{@"title":@"Переименовать контакт…",@"action":@"renameContact:"},@{@"title":@"Переместить в группу…",@"action":@"moveContact:"},@{@"title":@"Удалить из контактов…",@"action":@"removeContact:"}]) {
        NSMenuItem *item=[contactsMenu addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    [contactsMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *groups=[contactsMenu addItemWithTitle:@"Управление группами…" action:@selector(showGroups:) keyEquivalent:@""]; groups.target=self;
    [contactsItem setSubmenu:contactsMenu]; [bar addItem:contactsItem];
    NSMenuItem *soundsItem=[[NSMenuItem alloc] initWithTitle:@"Звуки" action:NULL keyEquivalent:@""];
    NSMenu *sounds=[[NSMenu alloc] initWithTitle:@"Звуки"];
    for (NSDictionary *item in @[@{@"title":@"Звуковые оповещения",@"key":@"enabled"},@{@"title":@"Появление и выход контактов",@"key":@"presenceEnabled"},@{@"title":@"Набор текста",@"key":@"typingEnabled"}]) {
        NSMenuItem *option=[sounds addItemWithTitle:item[@"title"] action:@selector(toggleSoundOption:) keyEquivalent:@""];
        option.target=self; option.representedObject=item[@"key"];
    }
    [sounds addItem:[NSMenuItem separatorItem]];
    NSArray *events=@[@"message",@"online",@"offline",@"typing"];
    NSArray *titles=@[@"Прослушать: сообщение",@"Прослушать: в сети",@"Прослушать: отключился",@"Прослушать: печатает"];
    for (NSUInteger i=0;i<events.count;i++) {
        NSMenuItem *sample=[sounds addItemWithTitle:titles[i] action:@selector(previewSound:) keyEquivalent:@""];
        sample.target=self; sample.representedObject=events[i];
    }
    [soundsItem setSubmenu:sounds]; [bar addItem:soundsItem];
    NSMenuItem *windowItem=[[NSMenuItem alloc] initWithTitle:@"Окно" action:NULL keyEquivalent:@""];
    NSMenu *windowMenu=[[NSMenu alloc] initWithTitle:@"Окно"];
    [windowMenu addItemWithTitle:@"Свернуть" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Закрыть окно" action:@selector(performClose:) keyEquivalent:@"w"];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *show=[windowMenu addItemWithTitle:@"Открыть JimmMac" action:@selector(showMainWindow:) keyEquivalent:@"0"]; show.target=self;
    [windowItem setSubmenu:windowMenu]; [bar addItem:windowItem];
    [NSApp setWindowsMenu:windowMenu];
    NSMenuItem *helpItem=[[NSMenuItem alloc] initWithTitle:@"Справка" action:NULL keyEquivalent:@""];
    NSMenu *help=[[NSMenu alloc] initWithTitle:@"Справка"];
    for (NSDictionary *entry in @[@{@"title":@"Сочетания клавиш…",@"action":@"showKeyboardHelp:"},@{@"title":@"Jimm.online — сайт и регистрация…",@"action":@"openSite:"},@{@"title":@"Telegraphica для Mac…",@"action":@"openTelegraphica:"}]) {
        NSMenuItem *item=[help addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    helpItem.submenu=help; [bar addItem:helpItem]; [NSApp setHelpMenu:help];
    [NSApp setMainMenu:bar];
}
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
    [self.chatWindow makeKeyAndOrderFront:nil]; [self.chatWindow makeFirstResponder:self.contactTable];
}
- (void)focusContactSearch:(id)sender {
    if (!self.history) return;
    [self.chatWindow makeKeyAndOrderFront:nil]; [self.chatWindow makeFirstResponder:self.searchField]; [self.searchField selectText:nil];
}
- (void)activateContactSelection:(id)sender {
    NSInteger row=self.contactTable.selectedRow;
    if (row>=0 && row<(NSInteger)self.visibleContacts.count) [self selectPeer:self.visibleContacts[(NSUInteger)row][@"aimId"]];
}
- (void)handleEscapeInWindow:(NSWindow *)window {
    if (window==self.loginWindow) { if (self.loginPending) [self cancelLogin:nil]; return; }
    if (window==self.chatWindow) {
        if (window.firstResponder==self.searchField.currentEditor && self.searchField.stringValue.length) {
            self.searchField.stringValue=@""; [self reloadContacts];
        } else [window makeFirstResponder:self.contactTable];
    } else if (window==self.historyWindow) [self closeHistorySearch:nil];
    else [window performClose:nil];
}
- (void)createLoginWindow {
    self.loginWindow = [[JMWindow alloc] initWithContentRect:NSMakeRect(0, 0, 440, 430)
        styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask backing:NSBackingStoreBuffered defer:NO];
    [self.loginWindow setTitle:@"JimmMac — вход"]; [self.loginWindow setReleasedWhenClosed:NO]; [self.loginWindow setDelegate:self];
    [self.loginWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,440,430)]];
    NSView *view = [self.loginWindow contentView];
    JMChromeView *banner=[[JMChromeView alloc] initWithFrame:NSMakeRect(0,258,440,172)];
    banner.topColor=JMLegacyHeaderTopColor(); banner.bottomColor=JMLegacyHeaderBottomColor(); [view addSubview:banner];
    NSImageView *flower = [[NSImageView alloc] initWithFrame:NSMakeRect(182,334,76,76)];
    [flower setImage:JMFlowerImage()]; [flower setImageScaling:NSImageScaleProportionallyUpOrDown]; [view addSubview:flower];
    NSTextField *title = JMLabel(@"JimmMac",NSMakeRect(30,296,380,31),24,YES); [title setAlignment:NSCenterTextAlignment]; [view addSubview:title];
    NSTextField *subtitle = JMLabel(@"Ваша аська на Mac · Jimm.online",NSMakeRect(30,268,380,22),12,NO);
    [subtitle setAlignment:NSCenterTextAlignment]; [subtitle setTextColor:JMSecondaryTextColor()]; [view addSubview:subtitle];
    [view addSubview:JMLabel(@"UIN",NSMakeRect(35,222,76,22),13,NO)];
    self.uinField = [[NSTextField alloc] initWithFrame:NSMakeRect(119,220,285,25)];
    [self.uinField setToolTip:@"Ваш числовой UIN, зарегистрированный в Jimm.online"];
    self.uinField.delegate=self;
    NSString *lastUIN = [self.loginDefaults stringForKey:@"LastUIN"];
    if (JMValidUIN(lastUIN)) [self.uinField setStringValue:lastUIN]; [view addSubview:self.uinField];
    [view addSubview:JMLabel(@"Пароль",NSMakeRect(35,178,76,22),13,NO)];
    self.passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(119,176,285,25)];
    [self.passwordField setToolTip:@"Пароль ICQ-аккаунта Jimm.online. Пароль не сохраняется; для автовхода используется токен в Связке ключей."];
    [self.passwordField setTarget:self]; [self.passwordField setAction:@selector(login:)]; [view addSubview:self.passwordField];
    self.rememberLoginCheckbox=JMCheckbox(@"Запомнить меня",NSMakeRect(119,143,285,22),self,@selector(rememberLoginChanged:));
    self.rememberLoginCheckbox.state=NSOnState; self.rememberLoginCheckbox.toolTip=@"Сохранить токен в системной Связке ключей и автоматически входить при запуске. Пароль не сохраняется."; [view addSubview:self.rememberLoginCheckbox];
    self.cancelLoginButton=JMButton(@"Отмена",NSMakeRect(113,99,149,32),self,@selector(cancelLogin:)); self.cancelLoginButton.hidden=YES; self.cancelLoginButton.keyEquivalent=@"\e"; [view addSubview:self.cancelLoginButton];
    self.loginButton = JMButton(@"Войти",NSMakeRect(274,99,136,32),self,@selector(login:));
    [self.loginButton setKeyEquivalent:@"\r"]; [view addSubview:self.loginButton];
    self.loginStatus = JMLabel(@"Введите UIN и пароль от Jimm.online.",NSMakeRect(35,42,370,48),12,NO);
    [[self.loginStatus cell] setWraps:YES]; [view addSubview:self.loginStatus];
    [view addSubview:JMButton(@"Открыть Jimm.online",NSMakeRect(27,5,183,29),self,@selector(openSite:))];
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
    JMChromeView *toolbar = [[JMChromeView alloc] initWithFrame:NSMakeRect(0,584,1000,66)];
    self.toolbar=toolbar; toolbar.topColor=JMLegacyHeaderTopColor(); toolbar.bottomColor=JMLegacyHeaderBottomColor();
    [toolbar setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin]; [root addSubview:toolbar];
    NSImageView *flower = [[NSImageView alloc] initWithFrame:NSMakeRect(17,15,36,36)];
    [flower setImage:JMFlowerImage()]; [flower setImageScaling:NSImageScaleProportionallyUpOrDown]; [toolbar addSubview:flower];
    [toolbar addSubview:JMLabel(@"JimmMac",NSMakeRect(65,31,200,25),18,YES)];
    NSTextField *subtitle = JMLabel(@"ICQ · Jimm.online",NSMakeRect(66,13,200,18),11,NO); [subtitle setTextColor:JMSecondaryTextColor()]; [toolbar addSubview:subtitle];
    self.accountLabel = JMLabel(@"Учётная запись",NSMakeRect(400,36,570,21),12,NO);
    [self.accountLabel setAlignment:NSRightTextAlignment]; [self.accountLabel setAutoresizingMask:NSViewMinXMargin]; [toolbar addSubview:self.accountLabel];
    self.presencePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(802,5,176,29) pullsDown:NO];
    NSArray *states=@[@"online",@"away",@"dnd",@"occupied",@"invisible"];
    NSArray *titles=@[@"В сети",@"Отошёл",@"Не беспокоить",@"Занят",@"Невидимый"];
    for (NSUInteger i=0;i<states.count;i++) { [self.presencePopup addItemWithTitle:titles[i]]; [[self.presencePopup lastItem] setRepresentedObject:states[i]]; [[self.presencePopup lastItem] setImage:JMStatusImage(states[i])]; }
    [self.presencePopup setToolTip:@"Ваш статус в сети. После изменения клиент проверит его на сервере."];
    [self.presencePopup setAutoresizingMask:NSViewMinXMargin]; [self.presencePopup setTarget:self]; [self.presencePopup setAction:@selector(changePresence:)]; [toolbar addSubview:self.presencePopup];
    self.presenceFeedback=JMLabel(@"",NSMakeRect(400,11,392,18),11,NO);
    [self.presenceFeedback setTextColor:JMSecondaryTextColor()]; [self.presenceFeedback setAlignment:NSRightTextAlignment];
    [self.presenceFeedback setAutoresizingMask:NSViewMinXMargin]; [toolbar addSubview:self.presenceFeedback];
    self.reconnectButton=JMButton(@"Подключиться",NSMakeRect(666,5,130,29),self,@selector(reconnect:));
    [self.reconnectButton setToolTip:@"Повторно подключиться к Jimm.online. Черновик сохранится."];
    [self.reconnectButton setAutoresizingMask:NSViewMinXMargin]; [toolbar addSubview:self.reconnectButton];
    JMChromeView *sidebar = [[JMChromeView alloc] initWithFrame:NSMakeRect(0,26,268,558)];
    self.sidebar=sidebar;
    sidebar.topColor = [NSColor colorWithCalibratedWhite:0.94 alpha:1];
    sidebar.bottomColor = sidebar.topColor;
    [sidebar setAutoresizingMask:NSViewHeightSizable]; [root addSubview:sidebar];
    self.sectionControl = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(12,518,244,28)];
    [self.sectionControl setSegmentCount:2]; [self.sectionControl setLabel:@"Контакты" forSegment:0];
    [self.sectionControl setLabel:@"Переписки" forSegment:1];
    [self.sectionControl setSegmentStyle:NSSegmentStyleRounded]; [self.sectionControl setFont:[NSFont systemFontOfSize:13]];
    [self.sectionControl setWidth:116 forSegment:0]; [self.sectionControl setWidth:116 forSegment:1];
    // Let Mavericks include the bezel and cap insets instead of clipping them
    // with a hand-picked frame smaller than the native control's drawing size.
    [self.sectionControl sizeToFit];
    [[self.sectionControl cell] setToolTip:@"Контакты, сохранённые в Jimm.online" forSegment:0];
    [[self.sectionControl cell] setToolTip:@"Открытые разговоры и история сообщений" forSegment:1];
    [[self.sectionControl cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne]; [self.sectionControl setSelectedSegment:0];
    [self.sectionControl setTarget:self]; [self.sectionControl setAction:@selector(changeSection:)];
    [self.sectionControl setAutoresizingMask:NSViewMinYMargin]; [sidebar addSubview:self.sectionControl];
    self.searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(12,480,244,25)];
    [[self.searchField cell] setPlaceholderString:@"Поиск контактов"]; [(NSTextField *)self.searchField setDelegate:self];
    [self.searchField setToolTip:@"Поиск по имени или UIN в выбранном разделе"];
    [self.searchField setAutoresizingMask:NSViewMinYMargin]; [sidebar addSubview:self.searchField];
    self.groupFilter=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(12,442,244,29) pullsDown:NO];
    self.groupFilter.target=self; self.groupFilter.action=@selector(groupFilterChanged:); [self.groupFilter setAutoenablesItems:NO];
    [self.groupFilter setToolTip:@"Показать все контакты или выбранную группу. Здесь же доступно управление группами."]; [sidebar addSubview:self.groupFilter];
    NSScrollView *list = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,85,268,385)];
    [list setAutoresizingMask:NSViewHeightSizable]; [list setHasVerticalScroller:YES]; [list setBorderType:NSNoBorder];
    self.contactTable = [[JMContactTable alloc] initWithFrame:[list bounds]];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"contact"]; [column setWidth:252]; [column setResizingMask:NSTableColumnAutoresizingMask];
    [self.contactTable addTableColumn:column]; [self.contactTable setHeaderView:nil]; [self.contactTable setRowHeight:60];
    [self.contactTable setBackgroundColor:sidebar.topColor]; [self.contactTable setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
    [self.contactTable setIntercellSpacing:NSMakeSize(0,0)];
    self.contactTable.target=self; self.contactTable.doubleAction=@selector(activateContactSelection:);
    [(JMContactTable *)self.contactTable setActivateAction:@selector(activateContactSelection:)];
    self.contactTable.toolTip=@"↑/↓ — выбрать собеседника; Enter — перейти к сообщению. Правый щелчок — действия с контактом.";
    [self.contactTable setDataSource:self]; [self.contactTable setDelegate:self];
    [self.contactTable setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    [self.contactTable setAllowsEmptySelection:YES]; [list setDocumentView:self.contactTable]; [sidebar addSubview:list];
    self.contactMenu=[[NSMenu alloc] initWithTitle:@"Контакт"]; self.contactMenu.delegate=self;
    for (NSDictionary *entry in @[@{@"title":@"Открыть переписку",@"action":@"writeContact:"},@{@"title":@"Профиль",@"action":@"profileContact:"},@{@"title":@"Переименовать…",@"action":@"renameContact:"},@{@"title":@"Переместить в группу…",@"action":@"moveContact:"},@{@"title":@"Удалить из контактов…",@"action":@"removeContact:"}]) {
        NSMenuItem *item=[self.contactMenu addItemWithTitle:entry[@"title"] action:NSSelectorFromString(entry[@"action"]) keyEquivalent:@""]; item.target=self;
    }
    [self.contactTable setMenu:self.contactMenu];
    self.emptyListLabel = JMLabel(@"",NSMakeRect(20,245,228,100),12,NO); [[self.emptyListLabel cell] setWraps:YES];
    [self.emptyListLabel setAlignment:NSCenterTextAlignment]; [self.emptyListLabel setTextColor:JMSecondaryTextColor()];
    [self.emptyListLabel setAutoresizingMask:NSViewMinYMargin|NSViewMaxYMargin]; [sidebar addSubview:self.emptyListLabel];
    self.countLabel = JMLabel(@"Контактов: 0",NSMakeRect(13,63,240,19),11,NO); [self.countLabel setTextColor:JMSecondaryTextColor()]; [sidebar addSubview:self.countLabel];
    self.contactNotice = JMLabel(@"",NSMakeRect(13,33,241,27),11,NO); [[self.contactNotice cell] setWraps:YES]; [sidebar addSubview:self.contactNotice];
    self.addContactButton = JMButton(@"Добавить…",NSMakeRect(6,3,112,29),self,@selector(addContact:)); [sidebar addSubview:self.addContactButton];
    [self.addContactButton setToolTip:@"Добавить UIN в контакт-лист на сервере Jimm.online"];
    NSButton *write=JMButton(@"Написать…",NSMakeRect(126,3,132,29),self,@selector(openConversation:));
    [write setToolTip:@"Открыть разговор по UIN, не добавляя его в контакты"]; [sidebar addSubview:write];
    NSView *chat = [[NSView alloc] initWithFrame:NSMakeRect(280,26,708,558)];
    self.chatPane=chat;
    [chat setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable]; [root addSubview:chat];
    self.peerAvatar=[[NSImageView alloc] initWithFrame:NSMakeRect(6,500,44,44)];
    [self.peerAvatar setImageScaling:NSImageScaleProportionallyUpOrDown]; [self.peerAvatar setImage:[NSImage imageNamed:NSImageNameUser]];
    [self.peerAvatar setAutoresizingMask:NSViewMinYMargin]; [chat addSubview:self.peerAvatar];
    self.peerLabel = JMLabel(@"Выберите собеседника",NSMakeRect(63,522,395,24),16,YES);
    [self.peerLabel setAutoresizingMask:NSViewMinYMargin|NSViewWidthSizable]; [chat addSubview:self.peerLabel];
    self.peerDetail = JMLabel(@"Контакты и переписки в отдельных разделах",NSMakeRect(64,498,395,19),11,NO);
    [self.peerDetail setTextColor:JMSecondaryTextColor()]; [self.peerDetail setAutoresizingMask:NSViewMinYMargin|NSViewWidthSizable]; [chat addSubview:self.peerDetail];
    self.addPeerButton = JMButton(@"Добавить в контакты",NSMakeRect(444,516,173,29),self,@selector(addSelectedPeer:));
    [self.addPeerButton setToolTip:@"Сохранить этого собеседника в контакт-листе Jimm.online"];
    [self.addPeerButton setAutoresizingMask:NSViewMinXMargin|NSViewMinYMargin]; [self.addPeerButton setHidden:YES]; [chat addSubview:self.addPeerButton];
    NSButton *profile=JMButton(@"Профиль",NSMakeRect(624,516,83,29),self,@selector(showProfile:));
    self.profileButton=profile; [profile setEnabled:NO]; [profile setToolTip:@"Открыть сведения о собеседнике и его фотографию"];
    [profile setAutoresizingMask:NSViewMinXMargin|NSViewMinYMargin]; [chat addSubview:profile];
    self.historySearchButton=JMButton(@"Найти…",NSMakeRect(520,516,96,29),self,@selector(showHistorySearch:));
    [self.historySearchButton setToolTip:@"Поиск по локальной истории сообщений (Cmd+F)"]; [chat addSubview:self.historySearchButton];
    NSScrollView *log = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,149,708,341)];
    [log setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable]; [log setHasVerticalScroller:YES]; [log setBorderType:NSNoBorder];
    self.transcript = [[NSTextView alloc] initWithFrame:[[log contentView] bounds]];
    [self.transcript setEditable:NO]; [self.transcript setSelectable:YES]; [self.transcript setRichText:YES]; [self.transcript setDelegate:self];
    [self.transcript setLinkTextAttributes:@{NSForegroundColorAttributeName:[NSColor colorWithCalibratedRed:0.08 green:0.29 blue:0.62 alpha:1],NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle),NSCursorAttributeName:[NSCursor pointingHandCursor]}];
    [self.transcript setTextContainerInset:NSMakeSize(18,16)]; [self.transcript setAutoresizingMask:NSViewWidthSizable]; [self.transcript setVerticallyResizable:YES];
    [self.transcript setHorizontallyResizable:NO]; [self.transcript setMaxSize:NSMakeSize(FLT_MAX,FLT_MAX)];
    [[self.transcript textContainer] setContainerSize:NSMakeSize(NSWidth([[log contentView] bounds]),FLT_MAX)];
    [[self.transcript textContainer] setWidthTracksTextView:YES]; [log setDocumentView:self.transcript]; [chat addSubview:log];
    self.conversationEmptyView=[[JMConversationEmptyView alloc] initWithFrame:log.frame];
    self.conversationEmptyView.writeButton.target=self; self.conversationEmptyView.writeButton.action=@selector(openConversation:); [chat addSubview:self.conversationEmptyView];
    [[log contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationDidScroll:) name:NSViewBoundsDidChangeNotification object:[log contentView]];
    self.typingLabel=JMLabel(@"",NSMakeRect(5,126,690,18),11,NO); [self.typingLabel setTextColor:JMSecondaryTextColor()];
    [self.typingLabel setAutoresizingMask:NSViewWidthSizable]; [chat addSubview:self.typingLabel];
    self.latestMessagesButton=JMButton(@"Новые сообщения ↓",NSMakeRect(528,122,180,26),self,@selector(jumpToLatest:));
    self.latestMessagesButton.toolTip=@"Перейти к последним сообщениям и отметить открытую переписку прочитанной"; self.latestMessagesButton.hidden=YES; [chat addSubview:self.latestMessagesButton];
    NSScrollView *input = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,40,708,80)];
    [input setAutoresizingMask:NSViewWidthSizable]; [input setHasVerticalScroller:YES]; [input setBorderType:NSBezelBorder];
    self.composer = [[JMComposerView alloc] initWithFrame:[[input contentView] bounds]];
    [(JMComposerView *)self.composer setPlaceholder:@"Сообщение…"];
    [self.composer setFont:self.chatPreferences.messageFont]; [self.composer setRichText:NO]; [self.composer setAllowsUndo:YES]; [self.composer setTextContainerInset:NSMakeSize(8,7)];
    [self.composer setDelegate:self]; [self.composer setAutoresizingMask:NSViewWidthSizable]; [[self.composer textContainer] setWidthTracksTextView:YES];
    [self.composer setVerticallyResizable:YES]; [self.composer setHorizontallyResizable:NO]; [self.composer setMaxSize:NSMakeSize(FLT_MAX,FLT_MAX)];
    [[self.composer textContainer] setContainerSize:NSMakeSize(NSWidth([[input contentView] bounds]),FLT_MAX)];
    [self.composer setToolTip:@"Введите сообщение. Enter — отправить, Shift+Enter — новая строка."];
    [input setDocumentView:self.composer]; [chat addSubview:input];
    self.sendButton = JMButton(@"Отправить",NSMakeRect(576,2,134,30),self,@selector(send:));
    [self.sendButton setToolTip:@"Отправить сообщение выбранному собеседнику (Enter)"];
    [self.sendButton setAutoresizingMask:NSViewMinXMargin]; [chat addSubview:self.sendButton];
    self.composerHint = JMLabel(@"Выберите контакт или нажмите «Написать…»",NSMakeRect(4,7,555,19),11,NO);
    [self.composerHint setTextColor:JMSecondaryTextColor()]; [self.composerHint setAutoresizingMask:NSViewWidthSizable]; [chat addSubview:self.composerHint];
    self.statusLabel = JMLabel(@"Не подключено",NSMakeRect(12,3,820,20),11,NO);
    [self.statusLabel setAutoresizingMask:NSViewWidthSizable]; [root addSubview:self.statusLabel];
    NSButton *logout = JMButton(@"Выйти",NSMakeRect(900,0,91,26),self,@selector(logout:));
    self.logoutButton=logout; [logout setToolTip:@"Выйти из аккаунта и отключиться от Jimm.online"];
    [logout setAutoresizingMask:NSViewMinXMargin]; [root addSubview:logout];
    self.soundButton=JMButton(@"",NSMakeRect(766,3,126,30),self,@selector(toggleSounds:)); [root addSubview:self.soundButton];
    // Include every control in the loop. AppKit skips hidden/disabled controls
    // and follows the user's Full Keyboard Access preference for buttons.
    NSArray *keyViews=@[self.presencePopup,self.sectionControl,self.searchField,self.groupFilter,self.contactTable,
        self.addContactButton,write,self.historySearchButton,self.profileButton,self.addPeerButton,
        self.conversationEmptyView.writeButton,self.transcript,self.latestMessagesButton,self.composer,
        self.sendButton,self.soundButton,self.logoutButton,self.reconnectButton];
    for (NSUInteger i=0;i<keyViews.count;i++) [keyViews[i] setNextKeyView:keyViews[(i+1)%keyViews.count]];
    self.chatWindow.autorecalculatesKeyViewLoop=NO;
    self.chatWindow.initialFirstResponder=self.searchField;
    [self refreshGroupChoices]; [self updateSoundControls]; [self updatePeerLabel]; [self layoutChatWindow]; [self updateSendButton]; [self reloadContacts];
}
- (void)layoutChatWindow {
    CGFloat width=NSWidth([[self.chatWindow contentView] bounds]), height=NSHeight([[self.chatWindow contentView] bounds]);
    self.toolbar.frame=NSMakeRect(0,height-66,width,66);
    self.sidebar.frame=NSMakeRect(0,36,268,height-102);
    self.chatPane.frame=NSMakeRect(280,36,width-292,height-102);
    BOOL showGroups=self.sectionControl.selectedSegment==0;
    self.groupFilter.hidden=!showGroups; self.groupFilter.frame=NSMakeRect(12,NSHeight(self.sidebar.bounds)-116,244,29);
    BOOL notice=self.contactNotice.stringValue.length>0;
    CGFloat footer=notice ? 94 : 62, listHeight=NSHeight(self.sidebar.bounds)-(showGroups ? 127 : 88)-footer;
    self.contactTable.enclosingScrollView.frame=NSMakeRect(0,footer,268,MAX(100,listHeight));
    self.emptyListLabel.frame=NSMakeRect(20,footer+(MAX(100,listHeight)-100)/2,228,100);
    self.countLabel.frame=NSMakeRect(12,footer-23,244,18); self.contactNotice.frame=NSMakeRect(12,34,244,32); self.contactNotice.hidden=!notice;
    NSSize tabs=self.sectionControl.frame.size;
    [self.sectionControl setFrameOrigin:NSMakePoint(floor((268-tabs.width)/2),NSHeight(self.sidebar.bounds)-12-tabs.height)];
    self.accountLabel.frame=NSMakeRect(280,36,width-302,21);
    self.presencePopup.frame=NSMakeRect(width-192,5,176,29);
    self.presenceFeedback.frame=NSMakeRect(280,11,width-482,18);
    self.reconnectButton.frame=NSMakeRect(width-328,5,130,29);
    self.statusLabel.frame=NSMakeRect(12,8,width-260,20);
    self.soundButton.frame=NSMakeRect(width-238,3,132,30);
    self.logoutButton.frame=NSMakeRect(width-102,3,94,30);
    CGFloat chatWidth=NSWidth(self.chatPane.bounds), chatHeight=NSHeight(self.chatPane.bounds);
    self.peerAvatar.frame=NSMakeRect(8,chatHeight-61,44,44);
    BOOL hasPeer=self.selectedPeer.length>0;
    self.peerLabel.frame=NSMakeRect(hasPeer ? 64 : 16,chatHeight-35,hasPeer ? chatWidth-270 : chatWidth-32,24);
    self.peerDetail.frame=NSMakeRect(hasPeer ? 64 : 16,chatHeight-60,hasPeer ? chatWidth-74-([self.addPeerButton isHidden] ? 0 : 180) : chatWidth-32,19);
    self.profileButton.frame=NSMakeRect(chatWidth-90,chatHeight-42,90,32);
    self.historySearchButton.frame=NSMakeRect(chatWidth-196,chatHeight-42,100,32);
    self.addPeerButton.frame=NSMakeRect(chatWidth-181,chatHeight-72,181,30);
    self.transcript.enclosingScrollView.frame=NSMakeRect(0,149,chatWidth,chatHeight-233);
    self.conversationEmptyView.frame=self.transcript.enclosingScrollView.frame;
    self.composerHint.frame=NSMakeRect(4,7,chatWidth-156,19);
    self.latestMessagesButton.frame=NSMakeRect(chatWidth-180,122,180,26);
    self.typingLabel.frame=NSMakeRect(5,126,chatWidth-(self.latestMessagesButton.isHidden ? 12 : 190),18);
}
- (void)windowDidResize:(NSNotification *)notification { if (notification.object==self.chatWindow) [self layoutChatWindow]; }
- (BOOL)canChangeRoster { return self.client.connected && !self.changingRoster && !self.addingContact; }
- (NSString *)contactForAction:(id)sender {
    if ([sender isKindOfClass:[NSMenuItem class]] && [sender representedObject]==[NSNull null]) return @"";
    if ([sender isKindOfClass:[NSMenuItem class]] && JMValidUIN(JMString([sender representedObject]))) return [sender representedObject];
    return self.selectedPeer ?: @"";
}
- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu!=self.contactMenu) return;
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
    [self.profileAbout setString:self.profileTexts[peer] ?: @"Загружаем профиль…"];
    [self updateProfileCard]; [self.profileWindow makeKeyAndOrderFront:nil]; [self refreshProfile:nil];
}
- (NSUInteger)contactsInGroup:(NSString *)group {
    NSUInteger count=0; for (NSString *peer in self.serverContactIDs) if ([JMArray(self.contacts[peer][@"groups"]) containsObject:group]) count++;
    return count;
}
- (void)refreshGroupChoices {
    NSArray *names=[self.serverGroups sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (self.selectedGroup && ![names containsObject:self.selectedGroup]) self.selectedGroup=nil;
    [self.groupFilter removeAllItems]; [self.groupFilter addItemWithTitle:@"Все группы"];
    for (NSString *name in names) { [self.groupFilter addItemWithTitle:name]; self.groupFilter.lastItem.representedObject=name; }
    [[self.groupFilter menu] addItem:[NSMenuItem separatorItem]];
    [self.groupFilter addItemWithTitle:@"Управление группами…"]; self.groupFilter.lastItem.tag=10001;
    [self.groupFilter selectItemAtIndex:0];
    for (NSMenuItem *item in self.groupFilter.itemArray) if ([item.representedObject isEqual:self.selectedGroup]) [self.groupFilter selectItem:item];
    self.groupFilter.toolTip=self.selectedGroup.length ? [NSString stringWithFormat:@"Группа: %@\nВыберите «Все группы», чтобы увидеть весь контакт-лист.",self.selectedGroup] : @"Все группы контактов. Здесь же доступно управление группами.";
    [self updateGroupWindow];
}
- (void)groupFilterChanged:(id)sender {
    if (self.groupFilter.selectedItem.tag==10001) { [self refreshGroupChoices]; [self showGroups:nil]; return; }
    self.selectedGroup=self.groupFilter.selectedItem.representedObject; [self refreshGroupChoices]; [self reloadContacts];
}
- (void)showGroups:(id)sender {
    if (!self.groupsWindow) {
        self.groupsWindow=[[JMPanel alloc] initWithContentRect:NSMakeRect(0,0,480,270) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
        self.groupsWindow.title=@"Группы — JimmMac"; self.groupsWindow.releasedWhenClosed=NO; self.groupsWindow.delegate=self;
        self.groupsWindow.contentView=[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,480,270)]; NSView *root=self.groupsWindow.contentView;
        [root addSubview:JMLabel(@"Группы контактов",NSMakeRect(24,222,432,24),16,YES)];
        NSTextField *help=JMLabel(@"Создавайте группы и распределяйте контакты. Изменения сохраняются в Jimm.online.",NSMakeRect(24,184,432,32),11,NO); [[help cell] setWraps:YES]; [root addSubview:help];
        self.groupManagerPopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(20,145,440,32) pullsDown:NO];
        self.groupManagerPopup.target=self; self.groupManagerPopup.action=@selector(groupManagerChanged:); [self.groupManagerPopup setToolTip:@"Выберите группу для переименования или удаления"]; [root addSubview:self.groupManagerPopup];
        self.groupCountLabel=JMLabel(@"",NSMakeRect(24,111,432,23),12,NO); [root addSubview:self.groupCountLabel];
        self.createGroupButton=JMButton(@"Создать…",NSMakeRect(16,64,132,32),self,@selector(createGroup:)); [root addSubview:self.createGroupButton];
        self.renameGroupButton=JMButton(@"Переименовать…",NSMakeRect(152,64,174,32),self,@selector(renameGroup:)); [root addSubview:self.renameGroupButton];
        self.removeGroupButton=JMButton(@"Удалить…",NSMakeRect(330,64,134,32),self,@selector(removeGroup:)); [self.removeGroupButton setToolTip:@"Удалить выбранную группу. Доступно только для пустой группы."]; [root addSubview:self.removeGroupButton];
        self.groupStatus=JMLabel(@"Удаляется только пустая группа.",NSMakeRect(24,14,308,36),11,NO); [[self.groupStatus cell] setWraps:YES]; [root addSubview:self.groupStatus];
        NSButton *close=JMButton(@"Закрыть",NSMakeRect(348,14,116,32),self,@selector(closeGroups:)); close.keyEquivalent=@"\e"; [root addSubview:close]; [self.groupsWindow center];
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
    if (!self.serverGroups.count) [self.groupManagerPopup addItemWithTitle:@"Нет групп"];
    for (NSMenuItem *item in self.groupManagerPopup.itemArray) if ([item.representedObject isEqual:selection]) [self.groupManagerPopup selectItem:item];
    NSString *group=self.groupManagerPopup.selectedItem.representedObject;
    self.groupManagerPopup.toolTip=group ?: @"Нет групп. Нажмите «Создать…».";
    JMSetLabel(self.groupCountLabel,group ? [NSString stringWithFormat:@"Контактов в группе: %lu",(unsigned long)[self contactsInGroup:group]] : @"Создайте первую группу или добавьте контакт."); [self updateGroupControls];
}
- (void)updateGroupControls {
    BOOL ready=[self canChangeRoster]; NSString *group=self.groupManagerPopup.selectedItem.representedObject;
    self.groupManagerPopup.enabled=self.serverGroups.count>0 && !self.changingRoster;
    self.createGroupButton.enabled=ready; self.renameGroupButton.enabled=ready && group.length;
    self.removeGroupButton.enabled=ready && group.length && [self contactsInGroup:group]==0;
}
- (NSAlert *)namePrompt:(NSString *)title detail:(NSString *)detail value:(NSString *)value {
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=title; alert.informativeText=detail;
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,330,25)]; field.stringValue=value ?: @""; field.toolTip=@"До 128 символов, без переносов строки";
    alert.accessoryView=field; [alert addButtonWithTitle:@"Сохранить"]; [[alert addButtonWithTitle:@"Отмена"] setKeyEquivalent:@"\e"]; [alert.window setInitialFirstResponder:field]; return alert;
}
- (BOOL)beginRosterChange:(NSString *)status {
    if (![self canChangeRoster]) return NO;
    self.changingRoster=YES; JMSetLabel(self.contactNotice,status); JMSetLabel(self.groupStatus,status); [self updateSendButton]; return YES;
}
- (void)finishRosterChange:(NSError *)error status:(NSString *)status {
    self.changingRoster=NO;
    NSString *message=error ? @"Изменение не подтверждено сервером." : status;
    JMSetLabel(self.contactNotice,message); JMSetLabel(self.groupStatus,message);
    [self refreshGroupChoices]; [self reloadContacts]; [self updatePeerLabel]; [self updateProfileCard]; [self renderTranscript]; [self.historyTable reloadData]; [self updateSendButton];
    if (error) [self showError:@"Не удалось изменить контакт-лист" detail:error.localizedDescription];
}
- (void)renameContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (![self canChangeRoster] || ![self.serverContactIDs containsObject:peer]) return;
    NSAlert *prompt=[self namePrompt:@"Имя контакта" detail:@"Личное имя контакта в Jimm.online. Пустое поле возвращает имя пользователя. До 128 символов." value:JMName(self.contacts[peer])];
    if ([prompt runModal]!=NSAlertFirstButtonReturn) return;
    [self renameContactUIN:peer name:[[(NSTextField *)prompt.accessoryView stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
- (void)renameContactUIN:(NSString *)peer name:(NSString *)name {
    if (![self.serverContactIDs containsObject:peer] || ![self beginRosterChange:@"Сохраняем имя…"]) return;
    [self.client renameContactWithUIN:peer name:name completion:^(NSDictionary *data,NSError *error) {
        if (!error) {
            if (name.length) { self.contacts[peer][@"_rosterFriendly"]=name; self.contacts[peer][@"friendly"]=name; }
            else { [self.contacts[peer] removeObjectForKey:@"_rosterFriendly"]; self.contacts[peer][@"friendly"]=peer; [self refreshPresenceForPeer:peer force:YES]; }
        }
        [self finishRosterChange:error status:@"Имя сохранено в Jimm.online."];
    }];
}
- (NSAlert *)removeContactPrompt:(NSString *)peer {
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"Удалить контакт?";
    alert.informativeText=[NSString stringWithFormat:@"%@ · UIN %@\nКонтакт будет удалён из всех групп Jimm.online. Переписка и локальная история сохранятся.",JMName(self.contacts[peer] ?: @{@"aimId":peer}),peer];
    [alert addButtonWithTitle:@"Удалить из контактов"]; [[alert addButtonWithTitle:@"Отмена"] setKeyEquivalent:@"\e"]; return alert;
}
- (void)removeContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (![self canChangeRoster] || ![self.serverContactIDs containsObject:peer]) return;
    if ([[self removeContactPrompt:peer] runModal]==NSAlertFirstButtonReturn) [self removeContactUIN:peer];
}
- (void)removeContactUIN:(NSString *)peer {
    if (![self.serverContactIDs containsObject:peer] || ![self beginRosterChange:@"Удаляем контакт…"]) return;
    [self.client removeContactWithUIN:peer completion:^(NSDictionary *data,NSError *error) {
        if (!error) { [self.serverContactIDs removeObject:peer]; self.contacts[peer][@"groups"]=@[]; self.contacts[peer][@"group"]=@""; [self.contacts[peer] removeObjectForKey:@"_rosterFriendly"]; }
        [self finishRosterChange:error status:@"Контакт удалён. История сохранена."];
    }];
}
- (void)moveContact:(id)sender {
    NSString *peer=[self contactForAction:sender]; if (![self canChangeRoster] || ![self.serverContactIDs containsObject:peer]) return;
    NSArray *sources=JMArray(self.contacts[peer][@"groups"]);
    if (!sources.count || self.serverGroups.count<2) { [self showGroups:nil]; JMSetLabel(self.groupStatus,@"Сначала создайте другую группу для переноса."); return; }
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"Переместить контакт"; alert.informativeText=[NSString stringWithFormat:@"%@ · UIN %@",JMName(self.contacts[peer]),peer];
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,100)];
    [view addSubview:JMLabel(@"Из группы",NSMakeRect(0,65,85,23),12,NO)]; [view addSubview:JMLabel(@"В группу",NSMakeRect(0,21,85,23),12,NO)];
    NSPopUpButton *source=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(89,61,271,32) pullsDown:NO]; [source addItemsWithTitles:sources]; [view addSubview:source];
    NSPopUpButton *destination=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(89,17,271,32) pullsDown:NO]; [destination addItemsWithTitles:self.serverGroups];
    for (NSString *name in self.serverGroups) if (![name isEqualToString:source.titleOfSelectedItem]) { [destination selectItemWithTitle:name]; break; } [view addSubview:destination];
    source.toolTip=@"Текущая группа контакта"; destination.toolTip=@"Группа назначения"; alert.accessoryView=view; [alert addButtonWithTitle:@"Переместить"]; [[alert addButtonWithTitle:@"Отмена"] setKeyEquivalent:@"\e"];
    if ([alert runModal]==NSAlertFirstButtonReturn) [self moveContactUIN:peer from:source.titleOfSelectedItem to:destination.titleOfSelectedItem];
}
- (void)moveContactUIN:(NSString *)peer from:(NSString *)source to:(NSString *)destination {
    if (![self.serverContactIDs containsObject:peer] || ![JMArray(self.contacts[peer][@"groups"]) containsObject:source] || ![self.serverGroups containsObject:destination]) return;
    if ([source isEqualToString:destination]) { JMSetLabel(self.contactNotice,@"Выберите другую группу."); return; }
    if (![self beginRosterChange:@"Перемещаем контакт…"]) return;
    [self.client moveContactWithUIN:peer fromGroup:source toGroup:destination completion:^(NSDictionary *data,NSError *error) {
        if (!error) { NSMutableArray *groups=[JMArray(self.contacts[peer][@"groups"]) mutableCopy]; [groups removeObject:source]; if (![groups containsObject:destination]) [groups addObject:destination]; self.contacts[peer][@"groups"]=groups; self.contacts[peer][@"group"]=[groups firstObject] ?: @""; }
        [self finishRosterChange:error status:@"Контакт перемещён в Jimm.online."];
    }];
}
- (void)createGroup:(id)sender {
    if (![self canChangeRoster]) return;
    NSAlert *prompt=[self namePrompt:@"Создать группу" detail:@"Название группы в Jimm.online. До 128 символов." value:@""];
    if ([prompt runModal]==NSAlertFirstButtonReturn) [self createGroupNamed:[[(NSTextField *)prompt.accessoryView stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
- (void)createGroupNamed:(NSString *)name {
    if (![self beginRosterChange:@"Создаём группу…"]) return;
    [self.client createGroup:name completion:^(NSDictionary *data,NSError *error) {
        if (!error && ![self.serverGroups containsObject:name]) [self.serverGroups addObject:name];
        [self finishRosterChange:error status:@"Группа создана в Jimm.online."]; if (!error) [self.groupManagerPopup selectItemWithTitle:name]; [self updateGroupWindow];
    }];
}
- (void)renameGroup:(id)sender {
    NSString *name=self.groupManagerPopup.selectedItem.representedObject; if (![self canChangeRoster] || !name.length) return;
    NSAlert *prompt=[self namePrompt:@"Переименовать группу" detail:@"Новое название группы в Jimm.online. До 128 символов." value:name];
    if ([prompt runModal]==NSAlertFirstButtonReturn) [self renameGroupNamed:name to:[[(NSTextField *)prompt.accessoryView stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
- (void)renameGroupNamed:(NSString *)name to:(NSString *)newName {
    if (![self.serverGroups containsObject:name]) return;
    if (![name isEqualToString:newName] && [self.serverGroups containsObject:newName]) { JMSetLabel(self.groupStatus,@"Группа с таким именем уже существует."); return; }
    if (![self beginRosterChange:@"Переименовываем группу…"]) return;
    [self.client renameGroup:name to:newName completion:^(NSDictionary *data,NSError *error) {
        if (!error) {
            [self.serverGroups removeObject:name]; if (![self.serverGroups containsObject:newName]) [self.serverGroups addObject:newName];
            for (NSString *peer in self.serverContactIDs) { NSMutableArray *groups=[JMArray(self.contacts[peer][@"groups"]) mutableCopy]; NSUInteger index=[groups indexOfObject:name]; if (index!=NSNotFound) groups[index]=newName; self.contacts[peer][@"groups"]=groups; self.contacts[peer][@"group"]=[groups firstObject] ?: @""; }
            if ([self.selectedGroup isEqualToString:name]) self.selectedGroup=newName;
        }
        [self finishRosterChange:error status:@"Название группы сохранено."]; if (!error) [self.groupManagerPopup selectItemWithTitle:newName]; [self updateGroupWindow];
    }];
}
- (void)removeGroup:(id)sender {
    NSString *name=self.groupManagerPopup.selectedItem.representedObject; if (![self canChangeRoster] || !name.length || [self contactsInGroup:name]) return;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"Удалить пустую группу?"; alert.informativeText=name; [alert addButtonWithTitle:@"Удалить"]; [[alert addButtonWithTitle:@"Отмена"] setKeyEquivalent:@"\e"];
    if ([alert runModal]==NSAlertFirstButtonReturn) [self removeGroupNamed:name];
}
- (void)removeGroupNamed:(NSString *)name {
    if (![self.serverGroups containsObject:name] || [self contactsInGroup:name]) { JMSetLabel(self.groupStatus,@"Сначала перенесите контакты из группы."); return; }
    if (![self beginRosterChange:@"Удаляем пустую группу…"]) return;
    [self.client removeGroup:name completion:^(NSDictionary *data,NSError *error) {
        if (!error) [self.serverGroups removeObject:name]; [self finishRosterChange:error status:@"Пустая группа удалена."];
    }];
}
- (void)showPreferences:(id)sender {
    if (!self.preferencesWindow) {
        self.preferencesWindow=[[JMPanel alloc] initWithContentRect:NSMakeRect(0,0,520,380) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
        [self.preferencesWindow setTitle:@"Настройки — JimmMac"]; [self.preferencesWindow setReleasedWhenClosed:NO]; [self.preferencesWindow setDelegate:self];
        [self.preferencesWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,520,380)]];
        NSView *windowRoot=self.preferencesWindow.contentView;
        self.preferenceSections=[[NSSegmentedControl alloc] initWithFrame:NSZeroRect]; [self.preferenceSections setSegmentCount:3];
        NSArray *sections=@[@"Переписка",@"Уведомления",@"Звуки"];
        for (NSUInteger i=0;i<sections.count;i++) { [self.preferenceSections setLabel:sections[i] forSegment:i]; [self.preferenceSections setWidth:140 forSegment:i]; [[self.preferenceSections cell] setToolTip:sections[i] forSegment:i]; }
        [self.preferenceSections setSegmentStyle:NSSegmentStyleRounded]; [self.preferenceSections sizeToFit];
        [self.preferenceSections setFrameOrigin:NSMakePoint(floor((520-NSWidth(self.preferenceSections.frame))/2),340)];
        [self.preferenceSections setSelectedSegment:0]; self.preferenceSections.target=self; self.preferenceSections.action=@selector(changePreferenceSection:); [windowRoot addSubview:self.preferenceSections];
        self.fontPreferencesView=[[NSView alloc] initWithFrame:NSMakeRect(20,56,480,268)]; [windowRoot addSubview:self.fontPreferencesView];
        self.notificationPreferencesView=[[NSView alloc] initWithFrame:self.fontPreferencesView.frame]; [windowRoot addSubview:self.notificationPreferencesView];
        self.soundPreferencesView=[[NSView alloc] initWithFrame:self.fontPreferencesView.frame]; [windowRoot addSubview:self.soundPreferencesView];
        NSView *root=self.fontPreferencesView;
        [root addSubview:JMLabel(@"Шрифт переписки",NSMakeRect(24,223,432,24),16,YES)];
        NSTextField *description=JMLabel(@"Применяется к сообщениям и полю ввода. Изменения сохраняются сразу.",NSMakeRect(24,185,432,33),11,NO);
        [[description cell] setWraps:YES]; [root addSubview:description];
        [root addSubview:JMLabel(@"Шрифт",NSMakeRect(24,153,80,22),13,NO)];
        self.fontFamilyPopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(108,149,350,29) pullsDown:NO];
        [self.fontFamilyPopup addItemWithTitle:@"Системный"]; self.fontFamilyPopup.lastItem.representedObject=@"";
        for (NSString *family in [[[NSFontManager sharedFontManager] availableFontFamilies] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
            [self.fontFamilyPopup addItemWithTitle:family]; self.fontFamilyPopup.lastItem.representedObject=family;
        }
        self.fontFamilyPopup.target=self; self.fontFamilyPopup.action=@selector(fontSettingsChanged:);
        [self.fontFamilyPopup setToolTip:@"Семейство шрифта для текста сообщений и черновиков"]; [root addSubview:self.fontFamilyPopup];
        [root addSubview:JMLabel(@"Размер",NSMakeRect(24,114,80,22),13,NO)];
        self.fontSizePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(108,110,92,29) pullsDown:NO];
        for (NSInteger size=9;size<=28;size++) { [self.fontSizePopup addItemWithTitle:[NSString stringWithFormat:@"%ld",(long)size]]; self.fontSizePopup.lastItem.representedObject=@(size); }
        self.fontSizePopup.target=self; self.fontSizePopup.action=@selector(fontSettingsChanged:); [self.fontSizePopup setToolTip:@"Размер шрифта от 9 до 28 пунктов"]; [root addSubview:self.fontSizePopup];
        self.fontPreview=JMLabel(@"Привет из JimmMac!",NSMakeRect(24,44,432,61),13,NO);
        [[self.fontPreview cell] setWraps:YES]; [self.fontPreview setBordered:YES]; [self.fontPreview setDrawsBackground:YES]; [self.fontPreview setBackgroundColor:[NSColor textBackgroundColor]]; [root addSubview:self.fontPreview];
        [root addSubview:JMLabel(@"Отправка",NSMakeRect(24,15,80,22),13,NO)];
        self.sendModePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(108,10,350,29) pullsDown:NO];
        [self.sendModePopup addItemsWithTitles:@[@"Enter",@"⌘Enter (Command+Enter)"]];
        self.sendModePopup.target=self; self.sendModePopup.action=@selector(sendModeChanged:);
        self.sendModePopup.toolTip=@"При выборе ⌘Enter обычный Enter добавляет строку. Shift+Enter всегда добавляет строку"; [root addSubview:self.sendModePopup];
        [self createAlertPreferenceViews];
        self.fontResetButton=JMButton(@"Сбросить шрифт",NSMakeRect(20,13,154,32),self,@selector(resetChatFont:)); [windowRoot addSubview:self.fontResetButton];
        NSButton *close=JMButton(@"Закрыть",NSMakeRect(386,13,114,32),self,@selector(closePreferences:)); close.keyEquivalent=@"\e"; [windowRoot addSubview:close];
        [self.preferencesWindow center];
    }
    [self syncFontControls]; [self syncAlertControls]; [self changePreferenceSection:nil]; [self.preferencesWindow makeKeyAndOrderFront:nil];
}
- (void)createAlertPreferenceViews {
    NSView *root=self.notificationPreferencesView;
    [root addSubview:JMLabel(@"Уведомления о сообщениях",NSMakeRect(24,223,432,24),16,YES)];
    NSTextField *help=JMLabel(@"Для сообщений вне открытой переписки. Вид баннера задаётся в «Системные настройки → Уведомления» OS X.",NSMakeRect(24,184,432,34),11,NO); [[help cell] setWraps:YES]; [root addSubview:help];
    self.notificationsCheckbox=JMCheckbox(@"Показывать системные уведомления",NSMakeRect(24,146,432,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.notificationsCheckbox];
    [root addSubview:JMLabel(@"В уведомлении",NSMakeRect(24,110,136,23),13,NO)];
    self.notificationContentPopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(164,105,292,32) pullsDown:NO];
    NSArray *titles=@[@"Только имя отправителя",@"Имя и текст сообщения",@"Без имени и текста"], *styles=@[@"sender",@"preview",@"private"];
    for (NSUInteger i=0;i<titles.count;i++) { [self.notificationContentPopup addItemWithTitle:titles[i]]; self.notificationContentPopup.lastItem.representedObject=styles[i]; }
    self.notificationContentPopup.target=self; self.notificationContentPopup.action=@selector(alertPreferencesChanged:); self.notificationContentPopup.toolTip=@"Какие сведения видны в баннере и Центре уведомлений"; [root addSubview:self.notificationContentPopup];
    self.notificationPrivacyHelp=JMLabel(@"",NSMakeRect(24,66,432,34),11,NO); [[self.notificationPrivacyHelp cell] setWraps:YES]; [root addSubview:self.notificationPrivacyHelp];
    self.dockAttentionCheckbox=JMCheckbox(@"Привлекать внимание значком Dock",NSMakeRect(24,36,432,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.dockAttentionCheckbox];
    self.notificationTestButton=JMButton(@"Проверить уведомление",NSMakeRect(18,0,228,32),self,@selector(testNotification:)); self.notificationTestButton.toolTip=@"Показать тестовый баннер JimmMac. Сообщения собеседникам не отправляются."; [root addSubview:self.notificationTestButton];
    self.notificationTestStatus=JMLabel(@"",NSMakeRect(252,5,208,24),11,NO); [root addSubview:self.notificationTestStatus];
    root=self.soundPreferencesView;
    [root addSubview:JMLabel(@"Звуковые оповещения",NSMakeRect(24,223,432,24),16,YES)];
    help=JMLabel(@"Оригинальные звуки Jimm.online. Кнопки внизу позволяют прослушать каждый сигнал.",NSMakeRect(24,184,432,34),11,NO); [[help cell] setWraps:YES]; [root addSubview:help];
    self.soundMasterCheckbox=JMCheckbox(@"Включить звуковые оповещения",NSMakeRect(24,148,432,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.soundMasterCheckbox];
    self.presenceSoundCheckbox=JMCheckbox(@"Появление и выход контактов",NSMakeRect(44,114,412,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.presenceSoundCheckbox];
    self.typingSoundCheckbox=JMCheckbox(@"Набор текста собеседником",NSMakeRect(44,80,412,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.typingSoundCheckbox];
    self.openConversationSoundCheckbox=JMCheckbox(@"Звук в открытой переписке",NSMakeRect(44,46,412,24),self,@selector(alertPreferencesChanged:)); [root addSubview:self.openConversationSoundCheckbox];
    NSArray *soundTitles=@[@"Сообщение",@"В сети",@"Вышел",@"Печатает"];
    for (NSUInteger i=0;i<soundTitles.count;i++) { NSButton *sample=JMButton(soundTitles[i],NSMakeRect(18+i*114,4,110,32),self,@selector(previewSoundButton:)); sample.tag=i; sample.toolTip=[@"Прослушать: " stringByAppendingString:soundTitles[i]]; [root addSubview:sample]; }
}
- (void)changePreferenceSection:(id)sender {
    NSInteger section=self.preferenceSections.selectedSegment;
    self.fontPreferencesView.hidden=section!=0; self.notificationPreferencesView.hidden=section!=1; self.soundPreferencesView.hidden=section!=2; self.fontResetButton.hidden=section!=0;
}
- (void)syncAlertControls {
    self.notificationsCheckbox.state=self.notificationAlerts.enabled ? NSOnState : NSOffState;
    self.dockAttentionCheckbox.state=self.notificationAlerts.dockAttentionEnabled ? NSOnState : NSOffState;
    for (NSMenuItem *item in self.notificationContentPopup.itemArray) if ([item.representedObject isEqualToString:self.notificationAlerts.contentStyle]) [self.notificationContentPopup selectItem:item];
    self.notificationContentPopup.enabled=self.notificationAlerts.enabled; self.notificationTestButton.enabled=self.notificationAlerts.enabled;
    NSString *privacy=[self.notificationAlerts.contentStyle isEqualToString:@"private"] ? @"Имя отправителя и текст сообщения скрыты." : ([self.notificationAlerts.contentStyle isEqualToString:@"preview"] ? @"Видны имя отправителя и начало сообщения." : @"Видно имя отправителя. Текст сообщения скрыт."); JMSetLabel(self.notificationPrivacyHelp,privacy);
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
- (void)testNotification:(id)sender { JMSetLabel(self.notificationTestStatus,[self.notificationAlerts sendTestNotification] ? @"Отправлено в систему." : @"Уведомления недоступны."); }
- (void)previewSoundButton:(NSButton *)sender { NSArray *events=@[@"message",@"online",@"offline",@"typing"]; if (sender.tag>=0 && sender.tag<(NSInteger)events.count) [self.audioAlerts previewEvent:events[(NSUInteger)sender.tag]]; }
- (void)syncFontControls {
    [self.sendModePopup selectItemAtIndex:self.chatPreferences.sendWithCommandReturn ? 1 : 0];
    for (NSMenuItem *item in self.fontFamilyPopup.itemArray) if ([item.representedObject isEqual:self.chatPreferences.family]) { [self.fontFamilyPopup selectItem:item]; break; }
    for (NSMenuItem *item in self.fontSizePopup.itemArray) if ([item.representedObject doubleValue]==self.chatPreferences.size) { [self.fontSizePopup selectItem:item]; break; }
    self.fontPreview.font=self.chatPreferences.messageFont;
}
- (void)applyChatFont {
    self.composer.font=self.chatPreferences.messageFont;
    self.composer.typingAttributes=@{NSFontAttributeName:self.chatPreferences.messageFont,NSForegroundColorAttributeName:[NSColor textColor]};
    [self renderTranscript]; [self syncFontControls];
}
- (void)fontSettingsChanged:(id)sender {
    [self.chatPreferences setFamily:self.fontFamilyPopup.selectedItem.representedObject size:[self.fontSizePopup.selectedItem.representedObject doubleValue]];
    [self applyChatFont];
}
- (void)resetChatFont:(id)sender { [self.chatPreferences reset]; [self applyChatFont]; }
- (void)sendModeChanged:(id)sender { self.chatPreferences.sendWithCommandReturn=self.sendModePopup.indexOfSelectedItem==1; [self updateSendButton]; }
- (void)closePreferences:(id)sender { [self.preferencesWindow orderOut:nil]; }
- (void)createHistoryWindow {
    if (self.historyWindow) return;
    self.historyWindow=[[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,680,440) styleMask:NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
    [self.historyWindow setTitle:@"Поиск по истории — JimmMac"]; [self.historyWindow setReleasedWhenClosed:NO]; [self.historyWindow setDelegate:self]; [self.historyWindow setContentMinSize:NSMakeSize(580,360)];
    [self.historyWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,680,440)]];
    NSView *root=self.historyWindow.contentView;
    self.historySearchField=[[NSSearchField alloc] initWithFrame:NSMakeRect(16,396,408,28)];
    [[self.historySearchField cell] setPlaceholderString:@"Слово или фраза в сообщениях"]; [(NSTextField *)self.historySearchField setDelegate:self];
    self.historySearchField.target=self; self.historySearchField.action=@selector(searchHistory:); self.historySearchField.autoresizingMask=NSViewWidthSizable|NSViewMinYMargin;
    [self.historySearchField setToolTip:@"Поиск по сохранённым сообщениям текущего аккаунта. Регистр букв не важен."]; [root addSubview:self.historySearchField];
    self.historyScopePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(434,393,232,32) pullsDown:NO];
    [self.historyScopePopup addItemWithTitle:@"Все переписки"]; [self.historyScopePopup addItemWithTitle:@"Текущая переписка"];
    [self.historyScopePopup setAutoenablesItems:NO];
    self.historyScopePopup.target=self; self.historyScopePopup.action=@selector(searchHistory:); self.historyScopePopup.autoresizingMask=NSViewMinXMargin|NSViewMinYMargin;
    [self.historyScopePopup setToolTip:@"Искать во всей локальной истории или только у выбранного собеседника"]; [root addSubview:self.historyScopePopup];
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(16,66,648,318)]; scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [scroll setHasVerticalScroller:YES]; [scroll setBorderType:NSBezelBorder];
    self.historyTable=[[JMContactTable alloc] initWithFrame:scroll.contentView.bounds];
    NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"history"]; column.width=630; column.resizingMask=NSTableColumnAutoresizingMask;
    [self.historyTable addTableColumn:column]; self.historyTable.headerView=nil; self.historyTable.rowHeight=54;
    self.historyTable.delegate=self; self.historyTable.dataSource=self; self.historyTable.target=self; self.historyTable.doubleAction=@selector(openHistoryResult:); [(JMContactTable *)self.historyTable setActivateAction:@selector(openHistoryResult:)];
    self.historyTable.columnAutoresizingStyle=NSTableViewLastColumnOnlyAutoresizingStyle; self.historyTable.selectionHighlightStyle=NSTableViewSelectionHighlightStyleRegular;
    [self.historyTable setToolTip:@"Двойной щелчок — перейти к сообщению в переписке"]; [scroll setDocumentView:self.historyTable]; [root addSubview:scroll];
    self.historySearchStatus=JMLabel(@"Введите слово или фразу для поиска.",NSMakeRect(16,21,395,28),12,NO); self.historySearchStatus.autoresizingMask=NSViewWidthSizable; [root addSubview:self.historySearchStatus];
    NSButton *close=JMButton(@"Закрыть",NSMakeRect(422,17,110,32),self,@selector(closeHistorySearch:)); close.keyEquivalent=@"\e"; close.autoresizingMask=NSViewMinXMargin; [root addSubview:close];
    self.historyOpenButton=JMButton(@"Открыть",NSMakeRect(538,17,126,32),self,@selector(openHistoryResult:)); self.historyOpenButton.keyEquivalent=@"\r"; self.historyOpenButton.autoresizingMask=NSViewMinXMargin;
    [self.historyOpenButton setToolTip:@"Открыть выбранное сообщение и подсветить найденный текст"]; [self.historyOpenButton setEnabled:NO]; [root addSubview:self.historyOpenButton];
    [self.historyWindow setInitialFirstResponder:self.historySearchField]; [self.historyWindow center];
}
- (void)showHistorySearch:(id)sender {
    if (!self.history) return;
    [self createHistoryWindow];
    [[self.historyScopePopup itemAtIndex:1] setEnabled:self.selectedPeer.length>0];
    if (!self.selectedPeer.length) [self.historyScopePopup selectItemAtIndex:0];
    [self.historyWindow makeKeyAndOrderFront:nil]; [self.historyWindow makeFirstResponder:self.historySearchField]; [self.historySearchField selectText:nil]; [self searchHistory:nil];
}
- (void)closeHistorySearch:(id)sender { [self.historyWindow orderOut:nil]; self.historySearchGeneration++; }
- (void)searchHistory:(id)sender {
    NSUInteger serial=++self.historySearchGeneration;
    NSString *query=[[self.historySearchField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (self.historyScopePopup.indexOfSelectedItem==1 && !self.selectedPeer.length) [self.historyScopePopup selectItemAtIndex:0];
    NSString *peer=self.historyScopePopup.indexOfSelectedItem==1 ? self.selectedPeer : nil;
    self.historyResults=@[]; self.historyResultsQuery=query; [self.historyTable reloadData]; [self.historyOpenButton setEnabled:NO];
    if (!query.length || !self.history) { JMSetLabel(self.historySearchStatus,@"Введите слово или фразу для поиска."); return; }
    if (self.history.loadError) { JMSetLabel(self.historySearchStatus,@"История недоступна: не удалось прочитать файл."); return; }
    JMSetLabel(self.historySearchStatus,@"Ищем в локальной истории…");
    // Capture on the main thread: appendMessage replaces arrays and dictionaries,
    // so this immutable snapshot stays consistent while new messages arrive.
    NSDictionary *snapshot=[self.history searchSnapshot]; JMHistory *history=self.history;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.18*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if (serial!=self.historySearchGeneration || history!=self.history) return;
        dispatch_async(self.historySearchQueue,^{
            @autoreleasepool {
              NSArray *hits=[JMHistory searchSnapshot:snapshot query:query peer:peer limit:201];
              dispatch_async(dispatch_get_main_queue(),^{
                if (serial!=self.historySearchGeneration || history!=self.history) return;
                BOOL limited=hits.count>200;
                self.historyResults=limited ? [hits subarrayWithRange:NSMakeRange(0,200)] : hits;
                [self.historyTable reloadData];
                JMSetLabel(self.historySearchStatus,limited ? @"Первые 200 результатов. Уточните запрос." : (hits.count ? [NSString stringWithFormat:@"Найдено сообщений: %lu",(unsigned long)hits.count] : @"Совпадений нет. Попробуйте другую фразу."));
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
    [self renderTranscript];
    NSValue *value=self.transcriptRanges[self.highlightedMessageID];
    if (value) {
        NSRange body=value.rangeValue;
        NSRange match=[self.transcript.string rangeOfString:self.historyHighlightQuery options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch range:body];
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
    NSMenu *result=[menu copy] ?: [[NSMenu alloc] initWithTitle:@"Сообщение"];
    NSDictionary *context=@{@"account":self.accountUIN ?: @"",@"peer":self.selectedPeer ?: @"",@"id":identifier,@"generation":@(self.conversationGeneration)};
    [result insertItem:[NSMenuItem separatorItem] atIndex:0];
    NSMenuItem *copy=[[NSMenuItem alloc] initWithTitle:@"Копировать сообщение целиком" action:@selector(copyWholeMessage:) keyEquivalent:@""]; copy.target=self; copy.representedObject=context;
    [result insertItem:copy atIndex:0];
    NSMenuItem *quote=[[NSMenuItem alloc] initWithTitle:@"Ответить цитатой" action:@selector(quoteMessage:) keyEquivalent:@""]; quote.target=self; quote.representedObject=context;
    [result insertItem:quote atIndex:0]; return result;
}
- (NSDictionary *)messageForAction:(NSMenuItem *)item {
    NSDictionary *context=JMDictionary(item.representedObject);
    if (!self.history || [context[@"generation"] unsignedIntegerValue]!=self.conversationGeneration || ![JMString(context[@"account"]) isEqualToString:self.accountUIN ?: @""] || ![JMString(context[@"peer"]) isEqualToString:self.selectedPeer]) return nil;
    for (NSDictionary *message in [self.history messagesForPeer:self.selectedPeer]) if ([JMString(message[@"id"]) isEqualToString:JMString(context[@"id"])]) return message;
    return nil;
}
- (void)writeMessageToPasteboard:(NSString *)text {
    NSPasteboard *board=[NSPasteboard generalPasteboard]; [board clearContents]; [board setString:text forType:NSPasteboardTypeString];
}
- (void)copyWholeMessage:(NSMenuItem *)sender { NSDictionary *message=[self messageForAction:sender]; if (message) [self writeMessageToPasteboard:JMString(message[@"text"])]; }
- (void)quoteMessage:(NSMenuItem *)sender {
    NSDictionary *message=[self messageForAction:sender]; if (!message || !self.composer.isEditable) return;
    NSString *name=[message[@"outgoing"] boolValue] ? (JMString(self.ownInfo[@"friendly"]).length ? JMString(self.ownInfo[@"friendly"]) : self.accountUIN ?: @"Я") : JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer});
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
    if (self.sending && self.sendingPeer.length && self.sendingText.length) {
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
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"Не удалось сохранить черновики";
    alert.informativeText=[NSString stringWithFormat:@"%@\n\nЧерновики пока находятся в памяти. Вернитесь и скопируйте нужный текст перед выходом.",self.draftSaveError.localizedDescription];
    [[alert addButtonWithTitle:@"Вернуться"] setKeyEquivalent:@"\e"]; [alert addButtonWithTitle:@"Продолжить без сохранения"];
    return [alert runModal]==NSAlertSecondButtonReturn;
}
- (void)updateSoundControls {
    [self.soundButton setTitle:self.audioAlerts.enabled ? @"Звуки: вкл." : @"Звуки: выкл."];
    [self.soundButton setToolTip:@"Включить или отключить все звуки. Отдельные события и прослушивание — в меню «Звуки»."];
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
    if (item.action==@selector(send:)) return self.chatWindow.isKeyWindow && self.chatWindow.firstResponder==self.composer && !self.composer.hasMarkedText && self.sendButton.isEnabled;
    if (item.action==@selector(copyWholeMessage:) || item.action==@selector(quoteMessage:)) return [self messageForAction:item]!=nil && (item.action!=@selector(quoteMessage:) || self.composer.isEditable);
    if (item.action==@selector(openConversation:) || item.action==@selector(focusContactSearch:) || item.action==@selector(showContactsSection:) || item.action==@selector(showConversationsSection:)) return self.history!=nil;
    if (item.action==@selector(showOwnProfile:)) return self.accountUIN.length>0;
    if (item.action==@selector(renameContact:) || item.action==@selector(removeContact:) || item.action==@selector(moveContact:)) return [self canChangeRoster] && [self.serverContactIDs containsObject:[self contactForAction:item]];
    if (item.action==@selector(writeContact:) || item.action==@selector(profileContact:)) return JMValidUIN([self contactForAction:item]);
    if (item.action==@selector(addContact:)) return [self canChangeRoster];
    if (item.action==@selector(showGroups:)) return self.history!=nil;
    if (item.action==@selector(toggleSoundOption:)) {
        [item setState:[[self.audioAlerts valueForKey:item.representedObject] boolValue] ? NSOnState : NSOffState];
        return [item.representedObject isEqualToString:@"enabled"] || self.audioAlerts.enabled;
    }
    if (item.action==@selector(logout:)) return self.accountUIN.length>0;
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
    self.loginAttemptSerial++;
    [self.historyWindow orderOut:nil]; self.historySearchGeneration++; self.historyResults=@[]; [self.historyTable reloadData]; [self.historySearchField setStringValue:@""];
    self.history = [self makeHistoryForUIN:uin]; self.showedHistoryError = NO;
    self.changingRoster=NO; self.selectedGroup=nil; [self.serverGroups removeAllObjects]; [self.groupsWindow orderOut:nil]; [self refreshGroupChoices];
    if (self.history.loadError) { [self showError:@"История недоступна" detail:[self.history.loadError localizedDescription]]; return NO; }
    [self flushDrafts]; self.draftStore=nil; self.conversationGeneration++;
    [self.contacts removeAllObjects]; [self.drafts removeAllObjects]; [self.unread removeAllObjects]; self.selectedPeer = nil; self.sending = NO;
    self.accountUIN = uin; [self.serverContactIDs removeAllObjects]; [self.conversationPeers removeAllObjects]; self.addingContact = NO; self.sendNotBefore = nil;
    [self restoreDraftsForUIN:uin];
    [self.avatars invalidate]; self.avatars=[self makeAvatarStore]; self.avatars.delegate=self;
    [self.ownInfo removeAllObjects]; [self.profileDates removeAllObjects]; [self.profileTexts removeAllObjects]; [self.incomingTyping removeAllObjects]; self.changingPresence=NO;
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
    if (!JMValidUIN(uin) || !password.length) { self.loginStatus.stringValue=@"Укажите числовой UIN и пароль."; return; }
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
    self.loginStatus.stringValue=@"Открываем сохранённый вход…";
    NSUInteger serial=++self.loginAttemptSerial; JMLoginStore *store=self.loginStore;
    __weak JMAppDelegate *weakSelf=self;
    dispatch_async(self.loginStoreQueue,^{
        NSError *error=nil; NSDictionary *record=[store loginForUIN:uin error:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            JMAppDelegate *self=weakSelf; if (!self || self.terminating || self.loginAttemptSerial!=serial) return;
            if (!record) {
                if (!error || ([error.domain isEqualToString:JMLoginStoreErrorDomain] && (error.code==-1 || error.code==-2))) [self forgetSavedLoginForUIN:uin];
                self.resumingLogin=NO; [self resetLogin:error.localizedDescription ?: @"Сохранённый вход не найден. Введите пароль."]; return;
            }
            if (![self prepareLoginUIForUIN:uin]) { self.resumingLogin=NO; [self resetLogin:@"Не удалось открыть локальные данные аккаунта."]; return; }
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
            JMAppDelegate *self=weakSelf; if (self && !self.terminating) [self showError:@"Автовход отключён" detail:@"Не удалось удалить запись JimmMac из Связки ключей. Автоматический вход отключён. Запись можно удалить в системной программе «Связка ключей»."];
        });
    });
}
- (void)rememberLoginChanged:(id)sender {
    if (self.rememberLoginCheckbox.state==NSOffState) [self forgetSavedLoginForUIN:[self.loginDefaults stringForKey:@"RememberedAccountUIN"]];
}
- (void)cancelLogin:(id)sender {
    [self logoutForgettingSavedLogin:NO]; self.loginStatus.stringValue=@"Подключение отменено. Можно войти вручную.";
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
                NSString *detail=error.localizedDescription ?: @"Сервер не сообщил срок действия токена. Вход придётся повторить при следующем запуске.";
                if (self.terminating) self.quitCredentialError=detail; else [self showError:@"Вход не сохранён" detail:detail]; return;
            }
            [self.loginDefaults setObject:uin forKey:@"RememberedAccountUIN"]; [self.loginDefaults synchronize];
            if (!self.terminating) JMSetLabel(self.statusLabel,@"Подключено · Вход сохранён в Связке ключей");
        });
    });
}
- (void)logout:(id)sender { [self logoutForgettingSavedLogin:YES]; }
- (void)logoutForgettingSavedLogin:(BOOL)forget {
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
    self.history = nil; self.selectedPeer = nil;
    [self.contacts removeAllObjects]; [self.drafts removeAllObjects]; [self.unread removeAllObjects];
    [self.composer setString:@""]; [self.composer.undoManager removeAllActions]; [self.transcript setString:@""]; [self reloadContacts];
    [self updateDockBadge]; [self.audioAlerts stop];
    [self.chatWindow orderOut:nil]; [self resetLogin:@"Вы вышли из аккаунта."];
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
    self.wasConnected=connected;
    JMSetLabel(self.statusLabel,status); JMSetLabel(self.loginStatus,status);
    [self updateAccountLabel];
    if (connected && [self.loginWindow isVisible]) { [self.loginWindow orderOut:nil]; [self.chatWindow makeKeyAndOrderFront:nil]; }
    [self updateSendButton]; [self updateTypingIndicator];
    if (connected) [self openPendingNotification];
}
- (void)updateAccountLabel {
    NSString *uin=JMValidUIN(self.accountUIN) ? self.accountUIN : self.client.uin;
    NSString *name=JMString(self.ownInfo[@"friendly"]);
    NSString *identity=JMValidUIN(uin) ? (name.length ? [NSString stringWithFormat:@"%@ · UIN %@",name,uin] : [@"UIN " stringByAppendingString:uin]) : (name.length ? name : @"Учётная запись");
    JMSetLabel(self.accountLabel,identity);
}
- (void)client:(JMAPIClient *)client failedLogin:(NSError *)error {
    BOOL savedAccount=[[self.loginDefaults stringForKey:@"RememberedAccountUIN"] isEqualToString:self.accountUIN];
    if ((self.resumingLogin || (!self.loginPending && savedAccount)) && [error.domain isEqualToString:JMAPIErrorDomain] && (error.code==401 || error.code==330)) [self forgetSavedLoginForUIN:self.accountUIN];
    self.resumingLogin=NO; self.pendingRememberLogin=NO;
    [self.ownProfileController invalidate]; self.ownProfileController=nil;
    self.notificationAlerts.accountUIN=nil;
    [self stopOutgoingTyping]; [self.profileWindow orderOut:nil];
    [self.chatWindow orderOut:nil]; [self resetLogin:[error localizedDescription]];
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
    self.contacts = newContacts; [self refreshGroupChoices]; [self reloadContacts]; [self updatePeerLabel]; [self updateProfileCard];
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
    if (oldState.length && newState.length && ![oldState isEqualToString:newState] && [self.serverContactIDs containsObject:peer] && client.connected && self.connectedSince && -[self.connectedSince timeIntervalSinceNow]>3) {
        BOOL wasOnline=![oldState isEqualToString:@"offline"], isOnline=![newState isEqualToString:@"offline"];
        if (wasOnline!=isOnline) [self.audioAlerts playEvent:isOnline ? @"online" : @"offline"];
    }
    if (changedAvatar) [self.avatars refreshUIN:peer];
}
- (BOOL)client:(JMAPIClient *)client receivedMessage:(NSDictionary *)message {
    NSString *peer = message[@"peer"];
    NSUInteger before = [[self.history messagesForPeer:peer] count];
    NSError *error = nil;
    if (![self.history appendMessage:message error:&error]) {
        if (!self.showedHistoryError) { self.showedHistoryError = YES; [self showError:@"Не удалось сохранить историю" detail:[error localizedDescription]]; }
        return NO;
    }
    if (!self.contacts[peer]) self.contacts[peer] = [@{@"aimId":peer, @"friendly":[JMString(message[@"name"]) length] ? message[@"name"] : peer, @"state":@"offline"} mutableCopy];
    [self.conversationPeers addObject:peer]; [self persistConversationPeers];
    BOOL isNew = [[self.history messagesForPeer:peer] count] > before;
    BOOL reading=[peer isEqualToString:self.selectedPeer] && [self isReadingConversation];
    if ([peer isEqualToString:self.selectedPeer] && isNew) [self renderTranscript];
    if (![message[@"outgoing"] boolValue] && isNew && !reading) self.unread[peer] = @([self.unread[peer] integerValue] + 1);
    if (isNew && ![message[@"outgoing"] boolValue]) {
        if (!reading || self.audioAlerts.soundInOpenConversation) [self.audioAlerts playEvent:@"message"];
        if (!reading) [self.notificationAlerts queueMessageFrom:peer name:JMName(self.contacts[peer]) text:JMString(message[@"text"])];
        if (!reading && self.notificationAlerts.dockAttentionEnabled && ![NSApp isActive]) [NSApp requestUserAttention:NSInformationalRequest];
    }
    [self reloadContacts]; [self updateDockBadge]; return YES;
}
- (BOOL)isReadingConversation {
    NSClipView *clip=self.transcript.enclosingScrollView.contentView;
    BOOL atBottom=NSMaxY(clip.bounds)>=NSHeight(self.transcript.bounds)-24;
    return atBottom && [NSApp isActive] && self.chatWindow.isKeyWindow && self.chatWindow.isVisible && !self.chatWindow.isMiniaturized;
}
- (void)updateDockBadge {
    NSInteger total=0; for (NSNumber *count in [self.unread allValues]) total+=[count integerValue];
    [[NSApp dockTile] setBadgeLabel:total>0 ? [NSString stringWithFormat:@"%ld",(long)total] : nil];
    [self updateUnreadControls];
}
- (void)markSelectedRead {
    if (self.selectedPeer && self.unread[self.selectedPeer] && [self isReadingConversation]) {
        [self.notificationAlerts clearPeer:self.selectedPeer];
        if (self.unread[self.selectedPeer]) { [self.unread removeObjectForKey:self.selectedPeer]; [self reloadContacts]; [self updateDockBadge]; }
    }
}
- (void)updateUnreadControls {
    NSInteger count=[self.unread[self.selectedPeer ?: @""] integerValue];
    self.latestMessagesButton.hidden=count==0;
    self.latestMessagesButton.title=[NSString stringWithFormat:@"Новые: %ld ↓",(long)count];
    [self layoutChatWindow];
}
- (void)jumpToLatest:(id)sender {
    [self.transcript scrollRangeToVisible:NSMakeRange(self.transcript.string.length,0)]; [self markSelectedRead];
}
- (void)markAllRead:(id)sender { [self.unread removeAllObjects]; [self.notificationAlerts clear]; [self reloadContacts]; [self updateDockBadge]; }
- (BOOL)notificationAlerts:(JMNotificationAlerts *)alerts shouldNotifyPeer:(NSString *)peer {
    return self.history!=nil && JMValidUIN(peer) && !([peer isEqualToString:self.selectedPeer] && [self isReadingConversation]);
}
- (void)notificationAlertsShowApplication:(JMNotificationAlerts *)alerts { [self showMainWindow:nil]; }
- (void)notificationAlerts:(JMNotificationAlerts *)alerts openPeer:(NSString *)peer account:(NSString *)account {
    NSString *active=self.notificationAlerts.accountUIN;
    if (active.length && ![active isEqualToString:account]) { [self showMainWindow:nil]; [self showError:@"Уведомление другого аккаунта" detail:[NSString stringWithFormat:@"Уведомление для UIN %@. Чтобы открыть переписку, выйдите из текущего аккаунта и войдите в этот UIN.",account]]; return; }
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
    [self showMainWindow:nil]; [self jumpToLatest:nil];
    dispatch_async(dispatch_get_main_queue(),^{ [self markSelectedRead]; });
}
- (void)conversationDidScroll:(NSNotification *)notification { [self markSelectedRead]; }
- (void)windowDidBecomeKey:(NSNotification *)notification { if (notification.object==self.chatWindow) [self markSelectedRead]; }
- (void)applicationDidBecomeActive:(NSNotification *)notification { [self markSelectedRead]; }
- (void)reloadContacts {
    NSString *query = [self.searchField stringValue] ?: @"";
    NSMutableArray *contacts = [NSMutableArray array];
    BOOL conversations = [self.sectionControl selectedSegment] == 1;
    NSSet *ids = conversations ? self.conversationPeers : self.serverContactIDs;
    for (NSString *peer in ids) {
        NSDictionary *contact = self.contacts[peer] ?: @{@"aimId":peer, @"friendly":peer, @"state":@"offline"};
        if (!conversations && self.selectedGroup.length && ![JMArray(contact[@"groups"]) containsObject:self.selectedGroup]) continue;
        if (![query length] || [JMName(contact) rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound || [JMString(contact[@"aimId"]) rangeOfString:query].location != NSNotFound) [contacts addObject:contact];
    }
    [contacts sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        if (conversations) {
            NSDictionary *lastA = [[self.history messagesForPeer:a[@"aimId"]] lastObject];
            NSDictionary *lastB = [[self.history messagesForPeer:b[@"aimId"]] lastObject];
            NSComparisonResult recency = [@([lastB[@"timestamp"] doubleValue]) compare:@([lastA[@"timestamp"] doubleValue])];
            if (recency != NSOrderedSame) return recency;
            return [JMName(a) localizedCaseInsensitiveCompare:JMName(b)];
        }
        BOOL aOnline = ![JMState(a) isEqualToString:@"Не в сети"], bOnline = ![JMState(b) isEqualToString:@"Не в сети"];
        if (aOnline != bOnline) return aOnline ? NSOrderedAscending : NSOrderedDescending;
        return [JMName(a) localizedCaseInsensitiveCompare:JMName(b)];
    }];
    self.visibleContacts = contacts; self.reloadingContacts = YES; [self.contactTable reloadData];
    NSInteger selected = -1;
    for (NSUInteger i = 0; i < [contacts count]; i++) if ([contacts[i][@"aimId"] isEqual:self.selectedPeer]) { selected = (NSInteger)i; break; }
    if (selected >= 0) [self.contactTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selected] byExtendingSelection:NO];
    else [self.contactTable deselectAll:nil];
    self.reloadingContacts = NO;
    [self.countLabel setStringValue:[NSString stringWithFormat:@"%@: %lu", conversations ? @"Переписок" : @"Контактов", (unsigned long)[contacts count]]];
    NSString *empty = [query length] ? @"Ничего не найдено.\nПопробуйте другое имя или UIN." : (conversations ? @"Переписок пока нет.\nВыберите контакт или нажмите «Написать…»." : (self.selectedGroup.length ? @"В этой группе пока нет контактов.\nДобавьте контакт или перенесите его из другой группы." : @"Контактов пока нет.\nНажмите «Добавить…», чтобы сохранить UIN на сервере."));
    [self.emptyListLabel setStringValue:empty]; [self.emptyListLabel setHidden:[contacts count] > 0];
    [self layoutChatWindow];
}
- (void)persistConversationPeers {
    if ([self.accountUIN length]) [[NSUserDefaults standardUserDefaults] setObject:[self.conversationPeers allObjects] forKey:[@"ConversationPeers." stringByAppendingString:self.accountUIN]];
}
- (void)changeSection:(id)sender {
    [self.searchField setStringValue:@""];
    [[self.searchField cell] setPlaceholderString:[self.sectionControl selectedSegment] == 1 ? @"Поиск переписок" : @"Поиск контактов"];
    [self layoutChatWindow]; [self reloadContacts];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return tableView==self.historyTable ? self.historyResults.count : self.visibleContacts.count; }
- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row { return [[JMContactRowView alloc] initWithFrame:NSZeroRect]; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView==self.historyTable) return JMString(self.historyResults[(NSUInteger)row][@"text"]);
    NSDictionary *contact = self.visibleContacts[(NSUInteger)row]; NSString *peer = contact[@"aimId"];
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
        NSString *title=[NSString stringWithFormat:@"%@%@ · %@",[message[@"outgoing"] boolValue] ? @"Вы → " : @"",name,date];
        NSString *snippet=JMHistorySnippet(JMString(message[@"text"]),self.historyResultsQuery);
        [cell configureName:title detail:snippet state:JMString(self.contacts[peer][@"state"]) unread:0]; [cell setAvatar:nil];
        [cell setToolTip:[NSString stringWithFormat:@"%@\nUIN %@ · %@\n%@",name,peer,date,snippet]]; return cell;
    }
    JMListCell *cell = [tableView makeViewWithIdentifier:@"person" owner:self];
    if (!cell) { cell = [[JMListCell alloc] initWithFrame:NSMakeRect(0,0,NSWidth([tableView bounds]),54)]; [cell setIdentifier:@"person"]; }
    NSDictionary *contact = self.visibleContacts[(NSUInteger)row]; NSString *peer = contact[@"aimId"];
    NSString *detail = [NSString stringWithFormat:@"%@ · %@", JMState(contact), peer];
    if ([self.sectionControl selectedSegment] == 1) {
        NSDictionary *last = [[self.history messagesForPeer:peer] lastObject];
        NSString *draft = JMString(self.drafts[peer]);
        if ([draft length]) detail = [@"Черновик: " stringByAppendingString:draft];
        else if (last) detail = [NSString stringWithFormat:@"%@%@", [last[@"outgoing"] boolValue] ? @"Вы: " : @"", JMString(last[@"text"])];
        else detail = @"Новая переписка";
        detail = [detail stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }
    [cell configureName:JMName(contact) detail:detail state:JMString(contact[@"state"]) unread:[self.unread[peer] integerValue]];
    if (self.sectionControl.selectedSegment==1) {
        NSDictionary *last=[[self.history messagesForPeer:peer] lastObject];
        [cell setTimestamp:last ? [self listTimestamp:[NSDate dateWithTimeIntervalSince1970:[last[@"timestamp"] doubleValue]]] : nil draft:JMString(self.drafts[peer]).length>0];
        if (last) [cell setTimestampTooltip:[NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:[last[@"timestamp"] doubleValue]] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle]];
    }
    [cell setToolTip:[NSString stringWithFormat:@"%@\nUIN %@ · %@%@",JMName(contact),peer,JMState(contact),[self.sectionControl selectedSegment]==1 ? [@"\n" stringByAppendingString:detail] : @""]];
    [cell setAvatar:[self.avatars imageForUIN:peer]];
    return cell;
}
- (NSString *)listTimestamp:(NSDate *)date {
    NSDateFormatter *format=[[NSDateFormatter alloc] init]; format.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"ru_RU"]; format.dateFormat=@"yyyy-MM-dd";
    NSDate *now=[NSDate date]; NSString *day=[format stringFromDate:date];
    if ([day isEqualToString:[format stringFromDate:now]]) format.dateFormat=@"HH:mm";
    else {
        NSDateComponents *offset=[[NSDateComponents alloc] init]; offset.day=-1;
        NSDate *yesterday=[[NSCalendar currentCalendar] dateByAddingComponents:offset toDate:now options:0];
        if ([day isEqualToString:[format stringFromDate:yesterday]]) return @"Вчера";
        format.dateFormat=@"dd.MM";
    }
    return [format stringFromDate:date];
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (notification.object==self.historyTable) { [self.historyOpenButton setEnabled:self.historyTable.selectedRow>=0]; return; }
    if (self.reloadingContacts) return;
    NSInteger row = [self.contactTable selectedRow]; if (row < 0 || row >= (NSInteger)[self.visibleContacts count]) return;
    BOOL navigatingList=self.chatWindow.firstResponder==self.contactTable;
    [self selectPeer:self.visibleContacts[(NSUInteger)row][@"aimId"]];
    if (navigatingList) [self.chatWindow makeFirstResponder:self.contactTable];
}
- (void)selectPeer:(NSString *)peer {
    self.highlightedMessageID=nil; self.historyHighlightQuery=nil;
    if (self.selectedPeer && ![self.selectedPeer isEqualToString:peer]) [self stopOutgoingTyping];
    if (self.selectedPeer) [self rememberDraftForPeer:self.selectedPeer text:self.composer.string];
    BOOL changed=![self.selectedPeer isEqualToString:peer];
    self.selectedPeer = peer; [self updateDockBadge];
    [self.conversationPeers addObject:peer]; [self persistConversationPeers];
    [self.composer setString:self.drafts[peer] ?: @""];
    if (changed) { [self.transcript setString:@""]; [self.composer.undoManager removeAllActions]; }
    [self.composer setSelectedRange:NSMakeRange(self.composer.string.length,0)];
    [self updatePeerLabel]; [self renderTranscript]; [self updateSendButton]; [self reloadContacts];
    [self.chatWindow makeFirstResponder:self.composer];
    [self updateTypingIndicator]; [self refreshPresenceForPeer:peer force:NO];
    [self markSelectedRead];
}
- (void)updatePeerLabel {
    NSDictionary *contact = self.contacts[self.selectedPeer ?: @""];
    [self.peerLabel setStringValue:contact ? JMName(contact) : @"Личные сообщения"];
    [self.peerDetail setStringValue:contact ? [NSString stringWithFormat:@"UIN %@ · %@%@", self.selectedPeer, JMState(contact), [self.serverContactIDs containsObject:self.selectedPeer] ? @" · В контактах" : @""] : @"Контакты и переписки Jimm.online"];
    [self.addPeerButton setHidden:!contact || [self.serverContactIDs containsObject:self.selectedPeer]];
    [self.peerAvatar setImage:[self.avatars imageForUIN:self.selectedPeer] ?: [NSImage imageNamed:NSImageNameUser]];
    [self.peerLabel setToolTip:self.peerLabel.stringValue]; [self.peerDetail setToolTip:self.peerDetail.stringValue];
    [self.profileButton setEnabled:contact!=nil];
    self.profileButton.hidden=!contact; self.historySearchButton.hidden=!contact; self.peerAvatar.hidden=!contact;
    [self layoutChatWindow];
}
- (void)renderTranscript {
    NSClipView *clip=self.transcript.enclosingScrollView.contentView;
    NSPoint position=clip.bounds.origin;
    NSRange selection=self.transcript.selectedRange;
    NSString *previousText=[self.transcript.string copy];
    BOOL follow=!selection.length && (!previousText.length || NSMaxY(clip.bounds)>=NSHeight(self.transcript.bounds)-24);
    self.transcriptRanges=[NSMutableDictionary dictionary];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
    NSDateFormatter *date=[[NSDateFormatter alloc] init]; date.dateFormat=@"HH:mm";
    NSDateFormatter *dayFormat=[[NSDateFormatter alloc] init]; dayFormat.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"ru_RU"]; dayFormat.dateFormat=@"d MMMM yyyy";
    NSDateFormatter *fullDate=[[NSDateFormatter alloc] init]; fullDate.dateFormat=@"dd.MM.yyyy HH:mm";
    NSString *previousDay=nil;
    NSMutableParagraphStyle *bodyStyle=[[NSMutableParagraphStyle alloc] init]; bodyStyle.lineSpacing=2;
    NSMutableParagraphStyle *headingStyle=[[NSMutableParagraphStyle alloc] init]; headingStyle.paragraphSpacing=3;
    for (NSDictionary *message in [self.history messagesForPeer:self.selectedPeer ?: @""]) {
        NSDate *sentAt=[NSDate dateWithTimeIntervalSince1970:[message[@"timestamp"] doubleValue]];
        NSString *day=[dayFormat stringFromDate:sentAt];
        if (![day isEqualToString:previousDay]) {
            NSMutableParagraphStyle *dayStyle=[[NSMutableParagraphStyle alloc] init]; dayStyle.alignment=NSCenterTextAlignment; dayStyle.paragraphSpacingBefore=previousDay ? 10 : 0; dayStyle.paragraphSpacing=12;
            [text appendAttributedString:[[NSAttributedString alloc] initWithString:[day stringByAppendingString:@"\n"] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:MAX(11,self.chatPreferences.size*0.8)],NSForegroundColorAttributeName:JMSecondaryTextColor(),NSParagraphStyleAttributeName:dayStyle}]];
            previousDay=day;
        }
        NSUInteger messageStart=text.length;
        BOOL outgoing=[message[@"outgoing"] boolValue];
        NSString *name=outgoing ? @"Вы" : JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer ?: @""});
        NSString *heading=[NSString stringWithFormat:@"%@  %@\n",name,[date stringFromDate:sentAt]];
        NSMutableAttributedString *header=[[NSMutableAttributedString alloc] initWithString:heading attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:MAX(10,self.chatPreferences.size-2)],NSForegroundColorAttributeName:JMSecondaryTextColor(),NSParagraphStyleAttributeName:headingStyle,NSToolTipAttributeName:[NSString stringWithFormat:@"%@ · %@",name,[fullDate stringFromDate:sentAt]]}];
        [header addAttributes:@{NSFontAttributeName:self.chatPreferences.headingFont,NSForegroundColorAttributeName:outgoing ? [NSColor colorWithCalibratedRed:0.25 green:0.35 blue:0.5 alpha:1] : [NSColor colorWithCalibratedRed:0.16 green:0.42 blue:0.17 alpha:1]} range:NSMakeRange(0,name.length)];
        [text appendAttributedString:header];
        NSString *plain=JMString(message[@"text"]);
        if (JMString(message[@"id"]).length) self.transcriptRanges[message[@"id"]]=[NSValue valueWithRange:NSMakeRange(text.length,plain.length)];
        NSMutableAttributedString *body=[[NSMutableAttributedString alloc] initWithString:[plain stringByAppendingString:@"\n\n"] attributes:@{NSFontAttributeName:self.chatPreferences.messageFont,NSForegroundColorAttributeName:[NSColor textColor],NSParagraphStyleAttributeName:bodyStyle}];
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
    if (follow) [self.transcript scrollRangeToVisible:NSMakeRange([text length], 0)];
    else { [[self.transcript layoutManager] ensureLayoutForTextContainer:self.transcript.textContainer]; [clip scrollToPoint:position]; [self.transcript.enclosingScrollView reflectScrolledClipView:clip]; }
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
    [self.composer setEditable:hasPeer];
    BOOL ready = self.client.connected && hasPeer && !self.sending;
    [self.presencePopup setEnabled:self.client.connected && !self.changingPresence];
    [self.historySearchButton setEnabled:self.history!=nil];
    [self.presenceFeedback setHidden:!self.client.connected];
    [self.reconnectButton setHidden:self.client.connected]; [self.reconnectButton setEnabled:!self.client.connected];
    [self.addContactButton setEnabled:[self canChangeRoster]];
    [self.addContactButton setTitle:self.addingContact ? @"Добавляем…" : @"Добавить…"];
    [self.addPeerButton setEnabled:[self canChangeRoster]]; [self updateGroupControls];
    BOOL hasText = [[[self.composer string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
    BOOL coolingDown = [self.sendNotBefore timeIntervalSinceNow] > 0;
    NSUInteger bytes=[self.composer.string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    [self.sendButton setEnabled:ready && hasText && bytes<=4000 && !coolingDown];
    [self.sendButton setTitle:self.sending ? @"Отправляем…" : (coolingDown ? @"Подождите…" : @"Отправить")];
    NSString *shortcut=self.chatPreferences.sendWithCommandReturn ? @"⌘Enter" : @"Enter";
    NSString *hint=[NSString stringWithFormat:@"%@ — отправить · Shift+Enter — новая строка",shortcut];
    if (!hasPeer) hint=@"Выберите контакт или нажмите «Написать…»";
    else if (self.draftSaveError) hint=@"Не удалось сохранить черновики на этом Mac";
    else if (self.sending) hint=@"Отправляем… Новый текст останется в черновике";
    else if (bytes>4000) hint=[NSString stringWithFormat:@"Текст: %lu / 4000 байт UTF-8 — разделите сообщение",(unsigned long)bytes];
    else if (!self.client.connected) hint=hasText && self.draftStore ? (self.draftsPending ? @"Нет связи · Сохраняем черновик…" : @"Нет связи · Черновик сохранён на этом Mac") : @"Можно писать черновик. Отправка — после подключения.";
    else if (hasText && self.draftStore) hint=self.draftsPending ? @"Сохраняем черновик…" : [NSString stringWithFormat:@"Черновик сохранён · %@ — отправить",shortcut];
    self.composerHint.stringValue=hint;
    self.composerHint.textColor=self.draftSaveError || bytes>4000 ? [NSColor redColor] : JMSecondaryTextColor();
    self.composerHint.toolTip=self.draftSaveError ? [NSString stringWithFormat:@"%@. Текст остаётся в окне; скопируйте его перед выходом. %@",hint,self.draftSaveError.localizedDescription] : hint;
    self.composer.toolTip=[NSString stringWithFormat:@"%@ — отправить. %@ Черновики автоматически сохраняются на этом Mac. Лимит сообщения — 4000 байт UTF-8.",shortcut,self.chatPreferences.sendWithCommandReturn ? @"Enter — новая строка." : @"Shift+Enter — новая строка."];
    self.sendButton.toolTip=[NSString stringWithFormat:@"Отправить сообщение выбранному собеседнику (%@)",shortcut];
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
    self.sending=YES; self.sendingPeer=peer; self.sendingText=text; self.sendingDraftWasEdited=NO;
    NSUInteger generation=self.conversationGeneration;
    [self updateSendButton]; [self stopOutgoingTyping];
    __weak JMAppDelegate *weakSelf=self;
    [self.client sendText:text to:peer completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self || generation!=self.conversationGeneration) return;
        BOOL edited=self.sendingDraftWasEdited;
        self.sending=NO; self.sendingPeer=nil; self.sendingText=nil;
        if ([self.selectedPeer isEqualToString:peer]) [self rememberDraftForPeer:peer text:self.composer.string];
        NSString *current=JMString(self.drafts[peer]);
        if (error) {
            NSString *detail=error.localizedDescription;
            if ([error.domain isEqualToString:JMAPIErrorDomain] && (error.code == 430 || error.code == 429)) {
                NSTimeInterval delay=MAX(1,[error.userInfo[@"retryAfter"] doubleValue]);
                self.sendNotBefore=[NSDate dateWithTimeIntervalSinceNow:delay];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((delay+0.1)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ if (generation==self.conversationGeneration) [self updateSendButton]; });
            }
            if ([error.domain isEqualToString:NSURLErrorDomain]) detail=@"Подтверждение не получено. Сообщение могло дойти; проверьте переписку перед повторной отправкой.";
            if (![current hasPrefix:text]) {
                NSString *recovered=current.length ? [NSString stringWithFormat:@"%@\n\n%@",text,current] : text;
                [self rememberDraftForPeer:peer text:recovered];
                if ([self.selectedPeer isEqualToString:peer]) { self.composer.string=recovered; [self.composer.undoManager removeAllActions]; }
                detail=[detail stringByAppendingString:@" Неотправленный текст возвращён в начало черновика."];
            }
            [self persistDraftsNow]; [self updateSendButton]; [self showError:@"Не удалось подтвердить отправку" detail:detail]; return;
        }
        NSString *msgID=JMString(data[@"msgId"]); if (!msgID.length) msgID=[[NSUUID UUID] UUIDString];
        NSTimeInterval timestamp=[JMString(data[@"timestamp"]) doubleValue];
        NSDictionary *message=@{@"peer":peer,@"outgoing":@YES,@"text":text,@"id":msgID,@"timestamp":@(timestamp>0 ? timestamp : [[NSDate date] timeIntervalSince1970]),@"name":@""};
        if ([self client:self.client receivedMessage:message]) {
            NSString *remaining=current;
            if ([current isEqualToString:text]) remaining=@"";
            else if (!edited && [current hasPrefix:text]) remaining=[current substringFromIndex:text.length];
            [self rememberDraftForPeer:peer text:remaining];
            if ([self.selectedPeer isEqualToString:peer]) { self.composer.string=remaining; [self.composer.undoManager removeAllActions]; }
            [self persistDraftsNow];
        }
        [self updateSendButton]; [self reloadContacts];
    }];
}
- (NSAlert *)newConversationPrompt {
    NSAlert *alert = [[NSAlert alloc] init]; [alert setMessageText:@"Написать по UIN"];
    [alert setInformativeText:@"Введите UIN собеседника в Jimm.online. Это откроет разговор; контакт-лист на сервере не изменится."];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 25)];
    [field setEditable:YES]; [field setSelectable:YES]; [field setEnabled:YES];
    [field setToolTip:@"Числовой UIN собеседника в Jimm.online"];
    [alert setAccessoryView:field];
    [alert addButtonWithTitle:@"Открыть"]; [[alert addButtonWithTitle:@"Отмена"] setKeyEquivalent:@"\e"];
    [[alert window] setInitialFirstResponder:field];
    return alert;
}
- (void)openConversation:(id)sender {
    NSAlert *alert = [self newConversationPrompt];
    NSTextField *field = (NSTextField *)[alert accessoryView];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *peer = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!JMValidUIN(peer)) { [self showError:@"Проверьте UIN" detail:@"UIN должен состоять из цифр."]; return; }
    if (!self.contacts[peer]) self.contacts[peer] = [@{@"aimId":peer, @"friendly":peer, @"state":@"offline"} mutableCopy];
    [self.sectionControl setSelectedSegment:1];
    [self.searchField setStringValue:@""]; [self selectPeer:peer];
}
- (NSAlert *)newAddContactPrompt {
    NSAlert *alert = [self newConversationPrompt]; [alert setMessageText:@"Добавить контакт"];
    [alert setInformativeText:@"Укажите UIN в Jimm.online. Контакт сохранится на сервере и будет доступен в других клиентах."];
    [[[alert buttons] firstObject] setTitle:@"Добавить"];
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,88)];
    [view addSubview:JMLabel(@"UIN",NSMakeRect(0,55,60,22),13,NO)];
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(68,53,292,25)]; field.tag=101; field.toolTip=@"Числовой UIN контакта в Jimm.online"; [view addSubview:field];
    [view addSubview:JMLabel(@"Группа",NSMakeRect(0,15,60,22),13,NO)];
    NSPopUpButton *groups=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(68,11,292,32) pullsDown:NO]; groups.tag=102;
    [groups addItemsWithTitles:self.serverGroups.count ? self.serverGroups : @[@"Buddies"]];
    if (self.selectedGroup.length) [groups selectItemWithTitle:self.selectedGroup];
    else if ([self.serverGroups containsObject:@"Buddies"]) [groups selectItemWithTitle:@"Buddies"];
    groups.toolTip=@"Группа, в которой контакт будет сохранён на сервере"; [view addSubview:groups];
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
    if (!JMValidUIN(uin)) { [self showError:@"Проверьте UIN" detail:@"UIN должен состоять из цифр."]; return; }
    if (![self canChangeRoster]) return;
    if ([self.serverContactIDs containsObject:uin]) { [self.contactNotice setStringValue:@"Этот UIN уже в контактах."]; return; }
    self.addingContact = YES; [self.contactNotice setStringValue:@"Сохраняем контакт на сервере…"]; [self updateSendButton];
    __weak JMAppDelegate *weakSelf = self;
    [self.client addContactWithUIN:uin group:group completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self = weakSelf; if (!self) return;
        self.addingContact = NO; [self updateSendButton];
        if (error) { [self.contactNotice setStringValue:@"Контакт не добавлен. Повторите попытку."]; [self showError:@"Не удалось добавить контакт" detail:[error localizedDescription]]; return; }
        if (!self.contacts[uin]) self.contacts[uin] = [@{@"aimId":uin, @"friendly":uin, @"state":@"offline"} mutableCopy];
        if (![JMString(data[@"resultCode"]) isEqualToString:@"alreadyExists"] && group.length) {
            NSMutableArray *groups=[JMArray(self.contacts[uin][@"groups"]) mutableCopy]; if (![groups containsObject:group]) [groups addObject:group];
            self.contacts[uin][@"groups"]=groups; self.contacts[uin][@"group"]=[groups firstObject] ?: @"";
            if (![self.serverGroups containsObject:group]) [self.serverGroups addObject:group];
            if (self.selectedGroup.length && ![self.selectedGroup isEqualToString:group]) self.selectedGroup=group;
        }
        [self.serverContactIDs addObject:uin];
        [self.contactNotice setStringValue:[JMString(data[@"resultCode"]) isEqualToString:@"alreadyExists"] ? @"Этот UIN уже был на сервере." : @"Контакт добавлен в Jimm.online."];
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
    [self.profileWindow setTitle:@"Профиль — JimmMac"]; [self.profileWindow setReleasedWhenClosed:NO];
    [self.profileWindow setContentView:[[JMWindowView alloc] initWithFrame:NSMakeRect(0,0,430,400)]];
    NSView *root=[self.profileWindow contentView];
    self.profileAvatar=[[NSImageView alloc] initWithFrame:NSMakeRect(24,306,64,64)]; [self.profileAvatar setImageScaling:NSImageScaleProportionallyUpOrDown]; [root addSubview:self.profileAvatar];
    self.profileName=JMLabel(@"",NSMakeRect(104,340,300,27),18,YES); [self.profileName setSelectable:YES]; [root addSubview:self.profileName];
    self.profileDetail=JMLabel(@"",NSMakeRect(105,308,300,25),12,NO); [self.profileDetail setSelectable:YES]; [root addSubview:self.profileDetail];
    self.profileStatus=JMLabel(@"",NSMakeRect(24,246,380,46),12,NO); [[self.profileStatus cell] setWraps:YES]; [self.profileStatus setTextColor:JMSecondaryTextColor()]; [root addSubview:self.profileStatus];
    [root addSubview:JMLabel(@"О себе",NSMakeRect(24,216,380,21),12,YES)];
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,65,382,147)]; [scroll setHasVerticalScroller:YES]; [scroll setBorderType:NSBezelBorder];
    self.profileAbout=[[NSTextView alloc] initWithFrame:[[scroll contentView] bounds]]; [self.profileAbout setEditable:NO]; [self.profileAbout setRichText:NO];
    [self.profileAbout setVerticallyResizable:YES]; [self.profileAbout setHorizontallyResizable:NO]; [self.profileAbout setMaxSize:NSMakeSize(FLT_MAX,FLT_MAX)];
    [[self.profileAbout textContainer] setContainerSize:NSMakeSize(NSWidth([[scroll contentView] bounds]),FLT_MAX)];
    [self.profileAbout setFont:[NSFont systemFontOfSize:13]]; [self.profileAbout setTextContainerInset:NSMakeSize(8,8)]; [self.profileAbout setAutoresizingMask:NSViewWidthSizable];
    [[self.profileAbout textContainer] setWidthTracksTextView:YES]; [scroll setDocumentView:self.profileAbout]; [root addSubview:scroll];
    self.profileRefresh=JMButton(@"Обновить",NSMakeRect(294,16,115,30),self,@selector(refreshProfile:)); [root addSubview:self.profileRefresh];
    [self.profileRefresh setToolTip:@"Заново загрузить профиль, статус и фотографию из Jimm.online"];
    [root addSubview:JMButton(@"Закрыть",NSMakeRect(16,16,105,30),self,@selector(closeProfile:))];
    [self.profileWindow center];
}
- (void)updateProfileCard {
    if (!self.profilePeer) return;
    NSDictionary *person=self.contacts[self.profilePeer] ?: @{@"aimId":self.profilePeer};
    [self.profileName setStringValue:JMName(person)];
    [self.profileName setToolTip:self.profileName.stringValue];
    [self.profileDetail setStringValue:[NSString stringWithFormat:@"UIN %@ · %@",self.profilePeer,JMState(person)]];
    NSString *status=JMString(person[@"statusMsg"]); [self.profileStatus setStringValue:status.length ? status : @"Статус без подписи"];
    [self.profileStatus setToolTip:self.profileStatus.stringValue]; [self.profileDetail setToolTip:self.profileDetail.stringValue];
    [self.profileAvatar setImage:[self.avatars imageForUIN:self.profilePeer] ?: [NSImage imageNamed:NSImageNameUser]];
    if (self.profileTexts[self.profilePeer]) [self.profileAbout setString:self.profileTexts[self.profilePeer]];
}
- (void)showProfile:(id)sender {
    if (!self.selectedPeer) return;
    [self createProfileWindow]; self.profilePeer=self.selectedPeer;
    [self.profileAbout setString:self.profileTexts[self.profilePeer] ?: @"Загружаем профиль…"];
    [self updateProfileCard]; [self.profileWindow makeKeyAndOrderFront:nil]; [self refreshProfile:nil];
}
- (void)refreshProfile:(id)sender {
    NSString *peer=self.profilePeer; if (!peer) return;
    if (!self.client.connected) { [self.profileAbout setString:self.profileTexts[peer] ?: @"Нет соединения. Подключитесь и нажмите «Обновить»."]; return; }
    [self.avatars refreshUIN:peer];
    [self refreshPresenceForPeer:peer force:YES]; [self.profileRefresh setEnabled:NO];
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchProfileForUIN:peer completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self) return;
        if (!error) {
            NSString *text=JMString(data[@"profile"]);
            BOOL html=[text rangeOfString:@"<HTML" options:NSCaseInsensitiveSearch].location!=NSNotFound;
            self.profileTexts[peer]=text.length ? JMPlainText(text,html) : @"Пользователь пока ничего не написал о себе.";
        }
        if (![peer isEqualToString:self.profilePeer]) return;
        [self.profileRefresh setEnabled:YES];
        if (error) [self.profileAbout setString:[NSString stringWithFormat:@"Не удалось загрузить профиль.\n%@\nНажмите «Обновить», чтобы повторить.",error.localizedDescription]];
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
    for (NSMenuItem *item in [self.presencePopup itemArray]) if ([[item representedObject] isEqualToString:state]) { [self.presencePopup selectItem:item]; break; }
    [self updateAccountLabel];
}
- (void)showOwnProfile:(id)sender {
    if (!JMValidUIN(self.accountUIN)) return;
    if (!self.ownProfileController) self.ownProfileController=[[JMOwnProfileController alloc] initWithClient:self.client avatars:self.avatars account:self.accountUIN];
    [self.ownProfileController openWithInfo:self.ownInfo];
}
- (void)changePresence:(id)sender {
    NSString *state=[[self.presencePopup selectedItem] representedObject]; if (!state || self.changingPresence) return;
    self.changingPresence=YES; [self.presenceFeedback setStringValue:@"Меняем статус и проверяем…"]; [self updateSendButton]; __weak JMAppDelegate *weakSelf=self;
    [self.client setPresenceState:state completion:^(NSDictionary *data, NSError *error) {
        JMAppDelegate *self=weakSelf; if (!self) return;
        self.changingPresence=NO; [self updateSendButton];
        if (error) { [self.presenceFeedback setStringValue:@"Не удалось сменить статус"]; [self client:self.client receivedOwnInfo:self.ownInfo]; [self showError:@"Не удалось сменить статус" detail:error.localizedDescription]; }
        else {
            [self client:self.client receivedOwnInfo:data];
            NSString *verification=JMString(data[@"_presenceVerification"]);
            if ([verification isEqualToString:@"confirmed"]) [self.presenceFeedback setStringValue:@"Статус подтверждён сервером"];
            else if ([verification isEqualToString:@"different"]) [self.presenceFeedback setStringValue:[NSString stringWithFormat:@"Сервер вернул: %@",JMState(data)]];
            else [self.presenceFeedback setStringValue:@"Статус принят; проверить пока не удалось"];
        }
        [self.presenceFeedback setToolTip:self.presenceFeedback.stringValue];
    }];
}
- (void)client:(JMAPIClient *)client receivedTyping:(NSDictionary *)typing {
    NSString *peer=JMString(typing[@"aimId"]); if (!JMValidUIN(peer)) return;
    BOOL wasTyping=[self.incomingTyping[peer] timeIntervalSinceNow]>0;
    if ([JMString(typing[@"typingStatus"]) isEqualToString:@"typing"]) {
        self.incomingTyping[peer]=[NSDate dateWithTimeIntervalSinceNow:8];
        if (!wasTyping && [peer isEqualToString:self.selectedPeer] && client.connected) [self.audioAlerts playEvent:@"typing"];
    }
    else [self.incomingTyping removeObjectForKey:peer];
    if ([peer isEqualToString:self.selectedPeer]) [self updateTypingIndicator];
}
- (void)updateTypingIndicator {
    [self.incomingTypingTimer invalidate]; self.incomingTypingTimer=nil;
    NSDate *expiry=self.incomingTyping[self.selectedPeer ?: @""]; NSTimeInterval remaining=[expiry timeIntervalSinceNow];
    NSString *text=@"";
    if (remaining>0 && self.client.connected) {
        text=[NSString stringWithFormat:@"%@ печатает…",JMName(self.contacts[self.selectedPeer] ?: @{@"aimId":self.selectedPeer})];
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
    [self stopOutgoingTyping]; [self.incomingTyping removeAllObjects]; [self updateTypingIndicator]; [self.client reconnect];
}
- (void)workspaceDidWake:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{ if (self.accountUIN.length) [self reconnect:nil]; });
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [self flushDrafts]; if (![self canLeaveDrafts]) return NSTerminateCancel;
    self.terminating=YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self]; [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [self stopOutgoingTyping]; [self.incomingTypingTimer invalidate]; [self.avatars invalidate]; [self.audioAlerts stop]; [self.notificationAlerts invalidate]; [self.client disconnect];
    // Finish only this app's queued keychain work, keeping the UI responsive.
    dispatch_async(self.loginStoreQueue,^{ dispatch_async(dispatch_get_main_queue(),^{
        if (self.quitCredentialError.length) [self showError:@"Вход не сохранён" detail:self.quitCredentialError];
        [NSApp replyToApplicationShouldTerminate:YES];
    }); });
    return NSTerminateLater;
}
- (BOOL)windowShouldClose:(id)sender {
    if (sender==self.chatWindow) [self flushDrafts];
    // Closing a chat window keeps long polling and sound alerts alive, as on Mac.
    [sender orderOut:nil]; return NO;
}
- (void)showMainWindow:(id)sender {
    NSWindow *window=self.notificationAlerts.accountUIN.length || self.client.connected ? self.chatWindow : self.loginWindow;
    if (window.isMiniaturized) [window deminiaturize:nil]; [window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self showMainWindow:nil]; return YES;
}
@end
