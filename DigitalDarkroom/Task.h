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

@interface Task : NSObject {
    NSString *taskName;
    TaskGroup *taskGroup;
    TaskStatus_t taskStatus;
    NSMutableArray *transformList;
    Transform *depthTransform;  // never nil, needs a default

    UIImageView *targetImageView;
    long taskIndex;  // or UNASSIGNED_TASK
    BOOL enabled;   // if transform target is on-screen
}

@property (nonatomic, strong)   NSString *taskName;
@property (assign, atomic)      TaskStatus_t taskStatus;
@property (nonatomic, strong)   UIImageView *targetImageView;
@property (strong, nonatomic)   NSMutableArray *transformList;
@property (assign)              long taskIndex;
@property (strong, nonatomic)   TaskGroup *taskGroup;
@property (assign)              BOOL enabled;
@property (strong, nonatomic)   Transform *depthTransform;

- (id)initInGroup:(TaskGroup *) tg name:(NSString *) n;
- (void) configureTaskForSize;
- (void) configureTransformAtIndex:(size_t)ti;

- (void) appendTransform:(Transform *) transform;
- (void) removeLastTransform;
- (void) removeAllTransforms;
- (void) executeTransformsFromPixBuf:(const PixBuf *) srcBuf;
- (void) startTransformsWithDepthBuf:(const DepthBuf *) depthBuf;


- (Transform *) currentTransform;

@end

NS_ASSUME_NONNULL_END
