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
        <AVCaptureVideoDataOutputSampleBufferDelegate,
        AVCaptureDataOutputSynchronizerDelegate> {
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id videoProcessor;
    NSMutableArray *formatList;     // from the device, edited to what we could use
    BOOL depthDataAvailable;
}

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)  __unsafe_unretained id videoProcessor;
@property (assign)  volatile BOOL depthDataAvailable;
@property (nonatomic, strong)   NSMutableArray *formatList; // available with this camera

- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format;

- (void) setupCameraSessionWithFormat:(AVCaptureDeviceFormat *)format;
- (BOOL) selectCameraOnSide:(BOOL)front;

- (void) updateOrientationTo:(UIDeviceOrientation) devo;

- (void) startCamera;
- (void) stopCamera;

+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o;
- (NSString *) dumpFormatType:(OSType) t;

@end

NS_ASSUME_NONNULL_END
