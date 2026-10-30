#import "JMChatPreferences.h"
#import <math.h>
@interface JMChatPreferences ()
@property(nonatomic, strong) NSUserDefaults *defaults;
@property(nonatomic, copy, readwrite) NSString *family;
@property(nonatomic, readwrite) CGFloat size;
@property(nonatomic, strong, readwrite) NSFont *messageFont;
@property(nonatomic, strong, readwrite) NSFont *headingFont;
@end
@implementation JMChatPreferences
- (id)initWithDefaults:(NSUserDefaults *)defaults {
    self=[super init]; if (!self) return nil;
    self.defaults=defaults ?: [NSUserDefaults standardUserDefaults];
    _sendWithCommandReturn=[self.defaults boolForKey:@"ChatSendWithCommandReturn"];
    [self applyFamily:[self.defaults objectForKey:@"ChatFontFamily"] size:[self.defaults doubleForKey:@"ChatFontSize"]];
    return self;
}
- (void)applyFamily:(NSString *)family size:(CGFloat)size {
    if (![family isKindOfClass:[NSString class]]) family=@"";
    if (!isfinite(size) || size<9 || size>28) size=13;
    NSFontManager *manager=[NSFontManager sharedFontManager];
    NSFont *font=family.length ? [manager fontWithFamily:family traits:0 weight:5 size:size] : nil;
    if (!font) { family=@""; font=[NSFont systemFontOfSize:size]; }
    self.family=family; self.size=size; self.messageFont=font;
    NSFont *heading=[manager convertFont:font toSize:MAX(9,size-1)];
    self.headingFont=[manager convertFont:heading toHaveTrait:NSBoldFontMask] ?: [NSFont boldSystemFontOfSize:MAX(9,size-1)];
}
- (void)setFamily:(NSString *)family size:(CGFloat)size {
    [self applyFamily:family size:size];
    [self.defaults setObject:self.family forKey:@"ChatFontFamily"]; [self.defaults setDouble:self.size forKey:@"ChatFontSize"];
}
- (void)reset { [self setFamily:@"" size:13]; }
- (void)setSendWithCommandReturn:(BOOL)value { _sendWithCommandReturn=value; [self.defaults setBool:value forKey:@"ChatSendWithCommandReturn"]; }
@end
