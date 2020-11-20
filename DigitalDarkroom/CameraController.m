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
                             mediaType: AVMediaTypeDepthData
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
                             mediaType: AVMediaTypeDepthData
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
    
    NSLog(@" +++ device orientation: %ld, %@",
          (long)[[UIDevice currentDevice] orientation],
          [CameraController dumpDeviceOrientationNames:[[UIDevice currentDevice]
                                                        orientation]]);
    
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
        NSLog(@"depth output: %@", depthOutput);
        if ([captureSession canAddOutput:depthOutput]) {
            [captureSession addOutput:depthOutput];
        } else {
            NSLog(@"**** could not add data output");
        }
        videoConnection = [depthOutput connectionWithMediaType:AVMediaTypeDepthData];
        assert(videoConnection);
        [videoConnection setVideoOrientation:videoOrientation];
        NSLog(@" +++ depth video orientation 2: %ld, %@", (long)videoOrientation,
              captureOrientationNames[videoOrientation]);
        NSLog(@"     activeDepthDataFormat: %@",
              [self dumpFormatType:
               CMFormatDescriptionGetMediaSubType(captureDevice.activeDepthDataFormat.formatDescription)]);

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
        NSLog(@" +++  video orientation: %ld, %@", (long)videoOrientation,
              captureOrientationNames[videoOrientation]);

        dataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
        dataOutput.videoSettings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        };
        dataOutput.alwaysDiscardsLateVideoFrames = YES;
        dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
        [dataOutput setSampleBufferDelegate:delegate queue:queue];
    }

    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];
}

- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format {
    CMFormatDescriptionRef ref = format.formatDescription;
    // I cannot seem to get the format data adjusted for device orientation.  So we
    // swap them here, if portrait.
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
    CGFloat w, h;
    
    if (UIDeviceOrientationIsPortrait(deviceOrientation)) {
        w = dimensions.height;
        h = dimensions.width;
        //NSLog(@" ***********         dimensions: %.0f x %.0f", w, h);
    } else {
        w = dimensions.width;
        h = dimensions.height;
        //NSLog(@" ***********   adj   dimensions: %.0f x %.0f", w, h);
    }
    return CGSizeMake(w, h);
}

- (BOOL) isNewSize:(CGSize)newSize
   aBetterSizeThan:(CGSize)bestSize
         forTarget:(CGSize)targetSize {
    if (targetSize.width == 0) { // just find the largest size we have
        if (newSize.width < bestSize.width && newSize.height < bestSize.height)
            return NO;
    } else {
        // it would be nice to fit in the size given. But if we have no size, use it
        // HRSI = high res still image dimensions.
        //NSLog(@"  format: %@", format);
        if (newSize.width > targetSize.width || newSize.height > targetSize.height) {
            if (bestSize.width == 0)
                return YES;
            else
                return NO;
        }
        if (newSize.width <= bestSize.width && newSize.height <= bestSize.height)    // we have better already
            return NO;
    }
    return YES;
}

// find and return the largest size that fits into the given size. Return
// Zero size if none works.  This should never happen.

// Determine the capture image size. If availableSize is zero, return the largest
// size we have. If the height is zero, fit the largest to the width.  If both height and
// width are non-zero, make it fit there.

- (CGSize) setupCameraForSize:(CGSize) availableSize
                  displayMode:(DisplayMode_t)displayMode {
    NSError *error;

    assert(captureDevice);
    NSArray *availableFormats = captureDevice.formats;
    CGSize captureSize = CGSizeZero;
    selectedFormat = nil;
//    AVCaptureDeviceFormat *depthFormat = nil;
    
    for (AVCaptureDeviceFormat *format in availableFormats) {
        CMFormatDescriptionRef ref = format.formatDescription;
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(ref);
        if (mediaType != kCMMediaType_Video)
            continue;
        if (IS_3D_CAMERA(selectedCamera)) { // if we need depth-capable formats only
            if (!format.supportedDepthDataFormats)
                continue;
            if (format.supportedDepthDataFormats.count == 0)
                continue;
        }
        
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        //NSLog(@"  mediaSubType %u", (unsigned int)mediaSubType);
        switch (mediaSubType) {
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                continue;
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: // We want only the formats with full range
            default:
//                NSLog(@"Unknown media subtype encountered in format: %@", format);
                break;
        }
        
        CGSize newSize = [self sizeForFormat:format];
        if (![self isNewSize:newSize aBetterSizeThan:captureSize forTarget:availableSize])
            continue;
        captureSize = newSize;
        selectedFormat = format;
    }
    
    if (!selectedFormat) {
        NSLog(@"******* inconceivable: no suitable video found for %.0f x %.0f",
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
    return captureSize;
}

- (void) startCamera {
    NSLog(@"+++++ startCamera");
    if (![self isCameraOn])
        [captureSession startRunning];
}

- (void) stopCamera {
    if ([self isCameraOn]) {
        NSLog(@"----- stopCamera");
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

+ (NSString *) dumpDeviceOrientationNames: (UIDeviceOrientation) o {
    return deviceOrientationNames[o];
}

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
