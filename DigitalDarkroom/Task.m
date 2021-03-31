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
@synthesize paramList;
@synthesize targetImageView;
@synthesize chBuf0, chBuf1;
@synthesize imBufs;
@synthesize imBuf0, imBuf1;
@synthesize taskGroup;
@synthesize taskIndex;
@synthesize taskStatus;
@synthesize enabled, depthLocked;

- (id)initTaskNamed:(NSString *) n inGroup:(TaskGroup *)tg usingDepth:(Transform *) dt {
    self = [super init];
    if (self) {
        taskName = n;
        taskGroup = tg;
        taskIndex = UNASSIGNED_TASK;
        transformList = [[NSMutableArray alloc] init];
        paramList = [[NSMutableArray alloc] init];
        [self useDepthTransform:dt];
        enabled = YES;
        depthLocked = NO;
        taskStatus = Stopped;
        targetImageView = nil;
        chBuf0 = chBuf1 = nil;
        imBuf0 = imBuf1 = nil;
        imBufs = [[NSMutableArray alloc] initWithCapacity:2];
        assert(imBufs);
    }
    return self;
}


- (ExecuteRowView *) emptyListViewForStep:(long) step {
    ExecuteRowView *rowView = [[ExecuteRowView alloc] initForStep:step];
    [rowView makeRowEmpty];
    return rowView;
}

- (ExecuteRowView *) listViewForStep:(long) step depthActive:(BOOL)doingDepth {
    ExecuteRowView *rowView = [[ExecuteRowView alloc] initForStep:step];
    rowView.hidden = (step == DEPTH_STEP) && !doingDepth;
    [self updateRowView:rowView depthActive:doingDepth];
    return rowView;
}

- (void) updateRowView:(ExecuteRowView *)rowView
           depthActive:(BOOL)doingDepth {
    Transform *transform = nil;
    TransformInstance *instance = nil;
    UIColor *textColor;
    if (!doingDepth && rowView.step == DEPTH_STEP)
        textColor = [UIColor lightGrayColor];
    else
        textColor = [UIColor blackColor];

    if (rowView.step < transformList.count) {  // non-empty step
        transform = [transformList objectAtIndex:rowView.step];
        instance = [paramList objectAtIndex:rowView.step];
    }
    [rowView updateWithName:transform.name
            param:instance
            color:textColor];
}

// we may not reveal it, but it is always there

- (void) useDepthTransform:(Transform *) transform {
    assert(transform);
    assert(transform.type = DepthVis);
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    if (transformList.count == 0) {
        // starting up.  first entry is always depth transform needed
        assert(DEPTH_TRANSFORM == 0);
        [transformList addObject:transform];
        [paramList addObject:instance];
    } else {
        [transformList replaceObjectAtIndex:DEPTH_TRANSFORM withObject:transform];
        [paramList replaceObjectAtIndex:DEPTH_TRANSFORM withObject:instance];
    }
}

- (long) appendTransformToTask:(Transform *) transform {
    assert(transformList.count > 0);    // depth has to be there already
    assert(transform.type != DepthVis); // we have depth, don't add another one
//    if (taskGroup.taskCtrl.layoutNeeded)
//        return; // nope, busy
    [transformList addObject:transform];
    TransformInstance *instance = [[TransformInstance alloc]
                                   initFromTransform:(Transform *)transform];
    [paramList addObject:instance];
    long newIndex = transformList.count - 1;
    return newIndex;
}

- (long) removeLastTransform {
    long step = transformList.count - 1;
    assert(step >= DEPTH_TRANSFORM + 1);    // should never try to delete the depth transform
    [transformList removeLastObject];
    [paramList removeLastObject];
    return step;
}

- (void) removeAllTransforms {
    size_t count = transformList.count - 1; // never remove depth transform, at zero
    if (count == 0)
        return;
    [transformList removeObjectsInRange:NSMakeRange(DEPTH_TRANSFORM+1, count)];
    [paramList removeObjectsInRange:NSMakeRange(DEPTH_TRANSFORM+1, count)];
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
    for (int i=1; i<transformList.count; i++) { // XXX not depth viz
        [self configureTransformAtIndex:i];
    }
}

- (void) configureTransformAtIndex:(size_t)index {
    CGSize s = taskGroup.transformSize;
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@"    TT %-15@   configureTransform  %zu size %.0f x %.0f", taskName, index, s.width, s.height);
#endif
    assert(s.width > 0 && s.height > 0);
    //    assert(taskStatus == Stopped);
    assert(index > DEPTH_TRANSFORM);
    Transform *transform = transformList[index];
    TransformInstance *instance = paramList[index];

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
    assert(index > DEPTH_TRANSFORM);  // cannot remove depth viz
    assert(index < transformList.count);
    [transformList removeObjectAtIndex:index];
    [paramList removeObjectAtIndex:index];
}

// first, apply depth vis on the depthdata, then run it through
// the other transforms. Don't mess with the incoming DepthBuf,

- (void) startTransformsWithDepthBuf:(const DepthBuf *) depthBuf {
    assert(taskStatus == Ready);
    if (!enabled)   // not onscreen
        return;
    taskStatus = Running;
    assert(transformList.count > 0);
    Transform *transform = [transformList objectAtIndex:DEPTH_TRANSFORM];
    TransformInstance *instance = [paramList objectAtIndex:DEPTH_TRANSFORM];
    transform.depthVisF(depthBuf, imBuf0, instance.value);
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
    
    // we copy the pixels into the correctly-sized, previously-created imBuf0,
    // which is also imBufs[0]
    [srcBuf copyPixelsTo:imBuf0];
#ifdef ONLY_RED
    for (int i=0; i<imBuf0.w*imBuf0.h; i++)
        imBuf0.pb[i] = Red;
    onlyRed = YES;
#endif
    [self executeTransformsStartingWithImBuf0];
}

- (void) executeTransformsStartingWithImBuf0 {
    assert(taskStatus == Running);
    if (transformList.count == 0) { // just display the input
        [self updateTargetWith:imBuf0];
        return;
    }
    
//    NSLog(@"transforming %@ to %zu x %zu", self.taskName, imBuf0.w, imBuf0.h);
    NSDate *startTime = [NSDate now];
    size_t sourceIndex = 0; // imBuf0, where the input is
    size_t destIndex;

    for (int i=DEPTH_TRANSFORM+1; i<transformList.count; i++) {
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
        NSLog(@"                                            EEElapsed: %10.3f", [startTime timeIntervalSinceNow]);
        NSDate *transformEnd = [NSDate now];
        instance.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:startTime];
        instance.timesCalled++;
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
    NSLog(@" pixBuf.pa[0][0] [30][30] [49][49] = %08x %08x %08x",
          *(uint32_t *)&pixBuf.pa[10][10],
          *(uint32_t *)&pixBuf.pa[30][30],
          *(uint32_t *)&pixBuf.pa[49][49]);

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
                                   orientation:UIImageOrientationUp];
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
