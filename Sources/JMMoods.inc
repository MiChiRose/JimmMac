// Frame numbering follows the original Jimm.online strip, including shared frames.
static NSString *JMMoodTitle(NSString *code) {
    switch (JMMoodFrame(code)) {
        case 0: return JML(@"Покупки");
        case 1: return JML(@"Ванна");
        case 2: return JML(@"Устал");
        case 3: return JML(@"Вечеринка");
        case 4: return JML(@"Пиво");
        case 5: return JML(@"Думаю");
        case 6: return JML(@"Обедаю");
        case 7: return JML(@"Смотрю ТВ");
        case 8: return JML(@"С друзьями");
        case 9: return JML(@"Кофе");
        case 10: return JML(@"Музыка");
        case 11: return JML(@"Дела");
        case 12: return JML(@"Кино");
        case 13: return JML(@"Веселюсь");
        case 14: return JML(@"На телефоне");
        case 15: return JML(@"Играю");
        case 16: return JML(@"Учусь");
        case 17: return JML(@"Болею");
        case 18: return JML(@"Засыпаю");
        case 19: return JML(@"Сёрфинг");
        case 20: return JML(@"Интернет");
        case 21: return JML(@"Работаю");
        case 22: return JML(@"Печатаю");
        case 23: return JML(@"Злюсь");
        case 24: return JML(@"Выходные");
        case 25: return JML(@"КПК");
        case 26: return JML(@"На мобильном");
        case 27: return JML(@"Сплю");
        case 28: return JML(@"В туалете");
        case 29: return JML(@"В замешательстве");
        case 30: return JML(@"В пути");
        case 31: return [code isEqual:@"0icqmood76"] ? JML(@"Влюблён") : JML(@"Любовь");
        case 34: return JML(@"Ищу");
        case 35: return JML(@"Дневник");
        default: return JML(@"Без X-статуса");
    }
}
static NSImage *JMMoodImage(NSString *code) {
    NSInteger frame=JMMoodFrame(code);
    if (frame<0) return nil;
    static NSMutableDictionary *icons;
    static NSImage *strip;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        icons=[NSMutableDictionary dictionary];
        NSString *path=[[NSBundle mainBundle] pathForResource:@"XStatus" ofType:@"png" inDirectory:@"Retro"];
        if (!path) {
            NSString *resources=[[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
            path=[resources stringByAppendingPathComponent:@"Resources/Retro/XStatus.png"];
        }
        strip=[[NSImage alloc] initWithContentsOfFile:path];
    });
    if (!strip) return nil;
    NSNumber *key=@(frame);
    if (!icons[key]) {
        NSRect bounds=NSMakeRect(0,0,16,16);
        NSImage *image=[[NSImage alloc] initWithSize:bounds.size];
        [image lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
        [strip drawInRect:bounds fromRect:NSMakeRect(frame*16,0,16,16) operation:NSCompositeCopy fraction:1];
        [image unlockFocus];
        icons[key]=image;
    }
    return icons[key];
}

static NSArray *JMMoodNumbers(void) {
    return @[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10,@11,@12,@13,@14,@81,@16,@17,@18,@19,
             @20,@21,@22,@23,@66,@15,@71,@70,@68,@77,@83,@61,@76,@85,@84];
}
