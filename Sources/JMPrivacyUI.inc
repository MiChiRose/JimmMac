- (NSNumber *)typingPreference:(NSDictionary *)preferences {
    id value=preferences[@"discloseTyping"];
    if ([value isKindOfClass:[NSNumber class]] || [@[@"0",@"1"] containsObject:JMString(value)]) return @([value boolValue]);
    return nil;
}
- (void)showAccountPrivacy:(id)sender {
    if (!self.client.connected || self.changingPrivacy) return;
    NSUInteger session=self.loginAttemptSerial;
    self.changingPrivacy=YES;
    __weak JMAppDelegate *weakSelf=self;
    [self.client fetchPrivacy:^(NSDictionary *privacy,NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || session!=self.loginAttemptSerial) return;
        if (error) { [self finishAccountPrivacy:error]; return; }
        [self.client fetchAccountPreferences:^(NSDictionary *preferences,NSError *readError) {
            JMAppDelegate *self=weakSelf;
            if (!self || session!=self.loginAttemptSerial) return;
            if (readError) { [self finishAccountPrivacy:readError]; return; }
            [self editAccountPrivacy:privacy preferences:preferences session:session];
        }];
    }];
}
- (void)finishAccountPrivacy:(NSError *)error {
    self.changingPrivacy=NO;
    if (error) [self showError:JML(@"Настройки приватности") detail:error.localizedDescription];
}
- (void)editAccountPrivacy:(NSDictionary *)privacy preferences:(NSDictionary *)preferences session:(NSUInteger)session {
    NSArray *modes=@[@"permitAll",@"denySome",@"permitOnList",@"permitSome",@"denyAll"];
    NSArray *titles=@[JML(@"Все"),JML(@"Все, кроме заблокированных"),JML(@"Только контакты"),JML(@"Только разрешённые UIN"),JML(@"Никто")];
    NSAlert *alert=[[NSAlert alloc] init];
    alert.messageText=JML(@"Настройки приватности");
    alert.informativeText=JML(@"Эти настройки хранятся в Jimm.online и действуют для аккаунта.");
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,384,144)];
    [view addSubview:JMLabel(JML(@"Кто может писать"),NSMakeRect(0,119,382,21),13,YES)];
    NSPopUpButton *mode=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,89,384,28) pullsDown:NO];
    [mode addItemsWithTitles:titles];
    [mode selectItemAtIndex:[modes indexOfObject:privacy[@"pdMode"]]];
    [view addSubview:mode];
    [view addSubview:JMLabel(JML(@"Разрешённые UIN через запятую"),NSMakeRect(0,64,382,20),13,YES)];
    NSTextField *allowed=[[NSTextField alloc] initWithFrame:NSMakeRect(0,36,384,23)];
    NSArray *originalUINs=JMAllowedUINs(privacy);
    allowed.stringValue=[originalUINs componentsJoinedByString:@", "];
    allowed.toolTip=JML(@"Список используется в режиме «Только разрешённые UIN».");
    [view addSubview:allowed];
    NSButton *typing=JMCheckbox(JML(@"Показывать собеседникам, что я печатаю"),NSMakeRect(0,2,382,25),nil,NULL);
    NSNumber *disclose=[self typingPreference:preferences];
    BOOL wasTyping=disclose ? disclose.boolValue : YES;
    typing.enabled=disclose!=nil;
    typing.state=wasTyping ? NSOnState : NSOffState;
    [view addSubview:typing];
    alert.accessoryView=view;
    [alert addButtonWithTitle:JML(@"Сохранить")];
    [alert addButtonWithTitle:JML(@"Отмена")].keyEquivalent=@"\e";
    if (session!=self.loginAttemptSerial || [alert runModal]!=NSAlertFirstButtonReturn || session!=self.loginAttemptSerial || !self.client.connected) {
        if (session==self.loginAttemptSerial) self.changingPrivacy=NO;
        return;
    }
    NSMutableOrderedSet *newUINs=[NSMutableOrderedSet orderedSet];
    for (NSString *token in [allowed.stringValue componentsSeparatedByString:@","]) {
        NSString *uin=[token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!uin.length) continue;
        if (!JMValidUIN(uin) || [uin isEqual:self.accountUIN] || newUINs.count>=100) {
            [self finishAccountPrivacy:[NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Укажите до 100 чужих числовых UIN через запятую.")}]];
            return;
        }
        [newUINs addObject:uin];
    }
    NSString *selected=modes[(NSUInteger)mode.indexOfSelectedItem];
    BOOL wantTyping=typing.state==NSOnState;
    NSSet *old=[NSSet setWithArray:originalUINs], *desired=newUINs.set;
    NSMutableSet *added=[desired mutableCopy], *removed=[old mutableCopy];
    [added minusSet:old];
    [removed minusSet:desired];
    BOOL privacyChanged=![selected isEqual:privacy[@"pdMode"]] || added.count || removed.count;
    __weak JMAppDelegate *weakSelf=self;
    void (^saveTyping)(void)=^{
        JMAppDelegate *self=weakSelf;
        if (!self || self.loginAttemptSerial!=session) return;
        if (wasTyping==wantTyping) { [self finishAccountPrivacy:nil]; return; }
        [self stopOutgoingTyping];
        if (!wantTyping) self.typingDisclosure=@NO;
        [self.client setDiscloseTyping:wantTyping completion:^(NSDictionary *result,NSError *error) {
            JMAppDelegate *self=weakSelf;
            if (!self || self.loginAttemptSerial!=session) return;
            NSNumber *value=[self typingPreference:result];
            if (!error && value) [self updateTypingDisclosure:result];
            if (error || !value || [value boolValue]!=wantTyping) {
                NSString *message=JML(@"Сервер не подтвердил изменение индикатора набора. Откройте настройки заново.");
                [self finishAccountPrivacy:error ?: [NSError errorWithDomain:JMAPIErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:message}]];
            } else [self finishAccountPrivacy:nil];
        }];
    };
    if (!privacyChanged) { saveTyping(); return; }
    [self.client updatePrivacyMode:selected allow:added.allObjects remove:removed.allObjects completion:^(NSDictionary *result,NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || self.loginAttemptSerial!=session) return;
        if (error || ![result[@"pdMode"] isEqual:selected] || ![[NSSet setWithArray:JMAllowedUINs(result) ?: @[]] isEqual:desired]) {
            NSString *message=JML(@"Сервер не подтвердил выбранный режим и список. Откройте настройки заново.");
            [self finishAccountPrivacy:error ?: [NSError errorWithDomain:JMAPIErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:message}]];
            return;
        }
        saveTyping();
    }];
}
- (void)updateTypingDisclosure:(NSDictionary *)preferences {
    NSNumber *value=[self typingPreference:preferences];
    if (!value) return;
    if (!value.boolValue) [self stopOutgoingTyping];
    self.typingDisclosure=value;
}

- (void)client:(JMAPIClient *)client receivedAccountPreferences:(NSDictionary *)preferences {
    [self updateTypingDisclosure:preferences];
}
