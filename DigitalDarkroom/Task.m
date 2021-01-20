//
//  Task.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/16/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "TransformInstance.h"
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

@synthesize taskName;
@synthesize transformList;
@synthesize depthTransform;
@synthesize paramList;
@synthesize targetImageView;
@synthesize sChan, dChan;
@synthesize imBufs;
@synthesize imBuf0, imBuf1;
@synthesize taskGroup;
@synthesize taskIndex;
@synthesize taskStatus;
@synthesize enabled;

- (id)initInGroup:(TaskGroup *) tg name:(NSString *) n {
    self = [super init];
    if (self) {
        taskName = n;
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

- (void) configureTaskForSize {
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@"   TTT %@  configureTaskForSize: %.0f x %.0f", taskName,
          taskGroup.transformSize.width, taskGroup.transformSize.height);
#endif
    imBuf0 = [[PixBuf alloc] initWithSize:taskGroup.transformSize];
    imBuf1 = [[PixBuf alloc] initWithSize:taskGroup.transformSize];
    assert(imBuf0);
    assert(imBuf1);
    imBufs[0] = imBuf0;
    imBufs[1] = imBuf1;
    for (int i=0; i<transformList.count; i++) {
        [self configureTransformAtIndex:i];
    }
}

- (void) configureTransformAtIndex:(size_t)ti {
#ifdef DEBUG_TASK_CONFIGURATION
    CGSize s = taskGroup.transformSize;
    NSLog(@"    TT  %-15@   configure for size %zu size %.0f x %.0f", taskName, ti, s.width, s.height);
#endif
//    assert(taskStatus == Stopped);
    [self computeRemapForTransformAtIndex:ti];
}

- (void) computeRemapForTransformAtIndex:(size_t) index {
    Transform *transform = transformList[index];
    if (!transform.remapImageF)
        return;
//    assert(taskStatus == Stopped);
#ifdef DEBUG_TASK_CONFIGURATION
    CGSize s = taskGroup.transformSize;
    NSLog(@"    TT  %-15@   %2zu remap size %.0f x %.0f", taskName, index, s.width, s.height);
#endif
    TransformInstance *instance = paramList[index];
    instance.remapBuf = [taskGroup remapForTransform:transform instance:instance];
}

- (void) appendTransform:(Transform *) transform {
    assert(transform.type != DepthVis);
//    if (taskGroup.taskCtrl.layoutNeeded)
//        return; // nope, busy
    [transformList addObject:transform];
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    [paramList addObject:instance];
    [self configureTransformAtIndex:transformList.count - 1];
}

- (void) removeLastTransform {
    [transformList removeLastObject];
    [paramList removeLastObject];
}

- (void) removeAllTransforms {
    [transformList removeAllObjects];
    [paramList removeAllObjects];
}

// first, apply depth vis on the depthdata, then run it through
// the other transforms. Don't mess with the incoming DepthBuf,

- (void) startTransformsWithDepthBuf:(const DepthBuf *) depthBuf {
    assert(taskStatus == Ready);
    if (!enabled)   // not onscreen
        return;
    taskStatus = Running;
    depthTransform.depthVisF(depthBuf, imBuf0.pb, depthTransform.value);
    [self executeTransformsStartingWithImBuf0];
}

// run the srcBuf image through the transforms. We need to make our own
// task-specific copy of the source image, because other tasks need a clean
// source.

- (void) executeTransformsFromPixBuf:(const PixBuf *) srcBuf {
    assert(taskStatus == Ready);
    if (!enabled)   // not onscreen
        return;
    taskStatus = Running;

    if (transformList.count == 0) { // just display the input
        [self updateTargetWith:srcBuf];
        return;
    }
    
    // we copy the pixels into the correctly-sized, previously-created imBuf0,
    // which is also imBufs[0]
    [srcBuf copyPixelsTo:imBuf0];
    [self executeTransformsStartingWithImBuf0];
}

- (void) executeTransformsStartingWithImBuf0 {
    assert(taskStatus == Running);
    if (transformList.count == 0) { // just display the input
        [self updateTargetWith:imBuf0];
        return;
    }
    
    size_t sourceIndex = 0; // imBuf0, where the input is
    size_t destIndex;

    NSDate *startTime = [NSDate now];
    for (int i=0; i<transformList.count; i++) {
        if (taskGroup.taskCtrl.layoutNeeded) {  // abort our processing
            taskStatus = Stopped;
            return;
        }
        Transform *transform = transformList[i];
        TransformInstance *instance = paramList[i];
        destIndex = [self performTransform:transform
                                    instance:instance
                               source:sourceIndex];
        assert(destIndex == 0 || destIndex == 1);
        sourceIndex = destIndex;
        NSDate *transformEnd = [NSDate now];
        instance.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:startTime];
        startTime = transformEnd;
    }

    // Our PixBuf imBufs[sourceIndex] contains our pixels.  Update the targetImage
    
    PixBuf *outBuf = imBufs[sourceIndex];
#ifdef DEBUG
    [outBuf verify];
#endif
    [self updateTargetWith:outBuf];
}

- (void) updateTargetWith:(const PixBuf *)pixBuf {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = sizeof(Pixel);
    NSUInteger bytesPerRow = bytesPerPixel * pixBuf.w;
    NSUInteger bitsPerComponent = 8*sizeof(channel);
    CGContextRef context = CGBitmapContextCreate(pixBuf.pb, pixBuf.w, pixBuf.h,
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
                     instance:(TransformInstance *)instance
                     source:(size_t)sourceIndex {
    size_t destIndex = 1 - sourceIndex;
    PixBuf *src = imBufs[sourceIndex];
    PixBuf *dst = imBufs[destIndex];        // we may not use this: transform may be in place
    
    switch (transform.type) {
        case ColorTrans:
            transform.ipPointF(src.pb, src.w*src.h, instance.value);
            return sourceIndex;     // was done in place
        case AreaTrans:
            transform.areaF(src.pa, dst.pa, src.w, src.h, instance);
            break;
        case DepthVis:
            assert(0);  // no depths here, please
            break;
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
        case GeometricTrans:
        case RemapTrans: {
            assert(transform.remapImageF);
            assert(instance.remapBuf);
#ifdef DEBUG
            [instance.remapBuf verify];
#endif
            BufferIndex *bip = instance.remapBuf.rb;
            Pixel *dp = dst.pb;
            for (int i=0; i<dst.w*dst.h; i++) {
                Pixel p;
                BufferIndex bi = *bip++;
                switch (bi) {
                    case Remap_White:
                        p = White;
                        break;
                    case Remap_Red:
                        p = Red;
                        break;
                    case Remap_Green:
                        p = Green;
                        break;
                    case Remap_Blue:
                        p = Blue;
                        break;
                    case Remap_Black:
                        p = Black;
                        break;
                    case Remap_Yellow:
                        p = Yellow;
                        break;
                    case Remap_Unset:
                        p = UnsetColor;
                        break;
                    default:
                        assert(bi >= 0 && bi < dst.w*dst.h);
                        p = src.pb[bi];
                }
                *dp++ = p;
            }
        }
    }
    return destIndex;
}


- (Transform *) currentTransform {
    if (transformList.count == 0)
        return nil;
    Transform *t = [transformList objectAtIndex:0]; // only one, for now
    return t;
}

@end
