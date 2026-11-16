#import "JMWebP.h"
#import "src/webp/decode.h"
#import <ImageIO/ImageIO.h>

static void JMReleaseWebPPixels(void *info, const void *bytes, size_t size) {
    WebPFree((void *)bytes);
}

CGImageRef JMCreateWebPPreview(NSData *data, int maximumSize) {
    WebPDecoderConfig config;
    if (maximumSize<1 || !WebPInitDecoderConfig(&config) ||
        WebPGetFeatures(data.bytes,data.length,&config.input)!=VP8_STATUS_OK) return NULL;
    int width=config.input.width, height=config.input.height;
    if (width<1 || height<1 || (int64_t)width*height>40000000 || config.input.has_animation) return NULL;
    if (MAX(width,height)>maximumSize) {
        config.options.use_scaling=1;
        config.options.scaled_width=MAX(1,(int)((int64_t)width*maximumSize/MAX(width,height)));
        config.options.scaled_height=MAX(1,(int)((int64_t)height*maximumSize/MAX(width,height)));
    }
    config.output.colorspace=MODE_RGBA;
    if (WebPDecode(data.bytes,data.length,&config)!=VP8_STATUS_OK) {
        WebPFreeDecBuffer(&config.output);
        return NULL;
    }
    WebPRGBABuffer *pixels=&config.output.u.RGBA;
    CGDataProviderRef provider=CGDataProviderCreateWithData(NULL,pixels->rgba,pixels->size,JMReleaseWebPPixels);
    if (!provider) {
        WebPFreeDecBuffer(&config.output);
        return NULL;
    }
    CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
    CGImageRef image=CGImageCreate(config.output.width,config.output.height,8,32,pixels->stride,color,
        kCGImageAlphaLast|kCGBitmapByteOrder32Big,provider,NULL,true,kCGRenderingIntentDefault);
    CGColorSpaceRelease(color);
    CGDataProviderRelease(provider);
    return image;
}

CGImageRef JMCreateAttachmentPreview(NSData *data, NSString *type) {
    if (!data.length) return NULL;
    if ([type isEqual:@"image/webp"]) return JMCreateWebPPreview(data,480);
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
    if (!source) return NULL;
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    double width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue];
    double height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
    CGImageRef preview=NULL;
    if (width>0 && height>0 && width*height<=40000000) {
        NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
                                (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
                                (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@480};
        preview=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)options);
    }
    CFRelease(source);
    return preview;
}
