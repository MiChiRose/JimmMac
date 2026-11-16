- (void)discardAttachmentPreviews {
    [self.attachmentTask cancel];
    self.attachmentTask=nil;
    [self.attachmentSound stop];
    self.attachmentSound=nil;
    self.attachmentURL=nil;
    self.attachmentImage=nil;
    self.attachmentFailure=nil;
    self.attachmentSerial++;
}
- (void)loadAttachment:(NSURL *)url {
    if (!JMJimmAttachmentURL(url) || !self.accountUIN.length) return;
    if ([url isEqual:self.attachmentURL] && self.attachmentTask) return;
    if ([url isEqual:self.attachmentURL] && self.attachmentSound) {
        if (self.attachmentSound.isPlaying) [self.attachmentSound stop];
        else [self.attachmentSound play];
        return;
    }
    if ([url isEqual:self.attachmentURL] && self.attachmentImage) return;
    [self discardAttachmentPreviews];
    self.attachmentURL=url;
    NSUInteger serial=self.attachmentSerial;
    if (!self.attachmentNetwork) {
        self.attachmentNetwork=[[JMHTTPClient alloc] initWithProtocolClasses:nil legacy:NO];
        self.attachmentNetwork.maximumResponseBytes=10*1024*1024;
        self.attachmentNetwork.resourceTimeout=25;
        self.attachmentNetwork.responseValidator=^BOOL(NSURLResponse *response) {
            if (![response isKindOfClass:[NSHTTPURLResponse class]] || [(NSHTTPURLResponse *)response statusCode]!=200) return NO;
            NSString *type=response.MIMEType.lowercaseString;
            return [@[@"image/jpeg",@"image/png",@"image/gif",@"image/webp"] containsObject:type] ||
                [type hasPrefix:@"audio/"] || [type isEqual:@"application/ogg"];
        };
    }
    NSURL *content=[NSURL URLWithString:[url.absoluteString stringByAppendingString:@"/content"]];
    NSURLRequest *request=[NSURLRequest requestWithURL:content cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    __weak JMAppDelegate *weakSelf=self;
    self.attachmentTask=[self.attachmentNetwork dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        NSString *type=response.MIMEType.lowercaseString;
        BOOL image=[type hasPrefix:@"image/"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
            CGImageRef preview=!error && image ? JMCreateAttachmentPreview(data,type) : NULL;
            dispatch_async(dispatch_get_main_queue(),^{
                JMAppDelegate *self=weakSelf;
                if (self && self.attachmentSerial==serial) {
                    self.attachmentTask=nil;
                    if (preview) self.attachmentImage=[[NSImage alloc] initWithCGImage:preview size:NSZeroSize];
                    if (!error && !image && data.length) {
                        self.attachmentSound=[[NSSound alloc] initWithData:data];
                        if (![self.attachmentSound play]) self.attachmentSound=nil;
                    }
                    if (!self.attachmentImage && !self.attachmentSound)
                        self.attachmentFailure=JML(@"Предпросмотр недоступен. Откройте исходную ссылку в браузере.");
                    [self renderTranscript];
                }
                if (preview) CGImageRelease(preview);
            });
        });
    }];
    [self.attachmentTask resume];
    [self renderTranscript];
}
- (void)appendAttachment:(NSURL *)url toMessage:(NSMutableAttributedString *)body {
    BOOL selected=[url isEqual:self.attachmentURL];
    if (selected && self.attachmentImage) {
        NSSize size=self.attachmentImage.size;
        CGFloat scale=MIN(1.0,MIN(260.0/MAX(size.width,1),180.0/MAX(size.height,1)));
        NSSize previewSize=NSMakeSize(floor(size.width*scale),floor(size.height*scale));
        NSImage *preview=[self.attachmentImage copy];
        preview.size=previewSize;
        NSTextAttachment *attachment=[[NSTextAttachment alloc] initWithFileWrapper:nil];
        attachment.attachmentCell=[[NSTextAttachmentCell alloc] initImageCell:preview];
        [body appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        return;
    }
    NSString *label=JML(@"Открыть вложение в чате");
    if (selected && self.attachmentTask) label=JML(@"Загружаем вложение…");
    else if (selected && self.attachmentSound) label=JML(@"Воспроизвести или остановить");
    else if (selected && self.attachmentFailure) label=self.attachmentFailure;
    NSMutableDictionary *attributes=[@{NSFontAttributeName:[NSFont systemFontOfSize:12],NSForegroundColorAttributeName:JMSecondaryTextColor()} mutableCopy];
    if (!(selected && (self.attachmentTask || self.attachmentFailure))) {
        attributes[NSLinkAttributeName]=[NSURL URLWithString:@"jimmmac-action:attachment"];
        attributes[@"JMAttachmentURL"]=url;
    }
    [body appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:attributes]];
}
