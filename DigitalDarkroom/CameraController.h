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
#import "MainVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraController : NSObject
<AVCaptureDataOutputSynchronizerDelegate,
        AVCaptureDepthDataOutputDelegate,
        AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id videoProcessor;
    BOOL usingDepthCamera;
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)  __unsafe_unretained id videoProcessor;
@property (assign)  volatile BOOL usingDepthCamera;

- (BOOL) cameraAvailableOnFront:(BOOL)front threeD:(BOOL)threeD;
- (NSArray *) formatsForSelectedCameraNeeding3D:(BOOL) need3D;
- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format;

- (void) setupCameraSessionWithFormat:(AVCaptureDeviceFormat *)format;
- (BOOL) selectCameraOnSide:(BOOL)front threeD:(BOOL)threeD;

- (void) updateOrientationTo:(UIDeviceOrientation) devo;

- (void) startCamera;
- (void) stopCamera;

+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o;
- (NSString *) dumpFormatType:(OSType) t;

@end

NS_ASSUME_NONNULL_END
