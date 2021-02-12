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
#import "ExecuteRowView.h"

#import "Transforms.h"
#import "Transform.h"

NS_ASSUME_NONNULL_BEGIN

#define UNASSIGNED_TASK (-1)
#define DEPTH_TRANSFORM 0

@interface Task : NSObject {
    NSString *taskName;
    TaskGroup *taskGroup;
    TaskStatus_t taskStatus;
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
            inGroup:(TaskGroup *) tg
         usingDepth:(Transform *) dt;
- (void) configureTaskForSize;
- (void) configureTransformAtIndex:(size_t)ti;

- (void) appendTransform:(Transform *) transform;
- (void) removeTransformAtIndex:(long) index;
- (void) removeLastTransform;
- (void) removeAllTransforms;
- (void) useDepthTransform:(Transform *) transform;

- (void) executeTransformsFromPixBuf:(const PixBuf *) srcBuf;
- (void) startTransformsWithDepthBuf:(const DepthBuf *) depthBuf;

- (ExecuteRowView *) executeViewForStep:(int) step;

- (NSString *) infoForScreenTransformAtIndex:(long) index;

@end

NS_ASSUME_NONNULL_END
