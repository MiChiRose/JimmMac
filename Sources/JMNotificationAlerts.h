#import <Cocoa/Cocoa.h>
@class JMNotificationAlerts;
@protocol JMNotificationAlertsDelegate <NSObject>
- (BOOL)notificationAlerts:(JMNotificationAlerts *)alerts shouldNotifyPeer:(NSString *)peer;
- (void)notificationAlerts:(JMNotificationAlerts *)alerts openPeer:(NSString *)peer account:(NSString *)account;
- (void)notificationAlertsShowApplication:(JMNotificationAlerts *)alerts;
@end
@interface JMNotificationAlerts : NSObject <NSUserNotificationCenterDelegate>
@property(nonatomic, weak) id<JMNotificationAlertsDelegate> delegate;
@property(nonatomic, copy) NSString *accountUIN;
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL dockAttentionEnabled;
@property(nonatomic, copy) NSString *contentStyle; // sender, preview, private
- (id)initWithDefaults:(NSUserDefaults *)defaults center:(NSUserNotificationCenter *)center;
- (void)queueMessageFrom:(NSString *)peer name:(NSString *)name text:(NSString *)text;
- (void)clearPeer:(NSString *)peer;
- (void)clear;
- (BOOL)sendTestNotification;
- (void)handleActivation:(NSUserNotification *)notification;
- (void)invalidate;
@end
