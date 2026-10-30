#import <Foundation/Foundation.h>

extern NSString * const JMAPIErrorDomain;
NSString *JMString(id value);
NSDictionary *JMDictionary(id value);
NSArray *JMArray(id value);
BOOL JMValidUIN(NSString *text);
BOOL JMValidRosterName(NSString *text, BOOL allowEmpty);
NSString *JMFormEncode(NSDictionary *parameters);
NSMutableURLRequest *JMRequest(NSURL *baseURL, NSString *path, NSDictionary *parameters, NSTimeInterval timeout);
NSDictionary *JMDecodeResponse(NSData *data, NSURLResponse *response, NSError **error);
NSString *JMPlainText(NSString *text, BOOL html);
NSArray *JMContactsFromBuddyList(NSDictionary *buddyList);
NSDictionary *JMMessageFromEvent(NSDictionary *event, NSString *ownUIN);
