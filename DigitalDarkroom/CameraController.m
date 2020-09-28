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
@property (assign)              BOOL frontFacingCamera, depthAvailable;

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (assign)              AVCaptureVideoOrientation videoOrientation;

@end

@implementation CameraController

@synthesize captureSession;
@synthesize delegate;
@synthesize imageOrientation;

@synthesize captureDevice, captureSize;
@synthesize frontFacingCamera, depthAvailable;
@synthesize captureVideoPreviewLayer;
@synthesize selectedFormat;
@synthesize videoOrientation;


- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        selectedFormat = nil;
        delegate = nil;
        captureDevice = nil;
        captureSession = nil;
    }
    return self;
}

- (AVCaptureDevice *) captureDevice:(Cameras) camera {
    AVCaptureDevice *captureDevice = nil;
    switch (camera) {
        case FrontCamera:
            frontFacingCamera = YES;
            depthAvailable = NO;
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
            break;
        case Front3DCamera:
            frontFacingCamera = YES;
            depthAvailable = YES;
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInTrueDepthCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionFront];
            break;
        case RearCamera:
            frontFacingCamera = NO;
            depthAvailable = NO;
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionBack];
            if (!captureDevice)
                captureDevice = [AVCaptureDevice
                                 defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                                 mediaType: AVMediaTypeVideo
                                 position: AVCaptureDevicePositionBack];
            break;
        case Rear3DCamera:
            frontFacingCamera = NO;
            depthAvailable = YES;
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionBack];
            break;
       default:
            NSLog(@" *** inconceivable, selected non-existant camera, %d", camera);
            return nil;
    }
    return captureDevice;
}

- (BOOL) isCameraAvailable:(Cameras) camera {
    assert(ISCAMERA(camera));
    return [self captureDevice:camera];
}

- (void) selectCamera:(Cameras) camera {
    captureDevice = [self captureDevice:camera];
    assert(captureDevice);
}

// find and return the largest size that fits into the given size. Return
// Zero size if none works.  This should never happen.
- (CGSize) setupCameraForSize:(CGSize) availableSize {
    assert(captureDevice);
    CGSize capTureSize = CGSizeZero;
    
    selectedFormat = nil;
    for (AVCaptureDeviceFormat *format in captureDevice.formats) {
        CMFormatDescriptionRef ref = format.formatDescription;
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(ref);
        if (mediaType != kCMMediaType_Video)
            continue;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
        if (dimensions.width > availableSize.width || dimensions.height > availableSize.height)
            continue;
        if (selectedFormat) {   // this one fits.  Is it better?
            if (dimensions.width < capTureSize.width || dimensions.height < capTureSize.height)
                continue;
        }
        selectedFormat = format;
        capTureSize = (CGSize){dimensions.width, dimensions.height};
    }
    if (!selectedFormat) {
        NSLog(@"inconceivable: no suitable video found for %.0f x %.0f",
              availableSize.width, availableSize.height);
        return CGSizeZero;
    }
    
    // selectedFormat doesn't work here.  Do it after the session starts.
    return capTureSize;
}

- (void) startSession {
    NSError *error;
    assert(delegate);
    
    // XXX if we already have a session, do we need to shut it down?
    
    if (captureSession) {
        [captureSession stopRunning];
        captureSession = nil;
    }

    captureSession = [[AVCaptureSession alloc] init];
    if (error) {
        NSLog(@"startSession: could not lock camera: %@",
              [error localizedDescription]);
        return;
    }
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput
                                   deviceInputWithDevice:captureDevice
                                   error:&error];
    if (error) {
        NSLog(@"*** startSession, AVCaptureDeviceInput: error %@",
              [error localizedDescription]);
        return;
    }
    if ([captureSession canAddInput:videoInput]) {
        [captureSession addInput:videoInput];
    } else {
        NSLog(@"**** could not add camera input");
    }
    
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    assert(dataOutput);
    dataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
    dataOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    };
    dataOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [dataOutput setSampleBufferDelegate:delegate queue:queue];

    if ([captureSession canAddOutput:dataOutput]) {
        [captureSession addOutput:dataOutput];
    } else {
        NSLog(@"**** could not add data output");
    }
    
    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];

    AVCaptureConnection *videoConnection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
    NSLog(@"capture orientation: %ld", (long)videoConnection.videoOrientation);
    
    //    imageOrientation = frontFacingCamera ? UIImageOrientationDownMirrored : UIImageOrientationDown;
    
    AVCaptureVideoOrientation videoOrientation;
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    switch (deviceOrientation) {
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceDown:
            videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            imageOrientation = frontFacingCamera ? UIImageOrientationUp : UIImageOrientationUp;
            videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationLandscapeRight:
            videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            imageOrientation = frontFacingCamera ? UIImageOrientationUp : UIImageOrientationUp;
            break;
    }
    videoConnection.videoOrientation = videoOrientation;
    videoConnection.videoMirrored = YES;
    videoConnection.enabled = YES;
    
    [captureDevice lockForConfiguration:&error];
    if (captureDevice.lowLightBoostSupported)
        [captureDevice automaticallyEnablesLowLightBoostWhenAvailable];
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
        [captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    if (captureDevice.smoothAutoFocusSupported)
        captureDevice.smoothAutoFocusEnabled = YES;
    captureDevice.activeFormat = selectedFormat;
 
    if (depthAvailable) {
        
    }
    // these must be after the activeFormat is set.  there are other conditions, see
    // https://stackoverflow.com/questions/34718833/ios-swift-avcapturesession-capture-frames-respecting-frame-rate
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    [captureDevice unlockForConfiguration];
    
#ifdef notdef
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    previewLayer.frame = self.view.layer.bounds;
    [self.view.layer addSublayer:previewLayer];


    - (void) setFrame: (CGRect) frame {
    captureVideoPreviewLayer.frame = frame;
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    captureVideoPreviewLayer.connection.videoOrientation = [UIDevice currentDevice].orientation == UIDeviceOrientationPortrait ?
        AVCaptureVideoOrientationPortrait : AVCaptureVideoOrientationLandscapeRight;
}

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
