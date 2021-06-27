//
//  TaskGroup.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/22/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "TaskCtrl.h"
#import "TaskGroup.h"
#import "Task.h"

@interface TaskGroup ()

@property (nonatomic, strong)   PixBuf *srcPix;   // common source pixels for all tasks in this group
@property (nonatomic, strong)   DepthBuf *depthBuf;
// remapping for every transform of current size, plus parameter
@property (nonatomic, strong)   NSMutableDictionary *remapCache;

@end

@implementation TaskGroup

@synthesize taskCtrl;
@synthesize srcPix;
@synthesize depthBuf;
@synthesize depthTransform;

@synthesize tasks;
@synthesize remapCache;
@synthesize bytesPerRow, pixelsInImage, pixelsPerRow;
@synthesize bitsPerComponent;
@synthesize bytesInImage;
@synthesize transformSize;
@synthesize groupName;
@synthesize busyCount;

- (id)initWithController:(TaskCtrl *) caller {
    self = [super init];
    if (self) {
        self.taskCtrl = caller;
        groupName = @"";
        tasks = [[NSMutableArray alloc] init];
        remapCache = [[NSMutableDictionary alloc] init];
        srcPix = nil;
        depthBuf = nil;
        bytesPerRow = 0;    // no current configuration
        transformSize = CGSizeZero; // unconfigured group
        busyCount = 0;
    }
    return self;
}

// Must be called before any tasks are added.  May be called afterwords to
// change size. Is this true?

- (void) configureGroupForSize:(CGSize) s {
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@" GG  %@: configure group for size %.0f x %.0f", groupName, s.width, s.height);
#endif
    assert(busyCount == 0);
    assert(s.width > 0 && s.height > 0);
    transformSize = s;
    
    if (!srcPix || srcPix.w != transformSize.width ||
            srcPix.h != transformSize.height) {
        srcPix = [[PixBuf alloc] initWithSize:transformSize];
    }
    
    if (!depthBuf || depthBuf.w != transformSize.width ||
            depthBuf.h != transformSize.height) {
        depthBuf = [[DepthBuf alloc] initWithSize:transformSize];
    }

    // clear and recompute any remaps
    [remapCache removeAllObjects];
    
    for (Task *task in tasks) {
        [task configureTaskForSize];
    }
}

- (Task *) createTaskForTargetImageView:(UIImageView *) tiv
                                  named:(NSString *)tn {
//    assert(transformSize.width > 0);    // group must be configured for a size already
    Task *newTask = [[Task alloc] initTaskNamed:tn
                                        inGroup:self];
    newTask.taskIndex = tasks.count;
    newTask.targetImageView = tiv;
//    [newTask configureTaskForSize];
    [tasks addObject:newTask];
    return newTask;   // XXX not sure we are going to use this
}

- (void) configureGroupWithNewDepthTransform:(Transform *) dt {
    for (Task *task in tasks) {
        if (task.depthLocked)
            continue;
        [task useDepthTransform:dt];
    }
}

- (void) removeAllTransforms {
    for (Task *task in tasks)
        [task removeAllTransforms];
}

- (void) removeLastTransform {
    for (Task *task in tasks)
        [task removeLastTransform];
}

// This is called back from task for transforms that remap pixels.  The remapping is based
// on the pixel array size, and maybe parameter settings.  We only compute the transform/parameter
// remap once, because it is good for every identical transform/param in all the tasks in this group.

- (RemapBuf *) remapForTransform:(Transform *) transform
                        instance:(TransformInstance *) instance {
//    NSLog(@"transform name: %@", transform.name);
//    NSLog(@"         value: %d", instance.value);
    NSString *name = [NSString stringWithFormat:@"%@:%d", transform.name, instance.value];
    RemapBuf *remapBuf = [remapCache objectForKey:name];
    if (remapBuf) {
#ifdef DEBUG_TASK_CONFIGURATION
        NSLog(@"    GG cached remap %@   size %.0f x %.0f",
              groupName, transformSize.width, transformSize.height);
#endif
        return remapBuf;
    }
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@"    GG new remap %@   size %.0f x %.0f",
          groupName, transformSize.width, transformSize.height);
#endif
    remapBuf = [[RemapBuf alloc] initWithWidth:transformSize.width
                                        height:transformSize.height];
    if (transform.type == RemapTrans) {
        transform.remapImageF(remapBuf, instance);
    } else {  // polar remap
        int centerX = transformSize.width/2;
        int centerY = transformSize.height/2;
        
        for (int dx=0; dx<=centerX; dx++) {
            for (int dy=0; dy<=centerY; dy++) {
                double r = hypot(dx, dy);
                double a = (dx + dy == 0) ? 0 : atan2(dy,dx);
                
                // third quadrant
                transform.polarRemapF(remapBuf, r, M_PI + a, instance,
                                      centerX - dx, centerY - dy);
                
                // second quandrant
                if (centerY + dy < remapBuf.h)
                    transform.polarRemapF(remapBuf, r, M_PI - a, instance, centerX - dx, centerY + dy);
                
                if (centerX + dx < remapBuf.w) {
                    // fourth quadrant
                    transform.polarRemapF(remapBuf, r, -a, instance, centerX + dx, centerY - dy);
                    
                    // first quadrant
                    if (centerY + dy < remapBuf.h)
                        transform.polarRemapF(remapBuf, r, a, instance, centerX + dx, centerY + dy);
                }
            }
        }
    }
    assert(remapBuf);
#ifdef DEBUG
    [remapBuf verify];
#endif
    [remapCache setObject:remapBuf forKey:name];
    return remapBuf;
}

- (BOOL) isReadyForLayout {
    assert(taskCtrl.reconfigurationNeeded);
    for (Task *task in tasks) {
        if (task.taskStatus != Stopped)
            return NO;
    }
    return YES;
}

- (void) enable {
    for (Task *task in tasks) {
        [task enable];
    }
}

- (void) executeTasksWithImage:(UIImage *) srcImage {
    // we prepare a read-only PixBuf for this image.
    // Task must not change it: it is shared among the tasks.
    // At the end of the loop, we don't need it any more
    // We assume (and verify) that the incoming buffer has
    // certain properties that not all iOS pixel buffer formats have.
    // srcBuf's pixels are copied out of the kernel buffer, so we
    // don't have to hold the memory lock.

    // The incoming image size might be larger than the transform size.  Reduce it.
    // The aspect ratio should not change.

    if (taskCtrl.reconfigurationNeeded) {
        for (Task *task in tasks) {
            if (task.taskStatus != Stopped) {   // still waiting for this one
                return;
            }
        }
        // The are all stopped.  Inform the authorities
        [taskCtrl idleForReconfiguration];
        return;
    }

    UIImage *scaledImage;
    if (srcPix.h != srcImage.size.height || srcPix.w != srcImage.size.width) {  // scale
        UIGraphicsBeginImageContext(CGSizeMake(srcPix.w, srcPix.h));
        [srcImage drawInRect:CGRectMake(0, 0, srcPix.w, srcPix.h)];
        scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else
        scaledImage = srcImage;

//#define SKIPTRANSFORMS  1
#ifdef SKIPTRANSFORMS   // for debugging
    dispatch_async(dispatch_get_main_queue(), ^{
        for (Task *task in self->tasks) {
            if (task.taskStatus == Running)
                continue;
            task.targetImageView.image = scaledImage;
            [task.targetImageView setNeedsDisplay];
        }
     });
    return;
#endif

    CGImageRef imageRef = [scaledImage CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSUInteger bytesPerRow = CGImageGetBytesPerRow(imageRef);
    bytesPerRow = width * sizeof(Pixel);    // previous value has un
    NSUInteger bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    assert(srcPix.w == width);
    assert(srcPix.h == height);
    CGContextRef context = CGBitmapContextCreate(srcPix.pb, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 BITMAP_OPTS);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);

    @synchronized (srcPix) {
        for (Task *task in tasks) {
            if (task.taskStatus == Running)
                continue;
            busyCount++;
            [task executeTransformsFromPixBuf:srcPix];
            busyCount--;
            assert(busyCount >= 0);
        }
    }
    [self checkForReconfigure];
}

- (void) checkForReconfigure {
    if (busyCount == 0 && taskCtrl.reconfigurationNeeded)
        [taskCtrl checkReadyForReconfiguration];
}

// same idea as image tasks, but convert the depth buffer
// into an image first. Return the first non-depth image
// for possible capture, etc.

- (UIImage *) executeTasksWithDepthBuf:(DepthBuf *) rawDepthBuf {
    UIImage *sourceImage = nil;   // after depth processing
    DepthBuf *activeDepthBuf = rawDepthBuf;
    if (depthBuf.w != rawDepthBuf.w || depthBuf.h != rawDepthBuf.h) {
        // cheap scaling: XXXX use the hardware
        double yScale = (double)depthBuf.h/(double)rawDepthBuf.h;
        double xScale = (double)depthBuf.w/(double)rawDepthBuf.w;
        for (int x=0; x<depthBuf.w; x++) {
            int sx = x/xScale;
            assert(sx <= rawDepthBuf.w);
            for (int y=0; y<depthBuf.h; y++) {
                int sy = trunc(y/yScale);
                assert(sy < rawDepthBuf.h);
                depthBuf.da[y][x] = rawDepthBuf.da[sy][sx];
            }
        }
        activeDepthBuf = depthBuf;
        activeDepthBuf.minDepth = rawDepthBuf.minDepth;
        activeDepthBuf.maxDepth = rawDepthBuf.maxDepth;
    }

    assert(activeDepthBuf.maxDepth != 0); // should have been done before now
    for (Task *task in tasks) {
        if (task.taskStatus == Running)
            continue;
        busyCount++;
        sourceImage = [task startTransformsWithDepthBuf:activeDepthBuf];
        busyCount--;
        assert(busyCount >= 0);
    }
    [self checkForReconfigure];
    return sourceImage;
}

@end
