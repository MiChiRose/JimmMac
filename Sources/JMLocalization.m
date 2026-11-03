#import "JMLocalization.h"
static NSString *selectedLanguage=@"ru";
void JMSetLanguage(NSString *language) { selectedLanguage=[language isEqualToString:@"en"] ? @"en" : @"ru"; }
NSString *JMLanguage(void) { return selectedLanguage; }
NSLocale *JMLocale(void) { return [[NSLocale alloc] initWithLocaleIdentifier:[selectedLanguage isEqual:@"en"] ? @"en_US_POSIX" : @"ru_RU"]; }
NSString *JML(NSString *russian) {
    if (![selectedLanguage isEqualToString:@"en"]) return russian;
    static NSDictionary *english; static dispatch_once_t once;
    dispatch_once(&once,^{ english=@{
#include "JMLocalizationTable.inc"
    }; });
    return english[russian] ?: russian;
}
