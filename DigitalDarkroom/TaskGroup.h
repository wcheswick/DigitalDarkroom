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
}

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   NSMutableArray *tasks;
@property (atomic, assign)      TaskStatus_t tasksStatus;
@property (assign, atomic)      CGSize transformSize;
@property (assign)          size_t bytesPerRow, pixelsInImage, pixelsPerRow;
@property (assign)          size_t bitsPerComponent;
@property (assign)          size_t bytesInImage;
@property (assign)          UIImageOrientation imageOrientation;

- (id)initWithController:(TaskCtrl *) caller;

- (void) executeTasksWithImage:(UIImage *) image;
- (RemapBuf *) remapForTransform:(Transform *) transform params:(Params *) params;
- (Task *) createTaskForTargetImageView:(UIImageView *)yiv;

- (void) removeAllTransforms;
- (void) removeLastTransform;

- (void) configureForSize:(CGSize) size;
- (void) configureForImage:(UIImage *) image;

- (BOOL) isReadyForLayout;
- (void) layoutCompleted;

@end

NS_ASSUME_NONNULL_END