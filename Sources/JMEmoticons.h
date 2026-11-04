#import <Cocoa/Cocoa.h>
NSImage *JMClassicSmileyImage(void);
NSImage *JMSmileyImage(NSString *code);
NSArray *JMSmileyCodes(void);
void JMApplyEmoticons(NSMutableAttributedString *text);
@interface JMTranscriptView : NSTextView
@end
