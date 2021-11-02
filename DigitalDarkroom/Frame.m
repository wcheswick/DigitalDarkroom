//
//  Frame.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/6/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Frame.h"

@implementation Frame

@synthesize pixBuf, depthBuf, image;
@synthesize creationTime;
@synthesize useCount;

- (id)init {
    self = [super init];
    if (self) {
#ifdef MEMLEAK_AIDS
        NSLog(@"+ Frame     ");
#endif
        depthBuf = nil;
        pixBuf = nil;
        image = nil;
        creationTime = [NSDate now];
        useCount = 0;
    }
    return self;
}

- (CGSize) size {
#ifdef OLD
    if (image) {
        assert(!pixBuf || SAME_SIZE(pixBuf.size, image.size));
        return image.size;
    }
#endif
    if (pixBuf) {
        assert(pixBuf);
        assert(!SAME_SIZE(pixBuf.size, CGSizeZero));
        return pixBuf.size;
    } else {
        assert(image);
        return image.size;
    }
}

- (void) readImageFromPath:(NSString *) path {
    image = [UIImage imageNamed:path];
    assert(image);
}

- (CGSize) imageSize {
    if (image)
        return image.size;
    else if (pixBuf)
        return pixBuf.size;
    else
        assert(NO); // has to be one of them
}

- (UIImage *) toUIImage {
    // XXX ok to use our buffer?  Does it need locking?
    void *baseAddress = pixBuf.pb;
    size_t bytesPerRow = sizeof(Pixel) * pixBuf.size.width;  // XXX assumes no slop at the end
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, pixBuf.size.width, pixBuf.size.height, 8,
                                                 bytesPerRow, colorSpace, BITMAP_OPTS);
    assert(context);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
//    CVPixelBufferUnlockBaseAddress(videoPixelBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:(CGFloat)1.0
                                   orientation:UIImageOrientationUp];
    CGImageRelease(quartzImage);
    return image;
}

- (void) copyTo:(Frame *) dest {
    assert(dest);
    if (pixBuf)
        [self.pixBuf copyPixelsTo:dest.pixBuf];
    else
        dest.pixBuf = nil;
    if (depthBuf)
        [self.depthBuf copyDepthsTo:dest.depthBuf];
    else
        dest.depthBuf = nil;
}

- (id)copyWithZone:(NSZone *)zone {
    Frame *copy = [[Frame alloc] init];
    copy.creationTime = creationTime;
    copy.useCount = 0;
    if (pixBuf)
        copy.pixBuf = [pixBuf copy];
    else
        copy.pixBuf = nil;
    if (depthBuf)
        copy.depthBuf = [depthBuf copy];
    else
        copy.depthBuf = nil;
    return copy;
}

- (void) scaleFrom:(const Frame *)srcFrame {
    [pixBuf scaleFrom:srcFrame.pixBuf];
    [depthBuf scaleFrom:srcFrame.depthBuf];
}

- (void) save {
    
}

@end
