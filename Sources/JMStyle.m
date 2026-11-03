#import "JMLocalization.h"
#import "JMStyle.h"
#import "JMTheme.h"
#import <ImageIO/ImageIO.h>
static void JMDrawMacHeader(NSRect rect);
NSImage *JMStatusImage(NSString *state) {
    static NSMutableDictionary *images;
    if (!images) images=[NSMutableDictionary dictionary];
    NSDictionary *frames=@{@"online":@7,@"freeForChat":@7,@"away":@0,@"na":@0,@"dnd":@2,@"occupied":@5,@"invisible":@3,@"offline":@6};
    NSNumber *frame=frames[state ?: @""] ?: @6;
    NSImage *image=images[frame]; if (image) return image;
    NSString *path=[[NSBundle mainBundle] pathForResource:@"JimmStatusSprite" ofType:@"png"];
    if (!path) path=[[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"../Resources/JimmStatusSprite.png"];
    CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],NULL);
    if (source) {
        CGImageRef sheet=CGImageSourceCreateImageAtIndex(source,0,NULL); CFRelease(source);
        if (sheet) {
            CGImageRef icon=CGImageCreateWithImageInRect(sheet,CGRectMake([frame integerValue]*16,0,16,16)); CGImageRelease(sheet);
            if (icon) { image=[[NSImage alloc] initWithCGImage:icon size:NSMakeSize(16,16)]; CGImageRelease(icon); }
        }
    }
    if (image) images[frame]=image;
    return image ?: [NSImage imageNamed:NSImageNameStatusNone];
}
NSImage *JMFlowerImage(void) {
    static NSImage *image;
    if (!image) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ICQFlower" ofType:@"png"];
        if (!path) path = [[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"../Resources/ICQFlower.png"];
        image = [[NSImage alloc] initWithContentsOfFile:path];
    }
    return image;
}
NSColor *JMSecondaryTextColor(void) { return [NSColor colorWithCalibratedWhite:0.34 alpha:1]; }
NSColor *JMLegacyHeaderTopColor(void) { return JMThemeHeaderTop(); }
NSColor *JMLegacyHeaderBottomColor(void) { return JMThemeHeaderBottom(); }
@implementation JMChromeView
- (void)drawRect:(NSRect)dirtyRect {
    NSColor *top = self.topColor ?: [NSColor colorWithCalibratedWhite:0.97 alpha:1];
    NSColor *bottom = self.bottomColor ?: [NSColor colorWithCalibratedWhite:0.84 alpha:1];
    if (JMTheme()==JMThemeMac2011 && [top isEqual:JMThemeHeaderTop()] && [bottom isEqual:JMThemeHeaderBottom()]) { JMDrawMacHeader(self.bounds); return; }
    [[[NSGradient alloc] initWithStartingColor:bottom endingColor:top] drawInRect:self.bounds angle:90];
    [[NSColor colorWithCalibratedWhite:0.68 alpha:1] setFill]; NSRectFill(NSMakeRect(0,0,NSWidth(self.bounds),1));
}
@end
NSColor *JMSelectionColor(BOOL emphasized) {
    if (JMTheme()==JMThemeMac2011) return emphasized ? [NSColor colorWithSRGBRed:217.0/255 green:227.0/255 blue:204.0/255 alpha:1] : [NSColor whiteColor];
    if (JMTheme()==JMThemePro2003) return emphasized ? [NSColor colorWithCalibratedRed:0.05 green:0.14 blue:0.44 alpha:1] : [NSColor colorWithCalibratedWhite:0.83 alpha:1];
    return emphasized ? [NSColor colorWithCalibratedRed:0.25 green:0.42 blue:0.65 alpha:1] : [NSColor colorWithCalibratedRed:0.80 green:0.84 blue:0.88 alpha:1];
}
@implementation JMContactRowView
- (NSBackgroundStyle)interiorBackgroundStyle { return self.selected && self.emphasized && JMTheme()!=JMThemeMac2011 ? NSBackgroundStyleDark : NSBackgroundStyleLight; }
- (void)drawSelectionInRect:(NSRect)dirtyRect { [JMSelectionColor(self.emphasized) setFill]; NSRectFill(self.bounds); }
- (void)refreshCells {
    for (NSView *view in self.subviews) if ([view isKindOfClass:[NSTableCellView class]]) [(NSTableCellView *)view setBackgroundStyle:self.interiorBackgroundStyle];
    self.needsDisplay=YES;
}
- (void)setEmphasized:(BOOL)value { [super setEmphasized:value]; [self refreshCells]; }
- (void)setSelected:(BOOL)value { [super setSelected:value]; [self refreshCells]; }
@end
@implementation JMComposerView
- (NSUndoManager *)undoManager {
    // A conversation's edits must never undo into another peer's draft or a field editor.
    if (!_composerUndoManager) _composerUndoManager=[[NSUndoManager alloc] init];
    return _composerUndoManager;
}
- (void)setString:(NSString *)string { [super setString:string]; self.needsDisplay=YES; }
- (void)didChangeText { [super didChangeText]; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (self.string.length || self.hasMarkedText || !self.isEditable || !self.placeholder.length) return;
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.lineBreakMode=NSLineBreakByTruncatingTail;
    NSPoint origin=self.textContainerOrigin; origin.x+=self.textContainer.lineFragmentPadding;
    [self.placeholder drawInRect:NSMakeRect(origin.x,origin.y,MAX(0,NSWidth(self.bounds)-origin.x-12),MAX(0,NSHeight(self.bounds)-origin.y))
        withAttributes:@{NSFontAttributeName:self.font ?: [NSFont systemFontOfSize:13],NSForegroundColorAttributeName:JMSecondaryTextColor(),NSParagraphStyleAttributeName:style}];
}
@end
@interface JMConversationEmptyView ()
@property(nonatomic, strong) NSImageView *flower;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *detailLabel;
@property(nonatomic, strong, readwrite) NSButton *writeButton;
@end
@implementation JMConversationEmptyView
- (id)initWithFrame:(NSRect)frame {
    self=[super initWithFrame:frame]; if (!self) return nil;
    self.flower=[[NSImageView alloc] initWithFrame:NSZeroRect]; self.flower.image=JMFlowerImage(); self.flower.imageScaling=NSImageScaleProportionallyUpOrDown; [self addSubview:self.flower];
    self.titleLabel=[[NSTextField alloc] initWithFrame:NSZeroRect]; self.detailLabel=[[NSTextField alloc] initWithFrame:NSZeroRect];
    for (NSTextField *label in @[self.titleLabel,self.detailLabel]) {
        label.bordered=NO; label.drawsBackground=NO; label.editable=NO; label.selectable=NO; label.alignment=NSCenterTextAlignment;
        [[label cell] setWraps:YES]; [[label cell] setLineBreakMode:NSLineBreakByWordWrapping]; [self addSubview:label];
    }
    self.titleLabel.font=[NSFont boldSystemFontOfSize:17]; self.detailLabel.font=[NSFont systemFontOfSize:12]; self.detailLabel.textColor=JMSecondaryTextColor();
    self.writeButton=[[JMThemedButton alloc] initWithFrame:NSZeroRect]; self.writeButton.bezelStyle=NSRoundedBezelStyle; self.writeButton.title=JML(@"Написать по UIN…");
    self.writeButton.toolTip=JML(@"Открыть новую переписку по номеру UIN"); [self addSubview:self.writeButton]; [self setHasPeer:NO]; return self;
}
- (void)drawRect:(NSRect)dirtyRect { [[NSColor textBackgroundColor] setFill]; NSRectFill(dirtyRect); }
- (void)setHasPeer:(BOOL)hasPeer {
    self.titleLabel.stringValue=hasPeer ? JML(@"Пока нет сообщений") : JML(@"Здесь начнётся переписка");
    self.detailLabel.stringValue=hasPeer ? JML(@"Напишите первое сообщение. Черновик можно подготовить даже без сети.") : JML(@"Выберите контакт слева или начните разговор по UIN.");
    self.writeButton.hidden=hasPeer; [self layoutContents];
}
- (void)layoutContents {
    CGFloat width=MIN(420,MAX(0,NSWidth(self.bounds)-40)), center=floor(NSWidth(self.bounds)/2);
    if (JMTheme()!=JMThemeCurrent) {
        self.flower.hidden=YES; self.titleLabel.font=[NSFont boldSystemFontOfSize:13]; self.detailLabel.font=[NSFont systemFontOfSize:11];
        CGFloat height=NSHeight(self.bounds); self.titleLabel.frame=NSMakeRect(center-width/2,MAX(0,height-35),width,20); self.detailLabel.frame=NSMakeRect(center-width/2,MAX(0,height-76),width,36);
        self.writeButton.frame=NSMakeRect(center-96,MAX(2,height-108),192,23); return;
    }
    self.flower.hidden=NO; self.titleLabel.font=[NSFont boldSystemFontOfSize:17]; self.detailLabel.font=[NSFont systemFontOfSize:12];
    CGFloat top=floor((NSHeight(self.bounds)+(self.writeButton.isHidden ? 150 : 200))/2);
    self.flower.frame=NSMakeRect(center-24,top-48,48,48);
    self.titleLabel.frame=NSMakeRect(center-width/2,top-86,width,26);
    self.detailLabel.frame=NSMakeRect(center-width/2,top-132,width,40);
    self.writeButton.frame=NSMakeRect(center-96,top-175,192,32);
}
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize { [super resizeSubviewsWithOldSize:oldSize]; [self layoutContents]; }
@end
@interface JMUnreadBadge : NSTextField
@property(nonatomic, copy) NSString *text;
@property(nonatomic) BOOL emphasized;
@end
@implementation JMUnreadBadge
- (id)initWithFrame:(NSRect)frame {
    self=[super initWithFrame:frame]; if (self) { self.editable=NO; self.selectable=NO; self.bordered=NO; self.drawsBackground=NO; self.font=[NSFont boldSystemFontOfSize:11]; } return self;
}
- (void)setText:(NSString *)text { _text=[text copy]; self.stringValue=text ?: @""; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirtyRect {
    if (!self.text.length) return;
    if (JMTheme()!=JMThemeCurrent) {
        NSString *label=[NSString stringWithFormat:@"(%@)",self.text]; NSFont *font=[NSFont boldSystemFontOfSize:10]; NSSize size=[label sizeWithAttributes:@{NSFontAttributeName:font}];
        NSColor *color=self.emphasized ? [NSColor whiteColor] : (JMTheme()==JMThemeMac2011 ? [NSColor colorWithCalibratedRed:0.13 green:0.36 blue:0.1 alpha:1] : [NSColor colorWithCalibratedRed:0.1 green:0.2 blue:0.4 alpha:1]);
        [label drawInRect:NSMakeRect(floor((NSWidth(self.bounds)-size.width)/2),floor((NSHeight(self.bounds)-size.height)/2),size.width,size.height) withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:color}]; return;
    }
    NSColor *blue=[NSColor colorWithCalibratedRed:0.20 green:0.38 blue:0.60 alpha:1];
    [(self.emphasized ? [NSColor whiteColor] : blue) setFill]; [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:9 yRadius:9] fill];
    NSDictionary *attributes=@{NSFontAttributeName:[NSFont boldSystemFontOfSize:11],NSForegroundColorAttributeName:self.emphasized ? blue : [NSColor whiteColor]};
    NSSize size=[self.text sizeWithAttributes:attributes]; [self.text drawAtPoint:NSMakePoint(floor((NSWidth(self.bounds)-size.width)/2),floor((NSHeight(self.bounds)-size.height)/2)) withAttributes:attributes];
}
@end
@interface JMListCell ()
@property(nonatomic, strong) NSTextField *detailLabel;
@property(nonatomic, strong) NSTextField *timestampLabel;
@property(nonatomic, strong) JMUnreadBadge *badge;
@property(nonatomic, strong) NSImageView *presenceImage;
@property(nonatomic) BOOL draft;
@property(nonatomic) NSInteger unread;
@end
@implementation JMListCell
- (id)initWithFrame:(NSRect)frame {
    self=[super initWithFrame:frame]; if (!self) return nil;
    NSImageView *avatar=[[JMClassicAvatarView alloc] initWithFrame:NSZeroRect]; avatar.imageScaling=NSImageScaleProportionallyUpOrDown; [self addSubview:avatar]; self.imageView=avatar;
    self.presenceImage=[[NSImageView alloc] initWithFrame:NSZeroRect]; self.presenceImage.imageScaling=NSImageScaleProportionallyUpOrDown; [self addSubview:self.presenceImage];
    NSTextField *name=[[NSTextField alloc] initWithFrame:NSZeroRect]; [self addSubview:name]; self.textField=name;
    self.detailLabel=[[NSTextField alloc] initWithFrame:NSZeroRect]; self.timestampLabel=[[NSTextField alloc] initWithFrame:NSZeroRect];
    for (NSTextField *label in @[self.textField,self.detailLabel,self.timestampLabel]) {
        label.bordered=NO; label.drawsBackground=NO; label.editable=NO; label.selectable=NO;
        [[label cell] setLineBreakMode:NSLineBreakByTruncatingTail]; [self addSubview:label];
    }
    self.textField.font=[NSFont systemFontOfSize:13]; self.detailLabel.font=[NSFont systemFontOfSize:11];
    self.timestampLabel.font=[NSFont systemFontOfSize:10]; self.timestampLabel.alignment=NSRightTextAlignment;
    self.badge=[[JMUnreadBadge alloc] initWithFrame:NSZeroRect]; [self addSubview:self.badge]; [self layoutContents]; return self;
}
- (void)layoutContents {
    CGFloat width=NSWidth(self.bounds), height=NSHeight(self.bounds)-[self groupHeaderHeight];
    BOOL person=[self.identifier isEqual:@"person"], compact=JMTheme()==JMThemePro2003 && person, mac=JMTheme()==JMThemeMac2011 && person;
    self.imageView.hidden=compact; self.detailLabel.hidden=compact || (mac && !self.detailLabel.stringValue.length);
    CGFloat badgeWidth=self.badge.text.length ? MAX(18,[self.badge.text sizeWithAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:10]}].width+10) : 0;
    if (compact) {
        self.presenceImage.frame=NSMakeRect(5,floor((height-16)/2),16,16);
        self.textField.frame=NSMakeRect(25,floor((height-17)/2),MAX(0,width-31-(badgeWidth ? badgeWidth+5 : 0)),17);
        self.badge.frame=NSMakeRect(width-5-badgeWidth,floor((height-18)/2),badgeWidth,18); self.badge.hidden=badgeWidth==0;
        self.timestampLabel.hidden=YES; return;
    }
    if (mac) {
        self.presenceImage.frame=NSMakeRect(7,floor((height-16)/2),16,16); self.imageView.frame=NSMakeRect(width-37,floor((height-28)/2),28,28);
        self.textField.frame=NSMakeRect(29,self.detailLabel.isHidden ? floor((height-18)/2) : height-23,MAX(0,width-73-(badgeWidth ? badgeWidth+5 : 0)),18);
        self.detailLabel.frame=NSMakeRect(29,2,MAX(0,width-73),15);
        self.timestampLabel.hidden=YES; self.badge.frame=NSMakeRect(width-42-badgeWidth,height-19,badgeWidth,18); self.badge.hidden=badgeWidth==0; return;
    }
    CGFloat stampWidth=self.timestampLabel.stringValue.length ? MAX(34,ceil([[self.timestampLabel cell] cellSize].width)+2) : 0;
    self.imageView.frame=NSMakeRect(10,floor((height-36)/2),36,36); self.presenceImage.frame=NSMakeRect(35,floor((height-36)/2)-3,16,16);
    self.timestampLabel.frame=NSMakeRect(width-12-stampWidth,height-25,stampWidth,17); self.timestampLabel.hidden=stampWidth==0;
    self.textField.frame=NSMakeRect(56,height-27,MAX(0,width-68-(stampWidth ? stampWidth+8 : 0)),21);
    self.detailLabel.frame=NSMakeRect(56,10,MAX(0,width-68-(badgeWidth ? badgeWidth+8 : 0)),17);
    self.badge.frame=NSMakeRect(width-12-badgeWidth,10,badgeWidth,18); self.badge.hidden=badgeWidth==0;
}
- (CGFloat)groupHeaderHeight { return self.groupTitle.length && [self.identifier isEqual:@"person"] && JMTheme()!=JMThemeCurrent ? (JMTheme()==JMThemePro2003 ? 17 : 21) : 0; }
- (void)setGroupTitle:(NSString *)title { _groupTitle=[title copy]; [self layoutContents]; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect]; CGFloat header=[self groupHeaderHeight]; if (!header) return;
    NSRect rect=NSMakeRect(0,NSHeight(self.bounds)-header,NSWidth(self.bounds),header);
    BOOL pro=JMTheme()==JMThemePro2003;
    [(pro ? [NSColor whiteColor] : [NSColor colorWithSRGBRed:222.0/255 green:224.0/255 blue:214.0/255 alpha:1]) setFill]; NSRectFill(rect);
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.alignment=pro ? NSCenterTextAlignment : NSLeftTextAlignment; style.lineBreakMode=NSLineBreakByTruncatingTail;
    NSFont *font=pro ? [NSFont systemFontOfSize:10] : [NSFont boldSystemFontOfSize:11];
    if (pro) { [[NSColor colorWithCalibratedWhite:0.6 alpha:1] setFill]; NSRectFill(NSMakeRect(4,NSMidY(rect),NSWidth(rect)-8,1)); CGFloat w=[self.groupTitle sizeWithAttributes:@{NSFontAttributeName:font}].width+10; [[NSColor whiteColor] setFill]; NSRectFill(NSMakeRect(NSMidX(rect)-w/2,rect.origin.y,w,header)); }
    [self.groupTitle drawInRect:NSInsetRect(rect,pro ? 6 : 9,3) withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:0.25 alpha:1],NSParagraphStyleAttributeName:style}];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize { [super resizeSubviewsWithOldSize:oldSize]; [self layoutContents]; }
- (void)configureName:(NSString *)name detail:(NSString *)detail state:(NSString *)state unread:(NSInteger)unread {
    self.textField.stringValue=name; self.detailLabel.stringValue=detail; self.unread=unread;
    CGFloat size=[self.identifier isEqual:@"person"] && JMTheme()!=JMThemeCurrent ? 11 : 13;
    self.textField.font=unread>0 || (JMTheme()==JMThemeMac2011 && [self.identifier isEqual:@"person"]) ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    self.detailLabel.font=[NSFont systemFontOfSize:JMTheme()==JMThemeMac2011 ? 10 : 11];
    self.badge.text=unread>99 ? @"99+" : (unread>0 ? [NSString stringWithFormat:@"%ld",(long)unread] : @"");
    self.badge.toolTip=unread>0 ? [NSString stringWithFormat:JML(@"Непрочитанных сообщений: %ld"),(long)unread] : nil;
    // The native text-field cell exposes the exact count to Accessibility;
    // drawRect uses the separate compact text for the visible badge.
    self.badge.stringValue=self.badge.toolTip ?: @"";
    self.toolTip=[NSString stringWithFormat:@"%@\n%@",name,detail]; self.presenceImage.image=JMStatusImage(state);
    [self setTimestamp:nil draft:NO];
}
- (void)setTimestamp:(NSString *)timestamp draft:(BOOL)draft {
    self.timestampLabel.stringValue=timestamp ?: @""; self.timestampLabel.toolTip=nil; self.draft=draft; [self layoutContents]; [self setBackgroundStyle:self.backgroundStyle];
}
- (void)setTimestampTooltip:(NSString *)tooltip { self.timestampLabel.toolTip=tooltip; }
- (void)setAvatar:(NSImage *)image { self.imageView.image=image ?: [NSImage imageNamed:NSImageNameUser]; }
- (void)setBackgroundStyle:(NSBackgroundStyle)style {
    [super setBackgroundStyle:style]; BOOL selected=style==NSBackgroundStyleDark;
    self.textField.textColor=selected ? [NSColor whiteColor] : [NSColor textColor];
    self.detailLabel.textColor=selected ? [NSColor whiteColor] : (self.draft ? [NSColor colorWithCalibratedRed:0.49 green:0.29 blue:0.10 alpha:1] : JMSecondaryTextColor());
    self.timestampLabel.textColor=selected ? [NSColor whiteColor] : JMSecondaryTextColor();
    self.badge.emphasized=selected; self.badge.needsDisplay=YES;
}
@end
static NSColor *JMColor(CGFloat r,CGFloat g,CGFloat b) { return [NSColor colorWithSRGBRed:r/255 green:g/255 blue:b/255 alpha:1]; }
// Samples follow the original screenshots (JPEG values averaged away from text).
// Pixel borders are independent from the fill; the two clients have different bezels.
#include "JMHistoricalColorSamples.inc"
static NSGradient *JMGradientFromSamples(const unsigned int *samples,NSUInteger count) {
    NSMutableArray *colors=[NSMutableArray arrayWithCapacity:count+2]; CGFloat positions[count+2];
    unsigned int first=samples[count-1], last=samples[0]; [colors addObject:JMColor((first>>16)&255,(first>>8)&255,first&255)]; positions[0]=0;
    for (NSUInteger i=0;i<count;i++) { unsigned int rgb=samples[count-i-1]; [colors addObject:JMColor((rgb>>16)&255,(rgb>>8)&255,rgb&255)]; positions[i+1]=((CGFloat)i+0.5)/count; }
    [colors addObject:JMColor((last>>16)&255,(last>>8)&255,last&255)]; positions[count+1]=1;
    return [[NSGradient alloc] initWithColors:colors atLocations:positions colorSpace:[NSColorSpace sRGBColorSpace]];
}
static NSGradient *JMMacHeaderGradient(void) { static NSGradient *gradient; static dispatch_once_t once; dispatch_once(&once,^{ gradient=JMGradientFromSamples(JMMacHeaderRGB,sizeof(JMMacHeaderRGB)/sizeof(*JMMacHeaderRGB)); }); return gradient; }
static NSGradient *JMProButtonGradient(void) { static NSGradient *gradient; static dispatch_once_t once; dispatch_once(&once,^{ gradient=JMGradientFromSamples(JMProButtonRGB,sizeof(JMProButtonRGB)/sizeof(*JMProButtonRGB)); }); return gradient; }
static void JMDrawMacHeader(NSRect rect) {
    NSRect inner=rect; inner.origin.y+=1; inner.size.height-=3; [JMMacHeaderGradient() drawInRect:inner angle:90];
    [JMColor(158,190,158) setFill]; NSRectFill(NSMakeRect(NSMinX(rect),NSMaxY(rect)-1,NSWidth(rect),1));
    [JMColor(151,198,153) setFill]; NSRectFill(NSMakeRect(NSMinX(rect),NSMaxY(rect)-2,NSWidth(rect),1));
    [JMColor(168,193,163) setFill]; NSRectFill(NSMakeRect(NSMinX(rect),NSMinY(rect),NSWidth(rect),1));
}
static void JMDrawControl(NSRect frame,BOOL pressed,BOOL focused,BOOL enabled,BOOL flipped) {
    BOOL pro=JMTheme()==JMThemePro2003; CGFloat radius=pro ? 3 : 1;
    NSRect outer=NSInsetRect(frame,0.5,0.5), inner=NSInsetRect(outer,1,1);
    NSBezierPath *edge=[NSBezierPath bezierPathWithRoundedRect:outer xRadius:radius yRadius:radius];
    if (pro) [[[NSGradient alloc] initWithStartingColor:JMColor(79,82,93) endingColor:JMColor(151,152,157)] drawInBezierPath:edge angle:flipped ? 270 : 90];
    else { [JMColor(153,158,142) setFill]; [edge fill]; }
    NSGradient *fill;
    if (pressed) fill=pro ? [[NSGradient alloc] initWithStartingColor:JMColor(223,231,244) endingColor:JMColor(182,195,217)] : [[NSGradient alloc] initWithStartingColor:JMColor(242,243,237) endingColor:JMColor(220,224,211)];
    else if (pro) fill=JMProButtonGradient();
    else fill=[[NSGradient alloc] initWithColorsAndLocations:JMColor(243,242,240),0.0,JMColor(248,249,247),0.45,JMColor(254,255,253),0.90,JMColor(255,255,251),1.0,nil];
    if (!enabled) fill=[[NSGradient alloc] initWithStartingColor:JMColor(227,230,235) endingColor:JMColor(247,248,251)];
    [fill drawInBezierPath:[NSBezierPath bezierPathWithRoundedRect:inner xRadius:MAX(0,radius-1) yRadius:MAX(0,radius-1)] angle:flipped ? 270 : 90];
    if (!pro) { [[NSColor whiteColor] setStroke]; [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(outer,1.5,1.5) xRadius:0.5 yRadius:0.5] stroke]; }
    if (focused) { [NSGraphicsContext saveGraphicsState]; NSSetFocusRingStyle(NSFocusRingOnly); [edge fill]; [NSGraphicsContext restoreGraphicsState]; }
}
static void JMDrawMacConversationTab(NSRect frame,BOOL selected,BOOL focused,BOOL flipped) {
    NSRect outer=NSInsetRect(frame,0.5,0.5); NSBezierPath *edge=[NSBezierPath bezierPathWithRoundedRect:outer xRadius:4 yRadius:4];
    [(selected ? JMColor(111,158,104) : JMColor(175,176,165)) setFill]; [edge fill];
    NSGradient *fill=selected ? [[NSGradient alloc] initWithColorsAndLocations:JMColor(138,216,135),0.0,JMColor(98,218,90),0.20,JMColor(10,206,49),0.50,JMColor(17,186,45),0.61,JMColor(79,215,96),0.66,JMColor(207,247,203),1.0,nil] : [[NSGradient alloc] initWithColorsAndLocations:JMColor(215,218,209),0.0,JMColor(229,229,219),0.48,JMColor(228,228,218),0.85,JMColor(217,217,207),1.0,nil];
    [fill drawInBezierPath:[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(outer,1,1) xRadius:3 yRadius:3] angle:flipped ? 270 : 90];
    if (focused) { [NSGraphicsContext saveGraphicsState]; NSSetFocusRingStyle(NSFocusRingOnly); [edge fill]; [NSGraphicsContext restoreGraphicsState]; }
}
@interface JMThemedButtonCell ()
@property(nonatomic) BOOL hovered;
@end
@implementation JMThemedButtonCell
- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)view {
    if (JMTheme()==JMThemeCurrent) { [super drawBezelWithFrame:frame inView:view]; return; }
    JMDrawControl(frame,self.isHighlighted || self.state==NSOnState,self.showsFirstResponder,self.isEnabled,view.isFlipped);
    if (self.hovered && self.isEnabled && !self.isHighlighted) { [(JMTheme()==JMThemePro2003 ? JMColor(80,115,175) : JMColor(72,132,42)) setStroke]; NSBezierPath *edge=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame,1.5,1.5) xRadius:3 yRadius:3]; [edge stroke]; }
}
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view {
    if (JMTheme()==JMThemeCurrent) { [super drawInteriorWithFrame:frame inView:view]; return; }
    NSRect content=NSInsetRect(frame,6,1);
    NSFont *font=self.font ?: [NSFont systemFontOfSize:11];
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.alignment=NSCenterTextAlignment; style.lineBreakMode=NSLineBreakByTruncatingTail;
    NSColor *ink=self.isEnabled ? ((JMTheme()==JMThemePro2003 && view.tag==905) ? JMColor(160,55,54) : JMColor(27,37,55)) : JMColor(115,121,133);
    if (self.image && self.imagePosition==NSImageOnly) { [self.image drawInRect:NSMakeRect(NSMidX(frame)-8,NSMidY(frame)-8,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:self.isEnabled ? 1 : 0.45 respectFlipped:YES hints:nil]; return; }
    CGFloat textWidth=[self.title sizeWithAttributes:@{NSFontAttributeName:font}].width;
    if (self.image && self.imagePosition!=NSNoImage) {
        CGFloat x=NSMidX(frame)-(MIN(textWidth,NSWidth(content)-22)+21)/2;
        [self.image drawInRect:NSMakeRect(x,NSMidY(frame)-8,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:self.isEnabled ? 1 : 0.45 respectFlipped:YES hints:nil];
        content.origin.x=x+21; content.size.width=NSMaxX(frame)-6-content.origin.x;
    }
    NSSize size=[self.title sizeWithAttributes:@{NSFontAttributeName:font}];
    content.origin.y=NSMidY(frame)-ceil(size.height)/2+(self.isHighlighted ? (view.isFlipped ? 1 : -1) : 0); content.size.height=ceil(size.height);
    [self.title drawInRect:content withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:ink,NSParagraphStyleAttributeName:style}];
}
@end
@interface JMThemedButton ()
@property(nonatomic,strong) NSTrackingArea *themeTracking;
@end
@implementation JMThemedButton
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if (self.themeTracking) [self removeTrackingArea:self.themeTracking];
    self.themeTracking=[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect owner:self userInfo:nil]; [self addTrackingArea:self.themeTracking];
}
- (void)mouseEntered:(NSEvent *)event { [(JMThemedButtonCell *)self.cell setHovered:YES]; self.needsDisplay=YES; }
- (void)mouseExited:(NSEvent *)event { [(JMThemedButtonCell *)self.cell setHovered:NO]; self.needsDisplay=YES; }
+ (Class)cellClass { return [JMThemedButtonCell class]; }
@end
@interface JMThemedPopUpCell : NSPopUpButtonCell
@end
@implementation JMThemedPopUpCell
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
    if (JMTheme()==JMThemeCurrent) { [super drawWithFrame:frame inView:view]; return; }
    if (JMTheme()==JMThemeMac2011 && view.tag==901) {
        NSMenuItem *item=self.selectedItem; [item.image drawInRect:NSMakeRect(NSMinX(frame)+1,NSMidY(frame)-8,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:self.isEnabled ? 1 : 0.5 respectFlipped:YES hints:nil];
        NSBezierPath *arrow=[NSBezierPath bezierPath]; CGFloat x=NSMaxX(frame)-5,y=NSMidY(frame); [arrow moveToPoint:NSMakePoint(x-2,y+2)]; [arrow lineToPoint:NSMakePoint(x+2,y+2)]; [arrow lineToPoint:NSMakePoint(x,y-1)]; [arrow closePath]; [JMColor(31,66,24) setFill]; [arrow fill];
        if (self.showsFirstResponder || self.isHighlighted) { [JMColor(244,253,237) setStroke]; [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame,0.5,0.5) xRadius:2 yRadius:2] stroke]; } return;
    }
    JMDrawControl(frame,self.isHighlighted,self.showsFirstResponder,self.isEnabled,view.isFlipped);
    if (JMTheme()==JMThemeMac2011 && view.tag==902) { [JMColor(84,96,77) setFill]; for (NSInteger i=0;i<3;i++) NSRectFill(NSMakeRect(NSMinX(frame)+5,NSMidY(frame)-3+i*3,9,1)); return; }
    NSRect text=NSInsetRect(frame,7,2); text.size.width-=13;
    NSMenuItem *item=self.pullsDown ? [self.itemArray firstObject] : self.selectedItem;
    if (item.image) { [item.image drawInRect:NSMakeRect(text.origin.x,NSMidY(frame)-8,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:self.isEnabled ? 1 : 0.45 respectFlipped:YES hints:nil]; text.origin.x+=21; text.size.width-=21; }
    NSString *title=item.title ?: self.title;
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.lineBreakMode=NSLineBreakByTruncatingTail;
    NSFont *font=self.font ?: [NSFont systemFontOfSize:11]; NSSize size=[title sizeWithAttributes:@{NSFontAttributeName:font}]; text.origin.y=NSMidY(frame)-ceil(size.height)/2; text.size.height=ceil(size.height);
    [(self.isEnabled ? JMColor(30,39,45) : JMColor(112,118,127)) setFill];
    [title drawInRect:text withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:self.isEnabled ? JMColor(30,39,45) : JMColor(112,118,127),NSParagraphStyleAttributeName:style}];
    NSBezierPath *arrow=[NSBezierPath bezierPath]; CGFloat x=NSMaxX(frame)-10,y=NSMidY(frame);
    [arrow moveToPoint:NSMakePoint(x-3,y+(view.isFlipped ? -2 : 2))]; [arrow lineToPoint:NSMakePoint(x+3,y+(view.isFlipped ? -2 : 2))]; [arrow lineToPoint:NSMakePoint(x,y+(view.isFlipped ? 2 : -2))]; [arrow closePath]; [arrow fill];
}
@end
@implementation JMThemedPopUpButton
+ (Class)cellClass { return [JMThemedPopUpCell class]; }
@end
@implementation JMThemedSegmentedCell
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
    if (JMTheme()==JMThemeCurrent) { [super drawWithFrame:frame inView:view]; return; }
    CGFloat x=frame.origin.x;
    for (NSInteger i=0;i<self.segmentCount;i++) {
        CGFloat width=[self widthForSegment:i]; if (!width) width=NSWidth(frame)/MAX(1,self.segmentCount);
        NSRect segment=NSMakeRect(x,frame.origin.y,width,NSHeight(frame));
        if (JMTheme()==JMThemeMac2011 && view.tag==904) JMDrawMacConversationTab(NSInsetRect(segment,1,1),[self isSelectedForSegment:i],self.showsFirstResponder && [self isSelectedForSegment:i],view.isFlipped);
        else JMDrawControl(NSInsetRect(segment,1,1),[self isSelectedForSegment:i] && view.tag!=903,self.showsFirstResponder && [self isSelectedForSegment:i],self.isEnabled,view.isFlipped);
        NSFont *font=self.font ?: [NSFont systemFontOfSize:11]; NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.alignment=NSCenterTextAlignment; style.lineBreakMode=NSLineBreakByTruncatingTail;
        NSImage *icon=[self imageForSegment:i]; NSString *title=[self labelForSegment:i]; CGFloat inset=5;
        if (icon) {
            BOOL labeled=title.length>0; [icon drawInRect:labeled ? NSMakeRect(x+5,NSMidY(segment)-8,16,16) : NSMakeRect(NSMidX(segment)-9,NSMidY(segment)-9,18,18) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
            if (!labeled) { x+=width; continue; } inset=25;
        }
        NSSize size=[title sizeWithAttributes:@{NSFontAttributeName:font}];
        [title drawInRect:NSMakeRect(x+inset,NSMidY(frame)-ceil(size.height)/2,width-inset-5,ceil(size.height)) withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:JMColor(31,46,37),NSParagraphStyleAttributeName:style}]; x+=width;
    }
}
@end
@implementation JMConversationChrome
- (void)drawRect:(NSRect)dirtyRect {
    if (JMTheme()==JMThemeMac2011) {
        [JMColor(233,233,225) setFill]; NSRectFill(self.bounds);
        NSRect top=NSMakeRect(0,NSHeight(self.bounds)-31,NSWidth(self.bounds),31); [JMColor(247,248,242) setFill]; NSRectFill(top);
        NSRect green=NSMakeRect(0,NSHeight(self.bounds)-99,NSWidth(self.bounds),68);
        JMDrawMacHeader(green);
        [JMColor(210,222,230) setFill]; NSRectFill(NSMakeRect(0,NSHeight(self.bounds)-125,NSWidth(self.bounds),26));
    } else {
        [JMThemeBackground() setFill]; NSRectFill(self.bounds);
        [[[NSGradient alloc] initWithStartingColor:JMColor(216,219,231) endingColor:JMColor(244,247,255)] drawInRect:self.bounds angle:90];
    }
    [JMColor(150,159,169) setFill]; NSRectFill(NSMakeRect(0,0,NSWidth(self.bounds),1));
}
@end
@implementation JMRosterChrome
- (void)drawRect:(NSRect)dirtyRect {
    if (JMTheme()==JMThemeCurrent) { [super drawRect:dirtyRect]; return; }
    BOOL mac=JMTheme()==JMThemeMac2011; [JMThemeBackground() setFill]; NSRectFill(self.bounds);
    if (mac) {
        NSRect profile=NSMakeRect(0,28,NSWidth(self.bounds),NSHeight(self.bounds)-50);
        JMDrawMacHeader(profile);
        NSRect status=NSMakeRect(66,NSHeight(self.bounds)-84,NSWidth(self.bounds)-73,36); [[NSColor colorWithCalibratedWhite:1 alpha:0.96] setFill]; [[NSBezierPath bezierPathWithRoundedRect:status xRadius:2 yRadius:2] fill];
        NSBezierPath *pointer=[NSBezierPath bezierPath]; [pointer moveToPoint:NSMakePoint(66,NSMidY(status)-4)]; [pointer lineToPoint:NSMakePoint(60,NSMidY(status))]; [pointer lineToPoint:NSMakePoint(66,NSMidY(status)+4)]; [pointer closePath]; [pointer fill];
        NSRect brand=NSMakeRect(0,NSHeight(self.bounds)-22,NSWidth(self.bounds),22);
        [[[NSGradient alloc] initWithStartingColor:JMColor(205,212,199) endingColor:JMColor(249,251,245)] drawInRect:brand angle:90];
        [JMFlowerImage() drawInRect:NSMakeRect(7,NSHeight(self.bounds)-20,16,16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:NO hints:nil];
    } else [[[NSGradient alloc] initWithStartingColor:JMColor(207,214,230) endingColor:JMColor(247,249,254)] drawInRect:self.bounds angle:90];
    [JMColor(151,159,170) setFill]; NSRectFill(NSMakeRect(0,0,NSWidth(self.bounds),1));
}
@end
NSImage *JMClassicToolbarImage(NSString *name) {
    static NSMutableDictionary *icons; if (!icons) icons=[NSMutableDictionary dictionary]; if (icons[name]) return icons[name];
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(18,18)]; [image lockFocus];
    if ([name isEqual:@"contacts"]) {
        NSArray *colors=@[JMColor(214,66,43),JMColor(91,154,40),JMColor(222,166,27)];
        for (NSUInteger i=0;i<3;i++) { CGFloat x=2+i*5,y=i==1 ? 1 : 3; [colors[i] setFill]; [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x,y,6,7) xRadius:2 yRadius:2] fill]; [JMColor(250,208,142) setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x+1,y+7,5,5)] fill]; }
    } else if ([name isEqual:@"conversations"]) {
        [JMColor(74,157,39) setFill]; [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1,6,13,10) xRadius:3 yRadius:3] fill];
        NSBezierPath *tail=[NSBezierPath bezierPath]; [tail moveToPoint:NSMakePoint(3,7)]; [tail lineToPoint:NSMakePoint(3,3)]; [tail lineToPoint:NSMakePoint(8,7)]; [tail closePath]; [tail fill];
        [JMColor(83,146,195) setFill]; [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(7,1,10,9) xRadius:2 yRadius:2] fill];
        [[NSColor whiteColor] setFill]; for (NSInteger x=9;x<=15;x+=3) NSRectFill(NSMakeRect(x,5,1,1));
    } else if ([name isEqual:@"favorites"]) {
        [JMColor(107,113,111) setFill]; NSRectFill(NSMakeRect(4,1,2,15));
        NSBezierPath *flag=[NSBezierPath bezierPath]; [flag moveToPoint:NSMakePoint(6,15)]; [flag curveToPoint:NSMakePoint(17,13) controlPoint1:NSMakePoint(11,18) controlPoint2:NSMakePoint(13,10)]; [flag lineToPoint:NSMakePoint(16,7)]; [flag curveToPoint:NSMakePoint(6,9) controlPoint1:NSMakePoint(12,5) controlPoint2:NSMakePoint(10,12)]; [flag closePath]; [JMColor(61,144,189) setFill]; [flag fill];
    } else if ([name isEqual:@"historyPage"]) {
        NSBezierPath *page=[NSBezierPath bezierPath]; [page moveToPoint:NSMakePoint(2,1)]; [page lineToPoint:NSMakePoint(2,17)]; [page lineToPoint:NSMakePoint(12,17)]; [page lineToPoint:NSMakePoint(16,13)]; [page lineToPoint:NSMakePoint(16,1)]; [page closePath]; [JMColor(255,244,160) setFill]; [page fill]; [JMColor(118,119,40) setStroke]; [page stroke];
        [@"H" drawAtPoint:NSMakePoint(4,3) withAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:10],NSForegroundColorAttributeName:JMColor(42,46,20)}];
    } else if ([name isEqual:@"history"]) {
        [JMColor(100,132,50) setFill]; [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1,1,16,16) xRadius:2 yRadius:2] fill];
        [@"H" drawAtPoint:NSMakePoint(4,1) withAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:14],NSForegroundColorAttributeName:JMColor(248,246,210)}];
    } else {
        [JMColor(154,140,83) setStroke]; [JMColor(252,239,185) setFill]; NSBezierPath *card=[NSBezierPath bezierPathWithRect:NSMakeRect(1.5,3.5,15,11)]; [card fill]; [card stroke];
        [JMColor(219,149,96) setFill]; [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(4,9,4,4)] fill]; [JMColor(93,149,170) setFill]; NSRectFill(NSMakeRect(3,5,6,4)); [JMColor(149,143,102) setFill]; NSRectFill(NSMakeRect(11,10,4,1)); NSRectFill(NSMakeRect(11,7,4,1));
    }
    [image unlockFocus]; icons[name]=image; return image;
}
@interface JMThemedSearchCell : NSSearchFieldCell
@end
@implementation JMThemedSearchCell
- (NSRect)searchButtonRectForBounds:(NSRect)rect { return JMTheme()==JMThemeMac2011 ? NSMakeRect(NSMaxX(rect)-21,NSMinY(rect)+2,18,NSHeight(rect)-4) : [super searchButtonRectForBounds:rect]; }
- (NSRect)cancelButtonRectForBounds:(NSRect)rect { return JMTheme()==JMThemeMac2011 ? NSMakeRect(NSMaxX(rect)-39,NSMinY(rect)+2,16,NSHeight(rect)-4) : [super cancelButtonRectForBounds:rect]; }
- (NSRect)searchTextRectForBounds:(NSRect)rect { return JMTheme()==JMThemeMac2011 ? NSMakeRect(NSMinX(rect)+5,NSMinY(rect)+2,NSWidth(rect)-44,NSHeight(rect)-4) : [super searchTextRectForBounds:rect]; }
@end
@implementation JMThemedSearchField
+ (Class)cellClass { return [JMThemedSearchCell class]; }
@end
@implementation JMClassicSendBar
- (void)drawRect:(NSRect)dirtyRect {
    if (JMTheme()!=JMThemePro2003) return;
    NSRect rect=NSInsetRect(self.bounds,0.5,0.5);
    [[[NSGradient alloc] initWithStartingColor:JMColor(213,215,227) endingColor:JMColor(239,239,249)] drawInRect:rect angle:90];
    [JMColor(102,106,119) setStroke]; NSBezierPath *edge=[NSBezierPath bezierPathWithRoundedRect:rect xRadius:6 yRadius:6]; [edge stroke];
    NSBezierPath *split=[NSBezierPath bezierPath]; [split moveToPoint:NSMakePoint(88,0)]; [split lineToPoint:NSMakePoint(112,NSHeight(rect))]; [JMColor(137,149,177) setStroke]; [split stroke];
    [[NSColor colorWithCalibratedWhite:1 alpha:0.8] setStroke]; NSBezierPath *shine=[NSBezierPath bezierPath]; [shine moveToPoint:NSMakePoint(90,0)]; [shine lineToPoint:NSMakePoint(114,NSHeight(rect))]; [shine stroke];
}
@end
@implementation JMClassicAvatarView
- (void)drawRect:(NSRect)dirtyRect {
    if (JMTheme()!=JMThemeMac2011) { [super drawRect:dirtyRect]; return; }
    NSBezierPath *edge=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,0.5,0.5) xRadius:2.5 yRadius:2.5];
    [[NSColor whiteColor] setFill]; [edge fill];
    [NSGraphicsContext saveGraphicsState]; [edge addClip]; [super drawRect:dirtyRect]; [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:1 alpha:0.9] setStroke]; [edge stroke];
}
@end
