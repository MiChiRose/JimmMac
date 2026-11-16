#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

CGImageRef JMCreateWebPPreview(NSData *data, int maximumSize) CF_RETURNS_RETAINED;
CGImageRef JMCreateAttachmentPreview(NSData *data, NSString *type) CF_RETURNS_RETAINED;
