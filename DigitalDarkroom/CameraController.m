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


#define MAX_FRAME_RATE  24

@interface CameraController ()

@property (nonatomic, strong)   AVCaptureSession *captureSession;
@property (nonatomic, strong)   AVCaptureDeviceFormat *selectedFormat;
@property (assign)              BOOL frontCamera;

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (strong, nonatomic)   AVCaptureConnection *connection;
@property (assign)              AVCaptureVideoOrientation videoOrientation;

@end

@implementation CameraController

@synthesize captureSession;
@synthesize delegate;
@synthesize imageOrientation;

@synthesize captureDevice;
@synthesize frontCamera;
@synthesize captureVideoPreviewLayer;
@synthesize connection;
@synthesize selectedFormat;
@synthesize videoOrientation;


- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        connection = nil;
        selectedFormat = nil;
        delegate = nil;
        captureDevice = nil;
        captureSession = nil;
    }
    return self;
}

- (AVCaptureDevice *) captureDevice:(BOOL) front {
    AVCaptureDevice *captureDevice = nil;
    if (front) {
        captureDevice = [AVCaptureDevice
                         defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                         mediaType: AVMediaTypeVideo
                         position: AVCaptureDevicePositionFront];
        if (!captureDevice) {
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionFront];
        }
    } else {
        captureDevice = [AVCaptureDevice
                         defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                         mediaType: AVMediaTypeVideo
                         position: AVCaptureDevicePositionBack];
        if (!captureDevice)
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionBack];
    }
    return captureDevice;
}

- (BOOL) isCameraAvailable:(cameras) camera {
    assert(ISCAMERA(camera));
    return [self captureDevice:(camera == FrontCamera)];
}

- (void) selectCamera:(cameras) camera {
    frontCamera = (camera == FrontCamera);
    captureDevice = [self captureDevice:frontCamera];
    assert(captureDevice);
}

// find and return the largest size that fits into the given size. Return
// Zero size if none works.  This should never happen.
- (CGSize) setupCameraForSize:(CGSize) availableSize {
    assert(captureDevice);
    CGSize bestSize = CGSizeZero;
    
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
    
    NSError *error;
    if (![captureDevice lockForConfiguration:&error]) {
        NSLog(@"** could not lock video camera: %@", [error localizedDescription]);
        return CGSizeZero;
    };
    captureDevice.activeFormat = bestFormat;
    [captureDevice unlockForConfiguration];
    return bestSize;
}

- (void) startSession {
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    switch (deviceOrientation) {    // XXXX portrait and others
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            imageOrientation = frontCamera ? UIImageOrientationDownMirrored : UIImageOrientationUp;
            break;
        case UIDeviceOrientationFaceUp:              // Device oriented flat, face up
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            imageOrientation = frontCamera ? UIImageOrientationUpMirrored : UIImageOrientationDown;
            break;
        case UIDeviceOrientationFaceDown :            // Device oriented flat, face down
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top        default:
            imageOrientation = frontCamera ? UIImageOrientationDownMirrored : UIImageOrientationDown;
    }
    NSLog(@"orientation: device: %ld  image:%ld",
          (long)deviceOrientation, (long)imageOrientation);

    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput
                                   deviceInputWithDevice:captureDevice
                                   error:&error];
    if (error) {
        NSLog(@"*** startSession, AVCaptureDeviceInput: error %@",
              [error localizedDescription]);
        return;
    }

    captureSession = [[AVCaptureSession alloc] init];
    assert(delegate);
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    assert(videoOutput);
    
    [captureSession beginConfiguration];
    for (AVCaptureDeviceInput *input in captureSession.inputs)
        [captureSession removeInput:input];
    
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession addInput:input];
    [captureSession commitConfiguration];

    videoOutput.automaticallyConfiguresOutputBufferDimensions = YES;
    videoOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    };
    
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [videoOutput setSampleBufferDelegate:delegate queue:queue];
    videoOutput.alwaysDiscardsLateVideoFrames = YES;

    [captureSession beginConfiguration];
    if (![captureSession canAddOutput:videoOutput]) {
        NSLog(@"** inconceivable, cannot add data output");
        captureSession = nil;
        return;
    }
    [captureSession addOutput:videoOutput];
    [captureSession commitConfiguration];
    
#ifdef doesntmatter
- (void) setFrame: (CGRect) frame {
    captureVideoPreviewLayer.frame = frame;
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    captureVideoPreviewLayer.connection.videoOrientation = [UIDevice currentDevice].orientation == UIDeviceOrientationPortrait ?
        AVCaptureVideoOrientationPortrait : AVCaptureVideoOrientationLandscapeRight;
}
#endif

#ifdef notyet
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, 24 );
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

    connection = [videoOutput.connections objectAtIndex:0];
    if (connection.supportsVideoMirroring)
        connection.videoMirrored = YES;
    connection.enabled = NO;
    connection.videoOrientation = UIImageOrientationLeftMirrored;
    
    let videoConnection = videoOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait
    
    assert(captureVideoPreviewLayer);
    assert(delegate);
    NSLog(@"configure configureVideoCapture");
    captureVideoPreviewLayer.session = captureSession;
    return nil;
#endif

}

- (void) startCamera {
    NSLog(@"startCamera");
    NSLog(@"  orientation: %ld", (long)connection.videoOrientation);
    if (![self isCameraOn])
        [captureSession startRunning];
}

- (void) stopCamera {
    NSLog(@"stopCamera");
    if ([self isCameraOn])
        [captureSession stopRunning];
}

- (BOOL) isCameraOn {
    assert(captureSession);
   return captureSession.isRunning;
}

@end
