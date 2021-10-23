//
//  CameraController.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "TaskCtrl.h"
#import "TaskGroup.h"
#import "Stats.h"
#import "MainVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraController : NSObject
        <AVCaptureVideoDataOutputSampleBufferDelegate,
        AVCaptureDepthDataOutputDelegate,
        AVCaptureDataOutputSynchronizerDelegate> {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id videoProcessor;
    NSMutableArray *formatList;     // from the device, edited to what we could use
    BOOL depthDataAvailable;
    Stats *stats;
    Frame *lastRawFrame;
    TaskCtrl *taskCtrl;
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)  __unsafe_unretained id videoProcessor;
@property (assign)  volatile BOOL depthDataAvailable;
@property (nonatomic, strong)   NSMutableArray *formatList; // available with this camera
@property (nonatomic, strong)   Stats *stats;
@property (nonatomic, strong)   Frame *lastRawFrame;
@property (nonatomic, strong)   TaskCtrl *taskCtrl;

- (void) setupCameraSessionWithFormat:(AVCaptureDeviceFormat *)format
                          depthFormat:(AVCaptureDeviceFormat *__nullable)depthFormat;
- (BOOL) selectCameraOnSide:(BOOL)front;
- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format;

- (void) updateOrientationTo:(UIDeviceOrientation) devo;
- (void) startCamera;
- (void) stopCamera;

+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o;
+ (BOOL) depthFormat:(AVCaptureDeviceFormat *)depthFormat
       isSuitableFor:(AVCaptureDeviceFormat *)format;
- (NSString *) dumpFormatType:(OSType) t;

- (void) currentRawSizes:(CGSize *)rawImageSize
            rawDepthSize:(CGSize *) rawDepthSize;
extern  CameraController *cameraController;

@end

NS_ASSUME_NONNULL_END
