#import <Cocoa/Cocoa.h>
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) return 2;
        NSImage *source = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (!source) return 1;
        NSString *directory = [NSString stringWithUTF8String:argv[2]];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        for (NSNumber *sizeValue in @[@16,@32,@64,@128,@256,@512,@1024]) {
            NSInteger size = [sizeValue integerValue];
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size pixelsHigh:size
                bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
            [[NSColor clearColor] setFill]; NSRectFill(NSMakeRect(0,0,size,size));
            [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
            NSSize original = [source size]; CGFloat scale = (size * 0.90) / MAX(original.width, original.height);
            NSSize target = NSMakeSize(original.width * scale, original.height * scale);
            [source drawInRect:NSMakeRect((size-target.width)/2,(size-target.height)/2,target.width,target.height)
                fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
            [NSGraphicsContext restoreGraphicsState];
            NSData *data = [bitmap representationUsingType:NSPNGFileType properties:@{}];
            NSArray *names = nil;
            switch (size) {
                case 16: names=@[@"icon_16x16.png"]; break;
                case 32: names=@[@"icon_16x16@2x.png",@"icon_32x32.png"]; break;
                case 64: names=@[@"icon_32x32@2x.png"]; break;
                case 128: names=@[@"icon_128x128.png"]; break;
                case 256: names=@[@"icon_128x128@2x.png",@"icon_256x256.png"]; break;
                case 512: names=@[@"icon_256x256@2x.png",@"icon_512x512.png"]; break;
                default: names=@[@"icon_512x512@2x.png"]; break;
            }
            for (NSString *name in names) if (![data writeToFile:[directory stringByAppendingPathComponent:name] atomically:YES]) return 1;
        }
    }
    return 0;
}
