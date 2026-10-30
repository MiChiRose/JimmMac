#import "JMProtocol.h"

NSString * const JMAPIErrorDomain = @"online.jimm.mavericks.api";
NSString *JMString(id value) {
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return @"";
}
NSDictionary *JMDictionary(id value) { return [value isKindOfClass:[NSDictionary class]] ? value : @{}; }
NSArray *JMArray(id value) { return [value isKindOfClass:[NSArray class]] ? value : @[]; }
BOOL JMValidUIN(NSString *text) {
    if (![text length] || [text length] > 20) return NO;
    return [text rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location == NSNotFound;
}
BOOL JMValidRosterName(NSString *text, BOOL allowEmpty) {
    if (![text isKindOfClass:[NSString class]] || text.length>128 || (!allowEmpty && !text.length)) return NO;
    return [text rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location==NSNotFound;
}
static NSString *JMEscape(NSString *text) {
    NSData *bytes = [text dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char *p = [bytes bytes];
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < [bytes length]; i++) {
        unsigned char c = p[i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
            [result appendFormat:@"%c", c];
        else [result appendFormat:@"%%%02X", c];
    }
    return result;
}
NSString *JMFormEncode(NSDictionary *parameters) {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)])
        for (id value in [parameters[key] isKindOfClass:[NSArray class]] ? parameters[key] : @[parameters[key]])
            [parts addObject:[NSString stringWithFormat:@"%@=%@", JMEscape(key), JMEscape(JMString(value))]];
    return [parts componentsJoinedByString:@"&"];
}
NSMutableURLRequest *JMRequest(NSURL *baseURL, NSString *path, NSDictionary *parameters, NSTimeInterval timeout) {
    NSString *url = [[baseURL absoluteString] stringByAppendingString:path];
    NSMutableDictionary *form = [parameters mutableCopy];
    form[@"f"] = @"json";
    // Keep the explicit GET-only contract. Login and message bodies use POST.
    BOOL getOnly = [@[@"/auth/getInfo", @"/aim/fetchEvents", @"/aim/endSession", @"/buddylist/addBuddy", @"/buddylist/removeBuddy", @"/buddylist/moveBuddy", @"/buddylist/setBuddyAttribute", @"/buddylist/addGroup", @"/buddylist/renameGroup", @"/buddylist/removeGroup", @"/presence/get", @"/presence/getProfile", @"/presence/setProfile", @"/presence/setStatus", @"/memberDir/get", @"/memberDir/update", @"/presence/setState", @"/im/setTyping"] containsObject:path];
    if (getOnly) url = [url stringByAppendingFormat:@"?%@", JMFormEncode(form)];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:getOnly ? @"GET" : @"POST"];
    if (!getOnly) {
        [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[JMFormEncode(form) dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [request setValue:@"no-store" forHTTPHeaderField:@"Cache-Control"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"JimmMac/0.1 (OS X 10.9+)" forHTTPHeaderField:@"User-Agent"];
    return request;
}
static NSError *JMError(NSInteger code, NSString *message, NSTimeInterval retry) {
    return [NSError errorWithDomain:JMAPIErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:message, @"retryAfter":@(retry)}];
}
NSDictionary *JMDecodeResponse(NSData *data, NSURLResponse *response, NSError **error) {
    NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (id)response : nil;
    NSDictionary *root = JMDictionary(data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);
    NSDictionary *envelope = JMDictionary(root[@"response"]);
    NSInteger status = [JMString(envelope[@"statusCode"]) integerValue];
    NSTimeInterval retry = 5;
    for (NSString *key in [http allHeaderFields])
        if ([key caseInsensitiveCompare:@"Retry-After"] == NSOrderedSame)
            retry = MAX(1, MIN(3600, [JMString([http allHeaderFields][key]) doubleValue]));
    if (status == 200 && (!http || [http statusCode] < 400)) return JMDictionary(envelope[@"data"]);
    NSInteger code = status ?: ([http statusCode] ?: -1);
    NSString *message = @"Сервер вернул непонятный ответ. Попробуйте подключиться снова.";
    if (code == 330) message = @"Неверный UIN или пароль. Проверьте данные Jimm.online.";
    else if (code == 401) message = @"Сессия истекла. Подключаемся заново…";
    else if (code == 430 || code == 429) message = [NSString stringWithFormat:@"Слишком много запросов. Повторите через %.0f с.", retry];
    else if (code == 602) message = @"Сообщение не доставлено: получатель недоступен, заблокирован или его ящик заполнен.";
    else if (code == 400 || code == 460) message = @"Сервер не принял параметры запроса.";
    else if (code == 462) message = @"Сервер не принял аватар: допустимы GIF, JPEG и PNG размером до 64 КБ.";
    else if (code >= 500) message = @"Сервис Jimm.online временно недоступен.";
    if (error) *error = JMError(code, message, retry);
    return nil;
}
NSString *JMPlainText(NSString *text, BOOL html) {
    if (!html) return text;
    NSRegularExpression *breaks = [NSRegularExpression regularExpressionWithPattern:@"(?i)<br\\s*/?>|</(?:p|div)>" options:0 error:NULL];
    NSString *plain = [breaks stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, [text length]) withTemplate:@"\n"];
    NSRegularExpression *tags = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:0 error:NULL];
    plain = [tags stringByReplacingMatchesInString:plain options:0 range:NSMakeRange(0, [plain length]) withTemplate:@""];
    NSDictionary *entities = @{@"&lt;":@"<", @"&gt;":@">", @"&quot;":@"\"", @"&#39;":@"'", @"&nbsp;":@" "};
    for (NSString *entity in entities) plain = [plain stringByReplacingOccurrencesOfString:entity withString:entities[entity]];
    return [plain stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
}
NSArray *JMContactsFromBuddyList(NSDictionary *buddyList) {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableDictionary *seen = [NSMutableDictionary dictionary];
    for (id groupValue in JMArray(buddyList[@"groups"])) {
        NSDictionary *group = JMDictionary(groupValue);
        for (id buddyValue in JMArray(group[@"buddies"])) {
            NSDictionary *buddy = JMDictionary(buddyValue);
            NSString *uin = JMString(buddy[@"aimId"]);
            if (!JMValidUIN(uin)) continue;
            NSString *groupName=JMString(group[@"name"]);
            NSMutableDictionary *existing=seen[uin];
            if (existing) {
                NSMutableArray *groups=[existing[@"groups"] mutableCopy];
                if (groupName.length && ![groups containsObject:groupName]) [groups addObject:groupName];
                existing[@"groups"]=groups; continue;
            }
            NSMutableDictionary *contact = [buddy mutableCopy];
            contact[@"aimId"] = uin;
            contact[@"group"] = groupName; contact[@"groups"]=groupName.length ? @[groupName] : @[];
            [result addObject:contact]; seen[uin]=contact;
        }
    }
    return result;
}
NSDictionary *JMMessageFromEvent(NSDictionary *event, NSString *ownUIN) {
    NSString *type = JMString(event[@"type"]);
    BOOL outgoing = [type isEqualToString:@"sentIM"];
    if (!outgoing && ![type isEqualToString:@"im"] && ![type isEqualToString:@"offlineIM"]) return nil;
    NSDictionary *data = JMDictionary(event[@"eventData"]);
    NSDictionary *source = JMDictionary(data[@"source"]);
    NSString *peer = outgoing ? JMString(JMDictionary(data[@"dest"])[@"aimId"]) : JMString(source[@"aimId"]);
    if (![peer length]) peer = JMString(data[@"aimId"]);
    if (!JMValidUIN(peer) || ![data[@"message"] isKindOfClass:[NSString class]]) return nil;
    NSString *text = data[@"message"];
    BOOL html = [JMString(data[@"imf"]) isEqualToString:@"html"] || [text rangeOfString:@"<HTML" options:NSCaseInsensitiveSearch].location != NSNotFound;
    NSTimeInterval ts = [JMString(data[@"timestamp"] ?: event[@"timestamp"]) doubleValue];
    NSString *msgID = JMString(data[@"msgId"]);
    if (![msgID length]) msgID = [NSString stringWithFormat:@"event-%@-%@", ownUIN, JMString(event[@"seqNum"])];
    return @{@"peer":peer, @"outgoing":@(outgoing), @"text":JMPlainText(text, html), @"id":msgID,
             @"timestamp":@(ts > 0 ? ts : [[NSDate date] timeIntervalSince1970]),
             @"name":JMString(source[@"friendly"] ?: data[@"friendly"])};
}
