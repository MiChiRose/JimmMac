#import <Foundation/Foundation.h>
@interface JMHistory : NSObject
@property(nonatomic, readonly) NSError *loadError;
- (id)initWithUIN:(NSString *)uin root:(NSURL *)root;
- (NSArray *)messagesForPeer:(NSString *)peer;
- (NSArray *)messagesForPeer:(NSString *)peer offset:(NSUInteger)offset limit:(NSUInteger)limit;
- (NSUInteger)countForPeer:(NSString *)peer;
- (NSDictionary *)lastMessageForPeer:(NSString *)peer;
- (NSDictionary *)messageWithID:(NSString *)identifier peer:(NSString *)peer;
- (NSUInteger)indexOfMessage:(NSString *)identifier peer:(NSString *)peer;
- (NSArray *)peers;
- (NSDictionary *)searchSnapshot;
+ (NSArray *)searchSnapshot:(NSDictionary *)snapshot query:(NSString *)query peer:(NSString *)peer limit:(NSUInteger)limit;
- (NSArray *)searchQuery:(NSString *)query peer:(NSString *)peer limit:(NSUInteger)limit;
- (BOOL)appendMessage:(NSDictionary *)message error:(NSError **)error;
- (BOOL)appendMessage:(NSDictionary *)message unread:(BOOL)unread error:(NSError **)error;
- (NSDictionary *)unreadCounts;
- (NSString *)firstUnreadIDForPeer:(NSString *)peer;
- (BOOL)markReadPeer:(NSString *)peer error:(NSError **)error;
- (BOOL)setDelivery:(NSString *)state forID:(NSString *)identifier peer:(NSString *)peer error:(NSError **)error;
- (BOOL)confirmLocalID:(NSString *)identifier peer:(NSString *)peer message:(NSDictionary *)message error:(NSError **)error;
- (BOOL)exportPeer:(NSString *)peer name:(NSString *)name account:(NSString *)account html:(BOOL)html toURL:(NSURL *)url error:(NSError **)error;
- (BOOL)writeBackupToURL:(NSURL *)url manifest:(NSDictionary *)manifest error:(NSError **)error;
+ (NSDictionary *)backupManifestAtURL:(NSURL *)url error:(NSError **)error;
- (NSUInteger)mergeBackupAtURL:(NSURL *)url error:(NSError **)error;
@end
