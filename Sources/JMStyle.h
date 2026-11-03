#import <Cocoa/Cocoa.h>
NSImage *JMFlowerImage(void);
NSImage *JMStatusImage(NSString *state);
NSColor *JMSecondaryTextColor(void);
NSColor *JMSelectionColor(BOOL emphasized);
NSColor *JMLegacyHeaderTopColor(void);
NSColor *JMLegacyHeaderBottomColor(void);
@interface JMChromeView : NSView
@property(nonatomic, strong) NSColor *topColor;
@property(nonatomic, strong) NSColor *bottomColor;
@end
@interface JMContactRowView : NSTableRowView
@end
@interface JMComposerView : NSTextView
@property(nonatomic, copy) NSString *placeholder;
@property(nonatomic, strong) NSUndoManager *composerUndoManager;
@end
@interface JMConversationEmptyView : NSView
@property(nonatomic, strong, readonly) NSButton *writeButton;
- (void)setHasPeer:(BOOL)hasPeer;
@end
@interface JMListCell : NSTableCellView
@property(nonatomic,copy) NSString *groupTitle;
- (CGFloat)groupHeaderHeight;
- (void)configureName:(NSString *)name detail:(NSString *)detail state:(NSString *)state unread:(NSInteger)unread;
- (void)setAvatar:(NSImage *)image;
- (void)setTimestamp:(NSString *)timestamp draft:(BOOL)draft;
- (void)setTimestampTooltip:(NSString *)tooltip;
@end
// Rendering stays in native AppKit cells: tracking, menus, focus and accessibility remain native.
@interface JMThemedButton : NSButton
@end
@interface JMThemedButtonCell : NSButtonCell
@end
@interface JMThemedPopUpButton : NSPopUpButton
@end
@interface JMThemedSegmentedCell : NSSegmentedCell
@end
@interface JMConversationChrome : JMChromeView
@end
@interface JMRosterChrome : JMChromeView
@end
NSImage *JMClassicToolbarImage(NSString *name);
@interface JMThemedSearchField : NSSearchField
@end
@interface JMClassicSendBar : NSView
@end
@interface JMClassicAvatarView : NSImageView
@end
