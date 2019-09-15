//
//  CameraController.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "CameraController.h"

@interface CameraController ()

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;

@property (strong, nonatomic)   AVCaptureDevice *frontVideoDevice;
@property (strong, nonatomic)   AVCaptureDevice *backVideoDevice;

@property (nonatomic, strong)   AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong)   AVCaptureConnection *connection;
@property (nonatomic, strong)   AVCaptureFileOutput *movieOutput;

@end


@implementation CameraController

@synthesize captureVideoPreviewLayer;
@synthesize captureDevice;
@synthesize captureSession;

@synthesize frontVideoDevice, backVideoDevice;


- (id)init {
    self = [super init];
    if (self) {
        frontVideoDevice = [AVCaptureDevice
                            defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                            mediaType: AVMediaTypeVideo
                            position: AVCaptureDevicePositionFront];
        if (!frontVideoDevice)
            frontVideoDevice = [AVCaptureDevice
                                defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                                mediaType: AVMediaTypeVideo
                                position: AVCaptureDevicePositionFront];
        
        backVideoDevice = [AVCaptureDevice
                           defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                           mediaType: AVMediaTypeVideo
                           position: AVCaptureDevicePositionBack];
        if (!backVideoDevice)
            backVideoDevice = [AVCaptureDevice
                               defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                               mediaType: AVMediaTypeVideo
                               position: AVCaptureDevicePositionBack];

        if (frontVideoDevice)
            captureDevice = frontVideoDevice;
        else {
            if (backVideoDevice)
                captureDevice = backVideoDevice;
            else {
                NSLog(@"no video devices available");
                return nil;
            }
        }
        
        // This app is portrait-only
        
        AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
        
        captureVideoPreviewLayer.connection.videoOrientation = orientation;
#ifdef notdef
        [connection setVideoOrientation: orientation];
        
        for (int i = 0; i < [[movieOutput connections] count]; i++) {
            AVCaptureConnection *captureConnection = [[movieOutput connections] objectAtIndex:i];
            if ([captureConnection isVideoOrientationSupported]) {
                [captureConnection setVideoOrientation:newOrientation];
            }
        }

        captureVideoPreviewLayer.connection.videoOrientation = UIDeviceOrientationPortrait;
        [connection setVideoOrientation: ];
        
        for (int i = 0; i < [[movieOutput connections] count]; i++) {
            AVCaptureConnection *captureConnection = [[movieOutput connections] objectAtIndex:i];
            if ([captureConnection isVideoOrientationSupported]) {
                [captureConnection setVideoOrientation:newOrientation];
            }
        }
#endif
    }
    return self;
}


- (void) startCamera:(NSString *_Nullable* _Nullable)errStr
              detail:(NSString *_Nullable* _Nullable)detailStr
              caller:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)caller {
    NSError *error;

    assert(captureDevice);
    
    if (![captureDevice lockForConfiguration:&error]) {
        *errStr = @"Could not lock media device";
        *detailStr = [error localizedDescription];
        return;
    }
    
    if (captureDevice.lowLightBoostSupported)
        [captureDevice automaticallyEnablesLowLightBoostWhenAvailable];
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
        [captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    
    if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    if (captureDevice.smoothAutoFocusSupported)
        captureDevice.smoothAutoFocusEnabled = YES;
    [captureDevice unlockForConfiguration];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%s: *** no camera available", __PRETTY_FUNCTION__);
        *errStr = @"No camera available";
        detailStr = nil;
        return;
    }
    [captureSession addInput:input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [captureSession addOutput:output];
    output.videoSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [output setSampleBufferDelegate:caller queue:queue];
    
    captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [captureSession startRunning];
}

- (void) stopCamera {
}


@end
