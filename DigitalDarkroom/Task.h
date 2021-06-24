//
//  Task.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/16/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TaskGroup.h"

#import "Transforms.h"
#import "Transform.h"

NS_ASSUME_NONNULL_BEGIN

#define UNASSIGNED_TASK (-1)
#define DEPTH_TRANSFORM 0

typedef enum {
    Idle,
    Running,
    Stopped,
} TaskStatus_t;

@interface Task : NSObject {
    NSString *taskName;
    TaskGroup *taskGroup;
    TaskStatus_t taskStatus;        // only this routine changes this
    NSMutableArray *transformList;  // first transform is the depth transform
    NSMutableArray *paramList;

    UIImageView *targetImageView;
    long taskIndex;  // or UNASSIGNED_TASK
    BOOL enabled;   // if transform target is on-screen
    BOOL depthLocked;   // if task is a depth button view, don't change it
}

@property (nonatomic, strong)   NSString *taskName;
@property (assign, atomic)      TaskStatus_t taskStatus;
@property (nonatomic, strong)   UIImageView *targetImageView;
@property (strong, nonatomic)   NSMutableArray *transformList;
@property (strong, nonatomic)   NSMutableArray *paramList;  // settings per transform step
@property (assign)              long taskIndex;
@property (strong, nonatomic)   TaskGroup *taskGroup;
@property (assign)              BOOL enabled, depthLocked;

- (id)initTaskNamed:(NSString *) n
            inGroup:(TaskGroup *) tg;
- (void) configureTaskForSize;
// UNNEEDED - (void) configureTransformAtIndex:(size_t)ti;
- (BOOL) updateParamOfLastTransformTo:(int) newParam;
- (int) valueForStep:(long) step;
- (long) lastStep;
- (void) enable;    // task must be stopped when calling this

- (long) appendTransformToTask:(Transform *) transform;
- (void) removeTransformAtIndex:(long) index;
- (long) removeLastTransform;
- (void) removeAllTransforms;
- (void) useDepthTransform:(Transform *) transform;
- (Transform *) lastTransform:(BOOL)doing3D;

- (void) executeTransformsFromPixBuf:(const PixBuf *) srcBuf;
- (void) startTransformsWithDepthBuf:(const DepthBuf *) depthBuf;

- (NSString *) infoForScreenTransformAtIndex:(long) index;

@end

NS_ASSUME_NONNULL_END
