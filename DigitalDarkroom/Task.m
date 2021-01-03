//
//  Task.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/16/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "Task.h"
#import "ChBuf.h"

//static int W, H;   // local size values, easy for C routines

#define RPI(x,y)    (PixelIndex_t)(((y)*pixelsPerRow) + (x))

#ifdef DEBUG_TRANSFORMS
// Some of our transforms might be a little buggy around the edges.  Make sure
// all the indicies are in range.

#define PI(x,y)   dPI((int)(x),(int)(y))   // pixel index in a buffer

static PixelIndex_t dPI(int x, int y) {
    assert(x >= 0);
    assert(x < W);
    assert(y >= 0);
    assert(y < H);
    PixelIndex_t index = RPI(x,y);
    assert(index >= 0 && index < pixelsInImage);
    return index;
}

#else
#define PI(x,y)   RPI((x),(y))
#endif

@interface Task ()

@property (strong, nonatomic)   NSMutableArray *paramList;         // settings per transform step
@property (nonatomic, strong)   ChBuf *sChan, *dChan;
@property (nonatomic, strong)   PixBuf *imBuf0, *imBuf1;
@property (nonatomic, strong)   NSMutableArray *imBufs;

@end

@implementation Task

@synthesize transformList;
@synthesize paramList;
@synthesize targetImageView;
@synthesize sChan, dChan;
@synthesize imBufs;
@synthesize imBuf0, imBuf1;
@synthesize taskGroup;
@synthesize taskIndex;
@synthesize taskStatus;
@synthesize enabled;

- (id)initInGroup:(TaskGroup *) tg {
    self = [super init];
    if (self) {
        taskGroup = tg;
        taskIndex = UNASSIGNED_TASK;
        transformList = [[NSMutableArray alloc] init];
        paramList = [[NSMutableArray alloc] init];
        enabled = YES;
        taskStatus = Stopped;
        targetImageView = nil;
        sChan = dChan = nil;
        imBuf0 = imBuf1 = nil;
        imBufs = [[NSMutableArray alloc] initWithCapacity:2];
    }
    return self;
}

- (void) appendTransform:(Transform *) transform {
    if (taskGroup.taskCtrl.layoutNeeded)
        return; // nope, busy
    [transformList addObject:transform];
    Params *params = [[Params alloc] init];
    [paramList addObject:params];
    if (transform.hasParameters)
        params.value = transform.value;
    [self computeRemapForTransformAtIndex:transformList.count - 1];
}

- (void) removeLastTransform {
    [transformList removeLastObject];
}

- (void) removeAllTransforms {
    [transformList removeAllObjects];
}

- (void) configureForSize:(CGSize) s {
    assert(taskStatus == Stopped);
    imBuf0 = [[PixBuf alloc] initWithWidth:s.width height:s.height];
    imBuf1 = [[PixBuf alloc] initWithWidth:s.width height:s.height];
    assert(imBuf0);
    assert(imBuf1);
    imBufs[0] = imBuf0;
    imBufs[1] = imBuf1;

    for (int i=0; i<transformList.count; i++) {
        [self computeRemapForTransformAtIndex:i];
    }
    
    // XXXX chbufs
}

- (void) computeRemapForTransformAtIndex:(size_t) index {
    Transform *transform = transformList[index];
    if (!transform.remapImageF)
        return;
    assert(taskStatus == Stopped);
    Params *params = paramList[index];
    params.remapBuf = [taskGroup remapForTransform:transform params:params];
}

- (void) executeTransformsWithPixBuf:(const PixBuf *) srcBuf {
    assert(taskStatus == Ready);
    if (!enabled)   // not onscreen
        return;
    taskStatus = Running;
    assert(imBuf0); // buffers allocated
    
    // We need to make our own task-specific copy of the source image.
    
    size_t sourceIndex = 0;
    size_t destIndex;
    
#define W   srcBuf.w
#define H   srcBuf.h

    // leave our source pixels untouched for others to use.
    // the destination already has the pixel array pointers set up
    // for the destination buffer.
    
    [srcBuf copyPixelsTo:(PixBuf *)imBufs[sourceIndex]];

    NSDate *startTime = [NSDate now];
    for (int i=0; i<transformList.count; i++) {
        if (taskGroup.taskCtrl.layoutNeeded) {  // abort our processing
            taskStatus = Stopped;
            return;
        }
        Transform *transform = transformList[i];
        Params *params = paramList[i];
        destIndex = [self performTransform:transform
                                    params:params
                               source:sourceIndex];
        assert(destIndex == 0 || destIndex == 1);
        sourceIndex = 1 - destIndex;
        NSDate *transformEnd = [NSDate now];
        params.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:startTime];
        startTime = transformEnd;
    }

    // Our PixBuf imBufs[sourceIndex] contains our pixels.  Update the targetImage
    
    PixBuf *outBuf = imBufs[sourceIndex];
    [outBuf verify];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = sizeof(Pixel);
    NSUInteger bytesPerRow = bytesPerPixel * W;
    NSUInteger bitsPerComponent = 8*sizeof(channel);
    CGContextRef context = CGBitmapContextCreate(outBuf.pb, outBuf.w, outBuf.h,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 BITMAP_OPTS);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    UIImage *transformed = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation:taskGroup.imageOrientation];
    CGImageRelease(quartzImage);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->targetImageView.image = transformed;
        [self->targetImageView setNeedsDisplay];
        self->taskStatus = Ready;
     });
}

- (size_t) performTransform:(Transform *)transform
                     params:(Params *)params
                     source:(size_t)sourceIndex {
    size_t destIndex = 1 - sourceIndex;
    PixBuf *src = imBufs[sourceIndex];
    PixBuf *dst = imBufs[destIndex];        // we may not use this: transform may be in place
    
    switch (transform.type) {
        case ColorTrans:
            transform.ipPointF(src.pb, src.w*src.h);
            return sourceIndex;     // was done in place
        case AreaTrans:
            transform.areaF(src.pa, dst.pa, src.w, src.h, params);
            break;
        case DepthVis:
            /// should not be reached
            break;
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
        case GeometricTrans:
        case RemapTrans:
            assert(transform.remapImageF);
            assert(params.remapBuf);
            [self remapFrom:src.pb to:dst.pb using:params.remapBuf];
    }
    return destIndex;
}

- (void) remapFrom:(Pixel *)src to:(Pixel *)dest using:(RemapBuf *)remapBuf {
}

@end
