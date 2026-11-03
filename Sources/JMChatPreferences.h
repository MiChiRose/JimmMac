#import <Cocoa/Cocoa.h>
@interface JMChatPreferences : NSObject
@property(nonatomic, copy, readonly) NSString *family;
@property(nonatomic, readonly) CGFloat size;
@property(nonatomic, strong, readonly) NSFont *messageFont;
@property(nonatomic, strong, readonly) NSFont *headingFont;
@property(nonatomic) BOOL sendWithCommandReturn;
@property(nonatomic) BOOL emoticonsEnabled;
- (id)initWithDefaults:(NSUserDefaults *)defaults;
- (void)setFamily:(NSString *)family size:(CGFloat)size;
- (void)reset;
@end
