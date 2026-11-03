#import <Foundation/Foundation.h>
#import "JMProtocol.h"
#import "JMHistory.h"
#import "JMAccountData.h"
#import "JMLocalization.h"
#import "JMUpdateChecker.h"
#import "JMGitHubTrust.h"
#import "JMAPIClient.h"
#import "JMHTTPClient.h"
#import "JMTextTools.h"
#import "JMDraftStore.h"
#import "JMLoginStore.h"
#import <sys/stat.h>
#import <sqlite3.h>

static NSUInteger checks = 0;
static void Check(BOOL condition, NSString *name) {
    checks++;
    if (!condition) { fprintf(stderr, "FAIL: %s\n", [name UTF8String]); exit(1); }
}
static NSData *JSON(id object) { return [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL]; }
static void Pump(NSTimeInterval duration) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:duration];
    while ([end timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

// Exercises the real NSURLSession request/response path without an account or Internet access.
static NSMutableArray *requests;
static NSMutableArray *forms;
static NSMutableArray *bodies;
static NSString *ownProfileText=@"Мой профиль";
static NSString *ownCaption=@"Моя подпись";
static BOOL failAvatar;
static NSMutableDictionary *directoryNames;
static BOOL wrongDirectory;
static BOOL wrongSavedIdentity;
static BOOL rejectSavedToken;
static NSInteger savedTokenRejectCode=401;
static BOOL failSavedReadOnce;
static NSString *Field(NSString *query, NSString *key) {
    for (NSString *part in [query componentsSeparatedByString:@"&"]) {
        NSRange equals=[part rangeOfString:@"="];
        if (equals.location!=NSNotFound && [[part substringToIndex:equals.location] isEqualToString:key]) return [[part substringFromIndex:equals.location+1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return nil;
}
static BOOL failSend;
static NSDictionary *pollReply;
static BOOL expireNextPoll;
static BOOL rejectLogin;
static NSString *addContactResult;
static NSString *rosterResult;
static NSString *ownReadState=@"away";
static BOOL failOwnRead;
@class FixtureProtocol;
static FixtureProtocol *heldPoll;
static NSUInteger CountRequests(NSString *suffix) { NSUInteger count=0; for (NSURLRequest *r in requests) if ([r.URL.path hasSuffix:suffix]) count++; return count; }
static NSInteger updateFixtureStatus=200;
static NSURLRequest *updateFixtureRequest;
@interface UpdateFixture : NSURLProtocol
@end
@implementation UpdateFixture
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqual:@"api.github.com"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    updateFixtureRequest=self.request;
    NSData *data=JSON(@{@"tag_name":@"v0.14.0",@"html_url":@"https://github.com/MiChiRose/JimmMac/releases/tag/v0.14.0",@"draft":@NO,@"prerelease":@NO,@"body":@"Fixture notes"});
    NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:updateFixtureStatus HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed]; [self.client URLProtocol:self didLoadData:data]; [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@interface FixtureProtocol : NSURLProtocol
- (void)respondWithData:(NSDictionary *)data status:(NSInteger)status;
@end
@implementation FixtureProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [[[request URL] host] isEqualToString:@"fixture.invalid"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSString *path = [[self.request URL] path];
    [requests addObject:self.request];
    NSData *body = [self.request HTTPBody];
    if (!body && [self.request HTTPBodyStream]) {
        NSInputStream *stream = [self.request HTTPBodyStream]; [stream open];
        NSMutableData *bytes = [NSMutableData data]; uint8_t buffer[1024]; NSInteger count;
        while ((count = [stream read:buffer maxLength:sizeof(buffer)]) > 0) [bytes appendBytes:buffer length:(NSUInteger)count];
        [stream close]; body = bytes;
    }
    [forms addObject:[[self.request HTTPMethod] isEqualToString:@"GET"] ? ([self.request.URL query] ?: @"") : (body ? ([[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] ?: @"") : @"")];
    [bodies addObject:body ?: [NSData data]];
    NSDictionary *data = @{}; NSInteger status = 200;
    if ([path hasSuffix:@"/fetchEvents"]) {
        if (![[self.request HTTPMethod] isEqualToString:@"GET"]) status = 404;
        else if (expireNextPoll) { expireNextPoll = NO; status = 401; }
        else if (pollReply) { data = pollReply; pollReply = nil; }
        else { heldPoll=self; return; } // The fixture server can deliver later, without user refresh.
    }
    if ([path hasSuffix:@"/endSession"] && ![[self.request HTTPMethod] isEqualToString:@"GET"]) status = 404;
    if ([path hasSuffix:@"/clientLogin"]) { if (rejectLogin) status = 330; else data = @{@"loginId":@"111",@"token":@{@"a":@"fixture-token",@"expiresIn":[Field(forms.lastObject,@"tokenType") isEqualToString:@"longterm"] ? @31536000 : @86400}}; }
    if ([path hasSuffix:@"/auth/getInfo"]) {
        if (![self.request.HTTPMethod isEqualToString:@"GET"]) status=404;
        else if (rejectSavedToken) status=savedTokenRejectCode;
        else if (failSavedReadOnce) { failSavedReadOnce=NO; status=503; }
        else data=@{@"userData":@{@"loginId":wrongSavedIdentity ? @"222" : @"111"}};
    }
    if ([path hasSuffix:@"/startSession"]) data = @{@"aimsid":@"fixture-session", @"events":@{@"buddylist":@{@"groups":@[@{@"name":@"Friends", @"buddies":@[@{@"aimId":@"222", @"friendly":@"Test"}]}]}}};
    if ([path hasSuffix:@"/sendIM"]) { if (failSend) status = 602; else data = @{@"msgId":@"sent-1", @"timestamp":@100}; }
    if ([path hasSuffix:@"/addBuddy"]) {
        if (![[self.request HTTPMethod] isEqualToString:@"GET"]) status = 404;
        else if (addContactResult) data = @{@"resultCode":addContactResult};
    }
    if ([path hasPrefix:@"/webapi/buddylist/"] && ![path hasSuffix:@"/addBuddy"]) {
        if (![self.request.HTTPMethod isEqualToString:@"GET"]) status=404;
        else if (rosterResult) data=@{@"resultCode":rosterResult};
    }
    if ([path hasPrefix:@"/webapi/presence/"] || [path hasSuffix:@"/setTyping"]) {
        if (![[self.request HTTPMethod] isEqualToString:@"GET"]) status=404;
        else if ([path hasSuffix:@"/get"]) {
            BOOL own=[[forms lastObject] rangeOfString:@"t=111"].location!=NSNotFound;
            if (own && failOwnRead) status=500;
            data=@{@"users":@[@{@"aimId":own ? @"111" : @"222",@"friendly":@"Profile Name",@"state":own ? ownReadState : @"online",@"statusMsg":own ? ownCaption : @""}]};
        }
        else if ([path hasSuffix:@"/getProfile"]) data=@{@"screenName":@"222",@"profile":[Field(self.request.URL.query,@"sn") isEqualToString:@"111"] ? ownProfileText : @"Fixture about me"};
        else if ([path hasSuffix:@"/setProfile"]) ownProfileText=Field(self.request.URL.query,@"profile");
        else if ([path hasSuffix:@"/setStatus"]) ownCaption=Field(self.request.URL.query,@"statusMsg");
        else if ([path hasSuffix:@"/setState"]) data=@{@"aimId":@"111",@"state":@"away"};
    }
    if ([path hasSuffix:@"/expressions/upload"]) {
        if (![self.request.HTTPMethod isEqualToString:@"POST"] || ![self.request valueForHTTPHeaderField:@"Content-Type"] || !body.length) status=462;
        else if (failAvatar) status=462;
        else data=@{@"id":@"fixture-icon-id"};
    }
    if ([path hasPrefix:@"/webapi/memberDir/"]) {
        if (![self.request.HTTPMethod isEqualToString:@"GET"]) status=404;
        else if ([path hasSuffix:@"/get"]) {
            NSMutableDictionary *profile=[directoryNames mutableCopy]; profile[@"aimId"]=wrongDirectory ? @"222" : @"111";
            data=@{@"infoArray":@[@{@"profile":profile}]};
        } else if ([path hasSuffix:@"/update"]) {
            for (NSString *part in [self.request.URL.query componentsSeparatedByString:@"&"]) {
                if (![part hasPrefix:@"set="]) continue;
                NSString *value=[[part substringFromIndex:4] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                NSRange equals=[value rangeOfString:@"="];
                if (equals.location!=NSNotFound) directoryNames[[value substringToIndex:equals.location]]=[value substringFromIndex:equals.location+1];
            }
        }
    }
    [self respondWithData:data status:status];
}
- (void)respondWithData:(NSDictionary *)data status:(NSInteger)status {
    NSString *path=self.request.URL.path;
    if (heldPoll==self) heldPoll=nil;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[path hasSuffix:@"/setTyping"] && status==200 ? [NSData data] : JSON(@{@"response":@{@"statusCode":@(status), @"data":data}})];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading { if (heldPoll==self) heldPoll=nil; }
@end
@interface FixtureClient : JMAPIClient
@end
@implementation FixtureClient
- (NSURL *)baseURL { return [NSURL URLWithString:@"https://fixture.invalid/webapi"]; }
- (NSArray *)protocolClasses { return @[[FixtureProtocol class]]; }
- (BOOL)useLegacyTransport { return getenv("JIMMMAC_TEST_LEGACY_TRANSPORT")!=NULL; }

@end
@interface FixtureDelegate : NSObject <JMAPIClientDelegate>
@property BOOL online;
@property NSUInteger buddyCount;
@property NSUInteger loginErrors;
@property NSUInteger messageCount;
@property NSUInteger presenceCount;
@property BOOL refuseMessages;
@property(nonatomic, strong) NSDictionary *ownInfo;
@property NSUInteger typingCount;
@property(nonatomic, copy) NSString *lastStatus;
@property(nonatomic,strong) NSError *lastLoginError;
@property NSUInteger authenticatedTokens;
@property BOOL longTermExpiration;
@end
@implementation FixtureDelegate
- (void)client:(JMAPIClient *)client changedStatus:(NSString *)status connected:(BOOL)connected { self.online = connected; self.lastStatus=status; }
- (void)client:(JMAPIClient *)client receivedBuddyList:(NSDictionary *)list { self.buddyCount = [JMContactsFromBuddyList(list) count]; }
- (void)client:(JMAPIClient *)client receivedPresence:(NSDictionary *)presence { self.presenceCount++; }
- (BOOL)client:(JMAPIClient *)client receivedMessage:(NSDictionary *)message { self.messageCount++; return !self.refuseMessages; }
- (void)client:(JMAPIClient *)client failedLogin:(NSError *)error { self.loginErrors++; self.lastLoginError=error; }
- (void)client:(JMAPIClient *)client receivedOwnInfo:(NSDictionary *)info { self.ownInfo=info; }
- (void)client:(JMAPIClient *)client receivedTyping:(NSDictionary *)typing { self.typingCount++; }
- (void)client:(JMAPIClient *)client authenticatedWithToken:(NSString *)token expiresAt:(NSDate *)expiration { self.authenticatedTokens++; self.longTermExpiration=expiration.timeIntervalSinceNow>300*86400; }
@end
@interface JMAPIClient (TransportTest)
- (JMHTTPTask *)call:(NSString *)path parameters:(NSDictionary *)parameters timeout:(NSTimeInterval)timeout completion:(void (^)(NSDictionary *, NSError *))completion;
@end

int main(void) {
    @autoreleasepool {
        NSString *linked=@"Сайт https://jimm.online/developers, почта test@example.com.";
        NSArray *links=JMLinksInText(linked);
        Check(links.count==2 && [[(NSTextCheckingResult *)links[0] URL].host isEqualToString:@"jimm.online"] && [[(NSTextCheckingResult *)links[1] URL].scheme isEqualToString:@"mailto"],@"native link detector supports web addresses and email");
        Check([[linked substringWithRange:[links[0] range]] isEqualToString:@"https://jimm.online/developers"],@"link range excludes adjacent punctuation");
        Check(!JMExternalURL(@"javascript:alert(1)") && !JMExternalURL(@"file:///tmp/test") && !JMExternalURL(@"custom:launch") && JMExternalURL(@"https://example.com/path?q=1&x=2"),@"external link actions accept web and mail schemes only");
        Check([JMHistorySnippet([@"До совпадения. " stringByPaddingToLength:240 withString:@"Тестовый текст. " startingAtIndex:0],@"Тестовый") length]<180,@"history snippet bounds long result previews");
        NSDictionary *snapshot=@{@"222":@[@{@"id":@"old",@"text":@"Привет, Mac!",@"timestamp":@1},@{@"id":@"new",@"text":@"ПРИВЕТ ещё раз",@"timestamp":@3}],@"333":@[@{@"id":@"other",@"text":@"Привет из другой переписки",@"timestamp":@2}]};
        NSArray *hits=[JMHistory searchSnapshot:snapshot query:@"привет" peer:nil limit:200];
        Check(hits.count==3 && [hits[0][@"id"] isEqualToString:@"new"] && [hits[1][@"peer"] isEqualToString:@"333"],@"history search is case-insensitive and newest-first across conversations");
        Check([JMHistory searchSnapshot:snapshot query:@"привет" peer:@"222" limit:200].count==2,@"history search supports current-conversation scope");
        Check([JMHistory searchSnapshot:snapshot query:@"  " peer:nil limit:200].count==0 && [JMHistory searchSnapshot:snapshot query:@"absent" peer:nil limit:200].count==0 && [JMHistory searchSnapshot:snapshot query:@"привет" peer:nil limit:1].count==1,@"blank queries, absent matches and result limits are handled");
        Check([JMHistory searchSnapshot:snapshot query:@"Mac!" peer:nil limit:200].count==1,@"history query treats punctuation as literal text");
        Check(JMValidUIN(@"123456"), @"numeric UIN");
        Check(JMValidRosterName(@"Друзья & коллеги",NO) && JMValidRosterName(@"",YES) && !JMValidRosterName(@"",NO) && !JMValidRosterName(@"Bad\nName",NO) && !JMValidRosterName([@"x" stringByPaddingToLength:129 withString:@"x" startingAtIndex:0],NO),@"roster names support Unicode and bound single-line input");
        NSArray *multi=JMContactsFromBuddyList(@{@"groups":@[@{@"name":@"Friends",@"buddies":@[@{@"aimId":@"222"}]},@{@"name":@"Work",@"buddies":@[@{@"aimId":@"222"}]}]});
        Check(multi.count==1 && [multi[0][@"groups"] count]==2,@"contact deduplication preserves membership in multiple groups");
        Check(!JMValidUIN(@"../123") && !JMValidUIN(@"") && !JMValidUIN(@"١٢٣"), @"reject invalid UIN / path traversal");
        NSString *encoded = JMFormEncode(@{@"s":@"123", @"pwd":@"a+b&c= д"});
        Check([encoded isEqualToString:@"pwd=a%2Bb%26c%3D%20%D0%B4&s=123"], @"UTF-8 form encoding and special characters");
        NSURLRequest *request = JMRequest([NSURL URLWithString:@"https://example.test/webapi"], @"/auth/clientLogin", @{@"pwd":@"private"}, 75);
        Check([[request HTTPMethod] isEqualToString:@"POST"] && [[[[request URL] absoluteString] componentsSeparatedByString:@"private"] count] == 1, @"secrets in body, not URL");
        NSURLRequest *poll = JMRequest([NSURL URLWithString:@"https://example.test/webapi"], @"/aim/fetchEvents", @{@"aimsid":@"fixture+session", @"seqNum":@9}, 75);
        Check([[poll HTTPMethod] isEqualToString:@"GET"], @"fetchEvents must use GET: live server returns 404 for POST");
        Check([[[poll URL] query] rangeOfString:@"aimsid=fixture%2Bsession"].location != NSNotFound && ![poll HTTPBody], @"poll parameters correctly encoded in query");
        Check([[JMRequest([NSURL URLWithString:@"https://example.test/webapi"], @"/aim/endSession", @{@"aimsid":@"fixture"}, 8) HTTPMethod] isEqualToString:@"GET"], @"endSession must use GET");
        Check([[JMRequest([NSURL URLWithString:@"https://example.test/webapi"], @"/buddylist/addBuddy", @{@"aimsid":@"fixture",@"buddy":@"222"}, 30) HTTPMethod] isEqualToString:@"GET"], @"addBuddy must use GET like the live server");
        for (NSString *path in @[@"/presence/get",@"/presence/getProfile",@"/presence/setState",@"/im/setTyping"])
            Check([[JMRequest([NSURL URLWithString:@"https://example.test/webapi"],path,@{},20) HTTPMethod] isEqualToString:@"GET"], @"new presence and typing routes use live GET contract");
        NSHTTPURLResponse *http = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Retry-After":@"12"}];
        NSError *error = nil;
        Check(JMDecodeResponse(JSON(@{@"response":@{@"statusCode":@200, @"data":@{@"ok":@YES}}}), http, &error) != nil, @"success envelope");
        error = nil;
        Check(JMDecodeResponse(JSON(@{@"response":@{@"statusCode":@602}}), http, &error) == nil && error.code == 602, @"HTTP 200 is not delivery success");
        error = nil;
        JMDecodeResponse(JSON(@{@"response":@{@"statusCode":@430}}), http, &error);
        Check([error.userInfo[@"retryAfter"] integerValue] == 12, @"respect Retry-After");
        error = nil;
        Check(JMDecodeResponse([@"<html>error</html>" dataUsingEncoding:NSUTF8StringEncoding], http, &error) == nil && error != nil, @"invalid response fails safely");
        Check([JMPlainText(@"<HTML><BODY>Hi<br>Tom &amp; &lt;Joe&gt;</BODY></HTML>", YES) isEqualToString:@"Hi\nTom & <Joe>"], @"HTML message displayed as plain text");
        Check([JMPlainText(@"a < b & c > d", NO) isEqualToString:@"a < b & c > d"], @"plain mathematical text preserved");
        NSDictionary *list = @{@"groups":@[@{@"name":@"Friends", @"buddies":@[@{@"aimId":@123, @"friendly":@"Friend"}, @{@"aimId":@"123"}, [NSNull null]]}]};
        Check([JMContactsFromBuddyList(list) count] == 1, @"contact list normalizes and deduplicates UINs");
        NSDictionary *offline = @{@"type":@"offlineIM", @"seqNum":@7, @"eventData":@{@"aimId":@"222", @"message":@"Offline", @"msgId":@"m1", @"timestamp":@100}};
        NSDictionary *incoming = JMMessageFromEvent(offline, @"111");
        Check([incoming[@"peer"] isEqualToString:@"222"] && ![incoming[@"outgoing"] boolValue], @"offlineIM sender shape");
        NSDictionary *sent = JMMessageFromEvent(@{@"type":@"sentIM", @"eventData":@{@"dest":@{@"aimId":@"222"}, @"iSent":@YES, @"message":@"Hello", @"msgId":@"m2", @"timestamp":@101}}, @"111");
        Check([sent[@"peer"] isEqualToString:@"222"] && [sent[@"outgoing"] boolValue], @"sentIM recipient shape and own-session echo");
        Check(!JMMessageFromEvent(@{@"type":@"presence"}, @"111"), @"non-message events ignored");
        NSString *quote=JMQuotedMessage(@{@"text":@"Первая\r\n\r\nПоследняя\rстрока"},@"Тест\nимени");
        Check([quote isEqualToString:@"Тест имени:\n> Первая\n> \n> Последняя\n> строка\n\n"],@"plain text quote normalizes line endings and preserves blank lines without markup");
        Check([JMQuotedMessage(@{@"text":@"https://jimm.online/?a=1&b=2",@"timestamp":@100},@"Имя") rangeOfString:@"> https://jimm.online/?a=1&b=2"].location!=NSNotFound,@"quote preserves link text and special characters");
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]] isDirectory:YES];
        JMDraftStore *drafts=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
        Check(!drafts.loadError && drafts.drafts.count==0,@"first launch starts with empty draft store");
        Check([drafts saveDrafts:@{@"222":@"Черновик + &\nстрока",@"333":@"Отдельный черновик",@"444":@""} error:NULL],@"atomic draft snapshot accepts Unicode and separate peers");
        drafts=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
        Check([drafts.drafts[@"222"] isEqualToString:@"Черновик + &\nстрока"] && drafts.drafts.count==2,@"drafts survive restart and empty entries are omitted");
        Check([[[JMDraftStore alloc] initWithUIN:@"999" root:root] drafts].count==0,@"draft files are isolated by account");
        NSURL *draftFile=[root URLByAppendingPathComponent:@"JimmMac/accounts/111/drafts.json"];
        struct stat draftStat; stat(draftFile.path.fileSystemRepresentation,&draftStat);
        Check((draftStat.st_mode & 0777)==0600,@"draft file has owner-only permissions");
        Check([drafts saveDrafts:@{@"333":@"Остался"} error:NULL] && [[[JMDraftStore alloc] initWithUIN:@"111" root:root] drafts][@"222"]==nil,@"cleared or sent draft stays removed after restart");
        NSData *savedDraftBytes=[NSData dataWithContentsOfURL:draftFile];
        Check(![drafts saveDrafts:@{@"../bad":@"invalid"} error:NULL] && [[NSData dataWithContentsOfURL:draftFile] isEqual:savedDraftBytes],@"invalid draft keys do not damage previous file");
        [@"broken JSON" writeToURL:draftFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        drafts=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
        Check(drafts.loadError!=nil && ![drafts saveDrafts:@{@"222":@"Do not overwrite"} error:NULL] && [[NSString stringWithContentsOfURL:draftFile encoding:NSUTF8StringEncoding error:NULL] isEqualToString:@"broken JSON"],@"corrupted draft file is preserved unchanged");
        [@"{}" writeToURL:draftFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        drafts=[[JMDraftStore alloc] initWithUIN:@"111" root:root];
        Check([drafts saveDrafts:@{} error:NULL] && drafts.drafts.count==0,@"clearing all drafts writes a valid empty store");
        NSURL *keychainURL=[root URLByAppendingPathComponent:@"isolated-login-test.keychain"];
        SecKeychainRef testKeychain=NULL; const char *testPassword="fixture-only-keychain";
        OSStatus keychainStatus=SecKeychainCreate(keychainURL.path.fileSystemRepresentation,(UInt32)strlen(testPassword),testPassword,NO,NULL,&testKeychain);
        Check(keychainStatus==errSecSuccess && testKeychain!=NULL,@"isolated temporary keychain is created without accessing user's login keychain");
        JMLoginStore *credentials=[[JMLoginStore alloc] initWithService:@"online.jimm.tests.login" keychain:testKeychain];
        Check([credentials loginForUIN:@"111" error:NULL]==nil,@"missing saved login is nonfatal");
        Check([credentials saveToken:@"fixture-keychain-token" expiresAt:[NSDate dateWithTimeIntervalSinceNow:3600] forUIN:@"111" error:NULL],@"token is stored using real Mavericks Security API in isolated keychain");
        NSDictionary *savedLogin=[credentials loginForUIN:@"111" error:NULL];
        Check([savedLogin[@"token"] isEqualToString:@"fixture-keychain-token"] && [savedLogin[@"expiresAt"] isKindOfClass:[NSDate class]],@"keychain record round trip preserves token and expiry");
        Check([credentials loginForUIN:@"222" error:NULL]==nil,@"keychain query is scoped to a single account");
        Check([credentials saveToken:@"updated-fixture-token" expiresAt:[NSDate dateWithTimeIntervalSinceNow:3600] forUIN:@"111" error:NULL] && [[[credentials loginForUIN:@"111" error:NULL] objectForKey:@"token"] isEqualToString:@"updated-fixture-token"],@"existing keychain token updates without duplicate records");
        Check(![credentials removeLoginForUIN:@"" error:NULL] && [credentials loginForUIN:@"111" error:NULL]!=nil,@"invalid account cannot trigger a broad keychain deletion");
        Check([credentials saveToken:@"expiring-fixture" expiresAt:[NSDate dateWithTimeIntervalSinceNow:0.2] forUIN:@"333" error:NULL],@"expiry fixture stored"); Pump(0.3);
        NSError *expiredError=nil;
        Check([credentials loginForUIN:@"333" error:&expiredError]==nil && expiredError.code==-2,@"expired token is never returned for automatic login");
        Check([credentials removeLoginForUIN:@"111" error:NULL] && [credentials loginForUIN:@"111" error:NULL]==nil && [credentials removeLoginForUIN:@"111" error:NULL],@"logout deletion is scoped and idempotent");
        credentials=nil; Check(SecKeychainDelete(testKeychain)==errSecSuccess,@"only the isolated test keychain is deleted"); CFRelease(testKeychain);
        JMHistory *history = [[JMHistory alloc] initWithUIN:@"111" root:root];
        Check([history appendMessage:incoming error:&error] && [history appendMessage:incoming error:&error] && [history appendMessage:sent error:&error], @"persist incoming and sent events");
        Check([[history messagesForPeer:@"222"] count] == 2, @"echo and replay message ID deduplication");
        history = [[JMHistory alloc] initWithUIN:@"111" root:root];
        Check([[history messagesForPeer:@"222"] count] == 2, @"history survives restart");
        JMHistory *other = [[JMHistory alloc] initWithUIN:@"333" root:root];
        Check([[other peers] count] == 0, @"account isolation");
        NSURL *file = [root URLByAppendingPathComponent:@"JimmMac/accounts/111/history.sqlite"];
        struct stat st; stat([[file path] fileSystemRepresentation], &st);
        Check((st.st_mode & 0777) == 0600, @"history database permissions");
        NSURL *brokenLegacy=[root URLByAppendingPathComponent:@"JimmMac/accounts/333/history.json"];
        other=nil;
        [[NSFileManager defaultManager] removeItemAtURL:[root URLByAppendingPathComponent:@"JimmMac/accounts/333"] error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtURL:[brokenLegacy URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        [@"broken" writeToURL:brokenLegacy atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        other = [[JMHistory alloc] initWithUIN:@"333" root:root];
        Check(other.loadError != nil && ![other appendMessage:sent error:NULL] && [[NSString stringWithContentsOfURL:brokenLegacy encoding:NSUTF8StringEncoding error:NULL] isEqual:@"broken"], @"corrupt legacy history never overwritten");
        NSURL *legacy=[root URLByAppendingPathComponent:@"JimmMac/accounts/444/history.json"];
        [[NSFileManager defaultManager] createDirectoryAtURL:[legacy URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        NSMutableDictionary *legacyIncoming=[incoming mutableCopy]; legacyIncoming[@"text"]=@"Привет из старой истории";
        NSData *legacyData=[NSJSONSerialization dataWithJSONObject:@{@"222":@[legacyIncoming,sent]} options:0 error:NULL]; [legacyData writeToURL:legacy atomically:YES];
        JMHistory *migrated=[[JMHistory alloc] initWithUIN:@"444" root:root];
        Check(!migrated.loadError && [migrated countForPeer:@"222"]==2,@"legacy JSON migrates to indexed SQLite without losing messages");
        Check([[NSData dataWithContentsOfURL:legacy] isEqual:legacyData],@"migration retains original JSON byte for byte as backup");
        Check([migrated searchQuery:@"ПРИВЕТ" peer:@"222" limit:200].count>0,@"SQLite search preserves Unicode case-insensitive matching");
        NSDictionary *unreadMessage=@{@"peer":@"222",@"id":@"durable-unread",@"text":@"Непрочитанное <script>alert('x')</script> & :)\nСледующая строка",@"timestamp":@9999999999,@"outgoing":@NO};
        Check([migrated appendMessage:unreadMessage unread:YES error:NULL] && [migrated appendMessage:unreadMessage unread:YES error:NULL] && [migrated.unreadCounts[@"222"] integerValue]==1,@"unread and incoming message persist in one insert and duplicates do not increment count");
        migrated=nil; migrated=[[JMHistory alloc] initWithUIN:@"444" root:root];
        Check([migrated.unreadCounts[@"222"] integerValue]==1 && [[migrated firstUnreadIDForPeer:@"222"] isEqual:@"durable-unread"],@"unread count and first-unread location survive reopening");
        Check([migrated markReadPeer:@"222" error:NULL],@"reading selected peer commits read flags");
        migrated=nil; migrated=[[JMHistory alloc] initWithUIN:@"444" root:root]; Check(migrated.unreadCounts.count==0,@"read flags survive reopening");
        NSDictionary *pending=@{@"peer":@"222",@"id":@"local-pending",@"text":@"Outgoing fixture",@"timestamp":@9999999998,@"outgoing":@YES,@"delivery":@"pending"};
        Check([migrated appendMessage:pending error:NULL],@"outgoing attempt is durable before request starts");
        migrated=nil; migrated=[[JMHistory alloc] initWithUIN:@"444" root:root];
        Check([[[migrated messageWithID:@"local-pending" peer:@"222"] objectForKey:@"delivery"] isEqual:@"unknown"],@"interrupted pending send becomes unknown on restart, without automatic retry");
        NSMutableDictionary *echo=[pending mutableCopy]; echo[@"id"]=@"server-id"; [echo removeObjectForKey:@"delivery"];
        [migrated appendMessage:echo error:NULL]; NSUInteger beforeConfirm=[migrated countForPeer:@"222"];
        Check([migrated confirmLocalID:@"local-pending" peer:@"222" message:echo error:NULL] && [migrated countForPeer:@"222"]==beforeConfirm-1 && [[[migrated messageWithID:@"server-id" peer:@"222"] objectForKey:@"delivery"] isEqual:@"accepted"],@"confirmation reconciles already received echo without duplicate outgoing row");
        Check([migrated messagesForPeer:@"222" offset:1 limit:2].count==2 && [migrated indexOfMessage:@"durable-unread" peer:@"222"]==[migrated countForPeer:@"222"]-1,@"bounded pages and indexed jump keep full ordered history");
        NSURL *html=[root URLByAppendingPathComponent:@"export.html"], *txt=[root URLByAppendingPathComponent:@"export.txt"];
        Check([migrated exportPeer:@"222" name:@"<Friend>" account:@"444" html:YES toURL:html error:NULL] && [migrated exportPeer:@"222" name:@"<Friend>" account:@"444" html:NO toURL:txt error:NULL],@"both export formats write full conversation");
        NSString *htmlText=[NSString stringWithContentsOfURL:html encoding:NSUTF8StringEncoding error:NULL],*plainText=[NSString stringWithContentsOfURL:txt encoding:NSUTF8StringEncoding error:NULL];
        Check([htmlText rangeOfString:@"<script>"].location==NSNotFound && [htmlText rangeOfString:@"&lt;script&gt;"].location!=NSNotFound && [htmlText rangeOfString:@"&lt;Friend&gt;"].location!=NSNotFound,@"HTML escapes message and participant content rather than executing it");
        Check([plainText rangeOfString:unreadMessage[@"text"]].location!=NSNotFound && [plainText rangeOfString:@"444"].location!=NSNotFound,@"TXT preserves original text, line breaks and emoticons");
        stat(txt.path.fileSystemRepresentation,&st); Check((st.st_mode&0777)==0600,@"export has owner-only permissions");
        Check(![migrated exportPeer:@"222" name:@"Friend" account:@"444" html:NO toURL:[root URLByAppendingPathComponent:@"missing/failed.txt"] error:NULL],@"export failure does not claim success");
        JMHistory *large=[[JMHistory alloc] initWithUIN:@"555" root:root]; NSTimeInterval began=[NSDate timeIntervalSinceReferenceDate];
        for (NSUInteger i=0;i<10000;i++) { @autoreleasepool { if (![large appendMessage:@{@"peer":@"222",@"id":[NSString stringWithFormat:@"bulk-%05lu",(unsigned long)i],@"text":@"Большая история: строка для поиска",@"timestamp":@(i),@"outgoing":@NO} error:NULL]) { fprintf(stderr,"Bulk insert failed\n"); exit(1); } } }
        NSTimeInterval inserted=[NSDate timeIntervalSinceReferenceDate]-began; began=[NSDate timeIntervalSinceReferenceDate];
        Check([large countForPeer:@"222"]==10000 && [large messagesForPeer:@"222" offset:9800 limit:200].count==200 && [large searchQuery:@"ИСТОРИЯ" peer:@"222" limit:201].count==201,@"10,000-message history supports bounded pages and bounded Unicode search results");
        printf("History benchmark: 10000 inserts %.3fs, page + search %.3fs\n",inserted,[NSDate timeIntervalSinceReferenceDate]-began);
        NSString *testDirectory=[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
        NSMutableArray *certificateChain=[NSMutableArray array];
        for (NSString *file in @[@"Fixtures/github-api-leaf.der",@"Fixtures/github-api-intermediate.der"]) {
            NSData *der=[NSData dataWithContentsOfFile:[testDirectory stringByAppendingPathComponent:file]];
            SecCertificateRef cert=der ? SecCertificateCreateWithData(NULL,(__bridge CFDataRef)der) : NULL;
            Check(cert!=NULL,@"public TLS chain fixture decodes"); [certificateChain addObject:CFBridgingRelease(cert)];
        }
        NSData *anchorData=[NSData dataWithContentsOfFile:[testDirectory stringByAppendingPathComponent:@"../Resources/SectigoPublicServerAuthenticationRootE46.der"]];
        SecCertificateRef anchor=SecCertificateCreateWithData(NULL,(__bridge CFDataRef)anchorData); Check(anchor!=NULL,@"official Sectigo root decodes"); NSArray *anchors=@[CFBridgingRelease(anchor)];
        SecPolicyRef tlsPolicy=SecPolicyCreateSSL(true,CFSTR("api.github.com")); SecTrustRef trust=NULL;
        SecTrustCreateWithCertificates((__bridge CFArrayRef)certificateChain,tlsPolicy,&trust);
        SecTrustSetVerifyDate(trust,(__bridge CFDateRef)[NSDate dateWithTimeIntervalSince1970:1793707200]);
        Check(JMEvaluateGitHubTrust(trust,@"api.github.com",anchors),@"scoped additional root validates genuine GitHub chain and hostname on legacy Security");
        Check(!JMEvaluateGitHubTrust(trust,@"evil.invalid",anchors),@"additional root is never used for another host");
        SecTrustSetVerifyDate(trust,(__bridge CFDateRef)[NSDate dateWithTimeIntervalSince1970:2208988800]);
        Check(!JMEvaluateGitHubTrust(trust,@"api.github.com",anchors),@"expired leaf remains rejected even with additional root"); CFRelease(trust);
        SecTrustCreateWithCertificates((__bridge CFArrayRef)anchors,tlsPolicy,&trust);
        Check(!JMEvaluateGitHubTrust(trust,@"api.github.com",anchors),@"trusted root by itself cannot impersonate api.github.com"); CFRelease(trust); CFRelease(tlsPolicy);
        Check([JMUpdateChecker compareVersion:@"0.13.0" to:@"0.12.9"]==NSOrderedDescending && [JMUpdateChecker compareVersion:@"0.9" to:@"0.12"]==NSOrderedAscending && [JMUpdateChecker compareVersion:@"1.2" to:@"1.2.0"]==NSOrderedSame,@"update versions compare numerically, not lexicographically");
        NSDictionary *release=@{@"tag_name":@"v0.13.0",@"html_url":@"https://github.com/MiChiRose/JimmMac/releases/tag/v0.13.0",@"draft":@NO,@"prerelease":@NO,@"body":@"Fixture release"};
        Check([[JMUpdateChecker releaseFromData:[NSJSONSerialization dataWithJSONObject:release options:0 error:NULL] error:NULL][@"version"] isEqual:@"0.13.0"],@"valid stable release is parsed");
        NSMutableDictionary *bad=[release mutableCopy]; bad[@"html_url"]=@"https://evil.invalid/update";
        Check([JMUpdateChecker releaseFromData:[NSJSONSerialization dataWithJSONObject:bad options:0 error:NULL] error:NULL]==nil,@"update response cannot redirect users to unrelated download site");
        bad=[release mutableCopy]; bad[@"prerelease"]=@YES;
        Check([JMUpdateChecker releaseFromData:[NSJSONSerialization dataWithJSONObject:bad options:0 error:NULL] error:NULL]==nil && [JMUpdateChecker releaseFromData:[@"broken" dataUsingEncoding:NSUTF8StringEncoding] error:NULL]==nil,@"prerelease and malformed release data are rejected");
        bad=[release mutableCopy]; bad[@"draft"]=@{};
        Check([JMUpdateChecker releaseFromData:JSON(bad) error:NULL]==nil,@"malformed boolean fields cannot crash update parsing");
        [NSURLProtocol registerClass:[UpdateFixture class]];
        JMUpdateChecker *updateChecker=[[JMUpdateChecker alloc] initWithProtocolClasses:@[[UpdateFixture class]] legacy:getenv("JIMMMAC_TEST_LEGACY_TRANSPORT")!=NULL];
        __block NSDictionary *checkedRelease=nil; __block NSError *updateError=nil;
        [updateChecker check:^(NSDictionary *r,NSError *e) { checkedRelease=r; updateError=e; }]; Pump(0.3);
        Check([checkedRelease[@"version"] isEqual:@"0.14.0"] && !updateError,@"update checker reads public release through selected HTTP transport");
        Check([updateFixtureRequest.HTTPMethod isEqual:@"GET"] && !updateFixtureRequest.URL.query.length && ![updateFixtureRequest valueForHTTPHeaderField:@"Authorization"] && !updateFixtureRequest.HTTPBody.length && !updateFixtureRequest.HTTPShouldHandleCookies,@"update request sends no account credentials, query or cookies");
        updateFixtureStatus=503; checkedRelease=nil;
        [updateChecker check:^(NSDictionary *r,NSError *e) { checkedRelease=r; updateError=e; }]; Pump(0.3);
        Check(!checkedRelease && updateError,@"GitHub HTTP failure is not reported as up-to-date");
        [NSURLProtocol unregisterClass:[UpdateFixture class]];
        NSDictionary *rollbackPending=@{@"peer":@"222",@"id":@"rollback-local",@"text":@"Retain on disk error",@"timestamp":@9999999999,@"outgoing":@YES,@"delivery":@"pending"};
        [migrated appendMessage:rollbackPending error:NULL];
        sqlite3 *faultDB=NULL; sqlite3_open([[root URLByAppendingPathComponent:@"JimmMac/accounts/444/history.sqlite"] path].fileSystemRepresentation,&faultDB);
        sqlite3_exec(faultDB,"CREATE TRIGGER fail_confirm BEFORE INSERT ON messages WHEN NEW.id='fail-confirm' BEGIN SELECT RAISE(ABORT,'fixture write failure'); END",NULL,NULL,NULL);
        NSMutableDictionary *failedConfirmation=[rollbackPending mutableCopy]; failedConfirmation[@"id"]=@"fail-confirm";
        Check(![migrated confirmLocalID:@"rollback-local" peer:@"222" message:failedConfirmation error:NULL] && [migrated messageWithID:@"rollback-local" peer:@"222"]!=nil,@"failed confirmation transaction keeps durable original outgoing text");
        sqlite3_exec(faultDB,"DROP TRIGGER fail_confirm",NULL,NULL,NULL); sqlite3_close(faultDB);
        JMSetLanguage(@"en"); Check([JML(@"Открыть историю офлайн…") isEqual:@"Open Offline History…"] && [JMLocale().localeIdentifier isEqual:@"en_US_POSIX"],@"explicit English language translates UI and dates independently of system language"); JMSetLanguage(@"ru");
        JMAccountData *accountData=[[JMAccountData alloc] initWithUIN:@"555" root:root];
        NSDictionary *cache=@{@"uin":@"555",@"contacts":@{@"222":@{@"aimId":@"222",@"friendly":@"Имя для офлайн-просмотра",@"state":@"online",@"token":@"must-never-copy"}},@"serverIDs":@[@"222"],@"groups":@[@"Friends"],@"ownInfo":@{@"friendly":@"My fixture",@"password":@"must-never-copy"},@"profiles":@{@"222":@"Тестовая анкета"}};
        Check([accountData saveRoster:cache error:NULL] && [[[accountData cachedRoster][@"contacts"] objectForKey:@"222"][@"friendly"] isEqual:@"Имя для офлайн-просмотра"],@"contact names and profiles survive as account-scoped offline cache");
        Check([accountData cachedRoster][@"contacts"][@"222"][@"token"]==nil && [accountData cachedRoster][@"ownInfo"][@"password"]==nil,@"roster cache copies only allowlisted display fields");
        Check([JMStoredAccounts(root) containsObject:@"555"] && ![JMStoredAccounts(root) containsObject:@"not-an-account"],@"offline account discovery uses only local valid UIN directories");
        NSDictionary *manifest=@{@"format":@"JimmMacBackup",@"version":@1,@"uin":@"555",@"createdAt":@1793700000,@"drafts":@{@"222":@"Набранный ответ"},@"roster":cache,@"token":@"must-never-copy",@"preferences":@{@"FavoritePeers":@[@"222"],@"MutedPeers":@[@"333"],@"ChatFontSize":@18,@"InterfaceAppearance":@"mac2011",@"RememberedAccountUIN":@"555",@"password":@"must-never-copy"}};
        [large appendMessage:@{@"peer":@"222",@"id":@"backup-unread",@"text":@"Unread",@"timestamp":@20001,@"outgoing":@NO} unread:YES error:NULL];
        [large appendMessage:@{@"peer":@"222",@"id":@"backup-pending",@"text":@"Pending",@"timestamp":@20000,@"outgoing":@YES,@"delivery":@"pending"} error:NULL];
        NSURL *backup=[root URLByAppendingPathComponent:@"Account.jimmbackup"];
        Check([large writeBackupToURL:backup manifest:manifest error:NULL],@"live WAL database snapshots to one portable backup file");
        NSError *backupReadError=nil; NSDictionary *manifestRead=[JMHistory backupManifestAtURL:backup error:&backupReadError];
        if (!manifestRead) fprintf(stderr,"Fixture backup manifest read failed: %s\n",backupReadError.localizedDescription.UTF8String);
        Check([manifestRead[@"drafts"][@"222"] isEqual:@"Набранный ответ"] && [manifestRead[@"preferences"][@"MutedPeers"] containsObject:@"333"],@"backup includes drafts and local notification settings");
        Check(!manifestRead[@"token"] && !manifestRead[@"preferences"][@"RememberedAccountUIN"] && !manifestRead[@"preferences"][@"password"],@"backup never includes credentials or automatic-login pointers");
        NSURL *targetRoot=[root URLByAppendingPathComponent:@"target"];
        JMHistory *restored=[[JMHistory alloc] initWithUIN:@"555" root:targetRoot];
        [restored appendMessage:@{@"peer":@"222",@"id":@"backup-unread",@"text":@"Unread",@"timestamp":@20001,@"outgoing":@NO} error:NULL];
        Check([restored mergeBackupAtURL:backup error:NULL]==10001 && [restored countForPeer:@"222"]==10002 && [restored mergeBackupAtURL:backup error:NULL]==0,@"restoration merges complete large history idempotently without truncation or duplicates");
        Check(![restored.unreadCounts[@"222"] integerValue] && [[[restored messageWithID:@"backup-pending" peer:@"222"] objectForKey:@"delivery"] isEqual:@"unknown"],@"restore preserves existing read flags and never resumes interrupted sending");
        Check([other mergeBackupAtURL:backup error:NULL]==NSNotFound,@"backup cannot be imported under a different UIN");
        Check(![large writeBackupToURL:[JMAccountDirectory(@"555",root) URLByAppendingPathComponent:@"history.sqlite"] manifest:manifest error:NULL],@"backup refuses overwriting the live database");
        stat(backup.path.fileSystemRepresentation,&st); Check((st.st_mode&0777)==0600,@"backup file is readable only by its owner");
        NSURL *malformedBackup=[root URLByAppendingPathComponent:@"Malformed.jimmbackup"];
        [[NSFileManager defaultManager] copyItemAtURL:backup toURL:malformedBackup error:NULL];
        sqlite3 *badDB=NULL; sqlite3_open(malformedBackup.path.fileSystemRepresentation,&badDB); sqlite3_exec(badDB,"UPDATE messages SET payload='[]' WHERE id='bulk-09999'",NULL,NULL,NULL); sqlite3_close(badDB);
        JMHistory *rollbackHistory=[[JMHistory alloc] initWithUIN:@"555" root:[root URLByAppendingPathComponent:@"rollback-target"]];
        Check([rollbackHistory mergeBackupAtURL:malformedBackup error:NULL]==NSNotFound && [rollbackHistory countForPeer:@"222"]==0,@"malformed imported row rolls back all earlier imported messages without crashing");
        [@"not a backup" writeToURL:malformedBackup atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        Check(![JMHistory backupManifestAtURL:malformedBackup error:NULL],@"invalid file is rejected without creating or replacing account data");
        [[NSFileManager defaultManager] removeItemAtURL:root error:NULL];
        requests = [NSMutableArray array]; forms = [NSMutableArray array]; bodies=[NSMutableArray array]; directoryNames=[@{@"firstName":@"Иван",@"lastName":@"Тест"} mutableCopy]; [NSURLProtocol registerClass:[FixtureProtocol class]];
        pollReply = @{@"events":@[offline, @{@"type":@"presence", @"seqNum":@8, @"eventData":@{@"aimId":@"222", @"state":@""}},
            @{@"type":@"sentIM", @"seqNum":@9, @"eventData":@{@"dest":@{@"aimId":@"222"}, @"message":@"Own echo", @"msgId":@"echo", @"iSent":@YES}},
            @{@"type":@"typing",@"seqNum":@10,@"eventData":@{@"aimId":@"222",@"typingStatus":@"typing"}},
            @{@"type":@"myInfo",@"seqNum":@11,@"eventData":@{@"aimId":@"111",@"friendly":@"My Name",@"state":@"online"}}], @"lastSeqNum":@11, @"timeToNextFetch":@1};
        FixtureClient *client = [[FixtureClient alloc] init]; FixtureDelegate *delegate = [[FixtureDelegate alloc] init]; client.delegate = delegate;
        [client loginWithUIN:@"111" password:@"fixture-only"]; Pump(0.8);
        Check(delegate.online && delegate.buddyCount == 1, @"transport login → startSession → contacts integration");
        Check([delegate.lastStatus isEqualToString:@"Подключено"],@"connection status does not duplicate account UIN from header");
        Check(delegate.messageCount == 2 && delegate.presenceCount == 1, @"long polling delivers offline, presence and sentIM events");
        NSString *lastForm = [forms lastObject];
        Check([lastForm rangeOfString:@"seqNum=11"].location != NSNotFound, @"next poll advances sequence after processing events");
        Check(delegate.typingCount==1 && [delegate.ownInfo[@"friendly"] isEqualToString:@"My Name"],@"typing and own profile events are delivered");
        NSUInteger pollsBefore=CountRequests(@"/fetchEvents");
        Check(heldPoll!=nil,@"long poll stays open while server has no new events");
        [heldPoll respondWithData:@{@"events":@[@{@"type":@"im",@"eventData":@{@"source":@{@"aimId":@"222"},@"message":@"Later arrival",@"msgId":@"later-1",@"timestamp":@101}}],@"lastSeqNum":@12,@"timeToNextFetch":@1} status:200]; Pump(0.65);
        [heldPoll respondWithData:@{@"events":@[@{@"type":@"im",@"eventData":@{@"source":@{@"aimId":@"222"},@"message":@"Another arrival",@"msgId":@"later-2",@"timestamp":@102}}],@"lastSeqNum":@13,@"timeToNextFetch":@1} status:200]; Pump(0.65);
        Check(delegate.messageCount==4 && CountRequests(@"/fetchEvents")==pollsBefore+2 && [[forms lastObject] rangeOfString:@"seqNum=13"].location!=NSNotFound,@"repeated server arrivals are received and acknowledged automatically without refresh");
        __block BOOL profileOK=NO;
        [client fetchPresenceForUIN:@"222" completion:^(NSDictionary *data,NSError *e) { profileOK=!e && [JMDictionary([JMArray(data[@"users"]) firstObject])[@"friendly"] isEqualToString:@"Profile Name"]; }]; Pump(0.3);
        Check(profileOK && [[forms lastObject] rangeOfString:@"t=222"].location!=NSNotFound,@"profile presence lookup resolves friendly name");
        profileOK=NO;
        [client fetchProfileForUIN:@"222" completion:^(NSDictionary *data,NSError *e) { profileOK=!e && [data[@"profile"] isEqualToString:@"Fixture about me"]; }]; Pump(0.3);
        Check(profileOK && [[forms lastObject] rangeOfString:@"sn=222"].location!=NSNotFound,@"profile about lookup uses sn");
        __block BOOL directoryOK=NO;
        [client fetchOwnDirectoryProfile:^(NSDictionary *d,NSError *e) { directoryOK=!e && [d[@"firstName"] isEqualToString:@"Иван"]; }]; Pump(0.2);
        Check(directoryOK && Field([[requests lastObject] URL].query,@"t")==nil,@"own directory lookup omits t and returns authenticated account");
        wrongDirectory=YES; __block BOOL badDirectory=NO;
        [client fetchOwnDirectoryProfile:^(NSDictionary *d,NSError *e) { badDirectory=e!=nil; }]; Pump(0.2);
        Check(badDirectory,@"directory response for another UIN cannot populate own editor"); wrongDirectory=NO;
        [client setOwnNameFields:@{@"firstName":@"Юра & + =",@"lastName":@"Проверка"} completion:^(NSDictionary *d,NSError *e) { directoryOK=!e; }]; Pump(0.2);
        NSString *nameQuery=[[requests lastObject] URL].query;
        Check(directoryOK && [directoryNames[@"firstName"] isEqualToString:@"Юра & + ="] && [directoryNames[@"lastName"] isEqualToString:@"Проверка"] && [nameQuery componentsSeparatedByString:@"set="].count==3,@"name update encodes repeated set keys and embedded equals without data loss");
        [client setOwnNameFields:@{@"lastName":@""} completion:^(NSDictionary *d,NSError *e) { directoryOK=!e; }]; Pump(0.2);
        Check(directoryOK && [directoryNames[@"lastName"] length]==0 && [directoryNames[@"firstName"] isEqualToString:@"Юра & + ="],@"empty surname clears only requested field");
        NSUInteger nameRequests=requests.count; __block BOOL badName=NO;
        [client setOwnNameFields:@{@"city":@"Forbidden"} completion:^(NSDictionary *d,NSError *e) { badName=e!=nil; }];
        Check(badName && requests.count==nameRequests,@"unsupported directory fields are rejected before network");
        badName=NO; [client setOwnNameFields:@{@"firstName":@"Bad\nName"} completion:^(NSDictionary *d,NSError *e) { badName=e!=nil; }];
        Check(badName && requests.count==nameRequests,@"invalid multiline name is rejected before network");
        __block BOOL editedProfile=NO;
        [client setOwnProfileText:@"Привет & +\nMavericks" completion:^(NSDictionary *d,NSError *e) { editedProfile=!e; }]; Pump(0.2);
        Check(editedProfile && [ownProfileText isEqualToString:@"Привет & +\nMavericks"] && [[[requests lastObject] HTTPMethod] isEqualToString:@"GET"],@"own profile edit preserves Unicode, special characters and newlines through live GET contract");
        __block BOOL rejectedProfile=NO; NSUInteger profileRequests=requests.count;
        [client setOwnProfileText:[@"я" stringByPaddingToLength:2049 withString:@"я" startingAtIndex:0] completion:^(NSDictionary *d,NSError *e) { rejectedProfile=e!=nil; }];
        Check(rejectedProfile && requests.count==profileRequests,@"4 KiB limit counts UTF-8 bytes before issuing request");
        [client setOwnProfileText:[@"я" stringByPaddingToLength:2048 withString:@"я" startingAtIndex:0] completion:^(NSDictionary *d,NSError *e) { editedProfile=!e; }]; Pump(0.2);
        Check(editedProfile && [ownProfileText lengthOfBytesUsingEncoding:NSUTF8StringEncoding]==4096,@"exact 4096-byte profile is accepted");
        [client setOwnProfileText:@"" completion:^(NSDictionary *d,NSError *e) { editedProfile=!e; }]; Pump(0.2);
        Check(editedProfile && ownProfileText.length==0 && [[forms lastObject] rangeOfString:@"profile="].location!=NSNotFound,@"empty own profile explicitly clears server field");
        [client setOwnStatusMessage:@"На связи & +" completion:^(NSDictionary *d,NSError *e) { editedProfile=!e; }]; Pump(0.2);
        Check(editedProfile && [ownCaption isEqualToString:@"На связи & +"] && Field([[requests lastObject] URL].query,@"mood")==nil,@"status caption edit does not reset x-status");
        [client setOwnStatusMessage:@"" completion:^(NSDictionary *d,NSError *e) { editedProfile=!e; }]; Pump(0.2);
        Check(editedProfile && ownCaption.length==0 && Field([[requests lastObject] URL].query,@"statusMsg")!=nil,@"empty caption is sent explicitly");
        rejectedProfile=NO; profileRequests=requests.count;
        [client setOwnStatusMessage:@"line\nbreak" completion:^(NSDictionary *d,NSError *e) { rejectedProfile=e!=nil; }];
        Check(rejectedProfile && requests.count==profileRequests,@"multiline caption is rejected before network");
        const unsigned char jpegBytes[]={0xff,0xd8,0xff,0xd9}; NSData *jpeg=[NSData dataWithBytes:jpegBytes length:sizeof(jpegBytes)];
        __block BOOL avatarOK=NO;
        [client uploadOwnAvatar:jpeg completion:^(NSDictionary *d,NSError *e) { avatarOK=!e && [d[@"id"] isEqualToString:@"fixture-icon-id"]; }]; Pump(0.2);
        NSURLRequest *upload=requests.lastObject;
        Check(avatarOK && [upload.HTTPMethod isEqualToString:@"POST"] && [bodies.lastObject isEqual:jpeg] && [[upload valueForHTTPHeaderField:@"Content-Type"] isEqualToString:@"image/jpeg"],@"avatar uses raw binary POST with image MIME type, not form encoding");
        Check([Field(upload.URL.query,@"type") isEqualToString:@"buddyIcon"] && [Field(upload.URL.query,@"aimsid") isEqualToString:@"fixture-session"],@"upload authentication and type use documented query contract");
        failAvatar=YES; __block NSInteger avatarFailure=0;
        [client uploadOwnAvatar:jpeg completion:^(NSDictionary *d,NSError *e) { avatarFailure=e.code; }]; Pump(0.2);
        Check(avatarFailure==462,@"avatar rejection inside HTTP 200 reaches UI as failure"); failAvatar=NO;
        profileRequests=requests.count; avatarFailure=0;
        [client uploadOwnAvatar:[NSMutableData dataWithLength:65537] completion:^(NSDictionary *d,NSError *e) { avatarFailure=e.code; }];
        Check(avatarFailure==462 && requests.count==profileRequests,@"oversized upload is rejected before network");
        __block BOOL stateOK=NO;
        [client setPresenceState:@"away" completion:^(NSDictionary *data,NSError *e) { stateOK=!e && [data[@"_presenceVerification"] isEqualToString:@"confirmed"]; }]; Pump(0.3);
        Check(stateOK && [delegate.ownInfo[@"state"] isEqualToString:@"away"],@"acknowledged own status updates delegate");
        Check([[forms lastObject] rangeOfString:@"t=111"].location!=NSNotFound,@"status verification reads own UIN from server");
        ownReadState=@"online"; stateOK=NO;
        [client setPresenceState:@"away" completion:^(NSDictionary *data,NSError *e) { stateOK=!e && [data[@"_presenceVerification"] isEqualToString:@"different"] && [data[@"state"] isEqualToString:@"online"]; }]; Pump(0.3);
        Check(stateOK && [delegate.ownInfo[@"state"] isEqualToString:@"online"],@"status mismatch reports server state without claiming confirmation");
        failOwnRead=YES; stateOK=NO;
        [client setPresenceState:@"away" completion:^(NSDictionary *data,NSError *e) { stateOK=!e && [data[@"_presenceVerification"] isEqualToString:@"unavailable"] && [data[@"state"] isEqualToString:@"away"]; }]; Pump(0.3);
        Check(stateOK,@"failed read-back keeps successful setter separate from verification");
        failOwnRead=NO; ownReadState=@"away";
        __block BOOL badStateRejected=NO;
        [client setPresenceState:@"made-up" completion:^(NSDictionary *data,NSError *e) { badStateRejected=e!=nil; }];
        Check(badStateRejected,@"invalid presence states do not reach server");
        __block BOOL emptyTypingOK=NO;
        [client call:@"/im/setTyping" parameters:@{@"aimsid":@"fixture",@"t":@"222",@"typingStatus":@"none"} timeout:10 completion:^(NSDictionary *data,NSError *e) { emptyTypingOK=!e && data!=nil; }]; Pump(0.3);
        Check(emptyTypingOK,@"typing HTTP 200 with empty body is documented success");
        NSUInteger typingBefore=CountRequests(@"/setTyping");
        [client setTypingStatus:@"typing" forUIN:@"222"]; Pump(0.2);
        [client setTypingStatus:@"typing" forUIN:@"222"]; [client setTypingStatus:@"none" forUIN:@"222"]; Pump(0.3);
        Check(CountRequests(@"/setTyping")==typingBefore+1,@"typing bursts are rate limited"); Pump(2.0);
        Check(CountRequests(@"/setTyping")==typingBefore+2 && [[forms lastObject] rangeOfString:@"typingStatus=none"].location!=NSNotFound,@"latest typing state is coalesced and sent after interval");
        NSUInteger startsBefore=CountRequests(@"/startSession"); NSUInteger statesBefore=CountRequests(@"/setState");
        [client reconnect]; Pump(0.6);
        Check(client.connected && CountRequests(@"/startSession")==startsBefore+1 && [delegate.lastStatus hasPrefix:@"Подключено"],@"manual reconnect survives cancelled stale long poll");
        Check(CountRequests(@"/setState")==statesBefore+1 && [delegate.ownInfo[@"state"] isEqualToString:@"away"],@"acknowledged presence is restored after reconnect");
        __block BOOL sendOK = NO;
        [client sendText:@"Тест & +" to:@"222" completion:^(NSDictionary *data, NSError *sendError) { sendOK = !sendError && [data[@"msgId"] isEqualToString:@"sent-1"]; }]; Pump(0.5);
        Check(sendOK, @"sendIM transport integration");
        __block BOOL addOK = NO;
        [client addContactWithUIN:@"444" completion:^(NSDictionary *data, NSError *addError) { addOK = data != nil && !addError; }]; Pump(0.3);
        Check(addOK && [[forms lastObject] rangeOfString:@"buddy=444"].location != NSNotFound, @"server contact addition uses buddy parameter");
        addContactResult = @"alreadyExists"; addOK = NO;
        [client addContactWithUIN:@"444" completion:^(NSDictionary *data, NSError *addError) { addOK = !addError && [data[@"resultCode"] isEqualToString:@"alreadyExists"]; }]; Pump(0.3);
        Check(addOK, @"alreadyExists contact result is nonfatal");
        addContactResult = @"notFound"; __block BOOL addFailed = NO;
        [client addContactWithUIN:@"444" completion:^(NSDictionary *data, NSError *addError) { addFailed = addError != nil; }]; Pump(0.3);
        Check(addFailed, @"contact resultCode failure is not mistaken for success"); addContactResult = nil;
        addOK=NO; [client addContactWithUIN:@"444" group:@"Работа & друзья" completion:^(NSDictionary *data,NSError *e) { addOK=!e; }]; Pump(0.25);
        Check(addOK && [[forms lastObject] rangeOfString:@"group=%D0%A0"].location!=NSNotFound && [[forms lastObject] rangeOfString:@"%26"].location!=NSNotFound,@"adding contact encodes selected Unicode group");
        __block BOOL rosterOK=NO;
        [client renameContactWithUIN:@"222" name:@"Мой + друг" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[forms lastObject] rangeOfString:@"t=222"].location!=NSNotFound && [[forms lastObject] rangeOfString:@"friendly="].location!=NSNotFound && [[forms lastObject] rangeOfString:@"%2B"].location!=NSNotFound,@"personal alias uses t and friendly with correct encoding");
        rosterOK=NO; [client renameContactWithUIN:@"222" name:@"" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[forms lastObject] rangeOfString:@"friendly=&"].location!=NSNotFound,@"empty alias is sent explicitly to restore public name");
        rosterOK=NO; [client moveContactWithUIN:@"222" fromGroup:@"Friends" toGroup:@"Work" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[forms lastObject] rangeOfString:@"group=Friends"].location!=NSNotFound && [[forms lastObject] rangeOfString:@"newGroup=Work"].location!=NSNotFound,@"move distinguishes source group and destination");
        rosterOK=NO; [client removeContactWithUIN:@"222" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[forms lastObject] rangeOfString:@"allGroups=1"].location!=NSNotFound,@"remove contact explicitly removes all group memberships");
        rosterOK=NO; [client createGroup:@"Work" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[[requests lastObject] HTTPMethod] isEqualToString:@"GET"],@"group creation uses GET and accepts empty data success");
        rosterOK=NO; [client renameGroup:@"Work" to:@"Colleagues" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[forms lastObject] rangeOfString:@"oldGroup=Work"].location!=NSNotFound && [[forms lastObject] rangeOfString:@"newGroup=Colleagues"].location!=NSNotFound,@"group rename sends old and new names");
        rosterOK=NO; [client removeGroup:@"Colleagues" completion:^(NSDictionary *d,NSError *e) { rosterOK=!e; }]; Pump(0.25);
        Check(rosterOK && [[forms lastObject] rangeOfString:@"group=Colleagues"].location!=NSNotFound,@"empty group deletion sends group name");
        rosterResult=@"notFound"; __block BOOL rosterFailed=NO;
        [client removeContactWithUIN:@"222" completion:^(NSDictionary *d,NSError *e) { rosterFailed=e!=nil; }]; Pump(0.25);
        Check(rosterFailed,@"roster resultCode errors are not successful mutations"); rosterResult=nil;
        NSUInteger requestsBefore=requests.count; rosterFailed=NO;
        [client moveContactWithUIN:@"222" fromGroup:@"Work" toGroup:@"Work" completion:^(NSDictionary *d,NSError *e) { rosterFailed=e!=nil; }];
        Check(rosterFailed && requests.count==requestsBefore,@"invalid same-group move is rejected before network");
        failSend = YES; __block NSInteger failureCode = 0;
        [client sendText:@"fail" to:@"222" completion:^(NSDictionary *data, NSError *sendError) { failureCode = sendError.code; }]; Pump(0.5);
        Check(failureCode == 602, @"send failure propagated to UI");
        [client disconnect]; Check(!client.connected, @"disconnect clears connection"); Pump(0.2);
        [client loginWithUIN:@"111" password:@"fixture-only"]; [client disconnect]; Pump(0.3);
        Check(!client.connected, @"stale login completion cannot revive disconnected session");
        delegate.refuseMessages = YES;
        pollReply = @{@"events":@[offline], @"lastSeqNum":@7, @"timeToNextFetch":@1};
        [client loginWithUIN:@"111" password:@"fixture-only"]; Pump(5.8);
        lastForm = [forms lastObject];
        Check([lastForm rangeOfString:@"seqNum=0"].location != NSNotFound && !client.connected, @"failed persistence retries same cursor without acknowledging event");
        [client disconnect]; delegate.refuseMessages = NO;
        [requests removeAllObjects]; expireNextPoll = YES;
        [client loginWithUIN:@"111" password:@"fixture-only"]; Pump(0.8);
        NSUInteger starts = 0;
        for (NSURLRequest *r in requests) if ([[[r URL] path] hasSuffix:@"/startSession"]) starts++;
        Check(starts == 2 && client.connected, @"expired session restarts using in-memory token");
        [client disconnect]; rejectLogin = YES;
        [client loginWithUIN:@"111" password:@"fixture-only"]; Pump(0.5);
        Check(delegate.loginErrors == 1 && !client.connected, @"invalid credentials return to login");
        rejectLogin=NO; NSUInteger issuedBefore=delegate.authenticatedTokens;
        [client loginWithUIN:@"111" password:@"fixture-only" longTerm:YES]; Pump(0.5);
        Check(client.connected && delegate.authenticatedTokens==issuedBefore+1 && delegate.longTermExpiration,@"long-term password login exposes expiring token only after session succeeds");
        [client disconnect]; NSUInteger passwordRequests=CountRequests(@"/clientLogin"), identityReads=CountRequests(@"/auth/getInfo"); issuedBefore=delegate.authenticatedTokens;
        [client resumeWithUIN:@"111" token:@"fixture-token"]; Pump(0.5);
        Check(client.connected && CountRequests(@"/clientLogin")==passwordRequests && CountRequests(@"/auth/getInfo")==identityReads+1 && delegate.authenticatedTokens==issuedBefore,@"saved-token login verifies account identity and connects without password exchange");
        wrongSavedIdentity=YES; NSUInteger errorsBefore=delegate.loginErrors, sessionsBefore=CountRequests(@"/startSession");
        [client resumeWithUIN:@"111" token:@"fixture-token"]; Pump(0.4);
        Check(!client.connected && delegate.loginErrors==errorsBefore+1 && CountRequests(@"/startSession")==sessionsBefore,@"token for another UIN never opens a session"); wrongSavedIdentity=NO;
        rejectSavedToken=YES; errorsBefore=delegate.loginErrors;
        [client resumeWithUIN:@"111" token:@"fixture-token"]; Pump(0.4);
        Check(!client.connected && delegate.loginErrors==errorsBefore+1,@"revoked saved token returns to password login"); rejectSavedToken=NO;
        rejectSavedToken=YES; savedTokenRejectCode=330;
        [client resumeWithUIN:@"111" token:@"fixture-token"]; Pump(0.4);
        Check(delegate.lastLoginError.code==330 && [delegate.lastLoginError.localizedDescription rangeOfString:@"сохранённый вход"].location!=NSNotFound && [delegate.lastLoginError.localizedDescription rangeOfString:@"Неверный UIN или пароль"].location==NSNotFound,@"rejected saved token explains reauthentication without falsely claiming password was wrong");
        rejectSavedToken=NO; savedTokenRejectCode=401;
        failSavedReadOnce=YES; identityReads=CountRequests(@"/auth/getInfo");
        [client resumeWithUIN:@"111" token:@"fixture-token"]; Pump(2.7);
        Check(client.connected && CountRequests(@"/auth/getInfo")==identityReads+2,@"temporary server failure retries saved-token verification without discarding it");
        [client resumeWithUIN:@"111" token:@"fixture-token"]; [client disconnect]; Pump(0.3);
        Check(!client.connected,@"cancelled saved-token verification cannot revive a disconnected session");
        [NSURLProtocol unregisterClass:[FixtureProtocol class]];
        printf("PASS: %lu checks (%s transport)\n", (unsigned long)checks,getenv("JIMMMAC_TEST_LEGACY_TRANSPORT") ? "10.8 NSURLConnection" : "NSURLSession");
    }
    return 0;
}
