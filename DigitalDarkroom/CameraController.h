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
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

- (void) selectCaptureDevice: (cameras) c;
- (CGSize) cameraVideoSizeFor: (CGSize) s;
- (void) setVideoOrientation;
- (void) setFrame: (CGRect) frame;

- (void) startCamera;
- (void) stopCamera;
- (BOOL) isCameraOn;
- (BOOL) cameraAvailable: (cameras) c;

- (NSString *) configureForCaptureWithCaller: (id<AVCaptureVideoDataOutputSampleBufferDelegate>)caller;
@end

NS_ASSUME_NONNULL_END
