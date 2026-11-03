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
