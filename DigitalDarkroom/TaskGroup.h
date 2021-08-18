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

@interface TaskGroup : NSObject {
    TaskCtrl *taskCtrl;
    Transform * __nullable depthTransform;
    NSMutableArray *tasks;
    volatile int busyCount;
    CGSize transformSize;
    size_t bytesPerRow, pixelsInImage, pixelsPerRow;
    size_t bytesInImage;
    size_t bitsPerComponent;
    NSString *groupName;        // for debug display purposes
}

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   Transform * __nullable depthTransform;
@property (nonatomic, strong)   NSMutableArray *tasks;
@property (assign, atomic)      CGSize transformSize;
@property (assign, atomic)      volatile int busyCount;
@property (assign)          size_t bytesPerRow, pixelsInImage, pixelsPerRow;
@property (assign)          size_t bitsPerComponent;
@property (assign)          size_t bytesInImage;
@property (nonatomic, strong)   NSString *groupName;

- (id)initWithController:(TaskCtrl *) caller;
- (Task *) createTaskForTargetImageView:(UIImageView *) tiv
                                  named:(NSString *)tn
                         thumbTransform:(Transform *__nullable) thumbTransform;
- (void) configureGroupForSize:(CGSize) s;
- (void) executeTasksWithImage:(UIImage *) srcImage
                              depth:(const DepthBuf *__nullable) rawDepthBuf;
- (void) configureGroupWithNewDepthTransform:(Transform *__nullable) dt;

- (RemapBuf *) remapForTransform:(Transform *) transform
                        instance:(TransformInstance *) instance;

- (void) removeAllTransforms;
- (void) removeLastTransform;
// XXX need - (void) removeTransformAtIndex:(long) index;

- (BOOL) isReadyForLayout;
- (void) enable;

@end

NS_ASSUME_NONNULL_END
