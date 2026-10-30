#import <Cocoa/Cocoa.h>
// Read the app icon through Icon Services, not directly through the ICNS decoder.
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc!=3) return 2;
        [NSApplication sharedApplication];
        NSString *app=[NSString stringWithUTF8String:argv[1]], *output=[NSString stringWithUTF8String:argv[2]];
        NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:app];
        BOOL valid=YES;
        for (NSNumber *number in @[@16,@32]) {
            NSInteger size=number.integerValue;
            NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size pixelsHigh:size bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
            [[NSColor clearColor] setFill]; NSRectFill(NSMakeRect(0,0,size,size));
            [icon drawInRect:NSMakeRect(0,0,size,size) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1]; [NSGraphicsContext restoreGraphicsState];
            NSUInteger green=0;
            for (NSInteger y=0;y<size;y++) for (NSInteger x=0;x<size;x++) {
                NSColor *color=[[bitmap colorAtX:x y:y] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
                if (color.alphaComponent>0.5 && color.greenComponent>0.3 && color.greenComponent>color.redComponent*1.4 && color.greenComponent>color.blueComponent*1.4) green++;
            }
            valid=valid && green>5; printf("Icon Services %ld px: %lu green pixels\n",(long)size,(unsigned long)green);
            NSString *path=[output stringByAppendingFormat:@"-%ld.png",(long)size];
            [[bitmap representationUsingType:NSPNGFileType properties:@{}] writeToFile:path atomically:YES];
        }
        return valid ? 0 : 1;
    }
}
