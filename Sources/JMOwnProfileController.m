#import "JMLocalization.h"
#import "JMOwnProfileController.h"
#import "JMKeyboard.h"
#import "JMStyle.h"
#import "JMTheme.h"
#import "JMAPIClient.h"
#import "JMAvatarStore.h"
#import "JMProtocol.h"
#import <float.h>

@interface JMProfileBackgroundView : NSView
@end
@implementation JMProfileBackgroundView
- (void)drawRect:(NSRect)dirtyRect { [JMThemeBackground() setFill]; NSRectFill(dirtyRect); }
@end

static NSTextField *Label(NSString *text, NSRect frame, CGFloat size, BOOL bold) {
    NSTextField *field=[[NSTextField alloc] initWithFrame:frame];
    field.stringValue=text; field.editable=NO; field.selectable=YES; field.bordered=NO; field.drawsBackground=NO;
    field.font=bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingTail]; field.toolTip=text; return field;
}
static NSButton *Button(NSString *title, NSRect frame, id target, SEL action) {
    NSButton *button=[[JMThemedButton alloc] initWithFrame:frame]; button.title=title; button.bezelStyle=NSRoundedBezelStyle;
    button.target=target; button.action=action; button.toolTip=title; return button;
}
@interface JMOwnProfileController ()
@property(nonatomic, strong) JMAPIClient *client;
@property(nonatomic, strong) JMAvatarStore *avatars;
@property(nonatomic, copy) NSString *account;
@property(nonatomic, strong) NSImageView *avatar;
@property(nonatomic, strong) NSTextField *name;
@property(nonatomic, strong) NSTextField *firstNameField;
@property(nonatomic, strong) NSTextField *lastNameField;
@property(nonatomic, strong) NSTextField *statusField;
@property(nonatomic, strong) NSTextView *about;
@property(nonatomic, strong) NSTextField *counter;
@property(nonatomic, strong) NSTextField *feedback;
@property(nonatomic, strong) NSButton *chooseButton;
@property(nonatomic, strong) NSButton *revertButton;
@property(nonatomic, strong) NSButton *reloadButton;
@property(nonatomic, strong) NSButton *closeButton;
@property(nonatomic, strong) NSButton *saveButton;
@property(nonatomic, copy) NSString *originalAbout;
@property(nonatomic, copy) NSString *originalStatus;
@property(nonatomic, copy) NSString *originalFirstName;
@property(nonatomic, copy) NSString *originalLastName;
@property(nonatomic, strong) NSData *pendingAvatar;
@property(nonatomic, strong) NSOpenPanel *filePanel;
@property(nonatomic) BOOL loaded;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL invalidated;
@property(nonatomic) BOOL closeAfterSave;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) NSUInteger savedCount;
@property(nonatomic) BOOL wroteAbout;
@property(nonatomic) BOOL wroteStatus;
@property(nonatomic) BOOL wroteNames;
@property(nonatomic, strong) NSSet *writtenNameKeys;
@end
@implementation JMOwnProfileController
- (id)initWithClient:(JMAPIClient *)client avatars:(JMAvatarStore *)avatars account:(NSString *)uin {
    NSWindow *window=[[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,520,644) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
    self=[super initWithWindow:window]; if (!self) return nil;
    self.client=client; self.avatars=avatars; self.account=uin;
    window.title=JML(@"Мой профиль — JimmMac"); window.releasedWhenClosed=NO; window.delegate=self;
    window.contentView=[[JMProfileBackgroundView alloc] initWithFrame:NSMakeRect(0,0,520,644)];
    NSView *root=window.contentView;
    self.avatar=[[NSImageView alloc] initWithFrame:NSMakeRect(24,528,80,80)]; self.avatar.imageScaling=NSImageScaleProportionallyUpOrDown;
    self.avatar.toolTip=JML(@"Ваш аватар в Jimm.online"); [root addSubview:self.avatar];
    self.name=Label(JML(@"Мой профиль"),NSMakeRect(120,582,376,27),18,YES); [root addSubview:self.name];
    [root addSubview:Label([NSString stringWithFormat:@"UIN %@",uin],NSMakeRect(120,560,376,22),12,NO)];
    self.chooseButton=Button(JML(@"Выбрать фото…"),NSMakeRect(114,521,164,30),self,@selector(chooseAvatar:));
    self.chooseButton.toolTip=JML(@"Выбрать JPEG, PNG или GIF с этого Mac. Загрузка начнётся после «Сохранить»"); [root addSubview:self.chooseButton];
    self.revertButton=Button(JML(@"Отменить выбор"),NSMakeRect(282,521,162,30),self,@selector(revertAvatar:)); [root addSubview:self.revertButton];
    [root addSubview:Label(JML(@"Квадрат из центра фото · до 256 × 256 · JPEG до 64 КБ"),NSMakeRect(24,491,472,20),11,NO)];
    [root addSubview:Label(JML(@"Имя"),NSMakeRect(24,456,224,20),13,YES)];
    [root addSubview:Label(JML(@"Фамилия"),NSMakeRect(268,456,228,20),13,YES)];
    self.firstNameField=[[NSTextField alloc] initWithFrame:NSMakeRect(24,426,224,25)]; self.firstNameField.delegate=self; self.firstNameField.font=[NSFont systemFontOfSize:13];
    self.firstNameField.toolTip=JML(@"Имя в общедоступной анкете: до 128 символов, без переносов строки"); [root addSubview:self.firstNameField];
    self.lastNameField=[[NSTextField alloc] initWithFrame:NSMakeRect(268,426,228,25)]; self.lastNameField.delegate=self; self.lastNameField.font=[NSFont systemFontOfSize:13];
    self.lastNameField.toolTip=JML(@"Фамилия в общедоступной анкете: до 128 символов, без переносов строки"); [root addSubview:self.lastNameField];
    [root addSubview:Label(JML(@"Подпись статуса"),NSMakeRect(24,373,472,20),13,YES)];
    self.statusField=[[NSTextField alloc] initWithFrame:NSMakeRect(24,343,472,25)]; self.statusField.delegate=self;
    self.statusField.font=[NSFont systemFontOfSize:13]; self.statusField.toolTip=JML(@"Подпись под вашим именем: до 256 символов. Пустое поле убирает подпись. X-статус сохраняется");
    [root addSubview:self.statusField];
    [root addSubview:Label(JML(@"О себе"),NSMakeRect(24,307,472,20),13,YES)];
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,149,472,150)];
    scroll.borderType=NSBezelBorder; scroll.hasVerticalScroller=YES;
    self.about=[[JMFormTextView alloc] initWithFrame:scroll.contentView.bounds]; self.about.delegate=self;
    self.about.richText=NO; self.about.font=[NSFont systemFontOfSize:13]; self.about.allowsUndo=YES;
    self.about.verticallyResizable=YES; self.about.horizontallyResizable=NO; self.about.maxSize=NSMakeSize(FLT_MAX,FLT_MAX);
    self.about.textContainer.containerSize=NSMakeSize(NSWidth(scroll.contentView.bounds),FLT_MAX);
    self.about.textContainer.widthTracksTextView=YES; self.about.autoresizingMask=NSViewWidthSizable; self.about.textContainerInset=NSMakeSize(6,6);
    self.about.toolTip=JML(@"Общедоступный текст профиля: не больше 4096 байт UTF-8. Пустой текст очищает профиль");
    scroll.documentView=self.about; [root addSubview:scroll];
    self.counter=Label(@"",NSMakeRect(24,124,472,20),11,NO); [root addSubview:self.counter];
    self.feedback=Label(@"",NSMakeRect(24,55,472,60),12,NO); [[self.feedback cell] setWraps:YES]; [[self.feedback cell] setLineBreakMode:NSLineBreakByWordWrapping]; [root addSubview:self.feedback];
    self.reloadButton=Button(JML(@"Обновить"),NSMakeRect(18,16,116,30),self,@selector(loadProfile:)); self.reloadButton.toolTip=JML(@"Перечитать профиль и аватар с сервера. Сначала сохраните изменения или закройте окно"); [root addSubview:self.reloadButton];
    self.closeButton=Button(JML(@"Закрыть"),NSMakeRect(272,16,108,30),self,@selector(closeEditor:)); self.closeButton.keyEquivalent=@"\e"; [root addSubview:self.closeButton];
    self.saveButton=Button(JML(@"Сохранить"),NSMakeRect(382,16,120,30),self,@selector(saveProfile:));
    self.saveButton.keyEquivalent=@"s"; self.saveButton.keyEquivalentModifierMask=NSCommandKeyMask;
    self.saveButton.toolTip=JML(@"Сохранить изменённые поля и выбранную фотографию в Jimm.online (Cmd+S)"); [root addSubview:self.saveButton];
    [self.firstNameField setNextKeyView:self.lastNameField]; [self.lastNameField setNextKeyView:self.statusField];
    [self.statusField setNextKeyView:self.about]; [self.about setNextKeyView:self.saveButton];
    [window center]; [self updateControls]; return self;
}
- (void)showFeedback:(NSString *)text { self.feedback.stringValue=text; self.feedback.toolTip=text; }
- (BOOL)dirty { return self.loaded && (![self.firstNameField.stringValue isEqualToString:self.originalFirstName] || ![self.lastNameField.stringValue isEqualToString:self.originalLastName] || ![self.about.string isEqualToString:self.originalAbout] || ![self.statusField.stringValue isEqualToString:self.originalStatus] || self.pendingAvatar!=nil); }
- (BOOL)validInput {
    return JMValidRosterName(self.firstNameField.stringValue,YES) && JMValidRosterName(self.lastNameField.stringValue,YES) && [self.about.string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=4096 && self.statusField.stringValue.length<=256 &&
        [self.statusField.stringValue rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location==NSNotFound;
}
- (void)updateControls {
    BOOL editable=self.loaded && !self.busy && !self.invalidated;
    self.about.editable=editable; self.statusField.editable=editable; self.statusField.enabled=editable;
    self.firstNameField.editable=editable; self.firstNameField.enabled=editable; self.lastNameField.editable=editable; self.lastNameField.enabled=editable;
    self.chooseButton.enabled=editable; self.revertButton.enabled=editable && self.pendingAvatar!=nil;
    self.reloadButton.enabled=!self.busy && ![self dirty] && self.client.connected && !self.invalidated;
    self.saveButton.enabled=editable && self.client.connected && [self dirty] && [self validInput];
    self.closeButton.enabled=!self.busy;
    NSUInteger bytes=[self.about.string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    self.counter.stringValue=[NSString stringWithFormat:JML(@"О себе: %lu / 4096 байт UTF-8 · Подпись: %lu / 256"),(unsigned long)bytes,(unsigned long)self.statusField.stringValue.length];
    self.counter.textColor=[self validInput] ? [NSColor controlTextColor] : [NSColor redColor];
    self.counter.toolTip=self.counter.stringValue;
}
- (void)openWithInfo:(NSDictionary *)info {
    if (self.invalidated) return;
    [self updateOwnInfo:info]; [self showWindow:nil]; [self.window makeKeyAndOrderFront:nil];
    if (!self.loaded && !self.busy) [self loadProfile:nil];
}
- (void)updateOwnInfo:(NSDictionary *)info {
    NSString *name=JMString(info[@"friendly"]); if (name.length) { self.name.stringValue=name; self.name.toolTip=name; }
    [self avatarUpdated];
}
- (void)avatarUpdated { if (!self.pendingAvatar) self.avatar.image=[self.avatars imageForUIN:self.account] ?: [NSImage imageNamed:NSImageNameUser]; }
- (void)connectionChanged {
    if (!self.client.connected && self.window.isVisible && !self.busy) [self showFeedback:JML(@"Нет соединения. Черновик остаётся в окне; сохранить можно после подключения.")];
    [self updateControls];
}
- (void)loadProfile:(id)sender {
    if (self.busy || [self dirty] || self.invalidated) return;
    if (!self.client.connected) { [self connectionChanged]; return; }
    self.busy=YES; [self showFeedback:JML(@"Загружаем профиль…")]; [self updateControls];
    NSUInteger generation=++self.generation;
    __weak JMOwnProfileController *weakSelf=self;
    [self.client fetchProfileForUIN:self.account completion:^(NSDictionary *profile,NSError *error) {
        JMOwnProfileController *self=weakSelf; if (!self) return;
        if (self.invalidated || self.generation!=generation) return;
        if (error || ![profile[@"profile"] isKindOfClass:[NSString class]]) { self.busy=NO; [self showFeedback:[JML(@"Не удалось загрузить профиль. ") stringByAppendingString:error.localizedDescription ?: JML(@"Сервер не вернул текст профиля. Нажмите «Обновить».")]]; [self updateControls]; return; }
        NSString *text=JMString(profile[@"profile"]);
        [self.client fetchPresenceForUIN:self.account completion:^(NSDictionary *presence,NSError *readError) {
            JMOwnProfileController *self=weakSelf; if (!self) return;
            if (self.invalidated || self.generation!=generation) return;
            NSDictionary *own=[self ownUser:presence]; self.busy=NO;
            if (readError || !own) { [self showFeedback:JML(@"Не удалось загрузить подпись статуса. Нажмите «Обновить», чтобы повторить.")]; [self updateControls]; return; }
            self.busy=YES;
            [self.client fetchOwnDirectoryProfile:^(NSDictionary *directory,NSError *directoryError) {
                JMOwnProfileController *self=weakSelf; if (!self || self.invalidated || self.generation!=generation) return;
                self.busy=NO;
                if (directoryError) { [self showFeedback:directoryError.localizedDescription]; [self updateControls]; return; }
                self.originalAbout=text; self.originalStatus=JMString(own[@"statusMsg"]);
                self.originalFirstName=JMString(directory[@"firstName"]); self.originalLastName=JMString(directory[@"lastName"]);
                self.firstNameField.stringValue=self.originalFirstName; self.lastNameField.stringValue=self.originalLastName;
                self.about.string=text; self.statusField.stringValue=self.originalStatus; self.loaded=YES;
                [self.about.undoManager removeAllActions]; [self updateOwnInfo:own];
                [self.avatars refreshUIN:self.account]; [self avatarUpdated];
                [self showFeedback:JML(@"Изменения будут видны другим пользователям после сохранения.")]; [self updateControls];
            }];
        }];
    }];
}
- (NSDictionary *)ownUser:(NSDictionary *)presence {
    for (NSDictionary *entry in JMArray(presence[@"users"])) if ([JMString(JMDictionary(entry)[@"aimId"]) isEqualToString:self.account]) return JMDictionary(entry);
    return nil;
}
- (void)controlTextDidChange:(NSNotification *)note { [self edited]; }
- (void)textDidChange:(NSNotification *)note { [self edited]; }
- (void)edited {
    NSString *invalid=(!JMValidRosterName(self.firstNameField.stringValue,YES) || !JMValidRosterName(self.lastNameField.stringValue,YES)) ? JML(@"Имя и фамилия: до 128 символов каждое, без переносов строки.") : JML(@"Сократите текст до указанного лимита. Подпись должна быть в одну строку.");
    [self showFeedback:[self validInput] ? ([self dirty] ? JML(@"Есть несохранённые изменения.") : JML(@"Изменений нет.")) : invalid];
    [self updateControls];
}
- (void)chooseAvatar:(id)sender {
    if (!self.loaded || self.busy || self.invalidated) return;
    self.filePanel=[NSOpenPanel openPanel]; self.filePanel.allowedFileTypes=@[@"jpg",@"jpeg",@"png",@"gif"];
    self.filePanel.allowsMultipleSelection=NO; self.filePanel.canChooseDirectories=NO; self.filePanel.canChooseFiles=YES;
    self.filePanel.title=JML(@"Фото профиля"); self.filePanel.prompt=JML(@"Выбрать");
    [self.filePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        NSURL *url=self.filePanel.URL; self.filePanel=nil;
        if (result!=NSFileHandlingPanelOKButton || self.invalidated) return;
        NSNumber *size=nil, *regular=nil; [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL]; [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:NULL];
        if (!regular.boolValue || !size || size.unsignedLongLongValue>20*1024*1024) { [self showFeedback:JML(@"Выберите обычный файл JPEG, PNG или GIF до 20 МБ.")]; return; }
        self.busy=YES; [self showFeedback:JML(@"Готовим фотографию…")]; [self updateControls];
        NSUInteger generation=self.generation;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
            NSError *error=nil; NSData *data=[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];
            NSData *jpeg=data ? JMPrepareAvatar(data,&error) : nil;
            dispatch_async(dispatch_get_main_queue(),^{
                if (self.invalidated || self.generation!=generation) return;
                self.busy=NO;
                if (jpeg) [self stageAvatar:jpeg];
                else { [self showFeedback:error.localizedDescription ?: JML(@"Не удалось прочитать фотографию.")]; [self updateControls]; }
            });
        });
    }];
}
- (void)stageAvatar:(NSData *)jpeg {
    NSImage *image=JMDecodeAvatar(jpeg); if (!image || self.invalidated) return;
    self.pendingAvatar=jpeg; self.avatar.image=image;
    [self showFeedback:JML(@"Предпросмотр нового аватара. Нажмите «Сохранить», чтобы загрузить его в Jimm.online.")]; [self updateControls];
}
- (void)revertAvatar:(id)sender { self.pendingAvatar=nil; [self avatarUpdated]; [self edited]; }
- (void)saveProfile:(id)sender {
    [self.window makeFirstResponder:nil];
    if (!self.loaded || self.busy || self.invalidated || ![self dirty] || ![self validInput] || !self.client.connected) { self.closeAfterSave=NO; [self updateControls]; return; }
    self.busy=YES; self.savedCount=0; self.wroteAbout=NO; self.wroteStatus=NO; self.wroteNames=NO; self.writtenNameKeys=nil;
    [self showFeedback:JML(@"Сохраняем изменения…")]; [self updateControls]; [self saveNext];
}
- (void)saveNext {
    if (self.invalidated) return;
    __weak JMOwnProfileController *weakSelf=self;
    NSMutableDictionary *names=[NSMutableDictionary dictionary];
    if (![self.firstNameField.stringValue isEqualToString:self.originalFirstName]) names[@"firstName"]=self.firstNameField.stringValue;
    if (![self.lastNameField.stringValue isEqualToString:self.originalLastName]) names[@"lastName"]=self.lastNameField.stringValue;
    if (names.count) {
        [self.client setOwnNameFields:names completion:^(NSDictionary *data,NSError *error) {
            JMOwnProfileController *self=weakSelf; if (!self || self.invalidated) return;
            if (error) { [self saveFailed:error]; return; }
            if (names[@"firstName"]) self.originalFirstName=names[@"firstName"];
            if (names[@"lastName"]) self.originalLastName=names[@"lastName"];
            self.savedCount++; self.wroteNames=YES; self.writtenNameKeys=[NSSet setWithArray:names.allKeys]; [self saveNext];
        }];
    } else if (![self.about.string isEqualToString:self.originalAbout]) {
        NSString *text=self.about.string;
        [self.client setOwnProfileText:text completion:^(NSDictionary *data,NSError *error) {
            JMOwnProfileController *self=weakSelf; if (!self) return;
            if (self.invalidated) return; if (error) { [self saveFailed:error]; return; }
            self.originalAbout=text; self.savedCount++; self.wroteAbout=YES; [self saveNext];
        }];
    } else if (![self.statusField.stringValue isEqualToString:self.originalStatus]) {
        NSString *text=self.statusField.stringValue;
        [self.client setOwnStatusMessage:text completion:^(NSDictionary *data,NSError *error) {
            JMOwnProfileController *self=weakSelf; if (!self) return;
            if (self.invalidated) return; if (error) { [self saveFailed:error]; return; }
            self.originalStatus=text; self.savedCount++; self.wroteStatus=YES; [self saveNext];
        }];
    } else if (self.pendingAvatar) {
        NSData *jpeg=self.pendingAvatar;
        [self.client uploadOwnAvatar:jpeg completion:^(NSDictionary *data,NSError *error) {
            JMOwnProfileController *self=weakSelf; if (!self) return;
            if (self.invalidated) return; if (error) { [self saveFailed:error]; return; }
            self.pendingAvatar=nil; self.savedCount++; [self.avatars storeUploadedAvatar:jpeg forUIN:self.account]; [self avatarUpdated]; [self saveNext];
        }];
    } else [self verifySavedFields];
}
- (void)saveFailed:(NSError *)error {
    self.busy=NO; self.closeAfterSave=NO;
    [self showFeedback:[NSString stringWithFormat:JML(@"%@%@ Несохранённые изменения оставлены в окне."),self.savedCount ? JML(@"Часть изменений сохранена. ") : @"",error.localizedDescription]]; [self updateControls];
}
- (void)verifySavedFields {
    if (!self.wroteAbout && !self.wroteStatus && !self.wroteNames) { [self finishedVerification:YES different:NO]; return; }
    [self showFeedback:JML(@"Проверяем сохранённые поля на сервере…")];
    __weak JMOwnProfileController *weakSelf=self;
    [self.client fetchProfileForUIN:self.account completion:^(NSDictionary *profile,NSError *error) {
        JMOwnProfileController *self=weakSelf; if (!self) return;
        if (self.invalidated) return;
        BOOL aboutReadable=!error && [profile[@"profile"] isKindOfClass:[NSString class]];
        BOOL different=self.wroteAbout && aboutReadable && ![profile[@"profile"] isEqualToString:self.originalAbout];
        if (self.wroteAbout && aboutReadable) self.originalAbout=profile[@"profile"];
        [self.client fetchPresenceForUIN:self.account completion:^(NSDictionary *presence,NSError *readError) {
            JMOwnProfileController *self=weakSelf; if (!self) return;
            if (self.invalidated) return;
            NSDictionary *own=[self ownUser:presence]; BOOL statusReadable=!readError && own!=nil;
            BOOL mismatch=different || (self.wroteStatus && statusReadable && ![JMString(own[@"statusMsg"]) isEqualToString:self.originalStatus]);
            if (self.wroteStatus && statusReadable) self.originalStatus=JMString(own[@"statusMsg"]);
            if (statusReadable && [self.client.delegate respondsToSelector:@selector(client:receivedOwnInfo:)]) [self.client.delegate client:self.client receivedOwnInfo:own];
            BOOL readable=(!self.wroteAbout || aboutReadable) && (!self.wroteStatus || statusReadable);
            if (!self.wroteNames) { [self finishedVerification:readable different:mismatch]; return; }
            [self.client fetchOwnDirectoryProfile:^(NSDictionary *directory,NSError *directoryError) {
                JMOwnProfileController *self=weakSelf; if (!self || self.invalidated) return;
                BOOL first=[self.writtenNameKeys containsObject:@"firstName"], last=[self.writtenNameKeys containsObject:@"lastName"];
                BOOL nameMismatch=!directoryError && ((first && ![JMString(directory[@"firstName"]) isEqualToString:self.originalFirstName]) || (last && ![JMString(directory[@"lastName"]) isEqualToString:self.originalLastName]));
                if (!directoryError) {
                    self.originalFirstName=JMString(directory[@"firstName"]); self.originalLastName=JMString(directory[@"lastName"]);
                    if (!first) self.firstNameField.stringValue=self.originalFirstName;
                    if (!last) self.lastNameField.stringValue=self.originalLastName;
                }
                [self finishedVerification:readable && !directoryError different:mismatch || nameMismatch];
            }];
        }];
    }];
}
- (void)finishedVerification:(BOOL)verified different:(BOOL)different {
    self.busy=NO;
    [self showFeedback:different ? JML(@"Сервер вернул другие значения. Ваш текст оставлен в окне; его можно сохранить ещё раз.") : (verified ? JML(@"Изменения сохранены на сервере.") : JML(@"Сервер принял изменения, но повторная проверка полей недоступна. Проверьте их кнопкой «Обновить»."))];
    [self updateControls];
    if (self.closeAfterSave && !different) { self.closeAfterSave=NO; [self.window orderOut:nil]; }
    self.closeAfterSave=NO;
}
- (void)closeEditor:(id)sender { [self.window performClose:sender]; }
- (BOOL)windowShouldClose:(id)sender {
    [self.window makeFirstResponder:nil];
    if (self.busy) return NO;
    if (![self dirty]) return YES;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=JML(@"Сохранить изменения профиля?");
    alert.informativeText=JML(@"Текст и выбранная фотография ещё не отправлены в Jimm.online.");
    [alert addButtonWithTitle:JML(@"Сохранить")]; [alert addButtonWithTitle:JML(@"Не сохранять")]; [[alert addButtonWithTitle:JML(@"Отмена")] setKeyEquivalent:@"\e"];
    NSInteger answer=[alert runModal];
    if (answer==NSAlertFirstButtonReturn) { self.closeAfterSave=YES; [self saveProfile:nil]; return NO; }
    if (answer==NSAlertSecondButtonReturn) { self.pendingAvatar=nil; self.loaded=NO; return YES; }
    return NO;
}
- (void)invalidate {
    self.invalidated=YES; self.generation++; self.client=nil;
    [self.filePanel cancel:nil]; self.filePanel=nil; self.pendingAvatar=nil; self.about.string=@""; self.statusField.stringValue=@"";
    self.firstNameField.stringValue=@""; self.lastNameField.stringValue=@""; self.originalFirstName=nil; self.originalLastName=nil;
    self.originalAbout=nil; self.originalStatus=nil; self.avatar.image=nil; [self.window orderOut:nil];
}
@end
