#import <Cocoa/Cocoa.h>

@interface JMAudioAlerts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL presenceEnabled;
@property(nonatomic) BOOL typingEnabled;
@property(nonatomic) BOOL soundInOpenConversation;
- (id)initWithDefaults:(NSUserDefaults *)defaults;
- (BOOL)playEvent:(NSString *)event;
- (BOOL)previewEvent:(NSString *)event;
- (NSSound *)soundForEvent:(NSString *)event;
- (void)stop;
@end
