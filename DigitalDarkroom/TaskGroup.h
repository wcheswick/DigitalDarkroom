//
//  TaskGroup.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/22/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
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
    NSMutableArray<Task *> *tasks;
    volatile BOOL groupBusy;
    size_t bytesPerRow, pixelsInImage, pixelsPerRow;
    size_t bytesInImage;
    size_t bitsPerComponent;
    NSString *groupName;        // for debug display purposes
    CGSize rawImageSize, rawDepthSize, targetSize;
    Frame *scaledIncomingFrame;
    BOOL groupEnabled, groupWantsDepth;
    NSTimeInterval elapsedProcessingTime;
    size_t timesCalled;
    size_t startTaskIndex;  // to round-robin task updates
}

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   Transform * __nullable incomingSizeTransform;
@property (nonatomic, strong)   NSMutableArray<Task *> *tasks;
@property (nonatomic, strong)   Frame *scaledIncomingFrame; // depthbuf not scaled

@property (assign, atomic)      volatile BOOL groupBusy;
@property (assign)              size_t bytesPerRow, pixelsInImage, pixelsPerRow;
@property (assign)              size_t bitsPerComponent;
@property (assign)              size_t bytesInImage;
@property (nonatomic, strong)   NSString *groupName;
@property (assign)              CGSize rawImageSize, rawDepthSize, targetSize;
@property (assign)              BOOL groupEnabled, groupWantsDepth;
@property (assign)              NSTimeInterval elapsedProcessingTime;
@property (assign)              size_t timesCalled, startTaskIndex;


- (id)initWithController:(TaskCtrl *) caller;
- (Task *) createTaskForTargetImageView:(UIImageView *) tiv
                                  named:(NSString *)tn;
- (void) configureGroupForSrcFrame:(const Frame *) srcFrame;
//- (void) newGroupScaling:(CGSize)targetSize;
//- (Frame * __nullable) executeTasksWithFrame:(const Frame *)frame
//                      dumpFile:(NSFileHandle *__nullable)imageFileHandle;
- (void) newFrameForGroup:(Frame *) frame;

- (RemapBuf *) remapForTransform:(Transform *) transform
                        instance:(TransformInstance *) instance;

- (void) removeAllTransforms;
- (void) removeLastTransform;

- (void) updateGroupDepthNeeds;
- (void) enable;

@end

NS_ASSUME_NONNULL_END
