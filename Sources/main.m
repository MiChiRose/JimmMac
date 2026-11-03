#import <Cocoa/Cocoa.h>
#import "JMAppDelegate.h"
#import "JMProtocol.h"
#import "JMKeyboard.h"
#import "JMHTTPClient.h"
#import "JMUpdateChecker.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc>1 && strcmp(argv[1],"--probe-updates")==0) {
            __block BOOL done=NO; __block int result=1;
            JMUpdateChecker *checker=[[JMUpdateChecker alloc] initWithProtocolClasses:nil legacy:argc>2 && strcmp(argv[2],"--legacy")==0];
            [checker check:^(NSDictionary *release,NSError *error) { if (release && !error) { printf("GitHub update check OK: stable version %s\n",[release[@"version"] UTF8String]); result=0; } else fprintf(stderr,"Update check failed: %s\n",[error.localizedDescription UTF8String]); done=YES; }];
            NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:30]; while (!done && deadline.timeIntervalSinceNow>0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            return result;
        }
        BOOL profileProbe=argc>1 && strcmp(argv[1],"--probe-profile")==0;
        if (argc > 1 && (strcmp(argv[1], "--probe-network") == 0 || profileProbe)) {
            // Check the actual routes/methods without a real token or session.
            __block int result = 0;
            JMHTTPClient *session=[[JMHTTPClient alloc] initWithProtocolClasses:nil legacy:argc>2 && strcmp(argv[2],"--legacy")==0];
            NSArray *profileRoutes=@[@"/presence/setProfile",@"/presence/setStatus",@"/memberDir/get",@"/memberDir/update",@"/expressions/upload"];
            NSArray *routes=profileProbe ? profileRoutes : [@[@"/auth/getInfo", @"/aim/fetchEvents", @"/aim/endSession", @"/buddylist/addBuddy", @"/presence/get", @"/presence/getProfile", @"/presence/setState", @"/im/setTyping", @"/buddylist/setBuddyAttribute", @"/buddylist/removeBuddy", @"/buddylist/moveBuddy", @"/buddylist/addGroup", @"/buddylist/renameGroup", @"/buddylist/removeGroup"] arrayByAddingObjectsFromArray:profileRoutes];
            for (NSString *path in routes) {
                __block BOOL done = NO;
                NSMutableURLRequest *request = JMRequest([NSURL URLWithString:@"https://jimm.online/webapi"], path,
                    @{@"aimsid":@"diagnostic-invalid-session", @"seqNum":@0, @"timeout":@1, @"buddy":@"11114", @"t":@"11114", @"sn":@"11114", @"view":@"online", @"typingStatus":@"none", @"group":@"Diagnostic", @"newGroup":@"Diagnostic New", @"oldGroup":@"Diagnostic", @"friendly":@"Diagnostic",@"profile":@"",@"statusMsg":@"",@"set":@[@"firstName=Diagnostic",@"lastName=Probe"]}, 20);
                if ([path isEqualToString:@"/expressions/upload"]) {
                    request.URL=[NSURL URLWithString:@"https://jimm.online/webapi/expressions/upload?aimsid=diagnostic-invalid-session&type=buddyIcon&f=json"];
                    request.HTTPMethod=@"POST";
                    // A generated solid square, never a user's selected photograph.
                    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:8 pixelsHigh:8 bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:24 bitsPerPixel:24];
                    memset(rep.bitmapData,160,192); request.HTTPBody=[rep representationUsingType:NSJPEGFileType properties:@{}];
                    [request setValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
                }
                [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    NSDictionary *json = JMDictionary(data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);
                    NSInteger status = [JMString(JMDictionary(json[@"response"])[@"statusCode"]) integerValue];
                    if (!error && status == 401) {
                        printf("HTTPS %s %s: OK (expected anonymous 401, TLS validation enabled)\n", [[request HTTPMethod] UTF8String], [path UTF8String]);
                    } else {
                        fprintf(stderr, "Probe failed: %s api=%ld domain=%s code=%ld\n", [path UTF8String], (long)status, [[error domain] UTF8String] ?: "none", (long)[error code]);
                        result = 1;
                    }
                    done = YES;
                }] resume];
                NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:25];
                while (!done && [deadline timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                if (!done) { result = 1; break; }
            }
            [session invalidateAndCancel]; return result;
        }
        NSApplication *app = [JMApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        JMAppDelegate *delegate = [[JMAppDelegate alloc] init]; [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
