#import "JMAudioAlerts.h"

@interface JMAudioAlerts ()
@property(nonatomic, strong) NSMutableDictionary *sounds;
@property(nonatomic, strong) NSMutableDictionary *lastPlayed;
@property(nonatomic, strong) NSSound *currentSound;
@property(nonatomic) NSTimeInterval lastAnySound;
@property(nonatomic, strong) NSUserDefaults *defaults;
@end
@implementation JMAudioAlerts
- (id)init { return [self initWithDefaults:nil]; }
- (id)initWithDefaults:(NSUserDefaults *)defaults {
    self=[super init]; if (!self) return nil;
    defaults=defaults ?: [NSUserDefaults standardUserDefaults]; self.defaults=defaults;
    [defaults registerDefaults:@{@"SoundsEnabled":@YES,@"PresenceSoundsEnabled":@YES,@"TypingSoundsEnabled":@NO,@"SoundInOpenConversation":@YES}];
    _enabled=[defaults boolForKey:@"SoundsEnabled"];
    _presenceEnabled=[defaults boolForKey:@"PresenceSoundsEnabled"];
    _typingEnabled=[defaults boolForKey:@"TypingSoundsEnabled"];
    _soundInOpenConversation=[defaults boolForKey:@"SoundInOpenConversation"];
    self.sounds=[NSMutableDictionary dictionary]; self.lastPlayed=[NSMutableDictionary dictionary];
    return self;
}
- (void)setEnabled:(BOOL)enabled { _enabled=enabled; [self.defaults setBool:enabled forKey:@"SoundsEnabled"]; if (!enabled) [self stop]; }
- (void)setPresenceEnabled:(BOOL)enabled { _presenceEnabled=enabled; [self.defaults setBool:enabled forKey:@"PresenceSoundsEnabled"]; }
- (void)setTypingEnabled:(BOOL)enabled { _typingEnabled=enabled; [self.defaults setBool:enabled forKey:@"TypingSoundsEnabled"]; }
- (void)setSoundInOpenConversation:(BOOL)enabled { _soundInOpenConversation=enabled; [self.defaults setBool:enabled forKey:@"SoundInOpenConversation"]; }
- (NSSound *)soundForEvent:(NSString *)event {
    if (![@[@"message",@"online",@"offline",@"typing"] containsObject:event]) return nil;
    NSSound *sound=self.sounds[event]; if (sound) return sound;
    NSString *path=[[NSBundle mainBundle] pathForResource:event ofType:@"mp3" inDirectory:@"Sounds"];
    if (!path) path=[[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"../Resources/Sounds/%@.mp3",event]];
    sound=[[NSSound alloc] initWithContentsOfFile:path byReference:NO];
    if (sound) self.sounds[event]=sound;
    return sound;
}
- (BOOL)playSound:(NSSound *)sound { return [sound play]; }
- (BOOL)previewEvent:(NSString *)event {
    NSSound *sound=[self soundForEvent:event]; if (!sound) return NO;
    [self stop]; self.currentSound=sound; return [self playSound:sound];
}
- (BOOL)playEvent:(NSString *)event {
    BOOL message=[event isEqualToString:@"message"], typing=[event isEqualToString:@"typing"];
    BOOL presence=[event isEqualToString:@"online"] || [event isEqualToString:@"offline"];
    if (!self.enabled || (!message && !typing && !presence) || (typing && !self.typingEnabled) || (presence && !self.presenceEnabled)) return NO;
    NSTimeInterval now=[[NSProcessInfo processInfo] systemUptime];
    NSTimeInterval interval=typing ? 10 : (message ? 0.8 : 2);
    NSString *key=presence ? @"presence" : event;
    if (self.lastPlayed[key] && now-[self.lastPlayed[key] doubleValue]<interval) return NO;
    // A message takes priority over presence sounds. Bursts never overlap.
    if (!message && self.lastAnySound && now-self.lastAnySound<1) return NO;
    NSSound *sound=[self soundForEvent:event]; if (!sound) return NO;
    [self stop]; self.currentSound=sound;
    if (![self playSound:sound]) return NO;
    self.lastPlayed[key]=@(now); self.lastAnySound=now; return YES;
}
- (void)stop { [self.currentSound stop]; self.currentSound=nil; }
@end
