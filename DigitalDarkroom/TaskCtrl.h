//
//  TaskCtrl.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/10/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Transforms.h"
#import <UIKit/UIKit.h>
#import "TaskGroup.h"

@class TaskGroup;

NS_ASSUME_NONNULL_BEGIN

// tasks are grouped by targetsize.  All active tasks in a particular group
// are processed in parallel, from a shared pixel/depth buffer.

//@class Task;
//@class TaskGroup;

@interface TaskCtrl : NSObject {
    Transforms *transforms;
    NSMutableArray<TaskGroup *> *taskGroups;
    NSMutableDictionary *activeGroups;
    Frame *__nullable lastFrame;
}

@property (nonatomic, strong)   NSMutableArray<TaskGroup *> *taskGroups;
@property (nonatomic, strong)   Transforms *transforms;
//@property (assign)              Display_Update_t pendingUpdateType;
@property (assign)              id mainVC;
@property (nonatomic, strong)   NSMutableDictionary *activeGroups;
@property (nonatomic, strong)   Frame *__nullable lastFrame;


- (TaskGroup *) newTaskGroupNamed:(NSString *)name;
- (void) suspendTasksForDisplayUpdate;
- (void) checkForIdle;  // are we ready to resume, after possible layout?
- (void) enableTasks;
- (void) processFrame:(Frame *) frame;
- (NSString *) stats;

@end

NS_ASSUME_NONNULL_END
