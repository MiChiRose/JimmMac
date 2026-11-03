#import "JMTheme.h"
static JMThemeMode selectedTheme=JMThemeCurrent;
void JMSetTheme(NSString *identifier) { selectedTheme=[identifier isEqual:@"mac2011"] ? JMThemeMac2011 : ([identifier isEqual:@"pro2003"] ? JMThemePro2003 : JMThemeCurrent); }
JMThemeMode JMTheme(void) { return selectedTheme; }
NSString *JMThemeIdentifier(void) { return selectedTheme==JMThemeMac2011 ? @"mac2011" : (selectedTheme==JMThemePro2003 ? @"pro2003" : @"current"); }
NSColor *JMThemeBackground(void) { return selectedTheme==JMThemeMac2011 ? [NSColor whiteColor] : (selectedTheme==JMThemePro2003 ? [NSColor colorWithCalibratedRed:0.83 green:0.82 blue:0.78 alpha:1] : [NSColor windowBackgroundColor]); }
NSColor *JMThemeHeaderTop(void) { return selectedTheme==JMThemeMac2011 ? [NSColor colorWithCalibratedRed:0.69 green:0.86 blue:0.18 alpha:1] : (selectedTheme==JMThemePro2003 ? [NSColor colorWithCalibratedRed:0.92 green:0.91 blue:0.87 alpha:1] : [NSColor colorWithCalibratedRed:0.97 green:0.99 blue:0.94 alpha:1]); }
NSColor *JMThemeHeaderBottom(void) { return selectedTheme==JMThemeMac2011 ? [NSColor colorWithCalibratedRed:0.48 green:0.72 blue:0.04 alpha:1] : (selectedTheme==JMThemePro2003 ? [NSColor colorWithCalibratedRed:0.83 green:0.82 blue:0.78 alpha:1] : [NSColor colorWithCalibratedRed:0.81 green:0.88 blue:0.75 alpha:1]); }
NSFont *JMThemeFont(NSFont *preferred,NSString *family) {
    if (family.length || selectedTheme==JMThemeCurrent) return preferred;
    NSString *name=selectedTheme==JMThemeMac2011 ? @"Arial" : @"Tahoma";
    return [NSFont fontWithName:name size:preferred.pointSize] ?: [NSFont fontWithName:@"LucidaGrande" size:preferred.pointSize] ?: preferred;
}
