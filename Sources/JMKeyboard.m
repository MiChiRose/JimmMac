#import "JMKeyboard.h"
#import <Carbon/Carbon.h>

static BOOL JMHasMenuShortcut(NSMenu *menu, NSString *key, NSUInteger flags) {
    NSUInteger mask=NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask;
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.keyEquivalent isEqualToString:key] && (item.keyEquivalentModifierMask & mask)==(flags & mask)) return YES;
        if (item.submenu && JMHasMenuShortcut(item.submenu,key,flags)) return YES;
    }
    return NO;
}
static BOOL JMHasButtonShortcut(NSView *view, NSString *key, NSUInteger flags) {
    if ([view isHidden]) return NO;
    NSUInteger mask=NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask;
    if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button=(NSButton *)view;
        if ([button.keyEquivalent isEqualToString:key] && (button.keyEquivalentModifierMask & mask)==(flags & mask)) return YES;
    }
    for (NSView *child in view.subviews) if (JMHasButtonShortcut(child,key,flags)) return YES;
    return NO;
}
static NSEvent *JMCommandEvent(NSApplication *app, NSEvent *event) {
    if (event.type!=NSKeyDown || !(event.modifierFlags & NSCommandKeyMask)) return event;
    NSString *characters=event.charactersIgnoringModifiers;
    if (!characters.length || [characters characterAtIndex:0]<128 || ![[NSCharacterSet letterCharacterSet] characterIsMember:[characters characterAtIndex:0]]) return event;
    NSTextView *editor=[app.keyWindow.firstResponder isKindOfClass:[NSTextView class]] ? (NSTextView *)app.keyWindow.firstResponder : nil;
    if (editor.hasMarkedText) return event;
    // Mavericks can deliver Cyrillic letters even for Command equivalents.
    // Use the system's ASCII-capable layout (including Dvorak), never a hardcoded
    // US key-code table. AppKit still owns validation, modal routing and actions.
    TISInputSourceRef source=TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
    if (!source) return event;
    CFDataRef data=TISGetInputSourceProperty(source,kTISPropertyUnicodeKeyLayoutData);
    UniChar buffer[4]; UniCharCount length=0; UInt32 dead=0;
    UInt32 modifiers=(event.modifierFlags & NSShiftKeyMask) ? (shiftKey >> 8) : 0;
    OSStatus status=data ? UCKeyTranslate((const UCKeyboardLayout *)CFDataGetBytePtr(data),event.keyCode,kUCKeyActionDown,modifiers,LMGetKbdType(),kUCKeyTranslateNoDeadKeysMask,&dead,4,&length,buffer) : paramErr;
    CFRelease(source);
    if (status!=noErr || !length) return event;
    NSString *key=[NSString stringWithCharacters:buffer length:length];
    if (!JMHasMenuShortcut(app.mainMenu,key,event.modifierFlags) && !JMHasButtonShortcut(app.keyWindow.contentView,key,event.modifierFlags)) return event;
    return [NSEvent keyEventWithType:NSKeyDown location:event.locationInWindow modifierFlags:event.modifierFlags timestamp:event.timestamp windowNumber:event.windowNumber context:nil characters:key charactersIgnoringModifiers:key isARepeat:event.isARepeat keyCode:event.keyCode];
}
@implementation JMApplication
- (void)sendEvent:(NSEvent *)event { [super sendEvent:JMCommandEvent(self,event)]; }
@end

static NSInteger JMEscapeEvent(NSWindow *window, NSEvent *event) {
    NSUInteger modifiers=event.modifierFlags & (NSCommandKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSShiftKeyMask);
    if (modifiers || ![event.charactersIgnoringModifiers isEqualToString:@"\e"]) return NO;
    // The input method must get Escape first while a marked sequence is active.
    NSResponder *responder=window.firstResponder;
    if (window.attachedSheet || ([responder isKindOfClass:[NSTextView class]] && [(NSTextView *)responder hasMarkedText])) return -1;
    [window cancelOperation:nil]; return YES;
}
static void JMCancelWindow(NSWindow *window) {
    id delegate=window.delegate;
    if ([delegate respondsToSelector:@selector(handleEscapeInWindow:)]) [(id<JMEscapeWindowDelegate>)delegate handleEscapeInWindow:window];
    else [window performClose:nil];
}

#define JM_WINDOW_COMMANDS \
- (BOOL)performKeyEquivalent:(NSEvent *)event { NSInteger escape=JMEscapeEvent(self,event); return escape ? escape>0 : [super performKeyEquivalent:event]; } \
- (void)cancelOperation:(id)sender { JMCancelWindow(self); } \
- (void)undo:(id)sender { NSUndoManager *manager=self.firstResponder.undoManager; if (manager.canUndo) [manager undo]; } \
- (void)redo:(id)sender { NSUndoManager *manager=self.firstResponder.undoManager; if (manager.canRedo) [manager redo]; } \
- (BOOL)validateMenuItem:(NSMenuItem *)item { \
    if (item.action==@selector(undo:)) return self.firstResponder.undoManager.canUndo; \
    if (item.action==@selector(redo:)) return self.firstResponder.undoManager.canRedo; \
    return [super validateMenuItem:item]; \
}

@implementation JMWindow
JM_WINDOW_COMMANDS
@end
@implementation JMPanel
JM_WINDOW_COMMANDS
@end

@implementation JMContactTable
- (void)drawBackgroundInClipRect:(NSRect)clip {
    if (!self.blueRosterGradient) { [super drawBackgroundInClipRect:clip]; return; }
    NSGradient *gradient=[[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.97 green:0.985 blue:1 alpha:1]
                                                        endingColor:[NSColor colorWithSRGBRed:0.82 green:0.90 blue:0.99 alpha:1]];
    [gradient drawInRect:NSMakeRect(0,NSMinY(clip),NSWidth(self.bounds),NSHeight(clip)) angle:0];
}
- (void)mouseDown:(NSEvent *)event {
    if (self.handleHeaderClick && self.isEnabled) {
        NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
        NSInteger row=[self rowAtPoint:point];
        if (row>=0 && self.handleHeaderClick(row,point.y-NSMinY([self rectOfRow:row]))) return;
    }
    [super mouseDown:event];
}
- (void)keyDown:(NSEvent *)event {
    NSUInteger flags=event.modifierFlags & (NSCommandKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSShiftKeyMask);
    NSString *key=event.charactersIgnoringModifiers;
    if (!flags && ([key isEqualToString:@"\r"] || [key isEqualToString:@"\003"])) {
        if (self.selectedRow>=0 && self.activateAction) [NSApp sendAction:self.activateAction to:self.target from:self];
        return;
    }
    [super keyDown:event];
}
@end
@implementation JMFormTextView
- (void)insertTab:(id)sender { [self.window selectNextKeyView:sender]; }
- (void)insertBacktab:(id)sender { [self.window selectPreviousKeyView:sender]; }
@end
