#import "JMTheme.h"
static JMThemeMode selectedTheme=JMThemeCurrent;
void JMSetTheme(NSString *identifier) { selectedTheme=[identifier isEqual:@"mac2011"] ? JMThemeMac2011 : ([identifier isEqual:@"pro2003"] ? JMThemePro2003 : JMThemeCurrent); }
JMThemeMode JMTheme(void) { return selectedTheme; }
NSString *JMThemeIdentifier(void) { return selectedTheme==JMThemeMac2011 ? @"mac2011" : (selectedTheme==JMThemePro2003 ? @"pro2003" : @"current"); }
NSColor *JMThemeBackground(void) { return selectedTheme==JMThemeMac2011 ? [NSColor whiteColor] : (selectedTheme==JMThemePro2003 ? [NSColor colorWithSRGBRed:215.0/255 green:217.0/255 blue:231.0/255 alpha:1] : [NSColor windowBackgroundColor]); }
NSColor *JMThemeHeaderTop(void) { return selectedTheme==JMThemeMac2011 ? [NSColor colorWithCalibratedRed:0.62 green:0.85 blue:0.45 alpha:1] : (selectedTheme==JMThemePro2003 ? [NSColor colorWithCalibratedRed:0.97 green:0.98 blue:1 alpha:1] : [NSColor colorWithCalibratedRed:0.97 green:0.99 blue:0.94 alpha:1]); }
NSColor *JMThemeHeaderBottom(void) { return selectedTheme==JMThemeMac2011 ? [NSColor colorWithCalibratedRed:0.02 green:0.63 blue:0.01 alpha:1] : (selectedTheme==JMThemePro2003 ? [NSColor colorWithSRGBRed:215.0/255 green:217.0/255 blue:231.0/255 alpha:1] : [NSColor colorWithCalibratedRed:0.81 green:0.88 blue:0.75 alpha:1]); }
NSFont *JMThemeFont(NSFont *preferred,NSString *family) {
    if (family.length || selectedTheme==JMThemeCurrent) return preferred;
    NSString *name=selectedTheme==JMThemeMac2011 ? @"Arial" : @"Tahoma";
    NSFont *font=[NSFont fontWithName:name size:preferred.pointSize] ?: [NSFont fontWithName:@"LucidaGrande" size:preferred.pointSize] ?: preferred;
    NSFontManager *manager=[NSFontManager sharedFontManager]; NSFontTraitMask traits=[manager traitsOfFont:preferred] & (NSBoldFontMask|NSItalicFontMask);
    return traits ? ([manager convertFont:font toHaveTrait:traits] ?: font) : font;
}
