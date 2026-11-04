#import "JMDiagnostics.h"
#import "JMLocalization.h"
#import <math.h>
NSArray *JMSafeDiagnosticEntries(NSArray *entries) {
    NSSet *paths=[NSSet setWithArray:@[@"/auth/clientLogin",@"/auth/getInfo",@"/aim/startSession",@"/aim/fetchEvents",@"/aim/endSession",@"/im/sendIM",@"/im/setTyping",@"/imlog/fetchStoredIMs",@"/preference/getPermitDeny",@"/preference/setPermitDeny",@"/presence/get",@"/presence/setState",@"/buddylist/getBuddyList",@"/buddylist/moveBuddy",@"/buddylist/addBuddy",@"/buddylist/removeBuddy",@"/buddylist/setBuddyAttribute",@"/buddylist/addGroup",@"/buddylist/removeGroup",@"/buddylist/renameGroup",@"/memberDir/update",@"/presence/getProfile",@"/presence/setProfile",@"/presence/setStatus",@"/memberDir/get",@"/memberDir/set",@"/aim/getProfile",@"/aim/setProfile",@"/expressions/upload"]];
    NSSet *domains=[NSSet setWithArray:@[@"",NSURLErrorDomain,@"online.jimm.api",@"online.jimm.mavericks.api",@"online.jimm.http",NSCocoaErrorDomain,NSPOSIXErrorDomain,@"kCFErrorDomainCFNetwork"]];
    NSMutableArray *safe=[NSMutableArray array];
    for (id value in entries) {
        if (![value isKindOfClass:[NSDictionary class]] || ![paths containsObject:value[@"endpoint"]]) continue;
        NSString *domain=[domains containsObject:value[@"errorDomain"]] ? value[@"errorDomain"] : @"other";
        NSMutableDictionary *row=[@{@"endpoint":value[@"endpoint"],@"errorDomain":domain} mutableCopy];
        for (NSString *key in @[@"http",@"api",@"errorCode",@"time"]) row[key]=[value[key] isKindOfClass:[NSNumber class]] && isfinite([value[key] doubleValue]) ? value[key] : @0;
        if ([row[@"time"] doubleValue]<0 || [row[@"time"] doubleValue]>4102444800.0) row[@"time"]=@0;
        [safe addObject:row];
    }
    return safe.count>20 ? [safe subarrayWithRange:NSMakeRange(safe.count-20,20)] : safe;
}
NSString *JMDiagnosticReport(NSDictionary *bundle,NSString *system,NSString *connection,BOOL legacy,NSArray *entries) {
    NSString *state=[@[@"connected",@"offline"] containsObject:connection] ? connection : @"disconnected";
    NSMutableString *report=[NSMutableString stringWithFormat:@"JimmMac %@ (%@)\nOS: %@\nArchitecture: Intel x86_64\nConnection: %@\nTransport: %@\n\n",bundle[@"CFBundleShortVersionString"] ?: @"0.16.0",bundle[@"CFBundleVersion"] ?: @"25",system,state,legacy ? @"NSURLConnection" : @"NSURLSession"];
    [report appendFormat:@"%@\n",JML(@"Отчёт не содержит UIN, имён, паролей, токенов и переписки.")];
    NSArray *safe=JMSafeDiagnosticEntries(entries); NSDictionary *lastFailure=nil;
    for (NSDictionary *row in safe) if ([row[@"errorCode"] integerValue] || [row[@"http"] integerValue]>=400 || [row[@"api"] integerValue]>=400) lastFailure=row;
    if (!safe.count) [report appendFormat:@"\n%@\n",JML(@"Сетевых запросов в этой сессии ещё не было.")];
    if (lastFailure) [report appendFormat:@"\nLast error: %@ HTTP %@ API %@ %@ %@\n",lastFailure[@"endpoint"],lastFailure[@"http"],lastFailure[@"api"],lastFailure[@"errorDomain"],lastFailure[@"errorCode"]];
    [report appendString:@"\nRecent requests (UTC):\n"];
    NSDateFormatter *date=[[NSDateFormatter alloc] init]; date.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]; date.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0]; date.dateFormat=@"yyyy-MM-dd HH:mm:ss";
    for (NSDictionary *row in safe) [report appendFormat:@"%@ %@ HTTP %@ API %@ %@ %@\n",[date stringFromDate:[NSDate dateWithTimeIntervalSince1970:[row[@"time"] doubleValue]]],row[@"endpoint"],row[@"http"],row[@"api"],row[@"errorDomain"],row[@"errorCode"]];
    return report;
}
