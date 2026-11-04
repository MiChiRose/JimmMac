#import <Cocoa/Cocoa.h>

@interface JMApplication : NSApplication
@end
// Keep editing commands on the native responder chain. No global event monitor.
@interface JMWindow : NSWindow
@end
@interface JMPanel : NSPanel
@end
@interface JMContactTable : NSTableView
@property(nonatomic) SEL activateAction;
@property(nonatomic) BOOL blueRosterGradient;
@property(nonatomic, copy) BOOL (^handleHeaderClick)(NSInteger row, CGFloat offset);
@end
@interface JMFormTextView : NSTextView
@end

@protocol JMEscapeWindowDelegate <NSObject>
- (void)handleEscapeInWindow:(NSWindow *)window;
@end
