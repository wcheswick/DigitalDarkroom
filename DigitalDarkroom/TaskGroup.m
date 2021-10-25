//
//  TaskGroup.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/22/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "CameraController.h"
#import "TaskCtrl.h"
#import "TaskGroup.h"
#import "MainVC.h"
#import "Task.h"

@interface TaskGroup ()

// remapping for every transform of current size, plus parameter
@property (nonatomic, strong)   NSMutableDictionary *remapCache;

@end

@implementation TaskGroup

@synthesize taskCtrl;
@synthesize scaledIncomingFrame;
@synthesize incomingSizeTransform;

@synthesize tasks;
@synthesize remapCache;
@synthesize bytesPerRow, pixelsInImage, pixelsPerRow;
@synthesize bitsPerComponent;
@synthesize bytesInImage;
@synthesize groupName;
@synthesize groupBusy, groupEnabled, groupWantsDepth;
@synthesize targetSize;

- (id)initWithController:(TaskCtrl *) caller {
    self = [super init];
    if (self) {
        self.taskCtrl = caller;
        groupName = @"";
        tasks = [[NSMutableArray alloc] init];
        remapCache = [[NSMutableDictionary alloc] init];
        scaledIncomingFrame = nil;
        bytesPerRow = 0;    // no current configuration
        groupBusy = NO;
        targetSize = CGSizeZero;
        groupEnabled = YES;
        groupWantsDepth = NO;
    }
    return self;
}

// Configure all tasks for possibly a new target image size. The task controller
// has the source image size.  We deal with depth data as we need to.

- (void) configureGroupForTargetSize:(CGSize) ts {
    if (!groupEnabled)
        return;
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@" GG  %@: configureGroupForTargetSize %.0f x %.0f",
          targetSize.width, targetSize.height);
#endif
    assert(!groupBusy);
    groupBusy = YES;
    targetSize = ts;
    assert(taskCtrl.rawImageSourceSize.width > 0 && taskCtrl.rawImageSourceSize.height > 0);
    assert(targetSize.width > 0 && targetSize.height > 0);
    
    if (!scaledIncomingFrame) {
        scaledIncomingFrame = [[Frame alloc] init];
    }
    scaledIncomingFrame.pixBuf.size = targetSize;
    if (!scaledIncomingFrame.pixBuf || !SAME_SIZE(scaledIncomingFrame.pixBuf.size, targetSize))
        scaledIncomingFrame.pixBuf = [[PixBuf alloc] initWithSize:targetSize];

    // camera controller will allocate and fill in the depthBuf if it is needed
    
    // clear and recompute any remaps
    [remapCache removeAllObjects];
    
    for (Task *task in tasks) {
        [task configureTaskForSize];
    }
    groupBusy = NO;
}

- (void) updateGroupDepthNeeds {
    for (Task *task in tasks) {
        if (task.needsDepthBuf) {
            groupWantsDepth = YES;
            return;
        }
    }
    groupWantsDepth = NO;
}
            
// we have a new frame for the group to transform.  The group tasks all use the same scaled frame,
// so scale the input frame once.  Each member of the group must not change the scaled
// frame, since they all share it.  If the depth data is available, it needs scaling too.

// new video frame data and perhaps depth data from the cameracontroller.
// This is a copy of the incoming frame, and further incoming frames will be
// ignored until this routine is done.  At this point, the depth data, if it
// is present, has min and max values computed, but one or more depths may
// be BAD_DEPTH.

- (void) newFrameForGroup:(Frame *) frame {
    if (!groupEnabled)
        return;
    if (groupBusy)
        return;
    groupBusy = YES;
    
    if (frame.image) {
        float scale = scaledIncomingFrame.pixBuf.size.width/frame.image.size.width;
        scaledIncomingFrame.image = [[UIImage alloc] initWithCGImage:frame.image.CGImage
                                                               scale:scale
                                                         orientation:UIImageOrientationUp];
        scaledIncomingFrame.pixBufNeedsUpdate = YES;
    } else {
        assert(frame.pixBuf);   // we need one of these
        assert(NO); //stub
#ifdef NOT_TESTED
        CGImageRef scaledCGImage = scaledImage.CGImage;
        CGContextRef cgContext = CGBitmapContextCreate((char *)scaledFrame.pixBuf.pb, r.size.width, r.size.height, 8,
                                                       r.size.width * sizeof(Pixel), colorSpace, BITMAP_OPTS);
        CGContextDrawImage(cgContext, r, scaledCGImage);
        CGContextRelease(cgContext);
#endif
    }
    
    if (groupWantsDepth) {
        if (!frame.depthBuf)
            scaledIncomingFrame.depthBuf = nil;
        else {
            if (!scaledIncomingFrame.depthBuf || !SAME_SIZE(scaledIncomingFrame.depthBuf.size, rawDepthSize)) {
                scaledIncomingFrame.depthBuf = [[DepthBuf alloc] initWithSize:rawDepthSize];
            }
            assert(frame.depthBuf.db);
            memcpy(scaledIncomingFrame.depthBuf.db, frame.depthBuf.db,
                   frame.depthBuf.size.width * frame.depthBuf.size.height*sizeof(Distance));
            //            [lastRawFrame.depthBuf stats];
        }
    }

    //  XXXXXXX depth?
    for (Task *task in tasks) {
        [task executeTaskTransformsOnIncomingFrame];
    }
    groupBusy = NO;
}

// Create a task with a name that is internally useful.

- (Task *) createTaskForTargetImageView:(UIImageView *) tiv
                                  named:(NSString *)tn {
//    assert(transformSize.width > 0);    // group must be configured for a size already
    Task *newTask = [[Task alloc] initTaskNamed:tn
                                        inGroup:self];
    newTask.taskIndex = tasks.count;
    newTask.targetImageView = tiv;
    [tasks addObject:newTask];
    return newTask;   // XXX not sure we are going to use this
}

#ifdef OLD
- (void) configureGroupWithNewDepthTransform:(Transform *__nullable) dt {
    for (Task *task in tasks) {
        if (task.isThumbTask)    // fixed depth transform for thumb, don't change
            continue;
        [task useDepthTransform:dt];
    }
    depthTransform = dt;
}
#endif

- (void) removeAllTransforms {
    for (Task *task in tasks)
        [task removeAllTransforms];
    groupWantsDepth = NO;
}

- (void) removeLastTransform {
    for (Task *task in tasks)
        [task removeLastTransform];
    [self updateGroupDepthNeeds];
}

- (void) enable {
    if (!groupEnabled)
        return;
    for (Task *task in tasks) {
        [task enable];
    }
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
    remapBuf = [[RemapBuf alloc] initWithSize:targetSize];
    if (transform.type == RemapImage) {
        transform.remapImageF(remapBuf, instance);
    } else {  // polar remap
        int centerX = remapBuf.size.width/2;
        int centerY = remapBuf.size.height/2;
        
        for (int dx=0; dx<=centerX; dx++) {
            for (int dy=0; dy<=centerY; dy++) {
                double r = hypot(dx, dy);
                double a = (dx + dy == 0) ? 0 : atan2(dy,dx);
                
                // third quadrant
                transform.remapPolarF(remapBuf, r, M_PI + a, instance,
                                      centerX - dx, centerY - dy);
                
                // second quandrant
                if (centerY + dy < remapBuf.size.height)
                    transform.remapPolarF(remapBuf, r, M_PI - a, instance, centerX - dx, centerY + dy);
                
                if (centerX + dx < remapBuf.size.width) {
                    // fourth quadrant
                    transform.remapPolarF(remapBuf, r, -a, instance, centerX + dx, centerY - dy);
                    
                    // first quadrant
                    if (centerY + dy < remapBuf.size.height)
                        transform.remapPolarF(remapBuf, r, a, instance, centerX + dx, centerY + dy);
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


@end
