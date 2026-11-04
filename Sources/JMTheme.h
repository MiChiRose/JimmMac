#import <Cocoa/Cocoa.h>
typedef NS_ENUM(NSInteger,JMThemeMode) { JMThemeCurrent, JMThemeMac2011, JMThemePro2003, JMThemeQIP, JMThemeJimm };
void JMSetTheme(NSString *identifier);
JMThemeMode JMTheme(void);
BOOL JMThemeIsMobile(void);
NSArray *JMThemeIdentifiers(void);
NSColor *JMThemeHeaderInk(void);
NSString *JMThemeIdentifier(void);
NSColor *JMThemeBackground(void);
NSColor *JMThemeTranscriptColor(void);
NSColor *JMThemeHeaderTop(void);
NSColor *JMThemeHeaderBottom(void);
NSFont *JMThemeFont(NSFont *preferred,NSString *family);
