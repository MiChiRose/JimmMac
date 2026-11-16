- (void)showMoodPicker:(id)sender {
    if (!self.client.connected || self.changingMood) return;
    NSUInteger session=self.loginAttemptSerial;
    NSAlert *alert=[[NSAlert alloc] init];
    alert.messageText=JML(@"X-статус ICQ");
    alert.informativeText=JML(@"Значок настроения виден собеседникам рядом с обычным статусом.");
    NSPopUpButton *picker=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,280,28) pullsDown:NO];
    [picker addItemWithTitle:JMMoodTitle(@"")];
    picker.lastItem.representedObject=@"";
    NSString *current=JMString(self.ownInfo[@"_mood"]);
    for (NSNumber *number in JMMoodNumbers()) {
        NSString *code=[@"0icqmood" stringByAppendingString:number.stringValue];
        [picker addItemWithTitle:JMMoodTitle(code)];
        picker.lastItem.representedObject=code;
        picker.lastItem.image=JMMoodImage(code);
        if ([code isEqual:current]) [picker selectItem:picker.lastItem];
    }
    alert.accessoryView=picker;
    [alert addButtonWithTitle:JML(@"Сохранить")];
    [alert addButtonWithTitle:JML(@"Отмена")].keyEquivalent=@"\e";
    if ([alert runModal]!=NSAlertFirstButtonReturn || session!=self.loginAttemptSerial || !self.client.connected) return;
    NSString *mood=picker.selectedItem.representedObject;
    self.changingMood=YES;
    __weak JMAppDelegate *weakSelf=self;
    [self.client setMood:mood completion:^(NSDictionary *data,NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || session!=self.loginAttemptSerial) return;
        self.changingMood=NO;
        if (error) { [self showError:JML(@"Не удалось сменить X-статус") detail:error.localizedDescription]; return; }
        self.ownInfo[@"_mood"]=mood;
        JMSetLabel(self.presenceFeedback,JMMoodTitle(mood));
    }];
}
