#import "JMEmoticons.h"
static NSImage *Face(BOOL sad,BOOL wink) {
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(16,16)]; [image lockFocus];
    NSBezierPath *circle=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0.5,0.5,15,15)];
    [[NSColor colorWithCalibratedRed:1 green:0.86 blue:0.22 alpha:1] setFill]; [circle fill];
    [[NSColor colorWithCalibratedRed:0.62 green:0.44 blue:0.06 alpha:1] setStroke]; [circle setLineWidth:1]; [circle stroke];
    [[NSColor colorWithCalibratedWhite:0.2 alpha:1] set];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(4,9,2,2)] fill];
    if (wink) { NSBezierPath *eye=[NSBezierPath bezierPath]; [eye moveToPoint:NSMakePoint(10,10)]; [eye lineToPoint:NSMakePoint(12,10)]; [eye stroke]; }
    else [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(10,9,2,2)] fill];
    NSBezierPath *mouth=[NSBezierPath bezierPath]; [mouth moveToPoint:NSMakePoint(4,5)];
    [mouth curveToPoint:NSMakePoint(12,5) controlPoint1:NSMakePoint(6,sad ? 9 : 1) controlPoint2:NSMakePoint(10,sad ? 9 : 1)]; mouth.lineWidth=1.2; [mouth stroke]; [image unlockFocus]; return image;
}
void JMApplyEmoticons(NSMutableAttributedString *text) {
    static NSRegularExpression *pattern; static NSDictionary *images; static dispatch_once_t once;
    dispatch_once(&once,^{ pattern=[NSRegularExpression regularExpressionWithPattern:@"(?<![\\p{L}\\p{N}:/])[:;]-?[)(](?![\\p{L}\\p{N}])" options:0 error:NULL]; images=@{@"smile":Face(NO,NO),@"sad":Face(YES,NO),@"wink":Face(NO,YES)}; });
    NSArray *matches=[pattern matchesInString:text.string options:0 range:NSMakeRange(0,text.length)];
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        if ([text attribute:NSLinkAttributeName atIndex:match.range.location effectiveRange:NULL]) continue;
        NSString *original=[text.string substringWithRange:match.range];
        NSTextAttachment *attachment=[[NSTextAttachment alloc] init];
        attachment.attachmentCell=[[NSTextAttachmentCell alloc] initImageCell:images[[original hasPrefix:@";"] ? @"wink" : ([original hasSuffix:@"("] ? @"sad" : @"smile")]];
        NSMutableAttributedString *replacement=[[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
        NSDictionary *attributes=[text attributesAtIndex:match.range.location effectiveRange:NULL];
        [replacement addAttributes:attributes range:NSMakeRange(0,replacement.length)];
        [replacement addAttribute:@"JMSmileyText" value:original range:NSMakeRange(0,replacement.length)];
        [text replaceCharactersInRange:match.range withAttributedString:replacement];
    }
}
@implementation JMTranscriptView
- (void)copy:(id)sender {
    NSRange range=self.selectedRange; if (!range.length || NSMaxRange(range)>self.textStorage.length) return;
    NSMutableAttributedString *selection=[[self.textStorage attributedSubstringFromRange:range] mutableCopy];
    for (NSInteger i=(NSInteger)selection.length-1;i>=0;i--) { NSString *original=[selection attribute:@"JMSmileyText" atIndex:(NSUInteger)i effectiveRange:NULL]; if (original) [selection replaceCharactersInRange:NSMakeRange((NSUInteger)i,1) withString:original]; }
    [[NSPasteboard generalPasteboard] clearContents]; [[NSPasteboard generalPasteboard] setString:selection.string forType:NSPasteboardTypeString];
}
@end
