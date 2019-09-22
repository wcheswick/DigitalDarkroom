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

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@end

@implementation CameraController

@synthesize captureDevice;
@synthesize captureSession;

@synthesize frontVideoDevice, backVideoDevice;
@synthesize captureVideoPreviewLayer;


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
        
        captureSession = [[AVCaptureSession alloc] init];
        if (captureDevice == nil) {
            captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            if (captureDevice == nil) {
                NSLog(@"No video camera found");
                return nil;
            }
        }
        

    }
    return self;
}

- (CGSize) cameraVideoSizeFor: (CGSize) availableSize {
    AVCaptureDeviceFormat *selectedFormat = nil;
    CGSize bestSize;
    for (AVCaptureDeviceFormat *format in captureDevice.formats) {
        CMFormatDescriptionRef ref = format.formatDescription;
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(ref);
        if (mediaType != kCMMediaType_Video)
            continue;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
        if (dimensions.width > availableSize.width || dimensions.height > availableSize.height)
            continue;
        if (selectedFormat) {   // this one fits.  Is it better?
            if (dimensions.width < bestSize.width || dimensions.height < bestSize.height)
                continue;
        }
        selectedFormat = format;
        bestSize = (CGSize){dimensions.width, dimensions.height};
    }
    if (!selectedFormat) {
        NSLog(@"inconceivable: no suitable video found for %.0f x %.0f",
              availableSize.width, availableSize.height);
        return (CGSize){0,0};
    }
    NSLog(@"selected %.0f x %.0f", bestSize.width, bestSize.height);
    NSLog(@" format %@", selectedFormat);
    return bestSize;
    
#ifdef notded
    captureDevice.activeFormat
    NSArray *sizes = [NSArray arrayWithObjects:
                      @[@(352),@(288), AVCaptureSessionPreset352x288],
                      @[@(640),@(480), AVCaptureSessionPreset640x480],
                      @[@(1280),@(720), AVCaptureSessionPreset1280x720],
                      @[@(1920),@(1080), AVCaptureSessionPreset1920x1080],
                      @[@(3840),@(2160), AVCaptureSessionPreset3840x2160],
                      nil];

    unsigned long i;
    for (i=sizes.count-1; i>=0; i--) {
        NSArray *entry = [sizes objectAtIndex:i];
        NSNumber *w = (NSNumber *)[entry objectAtIndex:0];
        NSNumber *h = (NSNumber *)[entry objectAtIndex:1];
        captureSession.sessionPreset = [entry objectAtIndex:2];
        if (w.intValue <= availableSize.width && h.intValue <= availableSize.height)
            return (CGSize){w.intValue,h.intValue};
    }
    NSLog(@"**** inconceivable, no size fits %.0f4,%.0f", availableSize.width, availableSize.height);
    return (CGSize){0,0};
#endif
}

- (void) startCamera:(NSString *_Nullable* _Nullable)errStr
              detail:(NSString *_Nullable* _Nullable)detailStr
              caller:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)caller {
    NSError *error;

    assert(captureDevice);
    assert(captureSession);
    if (![captureDevice lockForConfiguration:&error]) {
        *errStr = @"Could not lock media device";
        *detailStr = [error localizedDescription];
        return;
    }
    
    captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    captureVideoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    captureVideoPreviewLayer.connection.automaticallyAdjustsVideoMirroring = YES;

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
    
    [captureSession startRunning];
}

- (void) stopCamera {
}


@end
