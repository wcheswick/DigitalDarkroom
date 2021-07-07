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
#import "InputSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraController : NSObject {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id<AVCaptureVideoDataOutputSampleBufferDelegate,
        AVCaptureDepthDataOutputDelegate>delegate;
    BOOL frontCamera;
    BOOL threeDCamera;
}

@property (assign) BOOL frontCamera, threeDCamera;

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)  __unsafe_unretained id<AVCaptureVideoDataOutputSampleBufferDelegate,
                    AVCaptureDepthDataOutputDelegate>delegate;
@property (assign)  volatile BOOL usingDepthCamera;

- (BOOL) cameraAvailableOnFront:(BOOL)front threeD:(BOOL)threeD;
- (BOOL) selectCameraOnSide:(BOOL)front threeD:(BOOL)threeD;

- (void) updateOrientationTo:(UIDeviceOrientation) devo;

- (NSArray *) formatsForSelectedCameraNeeding3D:(BOOL) need3D;
- (void) setupCameraSessionWithFormat:(AVCaptureDeviceFormat *)format;
- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format;

- (void) startCamera;
- (void) stopCamera;
- (BOOL) isCameraOn;

+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o;

- (NSString *) dumpFormatType:(OSType) t;

@end

NS_ASSUME_NONNULL_END
