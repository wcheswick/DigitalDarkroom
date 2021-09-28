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
#import "MainVC.h"
#import "Task.h"

@interface TaskGroup ()

@property (nonatomic, strong)   Frame *groupSrcFrame;
// remapping for every transform of current size, plus parameter
@property (nonatomic, strong)   NSMutableDictionary *remapCache;

@end

@implementation TaskGroup

@synthesize taskCtrl;
@synthesize groupSrcFrame;
@synthesize incomingSizeTransform;

@synthesize tasks;
@synthesize remapCache;
@synthesize bytesPerRow, pixelsInImage, pixelsPerRow;
@synthesize bitsPerComponent;
@synthesize bytesInImage;
@synthesize groupName;
@synthesize busyCount;
@synthesize targetSize;

- (id)initWithController:(TaskCtrl *) caller {
    self = [super init];
    if (self) {
        self.taskCtrl = caller;
        groupName = @"";
        tasks = [[NSMutableArray alloc] init];
        remapCache = [[NSMutableDictionary alloc] init];
        groupSrcFrame = nil;
        bytesPerRow = 0;    // no current configuration
        busyCount = 0;
        targetSize = CGSizeZero;
    }
    return self;
}

// Configure all tasks for possibly a new target image size. The task controller
// has the source image size.  We deal with depth data as we need to.

- (void) configureGroupForTargetSize:(CGSize) ts {
    targetSize = ts;
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@" GG  %@: configureGroupForTargetSize %.0f x %.0f",
          targetSize.width, targetSize.height);
#endif
    assert(busyCount == 0);
    assert(taskCtrl.sourceSize.width > 0 && taskCtrl.sourceSize.height > 0);
    assert(targetSize.width > 0 && targetSize.height > 0);
    if (!groupSrcFrame || !SAME_SIZE(groupSrcFrame.pixBuf.size, targetSize)) {
        if (!groupSrcFrame) {
            groupSrcFrame = [[Frame alloc] init];
        }
        groupSrcFrame.pixBuf.size = targetSize;
        if (!groupSrcFrame.pixBuf || !SAME_SIZE(groupSrcFrame.pixBuf.size, targetSize))
            groupSrcFrame.pixBuf = [[PixBuf alloc] initWithSize:targetSize];
        if (!groupSrcFrame.depthBuf || !SAME_SIZE(groupSrcFrame.pixBuf.size, targetSize))
            groupSrcFrame.depthBuf = [[DepthBuf alloc] initWithSize:targetSize];
    }
    
    // source size must be scaled to targetsize.
    
    if (!groupSrcFrame.pixBuf || !SAME_SIZE(groupSrcFrame.pixBuf.size, targetSize)) {
        groupSrcFrame.pixBuf = [[PixBuf alloc] initWithSize:targetSize];
    }
    
    if (!groupSrcFrame.depthBuf || !SAME_SIZE(groupSrcFrame.depthBuf.size, targetSize)) {
        groupSrcFrame.depthBuf = [[DepthBuf alloc] initWithSize:targetSize];
    }
    
    // clear and recompute any remaps
    [remapCache removeAllObjects];
    
    for (Task *task in tasks) {
        [task configureTaskForSize];
    }
}

// we have a new frame for the group to transform.  The group tasks all use the same scaled frame,
// so scale the input frame once.  Each member of the group must not change the scaled
// frame, since they all share it.  The supplied newFrame must not be changed, since
// it is shared by all the groups.
//
// The targetSize that we are going to scale to must already be known.

- (void) newFrameForTasks:(const Frame * _Nonnull) newFrame {
    assert(targetSize.width > 0 && targetSize.height > 0);
    
    [groupSrcFrame scaleFrom:newFrame];
    // we set up the source frame, but don't start processing it until
    // we release the original raw frame.
}

- (void) doPendingTransforms {
    for (Task *task in tasks) {
        [task executeTransformsFromFrame:groupSrcFrame];
    }
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
}

- (void) removeLastTransform {
    for (Task *task in tasks)
        [task removeLastTransform];
}

- (void) enable {
    for (Task *task in tasks) {
        [task enable];
    }
}

// transform the image.
// return the frame of the image finally displayed by the last task.

- (Frame *) executeTasksWithFrame:(const Frame *) frame
                      dumpFile:(NSFileHandle *__nullable)imageFileHandle {
    // XXXXX this is mostly wrong now:
    assert(frame);
    // we prepare a read-only PixBuf for this image.
    // Task must not change it: it is shared among the tasks.
    // At the end of the loop, we don't need it any more
    // We assume (and verify) that the incoming buffer has
    // certain properties that not all iOS pixel buffer formats have.
    // srcBuf's pixels are copied out of the kernel buffer, so we
    // don't have to hold the memory lock.
    
    // We also prepare a readonly depth buffer (if depth supplied) that is scaled
    // to this group's image size.  The scaling is a bit crude at the moment,
    // and probably should be done in hardware.
    //
    // NB: the depth buffer has dirty values: negative and NaN.  Set these to
    // the maximum distance.
    
    // The incoming image size might be larger than the transform size.  Reduce it.
    // The aspect ratio should not change.

    if (taskCtrl.state != LayoutOK) {
        for (Task *task in tasks) {
            if (task.taskStatus != Stopped) {   // still waiting for this one
                return nil;
            }
        }
        // The are all stopped.  Inform the authorities
        [mainVC tasksReadyFor:taskCtrl.state];
        return nil;
    }

    // grousrcframe is scaled frame, already allocated
    
    Frame * __nullable lastFrame = nil;
    
    if (frame.depthBuf) {
        [frame.depthBuf verifyDepthRange];
        [groupSrcFrame.depthBuf scaleFrom:frame.depthBuf];
    }

    assert(frame.pixBuf);
    if (!SAME_SIZE(frame.pixBuf.size, targetSize)) {
//        XXXXXX scale to larger should await reconfiguration
        [groupSrcFrame.pixBuf scaleFrom:frame.pixBuf];
    } else
        groupSrcFrame.pixBuf = frame.pixBuf;
    assert(frame.pixBuf);

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

    if (imageFileHandle) {
        NSString *line = [NSMutableString stringWithFormat:@"%lu %lu %d\n",
                           (unsigned long)groupSrcFrame.pixBuf.size.width, (unsigned long)groupSrcFrame.pixBuf.size.height,
                          groupSrcFrame.depthBuf ? 4 : 3];
        [imageFileHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        if (groupSrcFrame.depthBuf)
            assert(SAME_SIZE(groupSrcFrame.depthBuf.size, groupSrcFrame.pixBuf.size));
        for (int y=0; y < groupSrcFrame.pixBuf.size.height; y++) {
            for (int x=0; x < groupSrcFrame.pixBuf.size.width; x++) {
                NSString *d = groupSrcFrame.depthBuf ? [NSString stringWithFormat:@"%f",
                                                        frame.depthBuf.da[y][x]] : @"";
                line = [NSString stringWithFormat:@"%d %d %d %@\n",
                        groupSrcFrame.pixBuf.pa[y][x].r,
                        groupSrcFrame.pixBuf.pa[y][x].g,
                        groupSrcFrame.pixBuf.pa[y][x].b, d];
                [imageFileHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
    
    for (Task *task in tasks) {
        if (task.taskStatus == Running)
            continue;
        busyCount++;
        // [task check];
        lastFrame = (Frame *)[task executeTransformsFromFrame:groupSrcFrame];
        busyCount--;
        assert(busyCount >= 0);
    }
    
    return lastFrame;
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
