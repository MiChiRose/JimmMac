#import "JMStyle.h"
#import <ImageIO/ImageIO.h>
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
NSColor *JMLegacyHeaderTopColor(void) { return [NSColor colorWithCalibratedRed:0.97 green:0.99 blue:0.94 alpha:1]; }
NSColor *JMLegacyHeaderBottomColor(void) { return [NSColor colorWithCalibratedRed:0.81 green:0.88 blue:0.75 alpha:1]; }
@implementation JMChromeView
- (void)drawRect:(NSRect)dirtyRect {
    NSColor *top = self.topColor ?: [NSColor colorWithCalibratedWhite:0.97 alpha:1];
    NSColor *bottom = self.bottomColor ?: [NSColor colorWithCalibratedWhite:0.84 alpha:1];
    [[[NSGradient alloc] initWithStartingColor:bottom endingColor:top] drawInRect:self.bounds angle:90];
    [[NSColor colorWithCalibratedWhite:0.68 alpha:1] setFill]; NSRectFill(NSMakeRect(0,0,NSWidth(self.bounds),1));
}
@end
NSColor *JMSelectionColor(BOOL emphasized) {
    return emphasized ? [NSColor colorWithCalibratedRed:0.25 green:0.42 blue:0.65 alpha:1] : [NSColor colorWithCalibratedRed:0.80 green:0.84 blue:0.88 alpha:1];
}
@implementation JMContactRowView
- (NSBackgroundStyle)interiorBackgroundStyle { return self.selected && self.emphasized ? NSBackgroundStyleDark : NSBackgroundStyleLight; }
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
    self.writeButton=[[NSButton alloc] initWithFrame:NSZeroRect]; self.writeButton.bezelStyle=NSRoundedBezelStyle; self.writeButton.title=@"Написать по UIN…";
    self.writeButton.toolTip=@"Открыть новую переписку по номеру UIN"; [self addSubview:self.writeButton]; [self setHasPeer:NO]; return self;
}
- (void)drawRect:(NSRect)dirtyRect { [[NSColor textBackgroundColor] setFill]; NSRectFill(dirtyRect); }
- (void)setHasPeer:(BOOL)hasPeer {
    self.titleLabel.stringValue=hasPeer ? @"Пока нет сообщений" : @"Здесь начнётся переписка";
    self.detailLabel.stringValue=hasPeer ? @"Напишите первое сообщение. Черновик можно подготовить даже без сети." : @"Выберите контакт слева или начните разговор по UIN.";
    self.writeButton.hidden=hasPeer; [self layoutContents];
}
- (void)layoutContents {
    CGFloat width=MIN(420,MAX(0,NSWidth(self.bounds)-40)), center=floor(NSWidth(self.bounds)/2);
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
    NSImageView *avatar=[[NSImageView alloc] initWithFrame:NSZeroRect]; avatar.imageScaling=NSImageScaleProportionallyUpOrDown; [self addSubview:avatar]; self.imageView=avatar;
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
    CGFloat width=NSWidth(self.bounds), height=NSHeight(self.bounds);
    CGFloat stampWidth=self.timestampLabel.stringValue.length ? MAX(34,ceil([[self.timestampLabel cell] cellSize].width)+2) : 0;
    CGFloat badgeWidth=self.badge.text.length ? MAX(20,[self.badge.text sizeWithAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:11]}].width+12) : 0;
    self.imageView.frame=NSMakeRect(10,floor((height-36)/2),36,36); self.presenceImage.frame=NSMakeRect(35,floor((height-36)/2)-3,16,16);
    self.timestampLabel.frame=NSMakeRect(width-12-stampWidth,height-25,stampWidth,17); self.timestampLabel.hidden=stampWidth==0;
    self.textField.frame=NSMakeRect(56,height-27,MAX(0,width-68-(stampWidth ? stampWidth+8 : 0)),21);
    self.detailLabel.frame=NSMakeRect(56,10,MAX(0,width-68-(badgeWidth ? badgeWidth+8 : 0)),17);
    self.badge.frame=NSMakeRect(width-12-badgeWidth,10,badgeWidth,18); self.badge.hidden=badgeWidth==0;
}
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize { [super resizeSubviewsWithOldSize:oldSize]; [self layoutContents]; }
- (void)configureName:(NSString *)name detail:(NSString *)detail state:(NSString *)state unread:(NSInteger)unread {
    self.textField.stringValue=name; self.detailLabel.stringValue=detail; self.unread=unread;
    self.textField.font=unread>0 ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13];
    self.badge.text=unread>99 ? @"99+" : (unread>0 ? [NSString stringWithFormat:@"%ld",(long)unread] : @"");
    self.badge.toolTip=unread>0 ? [NSString stringWithFormat:@"Непрочитанных сообщений: %ld",(long)unread] : nil;
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
