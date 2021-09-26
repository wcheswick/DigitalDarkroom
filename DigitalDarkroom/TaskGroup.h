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
#import "Frame.h"

#import "TaskCtrl.h"

//#import "RemapBuf.h"

NS_ASSUME_NONNULL_BEGIN

@class Task;
@class TaskCtrl;

@interface TaskGroup : NSObject {
    TaskCtrl *taskCtrl;
    Transform * __nullable incomingSizeTransform;   // adjust incoming size to needed size
    NSMutableArray *tasks;
    volatile int busyCount;
    size_t bytesPerRow, pixelsInImage, pixelsPerRow;
    size_t bytesInImage;
    size_t bitsPerComponent;
    NSString *groupName;        // for debug display purposes
    CGSize targetSize;
}

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   Transform * __nullable incomingSizeTransform;
@property (nonatomic, strong)   NSMutableArray *tasks;
@property (assign, atomic)      volatile int busyCount;
@property (assign)              size_t bytesPerRow, pixelsInImage, pixelsPerRow;
@property (assign)              size_t bitsPerComponent;
@property (assign)              size_t bytesInImage;
@property (nonatomic, strong)   NSString *groupName;
@property (assign)              CGSize targetSize;


- (id)initWithController:(TaskCtrl *) caller;
- (Task *) createTaskForTargetImageView:(UIImageView *) tiv
                                  named:(NSString *)tn;
- (void) configureGroupForTargetSize:(CGSize)targetSize;
- (Frame * __nullable) executeTasksWithFrame:(const Frame *)frame
                      dumpFile:(NSFileHandle *__nullable)imageFileHandle;
- (void) newFrameForTasks:(const Frame * _Nonnull) newFrame;
- (void) doPendingTransforms;

- (RemapBuf *) remapForTransform:(Transform *) transform
                        instance:(TransformInstance *) instance;

- (void) removeAllTransforms;
- (void) removeLastTransform;
// XXX need - (void) removeTransformAtIndex:(long) index;

- (void) enable;

@end

NS_ASSUME_NONNULL_END
