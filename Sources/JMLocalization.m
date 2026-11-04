#import "JMLocalization.h"

static NSString *selectedLanguage=@"ru";

void JMSetLanguage(NSString *language) {
    selectedLanguage=[@[@"ru",@"en",@"uk",@"be"] containsObject:language ?: @""] ? [language copy] : @"ru";
}

NSString *JMLanguage(void) { return selectedLanguage; }

NSLocale *JMLocale(void) {
    NSDictionary *locales=@{@"ru":@"ru_RU",@"en":@"en_US_POSIX",@"uk":@"uk_UA",@"be":@"be_BY"};
    return [[NSLocale alloc] initWithLocaleIdentifier:locales[selectedLanguage]];
}

NSString *JML(NSString *russian) {
    if ([selectedLanguage isEqual:@"ru"]) return russian;
    static NSDictionary *tables;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        tables=@{
            @"en":@{
#include "JMLocalizationTable.inc"
            },
            @"uk":@{
#include "JMLocalizationUK.inc"
            },
            @"be":@{
#include "JMLocalizationBE.inc"
            }
        };
    });
    return tables[selectedLanguage][russian] ?: russian;
}
