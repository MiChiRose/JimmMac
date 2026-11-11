static void CheckUtilityBounds(NSWindow *window) {
    NSView *root=window.contentView;
    for (NSView *view in root.subviews) if (!view.hidden) CheckUI(NSContainsRect(root.bounds,view.frame),"utility window keeps visible controls inside its content bounds");
}
static void ImprovementUI(SmokeDelegate *delegate,NSString *output) {
    UIClient *client=[[UIClient alloc] init]; client.fixtureConnected=YES; [delegate setValue:client forKey:@"client"]; [delegate setValue:@NO forKey:@"offlineMode"];
    [delegate setValue:[[JMAutoAway alloc] init] forKey:@"autoAway"]; [testAlertDefaults setInteger:5 forKey:@"AutoAwayMinutes"];
    delegate.fixtureIdle=@0; [delegate autoAwayTick:nil]; delegate.fixtureIdle=@301; [delegate autoAwayTick:nil];
    CheckUI([client.chosenState isEqual:@"away"] && [[delegate valueForKey:@"autoAway"] automaticallyAway],"idle policy reaches the API and applies automatic Away");
    delegate.fixtureIdle=@0; [delegate autoAwayTick:nil];
    CheckUI([client.chosenState isEqual:@"online"],"activity restores online through the API");
    NSPopUpButton *presence=[delegate valueForKey:@"presencePopup"];
    for (NSMenuItem *item in presence.itemArray) if ([item.representedObject isEqual:@"dnd"]) [presence selectItem:item];
    [delegate changePresence:nil]; delegate.fixtureIdle=@900; [delegate autoAwayTick:nil];
    CheckUI([client.chosenState isEqual:@"dnd"],"automatic idle handling respects a manually chosen Do Not Disturb");
    [delegate setValue:[[JMAutoAway alloc] init] forKey:@"autoAway"]; client.holdPresence=YES; delegate.fixtureIdle=@301; [delegate autoAwayTick:nil];
    CheckUI(presence.enabled && client.pendingPresence!=nil,"manual status remains available during an automatic request");
    void (^oldPresence)(NSDictionary *,NSError *)=client.pendingPresence; client.pendingPresence=nil; client.holdPresence=NO;
    for (NSMenuItem *item in presence.itemArray) if ([item.representedObject isEqual:@"dnd"]) [presence selectItem:item];
    [delegate changePresence:nil]; oldPresence(@{@"state":@"away",@"_presenceVerification":@"confirmed"},nil);
    CheckUI([client.chosenState isEqual:@"dnd"] && ![[delegate valueForKey:@"autoAway"] automaticallyAway],"late automatic confirmation cannot replace a manual status");
    NSUInteger connections=client.reconnects; [delegate workspaceDidWake:nil]; NSDate *wakeDeadline=[NSDate dateWithTimeIntervalSinceNow:2]; while (client.reconnects==connections && wakeDeadline.timeIntervalSinceNow>0) PumpUI(0.05);
    CheckUI(client.reconnects==connections+1,"wake notification reconnects the current session");
    [testAlertDefaults setInteger:0 forKey:@"AutoAwayMinutes"]; delegate.fixtureIdle=nil;
    [client setValue:[@[@{@"endpoint":@"/aim/fetchEvents",@"http":@503,@"api":@503,@"errorCode":@(-1009),@"errorDomain":NSURLErrorDomain,@"time":@1700000000,@"token":@"SECRET-FIXTURE"}] mutableCopy] forKey:@"diagnosticEntries"];
    [delegate showDiagnostics:nil]; NSWindow *diagnosticWindow=[delegate valueForKey:@"diagnosticsWindow"]; NSTextView *diagnostics=[delegate valueForKey:@"diagnosticsText"];
    CheckUI(diagnosticWindow.isVisible && !diagnostics.isEditable && diagnostics.isSelectable && [diagnostics.string rangeOfString:@"503"].location!=NSNotFound && [diagnostics.string rangeOfString:@"SECRET-FIXTURE"].location==NSNotFound,"diagnostics is selectable and displays codes without private values");
    [delegate copyDiagnostics:nil]; CheckUI([delegate.copiedMessage isEqual:diagnostics.string],"Copy Report copies the complete redacted report"); CheckUtilityBounds(diagnosticWindow);
    Capture(diagnosticWindow,[output stringByAppendingPathComponent:@"UI-015-diagnostics.png"]); [delegate handleEscapeInWindow:diagnosticWindow]; CheckUI(!diagnosticWindow.isVisible,"Escape closes diagnostics");
    JMHistory *history=[delegate valueForKey:@"history"]; NSString *peer=@"888888";
    NSDate *day=[delegate startOfDay:[NSDate dateWithTimeIntervalSince1970:1700000000]], *next=[delegate dayAfter:day];
    for (NSUInteger i=0;i<2;i++) CheckUI([history appendMessage:@{@"id":[NSString stringWithFormat:@"015-day-%lu",(unsigned long)i],@"peer":peer,@"text":@"Bookmark day fixture :)",@"timestamp":@(day.timeIntervalSince1970+60+i*60),@"outgoing":@NO} error:NULL],"history navigation fixture saved");
    [delegate selectPeer:peer]; [delegate showHistorySearch:nil];
    NSButton *dateFilter=[delegate valueForKey:@"historyDateCheckbox"], *bookmarks=[delegate valueForKey:@"historyBookmarkCheckbox"];
    NSDatePicker *from=[delegate valueForKey:@"historyFromDate"], *until=[delegate valueForKey:@"historyUntilDate"]; from.dateValue=day; until.dateValue=day; dateFilter.state=NSOnState; bookmarks.state=NSOffState;
    NSSearchField *query=[delegate valueForKey:@"historySearchField"]; query.stringValue=@""; NSPopUpButton *scope=[delegate valueForKey:@"historyScopePopup"]; [scope selectItemAtIndex:1]; [delegate searchHistory:nil]; PumpUI(0.5);
    CheckUI([[delegate valueForKey:@"historyResults"] count]==2,"date-only history filter displays that day's messages");
    for (NSMenuItem *item in scope.itemArray) if ([item.representedObject isEqual:peer]) [scope selectItem:item];
    [delegate selectPeer:@"222"]; [delegate searchHistory:nil]; PumpUI(0.5);
    CheckUI([[delegate valueForKey:@"historyResults"] count]==2,"specific-peer filter remains independent of the currently open conversation");
    [delegate jumpToHistoryDay:nil]; CheckUI([[delegate valueForKey:@"highlightedMessageID"] isEqual:@"015-day-0"] && ![[delegate valueForKey:@"historyWindow"] isVisible],"Go to Date opens the first message and closes search");
    CheckUI([[delegate valueForKey:@"selectedPeer"] isEqual:peer],"Go to Date follows the explicitly selected history peer");
    [delegate showHistorySearch:nil]; CheckUI([scope.selectedItem.representedObject isEqual:peer],"reopening search preserves the specific-peer filter"); [delegate closeHistorySearch:nil];
    NSDictionary *context=@{@"account":[delegate valueForKey:@"accountUIN"],@"peer":peer,@"id":@"015-day-0",@"generation":[delegate valueForKey:@"conversationGeneration"]};
    NSMenuItem *bookmark=[[NSMenuItem alloc] init]; bookmark.representedObject=context; [delegate toggleMessageBookmark:bookmark];
    CheckUI([history isBookmarkedID:@"015-day-0" peer:peer],"message action creates a persistent bookmark");
    [delegate showBookmarks:nil]; PumpUI(0.5); CheckUI([[delegate valueForKey:@"historyResults"] count]>=1,"Bookmarks menu browses messages without a search phrase");
    [delegate closeHistorySearch:nil];
    [delegate showPreferences:nil]; NSPopUpButton *density=[delegate valueForKey:@"densityPopup"];
    NSMenuItem *mode=[[NSMenuItem alloc] init]; mode.representedObject=@"current"; [delegate changeAppearance:mode];
    CGFloat regular=[[delegate valueForKey:@"contactTable"] rowHeight]; [density selectItemAtIndex:1]; [delegate appearancePreferencesChanged:density];
    CheckUI([[delegate valueForKey:@"contactTable"] rowHeight]<regular,"compact density changes actual roster row height");
    [(JMChatPreferences *)[delegate valueForKey:@"chatPreferences"] setFamily:@"" size:28]; [delegate applyChatFont];
    NSTextView *sample=[delegate valueForKey:@"appearancePreview"]; CheckUI([[sample.textStorage attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] pointSize]==28,"live conversation preview uses the configured large font");
    Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:@"UI-015-large-preview.png"]);
    [(JMChatPreferences *)[delegate valueForKey:@"chatPreferences"] setFamily:@"" size:13]; [delegate applyChatFont];
    for (NSString *theme in @[@"current",@"mac2011",@"pro2003"]) {
        mode.representedObject=theme; [delegate changeAppearance:mode]; [delegate showPreferences:nil]; NSSegmentedControl *sections=[delegate valueForKey:@"preferenceSections"];
        for (NSInteger i=0;i<5;i++) { sections.selectedSegment=i; [delegate changePreferenceSection:nil]; CheckUtilityBounds([delegate valueForKey:@"preferencesWindow"]); }
        sections.selectedSegment=3; [delegate changePreferenceSection:nil]; Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-015-%@-appearance.png",theme]]);
        sections.selectedSegment=4; [delegate changePreferenceSection:nil]; Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-015-%@-status.png",theme]]);
        [delegate showHistorySearch:nil]; PumpUI(0.4); CheckUtilityBounds([delegate valueForKey:@"historyWindow"]); Capture([delegate valueForKey:@"historyWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-015-%@-search.png",theme]]); [delegate closeHistorySearch:nil];
        [delegate showProfile:nil]; CheckUtilityBounds([delegate valueForKey:@"profileWindow"]); Capture([delegate valueForKey:@"profileWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-015-%@-profile.png",theme]]); [delegate closeProfile:nil];
        [delegate showStorage:nil]; CheckUtilityBounds([delegate valueForKey:@"storageWindow"]); Capture([delegate valueForKey:@"storageWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-015-%@-storage.png",theme]]); [delegate closeStorage:nil];
    }
    [delegate restoreStandardPreferences]; CheckUI([JMThemeIdentifier() isEqual:@"current"] && ![testAlertDefaults boolForKey:@"CompactContactList"] && [(JMChatPreferences *)[delegate valueForKey:@"chatPreferences"] size]==13 && [history countForPeer:peer]==2,"restoring preferences preserves history and restores font, theme and density");
    [delegate closePreferences:nil];
    [delegate showStorage:nil]; FixtureAvatarStore *avatars=[delegate valueForKey:@"avatars"]; NSURL *cache=[avatars valueForKey:@"cacheDirectory"];
    [@"avatar" writeToURL:[cache URLByAppendingPathComponent:@"222.image"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]; [@"keep" writeToURL:[cache URLByAppendingPathComponent:@"unrelated.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    CheckUI(avatars.cacheBytes==6,"storage measures only managed avatar files"); [delegate clearAvatarCache:nil];
    CheckUI(avatars.cacheBytes==0 && [[NSFileManager defaultManager] fileExistsAtPath:[cache URLByAppendingPathComponent:@"unrelated.txt"].path] && [history countForPeer:peer]==2,"cache cleanup preserves unrelated files and conversation history");
    NSURL *backup=[testDraftRoot URLByAppendingPathComponent:@"015-cleanup.jimmbackup"];
    [delegate deleteHistoryPeer:peer from:day until:next backupURL:[testDraftRoot URLByAppendingPathComponent:@"absent/failed.jimmbackup"]];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5]; while ([[delegate valueForKey:@"dataOperationInProgress"] boolValue] && deadline.timeIntervalSinceNow>0) PumpUI(0.02);
    CheckUI([history countForPeer:peer]==2,"failed requested backup prevents history deletion");
    [delegate deleteHistoryPeer:peer from:day until:next backupURL:backup]; deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while ([[delegate valueForKey:@"dataOperationInProgress"] boolValue] && deadline.timeIntervalSinceNow>0) PumpUI(0.02);
    CheckUI([history countForPeer:peer]==0 && [JMHistory backupManifestAtURL:backup error:NULL]!=nil,"storage workflow saves backup before deleting selected period");
    CheckUI([history mergeBackupAtURL:backup error:NULL]==2 && [history isBookmarkedID:@"015-day-0" peer:peer],"storage cleanup can be reversed using its actual portable backup");
    [delegate closeStorage:nil]; dateFilter.state=NSOffState; bookmarks.state=NSOffState; query.stringValue=@"";
}

static void ImprovementEnglishUI(SmokeDelegate *delegate,NSString *output) {
    for (NSString *theme in @[@"current",@"mac2011",@"pro2003"]) {
        NSMenuItem *mode=[[NSMenuItem alloc] init]; mode.representedObject=theme; [delegate changeAppearance:mode];
        [delegate showPreferences:nil]; NSSegmentedControl *sections=[delegate valueForKey:@"preferenceSections"];
        for (NSInteger i=0;i<5;i++) { sections.selectedSegment=i; [delegate changePreferenceSection:nil]; CheckUtilityBounds([delegate valueForKey:@"preferencesWindow"]); }
        sections.selectedSegment=3; [delegate changePreferenceSection:nil]; Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-015-English-%@-preferences.png",theme]]); [delegate closePreferences:nil];
        [delegate showStorage:nil]; CheckUtilityBounds([delegate valueForKey:@"storageWindow"]); [delegate closeStorage:nil];
        [delegate showHistorySearch:nil]; CheckUtilityBounds([delegate valueForKey:@"historyWindow"]); [delegate closeHistorySearch:nil];
    }
}

static void ManualUpdateAndAnimationUI(SmokeDelegate *delegate, NSString *output) {
    UIUpdateChecker *checker=[[UIUpdateChecker alloc] init];
    checker.holdResponse=YES;
    [delegate setValue:checker forKey:@"updateChecker"];
    [delegate checkForUpdates:nil];
    NSWindow *window=[delegate valueForKey:@"updateWindow"];
    NSTextField *heading=[delegate valueForKey:@"updateHeading"];
    NSButton *action=[delegate valueForKey:@"updateAction"];
    NSProgressIndicator *progress=[delegate valueForKey:@"updateProgress"];
    CheckUI(window.isVisible && !progress.isHidden && [heading.stringValue isEqual:@"Проверяем обновления…"] && action.isHidden,
        "manual updater shows progress before the HTTP response");
    [delegate checkForUpdates:nil];
    CheckUI(checker.checks==1,"reopening update progress joins the same request");
    Capture(window,[output stringByAppendingPathComponent:@"UI-016-update-checking.png"]);
    checker.releaseInfo=@{@"version":@"0.17.0",@"url":[NSURL URLWithString:@"https://github.com/MiChiRose/JimmMac/releases/tag/v0.17.0"],@"notes":@"Fixture release"};
    [checker finish];
    CheckUI(window.isVisible && progress.isHidden && [heading.stringValue rangeOfString:@"0.17.0"].location!=NSNotFound && !action.isHidden,
        "an available update replaces progress in the same window");
    [action performClick:nil];
    CheckUI([delegate.openedURL isEqual:checker.releaseInfo[@"url"]],"the release action opens the verified URL");
    [delegate checkForUpdates:nil];
    checker.releaseInfo=nil;
    checker.error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [checker finish];
    CheckUI(window.isVisible && [heading.stringValue isEqual:@"Не удалось проверить обновления"] && !action.isHidden,
        "manual update failure offers retry in the same window");
    [action performClick:nil];
    CheckUI(checker.checks==3 && [heading.stringValue isEqual:@"Проверяем обновления…"],"retry shows progress before issuing another request");
    checker.error=nil;
    checker.releaseInfo=@{@"version":@"0.16.0"};
    [checker finish];
    CheckUI(window.isVisible && action.isHidden && [heading.stringValue isEqual:@"У вас актуальная версия JimmMac"],
        "current version replaces progress in the same window");
    [delegate checkForUpdates:nil];
    [delegate closeUpdateWindow:nil];
    [checker finish];
    CheckUI(!window.isVisible,"a delayed update response does not reopen a closed window");

    [delegate checkUpdatesAutomatically:YES];
    [delegate checkForUpdates:nil];
    [delegate closeUpdateWindow:nil];
    checker.releaseInfo=@{@"version":@"0.18.0"};
    [checker finish];
    CheckUI(checker.checks==5 && [delegate valueForKey:@"pendingUpdateRelease"]==nil,
        "a manually dismissed check does not turn into a background notice");

    NSURL *legacy=[NSURL URLWithString:@"https://github.com/MiChiRose/JimmMac/releases/download/v0.18.0/JimmMac-0.18.0-macos10.8-10.13-x86_64.dmg"];
    NSURL *universal=[NSURL URLWithString:@"https://github.com/MiChiRose/JimmMac/releases/download/v0.18.0/JimmMac-0.18.0-macos10.13plus-universal.dmg"];
    checker.releaseInfo=@{@"version":@"0.18.0",@"url":[NSURL URLWithString:@"https://github.com/MiChiRose/JimmMac/releases/tag/v0.18.0"],@"legacyInstaller":legacy,@"universalInstaller":universal};
    [delegate checkForUpdates:nil];
    [checker finish];
    CheckUI([action.title isEqual:@"Скачать DMG"],"a compatible installer gets a download button");
    [action performClick:nil];
    struct utsname system;
    BOOL olderSystem=uname(&system)==0 && atoi(system.release)<17;
    CheckUI([delegate.openedURL isEqual:(olderSystem ? legacy : universal)],"the download button opens this Mac's installer");

    NSString *saved=JMThemeIdentifier();
    for (NSString *theme in @[@"jimm",@"qip",@"mac2011",@"pro2003"]) {
        JMSetTheme(theme);
        BOOL animated=JMThemeIsMobile();
        NSMutableAttributedString *sample=[[NSMutableAttributedString alloc] initWithString:@":-)"];
        JMApplyEmoticons(sample);
        NSTextAttachment *attachment=[sample attribute:NSAttachmentAttributeName atIndex:0 effectiveRange:NULL];
        id cell=attachment.attachmentCell;
        BOOL hasAnimation=[cell respondsToSelector:NSSelectorFromString(@"animation")];
        CheckUI(hasAnimation==animated,"only themes with a verified GIF source animate");
        if (animated) {
            NSArray *frames=[[cell valueForKey:@"animation"] valueForKey:@"frames"];
            NSMutableSet *pixels=[NSMutableSet set];
            for (NSImage *frame in frames) [pixels addObject:frame.TIFFRepresentation];
            CheckUI(pixels.count>1,"Mavericks decodes distinct frames from the original GIF");
            NSWindow *sampleWindow=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,180,70) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
            JMTranscriptView *view=[[JMTranscriptView alloc] initWithFrame:NSMakeRect(0,0,180,70)];
            sampleWindow.contentView=view;
            [view.textStorage setAttributedString:sample];
            [sampleWindow orderFront:nil];
            // Match the transcript's explicit TextKit 1 layout on modern AppKit.
            [view.layoutManager ensureLayoutForTextContainer:view.textContainer];
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            CheckUI([[cell valueForKey:@"startedAt"] doubleValue]>0 && [view valueForKey:@"smileyTimer"]!=nil,
                "visible animated attachment schedules its next frame on the Mavericks text view");
            [sampleWindow orderOut:nil];
        }
        for (NSString *status in @[@"online",@"offline",@"away",@"na",@"dnd",@"occupied",@"invisible",@"freeForChat"]) {
            CheckUI(NSEqualSizes(JMStatusImage(status).size,NSMakeSize(16,16)),"all status artwork decodes on Mavericks");
        }
    }
    JMSetTheme(saved);
}

static void RetroUpgradeUI(SmokeDelegate *delegate, NSString *output) {
    ManualUpdateAndAnimationUI(delegate,output);
    NSString *startingTheme=JMThemeIdentifier();
    NSMutableSet *smileImages=[NSMutableSet set];
    for (NSString *theme in @[@"jimm",@"qip",@"mac2011",@"pro2003"]) {
        JMSetTheme(theme);
        for (NSString *code in JMSmileyCodes()) {
            CheckUI([JMSmileyImage(code) isValid],"all smiley choices decode in each historical theme");
        }
        [smileImages addObject:JMSmileyImage(@":)").TIFFRepresentation];
        NSMutableAttributedString *sample=[[NSMutableAttributedString alloc] initWithString:@":-) ;-) :D https://example.com/:)"];
        [sample addAttribute:NSLinkAttributeName value:@"https://example.com/:)" range:[sample.string rangeOfString:@"https://example.com/:)"]];
        JMApplyEmoticons(sample);
        CheckUI([[sample attribute:@"JMSmileyText" atIndex:0 effectiveRange:NULL] isEqual:@":-)"]
            && [sample.string hasSuffix:@"https://example.com/:)"],"archival smileys preserve text codes and leave links alone");
    }
    CheckUI(smileImages.count==4,"each historical theme loads its own smiley artwork");
    JMSetTheme(startingTheme);
    UIClient *client=[[UIClient alloc] init];
    client.fixtureConnected=YES;
    [delegate setValue:client forKey:@"client"];
    [delegate setValue:@NO forKey:@"offlineMode"];
    [delegate client:client receivedBuddyList:@{@"groups":@[
        @{@"name":@"General",@"buddies":@[
            @{@"aimId":@"16001",@"friendly":@"Alex · Fixture",@"state":@"online"},
            @{@"aimId":@"16002",@"friendly":@"Olya · Fixture",@"state":@"away"}]},
        @{@"name":@"Friends",@"buddies":@[
            @{@"aimId":@"16003",@"friendly":@"Ira · Fixture",@"state":@"offline"}]}
    ]}];
    NSSegmentedControl *sections=[delegate valueForKey:@"sectionControl"];
    NSMenuItem *appearance=[[NSMenuItem alloc] init];
    for (NSString *theme in @[@"qip",@"jimm"]) {
        appearance.representedObject=theme;
        [delegate changeAppearance:appearance];
        sections.selectedSegment=0; [delegate changeSection:nil];
        CheckUI(JMThemeIsMobile() && [JMThemeIdentifier() isEqual:theme],"mobile-inspired appearance is selectable");
        NSWindow *roster=[delegate valueForKey:@"rosterWindow"];
        [roster makeKeyAndOrderFront:nil]; PumpUI(0.1);
        CheckUtilityBounds(roster);
        NSView *footer=[delegate valueForKey:@"mobileFooter"], *status=[delegate valueForKey:@"statusLabel"];
        CheckUI(!NSIntersectsRect(footer.frame,status.frame),"footer commands and connection status occupy separate rows");
        for (NSString *key in @[@"mobileFind",@"themeMainMenu",@"mobileSettings"]) {
            CheckUI(NSContainsRect(footer.frame,[[delegate valueForKey:key] frame]),"every footer action fits its themed bar");
        }
        sections.selectedSegment=1; [delegate changeSection:nil];
        NSScrollView *list=[[delegate valueForKey:@"contactTable"] enclosingScrollView];
        NSView *sidebar=[delegate valueForKey:@"sidebar"], *search=[delegate valueForKey:@"searchField"];
        NSButton *unreadButton=[delegate valueForKey:@"mobileUnread"];
        [roster setContentSize:roster.contentMinSize];
        Capture(roster,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-016-%@-conversations.png",theme]]);
        for (NSNumber *height in @[@(roster.contentMinSize.height),@700]) {
            [roster setContentSize:NSMakeSize(roster.contentMinSize.width,height.doubleValue)];
            PumpUI(0.03);
            NSRect buttonFrame=[sidebar convertRect:unreadButton.bounds fromView:unreadButton];
            CheckUI(!unreadButton.isHidden && NSContainsRect(sidebar.bounds,buttonFrame)
                && NSMinY(buttonFrame)>=NSMaxY(list.frame)+4 && NSMaxY(buttonFrame)<=NSMinY(search.frame)-3,
                "unread filter stays fully between search and the conversation list when resized");
        }
        [unreadButton performClick:nil];
        CheckUI(unreadButton.state==NSOnState && [[delegate valueForKey:@"unreadOnly"] boolValue],"unread filter button activates the real filter");
        [unreadButton performClick:nil];
        CheckUI(unreadButton.state==NSOffState && ![[delegate valueForKey:@"unreadOnly"] boolValue],"unread filter button restores all conversations");
        [roster setContentSize:roster.contentMinSize];
        NSView *empty=[delegate valueForKey:@"emptyListLabel"];
        CheckUI(NSContainsRect(list.frame,empty.frame) && fabs(NSMidY(list.frame)-NSMidY(empty.frame))<=1,"conversation empty state follows the filtered list geometry");
        sections.selectedSegment=0; [delegate changeSection:nil];
        CheckUI(unreadButton.isHidden,"unread filter stays out of the contacts tab");
        [delegate toggleGroup:@"General"];
        NSArray *visible=[delegate valueForKey:@"visibleContacts"];
        BOOL collapsed=NO, containsChild=NO;
        for (NSDictionary *row in visible) {
            if ([row[@"_collapsedGroup"] isEqual:@"General"]) collapsed=YES;
            if ([row[@"aimId"] isEqual:@"16001"]) containsChild=YES;
        }
        CheckUI(collapsed && !containsChild,"collapsing keeps the group header and hides its contacts");
        Capture(roster,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-016-%@-collapsed.png",theme]]);
        [delegate toggleGroup:@"General"];
        Capture(roster,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-016-%@-contacts.png",theme]]);
        [delegate selectPeer:@"16001"];
        NSWindow *chat=[delegate valueForKey:@"chatWindow"];
        [chat setContentSize:chat.contentMinSize];
        NSView *title=[delegate valueForKey:@"mobileChatTitle"], *profile=[delegate valueForKey:@"profileButton"];
        CheckUI(!NSIntersectsRect(title.frame,profile.frame),"chat title never covers profile button at the minimum size");
        Capture(chat,[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-016-%@-chat.png",theme]]);
        [delegate showPreferences:nil];
        NSSegmentedControl *prefs=[delegate valueForKey:@"preferenceSections"]; prefs.selectedSegment=3; [delegate changePreferenceSection:nil];
        Capture([delegate valueForKey:@"preferencesWindow"],[output stringByAppendingPathComponent:[NSString stringWithFormat:@"UI-016-%@-preferences.png",theme]]);
        [delegate closePreferences:nil];
    }
    JMHistory *history=[delegate valueForKey:@"history"];
    [delegate selectPeer:@"16001"];
    client.storedRows=@[@{@"sender":@"16001",@"msgId":@"016-recovered",@"message":@"Fixture recovered message",@"date":@1793346999}];
    [delegate restoreRecentMessages:nil]; [delegate restoreRecentMessages:nil];
    CheckUI([history countForPeer:@"16001"]==1 && [history messageWithID:@"016-recovered" peer:@"16001"]!=nil,"session recovery inserts a message only once");
    NSMutableDictionary *unread=[delegate valueForKey:@"unread"]; unread[@"16003"]=@1;
    [[delegate valueForKey:@"conversationPeers"] addObject:@"16003"];
    sections.selectedSegment=0; [delegate changeSection:nil]; [delegate toggleUnreadFilter:nil];
    NSArray *visible=[delegate valueForKey:@"visibleContacts"];
    CheckUI(sections.selectedSegment==1 && visible.count>0 && [visible indexOfObjectPassingTest:^BOOL(NSDictionary *row,NSUInteger index,BOOL *stop){ return [row[@"aimId"] isEqual:@"16003"]; }]!=NSNotFound,"unread shortcut switches to filtered conversations");
    for (NSDictionary *row in visible) CheckUI([unread[row[@"aimId"]] integerValue]>0,"read conversations are absent from unread-only list");
    [delegate toggleUnreadFilter:nil]; [unread removeObjectForKey:@"16003"];
    appearance.representedObject=@"current"; [delegate changeAppearance:appearance];
    for (NSString *language in @[@"uk",@"be"]) {
        JMSetLanguage(language);
        CheckUI([JMLanguage() isEqual:language] && ![JML(@"Настройки") isEqual:@"Настройки"] && ![JML(@"Непрочитанные") isEqual:@"Непрочитанные"],"Ukrainian and Belarusian provide translated interface strings");
    }
    JMSetLanguage(@"ru");
}

@interface SmokeDelegate (RetryConfirmation)
- (void)acceptRetryConfirmation:(NSTimer *)timer;
@end
@implementation SmokeDelegate (RetryConfirmation)
- (void)acceptRetryConfirmation:(NSTimer *)timer {
    CheckUI([NSApp modalWindow]!=nil,"manual retry asks for confirmation");
    [NSApp stopModalWithCode:NSAlertFirstButtonReturn];
}
@end

static void ArchiveAndBackupUI(SmokeDelegate *delegate, NSString *output) {
    UIClient *client=[delegate valueForKey:@"client"];
    NSString *account=[delegate valueForKey:@"accountUIN"];
    NSString *archiveKey=[@"ArchivedPeers." stringByAppendingString:account];
    NSMenuItem *archive=[[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleArchiveConversation:) keyEquivalent:@""];
    archive.representedObject=@"16001";
    NSDictionary *incoming=Incoming(@"archive-first",@"16001",@"Архивная фраза");
    [delegate client:client receivedMessage:incoming];
    [delegate toggleArchiveConversation:archive];
    CheckUI([[testAlertDefaults arrayForKey:archiveKey] containsObject:@"16001"] &&
        ![[[delegate valueForKey:@"visibleContacts"] valueForKey:@"aimId"] containsObject:@"16001"],
        "archiving saves the account preference and removes the chat from the main list");
    [delegate showArchive:nil];
    CheckUI([[[delegate valueForKey:@"visibleContacts"] valueForKey:@"aimId"] containsObject:@"16001"],
        "an archived chat remains visible in the archive");
    [delegate showArchive:nil];
    [delegate toggleUnreadFilter:nil];
    [delegate showHistorySearch:nil];
    [[delegate valueForKey:@"historyScopePopup"] selectItemAtIndex:0];
    [[delegate valueForKey:@"historyDateCheckbox"] setState:NSOffState];
    [[delegate valueForKey:@"historyBookmarkCheckbox"] setState:NSOffState];
    [[delegate valueForKey:@"historySearchField"] setStringValue:@"Архивная фраза"];
    [delegate searchHistory:nil];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while (![[delegate valueForKey:@"historyResults"] count] && deadline.timeIntervalSinceNow>0) PumpUI(0.02);
    CheckUI([[delegate valueForKey:@"historyResults"] count]==1,"history search finds messages in the archive");
    [delegate openHistoryResult:nil];
    CheckUI([[delegate valueForKey:@"showingArchive"] boolValue] && [[delegate valueForKey:@"selectedPeer"] isEqual:@"16001"] &&
        [[[delegate valueForKey:@"visibleContacts"] valueForKey:@"aimId"] containsObject:@"16001"],
        "opening the history result switches to the archived conversation");
    [delegate client:client receivedMessage:incoming];
    CheckUI([[testAlertDefaults arrayForKey:archiveKey] containsObject:@"16001"],"replayed messages leave a chat archived");
    [delegate client:client receivedMessage:Incoming(@"archive-next",@"16001",@"Сообщение после архивации")];
    CheckUI(![[testAlertDefaults arrayForKey:archiveKey] containsObject:@"16001"] &&
        ![[[delegate valueForKey:@"visibleContacts"] valueForKey:@"aimId"] containsObject:@"16001"],
        "a new incoming message returns the conversation to the active list");
    [delegate showArchive:nil];
    [delegate toggleArchiveConversation:archive];

    NSString *folder=[output stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *manager=[NSFileManager defaultManager];
    CheckUI([manager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:NULL],"backup fixture directory is ready");
    NSString *unrelated=[folder stringByAppendingPathComponent:@"manual.jimmbackup"];
    CheckUI([@"manual backup fixture" writeToFile:unrelated atomically:YES encoding:NSUTF8StringEncoding error:NULL],"manual fixture exists beside scheduled copies");
    NSString *key=[@"ScheduledBackup." stringByAppendingString:account];
    [testAlertDefaults setObject:@{@"path":folder,@"days":@7,@"last":[NSDate date]} forKey:key];
    [delegate showScheduledBackup:nil];
    NSWindow *window=[delegate valueForKey:@"scheduledBackupWindow"];
    CheckUI(window.isVisible,"scheduled backups have a settings window");
    CheckUtilityBounds(window);
    [delegate scheduledBackupTick:nil];
    CheckUI(![[delegate valueForKey:@"scheduledBackupRunning"] boolValue],"the weekly schedule skips a recent successful backup");
    [testAlertDefaults setObject:@{@"path":folder,@"days":@7,@"last":[NSDate dateWithTimeIntervalSinceNow:-8*86400]} forKey:key];
    [delegate scheduledBackupTick:nil];
    deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while ([[delegate valueForKey:@"scheduledBackupRunning"] boolValue] && deadline.timeIntervalSinceNow>0) PumpUI(0.02);
    CheckUI(![[delegate valueForKey:@"scheduledBackupRunning"] boolValue],"a due backup finishes without blocking the AppKit event loop");
    NSString *first=[[testAlertDefaults dictionaryForKey:key][@"files"] firstObject];
    NSURL *firstURL=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:first ?: @"missing"]];
    NSDictionary *manifest=[JMHistory backupManifestAtURL:firstURL error:NULL];
    CheckUI(first.length>0,"the successful backup filename is recorded");
    CheckUI([manifest[@"uin"] isEqual:account] && [manifest[@"preferences"][@"ArchivedPeers"] containsObject:@"16001"],
        "a due backup is restorable and includes the archived conversation");
    CheckUI([testAlertDefaults dictionaryForKey:key][@"last"] && [[[delegate valueForKey:@"scheduledBackupStatus"] stringValue] hasPrefix:@"Последняя копия:"],
        "the scheduled backup window shows its last completion time");
    for (NSUInteger i=0;i<5;i++) {
        [delegate runScheduledBackupNow:nil];
        deadline=[NSDate dateWithTimeIntervalSinceNow:5];
        while ([[delegate valueForKey:@"scheduledBackupRunning"] boolValue] && deadline.timeIntervalSinceNow>0) PumpUI(0.02);
    }
    CheckUI([[testAlertDefaults dictionaryForKey:key][@"files"] count]==5 &&
        [manager contentsOfDirectoryAtPath:folder error:NULL].count==6 && ![manager fileExistsAtPath:firstURL.path] &&
        [manager fileExistsAtPath:unrelated],"rotation retains five scheduled snapshots and preserves manual backups");
    [delegate closeScheduledBackup:nil];
    [testAlertDefaults removeObjectForKey:key];
    [manager removeItemAtPath:folder error:NULL];
    [delegate toggleArchiveConversation:archive];
}

static void ConversationNavigationUI(SmokeDelegate *delegate, NSString *output) {
    UIClient *client=[delegate valueForKey:@"client"];
    NSWindow *chat=[delegate valueForKey:@"chatWindow"];
    NSTextView *composer=[delegate valueForKey:@"composer"];
    NSTextView *transcript=[delegate valueForKey:@"transcript"];
    NSSegmentedControl *sections=[delegate valueForKey:@"sectionControl"];
    NSString *account=[delegate valueForKey:@"accountUIN"];
    [delegate client:client changedStatus:@"Подключено" connected:YES];
    [delegate markAllRead:nil];
    delegate.forcedReading=@NO;
    [delegate selectPeer:@"16001"];
    Draft(delegate,composer,@"До встречи!");
    [delegate client:client receivedMessage:@{@"peer":@"16002",@"id":@"navigation-unread",@"text":@"Новое сообщение",
        @"timestamp":@1793347999,@"outgoing":@NO}];
    sections.selectedSegment=1;
    [delegate changeSection:nil];
    NSMenuItem *pin=[[NSMenuItem alloc] initWithTitle:@"" action:@selector(togglePinConversation:) keyEquivalent:@""];
    pin.representedObject=@"16001";
    [delegate togglePinConversation:pin];
    CheckUI([[[delegate valueForKey:@"visibleContacts"] firstObject][@"aimId"] isEqual:@"16001"] &&
        [[testAlertDefaults arrayForKey:[@"PinnedPeers." stringByAppendingString:account]] containsObject:@"16001"],
        "pin moves an older conversation to the top and saves it by account");
    CheckUI(![[delegate valueForKey:@"favoritePeers"] containsObject:@"16001"],"pin does not change contact favorites");

    KeyInWindow(chat,@"u",NSCommandKeyMask,32);
    CheckUI([[delegate valueForKey:@"selectedPeer"] isEqual:@"16002"] && [[delegate valueForKey:@"transcriptRanges"] objectForKey:@"navigation-unread"] &&
        [[delegate draftSnapshot][@"16001"] isEqual:@"До встречи!"],"next unread opens its message and preserves the previous draft");

    [[delegate valueForKey:@"conversationPeers"] removeObject:@"16003"];
    KeyInWindow(chat,@"k",NSCommandKeyMask,40);
    NSWindow *picker=[delegate valueForKey:@"quickChatWindow"];
    NSSearchField *search=[delegate valueForKey:@"quickChatSearch"];
    NSTableView *results=[delegate valueForKey:@"quickChatTable"];
    CheckUI(picker.isVisible && results.selectedRow==0 && [[[delegate valueForKey:@"quickChatResults"] firstObject][@"contact"][@"aimId"] isEqual:@"16001"],
        "conversation picker opens with the pinned conversation at the top");
    Capture(picker,[output stringByAppendingPathComponent:@"UI-conversation-picker.png"]);
    KeyInWindow(picker,[NSString stringWithFormat:@"%C",(unichar)NSDownArrowFunctionKey],NSFunctionKeyMask,125);
    CheckUI(results.selectedRow==1,"down arrow selects the next result without moving focus out of search");
    search.stringValue=@" iRa ";
    [delegate controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:search]];
    CheckUI(results.numberOfRows==1 && [[[delegate valueForKey:@"quickChatResults"] firstObject][@"contact"][@"aimId"] isEqual:@"16003"],
        "name search also finds a contact without a recent chat");
    search.stringValue=@"16001";
    [delegate controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:search]];
    KeyInWindow(picker,@"\r",0,36);
    CheckUI(!picker.isVisible && [[delegate valueForKey:@"selectedPeer"] isEqual:@"16001"] && [composer.string isEqual:@"До встречи!"],
        "Enter opens the UIN match and restores its draft");
    [delegate showQuickChat:nil];
    KeyInWindow(picker,@"\e",0,53);
    CheckUI(!picker.isVisible && [[delegate valueForKey:@"selectedPeer"] isEqual:@"16001"],"Escape closes the picker without changing conversations");
    [delegate togglePinConversation:pin];
    CheckUI(![[testAlertDefaults arrayForKey:[@"PinnedPeers." stringByAppendingString:account]] containsObject:@"16001"],
        "unpin updates saved account preferences");

    JMHistory *history=[delegate valueForKey:@"history"];
    [history appendMessage:@{@"peer":@"16001",@"id":@"navigation-unknown",@"text":@"Увидимся?",@"timestamp":@1793348000,@"outgoing":@YES,@"delivery":@"unknown"} error:NULL];
    [delegate renderTranscript];
    NSRange retry=[transcript.string rangeOfString:JML(@"Повторить отправку…")];
    CheckUI(retry.location!=NSNotFound && [transcript.textStorage attribute:NSLinkAttributeName atIndex:retry.location effectiveRange:NULL]!=nil,
        "unconfirmed message has a visible manual retry link while online");
    NSUInteger sends=client.sendCount;
    NSMenuItem *appearance=[[NSMenuItem alloc] init];
    appearance.representedObject=@"qip";
    [delegate changeAppearance:appearance];
    client.fixtureConnected=NO;
    NSString *status=@"Нет соединения. Повтор через 2 с…";
    [delegate client:client changedStatus:status connected:NO];
    CheckUI([[[delegate valueForKey:@"composerHint"] stringValue] isEqual:status] && composer.isEditable &&
        [transcript.string rangeOfString:JML(@"Повторить отправку…")].location==NSNotFound,
        "split chat shows reconnection progress while preserving editing and hiding unavailable retry");
    client.fixtureConnected=YES;
    [delegate client:client changedStatus:@"Подключено" connected:YES];
    CheckUI(client.sendCount==sends && [transcript.string rangeOfString:JML(@"Повторить отправку…")].location!=NSNotFound,
        "reconnection restores manual retry without retransmitting an unconfirmed message");
    retry=[transcript.string rangeOfString:JML(@"Повторить отправку…")];
    id retryLink=[transcript.textStorage attribute:NSLinkAttributeName atIndex:retry.location effectiveRange:NULL];
    NSTimer *confirm=[NSTimer timerWithTimeInterval:0.1 target:delegate selector:@selector(acceptRetryConfirmation:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:confirm forMode:NSModalPanelRunLoopMode];
    [delegate textView:transcript clickedOnLink:retryLink atIndex:retry.location];
    [confirm invalidate];
    CheckUI(client.sendCount==sends+1 && [client.sentText isEqual:@"Увидимся?"] && [composer.string isEqual:@"До встречи!"],
        "confirmed link retries only the chosen message and preserves the separate draft");
    FinishSend(client,@"navigation-confirmed",nil);
    appearance.representedObject=@"current";
    [delegate changeAppearance:appearance];
    [delegate markAllRead:nil];
    Draft(delegate,composer,@"");
    ArchiveAndBackupUI(delegate,output);
    [delegate markAllRead:nil];
    [chat makeKeyAndOrderFront:nil];
    delegate.forcedReading=@YES;
}
