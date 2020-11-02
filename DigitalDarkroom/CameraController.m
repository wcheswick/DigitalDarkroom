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

@property (assign)              Cameras selectedCamera;

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;
@property (assign)              UIDeviceOrientation deviceOrientation;
@property (strong, nonatomic)   AVCaptureConnection *videoConnection;

@property (nonatomic, strong)   AVCaptureDeviceFormat *selectedFormat;

@property (assign)              AVCaptureVideoOrientation videoOrientation;

@end

@implementation CameraController

@synthesize captureSession;
@synthesize delegate;

@synthesize captureDevice, selectedCamera;
@synthesize deviceOrientation;
@synthesize videoConnection;
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

+ (AVCaptureVideoOrientation) videoOrientationForDeviceOrientation {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;  // fine
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;    // fine
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default:
            NSLog(@"************* Inconceivable video orientation: %ld",
                  (long)deviceOrientation);
            return AVCaptureVideoOrientationPortrait;
    }
}

- (void) setupSessionForCurrentDeviceOrientation {
    NSError *error;
    assert(captureDevice);
    
    deviceOrientation = [[UIDevice currentDevice] orientation];
    videoOrientation = [CameraController videoOrientationForDeviceOrientation];
    
#ifdef notdef
    NSLog(@" +++ device orientation: %ld, %@",
          (long)[[UIDevice currentDevice] orientation],
          [CameraController dumpDeviceOrientation:[[UIDevice currentDevice] orientation]]);
    NSLog(@"  + video orientation 2: %ld, %@", (long)videoOrientation,
          captureOrientationNames[videoOrientation]);
#endif
    
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

    if (IS_3D_CAMERA(selectedCamera)) {   // XXX i.e. depth available ?!        
        AVCaptureDepthDataOutput *depthOutput = [[AVCaptureDepthDataOutput alloc] init];
        assert(depthOutput);
        if ([captureSession canAddOutput:depthOutput]) {
            [captureSession addOutput:depthOutput];
        } else {
            NSLog(@"**** could not add data output");
        }
        videoConnection = [depthOutput connectionWithMediaType:AVMediaTypeVideo];
        [videoConnection setVideoOrientation:videoOrientation];

        dispatch_queue_t queue = dispatch_queue_create("DepthQueue", NULL);
        [depthOutput setDelegate:delegate callbackQueue:queue];
        depthOutput.filteringEnabled = YES;
    } else {
        AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
        assert(dataOutput);
        if ([captureSession canAddOutput:dataOutput]) {
            [captureSession addOutput:dataOutput];
        } else {
            NSLog(@"**** could not add data output");
        }
        videoConnection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
        [videoConnection setVideoOrientation:videoOrientation];
        
        dataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
        dataOutput.videoSettings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        };
        dataOutput.alwaysDiscardsLateVideoFrames = YES;
        dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
        [dataOutput setSampleBufferDelegate:delegate queue:queue];
    }
    NSLog(@"111 activeDepthDataFormat: %@",
          [self dumpFormatType:
           CMFormatDescriptionGetMediaSubType(captureDevice.activeDepthDataFormat.formatDescription)]);

    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];
    
    NSLog(@"222  activeDepthDataFormat: %@",
          [self dumpFormatType:
           CMFormatDescriptionGetMediaSubType(captureDevice.activeDepthDataFormat.formatDescription)]);
}

// find and return the largest size that fits into the given size. Return
// Zero size if none works.  This should never happen.
- (CGSize) setupCameraForSize:(CGSize) availableSize
                  displayMode:(DisplayMode_t)displayMode {
    NSError *error;
    
    assert(captureDevice);
    CGSize captureSize = CGSizeZero;
    
    selectedFormat = nil;
    NSArray *availableFormats = captureDevice.formats;
    
    NSLog(@" @@@@ fitting into %.0f x %.0f %@",
          availableSize.width, availableSize.height,
          UIDeviceOrientationIsPortrait(deviceOrientation) ? @"portrait" : @"");
    
    for (AVCaptureDeviceFormat *format in availableFormats) {
        CMFormatDescriptionRef ref = format.formatDescription;
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(ref);
        if (mediaType != kCMMediaType_Video)
            continue;
        
        if (IS_3D_CAMERA(selectedCamera)) { // if we need depth-capable formats only
            if (!format.supportedDepthDataFormats)
                continue;
            if (!format.supportedDepthDataFormats.count)
                continue;
        }
        // I cannot seem to get the format data adjusted for device orientation.  So we
        // swap them here, if portrait.
        
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);        CGFloat w, h;
        if (UIDeviceOrientationIsPortrait(deviceOrientation)) {
            w = dimensions.height;
            h = dimensions.width;
        } else {
            w = dimensions.width;
            h = dimensions.height;
        }
        NSLog(@"   adj   dimensions: %.0f x %.0f", w, h);

        if (w > availableSize.width || h > availableSize.height)
            break;
        if (displayMode == small)
            if (dimensions.height > availableSize.height/2.0)
                break;
        selectedFormat = format;
        captureSize = (CGSize){w, h};
    }
    if (!selectedFormat) {
        NSLog(@"inconceivable: no suitable video found for %.0f x %.0f",
              availableSize.width, availableSize.height);
        return CGSizeZero;
    }

    [captureDevice lockForConfiguration:&error];
    captureDevice.activeFormat = selectedFormat;
    // these must be after the activeFormat is set.  there are other conditions, see
    // https://stackoverflow.com/questions/34718833/ios-swift-avcapturesession-capture-frames-respecting-frame-rate
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    //NSLog(@"-- format selected: %@", selectedFormat.description);
    [captureDevice unlockForConfiguration];
    
    if (IS_3D_CAMERA(selectedCamera)) {
        AVCaptureDeviceFormat *depthCaptureFormat = nil;
        // useful source: https://www.raywenderlich.com/5999357-video-depth-maps-tutorial-for-ios-getting-started
        
        for (AVCaptureDeviceFormat *format in captureDevice.activeFormat.supportedDepthDataFormats) {
            FourCharCode pixelFormatType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
            if (pixelFormatType == kCVPixelFormatType_DepthFloat32) {
                depthCaptureFormat = format;
            } else if (pixelFormatType == kCVPixelFormatType_DepthFloat16) {
                if (!depthCaptureFormat)
                    depthCaptureFormat = format;
            }
        }
        if (!depthCaptureFormat) {
            NSLog(@"inconceivable, no capture format found");
            return CGSizeZero;
        }
        
        [captureDevice lockForConfiguration:&error];
        captureDevice.activeDepthDataFormat = depthCaptureFormat;
        [captureDevice unlockForConfiguration];
    }
    return captureSize;
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

#ifdef XXX
static NSString * const sectionTitles[] = {
        [0] = @"    Cameras",
        [1] = @"    Samples",
        [2] = @"    From library",
    };
#endif

static NSString * const captureOrientationNames[] = {
    @"(zero)",
    @"Portrait",
    @"PortraitUpsideDown",
    @"LandscapeRight",
    @"LandscapeLeft",
};

static NSString * const deviceOrientationNames[] = {
    @"Unknown",
    @"Portrait",
    @"PortraitUpsideDown",
    @"LandscapeLeft",
    @"LandscapeRight",
    @"FaceUp",
    @"FaceDown"
};

static NSString * const imageOrientation[] = {
    @"default",            // default orientation
    @"rotate 180",
    @"rotate 90 CCW",
    @"rotate 90 CW",
    @"Up Mirrored",
    @"Down Mirrored",
    @"Left Mirrored",
    @"Right Mirrored"
};

- (NSString *) dumpFormatType:(OSType) t {
    switch (t) {
        case 1751411059:
            return @"kCVPixelFormatType_DisparityFloat16";
       case 1717856627:
            return @"kCVPixelFormatType_DisparityFloat32";
        case 1751410032:
            return @"kCVPixelFormatType_DepthFloat16";
        case 1717855600:
            return @"kCVPixelFormatType_DepthFloat32";
    }
    return [NSString stringWithFormat:@"%d", t];
}

@end
