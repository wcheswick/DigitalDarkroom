//
//  Frame.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/6/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Frame.h"

@implementation Frame

@synthesize pixBuf, depthBuf;
@synthesize creationTime;
@synthesize writeLockCount;

- (id)init {
    self = [super init];
    if (self) {
        depthBuf = nil;
        pixBuf = nil;
        creationTime = [NSDate now];
        writeLockCount = 0;
    }
    return self;
}

- (void) readImageFromPath:(NSString *) path {
//    UIImage *image = [UIImage imageNamed:path];
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
    if (pixBuf)
        copy.pixBuf = [pixBuf copy];
    else
        copy.pixBuf = nil;
    if (depthBuf)
        copy.depthBuf = [depthBuf copy];
    else
        copy.depthBuf = nil;
    copy.writeLockCount = 0;
    return copy;
}

- (void) save {
    
}

@end
