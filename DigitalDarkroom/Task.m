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

@property (nonatomic, strong)   PixBuf *dstPixBuf;
@property (nonatomic, strong)   ChBuf *chBuf0, *chBuf1;
@property (nonatomic, strong)   Frame *frame0, *frame1;
@property (nonatomic, strong)   NSMutableArray<Frame *> *frames;

@end

@implementation Task

@synthesize taskName;
@synthesize transformList;
@synthesize paramList;
@synthesize targetImageView;
@synthesize dstPixBuf;
@synthesize chBuf0, chBuf1;
@synthesize frames, frame0, frame1;
@synthesize taskGroup;
@synthesize taskIndex;
@synthesize taskStatus;
@synthesize enabled, isThumbTask;

- (id)initTaskNamed:(NSString *) n inGroup:(TaskGroup *)tg {
    self = [super init];
    if (self) {
        taskName = n;
        taskGroup = tg;
        taskIndex = UNASSIGNED_TASK;
        // create list, with empty depth transform
        transformList = [[NSMutableArray alloc] init];
        isThumbTask = NO;
        paramList = [[NSMutableArray alloc] init];
        
        enabled = YES;
        taskStatus = Stopped;
        targetImageView = nil;
        // room for frame0 and frame1:
        frame0 = [[Frame alloc] init];
        assert(!frame0.depthBuf);  // XXXXXXXXX debug
        frame1 = [[Frame alloc] init];
        frames = [[NSMutableArray alloc] initWithObjects:frame0, frame1, nil];
        for (Frame *frame in frames)
            assert(!frame.depthBuf);  // XXXXXXXXX debug
        assert(frames);
    }
    return self;
}

- (void) enable {
    //assert(taskStatus == Stopped);
    taskStatus = Idle;
}

#ifdef OLD
- (void) useDepthTransform:(Transform *__nullable) transform {
    depthTransform = transform;
    if (!depthTransform) {
        depthInstance = nil;
    } else {
        depthInstance = [[TransformInstance alloc]
                                       initFromTransform:(Transform *)transform];
        assert(depthInstance);
    }
//    NSLog(@" task '%@' using depth transform '%@'", taskName, depthTransform.name);
}
#endif

- (long) appendTransformToTask:(Transform *) transform {
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    [transformList addObject:transform];
    [paramList addObject:instance];
    return transformList.count - 1;
}

- (long) removeLastTransform {
    assert(transformList.count > 0);
    [transformList removeLastObject];
    [paramList removeLastObject];
    return transformList.count;
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
    for (Frame *frame in frames) {
        frame.pixBuf = [[PixBuf alloc] initWithSize:taskGroup.targetSize];
        assert(frame.pixBuf);
        frame.depthBuf = [[DepthBuf alloc] initWithSize:taskGroup.targetSize];
        assert(frame.depthBuf);
    }
    
    dstPixBuf = [[PixBuf alloc] initWithSize:taskGroup.targetSize];
    chBuf0 = [[ChBuf alloc] initWithSize:taskGroup.targetSize];
    assert(chBuf0);
    chBuf1 = [[ChBuf alloc] initWithSize:taskGroup.targetSize];
    assert(chBuf1);
    
    for (int i=0; i<transformList.count; i++) {
        [self configureTransformAtIndex:i];
    }
}

// step -1 is the depth step
- (int) valueForStep:(size_t) step {
    TransformInstance *instance = paramList[step];
    return instance.value;
}

- (long) lastStep {
    return paramList.count - 1;
}

- (BOOL) updateParamOfLastTransformTo:(int) newParam {
    Transform *lastTransform = [transformList lastObject];
    assert(lastTransform);
    TransformInstance *lastInstance = [paramList lastObject];
    if (lastInstance.value == newParam)
        return NO;
    if (newParam > lastTransform.high || newParam < lastTransform.low)
        return NO;
    lastInstance.value = newParam;
    [self configureTransformAtIndex:transformList.count - 1];
    return YES;
}

- (void) configureTransformAtIndex:(size_t)index {
    Transform *transform = transformList[index];
    TransformInstance *instance = paramList[index];
    [self configureTransform:transform andInstance:instance];
}

- (void) configureTransform:(Transform *) transform
                           andInstance:(TransformInstance *) instance {
    if (transform.hasParameters)
        assert(instance);
    CGSize s = taskGroup.targetSize;
// maybe ok    assert(taskStatus == Stopped);
    assert(s.width > 0 && s.height > 0);
    
    switch (transform.type) {
        case RemapImage:
        case RemapPolar:
            instance.remapBuf = [taskGroup remapForTransform:transform instance:instance];
            //    assert(taskStatus == Stopped);
#ifdef DEBUG_TASK_CONFIGURATION
            NSLog(@"    TT  %-15@   %2zu remap size %.0f x %.0f", taskName, index, s.width, s.height);
#endif
            break;
        default:
            assert(transform.type != RemapSize);    // not currently used
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
// source.  Return the frame displayed.

- (const Frame * __nullable) executeTransformsFromFrame:(const Frame *)sourceFrame {
    if (taskStatus == Stopped || !enabled)
        return sourceFrame;     // not now
    if (taskGroup.taskCtrl.state != LayoutOK) {
        taskStatus = Stopped;
        return sourceFrame;
    }

    if (transformList.count == 0) { // just display the input
        UIImage *unmodifiedSourceImage = [sourceFrame toUIImage];
        [self updateTargetWith:unmodifiedSourceImage];
        return sourceFrame;
    }
    
    taskStatus = Running;
    
    if (isThumbTask)
        assert(transformList.count == 1);

#ifdef EXTRA
    if (isThumbTask) {
        // just one transform, for the thumbnail, is special processing
        Transform *transform = transformList[0];
        size_t destIndex = [self performTransform:transform
                                         instance:paramList[0]
                                           source:0];
        Frame *lastFrame = frames[destIndex];
        [self updateTargetWith:[lastFrame toUIImage]];
        taskStatus = Idle;
        return lastFrame;
    }

    if (transformList.count == 0 && !depthTransform) { // just display the input
        UIImage *unmodifiedSourceImage = [self pixbufToImage:imBufs[0]];
        [self updateTargetWith:unmodifiedSourceImage];
        return frame;
    }
#endif
    Frame *activeFrame = [sourceFrame copy];
#ifdef DEBUG
    if (sourceFrame.depthBuf) {
        [sourceFrame.depthBuf verify];
        [sourceFrame.depthBuf verifyDepthRange];
        assert(activeFrame.depthBuf);
        [activeFrame.depthBuf verify];
        [activeFrame.depthBuf verifyDepthRange];
    }
#endif
    NSDate *startTime = [NSDate now];

    for (int i=0; i<transformList.count; i++) {
        if (taskGroup.taskCtrl.state != LayoutOK) {  // abort our processing
            taskStatus = Stopped;
            return sourceFrame;
        }
        Transform *transform = transformList[i];
        TransformInstance *instance = paramList[i];
        
        [self performTransform:transform
                      instance:instance
                         frame:activeFrame];
#ifdef NOTDEF
        NSLog(@"transform %@", transform.name);
        if (transform.type == DepthVis && sourceIndex != destIndex && frames[sourceIndex].depthBuf) {
            frames[destIndex].depthBuf = frames[sourceIndex].depthBuf;
            [frames[destIndex].depthBuf verifyDepthRange];
        }
#endif
        NSDate *transformEnd = [NSDate now];
        instance.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:startTime];
        instance.timesCalled++;
        startTime = transformEnd;
    }
    
    Frame *lastFrame = activeFrame;
    assert(lastFrame);
    if (lastFrame.depthBuf)
        [lastFrame.depthBuf verifyDepthRange];
    [self updateTargetWith:[lastFrame toUIImage]];
    taskStatus = Idle;
    return lastFrame;
}

#ifdef UNUSED_IS_IN_FRAME_NOW
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
#endif

- (void) updateTargetWith:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->targetImageView.image = image;
        [self->targetImageView setNeedsDisplay];
        self->taskStatus = Idle;
     });
}

- (void) performTransform:(Transform *)transform
                     instance:(TransformInstance *)instance
                     frame:(Frame *)srcFrame {
    int N = srcFrame.pixBuf.size.width*srcFrame.pixBuf.size.height;
    
    switch (transform.type) {
        case NullTrans:
            assert(NO); // should never try a null, it is a placeholder for inactive stuff
        case ColorTrans:
            transform.ipPointF(srcFrame, instance.value);
            break;     // was done in place
        case AreaTrans:
            transform.areaF(srcFrame, dstPixBuf, chBuf0, chBuf1, instance);
            memcpy(srcFrame.pixBuf.pb, dstPixBuf.pb,
                   srcFrame.pixBuf.size.height * srcFrame.pixBuf.size.width * sizeof(Pixel));
            break;
        case DepthVis:
            if (srcFrame.depthBuf)
                transform.depthVisF(srcFrame, instance);
            // result is in pixBuf, maybe with modified depthBuf
            break;
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
        case RemapSize:
            assert(NO); // RemapSize not currently used
        case GeometricTrans:
        case RemapPolar:
        case RemapImage: {
            assert(instance);
            assert(instance.remapBuf);
 //           [instance.remapBuf verify];
            BufferIndex *bip = instance.remapBuf.rb;
            PixBuf *destPixBuf = [[PixBuf alloc] initWithSize:srcFrame.pixBuf.size];
            Pixel *dp = destPixBuf.pb;
            for (int i=0; i<N; i++) {
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
                        assert(bi >= 0 && bi < N);
                        p = srcFrame.pixBuf.pb[bi];
                }
                *dp++ = p;
            }
            srcFrame.pixBuf = destPixBuf;   // swap in new bits
        }
    }
    return;
}

@end
