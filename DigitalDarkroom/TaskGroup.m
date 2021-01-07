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
// remapping for every transform of current size, plus parameter
@property (nonatomic, strong)   NSMutableDictionary *remapCache;

@end

@implementation TaskGroup

@synthesize taskCtrl;
@synthesize srcPix;
@synthesize tasksStatus;

@synthesize tasks;
@synthesize remapCache;
@synthesize bytesPerRow, pixelsInImage, pixelsPerRow;
@synthesize bitsPerComponent;
@synthesize bytesInImage;
@synthesize transformSize;
@synthesize imageOrientation;
@synthesize groupName;

- (id)initWithController:(TaskCtrl *) caller {
    self = [super init];
    if (self) {
        self.taskCtrl = caller;
        groupName = @"";
        tasks = [[NSMutableArray alloc] init];
        remapCache = [[NSMutableDictionary alloc] init];
        srcPix = nil;
        bytesPerRow = 0;    // no current configuration
        transformSize = CGSizeZero; // unconfigured group
        tasksStatus = Stopped;
    }
    return self;
}

// Must be called before any tasks are added.  May be called afterwords to
// change size.
- (void) configureGroupForSize:(CGSize) s {
#ifdef DEBUG_TASK_CONFIGURATION
    NSLog(@" GG  %@: configure group for size %.0f x %.0f", groupName, s.width, s.height);
#endif

    transformSize = s;
    
    if (!srcPix ||
            srcPix.w != transformSize.width || srcPix.h != transformSize.height) {
        srcPix = [[PixBuf alloc] initWithSize:transformSize];
    }
    // clear and recompute any remaps
    [remapCache removeAllObjects];
    
    for (Task *task in tasks) {
        [task configureTaskForSize];
    }
}

- (Task *) createTaskForTargetImageView:(UIImageView *) tiv named:(NSString *)tn {
    assert(transformSize.width > 0);    // group must be configured for a size already
    Task *newTask = [[Task alloc] initInGroup:self name:tn];
    newTask.taskIndex = tasks.count;
    newTask.targetImageView = tiv;
    [newTask configureTaskForSize];
    [tasks addObject:newTask];
    return newTask;   // XXX not sure we are going to use this
}

- (void) removeAllTransforms {
    for (Task *task in tasks)
        [task removeAllTransforms];
}

- (void) removeLastTransform {
    for (Task *task in tasks)
        [task removeLastTransform];
}

        
#ifdef notdef
        if (tasksStatus != Stopped) {
        for (Task *task in tasks)
            NSLog(@" ** task status is %d", task.taskStatus);
        assert(tasksStatus == Stopped);
    }
#endif

// This is called back from task for transforms that remap pixels.  The remapping is based
// on the pixel array size, and maybe parameter settings.  We only compute the transform/parameter
// remap once, because it is good for every identical transform/param in all the tasks in this group.

- (RemapBuf *) remapForTransform:(Transform *) transform
                        instance:(TransformInstance *) instance {
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
    transform.remapImageF(remapBuf, instance);
    assert(remapBuf);
    [remapCache setObject:remapBuf forKey:name];
    return remapBuf;
}

- (BOOL) isReadyForLayout {
    assert(taskCtrl.layoutNeeded);
    if (tasksStatus == Stopped)
        return YES;
    for (Task *task in tasks) {
        switch (task.taskStatus) {
            case Running:
                return NO;
            case Ready:
                task.taskStatus = Stopped;
                //  FALLTHROUGH
            case Stopped:
                ;
        }
    }
    tasksStatus = Stopped;
    return YES;
}

- (void) layoutCompleted {
    tasksStatus = Ready;
    for (Task *task in tasks) {
//        assert(task.taskStatus == Stopped);
        task.taskStatus = Ready;
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
    
    if (taskCtrl.layoutNeeded && tasksStatus != Stopped) {
        for (Task *task in tasks) {
            if (task.taskStatus != Stopped) {   // still waiting for this one
                return;
            }
        }
        // The are all stopped.  Inform the authorities
        tasksStatus = Stopped;
//        STUB
        return;
    } else {
        for (Task *task in tasks) {
            if (task.taskStatus == Stopped) {   // still waiting for this one
                task.taskStatus = Ready;
            }
        }
    }
    tasksStatus = Running;
    
    UIGraphicsBeginImageContext(CGSizeMake(srcPix.w, srcPix.h));
    [srcImage drawInRect:CGRectMake(0, 0, srcPix.w, srcPix.h)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
#ifdef SKIPTRANSFORMS   // for debugging
    dispatch_async(dispatch_get_main_queue(), ^{
        for (Task *task in self->tasks) {
            if (task.taskStatus == Running)
                continue;
            task.targetImageView.image = scaledImage;
            [task.targetImageView setNeedsDisplay];
        }
     });
#endif

    CGImageRef imageRef = [scaledImage CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSUInteger bytesPerRow = CGImageGetBytesPerRow(imageRef);
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
            [task executeTransformsWithPixBuf:srcPix];
        }
    }
}

@end
