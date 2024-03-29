//
//  Task.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/16/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
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

@property (nonatomic, strong)   ChBuf *chBuf0, *chBuf1; // scratch channel buffers
@property (nonatomic, strong)   NSMutableArray<Frame *> *frames;    // two scratch frames of the right size

@end

@implementation Task

@synthesize taskName;
@synthesize transformList;
@synthesize paramList;
@synthesize targetImageView;
@synthesize chBuf0, chBuf1;
@synthesize frames;
@synthesize taskGroup;
@synthesize taskIndex;
@synthesize taskStatus;
@synthesize enabled;
@synthesize needsDepthBuf, modifiesDepthBuf;

- (id)initTaskNamed:(NSString *) n inGroup:(TaskGroup *)tg {
    self = [super init];
    if (self) {
        taskName = n;
        taskGroup = tg;
        taskIndex = UNASSIGNED_TASK;
        // create list, with empty depth transform
        transformList = [[NSMutableArray alloc] init];
        paramList = [[NSMutableArray alloc] init];

        enabled = YES;
        taskStatus = Stopped;
        targetImageView = nil;
    }
    return self;
}

- (void) enable {
    //assert(taskStatus == Stopped);
    taskStatus = Idle;
}

- (long) appendTransformToTask:(Transform *) transform {
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    [transformList addObject:transform];
    [paramList addObject:instance];
    [self updateDepthNeeds];
    return transformList.count - 1;
}

- (void) changeLastTransformTo:(Transform *) transform {
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    assert(transformList.count);
    size_t index = transformList.count - 1;
    [transformList replaceObjectAtIndex:index withObject:transform];
    [paramList replaceObjectAtIndex:index withObject:instance];
    [self updateDepthNeeds];
}

- (long) removeLastTransform {
    assert(transformList.count > 0);
    [transformList removeLastObject];
    [paramList removeLastObject];
    [self updateDepthNeeds];
    return transformList.count;
}

- (void) removeAllTransforms {
    [transformList removeAllObjects];
    [paramList removeAllObjects];
    [self updateDepthNeeds];
}

- (void) updateDepthNeeds {
    BOOL needsDepth = NO;
    for (Transform *transform in transformList)
        if (transform.needsScaledDepth) {
            needsDepth = YES;
            break;
        }
    needsDepthBuf = needsDepth;
    [taskGroup updateGroupDepthNeeds];
}

- (NSString *) displayInfoForStep:(long) step
                        shortForm:(BOOL) shortForm {
    assert(step < transformList.count);
    Transform *transform = transformList[step];
    TransformInstance *instance = paramList[step];
    NSString *name = [transform.name stringByReplacingOccurrencesOfString:@"\n"
                                                               withString:@" "];
    NSString *params = @"";
    if (instance.hasParams) {
        int value = instance.value;
        params = [NSString stringWithFormat:@"   %@:  %@%d%@",
                  transform.paramName,
                  value == transform.low ? @"[" : @"<",
                  value,
                  value == transform.high ? @"]" : @">"];
    }
    
    NSString *desc = @"";
    if (!shortForm && ![transform.description isEqual:@""])
        desc = [NSString stringWithFormat:@"  (%@)", transform.description];

    return [NSString stringWithFormat:@"%@%@%@",
            name, params, desc];
}

- (TransformInstance *) instanceForStep:(long) step {
    assert(step < transformList.count);
    TransformInstance *instance = paramList[step];
    return instance;
}

- (void) configureTaskForSize {
    taskStatus = Stopped;   // XXX doesn't wait for idle
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@"   TTT %@  configureTaskForSize: %.3f x %.3f", taskName,
          taskGroup.targetSize.width, taskGroup.targetSize.height);
#endif
    
    chBuf0 = [[ChBuf alloc] initWithSize:taskGroup.targetSize];
    assert(chBuf0);
    chBuf1 = [[ChBuf alloc] initWithSize:taskGroup.targetSize];
    assert(chBuf1);
    
    needsDepthBuf = NO;    // these notes help us prevent extra frame copies
    modifiesDepthBuf = NO;

    // processing space in frames
    frames = [[NSMutableArray alloc] init];
    for (int i=0; i<2; i++) {
        Frame *frame = [[Frame alloc] init];
        frame.pixBuf = [[PixBuf alloc] initWithSize:taskGroup.targetSize];
        frame.depthBuf = [[DepthBuf alloc] initWithSize:taskGroup.targetSize];
        [frames addObject:frame];
    }

    for (int i=0; i<transformList.count; i++) {
        Transform *transform = [self configureTransformAtIndex:i];
        needsDepthBuf |= transform.needsScaledDepth;
        modifiesDepthBuf |= transform.modifiesDepthBuf;
    }
    taskStatus = Idle;
}

- (Transform *) configureTransformAtIndex:(size_t)index {
    Transform *transform = transformList[index];
    TransformInstance *instance = paramList[index];
    [self configureTransform:transform andInstance:instance];
    return transform;
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

- (void) configureTransform:(Transform *) transform
                           andInstance:(TransformInstance *) instance {
    if (transform.hasParameters)
        assert(instance);
    CGSize s = taskGroup.targetSize;
// maybe ok    assert(taskStatus == Stopped);
    assert(s.width > 0 && s.height > 0);
    assert(trunc(s.height) == s.height);
    
    switch (transform.type) {
        case RemapImage:
        case RemapPolar:
            assert(instance);
            instance.remapBuf = [taskGroup remapForTransform:transform instance:instance];
            //    assert(taskStatus == Stopped);
#ifdef DEBUG_TASK_CONFIGURATION
            NSLog(@"    TT  %-15@   remap size %.0f x %.0f",
                  taskName,
                  s.width, s.height);
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

// transform starting with the general group sourceFrame, which must not be changed.

// the incoming frame for this task is shared with the rest of the group.  We are free to
// read it, but not change it.   We have two frames preallocated that are writable, stored
// in frames[0..1].  We pass frames or pixBufs to the transform. This can be frame index -1 (for
// the unwritable incoming frame) or 0 or 1.  Transforms tend to copy their work from input to output,
// so input can be the incoming frame.  Then we jump between the working frames.
//
// Most of these transforms have nothing to do with the depth data, so we avoid copying it unless
// we change it.

// The frames are allocated to the correct size. The buffers may be overwritten or swapped.

- (const Frame * __nullable) executeTaskTransformsOnIncomingFrame {
    if (!enabled)
        return nil;
    switch (taskStatus) {
        case Stopped:
        case Running:
            return nil;
        case LayoutBroken:
            return nil; // XXXX is this right
        case Idle:
            break;
    }
#ifdef XXXX
    if (taskGroup.taskCtrl.taskStatus == LayoutBroken) {
        taskStatus = Stopped;
        return nil;
    }
#endif
    
    Frame *readOnlyIncomingFrame = taskGroup.scaledIncomingFrame;
    if (transformList.count == 0) { // just display the input
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self->targetImageView.image = readOnlyIncomingFrame.image;
            [self->targetImageView setNeedsDisplay];
            self->taskStatus = Idle;
        });
        return nil;
    }
    
    int dstIndex;
    Frame *scaledSrcFrame;
    DepthBuf *scaledSrcDepthBuf = readOnlyIncomingFrame.depthBuf;
    //    if (readOnlyIncomingFrame.pixBufNeedsUpdate || needsDepthBuf) {
    if (needsDepthBuf) {
        scaledSrcFrame = frames[0];
        [scaledSrcFrame.pixBuf loadPixelsFromImage:readOnlyIncomingFrame.image];
        if (readOnlyIncomingFrame.depthBuf &&
            readOnlyIncomingFrame.depthBuf.size.width > 0)
            [scaledSrcFrame.depthBuf scaleFrom:readOnlyIncomingFrame.depthBuf];
        else
            readOnlyIncomingFrame.depthBuf = nil;   // XXXXXX this is the wrong place for this.
        scaledSrcDepthBuf = scaledSrcFrame.depthBuf;
        dstIndex = 1;
    } else {
        scaledSrcFrame = readOnlyIncomingFrame;
        assert(!needsDepthBuf);
//        assert(scaledSrcFrame.depthBuf);
        dstIndex = 0;
    }

    taskStatus = Running;
    int depthIndex = -1;    // in readOnlyIncomingFrame, unless we need it
    NSDate *startTime = [NSDate now];
    
    for (int i=0; i<transformList.count; i++) {
        Transform *transform = transformList[i];
        TransformInstance *instance = paramList[i];
        Frame *dstFrame = frames[dstIndex];
        switch (transform.type) {
            case NullTrans:
                assert(NO); // should never try a null, it is a placeholder for inactive stuff
            case ColorTrans:
                transform.ipPointF(scaledSrcFrame.pixBuf, dstFrame.pixBuf, instance.value);
                scaledSrcFrame = dstFrame;
                dstIndex = 1 - dstIndex;
                break;
            case AreaTrans:
                // compute transform of pixel data only to a destination pixbuf
                transform.areaF(scaledSrcFrame.pixBuf, dstFrame.pixBuf, chBuf0, chBuf1, instance);
                scaledSrcFrame = dstFrame;
                dstIndex = 1 - dstIndex;
                break;
            case DepthVis:
                assert(scaledSrcDepthBuf);
                transform.depthVisF(scaledSrcFrame.pixBuf, scaledSrcDepthBuf, dstFrame.pixBuf, instance);
                // result is in dstFrame, maybe with modified depthBuf
                scaledSrcFrame = dstFrame;
                dstIndex = 1 - dstIndex;
                break;
            case DepthTrans:
                assert(scaledSrcDepthBuf);
                transform.depthVisF(scaledSrcFrame.pixBuf, scaledSrcDepthBuf, dstFrame.pixBuf, instance);
                depthIndex = dstIndex;
                scaledSrcDepthBuf = dstFrame.depthBuf;
                scaledSrcFrame = dstFrame;
                dstIndex = 1 - dstIndex;
                break;
            case EtcTrans:
                NSLog(@"stub - etctrans");
                scaledSrcFrame = dstFrame;
                dstIndex = 1 - dstIndex;
                break;
            case RemapSize:
                assert(NO); // RemapSize not currently used
            case GeometricTrans:
            case RemapPolar:
            case RemapImage: {
                assert(instance);
                assert(instance.remapBuf);
                assert(SAME_SIZE(instance.remapBuf.size, scaledSrcFrame.pixBuf.size));
     //           [instance.remapBuf verify];
                BufferIndex *bip = instance.remapBuf.rb;
                Pixel *dp = dstFrame.pixBuf.pb;
                int N = instance.remapBuf.size.width * instance.remapBuf.size.height;
                assert(N <= scaledSrcFrame.pixBuf.size.width * scaledSrcFrame.pixBuf.size.height);
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
                            p = scaledSrcFrame.pixBuf.pb[bi];
                    }
                    *dp++ = p;
                }
                scaledSrcFrame = dstFrame;
                dstIndex = 1 - dstIndex;
            }
        }
        
        NSDate *transformEnd = [NSDate now];
        instance.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:startTime];
        instance.timesCalled++;
        startTime = transformEnd;
    }
    
    assert(scaledSrcFrame);
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self->targetImageView.image = [scaledSrcFrame.pixBuf toImage];
        [self->targetImageView setNeedsDisplay];
        self->taskStatus = Idle;
    });
    return nil;
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


@end
