//
//  Execute.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/10/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "TaskCtrl.h"

@interface TaskCtrl ()

@property (nonatomic, strong)   Transform * __nullable depthTransform;
@property (assign)              size_t centerX, centerY;
@property (assign)              BOOL busy;
@property (assign)              CGSize newLayoutSize;

@end

@implementation TaskCtrl

@synthesize mainVC;
@synthesize transforms;
@synthesize taskGroups;
@synthesize depthTransform;
@synthesize busy;
@synthesize layoutNeeded;
@synthesize newLayoutSize;

- (id)init {
    self = [super init];
    if (self) {
        mainVC = nil;
        newLayoutSize = CGSizeZero;
        taskGroups = [[NSMutableArray alloc] initWithCapacity:N_TASK_GROUPS];
        depthTransform = nil;
        layoutNeeded = YES;
    }
    return self;
}

- (TaskGroup *) newTaskGroup {
    TaskGroup *taskGroup = [[TaskGroup alloc] initWithController:self];
    [taskGroups addObject:taskGroup];
    return taskGroup;
}

- (void) needLayout:(CGSize) newSize {
    newLayoutSize = newSize;
    layoutNeeded = YES;
    for (TaskGroup *taskGroup in taskGroups) {
        if (taskGroup.tasksStatus != Stopped)
            return;
    }
    assert(newLayoutSize.width > 0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->mainVC doLayout:self->newLayoutSize];
    });
}

- (void) layoutCompleted {
    NSLog(@" --- layout completed");
    layoutNeeded = NO;
    for (TaskGroup *taskGroup in taskGroups)
        [taskGroup layoutCompleted];
}

- (Task *) createTaskInGroup:(TaskGroup *) taskGroup
                 forTargetView:(UIImageView *)tiv {
    return [taskGroup createTaskForTargetImageView:tiv];
}

- (void) configureForSize:(CGSize) ts {
}

- (void) configureForImage:(UIImage *) image {
}

- (void) executeTasksWithImage:(UIImage *)image {
    for (TaskGroup *taskGroup in taskGroups) {
        if (taskGroup.tasksStatus != Ready)
            continue;
        [taskGroup executeTasksWithImage: image];
    }
}

- (void) selectDepthTransform:(int)index {
    depthTransform = [transforms depthTransformForIndex:index];
}

- (void) depthToPixels: (DepthImage *)depthImage pixels:(Pixel *)depthPixelVisImage {
    assert(depthTransform);
    depthTransform.depthVisF(depthImage, depthPixelVisImage, depthTransform.value);
}

#ifdef GONE
- (PixelIndex_t *) computeMappingFor:(Transform *) transform {
    assert(bytesPerRow);
    assert(transform.type == RemapTrans);
    NSLog(@"remap %@", transform.name);
    PixelIndex_t *remapTable = (PixelIndex_t *)calloc(pixelsInImage, sizeof(PixelIndex_t));
    
#ifdef DEBUG_TRANSFORMS
    for (int i=0; i<configuredPixelsInImage; i++)
        remapTable[i] = Remap_Unset;
#endif
    transform.remapTable = remapTable;

    if (transform.remapPolarF) {     // polar remap
        for (int dx=0; dx<centerX; dx++) {
            for (int dy=0; dy<centerY; dy++) {
                double r = hypot(dx, dy);
                double a;
                if (dx == 0 && dy == 0)
                    a = 0;
                else
                    a = atan2(dy, dx);
                remapTable[PI(centerX-dx, centerY-dy)] = transform.remapPolarF(r, M_PI + a, transform.value);
                if (centerY+dy < H)
                    remapTable[PI(centerX-dx, centerY+dy)] = transform.remapPolarF(r, M_PI - a, transform.value);
                if (centerX+dx < W) {
                    if (centerY+dy < H)
                        remapTable[PI(centerX+dx, centerY+dy)] = transform.remapPolarF(r, a, transform.value);
                    remapTable[PI(centerX+dx, centerY-dy)] = transform.remapPolarF(r, -a, transform.value);
                }
            }
        }

#ifdef OLDNEW
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                double rx = x - centerX;
                double ry = y - centerY;
                double r = hypot(rx, ry);
                double a = atan2(ry, rx);
                remapTable[PI(x,y)] = transform.remapPolarF(r, /* M_PI+ */ a,
                                                            transform.p,
                                                            W,
                                                            H);
            }
        }
#endif
    } else {        // whole screen remap
        NSLog(@"transform: %@", transform);
        transform.remapImageF(remapTable,
                              W, H,
                              transform.value);
    }
    return remapTable;
}
#endif

// It is important that the user interface doesn't change the transform list
// while we are running through it.  There are several changes of interest:
//  1) adding or deleting one or more transforms
//  2) changing the parameter on a particular transform
//  3) changing the display area size (via source or orientation change
//
// The master list of transforms to be executed is 'sequence', and is managed by
// the GUI. We can't run from this list, because a change in the middle of transforming would
// mess up everything.
//
// So the GUI changes this sequence as it wants to, using @synchronize on the array. It sets
// a flag, sequenceChanged, when changes occur.  Right here, just before we run through a
// transform sequence, we check for changes, and update our current transform sequence,
// 'executeList' from a locked copy of the sequence list.
//
// We keep our own local list of current transforms, and keep the parameters
// for each (a transform could appear more than once, with different params.)
//
// A number of transforms simply involve moving pixels around just based on position.
// we recompute the table of pixel indicies and just use that.  That table needs to
// be computed the first time the transform is used, whenever the param changes, or
// when the screen size changes.  If it needs updating, the table pointer is NULL.
// Only this routine changes this pointer.

#ifdef NOTYET
// adjust execute list
        [executeList removeAllObjects];
        
        @synchronized (sequence) {
            for (Transform *t in sequence) {
                if (t.newValue) {
                    [t clearRemap];
                    t.newValue = NO;
                }
                [executeList addObject:t];
            }
        }
        sequenceChanged = NO;
        @synchronized (sequence) {
            for (Transform *t in sequence) {
                if (t.newValue) {
                    [t clearRemap];
                    t.newValue = NO;
                }
            }
        }
    }
#endif


@end