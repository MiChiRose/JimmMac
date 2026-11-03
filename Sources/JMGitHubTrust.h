#import <Foundation/Foundation.h>
#import <Security/Security.h>
NSArray *JMGitHubAnchorCertificates(void);
BOOL JMEvaluateGitHubTrust(SecTrustRef trust,NSString *host,NSArray *anchors);
