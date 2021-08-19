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

@property (nonatomic, strong)   ChBuf *chBuf0, *chBuf1;
@property (nonatomic, strong)   PixBuf *imBuf0, *imBuf1;
@property (nonatomic, strong)   NSMutableArray *imBufs;

@end

@implementation Task

@synthesize taskName;
@synthesize transformList;
@synthesize depthTransform, depthInstance;
@synthesize thumbTransform, thumbInstance;
@synthesize paramList;
@synthesize targetImageView;
@synthesize chBuf0, chBuf1;
@synthesize imBufs;
@synthesize imBuf0, imBuf1;
@synthesize taskGroup;
@synthesize taskIndex;
@synthesize taskStatus;
@synthesize enabled;

- (id)initTaskNamed:(NSString *) n inGroup:(TaskGroup *)tg {
    self = [super init];
    if (self) {
        taskName = n;
        taskGroup = tg;
        taskIndex = UNASSIGNED_TASK;
        // create list, with empty depth transform
        transformList = [[NSMutableArray alloc] init];
        depthTransform = nil;
        depthInstance = nil;
        thumbTransform = nil;   // instead of the list
        thumbInstance = nil;
        paramList = [[NSMutableArray alloc] init];
        
        enabled = YES;
        taskStatus = Stopped;
        targetImageView = nil;
        chBuf0 = chBuf1 = nil;
        imBuf0 = imBuf1 = nil;
        imBufs = [[NSMutableArray alloc] initWithCapacity:2];
        assert(imBufs);
    }
    return self;
}

- (void) enable {
    //assert(taskStatus == Stopped);
    taskStatus = Idle;
}

- (Transform *) lastTransform {
    if (transformList.count > 0)
        return [transformList lastObject];
    return nil;
}

- (void) useDepthTransform:(Transform *__nullable) transform {
    depthTransform = transform;
    if (!depthTransform) {
        depthInstance = nil;
    } else {
        depthInstance = [[TransformInstance alloc]
                                       initFromTransform:(Transform *)transform];
    }
//    NSLog(@" task '%@' using depth transform '%@'", taskName, depthTransform.name);
}

- (long) appendTransformToTask:(Transform *) transform {
    [transformList addObject:transform];
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    [paramList addObject:instance];
    long newIndex = transformList.count - 1;
    return newIndex;
}

- (long) removeLastTransform {
    long step = transformList.count - 1;
    if (step >= 0) {
        [transformList removeLastObject];
        [paramList removeLastObject];
    }
    return step;
}

- (void) removeAllTransforms {
    [transformList removeAllObjects];
    [paramList removeAllObjects];
}

- (NSString *) infoForScreenTransformAtIndex:(long) index {
    assert(index < transformList.count);
    assert(index < paramList.count);
    Transform *transform = [transformList objectAtIndex:index];
    TransformInstance *instance = [paramList objectAtIndex:index];
    return [NSString stringWithFormat:@"%@;%@;%@",
            transform.name,
            [instance valueInfo], [instance timeInfo]];
}

- (void) configureTaskForSize {
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@"   TTT %@  configureTaskForSize: %.0f x %.0f", taskName,
          taskGroup.transformSize.width, taskGroup.transformSize.height);
#endif
// maybe ok    assert(taskStatus == Stopped);
    imBuf0 = [[PixBuf alloc] initWithSize:taskGroup.transformSize];
    imBuf1 = [[PixBuf alloc] initWithSize:taskGroup.transformSize];
    assert(imBuf0);
    assert(imBuf1);
    imBufs[0] = imBuf0;
    imBufs[1] = imBuf1;
    
    chBuf0 = [[ChBuf alloc] initWithSize:taskGroup.transformSize];
    chBuf1 = [[ChBuf alloc] initWithSize:taskGroup.transformSize];
    assert(chBuf0);
    assert(chBuf1);
    
    if (thumbTransform) {
        [self configureTransform:thumbTransform andInstance:thumbInstance];
    } else {
        if (depthTransform)
            [self configureTransform:depthTransform andInstance:depthInstance];
        
        for (int i=0; i<transformList.count; i++) {
            [self configureTransformAtIndex:i];
        }
    }
}

// step -1 is the depth step
- (int) valueForStep:(long) step {
    if (step < 0)
        return depthInstance.value;
    TransformInstance *instance = paramList[step];
    return instance.value;
}

- (long) lastStep {
    return paramList.count - 1;
}

- (BOOL) updateParamOfLastTransformTo:(int) newParam {
    long index = paramList.count - 1;
    Transform *lastTransform = transformList[index];
    if (lastTransform.type == NullTrans)
        return NO;
    TransformInstance *lastInstance = paramList[index];
    if (lastInstance.value == newParam)
        return NO;
    if (newParam > lastTransform.high || newParam < lastTransform.low)
        return NO;
    lastInstance.value = newParam;
    [self configureTransformAtIndex:index];
    return YES;
}

- (void) configureTransformAtIndex:(size_t)index {
    Transform *transform = transformList[index];
    TransformInstance *instance = paramList[index];
    [self configureTransform:transform andInstance:instance];
}

- (void) configureTransform:(Transform *) transform
                           andInstance:(TransformInstance *) instance {
    CGSize s = taskGroup.transformSize;
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@"    TT %-15@   configureTransform  %zu size %.0f x %.0f", taskName, index, s.width, s.height);
#endif
// maybe ok    assert(taskStatus == Stopped);
    assert(s.width > 0 && s.height > 0);
    
    switch (transform.type) {
        case RemapTrans:
        case RemapPolarTrans:
            instance.remapBuf = [taskGroup remapForTransform:transform instance:instance];
            //    assert(taskStatus == Stopped);
#ifdef DEBUG_TASK_CONFIGURATION
            NSLog(@"    TT  %-15@   %2zu remap size %.0f x %.0f", taskName, index, s.width, s.height);
#endif
            break;
        default:
            ;
    }
}

- (void) removeTransformAtIndex:(long) index {
    assert(index < transformList.count);
    [transformList removeObjectAtIndex:index];
    [paramList removeObjectAtIndex:index];
}

// run the srcBuf image through the transforms. We need to make our own
// task-specific copy of the source image, because other tasks need a clean
// source.

- (void) executeTransformsFromPixBuf:(const PixBuf *) srcBuf
                               depth:(const DepthBuf *)depthBuf {
    if (taskStatus == Stopped || !enabled)
        return;     // not now
    if (taskGroup.taskCtrl.reconfigurationNeeded) {
        taskStatus = Stopped;
        return;
    }
    taskStatus = Running;
    
    // we copy the pixels into the correctly-sized, previously-created imBuf0,
    // which is also imBufs[0]
    UIImage *finalImage;
    [srcBuf copyPixelsTo:imBuf0];

    if (thumbTransform) {   // just one transform, for the thumbnail
        assert(thumbInstance);
        if (!thumbTransform.broken) {
            if (thumbTransform.type == DepthVis) {  // depth thumbnail
                thumbTransform.depthVisF(depthBuf, imBuf0, thumbInstance);
                finalImage = [self pixbufToImage:imBuf0];
            } else {
                [srcBuf copyPixelsTo:imBuf0];
                size_t destIndex = [self performTransform:thumbTransform
                                              instance:thumbInstance
                                                source:0];
                finalImage = [self pixbufToImage:imBufs[destIndex]];
            }
            [self updateTargetWith:finalImage];
            taskStatus = Idle;
        }
        taskStatus = Idle;
        return;
    }

    // for non-thumbnail visualizations, we apply the depth transform, if any, plus
    // each of the selected transforms.

    assert(taskStatus == Running);

    if (transformList.count == 0 && !depthTransform) { // just display the input
        UIImage *unmodifiedSourceImage = [self pixbufToImage:imBufs[0]];
        [self updateTargetWith:unmodifiedSourceImage];
        return;
    }
    
    NSDate *startTime = [NSDate now];
    if (depthTransform) {   // do the depth first, if there is one
        depthTransform.depthVisF(depthBuf, imBuf0, depthInstance);
    }
    size_t sourceIndex = 0; // imBuf0, where the input is
    size_t destIndex;
    
    for (int i=0; i<transformList.count; i++) {
        if (taskGroup.taskCtrl.reconfigurationNeeded) {  // abort our processing
            taskStatus = Stopped;
            return;
        }
        Transform *transform;
        TransformInstance *instance;
        transform = transformList[i];
        instance = paramList[i];
        destIndex = [self performTransform:transform
                                  instance:instance
                                    source:sourceIndex];
        assert(destIndex == 0 || destIndex == 1);
        sourceIndex = destIndex;
        NSDate *transformEnd = [NSDate now];
        instance.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:startTime];
        instance.timesCalled++;
        startTime = transformEnd;
    }
    
    // Our PixBuf imBufs[sourceIndex] contains our pixels.  Update the targetImage
    finalImage = [self pixbufToImage:imBufs[sourceIndex]];
    [self updateTargetWith:finalImage];
    taskStatus = Idle;
}

- (UIImage *) pixbufToImage:(const PixBuf *) pixBuf {
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

    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation:UIImageOrientationUp];
    CGImageRelease(quartzImage);
    return image;
}

- (void) updateTargetWith:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->targetImageView.image = image;
        [self->targetImageView setNeedsDisplay];
        self->taskStatus = Idle;
     });
}

- (size_t) performTransform:(Transform *)transform
                     instance:(TransformInstance *)instance
                     source:(size_t)sourceIndex {
    size_t destIndex = 1 - sourceIndex;
    PixBuf *src = imBufs[sourceIndex];
    PixBuf *dst = imBufs[destIndex];        // we may not use this: transform may be in place
    
    switch (transform.type) {
        case NullTrans:
            assert(NO); // should never try a null, it is a placeholder for inactive stuff
        case ColorTrans:
            transform.ipPointF(src.pb, src.w*src.h, instance.value);
            return sourceIndex;     // was done in place
        case AreaTrans:
            transform.areaF(src, dst, chBuf0, chBuf1, instance);
            break;
        case DepthVis:
            assert(0);  // no depths here, please
            break;
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
        case GeometricTrans:
        case RemapPolarTrans:
        case RemapTrans: {
            assert(instance);
            assert(instance.remapBuf);
 //           [instance.remapBuf verify];
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
                    case Remap_OutOfRange:
                        p = Magenta;
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

@end
