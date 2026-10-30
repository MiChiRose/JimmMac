#import <Cocoa/Cocoa.h>
NSImage *JMFlowerImage(void);
NSImage *JMStatusImage(NSString *state);
NSColor *JMSecondaryTextColor(void);
NSColor *JMSelectionColor(BOOL emphasized);
@interface JMChromeView : NSView
@property(nonatomic, strong) NSColor *topColor;
@property(nonatomic, strong) NSColor *bottomColor;
@end
@interface JMContactRowView : NSTableRowView
@end
@interface JMComposerView : NSTextView
@property(nonatomic, copy) NSString *placeholder;
@end
@interface JMConversationEmptyView : NSView
@property(nonatomic, strong, readonly) NSButton *writeButton;
- (void)setHasPeer:(BOOL)hasPeer;
@end
@interface JMListCell : NSTableCellView
- (void)configureName:(NSString *)name detail:(NSString *)detail state:(NSString *)state unread:(NSInteger)unread;
- (void)setAvatar:(NSImage *)image;
- (void)setTimestamp:(NSString *)timestamp draft:(BOOL)draft;
- (void)setTimestampTooltip:(NSString *)tooltip;
@end
