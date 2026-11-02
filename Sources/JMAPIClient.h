#import <Foundation/Foundation.h>
@class JMAPIClient;
@protocol JMAPIClientDelegate <NSObject>
- (void)client:(JMAPIClient *)client changedStatus:(NSString *)status connected:(BOOL)connected;
- (void)client:(JMAPIClient *)client receivedBuddyList:(NSDictionary *)buddyList;
- (void)client:(JMAPIClient *)client receivedPresence:(NSDictionary *)presence;
- (BOOL)client:(JMAPIClient *)client receivedMessage:(NSDictionary *)message;
- (void)client:(JMAPIClient *)client failedLogin:(NSError *)error;
@optional
- (void)client:(JMAPIClient *)client receivedOwnInfo:(NSDictionary *)info;
- (void)client:(JMAPIClient *)client receivedTyping:(NSDictionary *)typing;
- (void)client:(JMAPIClient *)client authenticatedWithToken:(NSString *)token expiresAt:(NSDate *)expiration;
@end

@interface JMAPIClient : NSObject
@property(nonatomic, weak) id<JMAPIClientDelegate> delegate;
@property(nonatomic, readonly) BOOL connected;
@property(nonatomic, copy, readonly) NSString *uin;
- (void)loginWithUIN:(NSString *)uin password:(NSString *)password;
- (void)loginWithUIN:(NSString *)uin password:(NSString *)password longTerm:(BOOL)longTerm;
- (void)resumeWithUIN:(NSString *)uin token:(NSString *)token;
- (void)sendText:(NSString *)text to:(NSString *)peer completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)addContactWithUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)addContactWithUIN:(NSString *)uin group:(NSString *)group completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)renameContactWithUIN:(NSString *)uin name:(NSString *)name completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)removeContactWithUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)moveContactWithUIN:(NSString *)uin fromGroup:(NSString *)source toGroup:(NSString *)destination completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)createGroup:(NSString *)name completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)renameGroup:(NSString *)name to:(NSString *)newName completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)removeGroup:(NSString *)name completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)fetchPresenceForUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)fetchProfileForUIN:(NSString *)uin completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)setOwnProfileText:(NSString *)text completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)fetchOwnDirectoryProfile:(void (^)(NSDictionary *, NSError *))completion;
- (void)setOwnNameFields:(NSDictionary *)fields completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)setOwnStatusMessage:(NSString *)text completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)uploadOwnAvatar:(NSData *)jpeg completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)setPresenceState:(NSString *)state completion:(void (^)(NSDictionary *, NSError *))completion;
- (void)setTypingStatus:(NSString *)status forUIN:(NSString *)uin;
- (void)reconnect;
- (void)disconnect;
@end
