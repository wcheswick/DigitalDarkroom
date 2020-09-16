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
#import "InputSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraController : NSObject {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id<AVCaptureVideoDataOutputSampleBufferDelegate>delegate;
    UIImageOrientation imageOrientation;
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)  __unsafe_unretained id<AVCaptureVideoDataOutputSampleBufferDelegate>delegate;
@property (assign)  UIImageOrientation imageOrientation;

- (void) setupCamerasForCurrentOrientationAndSizeOf:(CGSize) s;
- (CGSize) captureSizeFor:(cameras) camera;
- (void) selectCamera:(cameras) camera;

- (void) startCamera;
- (void) stopCamera;
- (BOOL) isCameraOn;

//- (void) selectCaptureDevice: (cameras) c;

- (BOOL) cameraAvailable: (cameras) c;
- (BOOL) camerasAvailable;


@end

NS_ASSUME_NONNULL_END
