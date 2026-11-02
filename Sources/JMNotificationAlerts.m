#import "JMNotificationAlerts.h"
#import "JMProtocol.h"

@interface JMNotificationAlerts ()
@property(nonatomic, strong) NSUserDefaults *defaults;
@property(nonatomic, strong) NSUserNotificationCenter *center;
@property(nonatomic, strong) NSMutableDictionary *pending;
@property(nonatomic, strong) NSMutableDictionary *lastPosted;
@property(nonatomic, strong) NSMutableDictionary *deliveryIDs;
@property(nonatomic) NSUInteger generation;
@end
@implementation JMNotificationAlerts
- (id)init { return [self initWithDefaults:nil center:[NSUserNotificationCenter defaultUserNotificationCenter]]; }
- (id)initWithDefaults:(NSUserDefaults *)defaults center:(NSUserNotificationCenter *)center {
    self=[super init]; if (!self) return nil;
    self.defaults=defaults ?: [NSUserDefaults standardUserDefaults]; self.center=center;
    [self.defaults registerDefaults:@{@"NotificationsEnabled":@YES,@"NotificationContentStyle":@"sender",@"DockAttentionEnabled":@YES}];
    _enabled=[self.defaults boolForKey:@"NotificationsEnabled"]; _dockAttentionEnabled=[self.defaults boolForKey:@"DockAttentionEnabled"];
    NSString *style=JMString([self.defaults objectForKey:@"NotificationContentStyle"]);
    _contentStyle=[@[@"sender",@"preview",@"private"] containsObject:style] ? style : @"sender";
    self.pending=[NSMutableDictionary dictionary]; self.lastPosted=[NSMutableDictionary dictionary]; self.deliveryIDs=[NSMutableDictionary dictionary]; self.center.delegate=self;
    return self;
}
- (void)setEnabled:(BOOL)enabled { _enabled=enabled; [self.defaults setBool:enabled forKey:@"NotificationsEnabled"]; if (!enabled) [self clear]; }
- (void)setDockAttentionEnabled:(BOOL)enabled { _dockAttentionEnabled=enabled; [self.defaults setBool:enabled forKey:@"DockAttentionEnabled"]; }
- (void)setContentStyle:(NSString *)style {
    if (![@[@"sender",@"preview",@"private"] containsObject:style]) style=@"sender";
    if (![_contentStyle isEqualToString:style]) [self clear];
    _contentStyle=[style copy]; [self.defaults setObject:style forKey:@"NotificationContentStyle"];
}
- (void)setAccountUIN:(NSString *)uin {
    if (!JMValidUIN(uin)) uin=nil;
    if ([_accountUIN isEqualToString:uin] || (!_accountUIN && !uin)) return;
    [self clear]; _accountUIN=[uin copy];
}
- (BOOL)supportsNotificationIdentifiers { return [[[NSUserNotification alloc] init] respondsToSelector:@selector(setIdentifier:)]; }
- (NSArray *)deliveredNotifications { return self.center.deliveredNotifications ?: @[]; }
- (void)removeNotification:(NSUserNotification *)notification { [self.center removeDeliveredNotification:notification]; }
- (void)clearDeliveredNotifications { [self.center removeAllDeliveredNotifications]; }
- (BOOL)postNotification:(NSUserNotification *)notification {
    if (!self.center) return NO;
    [self.center deliverNotification:notification]; return YES;
}
- (void)clear {
    self.generation++; [self.pending removeAllObjects]; [self.lastPosted removeAllObjects]; [self.deliveryIDs removeAllObjects]; [self clearDeliveredNotifications];
    for (NSUserNotification *notification in self.center.scheduledNotifications) [self.center removeScheduledNotification:notification];
}
- (void)clearPeer:(NSString *)peer {
    if (!JMValidUIN(peer)) return;
    [self.pending removeObjectForKey:peer]; [self.lastPosted removeObjectForKey:peer]; [self.deliveryIDs removeObjectForKey:peer];
    for (NSUserNotification *notification in [[self deliveredNotifications] copy])
        if ([JMString(notification.userInfo[@"account"]) isEqualToString:self.accountUIN] && [JMString(notification.userInfo[@"peer"]) isEqualToString:peer]) [self removeNotification:notification];
}
- (void)queueMessageFrom:(NSString *)peer name:(NSString *)name text:(NSString *)text {
    if (!self.enabled || !JMValidUIN(self.accountUIN) || !JMValidUIN(peer)) return;
    NSMutableDictionary *entry=self.pending[peer];
    if (entry) { entry[@"count"]=@([entry[@"count"] unsignedIntegerValue]+1); entry[@"name"]=name ?: peer; entry[@"text"]=text ?: @""; return; }
    entry=[@{@"count":@1,@"name":name.length ? name : peer,@"text":text ?: @""} mutableCopy]; self.pending[peer]=entry;
    NSUInteger generation=self.generation;
    NSTimeInterval now=[[NSProcessInfo processInfo] systemUptime];
    NSTimeInterval delay=MAX(0.65,3.0-(now-[self.lastPosted[peer] doubleValue]));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if (generation==self.generation && self.pending[peer]==entry) [self flushPeer:peer];
    });
}
- (void)flushPeer:(NSString *)peer {
    NSDictionary *entry=self.pending[peer]; if (!entry) return;
    [self.pending removeObjectForKey:peer];
    if (!self.enabled || !JMValidUIN(self.accountUIN) || ![self.delegate notificationAlerts:self shouldNotifyPeer:peer]) return;
    NSUserNotification *notification=[[NSUserNotification alloc] init];
    NSUInteger count=[entry[@"count"] unsignedIntegerValue]; BOOL private=[self.contentStyle isEqualToString:@"private"];
    notification.title=private ? @"JimmMac" : JMString(entry[@"name"]);
    NSString *generic=count>1 ? [NSString stringWithFormat:@"Новых сообщений: %lu",(unsigned long)count] : @"Новое сообщение";
    NSString *body=JMString(entry[@"text"]);
    if ([self.contentStyle isEqualToString:@"preview"] && body.length) {
        body=[[body componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
        if (body.length>180) body=[[body substringWithRange:[body rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,180)]] stringByAppendingString:@"…"];
        notification.informativeText=body; notification.subtitle=count>1 ? generic : @"";
    } else notification.informativeText=generic;
    if ([self supportsNotificationIdentifiers]) notification.identifier=[NSString stringWithFormat:@"JimmMac.message.%@.%@",self.accountUIN,peer];
    if (!self.deliveryIDs[peer]) self.deliveryIDs[peer]=[[NSUUID UUID] UUIDString];
    notification.userInfo=@{@"kind":@"message",@"account":self.accountUIN,@"peer":peer,@"delivery":self.deliveryIDs[peer]};
    notification.hasActionButton=YES; notification.actionButtonTitle=@"Открыть"; notification.soundName=nil;
    // Mountain Lion has no identifier property: replace only this account/peer.
    for (NSUserNotification *old in [[self deliveredNotifications] copy])
        if ([JMString(old.userInfo[@"account"]) isEqualToString:self.accountUIN] && [JMString(old.userInfo[@"peer"]) isEqualToString:peer]) [self removeNotification:old];
    if ([self postNotification:notification]) self.lastPosted[peer]=@([[NSProcessInfo processInfo] systemUptime]);
}
- (BOOL)sendTestNotification {
    if (!self.enabled) return NO;
    NSUserNotification *notification=[[NSUserNotification alloc] init]; notification.title=@"JimmMac";
    notification.informativeText=@"Уведомления работают. Нажмите, чтобы открыть JimmMac.";
    if ([self supportsNotificationIdentifiers]) notification.identifier=@"JimmMac.test"; notification.userInfo=@{@"kind":@"test"}; notification.soundName=nil;
    notification.actionButtonTitle=@"Открыть"; return [self postNotification:notification];
}
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    if (!self.enabled) return NO;
    if ([JMString(notification.userInfo[@"kind"]) isEqualToString:@"test"]) return YES;
    NSString *peer=JMString(notification.userInfo[@"peer"]);
    return [JMString(notification.userInfo[@"account"]) isEqualToString:self.accountUIN] && [JMString(notification.userInfo[@"delivery"]) isEqualToString:self.deliveryIDs[peer]] && [self.delegate notificationAlerts:self shouldNotifyPeer:peer];
}
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
    // The user can read a conversation while the OS is still delivering it.
    // Also discard a late delivery after logout or a privacy/settings change.
    BOOL test=[JMString(notification.userInfo[@"kind"]) isEqualToString:@"test"];
    NSString *peer=JMString(notification.userInfo[@"peer"]);
    BOOL current=[JMString(notification.userInfo[@"account"]) isEqualToString:self.accountUIN] && [JMString(notification.userInfo[@"delivery"]) isEqualToString:self.deliveryIDs[peer]];
    BOOL wanted=test || (current && [self.delegate notificationAlerts:self shouldNotifyPeer:peer]);
    if (!self.enabled || !wanted) [self removeNotification:notification];
}
- (void)handleActivation:(NSUserNotification *)notification {
    if (![notification isKindOfClass:[NSUserNotification class]]) return;
    [self removeNotification:notification];
    NSString *kind=JMString(notification.userInfo[@"kind"]);
    if ([kind isEqualToString:@"test"]) { [self.delegate notificationAlertsShowApplication:self]; return; }
    NSString *account=JMString(notification.userInfo[@"account"]), *peer=JMString(notification.userInfo[@"peer"]);
    if ([kind isEqualToString:@"message"] && JMValidUIN(account) && JMValidUIN(peer)) [self.delegate notificationAlerts:self openPeer:peer account:account];
}
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    if (notification.activationType==NSUserNotificationActivationTypeContentsClicked || notification.activationType==NSUserNotificationActivationTypeActionButtonClicked) [self handleActivation:notification];
}
- (void)invalidate { self.generation++; [self.pending removeAllObjects]; if (self.center.delegate==self) self.center.delegate=nil; }
@end
