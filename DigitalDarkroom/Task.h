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
    Transform *__nullable depthTransform;
    TransformInstance *__nullable depthInstance;
    NSMutableArray *transformList;  // Transforms after depth transform
    Transform *__nullable thumbTransform;   // if task is a thumbnail
    TransformInstance *__nullable thumbInstance;
    NSMutableArray *paramList;

    UIImageView *targetImageView;
    long taskIndex;  // or UNASSIGNED_TASK
    BOOL enabled;   // if transform target is on-screen
}

@property (nonatomic, strong)   NSString *taskName;
@property (assign, atomic)      TaskStatus_t taskStatus;
@property (nonatomic, strong)   UIImageView *targetImageView;
@property (nonatomic, strong)   Transform *__nullable depthTransform;
@property (nonatomic, strong)   TransformInstance *depthInstance;
@property (nonatomic, strong)   Transform *__nullable thumbTransform;
@property (nonatomic, strong)   TransformInstance *__nullable thumbInstance;
@property (strong, nonatomic)   NSMutableArray *transformList;
@property (strong, nonatomic)   NSMutableArray *paramList;  // settings per transform step
@property (assign)              long taskIndex;
@property (strong, nonatomic)   TaskGroup *taskGroup;
@property (assign)              BOOL enabled;

- (id)initTaskNamed:(NSString *) n
            inGroup:(TaskGroup *) tg;
- (void) configureTaskForSize;
- (BOOL) updateParamOfLastTransformTo:(int) newParam;
- (int) valueForStep:(long) step;
- (long) lastStep;
- (void) enable;    // task must be stopped when calling this

- (long) appendTransformToTask:(Transform *) transform;
- (void) removeTransformAtIndex:(long) index;
- (long) removeLastTransform;
- (void) removeAllTransforms;
- (void) useDepthTransform:(Transform *__nullable) transform;
- (Transform *) lastTransform;

- (void) executeTransformsFromPixBuf:(const PixBuf *) srcBuf
                               depth:(const DepthBuf *__nullable)activeDepthBuf;
- (NSString *) infoForScreenTransformAtIndex:(long) index;

- (void) check;

@end

NS_ASSUME_NONNULL_END
