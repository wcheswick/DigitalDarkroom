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

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (assign)              Cameras selectedCamera;
@property (assign)              AVCaptureVideoOrientation videoOrientation;

@end

@implementation CameraController

@synthesize captureSession;
@synthesize delegate;
@synthesize imageOrientation;

@synthesize captureDevice, selectedCamera;
@synthesize displaySize;
@synthesize captureVideoPreviewLayer;
@synthesize selectedFormat;
@synthesize videoOrientation;


- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        selectedFormat = nil;
        selectedCamera = NotACamera;
        delegate = nil;
        captureDevice = nil;
        captureSession = nil;
        displaySize = CGSizeZero;
    }
    return self;
}

- (AVCaptureDevice *) captureDeviceForCamera:(Cameras) camera {
    AVCaptureDevice *captureDevice = nil;
    switch (camera) {
        case FrontCamera:
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
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInTrueDepthCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionFront];
            break;
        case RearCamera:
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
            captureDevice = [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                             mediaType: AVMediaTypeVideo
                             position: AVCaptureDevicePositionBack];
            break;
       default:
            NSLog(@" *** inconceivable, selected non-existant camera, %d", camera);
            return nil;
    }
    //NSLog(@"***** captureDevice: cam %d %@", camera, captureDevice.activeFormat.supportedDepthDataFormats);
    return captureDevice;
}

- (BOOL) isCameraAvailable:(Cameras) camera {
    assert(ISCAMERA(camera));
    return [self captureDeviceForCamera:camera];
}

- (void) selectCamera:(Cameras) camera {
    captureDevice = [self captureDeviceForCamera:camera];
    assert(captureDevice);
    selectedCamera = camera;
    NSLog(@" -- camera selected: %d", selectedCamera);
}

// find and return the largest size that fits into the given size. Return
// Zero size if none works.  This should never happen.
- (CGSize) setupCameraForSize:(CGSize) availableSize {
    assert(captureDevice);
    CGSize captureSize = CGSizeZero;
    
    selectedFormat = nil;
    NSArray *availableFormats = captureDevice.formats;
#ifdef notdef
    AVCaptureDeviceFormat *format = [availableFormats objectAtIndex:0];
    if (format.supportedDepthDataFormats != nil && format.supportedDepthDataFormats.count) { // use the 3D format list
        availableFormats = format.supportedDepthDataFormats;
    }
#endif
    
    for (AVCaptureDeviceFormat *format in availableFormats) {
        if (IS_3D_CAMERA(selectedCamera)) {
            //NSLog(@"-- format selected: %@", format.description);
            //NSLog(@"-- format selected: %@", format.supportedDepthDataFormats);
            if (!format.supportedDepthDataFormats || format.supportedDepthDataFormats.count == 0)
                continue;
            
       }

        CMFormatDescriptionRef ref = format.formatDescription;
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(ref);
        if (mediaType != kCMMediaType_Video)
            continue;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
//            NSLog(@"----- depth data formats: %@",format.supportedDepthDataFormats);
//            NSLog(@"      dimensions: %.0d x %.0d", dimensions.width, dimensions.height);
        if (dimensions.width > availableSize.width || dimensions.height > availableSize.height)
            continue;
        if (selectedFormat) {   // this one fits.  Is it better?
            if (dimensions.width <= captureSize.width || dimensions.height <= captureSize.height)
                continue;
        }
        selectedFormat = format;
        captureSize = (CGSize){dimensions.width, dimensions.height};
    }
    if (!selectedFormat) {
        NSLog(@"inconceivable: no suitable video found for %.0f x %.0f",
              availableSize.width, availableSize.height);
        return CGSizeZero;
    }
    
    // selectedFormat doesn't work here.  Do it after the session starts.
    //NSLog(@"-- format selected: %@", selectedFormat.description);
    return captureSize;
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

    AVCaptureConnection *videoConnection;
    if (IS_3D_CAMERA(selectedCamera)) {   // XXX i.e. depth available ?!
        // useful source: https://www.raywenderlich.com/5999357-video-depth-maps-tutorial-for-ios-getting-started
        
        AVCaptureDepthDataOutput *depthOutput = [[AVCaptureDepthDataOutput alloc] init];
        assert(depthOutput);
        dispatch_queue_t queue = dispatch_queue_create("DepthQueue", NULL);
        [depthOutput setDelegate:delegate callbackQueue:queue];
        depthOutput.filteringEnabled = YES;
        if ([captureSession canAddOutput:depthOutput]) {
            [captureSession addOutput:depthOutput];
        } else {
            NSLog(@"**** could not add data output");
        }
        videoConnection = [depthOutput connectionWithMediaType:AVMediaTypeVideo];
    } else {
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
        videoConnection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
    }
    
    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];

    //NSLog(@"capture orientation: %ld", (long)videoConnection.videoOrientation);
    
//    videoConnection.videoOrientation = [CameraController videoOrientationForDeviceOrientation];
    // for some reason, this orientation setting works for both landscape settings. Why? Beats me.
    // why is the cast ok?  Again, dunno.
    
    videoConnection.videoOrientation = (AVCaptureVideoOrientation)[MainVC imageOrientationForDeviceOrientation];
    //videoConnection.videoMirrored = YES;
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
    if ([self isCameraOn]) {
        NSLog(@"stopping camera");
        [captureSession stopRunning];
    }
}

- (BOOL) isCameraOn {
    if (!captureSession)
        return NO;
    return captureSession.isRunning;
}

+ (AVCaptureVideoOrientation) videoOrientationForDeviceOrientation {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    switch (deviceOrientation) {
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceDown:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeLeft:
            //imageOrientation = FRONT_FACING_CAMERA ? UIImageOrientationUp : UIImageOrientationUp;
            return AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationLandscapeRight:
            // imageOrientation = FRONT_FACING_CAMERA ? UIImageOrientationUp : UIImageOrientationUp;
            return AVCaptureVideoOrientationLandscapeLeft;
    }
}

@end
