#import <Cocoa/Cocoa.h>
@class JMAPIClient, JMAvatarStore;
@interface JMOwnProfileController : NSWindowController <NSWindowDelegate, NSTextViewDelegate, NSTextFieldDelegate>
- (id)initWithClient:(JMAPIClient *)client avatars:(JMAvatarStore *)avatars account:(NSString *)uin;
- (void)openWithInfo:(NSDictionary *)info;
- (void)updateOwnInfo:(NSDictionary *)info;
- (void)avatarUpdated;
- (void)connectionChanged;
- (void)invalidate;
@end
