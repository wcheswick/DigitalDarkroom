//
//  TaskGroup.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/22/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Transform.h"
#import "TransformInstance.h"

#import "TaskCtrl.h"

//#import "RemapBuf.h"

NS_ASSUME_NONNULL_BEGIN

@class Task;
@class TaskCtrl;

typedef enum {
    Ready,
    Running,
    Stopped,
} TaskStatus_t;

@interface TaskGroup : NSObject {
    TaskCtrl *taskCtrl;
    TaskStatus_t tasksStatus;
    NSMutableArray *tasks;
    CGSize transformSize;
    size_t bytesPerRow, pixelsInImage, pixelsPerRow;
    size_t bytesInImage;
    size_t bitsPerComponent;
    UIImageOrientation imageOrientation;
    NSString *groupName;        // for debug display purposes
}

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   NSMutableArray *tasks;
@property (atomic, assign)      TaskStatus_t tasksStatus;
@property (assign, atomic)      CGSize transformSize;
@property (assign)          size_t bytesPerRow, pixelsInImage, pixelsPerRow;
@property (assign)          size_t bitsPerComponent;
@property (assign)          size_t bytesInImage;
@property (assign)          UIImageOrientation imageOrientation;
@property (nonatomic, strong)   NSString *groupName;

- (id)initWithController:(TaskCtrl *) caller;
- (Task *) createTaskForTargetImageView:(UIImageView *) tiv
                                  named:(NSString *)tn
                         depthTransform:(Transform *)dt;
- (void) configureGroupForSize:(CGSize) s orientation:(UIImageOrientation) io;
- (void) executeTasksWithImage:(UIImage *) image;
- (void) executeTasksWithDepthBuf:(DepthBuf *) rawDepthBuf;
- (void) configureGroupWithNewDepthTransform:(Transform *) dt;

- (RemapBuf *) remapForTransform:(Transform *) transform
                        instance:(TransformInstance *) instance;

- (void) removeAllTransforms;
- (void) removeLastTransform;

- (BOOL) isReadyForLayout;
- (void) layoutCompleted;

@end

NS_ASSUME_NONNULL_END
