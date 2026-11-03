#import "JMGitHubTrust.h"
#import <dlfcn.h>
NSArray *JMGitHubAnchorCertificates(void) {
    NSMutableArray *anchors=[NSMutableArray array];
    for (NSString *name in @[@"SectigoPublicServerAuthenticationRootE46",@"USERTrustECCCertificationAuthority"]) {
        NSString *path=[[NSBundle mainBundle] pathForResource:name ofType:@"der"];
        NSData *data=path ? [NSData dataWithContentsOfFile:path] : nil;
        SecCertificateRef certificate=data ? SecCertificateCreateWithData(NULL,(__bridge CFDataRef)data) : NULL;
        if (certificate) [anchors addObject:CFBridgingRelease(certificate)];
    }
    return anchors;
}
BOOL JMEvaluateGitHubTrust(SecTrustRef trust,NSString *host,NSArray *anchors) {
    if (!trust || ![host isEqualToString:@"api.github.com"] || !anchors.count) return NO;
    // Scoped to the public updater. Preserve TLS hostname, expiry and chain validation;
    // supplement old OS roots without modifying any Keychain or accepting an invalid leaf.
    SecPolicyRef policy=SecPolicyCreateSSL(true,(__bridge CFStringRef)host);
    OSStatus status=SecTrustSetPolicies(trust,policy); CFRelease(policy);
    if (status!=errSecSuccess || SecTrustSetAnchorCertificates(trust,(__bridge CFArrayRef)anchors)!=errSecSuccess || SecTrustSetAnchorCertificatesOnly(trust,false)!=errSecSuccess) return NO;
    // The setter was introduced in 10.9; look it up rather than calling a missing
    // weak symbol on Mountain Lion. Its absence does not bypass trust evaluation.
    typedef OSStatus (*SetFetchAllowed)(SecTrustRef,Boolean);
    SetFetchAllowed setFetch=(SetFetchAllowed)dlsym(RTLD_DEFAULT,"SecTrustSetNetworkFetchAllowed");
    if (setFetch) setFetch(trust,false);
    SecTrustResultType result=kSecTrustResultInvalid;
    OSStatus evaluated=SecTrustEvaluate(trust,&result);
    return evaluated==errSecSuccess && (result==kSecTrustResultUnspecified || result==kSecTrustResultProceed);
}
