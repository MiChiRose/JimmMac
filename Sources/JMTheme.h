#import <Cocoa/Cocoa.h>
typedef NS_ENUM(NSInteger,JMThemeMode) { JMThemeCurrent, JMThemeMac2011, JMThemePro2003 };
void JMSetTheme(NSString *identifier);
JMThemeMode JMTheme(void);
NSString *JMThemeIdentifier(void);
NSColor *JMThemeBackground(void);
NSColor *JMThemeHeaderTop(void);
NSColor *JMThemeHeaderBottom(void);
NSFont *JMThemeFont(NSFont *preferred,NSString *family);
