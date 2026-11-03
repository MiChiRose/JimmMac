#import <Foundation/Foundation.h>
NSArray *JMSafeDiagnosticEntries(NSArray *entries);
NSString *JMDiagnosticReport(NSDictionary *bundle,NSString *system,NSString *connection,BOOL legacy,NSArray *entries);
