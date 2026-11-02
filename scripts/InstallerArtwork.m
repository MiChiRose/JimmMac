#import <Cocoa/Cocoa.h>
static NSColor *RGB(CGFloat r, CGFloat g, CGFloat b) { return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1]; }
static void Text(NSString *text, NSRect rect, CGFloat size, BOOL bold, NSColor *color) {
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.lineBreakMode=NSLineBreakByWordWrapping;
    [text drawInRect:rect withAttributes:@{NSFontAttributeName:([NSFont fontWithName:bold ? @"LucidaGrande-Bold" : @"LucidaGrande" size:size] ?: (bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size])),NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:style}];
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc!=4) return 2;
        CGFloat scale=atof(argv[3]);
        NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:640*scale pixelsHigh:440*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        bitmap.size=NSMakeSize(640,440);
        NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        [NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:context.graphicsPort flipped:YES]];
        NSAffineTransform *flip=[NSAffineTransform transform]; [flip translateXBy:0 yBy:440*scale]; [flip scaleXBy:scale yBy:-scale]; [flip concat];
        [[[NSGradient alloc] initWithStartingColor:RGB(.98,.99,.97) endingColor:RGB(.79,.85,.78)] drawInRect:NSMakeRect(0,0,640,440) angle:90];
        NSBezierPath *panel=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(18,18,604,404) xRadius:12 yRadius:12];
        [RGB(.95,.97,.93) setFill]; [panel fill]; [RGB(.61,.69,.58) setStroke]; panel.lineWidth=1; [panel stroke];
        NSBezierPath *header=[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(19,19,602,76) xRadius:11 yRadius:11];
        [[[NSGradient alloc] initWithStartingColor:RGB(.91,.96,.86) endingColor:RGB(.71,.83,.59)] drawInBezierPath:header angle:90];
        NSImage *flower=[[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        [flower drawInRect:NSMakeRect(37,32,48,48) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
        Text(@"JimmMac",NSMakeRect(103,29,480,32),25,YES,RGB(.15,.25,.12));
        Text(@"Знакомая аська. Снова на вашем Mac.",NSMakeRect(104,63,470,19),12,NO,RGB(.21,.31,.18));
        Text(@"Установка в одно движение",NSMakeRect(38,115,564,27),18,YES,RGB(.17,.24,.15));
        Text(@"Drag JimmMac to Applications",NSMakeRect(39,146,564,22),12,NO,RGB(.32,.38,.30));
        for (NSNumber *x in @[@160,@480]) {
            NSBezierPath *pad=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x.doubleValue-69,175,138,138)];
            [[[NSGradient alloc] initWithStartingColor:[NSColor whiteColor] endingColor:RGB(.83,.88,.80)] drawInBezierPath:pad angle:90];
            [RGB(.73,.79,.68) setStroke]; [pad stroke];
        }
        [NSGraphicsContext saveGraphicsState]; NSShadow *shadow=[[NSShadow alloc] init]; shadow.shadowOffset=NSMakeSize(0,2); shadow.shadowBlurRadius=3; shadow.shadowColor=[NSColor colorWithCalibratedWhite:0 alpha:.22]; [shadow set];
        NSBezierPath *arrow=[NSBezierPath bezierPath];
        [arrow moveToPoint:NSMakePoint(277,224)]; [arrow lineToPoint:NSMakePoint(325,224)]; [arrow lineToPoint:NSMakePoint(325,209)]; [arrow lineToPoint:NSMakePoint(357,239)]; [arrow lineToPoint:NSMakePoint(325,269)]; [arrow lineToPoint:NSMakePoint(325,254)]; [arrow lineToPoint:NSMakePoint(277,254)]; [arrow closePath];
        [[NSColor whiteColor] setFill]; [arrow fill]; [RGB(.38,.49,.33) setStroke]; arrow.lineWidth=2; [arrow stroke]; [NSGraphicsContext restoreGraphicsState];
        Text(@"Перетащите JimmMac в «Программы»",NSMakeRect(38,338,564,25),16,YES,RGB(.17,.24,.15));
        Text(@"Затем откройте JimmMac из папки «Программы».",NSMakeRect(39,368,564,21),12,NO,RGB(.32,.38,.30));
        Text(@"Intel Mac  •  OS X 10.8 – macOS 10.13",NSMakeRect(39,394,564,18),11,NO,RGB(.32,.38,.30));
        [NSGraphicsContext restoreGraphicsState];
        return [[bitmap representationUsingType:NSPNGFileType properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES] ? 0 : 1;
    }
}
