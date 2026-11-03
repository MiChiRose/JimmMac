#import "JMUpdateChecker.h"
#import "JMHTTPClient.h"
@interface JMUpdateChecker ()
@property(nonatomic,strong) JMHTTPClient *network;
@end
@implementation JMUpdateChecker
+ (NSComparisonResult)compareVersion:(NSString *)a to:(NSString *)b {
    NSArray *left=[a componentsSeparatedByString:@"."], *right=[b componentsSeparatedByString:@"."];
    for (NSUInteger i=0;i<MAX(left.count,right.count);i++) { NSInteger x=i<left.count ? [left[i] integerValue] : 0,y=i<right.count ? [right[i] integerValue] : 0; if (x!=y) return x<y ? NSOrderedAscending : NSOrderedDescending; } return NSOrderedSame;
}
+ (NSDictionary *)releaseFromData:(NSData *)data error:(NSError **)error {
    id json=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        id tag=json[@"tag_name"], url=json[@"html_url"];
        if ([tag isKindOfClass:[NSString class]] && [url isKindOfClass:[NSString class]]) {
            NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"^v[0-9]{1,6}(\\.[0-9]{1,6}){1,3}$" options:0 error:NULL];
            NSString *expected=[@"https://github.com/MiChiRose/JimmMac/releases/tag/" stringByAppendingString:tag];
            if ([json[@"draft"] isKindOfClass:[NSNumber class]] && [json[@"prerelease"] isKindOfClass:[NSNumber class]] && [pattern numberOfMatchesInString:tag options:0 range:NSMakeRange(0,[tag length])]==1 && [url isEqual:expected] && ![json[@"draft"] boolValue] && ![json[@"prerelease"] boolValue]) return @{@"version":[tag substringFromIndex:1],@"url":[NSURL URLWithString:expected],@"notes":[json[@"body"] isKindOfClass:[NSString class]] ? json[@"body"] : @""};
        }
    }
    if (error) *error=[NSError errorWithDomain:@"online.jimm.updates" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GitHub вернул неподходящее описание релиза. Повторите проверку позже."}]; return nil;
}
- (id)init { return [self initWithProtocolClasses:nil legacy:NO]; }
- (id)initWithProtocolClasses:(NSArray *)classes legacy:(BOOL)legacy {
    self=[super init]; if (self) { self.network=[[JMHTTPClient alloc] initWithProtocolClasses:classes legacy:legacy]; self.network.githubUpdateTrust=YES; self.network.maximumResponseBytes=512*1024; self.network.resourceTimeout=25; self.network.responseValidator=^BOOL(NSURLResponse *response) { return [response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode]==200; }; } return self;
}
- (void)check:(void (^)(NSDictionary *,NSError *))completion {
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.github.com/repos/MiChiRose/JimmMac/releases/latest"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"]; [request setValue:@"JimmMac-Update-Check" forHTTPHeaderField:@"User-Agent"];
    [[self.network dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        NSDictionary *release=nil;
        if (!error) release=[[self class] releaseFromData:data error:&error];
        completion(release,error);
    }] resume];
}
- (void)dealloc { [self.network invalidateAndCancel]; }
@end
