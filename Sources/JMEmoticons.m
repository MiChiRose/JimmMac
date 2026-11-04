#import "JMEmoticons.h"
#import "JMTheme.h"
#import "JMStyle.h"

NSArray *JMSmileyCodes(void) {
    return @[@":)", @":(", @";)", @":D", @":P", @":'(", @"8-)", @":-*", @"=-O", @"O:-)"];
}

static NSString *JMSmileyResourceName(NSString *code) {
    static NSDictionary *names;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        names=@{@":)":@"smile", @":(":@"sad", @";)":@"wink", @":d":@"laugh",
                @":p":@"tongue", @":'(":@"cry", @"8)":@"cool", @":*":@"kiss",
                @"=o":@"shock", @"o:)":@"angel"};
    });
    NSString *key=[[code lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *name=names[key];
    return name ? [@"smiley-" stringByAppendingString:name] : nil;
}

NSImage *JMSmileyImage(NSString *code) {
    NSString *name=JMSmileyResourceName(code);
    return name ? JMRetroImage(name) : nil;
}

NSImage *JMClassicSmileyImage(void) { return JMSmileyImage(@":)"); }

@interface JMAnimatedSmiley : NSObject
@property(nonatomic,copy) NSArray *frames;
@property(nonatomic,copy) NSArray *endTimes;
@property(nonatomic) NSTimeInterval duration;
@end
@implementation JMAnimatedSmiley
@end

static JMAnimatedSmiley *JMAnimationForSmiley(NSString *code) {
    JMThemeMode theme=JMTheme();
    if (theme!=JMThemeCurrent && theme!=JMThemeJimm && theme!=JMThemeQIP) return nil;
    NSString *pack=theme==JMThemeQIP ? @"qip" : @"jimm";
    NSString *name=JMSmileyResourceName(code);
    if (!name) return nil;
    static NSMutableDictionary *cache;
    if (!cache) cache=[NSMutableDictionary dictionary];
    NSString *key=[pack stringByAppendingPathComponent:name];
    id cached=cache[key];
    if (cached) return cached==[NSNull null] ? nil : cached;

    NSURL *url=JMRetroResourceURL(name,@"gif",pack);
    NSData *data=url ? [NSData dataWithContentsOfURL:url] : nil;
    NSBitmapImageRep *bitmap=data ? [NSBitmapImageRep imageRepWithData:data] : nil;
    NSInteger count=[[bitmap valueForProperty:NSImageFrameCount] integerValue];
    NSMutableArray *frames=[NSMutableArray array], *endTimes=[NSMutableArray array];
    NSTimeInterval duration=0;
    for (NSInteger i=0;i<count;i++) {
        [bitmap setProperty:NSImageCurrentFrame withValue:@(i)];
        CGImageRef frame=bitmap.CGImage;
        if (!frame) break;
        NSSize size=NSMakeSize(CGImageGetWidth(frame),CGImageGetHeight(frame));
        [frames addObject:[[NSImage alloc] initWithCGImage:frame size:size]];
        NSTimeInterval delay=[[bitmap valueForProperty:NSImageCurrentFrameDuration] doubleValue];
        duration+=delay>0 ? delay : 0.1;
        [endTimes addObject:@(duration)];
    }
    JMAnimatedSmiley *animation=nil;
    if (frames.count>1) {
        animation=[[JMAnimatedSmiley alloc] init];
        animation.frames=frames; animation.endTimes=endTimes; animation.duration=duration;
    }
    cache[key]=animation ?: (id)[NSNull null];
    return animation;
}

@interface JMTranscriptView ()
@property(nonatomic,strong) NSTimer *smileyTimer;
@property(nonatomic) NSRect smileyDirtyRect;
- (void)requestSmileyRedrawInRect:(NSRect)rect after:(NSTimeInterval)delay;
@end

@interface JMAnimatedSmileyCell : NSTextAttachmentCell
@property(nonatomic,strong) JMAnimatedSmiley *animation;
@property(nonatomic) NSTimeInterval startedAt;
@end
@implementation JMAnimatedSmileyCell
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
    if (![view isKindOfClass:[JMTranscriptView class]]) {
        [super drawWithFrame:frame inView:view];
        return;
    }
    NSTimeInterval now=[[NSProcessInfo processInfo] systemUptime];
    if (!self.startedAt) self.startedAt=now;
    NSTimeInterval time=fmod(now-self.startedAt,self.animation.duration);
    NSUInteger index=0;
    while (index+1<self.animation.frames.count && time>=[self.animation.endTimes[index] doubleValue]) index++;
    NSImage *image=self.animation.frames[index];
    [image drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
    NSTimeInterval remaining=[self.animation.endTimes[index] doubleValue]-time;
    [(JMTranscriptView *)view requestSmileyRedrawInRect:frame after:remaining];
}
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view characterIndex:(NSUInteger)index {
    [self drawWithFrame:frame inView:view];
}
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view characterIndex:(NSUInteger)index layoutManager:(NSLayoutManager *)layoutManager {
    [self drawWithFrame:frame inView:view];
}
@end

void JMApplyEmoticons(NSMutableAttributedString *text) {
    static NSRegularExpression *pattern;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        pattern=[NSRegularExpression regularExpressionWithPattern:
                 @"(?<![\\p{L}\\p{N}:/])(?:o:-?\\)|:'-?\\(|8-?\\)|=-?o|;-?\\)|:-?[()dp*])(?![\\p{L}\\p{N}])"
                    options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    NSArray *matches=[pattern matchesInString:text.string options:0 range:NSMakeRange(0,text.length)];
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        if ([text attribute:NSLinkAttributeName atIndex:match.range.location effectiveRange:NULL]) continue;
        NSString *original=[text.string substringWithRange:match.range];
        NSImage *image=JMSmileyImage(original);
        if (!image) continue;
        NSTextAttachment *attachment=[[NSTextAttachment alloc] init];
        JMAnimatedSmiley *animation=JMAnimationForSmiley(original);
        if (animation) {
            JMAnimatedSmileyCell *cell=[[JMAnimatedSmileyCell alloc] initImageCell:animation.frames[0]];
            cell.animation=animation;
            attachment.attachmentCell=cell;
        } else attachment.attachmentCell=[[NSTextAttachmentCell alloc] initImageCell:image];
        NSMutableAttributedString *replacement=[[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
        NSDictionary *attributes=[text attributesAtIndex:match.range.location effectiveRange:NULL];
        [replacement addAttributes:attributes range:NSMakeRange(0,replacement.length)];
        [replacement addAttribute:@"JMSmileyText" value:original range:NSMakeRange(0,replacement.length)];
        [text replaceCharactersInRange:match.range withAttributedString:replacement];
    }
}
@implementation JMTranscriptView
- (void)requestSmileyRedrawInRect:(NSRect)rect after:(NSTimeInterval)delay {
    if (!self.window.isVisible || self.window.isMiniaturized || self.isHiddenOrHasHiddenAncestor ||
        !NSIntersectsRect(self.visibleRect,rect)) return;
    self.smileyDirtyRect=NSUnionRect(self.smileyDirtyRect,rect);
    NSDate *nextFrame=[NSDate dateWithTimeIntervalSinceNow:MAX(0.01,delay)];
    if (self.smileyTimer && [self.smileyTimer.fireDate compare:nextFrame]!=NSOrderedDescending) return;
    [self.smileyTimer invalidate];
    self.smileyTimer=[[NSTimer alloc] initWithFireDate:nextFrame interval:0 target:self
        selector:@selector(redrawSmileyFrames:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.smileyTimer forMode:NSRunLoopCommonModes];
}
- (void)redrawSmileyFrames:(NSTimer *)timer {
    self.smileyTimer=nil;
    NSRect dirty=self.smileyDirtyRect;
    self.smileyDirtyRect=NSZeroRect;
    if (self.window.isVisible && !self.window.isMiniaturized && !self.isHiddenOrHasHiddenAncestor) {
        [self setNeedsDisplayInRect:NSIntersectionRect(self.visibleRect,dirty)];
    }
}
- (void)drawViewBackgroundInRect:(NSRect)rect {
    [super drawViewBackgroundInRect:rect]; if (JMTheme()!=JMThemeMac2011 || !self.textStorage.length) return;
    NSLayoutManager *layout=self.layoutManager; NSPoint origin=self.textContainerOrigin;
    NSRange visibleGlyphs=[layout glyphRangeForBoundingRect:NSOffsetRect(rect,-origin.x,-origin.y) inTextContainer:self.textContainer];
    NSRange visible=[layout characterRangeForGlyphRange:visibleGlyphs actualGlyphRange:NULL];
    [self.textStorage enumerateAttribute:@"JMMessageID" inRange:visible options:0 usingBlock:^(id value,NSRange range,BOOL *stop) {
        if (!value) return;
        // Expand a partially visible message to its complete attributed range.
        NSRange entire; [self.textStorage attribute:@"JMMessageID" atIndex:range.location longestEffectiveRange:&entire inRange:NSMakeRange(0,self.textStorage.length)];
        NSRange glyphs=[layout glyphRangeForCharacterRange:entire actualCharacterRange:NULL]; NSRect bounds=[layout boundingRectForGlyphRange:glyphs inTextContainer:self.textContainer];
        bounds=NSOffsetRect(bounds,origin.x,origin.y); bounds.origin.x=8; bounds.size.width=MAX(0,NSWidth(self.bounds)-16); bounds.origin.y-=5; bounds.size.height+=9;
        NSBezierPath *card=[NSBezierPath bezierPathWithRoundedRect:NSIntegralRect(bounds) xRadius:2 yRadius:2]; [[NSColor whiteColor] setFill]; [card fill];
        [[NSColor colorWithCalibratedRed:0.75 green:0.77 blue:0.73 alpha:1] setStroke]; card.lineWidth=1; [card stroke];
    }];
}

- (void)copy:(id)sender {
    NSRange range=self.selectedRange; if (!range.length || NSMaxRange(range)>self.textStorage.length) return;
    NSMutableAttributedString *selection=[[self.textStorage attributedSubstringFromRange:range] mutableCopy];
    for (NSInteger i=(NSInteger)selection.length-1;i>=0;i--) { NSString *original=[selection attribute:@"JMSmileyText" atIndex:(NSUInteger)i effectiveRange:NULL]; if (original) [selection replaceCharactersInRange:NSMakeRange((NSUInteger)i,1) withString:original]; }
    [[NSPasteboard generalPasteboard] clearContents]; [[NSPasteboard generalPasteboard] setString:selection.string forType:NSPasteboardTypeString];
}
@end
