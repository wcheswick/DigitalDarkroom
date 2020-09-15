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
@property (strong, nonatomic)   AVCaptureDevice *rearVideoDevice;

@property (strong, nonatomic)   AVCaptureConnection *connection;
@property (assign)              AVCaptureVideoOrientation videoOrientation;

@end

@implementation CameraController

@synthesize captureDevice;
@synthesize captureSession;

@synthesize frontVideoDevice, rearVideoDevice;
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
        
        rearVideoDevice = [AVCaptureDevice
                           defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                           mediaType: AVMediaTypeVideo
                           position: AVCaptureDevicePositionBack];
        if (!rearVideoDevice)
            rearVideoDevice = [AVCaptureDevice
                               defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                               mediaType: AVMediaTypeVideo
                               position: AVCaptureDevicePositionBack];
        
        if (frontVideoDevice || rearVideoDevice) {
            captureSession = [[AVCaptureSession alloc] init];
        } else {
            NSLog(@"no cameras available");
            captureSession = nil;       // no cameras available
        }
    }
    return self;
}

- (BOOL) camerasAvailable {
    return captureSession != nil;
}

- (void) setupCamerasForCurrentOrientationAndSizeOf:(CGSize) s {
    NSError *error;

    CGSize frontSize = [self configureCamera: frontVideoDevice forSize:s];
    if (!frontSize.width) {
        NSLog(@"setupSessionForCurrentOrientationAndSizeOf: front camera not available");
    }
    CGSize rearSize = [self configureCamera: rearVideoDevice forSize:s];
    if (!rearSize.width) {
        NSLog(@"setupSessionForCurrentOrientationAndSizeOf: rear camera not available");
    }
    
    AVCaptureDeviceInput *frontInput = [AVCaptureDeviceInput
                                   deviceInputWithDevice:frontVideoDevice
                                   error:&error];
    if (!frontInput) {
        NSLog(@"inconceivable: setupSessionForCurrentOrientationAndSizeOf: add front: %@",
              [error localizedDescription]);
    }
    
    AVCaptureDeviceInput *rearInput = [AVCaptureDeviceInput
                                   deviceInputWithDevice:rearVideoDevice
                                   error:&error];
    if (!rearInput) {
        NSLog(@"inconceivable: setupSessionForCurrentOrientationAndSizeOf: add rear: %@",
              [error localizedDescription]);
    }
}

- (void) selectCamera:(cameras)camera {
    AVCaptureDevice *device;
    if (camera == FrontCamera) {
        if (!frontVideoDevice) {
            NSLog(@"front camera selected, bu no video device");
            return;
        }
        device = frontVideoDevice;
    } else {
        if (!rearVideoDevice) {
            NSLog(@"rear camera selected, bu no video device");
            return;
        }
        device = rearVideoDevice;
    }
    
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        NSLog(@"*** selectCamera: error %@", [error localizedDescription]);
        return;
    }
    
    [captureSession beginConfiguration];
    for (AVCaptureDeviceInput *input in captureSession.inputs)
        [captureSession removeInput:input];
    [captureSession addInput:input];
    [captureSession commitConfiguration];
}

- (CGSize) configureCamera: (AVCaptureDevice *) captureDevice forSize: (CGSize)availableSize {
    CGSize bestSize = CGSizeZero;
    
    if (!captureDevice)
        return bestSize;
    
    AVCaptureDeviceFormat *selectedFormat = nil;
    AVCaptureDeviceFormat *bestFormat;
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
        bestFormat = format;
    }
    if (!selectedFormat) {
        NSLog(@"inconceivable: no suitable video found for %.0f x %.0f",
              availableSize.width, availableSize.height);
        return CGSizeZero;
    }
    
#define MAX_FRAME_RATE  24

    NSError *error;
    if (![captureDevice lockForConfiguration:&error]) {
        NSLog(@"** could not lock video camera: %@", [error localizedDescription]);
        return CGSizeZero;
    };
    captureDevice.activeFormat = bestFormat;
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    if (captureDevice.lowLightBoostSupported)
        [captureDevice automaticallyEnablesLowLightBoostWhenAvailable];
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
        [captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    if (captureDevice.smoothAutoFocusSupported)
        captureDevice.smoothAutoFocusEnabled = YES;
    [captureDevice unlockForConfiguration];
    
    return bestSize;
}

- (NSString *) configureForCaptureWithCaller: (MainVC *)caller {
    NSError *error;
    return @"not implemented";
    
    NSLog(@"configure output session");
    assert(captureDevice);
    if (![captureDevice lockForConfiguration:&error])
        return [NSString stringWithFormat:@"error locking camera: %@", error.localizedDescription];
    [captureDevice unlockForConfiguration];
    
    
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
    NSLog(@"*** set camera video orientation");
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
#ifdef doesntmatter
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    captureVideoPreviewLayer.connection.videoOrientation = [UIDevice currentDevice].orientation == UIDeviceOrientationPortrait ?
        AVCaptureVideoOrientationPortrait : AVCaptureVideoOrientationLandscapeRight;
#endif
}

- (void) startCamera {
    NSLog(@"startCamera");
    NSLog(@"  orientation: %ld", (long)connection.videoOrientation);
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

- (BOOL) isCameraOn {
    return connection.enabled;
}

- (BOOL) cameraAvailable:(cameras) c {
    switch (c) {
        case FrontCamera:
            return frontVideoDevice != nil;
        case RearCamera:
            return rearVideoDevice != nil;
        default:
            return NO;
    }
}

- (CGSize) captureSizeFor:(cameras)camera {
    AVCaptureDevice *device;
    switch (camera) {
        case FrontCamera:
            device = frontVideoDevice;
            break;
        case RearCamera:
            device = rearVideoDevice;
            break;
        default:
            NSLog(@"inconceivable: captureSizeFor: not a camera");
            return CGSizeZero;
    }
    CMFormatDescriptionRef ref = device.activeFormat.formatDescription;
    CMVideoDimensions dim = CMVideoFormatDescriptionGetDimensions(ref);
    return CGSizeMake(dim.width, dim.height);
}
@end

#ifdef notneeded

- (void) selectCaptureDevice: (cameras) camera {
    NSLog(@"selectCaptureDevice: %d", camera);
    if ([self cameraAvailable:camera])
    switch (camera) {
        case FrontCamera:
            captureDevice = frontVideoDevice;
            return;
        case RearCamera:
            captureDevice = rearVideoDevice;
            return;
        default:
            captureDevice = nil;
    }
    //captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}
#endif

