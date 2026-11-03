#import <Cocoa/Cocoa.h>
NSImage *JMDecodeAvatar(NSData *data);
NSData *JMPrepareAvatar(NSData *data, NSError **error);
@class JMAvatarStore;
@protocol JMAvatarStoreDelegate <NSObject>
- (void)avatarStore:(JMAvatarStore *)store updatedUIN:(NSString *)uin;
@end
@interface JMAvatarStore : NSObject
@property(nonatomic, weak) id<JMAvatarStoreDelegate> delegate;
- (NSImage *)imageForUIN:(NSString *)uin;
- (void)refreshUIN:(NSString *)uin;
- (void)storeUploadedAvatar:(NSData *)data forUIN:(NSString *)uin;
- (unsigned long long)cacheBytes;
- (BOOL)clearCache:(NSError **)error;
- (void)invalidate;
@end
