#import "JMLocalization.h"
#import "JMAPIClient.h"
#import "JMProtocol.h"
#import "JMHTTPClient.h"
#import <math.h>

@interface JMAPIClient ()
@property(nonatomic, strong) JMHTTPClient *network;
@property(nonatomic, strong) JMHTTPTask *pollTask;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, strong) NSDate *tokenExpiration;
@property(nonatomic) BOOL deliverLoginToken;
@property(nonatomic) BOOL usingSavedToken;
@property(nonatomic, copy) NSString *sessionID;
@property(nonatomic, copy, readwrite) NSString *uin;
@property(nonatomic, readwrite) BOOL connected;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) long long sequence;
@property(nonatomic) NSUInteger failures;
@property(nonatomic, strong) NSMutableArray *diagnosticEntries;
@property(nonatomic, strong) NSMutableDictionary *typingLastSent;
@property(nonatomic, strong) NSMutableDictionary *typingPending;
@property(nonatomic, strong) NSMutableSet *typingScheduled;
@property(nonatomic) NSUInteger pollSerial;
@property(nonatomic) NSUInteger sessionSerial;
@property(nonatomic) BOOL polling;
@property(nonatomic, copy) NSString *preferredPresence;
@end

@implementation JMAPIClient
- (NSURL *)baseURL { return [NSURL URLWithString:@"https://jimm.online/webapi"]; }
- (NSArray *)protocolClasses { return nil; }
- (BOOL)useLegacyTransport { return NO; }
- (JMHTTPClient *)makeNetwork { return [[JMHTTPClient alloc] initWithProtocolClasses:[self protocolClasses] legacy:[self useLegacyTransport]]; }
- (void)status:(NSString *)text connected:(BOOL)connected {
    self.connected = connected;
    [self.delegate client:self changedStatus:text connected:connected];
}
- (void)recordDiagnosticForPath:(NSString *)path data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    if (![[[self baseURL] host] isEqualToString:@"jimm.online"]) return;
    if (!self.diagnosticEntries) self.diagnosticEntries = [NSMutableArray array];
    NSDictionary *json = JMDictionary(data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);
    NSInteger http = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
    NSInteger api = [JMString(JMDictionary(json[@"response"])[@"statusCode"]) integerValue];
    // A strict allowlist of metadata only. Never record the URL/query/body,
    // UIN, token, session ID, messages or NSError's userInfo.
    [self.diagnosticEntries addObject:@{@"endpoint":path, @"http":@(http), @"api":@(api),
        @"errorDomain":error.domain ?: @"", @"errorCode":@(error.code),
        @"version":@"0.14.0", @"time":@([[NSDate date] timeIntervalSince1970])}];
    if ([self.diagnosticEntries count] > 20) [self.diagnosticEntries removeObjectAtIndex:0];
    NSURL *root = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory = [root URLByAppendingPathComponent:@"JimmMac" isDirectory:YES];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL]) return;
    NSURL *file = [directory URLByAppendingPathComponent:@"network-diagnostics.json"];
    NSData *safeData = [NSJSONSerialization dataWithJSONObject:self.diagnosticEntries options:0 error:NULL];
    if ([safeData writeToURL:file options:NSDataWritingAtomic error:NULL])
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:[file path] error:NULL];
}
- (JMHTTPTask *)call:(NSString *)path parameters:(NSDictionary *)parameters timeout:(NSTimeInterval)timeout
                  completion:(void (^)(NSDictionary *, NSError *))completion {
    return [self performRequest:JMRequest([self baseURL],path,parameters,timeout) path:path completion:completion];
}
- (JMHTTPTask *)performRequest:(NSURLRequest *)request path:(NSString *)path completion:(void (^)(NSDictionary *, NSError *))completion {
    NSUInteger generation = self.generation;
    JMHTTPTask *task = [self.network dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *transportError) {
        if (generation != self.generation) return;
        NSError *error = transportError;
        BOOL emptyTypingOK = [path isEqualToString:@"/im/setTyping"] && ![data length] && [response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode] == 200;
        NSDictionary *result = error ? nil : (emptyTypingOK ? @{} : JMDecodeResponse(data, response, &error));
        [self recordDiagnosticForPath:path data:data response:response error:error];
        completion(result, error);
    }];
    [task resume];
    return task;
}
- (void)prepareLoginWithUIN:(NSString *)uin {
    [self disconnect];
    self.uin = uin;
    if (!self.diagnosticEntries) self.diagnosticEntries = [NSMutableArray array];
    self.usingSavedToken=NO;
    self.typingLastSent = [NSMutableDictionary dictionary]; self.typingPending = [NSMutableDictionary dictionary]; self.typingScheduled = [NSMutableSet set];
    self.preferredPresence=nil;
    self.sequence = 0; self.failures = 0;
    self.network=[self makeNetwork];
}
- (void)loginWithUIN:(NSString *)uin password:(NSString *)password { [self loginWithUIN:uin password:password longTerm:NO]; }
- (void)loginWithUIN:(NSString *)uin password:(NSString *)password longTerm:(BOOL)longTerm {
    [self prepareLoginWithUIN:uin];
    [self status:JML(@"Проверяем UIN и пароль…") connected:NO];
    [self call:@"/auth/clientLogin" parameters:@{@"s":uin,@"pwd":password,@"devId":@"JimmMac-Mavericks",@"tokenType":longTerm ? @"longterm" : @"shortterm"} timeout:30 completion:^(NSDictionary *data,NSError *error) {
        NSDictionary *issued=JMDictionary(data[@"token"]); NSString *token=JMString(issued[@"a"]);
        if (error || !token.length) { [self loginFailed:error]; return; }
        NSString *identity=JMString(data[@"loginId"]);
        if (identity.length && ![identity isEqualToString:uin]) { [self loginFailed:[NSError errorWithDomain:JMAPIErrorDomain code:401 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер вернул другой аккаунт. Вход отменён.")}]]; return; }
        self.token=token; self.deliverLoginToken=YES;
        NSTimeInterval lifetime=[JMString(issued[@"expiresIn"] ?: data[@"tokenExpiresIn"]) doubleValue];
        self.tokenExpiration=isfinite(lifetime) && lifetime>0 && lifetime<=400*86400 ? [NSDate dateWithTimeIntervalSinceNow:lifetime] : nil;
        [self startSession];
    }];
}
- (void)resumeWithUIN:(NSString *)uin token:(NSString *)token {
    [self prepareLoginWithUIN:uin];
    if (!JMValidUIN(uin) || ![token isKindOfClass:[NSString class]] || !token.length || token.length>16384) { [self loginFailed:nil]; return; }
    self.token=token; self.usingSavedToken=YES; [self verifySavedToken];
}
- (void)verifySavedToken {
    [self status:JML(@"Восстанавливаем сохранённый вход…") connected:NO];
    [self call:@"/auth/getInfo" parameters:@{@"a":self.token} timeout:20 completion:^(NSDictionary *data,NSError *error) {
        if (error) {
            if ([error.domain isEqualToString:JMAPIErrorDomain] && (error.code==401 || error.code==330)) { [self loginFailed:error]; return; }
            NSTimeInterval delay=[self delayForError:error];
            [self status:[NSString stringWithFormat:JML(@"Нет соединения. Повтор входа через %.0f с…"),delay] connected:NO];
            [self later:delay block:^{ [self verifySavedToken]; }]; return;
        }
        if (![JMString(JMDictionary(data[@"userData"])[@"loginId"]) isEqualToString:self.uin]) { [self loginFailed:[NSError errorWithDomain:JMAPIErrorDomain code:401 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сохранённый вход относится к другому UIN. Введите пароль заново.")}]]; return; }
        [self startSession];
    }];
}
- (void)loginFailed:(NSError *)error {
    if (!error) error = [NSError errorWithDomain:JMAPIErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер не вернул данные для входа.")}];
    if (self.usingSavedToken && [error.domain isEqual:JMAPIErrorDomain] && (error.code==330 || error.code==401)) error=[NSError errorWithDomain:error.domain code:error.code userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер отклонил сохранённый вход. Введите UIN и пароль заново; после входа можно снова включить «Запомнить меня».")}];
    [self disconnect];
    [self.delegate client:self failedLogin:error];
}
- (void)startSession {
    NSUInteger attempt = ++self.sessionSerial;
    [self status:JML(@"Подключаемся к Jimm.online…") connected:NO];
    [self call:@"/aim/startSession" parameters:@{@"a":self.token, @"events":@"buddylist,presence,im,offlineIM,sentIM,typing,myInfo,sessionEnded,rateLimit",
                                              @"clientName":@"JimmMac Legacy", @"clientVersion":@"0.14.0", @"timeout":@"60"}
           timeout:30 completion:^(NSDictionary *data, NSError *error) {
        if (attempt != self.sessionSerial) return;
        if (error) {
            if (error.code == 401 || error.code == 330) { [self loginFailed:error]; return; }
            [self retrySessionAfterError:error]; return;
        }
        NSString *sid = JMString(data[@"aimsid"]);
        if (![sid length]) { [self loginFailed:nil]; return; }
        self.sessionID = sid; self.sequence = 0; self.failures = 0;
        NSDictionary *events = JMDictionary(data[@"events"]);
        [self.delegate client:self receivedBuddyList:JMDictionary(events[@"buddylist"])];
        if ([self.delegate respondsToSelector:@selector(client:receivedOwnInfo:)]) [self.delegate client:self receivedOwnInfo:JMDictionary(data[@"myInfo"])];
        if (self.deliverLoginToken && [self.delegate respondsToSelector:@selector(client:authenticatedWithToken:expiresAt:)]) [self.delegate client:self authenticatedWithToken:self.token expiresAt:self.tokenExpiration];
        self.deliverLoginToken=NO;
        [self status:JML(@"Подключено") connected:YES];
        NSString *state=JMString(JMDictionary(data[@"myInfo"])[@"state"]);
        if (self.preferredPresence && ![self.preferredPresence isEqualToString:state])
            [self setPresenceState:self.preferredPresence completion:^(NSDictionary *info,NSError *error) {}];
        else if (!self.preferredPresence && state.length) self.preferredPresence=state;
        [self schedulePoll:0.1];
    }];
}
- (void)later:(NSTimeInterval)seconds block:(void (^)(void))block {
    NSUInteger generation = self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == self.generation && self.network) block();
    });
}
- (NSTimeInterval)delayForError:(NSError *)error {
    self.failures++;
    if ([error.domain isEqualToString:JMAPIErrorDomain] && (error.code == 430 || error.code == 429))
        return MAX(1, [error.userInfo[@"retryAfter"] doubleValue]);
    return MIN(30, pow(2, MIN(self.failures, (NSUInteger)5)));
}
- (void)retrySessionAfterError:(NSError *)error {
    NSTimeInterval delay = [self delayForError:error];
    NSUInteger attempt = self.sessionSerial;
    [self status:[NSString stringWithFormat:JML(@"Нет соединения. Повтор через %.0f с…"), delay] connected:NO];
    [self later:delay block:^{ if (attempt == self.sessionSerial) [self startSession]; }];
}
- (void)schedulePoll:(NSTimeInterval)delay {
    NSString *sid = self.sessionID;
    [self later:delay block:^{ if ([sid isEqualToString:self.sessionID]) [self poll]; }];
}
- (void)poll {
    if (![self.sessionID length] || self.polling) return;
    self.polling = YES;
    NSUInteger attempt = ++self.pollSerial;
    self.pollTask = [self call:@"/aim/fetchEvents" parameters:@{@"aimsid":self.sessionID, @"seqNum":@(self.sequence), @"timeout":@"60000"}
                      timeout:75 completion:^(NSDictionary *data, NSError *error) {
        if (attempt != self.pollSerial) return;
        self.pollTask = nil; self.polling = NO;
        if (error) {
            if ([error.domain isEqualToString:JMAPIErrorDomain] && error.code == 401) {
                self.sessionID = nil; [self startSession]; return;
            }
            NSTimeInterval delay = [self delayForError:error];
            NSString *reason = [error.domain isEqualToString:JMAPIErrorDomain] ? [NSString stringWithFormat:@"API %ld", (long)error.code] : JML(@"сеть недоступна");
            [self status:[NSString stringWithFormat:JML(@"Соединение прервано (%@). Повтор через %.0f с…"), reason, delay] connected:NO];
            [self schedulePoll:delay]; return;
        }
        self.failures = 0;
        for (id value in JMArray(data[@"events"])) {
            NSDictionary *event = JMDictionary(value);
            NSString *type = JMString(event[@"type"]);
            NSDictionary *payload = JMDictionary(event[@"eventData"]);
            if ([type isEqualToString:@"buddylist"]) [self.delegate client:self receivedBuddyList:payload];
            else if ([type isEqualToString:@"presence"]) [self.delegate client:self receivedPresence:payload];
            else if ([type isEqualToString:@"typing"] && [self.delegate respondsToSelector:@selector(client:receivedTyping:)]) [self.delegate client:self receivedTyping:payload];
            else if ([type isEqualToString:@"myInfo"]) {
                NSString *state=JMString(payload[@"state"]);
                if ([@[@"online",@"away",@"dnd",@"occupied",@"invisible"] containsObject:state]) self.preferredPresence=state;
                if ([self.delegate respondsToSelector:@selector(client:receivedOwnInfo:)]) [self.delegate client:self receivedOwnInfo:payload];
            }
            else if ([type isEqualToString:@"sessionEnded"]) {
                [self loginFailed:[NSError errorWithDomain:JMAPIErrorDomain code:401 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер закрыл сессию. Войдите снова.")}]]; return;
            } else {
                NSDictionary *message = JMMessageFromEvent(event, self.uin);
                if (message && ![self.delegate client:self receivedMessage:message]) {
                    [self status:JML(@"Не удалось сохранить сообщение. Проверяем диск…") connected:NO];
                    [self schedulePoll:5]; return; // Do not acknowledge an event until it is saved.
                }
            }
        }
        long long last = [JMString(data[@"lastSeqNum"]) longLongValue];
        self.sequence = MAX(self.sequence, last);
        [self status:JML(@"Подключено") connected:YES];
        NSTimeInterval delay = [JMString(data[@"timeToNextFetch"]) doubleValue] / 1000.0;
        [self schedulePoll:MAX(0.25, MIN(60, delay))];
    }];
}
- (void)sendText:(NSString *)text to:(NSString *)peer completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!self.connected || ![self.sessionID length]) {
        completion(nil, [NSError errorWithDomain:JMAPIErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey:JML(@"Подождите восстановления соединения.")}]); return;
    }
    [self call:@"/im/sendIM" parameters:@{@"aimsid":self.sessionID, @"t":peer, @"message":text, @"offlineIM":@"true"} timeout:30
     completion:^(NSDictionary *data, NSError *error) { completion(data, error); }];
}
- (void)addContactWithUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion {
    [self addContactWithUIN:uin group:nil completion:completion];
}
- (void)addContactWithUIN:(NSString *)uin group:(NSString *)group completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!self.connected || ![self.sessionID length] || !JMValidUIN(uin)) {
        completion(nil, [NSError errorWithDomain:JMAPIErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey:JML(@"Проверьте UIN и дождитесь подключения к сети.")}]); return;
    }
    NSMutableDictionary *parameters=[@{@"aimsid":self.sessionID,@"buddy":uin} mutableCopy];
    if (group.length) {
        if (!JMValidRosterName(group,NO)) { completion(nil,[NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Проверьте название группы (до 128 символов, без переносов строки).")}]); return; }
        parameters[@"group"]=group;
    }
    [self call:@"/buddylist/addBuddy" parameters:parameters timeout:30 completion:^(NSDictionary *data, NSError *error) {
        NSString *result = JMString(data[@"resultCode"]);
        if (!error && [result length] && ![result isEqualToString:@"alreadyExists"] && ![result isEqualToString:@"0"]) {
            error = [NSError errorWithDomain:JMAPIErrorDomain code:-4 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер не смог добавить контакт. Проверьте номер и повторите попытку.")}];
        }
        completion(data, error);
    }];
}
- (void)rosterCall:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    NSMutableDictionary *form=[parameters mutableCopy]; form[@"aimsid"]=self.sessionID;
    [self call:path parameters:form timeout:30 completion:^(NSDictionary *data,NSError *error) {
        NSString *result=JMString(data[@"resultCode"]);
        BOOL existingGroup=[path isEqualToString:@"/buddylist/addGroup"] && [result isEqualToString:@"alreadyExists"];
        if (!error && result.length && ![result isEqualToString:@"0"] && !existingGroup)
            error=[NSError errorWithDomain:JMAPIErrorDomain code:-4 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер не подтвердил изменение контакт-листа. Повторите после обновления списка.")}];
        completion(data,error);
    }];
}
- (void)invalidRosterInput:(void (^)(NSDictionary *, NSError *))completion {
    completion(nil,[NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Проверьте UIN и название: до 128 символов, без переносов строк.")}]);
}
- (void)renameContactWithUIN:(NSString *)uin name:(NSString *)name completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!JMValidUIN(uin) || !JMValidRosterName(name,YES)) { [self invalidRosterInput:completion]; return; }
    [self rosterCall:@"/buddylist/setBuddyAttribute" parameters:@{@"t":uin,@"friendly":name} completion:completion];
}
- (void)removeContactWithUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!JMValidUIN(uin)) { [self invalidRosterInput:completion]; return; }
    [self rosterCall:@"/buddylist/removeBuddy" parameters:@{@"buddy":uin,@"allGroups":@"1"} completion:completion];
}
- (void)moveContactWithUIN:(NSString *)uin fromGroup:(NSString *)source toGroup:(NSString *)destination completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!JMValidUIN(uin) || !JMValidRosterName(source,NO) || !JMValidRosterName(destination,NO) || [source isEqualToString:destination]) { [self invalidRosterInput:completion]; return; }
    [self rosterCall:@"/buddylist/moveBuddy" parameters:@{@"buddy":uin,@"group":source,@"newGroup":destination} completion:completion];
}
- (void)createGroup:(NSString *)name completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!JMValidRosterName(name,NO)) { [self invalidRosterInput:completion]; return; }
    [self rosterCall:@"/buddylist/addGroup" parameters:@{@"group":name} completion:completion];
}
- (void)renameGroup:(NSString *)name to:(NSString *)newName completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!JMValidRosterName(name,NO) || !JMValidRosterName(newName,NO)) { [self invalidRosterInput:completion]; return; }
    [self rosterCall:@"/buddylist/renameGroup" parameters:@{@"oldGroup":name,@"newGroup":newName} completion:completion];
}
- (void)removeGroup:(NSString *)name completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!JMValidRosterName(name,NO)) { [self invalidRosterInput:completion]; return; }
    [self rosterCall:@"/buddylist/removeGroup" parameters:@{@"group":name} completion:completion];
}
- (BOOL)requireSession:(void (^)(NSDictionary *, NSError *))completion {
    if (self.connected && [self.sessionID length]) return YES;
    completion(nil, [NSError errorWithDomain:JMAPIErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey:JML(@"Нет соединения. Нажмите «Подключиться» и повторите попытку.")}]); return NO;
}
- (void)fetchPresenceForUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    if (!JMValidUIN(uin)) { completion(nil, [NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Проверьте UIN.")}]); return; }
    [self call:@"/presence/get" parameters:@{@"aimsid":self.sessionID,@"t":uin,@"mdir":@"1",@"profileMsg":@"1"} timeout:20 completion:completion];
}
- (void)fetchProfileForUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    if (!JMValidUIN(uin)) { completion(nil, [NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Проверьте UIN.")}]); return; }
    [self call:@"/presence/getProfile" parameters:@{@"aimsid":self.sessionID,@"sn":uin} timeout:20 completion:completion];
}
- (void)setPresenceState:(NSString *)state completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    if (![@[@"online",@"away",@"dnd",@"occupied",@"invisible"] containsObject:state]) {
        completion(nil, [NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Неизвестный статус.")}]); return;
    }
    [self call:@"/presence/setState" parameters:@{@"aimsid":self.sessionID,@"view":state} timeout:20 completion:^(NSDictionary *data, NSError *error) {
        if (error) { completion(nil,error); return; }
        self.preferredPresence=state;
        NSMutableDictionary *accepted=[data mutableCopy] ?: [NSMutableDictionary dictionary];
        // The setter succeeded even if the independent read-back is unavailable.
        // Never turn a verification failure into a failed mutation or retry it.
        if (!accepted[@"state"]) accepted[@"state"]=state;
        [self fetchPresenceForUIN:self.uin completion:^(NSDictionary *presence, NSError *readError) {
            NSDictionary *own=nil;
            for (NSDictionary *entry in JMArray(presence[@"users"])) {
                NSDictionary *user=JMDictionary(entry);
                if ([JMString(user[@"aimId"]) isEqualToString:self.uin]) { own=user; break; }
            }
            NSString *serverState=JMString(own[@"state"]);
            BOOL readable=!readError && serverState.length>0;
            if (readable) {
                [accepted addEntriesFromDictionary:own];
                if ([@[@"online",@"away",@"dnd",@"occupied",@"invisible"] containsObject:serverState]) self.preferredPresence=serverState;
            }
            accepted[@"_presenceVerification"]=readable ? ([serverState isEqualToString:state] ? @"confirmed" : @"different") : @"unavailable";
            if ([self.delegate respondsToSelector:@selector(client:receivedOwnInfo:)]) [self.delegate client:self receivedOwnInfo:accepted];
            completion(accepted,nil);
        }];
    }];
}
- (void)setOwnProfileText:(NSString *)text completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    if (![text isKindOfClass:[NSString class]] || [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>4096) {
        completion(nil,[NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Текст «О себе» должен занимать не больше 4096 байт UTF-8.")}]); return;
    }
    [self call:@"/presence/setProfile" parameters:@{@"aimsid":self.sessionID,@"profile":text} timeout:30 completion:completion];
}
- (void)fetchOwnDirectoryProfile:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    [self call:@"/memberDir/get" parameters:@{@"aimsid":self.sessionID} timeout:20 completion:^(NSDictionary *data,NSError *error) {
        NSDictionary *profile=nil;
        for (NSDictionary *entry in JMArray(data[@"infoArray"])) {
            NSDictionary *p=JMDictionary(JMDictionary(entry)[@"profile"]);
            if ([JMString(p[@"aimId"]) isEqualToString:self.uin]) { profile=p; break; }
        }
        if (!error && !profile) error=[NSError errorWithDomain:JMAPIErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер не вернул вашу анкету. Нажмите «Обновить», чтобы повторить.")}];
        completion(profile,error);
    }];
}
- (void)setOwnNameFields:(NSDictionary *)fields completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    if (![fields isKindOfClass:[NSDictionary class]] || !fields.count) { [self invalidRosterInput:completion]; return; }
    NSMutableArray *values=[NSMutableArray array];
    for (NSString *key in [[fields allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        if (![@[@"firstName",@"lastName"] containsObject:key] || !JMValidRosterName(fields[key],YES)) {
            completion(nil,[NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Имя и фамилия: до 128 символов каждое, без переносов строки.")}]); return;
        }
        [values addObject:[NSString stringWithFormat:@"%@=%@",key,fields[key]]];
    }
    [self call:@"/memberDir/update" parameters:@{@"aimsid":self.sessionID,@"set":values} timeout:30 completion:completion];
}
- (void)setOwnStatusMessage:(NSString *)text completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    if (![text isKindOfClass:[NSString class]] || text.length>256 || [text rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location!=NSNotFound) {
        completion(nil,[NSError errorWithDomain:JMAPIErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:JML(@"Подпись статуса: до 256 символов, без переносов строки.")}]); return;
    }
    // Omit mood: editing the caption must not reset an existing x-status.
    [self call:@"/presence/setStatus" parameters:@{@"aimsid":self.sessionID,@"statusMsg":text} timeout:30 completion:completion];
}
- (void)uploadOwnAvatar:(NSData *)jpeg completion:(void (^)(NSDictionary *, NSError *))completion {
    if (![self requireSession:completion]) return;
    const unsigned char *bytes=jpeg.bytes;
    if (jpeg.length<4 || jpeg.length>65536 || bytes[0]!=0xff || bytes[1]!=0xd8) {
        completion(nil,[NSError errorWithDomain:JMAPIErrorDomain code:462 userInfo:@{NSLocalizedDescriptionKey:JML(@"Выберите фотографию заново: нужен JPEG размером до 64 КБ.")}]); return;
    }
    NSString *url=[[[self baseURL] absoluteString] stringByAppendingFormat:@"/expressions/upload?%@",JMFormEncode(@{@"aimsid":self.sessionID,@"type":@"buddyIcon",@"f":@"json"})];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    request.HTTPMethod=@"POST"; request.HTTPBody=jpeg;
    [request setValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"no-store" forHTTPHeaderField:@"Cache-Control"];
    [self performRequest:request path:@"/expressions/upload" completion:^(NSDictionary *data,NSError *error) {
        if (!error && !JMString(data[@"id"]).length) error=[NSError errorWithDomain:JMAPIErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:JML(@"Сервер не подтвердил новый аватар. Обновите профиль перед повторной попыткой.")}];
        completion(data,error);
    }];
}
- (void)setTypingStatus:(NSString *)status forUIN:(NSString *)uin {
    if (!self.connected || ![self.sessionID length] || !JMValidUIN(uin) || ![@[@"typing",@"typed",@"none"] containsObject:status]) return;
    if ([self.preferredPresence isEqualToString:@"invisible"] && ![status isEqualToString:@"none"]) return;
    self.typingPending[uin] = status;
    if ([self.typingScheduled containsObject:uin]) return;
    NSTimeInterval elapsed = [[NSProcessInfo processInfo] systemUptime] - [self.typingLastSent[uin] doubleValue];
    if (elapsed < 2.0) {
        [self.typingScheduled addObject:uin];
        [self later:2.05-elapsed block:^{
            [self.typingScheduled removeObject:uin];
            NSString *pending = self.typingPending[uin]; if (pending) [self setTypingStatus:pending forUIN:uin];
        }]; return;
    }
    NSString *pending = self.typingPending[uin]; [self.typingPending removeObjectForKey:uin];
    self.typingLastSent[uin] = @([[NSProcessInfo processInfo] systemUptime]);
    [self call:@"/im/setTyping" parameters:@{@"aimsid":self.sessionID,@"t":uin,@"typingStatus":pending} timeout:10 completion:^(NSDictionary *data, NSError *error) {}];
}
- (void)reconnect {
    if (![self.token length]) { [self loginFailed:nil]; return; }
    self.pollSerial++; self.polling = NO; [self.pollTask cancel]; self.pollTask = nil;
    NSString *previous = self.sessionID; self.sessionID = nil; self.failures = 0;
    if ([previous length]) [self call:@"/aim/endSession" parameters:@{@"aimsid":previous} timeout:8 completion:^(NSDictionary *data, NSError *error) {}];
    [self startSession];
}
- (void)disconnect {
    self.generation++;
    self.pollSerial++; self.polling = NO; self.sessionSerial++;
    NSString *sid = self.sessionID;
    [self.network invalidateAndCancel];
    self.network = nil; self.pollTask = nil; self.token = nil; self.tokenExpiration=nil; self.deliverLoginToken=NO; self.sessionID = nil; self.connected = NO;
    if ([sid length]) {
        // Best-effort logout on a separate short-lived connection. No credentials on disk.
        JMHTTPClient *goodbye=[self makeNetwork];
        [[goodbye dataTaskWithRequest:JMRequest([self baseURL], @"/aim/endSession", @{@"aimsid":sid}, 8)
                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {}] resume];
        [goodbye finishTasksAndInvalidate];
    }
}
@end
