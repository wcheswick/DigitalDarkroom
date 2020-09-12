//
//  CameraController.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "MainVC.h"
#import "CameraController.h"
#import "InputSource.h"

@interface CameraController ()

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;
@property (nonatomic, strong)   AVCaptureDeviceFormat *selectedFormat;

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
@synthesize selectedFormat;
@synthesize videoOrientation;


- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] init];
        connection = nil;
        selectedFormat = nil;
        
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
        NSLog(@"cameras available: front:%d  back:%d",
              [self cameraAvailable:FrontCamera],
              [self cameraAvailable:BackCamera]);
        captureDevice = nil;
    }
    return self;
}

- (BOOL) cameraAvailable:(cameras) c {
    switch (c) {
        case FrontCamera:
            return frontVideoDevice != nil;
        case BackCamera:
            return backVideoDevice != nil;
        default:
            return NO;
    }
}

- (void) selectCaptureDevice: (cameras) camera {
    NSLog(@"selectCaptureDevice: %d", camera);
    if ([self cameraAvailable:camera])
    switch (camera) {
        case FrontCamera:
            captureDevice = frontVideoDevice;
            return;
        case BackCamera:
            captureDevice = backVideoDevice;
            return;
        default:
            captureDevice = nil;
    }
    //captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

#define MAX_FRAME_RATE  24

- (CGSize) cameraVideoSizeFor: (CGSize) availableSize {
    NSLog(@"cameraVideoSizeFor %.0f x %.0f", availableSize.width, availableSize.height);
    NSError *error;
    if (!captureDevice) {
        NSLog(@"*** nconceivable, camera size with no camera capture device");
        return CGSizeZero;
    }
    
    BOOL isPortrait = (videoOrientation == AVCaptureVideoOrientationPortrait) ||
        (videoOrientation == AVCaptureVideoOrientationPortraitUpsideDown);
    
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
    NSLog(@" for orientation: %@",
          isPortrait ? @"port" : @"land");
    
    if (![captureDevice lockForConfiguration:&error]) {
        NSLog(@"could not lock device for configuration");
        return CGSizeZero;
    }
    captureDevice.activeFormat = selectedFormat;
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );

    [captureDevice unlockForConfiguration];
    
    if (isPortrait) // this is a hack I can't figure out how to avoid
        bestSize = (CGSize){bestSize.height,bestSize.width};
    NSLog(@"----- video selected: %.0f x %.0f", bestSize.width, bestSize.height);

    return bestSize;
}

- (NSString *) configureForCaptureWithCaller: (MainVC *)caller {
    NSError *error;
    
    NSLog(@"configure camera");
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
    if (connection.supportsVideoMirroring)
        connection.videoMirrored = YES;
    connection.enabled = NO;
    
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
            videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
    }
    connection.videoOrientation = videoOrientation; // **** This one matters!
}

- (void) setFrame: (CGRect) frame {
    captureVideoPreviewLayer.frame = frame;
//    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

#ifdef notdef   // this doesn't matter
    captureVideoPreviewLayer.connection.videoOrientation = isPortrait ?
        AVCaptureVideoOrientationPortrait : AVCaptureVideoOrientationLandscapeRight;
#endif
}

- (void) startCamera {
    NSLog(@"startCamera");
    assert(captureSession);
    connection.enabled = YES;
    [captureSession startRunning];
}

- (void) stopCamera {
    NSLog(@"stopCamera");
    if (!captureSession) {
        NSLog(@" *** inconceivable: stopping a non-existant camera session");
    } else
        [captureSession stopRunning];
    connection.enabled = NO;
}

- (BOOL) cameraOn {
    return connection.enabled;
}

@end
