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

typedef enum {
    Front,
    Rear,
} CameraSide;

#define FLIP_SIDE(s)    (CameraSide)(Rear - s)

@interface CameraController : NSObject {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id<AVCaptureVideoDataOutputSampleBufferDelegate,
        AVCaptureDepthDataOutputDelegate>delegate;
    CameraSide currentSide;
    volatile BOOL usingDepthCamera;
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)  __unsafe_unretained id<AVCaptureVideoDataOutputSampleBufferDelegate,
                    AVCaptureDepthDataOutputDelegate>delegate;
@property (assign)  CameraSide currentSide;
@property (assign)  volatile BOOL usingDepthCamera;

- (BOOL) hasCameraOnSide:(CameraSide) side;
- (BOOL) hasDepthCameraOnSide:(CameraSide) side;
- (BOOL) isFlipAvailable;
- (BOOL) isDepthAvailable;

- (BOOL) selectCameraOnSide:(CameraSide) side threeD:(BOOL)usingDepthCamera;

- (void) updateOrientationTo:(UIDeviceOrientation) devo;
- (void) setupSession;

- (NSArray *) formatsForSelectedCameraNeeding3D:(BOOL) need3D;
- (void) setupCameraWithFormat:(AVCaptureDeviceFormat *) format;
- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format;

- (void) startCamera;
- (void) stopCamera;
- (BOOL) isCameraOn;

+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o;

- (NSString *) dumpFormatType:(OSType) t;

@end

NS_ASSUME_NONNULL_END
