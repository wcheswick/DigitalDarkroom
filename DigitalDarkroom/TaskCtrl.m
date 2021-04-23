//
//  TaskCtrl.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/10/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "TaskCtrl.h"

@interface TaskCtrl ()

@property (assign)              size_t centerX, centerY;
@property (assign)              volatile BOOL layingOut;

@end

@implementation TaskCtrl

@synthesize mainVC;
@synthesize transforms;
@synthesize taskGroups;
@synthesize layoutNeeded;
@synthesize layingOut;
@synthesize reconfiguring;

- (id)init {
    self = [super init];
    if (self) {
        mainVC = nil;
        taskGroups = [[NSMutableArray alloc] initWithCapacity:N_TASK_GROUPS];
        assert(taskGroups);
        layoutNeeded = YES;
        layingOut = NO;
        reconfiguring = 0;
    }
    return self;
}

- (TaskGroup *) newTaskGroupNamed:(NSString *)name {
    TaskGroup *taskGroup = [[TaskGroup alloc] initWithController:self];
    taskGroup.groupName = name;
    [taskGroups addObject:taskGroup];
    return taskGroup;
}

- (void) idleForLayout {
    if (!layingOut) {
        reconfiguring++;
        assert(!layingOut);
        layoutNeeded = YES; // race?
    }
    [self reconfigureIfReady];
}

- (void) reconfigureIfReady {
    if (layingOut)
        return;
    TaskStatus_t newStatus = Stopped;
    for (TaskGroup *taskGroup in taskGroups) {
        if (![taskGroup isReadyForLayout])
            newStatus = Running;
    }
    if (newStatus == Stopped) {
        layingOut = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->mainVC idledForReconfiguration];
        });
    } else
        NSLog(@"  -- still busy to layout");
}

- (void) layoutCompleted {
    layoutNeeded = NO;
    layingOut = NO;
    reconfiguring--;
    NSLog(@" layout completed: %d", reconfiguring);
    if (reconfiguring < 0) {
        NSLog(@"** reconfiguring error: %d", reconfiguring);
        reconfiguring = 0;
    }
    for (TaskGroup *taskGroup in taskGroups)
        [taskGroup layoutCompleted];
}

// not used, taskStatus needs to be right
- (void) executeTasksWithImage:(UIImage *)image {
    for (TaskGroup *taskGroup in taskGroups) {
        if (taskGroup.tasksStatus != Ready)
            continue;
        [taskGroup executeTasksWithImage: image];
    }
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
