#import "JMLocalization.h"
#import "JMAvatarStore.h"
#import "JMProtocol.h"
#import "JMHTTPClient.h"
#import <ImageIO/ImageIO.h>
static const NSUInteger JMAvatarByteLimit = 1024 * 1024;
NSData *JMPrepareAvatar(NSData *data, NSError **error) {
    NSString *failure=JML(@"Не удалось прочитать фотографию. Выберите JPEG, PNG или GIF до 20 МБ.");
    CGImageSourceRef source=data.length && data.length<=20*1024*1024 ? CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL) : NULL;
    CGImageRef thumbnail=NULL;
    if (source) {
        NSString *type=(__bridge NSString *)CGImageSourceGetType(source);
        NSDictionary *p=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
        double w=[p[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue], h=[p[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
        if (type && [@[@"public.jpeg",@"public.png",@"com.compuserve.gif"] containsObject:type] && w>=2 && h>=2 && w<=20000 && h<=20000 && w*h<=100000000) {
            thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)@{
                (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
                (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
                (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@512});
        }
        CFRelease(source);
    }
    if (thumbnail) {
        size_t w=CGImageGetWidth(thumbnail), h=CGImageGetHeight(thumbnail), side=MIN((size_t)256,MIN(w,h));
        CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
        CGContextRef context=side>=2 ? CGBitmapContextCreate(NULL,side,side,8,side*4,space,kCGImageAlphaNoneSkipLast|kCGBitmapByteOrder32Big) : NULL;
        CGColorSpaceRelease(space);
        if (context) {
            CGContextSetRGBFillColor(context,1,1,1,1); CGContextFillRect(context,CGRectMake(0,0,side,side));
            CGContextSetInterpolationQuality(context,kCGInterpolationHigh);
            CGFloat scale=(CGFloat)side/MIN(w,h);
            CGContextDrawImage(context,CGRectMake((side-w*scale)/2,(side-h*scale)/2,w*scale,h*scale),thumbnail);
            CGImageRef square=CGBitmapContextCreateImage(context); CGContextRelease(context);
            NSBitmapImageRep *rep=square ? [[NSBitmapImageRep alloc] initWithCGImage:square] : nil;
            if (square) CGImageRelease(square);
            CGImageRelease(thumbnail);
            for (NSNumber *quality in @[@0.85,@0.65,@0.45,@0.25]) {
                NSData *jpeg=[rep representationUsingType:NSJPEGFileType properties:@{NSImageCompressionFactor:quality}];
                if (jpeg.length && jpeg.length<=65536) return jpeg;
            }
            failure=JML(@"Не удалось уменьшить фотографию до 64 КБ. Выберите другую картинку.");
        } else CGImageRelease(thumbnail);
    }
    if (error) *error=[NSError errorWithDomain:JMAPIErrorDomain code:462 userInfo:@{NSLocalizedDescriptionKey:failure}];
    return nil;
}
NSImage *JMDecodeAvatar(NSData *data) {
    if (!data.length || data.length>JMAvatarByteLimit) return nil;
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL); if (!source) return nil;
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL)); CFRelease(source);
    NSInteger width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] integerValue];
    NSInteger height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] integerValue];
    if (width<2 || height<2 || width>2048 || height>2048) return nil;
    NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:data]; if (!rep) return nil;
    // Some accounts have a fully transparent GIF instead of an actual avatar.
    // Keep the visible system placeholder rather than displaying an empty square.
    size_t count=(size_t)width*(size_t)height;
    unsigned char *pixels=calloc(count,4); if (!pixels) return nil;
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels,width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    BOOL visible=NO;
    if (context) {
        CGContextDrawImage(context,CGRectMake(0,0,width,height),[rep CGImage]);
        for (size_t i=0;i<count;i++) if (pixels[i*4+3]) { visible=YES; break; }
        CGContextRelease(context);
    }
    free(pixels); if (!visible) return nil;
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(width,height)]; [image addRepresentation:rep]; return image;
}
@interface JMAvatarStore ()
@property(nonatomic, strong) JMHTTPClient *network;
@property(nonatomic, strong) NSCache *images;
@property(nonatomic, strong) NSMutableDictionary *pending;
@property(nonatomic, strong) NSMutableDictionary *retryAfter;
@property(nonatomic, strong) NSURL *cacheDirectory;
@end
@implementation JMAvatarStore
- (id)init {
    self=[super init]; if (!self) return nil;
    self.images=[[NSCache alloc] init]; self.images.countLimit=64; self.images.totalCostLimit=16*1024*1024;
    self.pending=[NSMutableDictionary dictionary]; self.retryAfter=[NSMutableDictionary dictionary];
    self.network=[[JMHTTPClient alloc] initWithProtocolClasses:nil legacy:NO];
    self.network.maximumResponseBytes=JMAvatarByteLimit; self.network.resourceTimeout=20; self.network.allowsSameOriginRedirects=YES;
    self.network.responseValidator=^BOOL(NSURLResponse *response) {
        return [response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode]==200 && [response.MIMEType hasPrefix:@"image/"];
    };
    NSURL *root=[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    self.cacheDirectory=[root URLByAppendingPathComponent:@"JimmMac/Avatars" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.cacheDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
    return self;
}
- (NSImage *)decode:(NSData *)data {
    return JMDecodeAvatar(data);
}
- (NSImage *)imageForUIN:(NSString *)uin {
    if (!JMValidUIN(uin)) return nil;
    NSImage *image=[self.images objectForKey:uin]; if (image) return image;
    NSURL *file=[self.cacheDirectory URLByAppendingPathComponent:[uin stringByAppendingString:@".image"]];
    NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:NULL];
    if ([attributes[NSFileSize] unsignedLongLongValue]<=JMAvatarByteLimit && (!self.network || [attributes[NSFileModificationDate] timeIntervalSinceNow]>-86400)) {
        image=[self decode:[NSData dataWithContentsOfURL:file]];
        if (image) { [self.images setObject:image forKey:uin cost:(NSUInteger)(image.size.width*image.size.height*4)]; return image; }
    }
    if (!self.network || self.pending[uin] || [self.retryAfter[uin] timeIntervalSinceNow]>0) return nil;
    NSString *url=[@"https://jimm.online/webapi/expressions/get?" stringByAppendingString:JMFormEncode(@{@"t":uin,@"type":@"buddyIcon"})];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    [request setValue:@"image/*" forHTTPHeaderField:@"Accept"]; [request setValue:@"no-store" forHTTPHeaderField:@"Cache-Control"];
    __weak JMAvatarStore *weakSelf=self;
    __block __weak JMHTTPTask *weakTask;
    JMHTTPTask *task=[self.network dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        [weakSelf completeDownloadForUIN:uin task:weakTask data:data error:error];
    }];
    weakTask=task; self.pending[uin]=task; [task resume]; return nil;
}
- (void)cancelDownloadForUIN:(NSString *)uin {
    JMHTTPTask *task=self.pending[uin];
    if (!task) return;
    [self.pending removeObjectForKey:uin]; [task cancel];
}

- (void)refreshUIN:(NSString *)uin {
    if (!JMValidUIN(uin)) return;
    [self cancelDownloadForUIN:uin];
    [self.images removeObjectForKey:uin]; [self.retryAfter removeObjectForKey:uin];
    NSURL *file=[self.cacheDirectory URLByAppendingPathComponent:[uin stringByAppendingString:@".image"]];
    [[NSFileManager defaultManager] removeItemAtURL:file error:NULL];
    [self imageForUIN:uin];
}
- (void)storeUploadedAvatar:(NSData *)data forUIN:(NSString *)uin {
    NSImage *image=JMDecodeAvatar(data); if (!image || !JMValidUIN(uin) || !self.network) return;
    // An older in-flight download must not overwrite a newly accepted upload.
    [self cancelDownloadForUIN:uin]; [self.retryAfter removeObjectForKey:uin];
    [self.images setObject:image forKey:uin cost:(NSUInteger)(image.size.width*image.size.height*4)];
    NSURL *file=[self.cacheDirectory URLByAppendingPathComponent:[uin stringByAppendingString:@".image"]];
    if ([data writeToURL:file options:NSDataWritingAtomic error:NULL]) [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:file.path error:NULL];
    [self.delegate avatarStore:self updatedUIN:uin];
}
- (void)completeDownloadForUIN:(NSString *)uin task:(JMHTTPTask *)task data:(NSData *)data error:(NSError *)error {
    if (!JMValidUIN(uin) || self.pending[uin]!=task || !task) return;
    [self.pending removeObjectForKey:uin]; if (!self.network) return;
    NSImage *image=error ? nil : [self decode:data];
    if (image) {
        [self.images setObject:image forKey:uin cost:(NSUInteger)(image.size.width*image.size.height*4)];
        NSURL *file=[self.cacheDirectory URLByAppendingPathComponent:[uin stringByAppendingString:@".image"]];
        if ([data writeToURL:file options:NSDataWritingAtomic error:NULL]) [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:file.path error:NULL];
    } else self.retryAfter[uin]=[NSDate dateWithTimeIntervalSinceNow:300];
    [self.delegate avatarStore:self updatedUIN:uin];
}
- (unsigned long long)cacheBytes {
    unsigned long long bytes=0;
    for (NSURL *file in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.cacheDirectory includingPropertiesForKeys:nil options:0 error:NULL]) {
        if (![file.pathExtension isEqual:@"image"] || !JMValidUIN(file.lastPathComponent.stringByDeletingPathExtension)) continue;
        NSDictionary *attrs=[[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:NULL]; if ([attrs[NSFileType] isEqual:NSFileTypeRegular]) bytes+=[attrs[NSFileSize] unsignedLongLongValue];
    } return bytes;
}
- (BOOL)clearCache:(NSError **)error {
    NSArray *tasks=self.pending.allValues; [self.pending removeAllObjects]; for (JMHTTPTask *task in tasks) [task cancel];
    [self.images removeAllObjects]; [self.retryAfter removeAllObjects];
    NSArray *files=[[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.cacheDirectory includingPropertiesForKeys:nil options:0 error:error]; if (!files) return NO;
    for (NSURL *file in files) {
        if (![file.pathExtension isEqual:@"image"] || !JMValidUIN(file.lastPathComponent.stringByDeletingPathExtension)) continue;
        NSDictionary *attrs=[[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:NULL];
        if (![attrs[NSFileType] isEqual:NSFileTypeRegular]) continue;
        if (![[NSFileManager defaultManager] removeItemAtURL:file error:error]) return NO;
    } return YES;
}
- (void)invalidate { [self.network invalidateAndCancel]; self.network=nil; self.delegate=nil; [self.pending removeAllObjects]; }
@end
