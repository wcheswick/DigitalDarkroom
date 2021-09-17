//
//  TaskCtrl.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/10/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Transforms.h"
#import <UIKit/UIKit.h>
#import "MainVC.h"
#import "TaskGroup.h"
#import "Task.h"

NS_ASSUME_NONNULL_BEGIN

// tasks are grouped by targetsize.  All active tasks in a particular group
// are processed in parallel.

typedef enum {
    ScreenTasks,
    ThumbTasks,
    ExternalTasks,
} TaskGroup_t;
#define N_TASK_GROUPS   (ExternalTasks + 1)

@class Task;
@class TaskGroup;

@interface TaskCtrl : NSObject {
    Transforms *transforms;
    NSMutableArray *taskGroups;
    CGSize sourceSize;
    volatile BOOL reconfigurationNeeded;
}

@property (nonatomic, strong)   NSMutableArray *taskGroups;
@property (nonatomic, strong)   Transforms *transforms;
@property (assign, atomic)      volatile BOOL reconfigurationNeeded;
@property (assign)              CGSize sourceSize;

- (TaskGroup *) newTaskGroupNamed:(NSString *)name;
- (BOOL) tasksAreIdled;
- (void) enableTasks;
- (void) idleTransforms;

@end

NS_ASSUME_NONNULL_END
