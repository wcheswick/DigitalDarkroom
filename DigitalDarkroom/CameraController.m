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
#import "Defines.h"


#define MAX_FRAME_RATE  24

@interface CameraController ()

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;
@property (assign)              AVCaptureVideoOrientation videoOrientation;
@property (assign)              UIDeviceOrientation deviceOrientation;

@property (nonatomic, strong)   InputSource *currentCamera;
@end

@implementation CameraController

@synthesize captureSession;
@synthesize delegate;

@synthesize captureDevice;
@synthesize deviceOrientation;
@synthesize captureVideoPreviewLayer;
@synthesize videoOrientation;
@synthesize currentCamera;


- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        delegate = nil;
        captureDevice = nil;
        captureSession = nil;
        currentCamera = nil;
    }
    return self;
}

- (AVCaptureDevice *) captureDeviceForCamera:(BOOL)frontCamera threeD:(BOOL)threeD {
    if (threeD) {
        if (frontCamera) {
            return [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInTrueDepthCamera
                             mediaType: AVMediaTypeDepthData
                             position: AVCaptureDevicePositionFront];
        } else {
            return [AVCaptureDevice
                             defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDualCamera
                             mediaType: AVMediaTypeDepthData
                             position: AVCaptureDevicePositionBack];
        }
    }
    
    AVCaptureDevice *captureDevice = nil;
    if (frontCamera) {
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
    } else {    // rear camera
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

- (BOOL) isCameraAvailable:(InputSource *)source {
    return [self captureDeviceForCamera:source.frontCamera threeD:source.threeDCamera] != nil;
}

- (BOOL) isDepthAvailable: (InputSource *)source {
    if (!IS_CAMERA(source))
        return NO;
    return [self captureDeviceForCamera:source.frontCamera threeD:YES] != nil;
}

- (BOOL) isFlipAvailable:(InputSource *)source {
    if (!IS_CAMERA(source))
        return NO;
    return [self captureDeviceForCamera:!source.frontCamera threeD:source.threeDCamera] != nil;
}

- (void) selectCamera:(InputSource *)source {
    assert(IS_CAMERA(source));
    captureDevice = [self captureDeviceForCamera:source.frontCamera threeD:source.threeDCamera];
    assert(captureDevice);
    currentCamera = source;
}

// I really have no idea what is going on here.  Values were determined by
// experimentation.  The Apple documentation has been ... difficult.

- (AVCaptureVideoOrientation) videoOrientationForDeviceOrientation {
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceUp:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;    // fine, but needs mirroring
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;  // fine, but needs mirroring
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceDown:
        default:
            NSLog(@"************* Inconceivable video orientation: %ld",
                  (long)deviceOrientation);
            return AVCaptureVideoOrientationPortrait;
    }
}

// need an up-to-date deviceorientation
- (void) setupSessionForOrientation: (UIDeviceOrientation) devo {
    NSError *error;
    assert(captureDevice);
    
    deviceOrientation = devo;
    videoOrientation = [self videoOrientationForDeviceOrientation];
    
#ifdef DEBUG_ORIENTATION
    NSLog(@" +++ setupSession: device orientation (%ld): %@",
          (long)deviceOrientation,
          [CameraController dumpDeviceOrientationName:deviceOrientation]);
    NSLog(@"                     video orientaion (%ld): %@",
          videoOrientation,
          deviceOrientationNames[videoOrientation]);
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

    if (currentCamera.threeDCamera) {   // XXX i.e. depth available ?!        
        AVCaptureDepthDataOutput *depthOutput = [[AVCaptureDepthDataOutput alloc] init];
        assert(depthOutput);
        if ([captureSession canAddOutput:depthOutput]) {
            [captureSession addOutput:depthOutput];
        } else {
            NSLog(@"**** could not add data output");
        }
        AVCaptureConnection *depthConnection = [depthOutput connectionWithMediaType:AVMediaTypeDepthData];
        assert(depthConnection);
        [depthConnection setVideoOrientation:videoOrientation];
        depthConnection.videoMirrored = currentCamera.threeDCamera;
#ifdef DEBUG_DEPTH
        NSLog(@" +++ depth video orientation 2: %ld, %@", (long)videoOrientation,
              captureOrientationNames[videoOrientation]);
        NSLog(@"     activeDepthDataFormat: %@", captureDevice.activeDepthDataFormat.formatDescription);
#endif
        
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
        // depthDataByApplyingExifOrientation
        AVCaptureConnection *videoConnection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
        [videoConnection setVideoOrientation:videoOrientation];
        videoConnection.videoMirrored = !currentCamera.threeDCamera;
#ifdef DEBUG_ORIENTATION
        NSLog(@" +++  video orientation: %ld, %@", (long)videoOrientation,
              deviceOrientationNames[videoOrientation]);
#endif

        dataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
        dataOutput.videoSettings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        };
        dataOutput.alwaysDiscardsLateVideoFrames = YES;
        dispatch_queue_t queue = dispatch_queue_create("VideoQueue", NULL);
        [dataOutput setSampleBufferDelegate:delegate queue:queue];
    }

    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];
//    NSLog(@" *** video/depth sessions set up");
}

- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format {
    CMFormatDescriptionRef ref = format.formatDescription;
    // I cannot seem to get the format data adjusted for device orientation.  So we
    // swap them here, if portrait.
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
    CGFloat w, h;
    
    switch (videoOrientation) {
        case AVCaptureVideoOrientationPortrait:
        case AVCaptureVideoOrientationPortraitUpsideDown:
            w = dimensions.height;
            h = dimensions.width;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
        case AVCaptureVideoOrientationLandscapeRight:
            w = dimensions.width;
            h = dimensions.height;
            break;
    }
    return CGSizeMake(w, h);
}

- (BOOL) isNewSize:(CGSize)newSize
   aBetterSizeThan:(CGSize)bestSize
         forTarget:(CGSize)targetSize {
#ifdef DEBUG_CAMERA_CAPTURE_SIZE
    CGSize room = CGSizeMake(targetSize.width-newSize.width,
                             targetSize.height - newSize.height);
    NSLog(@"       checking size %.0f x %.0f (%4.2f)   for %.0f x %.0f  => %.0f %.0f",
          newSize.width, newSize.height,
          newSize.width/newSize.height,
          targetSize.width, targetSize.height,
          room.width, room.height);
#endif
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

- (NSArray *) formatsForSelectedCameraNeeding3D:(BOOL) need3D {
    NSMutableArray *formatList = [[NSMutableArray alloc] init];
    for (AVCaptureDeviceFormat *format in captureDevice.formats) {
        CMFormatDescriptionRef ref = format.formatDescription;
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(ref);
        if (mediaType != kCMMediaType_Video)
            continue;
        if (need3D) {
            if (!format.supportedDepthDataFormats || !format.supportedDepthDataFormats.count)
                continue;
        }
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        //NSLog(@"  mediaSubType %u", (unsigned int)mediaSubType);
        switch (mediaSubType) {
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                continue;
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: // We want only the formats with full range
                break;
            case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: // 'x420'
                /* 2 plane YCbCr10 4:2:0, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
                continue;
            case kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange:  //'x422'
                /* 2 plane YCbCr10 4:2:2, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
                continue;
            case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange: // 'x444'
                /* 2 plane YCbCr10 4:4:4, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
                continue;
            default:
                NSLog(@"??? Unknown media subtype encountered in format: %@", format);
                break;
        }
        [formatList addObject:format];
    }
    return [NSArray arrayWithArray:formatList];
}

- (void) setupCameraWithFormat:(AVCaptureDeviceFormat *) format {
    NSError *error;
    
    [captureDevice lockForConfiguration:&error];
    captureDevice.activeFormat = format;
    
    // these must be after the activeFormat is set.  there are other conditions, see
    // https://stackoverflow.com/questions/34718833/ios-swift-avcapturesession-capture-frames-respecting-frame-rate
    
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    [captureDevice unlockForConfiguration];
}

- (void) startCamera {
#ifdef DEBUG_CAMERA
    NSLog(@">>>>> startCamera");
#endif
    if (![self isCameraOn])
        [captureSession startRunning];
}

- (void) stopCamera {
    if ([self isCameraOn]) {
#ifdef DEBUG_CAMERA
        NSLog(@"<<<<< stopCamera");
#endif
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

static NSString * const deviceOrientationNames[] = {
    @"Unknown",
    @"Portrait",
    @"PortraitUpsideDown",
    @"LandscapeLeft",
    @"LandscapeRight",
    @"FaceUp",
    @"FaceDown"
};

+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o {
    return deviceOrientationNames[o];
}

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
