#import "JMLocalization.h"
#import "JMTextTools.h"
#import "JMProtocol.h"
#import <math.h>
NSString *JMQuotedMessage(NSDictionary *message, NSString *name) {
    NSString *text=JMString(message[@"text"]);
    text=[[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    name=[[JMString(name) componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@" "];
    if (!name.length) name=JML(@"Собеседник");
    NSTimeInterval timestamp=[message[@"timestamp"] doubleValue]; NSString *heading=name;
    if (isfinite(timestamp) && timestamp>0) {
        NSDateFormatter *format=[[NSDateFormatter alloc] init]; format.dateFormat=@"dd.MM.yyyy HH:mm";
        heading=[NSString stringWithFormat:@"%@, %@",name,[format stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]]];
    }
    return [NSString stringWithFormat:@"%@:\n> %@\n\n",heading,[[text componentsSeparatedByString:@"\n"] componentsJoinedByString:@"\n> "]];
}
NSURL *JMExternalURL(id value) {
    NSURL *url=[value isKindOfClass:[NSURL class]] ? value : ([value isKindOfClass:[NSString class]] ? [NSURL URLWithString:value] : nil);
    NSString *scheme=[url.scheme lowercaseString];
    if (([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) && url.host.length) return url;
    if ([scheme isEqualToString:@"mailto"] && url.resourceSpecifier.length) return url;
    return nil;
}
NSArray *JMLinksInText(NSString *text) {
    static NSDataDetector *detector;
    static dispatch_once_t once;
    dispatch_once(&once,^{ detector=[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL]; });
    NSMutableArray *links=[NSMutableArray array];
    for (NSTextCheckingResult *match in [detector matchesInString:text ?: @"" options:0 range:NSMakeRange(0,text.length)])
        if (JMExternalURL(match.URL)) [links addObject:match];
    return links;
}
NSString *JMHistorySnippet(NSString *text, NSString *query) {
    if (!text.length) return @"";
    NSRange match=[text rangeOfString:query ?: @"" options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
    NSUInteger start=match.location!=NSNotFound && match.location>40 ? match.location-40 : 0;
    NSRange range=[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(start,MIN((NSUInteger)140,text.length-start))];
    NSString *snippet=[text substringWithRange:range];
    snippet=[[snippet componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
    return [NSString stringWithFormat:@"%@%@%@",range.location ? @"…" : @"",snippet,NSMaxRange(range)<text.length ? @"…" : @""];
}
