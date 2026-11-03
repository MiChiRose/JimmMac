#import "JMLocalization.h"
#import "JMInformationController.h"
#import "JMKeyboard.h"
#import "JMStyle.h"
#import <float.h>

NSURL *JMTelegraphicaURL(void) { return [NSURL URLWithString:@"https://github.com/MiChiRose/telegraphica"]; }
@interface JMInformationBackground : NSView
@end
@implementation JMInformationBackground
- (BOOL)isOpaque { return YES; }
- (void)drawRect:(NSRect)rect { [[NSColor windowBackgroundColor] setFill]; NSRectFill(rect); }
@end
static NSTextField *Label(NSString *text, NSRect frame, CGFloat size, BOOL bold) {
    NSTextField *field=[[NSTextField alloc] initWithFrame:frame]; field.stringValue=text; field.editable=NO; field.selectable=YES;
    field.bordered=NO; field.drawsBackground=NO; field.font=bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    [[field cell] setWraps:YES]; [[field cell] setLineBreakMode:NSLineBreakByWordWrapping]; field.toolTip=text; return field;
}
static NSButton *Button(NSString *text, NSRect frame, id target, SEL action) {
    NSButton *button=[[NSButton alloc] initWithFrame:frame]; button.title=text; button.bezelStyle=NSRoundedBezelStyle;
    button.target=target; button.action=action; button.toolTip=text; return button;
}
@implementation JMInformationController
- (id)initWithKeyboardHelp:(BOOL)keyboardHelp {
    CGFloat height=keyboardHelp ? 570 : 420;
    JMWindow *window=[[JMWindow alloc] initWithContentRect:NSMakeRect(0,0,560,height) styleMask:NSTitledWindowMask|NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
    self=[super initWithWindow:window]; if (!self) return nil;
    window.title=keyboardHelp ? JML(@"Сочетания клавиш — JimmMac") : JML(@"О JimmMac"); window.releasedWhenClosed=NO;
    window.contentView=[[JMInformationBackground alloc] initWithFrame:NSMakeRect(0,0,560,height)];
    NSView *root=window.contentView;
    JMChromeView *header=[[JMChromeView alloc] initWithFrame:NSMakeRect(0,height-96,560,96)];
    header.topColor=JMLegacyHeaderTopColor(); header.bottomColor=JMLegacyHeaderBottomColor(); [root addSubview:header];
    NSImageView *flower=[[NSImageView alloc] initWithFrame:NSMakeRect(24,20,56,56)]; flower.image=JMFlowerImage(); flower.imageScaling=NSImageScaleProportionallyUpOrDown; [header addSubview:flower];
    NSString *version=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.14.0";
    [header addSubview:Label(keyboardHelp ? JML(@"JimmMac с клавиатуры") : [@"JimmMac " stringByAppendingString:version],NSMakeRect(96,48,438,28),21,YES)];
    [header addSubview:Label(JML(@"Ваша аська на Mac · Jimm.online"),NSMakeRect(97,22,438,20),12,NO)];
    if (keyboardHelp) {
        NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(22,62,516,height-176)]; scroll.hasVerticalScroller=YES; scroll.borderType=NSBezelBorder;
        NSTextView *text=[[NSTextView alloc] initWithFrame:scroll.contentView.bounds]; text.editable=NO; text.selectable=YES; text.richText=NO;
        text.font=[NSFont systemFontOfSize:13]; text.textContainerInset=NSMakeSize(12,12); text.verticallyResizable=YES; text.horizontallyResizable=NO;
        text.maxSize=NSMakeSize(FLT_MAX,FLT_MAX); text.textContainer.widthTracksTextView=YES; text.autoresizingMask=NSViewWidthSizable;
        text.string=JML(@"ПРАВКА\n⌘C / ⌘X / ⌘V — копировать, вырезать, вставить\n⌘A — выделить всё в текущем поле\n⌘Z / ⇧⌘Z — отменить / повторить изменение\n⌥⇧⌘V — вставить без оформления\n\nПЕРЕПИСКА\nEnter — отправить сообщение¹\n⇧Enter / ⌥Enter — новая строка\n⌘Enter — отправить из поля сообщения\nTab / ⇧Tab — следующий / предыдущий элемент\n⌥Tab — вставить табуляцию в сообщение\n↑ / ↓ — выбрать собеседника в списке\nEnter в списке — перейти к сообщению\nEscape в переписке — вернуть фокус в список\n\nНАВИГАЦИЯ\n⌘N — написать по UIN\n⇧⌘N — добавить контакт\n⌘1 / ⌘2 — контакты / переписки\n⌘L — поиск контактов или переписок\n⌘F — поиск по истории\n⌘I — мой профиль\n⌘S в профиле — сохранить изменения\n⌘, — настройки\n⌘0 — открыть главное окно\n⌘W — закрыть текущее окно\n⌘M / ⌘H — свернуть / скрыть\n⌘Q — завершить приложение\n⇧⌘L — выйти из аккаунта\n\nEscape закрывает вспомогательное окно. В поиске списка он сначала очищает фильтр, затем возвращает фокус в список. Черновик при этом сохраняется.\n\n¹ В настройках можно выбрать отправку только по ⌘Enter. Тогда обычный Enter добавляет строку. Во время ввода иероглифов Enter сначала подтверждает ввод.\n\n⌘ — Command    ⇧ — Shift    ⌥ — Option");
        scroll.documentView=text; [root addSubview:scroll];
    } else {
        [root addSubview:Label(JML(@"Личные сообщения, контакты и знакомые звуки ICQ на OS X 10.8–macOS 10.13."),NSMakeRect(26,252,508,54),14,NO)];
        [root addSubview:Label(JML(@"История и черновики хранятся на этом Mac. Для автоматического входа используется токен в системной Связке ключей; пароль не сохраняется."),NSMakeRect(26,176,508,66),12,NO)];
        NSBox *line=[[NSBox alloc] initWithFrame:NSMakeRect(26,160,508,1)]; line.boxType=NSBoxSeparator; [root addSubview:line];
        [root addSubview:Label(JML(@"Ещё один мессенджер для старого Mac"),NSMakeRect(26,124,508,24),13,YES)];
        [root addSubview:Label(JML(@"Telegraphica — наш клиент Telegram для Intel Mac с OS X 10.8–macOS 10.13. Скачивание и новости — на GitHub."),NSMakeRect(26,70,508,48),12,NO)];
        [root addSubview:Button(@"Jimm.online",NSMakeRect(20,16,128,32),self,@selector(openJimm:))];
        NSButton *telegraphica=Button(JML(@"Telegraphica на GitHub…"),NSMakeRect(150,16,232,32),self,@selector(openTelegraphica:)); telegraphica.toolTip=JMTelegraphicaURL().absoluteString; [root addSubview:telegraphica];
    }
    NSButton *close=Button(JML(@"Закрыть"),NSMakeRect(420,16,120,32),self,@selector(close:)); close.keyEquivalent=@"\e"; [root addSubview:close];
    [window center]; return self;
}
- (void)openJimm:(id)sender { [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://jimm.online/"]]; }
- (void)openTelegraphica:(id)sender { [[NSWorkspace sharedWorkspace] openURL:JMTelegraphicaURL()]; }
@end
