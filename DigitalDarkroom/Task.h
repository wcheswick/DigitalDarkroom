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

typedef enum {
    Idle,
    Running,
    Stopped,
} TaskStatus_t;

@interface Task : NSObject {
    NSString *taskName;
    TaskGroup *taskGroup;
    TaskStatus_t taskStatus;        // only this routine changes this
    NSMutableArray *transformList;  // Transforms after depth transform
    NSMutableArray *paramList;

    UIImageView *targetImageView;
    long taskIndex;  // or UNASSIGNED_TASK
    BOOL isThumbTask;   // must have exactly one transform, which is always run
    BOOL enabled;   // if transform target is on-screen and needs update
}

@property (nonatomic, strong)   NSString *taskName;
@property (assign, atomic)      TaskStatus_t taskStatus;
@property (nonatomic, strong)   UIImageView *targetImageView;
@property (strong, nonatomic)   NSMutableArray *transformList;
@property (strong, nonatomic)   NSMutableArray *paramList;  // settings per transform step
@property (assign)              long taskIndex;
@property (strong, nonatomic)   TaskGroup *taskGroup;
@property (assign)              BOOL enabled, isThumbTask;

- (id)initTaskNamed:(NSString *) n
            inGroup:(TaskGroup *) tg;
- (void) configureTaskForSize;
- (BOOL) updateParamOfLastTransformTo:(int) newParam;
- (int) valueForStep:(size_t) step;
- (long) lastStep;
- (void) enable;    // task must be stopped when calling this

- (long) appendTransformToTask:(Transform *) transform;
- (void) removeTransformAtIndex:(long) index;
- (long) removeLastTransform;
- (void) removeAllTransforms;
- (Transform *) lastTransform;

- (Frame * __nullable) executeTransformsFromFrame:(Frame *)sourceFrame;
- (NSString *) infoForScreenTransformAtIndex:(long) index;

@end

NS_ASSUME_NONNULL_END
