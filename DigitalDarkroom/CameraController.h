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
#import "SelectInputVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraController : NSObject {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

- (BOOL) selectCaptureDevice: (enum cameras) camera;
- (CGSize) cameraVideoSizeFor: (CGSize) s;
- (void) setVideoOrientation;
- (void) setFrame: (CGRect) frame;

- (void) startCamera;
- (void) stopCamera;
- (void) startCapture;
- (void) stopCapture;

- (NSString *) configureForCaptureWithCaller: (id<AVCaptureVideoDataOutputSampleBufferDelegate>)caller;
@end

NS_ASSUME_NONNULL_END
