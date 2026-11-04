#import "JMTheme.h"
static JMThemeMode selectedTheme=JMThemeCurrent;
NSArray *JMThemeIdentifiers(void) { return @[@"current",@"mac2011",@"pro2003",@"qip",@"jimm"]; }
void JMSetTheme(NSString *identifier) {
    NSUInteger index=[JMThemeIdentifiers() indexOfObject:identifier ?: @""];
    selectedTheme=index==NSNotFound ? JMThemeCurrent : (JMThemeMode)index;
}
JMThemeMode JMTheme(void) { return selectedTheme; }
NSString *JMThemeIdentifier(void) { return JMThemeIdentifiers()[(NSUInteger)selectedTheme]; }
BOOL JMThemeIsMobile(void) { return selectedTheme==JMThemeQIP || selectedTheme==JMThemeJimm; }
static NSColor *RGB(unsigned r,unsigned g,unsigned b) { return [NSColor colorWithSRGBRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]; }
NSColor *JMThemeBackground(void) {
    switch (selectedTheme) {
        case JMThemeQIP: return RGB(235,233,217);
        case JMThemeJimm: return RGB(204,204,204);
        case JMThemeMac2011: return [NSColor whiteColor];
        case JMThemePro2003: return RGB(215,217,231);
        default: return [NSColor windowBackgroundColor];
    }
}
NSColor *JMThemeTranscriptColor(void) {
    switch (selectedTheme) {
        case JMThemeQIP: return RGB(245,249,255);
        case JMThemeJimm: return RGB(244,244,244);
        case JMThemeMac2011: return RGB(232,232,222);
        default: return [NSColor whiteColor];
    }
}
NSColor *JMThemeHeaderTop(void) {
    switch (selectedTheme) {
        case JMThemeQIP: return RGB(76,110,150);
        case JMThemeJimm: return RGB(153,0,0);
        case JMThemeMac2011: return [NSColor colorWithCalibratedRed:0.62 green:0.85 blue:0.45 alpha:1];
        case JMThemePro2003: return [NSColor colorWithCalibratedRed:0.97 green:0.98 blue:1 alpha:1];
        default: return [NSColor colorWithCalibratedRed:0.97 green:0.99 blue:0.94 alpha:1];
    }
}
NSColor *JMThemeHeaderBottom(void) {
    switch (selectedTheme) {
        case JMThemeQIP: return RGB(130,171,211);
        case JMThemeJimm: return RGB(153,0,0);
        case JMThemeMac2011: return [NSColor colorWithCalibratedRed:0.02 green:0.63 blue:0.01 alpha:1];
        case JMThemePro2003: return RGB(215,217,231);
        default: return [NSColor colorWithCalibratedRed:0.81 green:0.88 blue:0.75 alpha:1];
    }
}
NSColor *JMThemeHeaderInk(void) { return JMThemeIsMobile() ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite:0.12 alpha:1]; }
NSFont *JMThemeFont(NSFont *preferred,NSString *family) {
    if (family.length || selectedTheme==JMThemeCurrent) return preferred;
    NSString *name=selectedTheme==JMThemeMac2011 || selectedTheme==JMThemeJimm ? @"Arial" : @"Tahoma";
    NSFont *font=[NSFont fontWithName:name size:preferred.pointSize] ?: [NSFont fontWithName:@"LucidaGrande" size:preferred.pointSize] ?: preferred;
    NSFontManager *manager=[NSFontManager sharedFontManager]; NSFontTraitMask traits=[manager traitsOfFont:preferred] & (NSBoldFontMask|NSItalicFontMask);
    return traits ? ([manager convertFont:font toHaveTrait:traits] ?: font) : font;
}
