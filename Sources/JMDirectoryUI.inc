- (void)showDirectory:(id)sender {
    if (!self.client.connected || !self.history) return;
    if (!self.directoryWindow) {
        NSRect frame=NSMakeRect(0,0,580,376);
        self.directoryWindow=[[JMPanel alloc] initWithContentRect:frame styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
        self.directoryWindow.releasedWhenClosed=NO;
        self.directoryWindow.delegate=self;
        NSView *root=[[JMWindowView alloc] initWithFrame:frame];
        self.directoryWindow.contentView=root;

        self.directoryField=[[JMThemedSearchField alloc] initWithFrame:NSMakeRect(18,333,278,27)];
        self.directoryField.toolTip=JML(@"Имя, фамилия или UIN в сети Jimm.online");
        [[self.directoryField cell] setPlaceholderString:self.directoryField.toolTip];
        [(NSSearchFieldCell *)self.directoryField.cell setSendsWholeSearchString:YES];
        self.directoryField.target=self;
        self.directoryField.action=@selector(searchDirectory:);
        [root addSubview:self.directoryField];
        self.directoryKind=[[JMThemedPopUpButton alloc] initWithFrame:NSMakeRect(304,332,145,29) pullsDown:NO];
        [self.directoryKind addItemsWithTitles:@[JML(@"Имя"),JML(@"Фамилия"),@"UIN"]];
        [root addSubview:self.directoryKind];
        NSButton *find=JMButton(JML(@"Найти"),NSMakeRect(456,330,106,32),self,@selector(searchDirectory:));
        find.keyEquivalent=@"\r";
        [root addSubview:find];

        NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(18,100,544,223)];
        scroll.hasVerticalScroller=YES;
        scroll.borderType=NSBezelBorder;
        self.directoryTable=[[NSTableView alloc] initWithFrame:scroll.contentView.bounds];
        NSTableColumn *name=[[NSTableColumn alloc] initWithIdentifier:@"name"];
        name.width=369;
        name.editable=NO;
        [name.headerCell setStringValue:JML(@"Имя")];
        [self.directoryTable addTableColumn:name];
        NSTableColumn *uin=[[NSTableColumn alloc] initWithIdentifier:@"uin"];
        uin.width=144;
        uin.editable=NO;
        [uin.headerCell setStringValue:@"UIN"];
        [self.directoryTable addTableColumn:uin];
        self.directoryTable.columnAutoresizingStyle=NSTableViewLastColumnOnlyAutoresizingStyle;
        self.directoryTable.dataSource=self;
        self.directoryTable.target=self;
        self.directoryTable.doubleAction=@selector(writeDirectoryContact:);
        scroll.documentView=self.directoryTable;
        [root addSubview:scroll];

        self.directoryStatus=JMLabel(@"",NSMakeRect(18,65,544,24),12,NO);
        [root addSubview:self.directoryStatus];
        [root addSubview:JMButton(JML(@"Профиль"),NSMakeRect(18,18,105,32),self,@selector(profileDirectoryContact:))];
        [root addSubview:JMButton(JML(@"Написать…"),NSMakeRect(129,18,112,32),self,@selector(writeDirectoryContact:))];
        [root addSubview:JMButton(JML(@"Добавить…"),NSMakeRect(247,18,116,32),self,@selector(addDirectoryContact:))];
        self.directoryNext=JMButton(JML(@"Ещё…"),NSMakeRect(369,18,85,32),self,@selector(nextDirectoryPage:));
        [root addSubview:self.directoryNext];
        NSButton *close=JMButton(JML(@"Закрыть"),NSMakeRect(462,18,100,32),self,@selector(closeDirectory:));
        close.keyEquivalent=@"\e";
        [root addSubview:close];
        [self.directoryWindow center];
    }
    if (!self.directoryWindow.isVisible) {
        self.directoryField.stringValue=@"";
        self.directoryResults=@[];
        [self.directoryTable reloadData];
        self.directoryNext.enabled=NO;
        JMSetLabel(self.directoryStatus,JML(@"Введите имя, фамилию или UIN."));
    }
    JMDecorateUtilityWindow(self.directoryWindow,JML(@"Найти человека…"));
    [self.directoryWindow makeKeyAndOrderFront:nil];
    [self.directoryWindow makeFirstResponder:self.directoryField];
}
- (void)closeDirectory:(id)sender {
    self.directorySerial++;
    [self.directoryWindow orderOut:nil];
}
- (void)searchDirectory:(id)sender {
    NSString *value=[self.directoryField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger type=self.directoryKind.indexOfSelectedItem;
    if (!value.length || value.length>100 || (type==2 && !JMValidUIN(value))) {
        self.directorySerial++;
        self.directoryNext.enabled=NO;
        self.directoryResults=@[];
        [self.directoryTable reloadData];
        JMSetLabel(self.directoryStatus,JML(@"Укажите имя, фамилию или числовой UIN."));
        return;
    }
    self.directoryQuery=value;
    self.directoryQueryField=type==2 || JMValidUIN(value) ? @"keyword" : (type==1 ? @"lastName" : @"firstName");
    [self requestDirectoryPage:0];
}
- (void)nextDirectoryPage:(id)sender { [self requestDirectoryPage:self.directoryOffset]; }
- (void)requestDirectoryPage:(NSUInteger)offset {
    NSUInteger serial=++self.directorySerial;
    self.directoryNext.enabled=NO;
    self.directoryResults=@[];
    [self.directoryTable reloadData];
    JMSetLabel(self.directoryStatus,JML(@"Ищем в каталоге Jimm.online…"));
    __weak JMAppDelegate *weakSelf=self;
    [self.client searchDirectory:self.directoryQuery field:self.directoryQueryField offset:offset completion:^(NSDictionary *data,NSError *error) {
        JMAppDelegate *self=weakSelf;
        if (!self || self.directorySerial!=serial) return;
        if (error) { JMSetLabel(self.directoryStatus,error.localizedDescription); return; }
        NSDictionary *set=JMDictionary(data[@"results"]);
        NSMutableArray *rows=[NSMutableArray array];
        NSMutableSet *seen=[NSMutableSet set];
        NSArray *profiles=JMArray(set[@"infoArray"]);
        for (id value in profiles) {
            NSDictionary *person=JMDictionary(JMDictionary(value)[@"profile"]);
            NSString *uin=JMString(person[@"aimId"]);
            if (!JMValidUIN(uin) || [uin isEqual:self.accountUIN] || [seen containsObject:uin]) continue;
            [seen addObject:uin];
            [rows addObject:person];
        }
        self.directoryOffset=offset+profiles.count;
        self.directoryResults=rows;
        [self.directoryTable reloadData];
        if (rows.count) [self.directoryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        NSInteger total=[JMString(set[@"nTotal"]) integerValue];
        self.directoryNext.enabled=profiles.count && total>0 && self.directoryOffset<(NSUInteger)total;
        JMSetLabel(self.directoryStatus,rows.count ? [NSString stringWithFormat:JML(@"Показано пользователей: %lu"),(unsigned long)rows.count] : JML(@"Пользователи не найдены."));
    }];
}
- (NSDictionary *)selectedDirectoryPerson {
    NSInteger row=self.directoryTable.selectedRow;
    return row>=0 && row<(NSInteger)self.directoryResults.count ? self.directoryResults[(NSUInteger)row] : nil;
}
- (NSString *)directoryPersonName:(NSDictionary *)person {
    NSString *name=[[NSString stringWithFormat:@"%@ %@",JMString(person[@"firstName"]),JMString(person[@"lastName"])] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return name.length ? name : (JMString(person[@"displayId"]).length ? JMString(person[@"displayId"]) : JMString(person[@"aimId"]));
}
- (NSMenuItem *)actionForDirectoryContact {
    NSDictionary *person=[self selectedDirectoryPerson];
    NSString *peer=JMString(person[@"aimId"]);
    if (!JMValidUIN(peer) || !self.client.connected) return nil;
    if (!self.contacts[peer]) self.contacts[peer]=[@{@"aimId":peer,@"friendly":[self directoryPersonName:person],@"state":@"offline"} mutableCopy];
    NSMenuItem *item=[[NSMenuItem alloc] init];
    item.representedObject=peer;
    return item;
}
- (void)writeDirectoryContact:(id)sender {
    NSMenuItem *item=[self actionForDirectoryContact];
    if (item) { [self closeDirectory:nil]; [self writeContact:item]; }
}
- (void)profileDirectoryContact:(id)sender {
    NSMenuItem *item=[self actionForDirectoryContact];
    if (item) [self profileContact:item];
}
- (void)addDirectoryContact:(id)sender {
    NSString *peer=[self actionForDirectoryContact].representedObject;
    if (!peer || ![self canChangeRoster]) return;
    if ([self.serverContactIDs containsObject:peer]) { JMSetLabel(self.directoryStatus,JML(@"Этот UIN уже в контактах.")); return; }
    NSAlert *alert=[self newAddContactPrompt];
    NSTextField *field=(NSTextField *)[alert.accessoryView viewWithTag:101];
    field.stringValue=peer;
    field.editable=NO;
    if ([alert runModal]!=NSAlertFirstButtonReturn) return;
    NSString *group=[(NSPopUpButton *)[alert.accessoryView viewWithTag:102] titleOfSelectedItem];
    [self closeDirectory:nil];
    [self addContactUIN:peer group:group];
}
