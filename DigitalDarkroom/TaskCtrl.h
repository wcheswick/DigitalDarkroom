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
#import "TaskGroup.h"

@class TaskGroup;

NS_ASSUME_NONNULL_BEGIN

// tasks are grouped by targetsize.  All active tasks in a particular group
// are processed in parallel, from a shared pixel/depth buffer.

typedef enum {
    LayoutOK,
    NeedsNewLayout,
    ApplyLayout,
} LayoutStatus_t;

//@class Task;
//@class TaskGroup;

@interface TaskCtrl : NSObject {
    LayoutStatus_t state;
    Transforms *transforms;
    NSMutableArray<TaskGroup *> *taskGroups;
    NSMutableDictionary *activeGroups;
    Frame *lastFrame;
}

@property (nonatomic, strong)   NSMutableArray<TaskGroup *> *taskGroups;
@property (nonatomic, strong)   Transforms *transforms;
@property (assign)              LayoutStatus_t state;
@property (assign)              id mainVC;
@property (nonatomic, strong)   NSMutableDictionary *activeGroups;
@property (nonatomic, strong)   Frame *lastFrame;


- (TaskGroup *) newTaskGroupNamed:(NSString *)name;
- (void) idleFor:(LayoutStatus_t) newStatus;
- (void) checkForIdle;  // are we ready to resume, after possible layout?
- (void) enableTasks;
- (void) processFrame:(Frame *) frame;

@end

NS_ASSUME_NONNULL_END
