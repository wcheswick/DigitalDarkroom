//
//  CameraController.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "MainVC.h"
#import "CameraController.h"

@interface CameraController ()

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;

@property (strong, nonatomic)   AVCaptureDevice *frontVideoDevice;
@property (strong, nonatomic)   AVCaptureDevice *backVideoDevice;

@property (strong, nonatomic)   AVCaptureConnection *connection;
@property (assign)              AVCaptureVideoOrientation videoOrientation;

@end

@implementation CameraController

@synthesize captureDevice;
@synthesize captureSession;

@synthesize frontVideoDevice, backVideoDevice;
@synthesize captureVideoPreviewLayer;
@synthesize connection;
@synthesize videoOrientation;


- (id)init {
    self = [super init];
    if (self) {
        NSLog(@"capture device: %@", captureDevice);
        connection = nil;
    }
    return self;
}

- (void) selectCaptureDevice {
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
    else if (backVideoDevice)
        captureDevice = backVideoDevice;
    else
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSLog(@"capture device: %@", captureDevice);
}

- (CGSize) cameraVideoSizeFor: (CGSize) availableSize portrait:(BOOL) isPortrait {
    assert(captureDevice);
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
    NSLog(@"----- selected %.0f x %.0f", bestSize.width, bestSize.height);
    NSLog(@" format %@", selectedFormat);
    if (isPortrait) // this is a hack I can't figure out how to avoid
        return (CGSize){bestSize.height,bestSize.width};
    else
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

- (NSString *) configureForCaptureWithCaller: (MainVC *)caller {
    NSError *error;
    
    assert(captureDevice);
    if (![captureDevice lockForConfiguration:&error])
        return [NSString stringWithFormat:@"error locking camera: %@", error.localizedDescription];
    if (captureDevice.lowLightBoostSupported)
        [captureDevice automaticallyEnablesLowLightBoostWhenAvailable];
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
        [captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    if (captureDevice.smoothAutoFocusSupported)
        captureDevice.smoothAutoFocusEnabled = YES;
    [captureDevice unlockForConfiguration];
    
    captureSession = [[AVCaptureSession alloc] init];
    [captureSession beginConfiguration];
    assert(captureSession);
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        return [NSString stringWithFormat:@"error connecting input: %@", error.localizedDescription];
    }
    [captureSession addInput:input];
    
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    assert(dataOutput);
    [captureSession addOutput:dataOutput];
    dataOutput.videoSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    
    connection = [dataOutput.connections objectAtIndex:0];
    
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [dataOutput setSampleBufferDelegate:caller queue:queue];
    
    [captureSession commitConfiguration];
    return nil;
}

- (void) setVideoOrientation {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    switch (deviceOrientation) {
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
            videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
    }

    captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] init];
    connection.videoOrientation = videoOrientation; // **** This one matters!
}

- (void) setFrame: (CGRect) frame {
    captureVideoPreviewLayer.frame = frame;
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

#ifdef notdef   // this doesn't matter
    captureVideoPreviewLayer.connection.videoOrientation = isPortrait ?
        AVCaptureVideoOrientationPortrait : AVCaptureVideoOrientationLandscapeRight;
#endif
}

- (void) startCamera {
    assert(captureSession);
    [captureSession startRunning];
}

- (void) stopCamera {
    [captureSession stopRunning];
}


@end
