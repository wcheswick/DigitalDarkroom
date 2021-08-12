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

@property (nonatomic, strong)   AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong)   AVCaptureDepthDataOutput *depthDataOutput;
@property (nonatomic, strong)   AVCaptureDataOutputSynchronizer *syncer;

@property (assign)              BOOL depthCaptureEnabled;

@end

@implementation CameraController

@synthesize videoDataOutput, depthDataOutput, syncer;

@synthesize captureSession;
@synthesize videoProcessor;

@synthesize depthDataAvailable;

@synthesize captureDevice;
@synthesize deviceOrientation;
@synthesize captureVideoPreviewLayer;
@synthesize videoOrientation;
@synthesize formatList;

- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        captureDevice = nil;
        captureSession = nil;
        videoOrientation = -1;  // not initialized
        formatList = [[NSMutableArray alloc] init];
    }
    return self;
}


- (BOOL) cameraDeviceOnFront:(BOOL)onFront {
    AVCaptureDeviceDiscoverySession *discSess = [AVCaptureDeviceDiscoverySession
                                                 discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTrueDepthCamera,
                                                                                   AVCaptureDeviceTypeBuiltInDualWideCamera,
                                                                                   AVCaptureDeviceTypeBuiltInTripleCamera,
                                                                                   AVCaptureDeviceTypeBuiltInDualCamera,
                                                                                   AVCaptureDeviceTypeBuiltInWideAngleCamera,
                                                                                   AVCaptureDeviceTypeBuiltInUltraWideCamera]
                                                 mediaType:AVMediaTypeVideo
                                                 position:onFront ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
//    NSLog(@" discovered devices: %@", discSess.devices);
//    NSLog(@"        device sets: %@", discSess.supportedMultiCamDeviceSets);
    if (!discSess.devices.count)
        return NO;
    
    captureDevice = discSess.devices[0];
    //    NSLog(@" top device: %@", activeDevice);
    //    NSLog(@"    formats: %@", activeDevice.formats);    // need to select supports depth
    [formatList removeAllObjects];
    int depthCount = 0;
    for (AVCaptureDeviceFormat *format in captureDevice.formats) {
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        //NSLog(@"  mediaSubType %u", (unsigned int)mediaSubType);
        switch (mediaSubType) {
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: // 'x420'
                /* 2 plane YCbCr10 4:2:0, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
            case kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange:  //'x422'
                /* 2 plane YCbCr10 4:2:2, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
            case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange: // 'x444'
                /* 2 plane YCbCr10 4:4:4, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
                continue;
           case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: // We want only the formats with full range
                break;
            default:
                NSLog(@"??? Unknown media subtype encountered in format: %@", format);
                continue;
        }
        if (format.supportedDepthDataFormats &&
            format.supportedDepthDataFormats.count > 0)
            depthCount++;
#ifdef NOT
        NSLog(@"DDDDDD format: %@", format.formatDescription);
        NSArray<AVCaptureDeviceFormat *> *depthFormats = format.supportedDepthDataFormats;
        NSLog(@"       depth formats: %@", depthFormats);
#endif
        [formatList addObject:format];
    }
    assert(formatList.count);   // we need at least one format!
    if (!formatList.count) {
        return NO;
    }
    NSLog(@" --- depthcount: %d", depthCount);
    return YES;
}

- (BOOL) selectCameraOnSide:(BOOL)front {
#ifdef DEBUG_CAMERA
    NSLog(@"CCC selecting camera on side %@", front ? @"Front" : @"Rear ");
#endif
    if (![self cameraDeviceOnFront:front])
        return NO;
    return YES;
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

- (void) updateOrientationTo:(UIDeviceOrientation) devo {
    deviceOrientation = devo;
    videoOrientation = [self videoOrientationForDeviceOrientation];
}

// need an up-to-date deviceorientation
// need capturedevice set
- (void) setupCameraSessionWithFormat:(AVCaptureDeviceFormat *)format {
    NSError *error;
    assert(captureDevice);  // must have been selected, but not configured, before
    depthDataAvailable = (format.supportedDepthDataFormats &&
                          format.supportedDepthDataFormats.count > 0);
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
    }
    captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput
                                        deviceInputWithDevice:captureDevice
                                        error:&error];
    if (error) {
        NSLog(@"*** startSession, AVCaptureDeviceInput: error %@",
              [error localizedDescription]);
        return;
    }
    
#ifdef DEBUG_CAMERA
    NSLog(@" CCCC setupCameraSessionWithFormat: %@", captureDevice.activeFormat);
    NSLog(@"                       DepthFormat: %@", captureDevice.activeFormat.supportedDepthDataFormats);
#endif

    [captureDevice lockForConfiguration:&error];
    if (error) {
        NSLog(@"startSession: could not lock camera: %@",
              [error localizedDescription]);
        return;
    }
    assert(format);
    captureDevice.activeFormat = format;

    // these must be after the activeFormat is set.  there are other conditions, see
    // https://stackoverflow.com/questions/34718833/ios-swift-avcapturesession-capture-frames-respecting-frame-rate
    
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    [captureDevice unlockForConfiguration];

    // insist on our activeFormat selection:
    [captureSession setSessionPreset:AVCaptureSessionPresetInputPriority];
    if ([captureSession canAddInput:videoInput]) {
        [captureSession addInput:videoInput];
    } else {
        NSLog(@"**** could not add camera input");
    }

    // configure video capture...
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    assert(videoDataOutput);
    if ([captureSession canAddOutput:videoDataOutput]) {
        [captureSession addOutput:videoDataOutput];
    } else {
        NSLog(@"**** could not add video data output");
    }
    // depthDataByApplyingExifOrientation
    
    AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:videoOrientation];
    videoConnection.videoMirrored = YES;
#ifdef DEBUG_ORIENTATION
    NSLog(@" +++  video orientation: %ld, %@", (long)videoOrientation,
          deviceOrientationNames[videoOrientation]);
#endif
    videoDataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
    videoDataOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    };
    videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t videoQueue = dispatch_queue_create("VideoCaptureQueue", NULL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoQueue];

    if ([captureSession canAddOutput:videoDataOutput]) {
        [captureSession addOutput:videoDataOutput];
//        [self _enableVideoMirrorForDevicePosition:devicePosition];
    }

    depthDataOutput = [[AVCaptureDepthDataOutput alloc] init];
    assert(depthDataOutput);
    [[depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:NO];
    if ([captureSession canAddOutput:depthDataOutput]) {
        [captureSession addOutput:depthDataOutput];
        dispatch_queue_t depthQueue = dispatch_queue_create("DepthCaptureQueue", NULL);
        [depthDataOutput setDelegate:self callbackQueue:depthQueue];
        
        AVCaptureConnection *depthConnection = [depthDataOutput connectionWithMediaType:AVMediaTypeDepthData];
        depthConnection.videoMirrored = NO;
        depthDataAvailable = (depthConnection != nil);
        
        if (depthDataAvailable) {
            [depthConnection setVideoOrientation:videoOrientation];
            depthConnection.videoMirrored = YES; // XXXXXX depthDataAvailable;
    #ifdef DEBUG_DEPTH
            NSLog(@" +++ depth video orientation 2: %ld, %@", (long)videoOrientation,
                  captureOrientationNames[videoOrientation]);
            NSLog(@"     activeDepthDataFormat: %@", captureDevice.activeDepthDataFormat.formatDescription);
    #endif
            depthDataOutput.filteringEnabled = YES; // XXXX does this need to be last, after delegate?
        }
    }

#ifdef NOTES
    _depthCaptureEnabled = enabled;
    [[_depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:enabled];
    if (enabled) {
        _dataOutputSynchronizer =
            [[AVCaptureDataOutputSynchronizer alloc] initWithDataOutputs:@[ _videoDataOutput, _depthDataOutput ]];
        [_dataOutputSynchronizer setDelegate:self queue:_performer.queue];
    } else {
        _dataOutputSynchronizer = nil;
    }
    
    - (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation
    {
        SCTraceStart();
        // It is not neccessary call these changes on private queue, because is is just only data output configuration.
        // It should be called from manged capturer queue to prevent lock capture session in two different(private and
        // managed capturer) queues that will cause the deadlock.
        SCLogVideoStreamerInfo(@"setVideoOrientation oldOrientation:%lu newOrientation:%lu",
                               (unsigned long)_videoOrientation, (unsigned long)videoOrientation);
        _videoOrientation = videoOrientation;
        AVCaptureConnection *connection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        connection.videoOrientation = _videoOrientation;
    }

#endif
    
    syncer = [[AVCaptureDataOutputSynchronizer alloc]
                                               initWithDataOutputs:
              depthDataAvailable ? @[videoDataOutput, depthDataOutput] : @[videoDataOutput]];
    dispatch_queue_t syncQueue = dispatch_queue_create("CameraSyncQueue", NULL);
    [syncer setDelegate:self queue:syncQueue];

#ifdef DEBUG_CAMERA
    NSLog(@"synchronized session set up");
#endif

    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];

    return;
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)videoSampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    [(id<videoSampleProcessorDelegate>)videoProcessor processSampleBuffer:videoSampleBuffer
                                                                    depth:nil];
}

static int droppedCount = 0;

- (void)captureOutput:(AVCaptureOutput *)output
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    droppedCount++;
}


#pragma mark - AVCaptureDataOutputSynchronizer (Video + Depth)

// from https://git.fuwafuwa.moe/mindcrime/Source-SCCamera/commit/402429fa18b08aef139b44700fb44a4d6310c076

- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer
    didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)synchronizedDataCollection {
    
//    NSLog(@" SSSS didOutputSynchronizedDataCollection");
    AVCaptureSynchronizedDepthData *syncedDepthData = (AVCaptureSynchronizedDepthData *)[synchronizedDataCollection
        synchronizedDataForCaptureOutput:depthDataOutput];
    AVDepthData *depthData = nil;
    if (syncedDepthData && !syncedDepthData.depthDataWasDropped) {
        depthData = syncedDepthData.depthData;
    }

    AVCaptureSynchronizedSampleBufferData *syncedVideoData =
        (AVCaptureSynchronizedSampleBufferData *)[synchronizedDataCollection
            synchronizedDataForCaptureOutput:videoDataOutput];
    if (syncedVideoData && !syncedVideoData.sampleBufferWasDropped) {
        CMSampleBufferRef videoSampleBuffer = syncedVideoData.sampleBuffer;
        [(id<videoSampleProcessorDelegate>)videoProcessor processSampleBuffer:videoSampleBuffer
                                                                        depth:depthData];
    }
}

- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format {
    CMFormatDescriptionRef ref = format.formatDescription;
    // I cannot seem to get the format data adjusted for device orientation.  So we
    // swap them here, if portrait.
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
    CGFloat w=0, h=0;
    
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
        case -1:
            NSLog(@"inconceivable: orientation not initialized");
            break;
        default:
            NSLog(@"Unexpected video orientation: %ld", (long)videoOrientation);
            NSLog(@"inconceivable!");
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

#ifdef OLD
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
#endif

- (void) startCamera {
    if (!captureSession) {
        NSLog(@"startcamera: no capture session yet");
        return;
    }
    if (!captureSession.isRunning) {
        [captureSession startRunning];
#ifdef DEBUG_CAMERA
        NSLog(@"CCCC turning camera on");
#endif
    }
}

- (void) stopCamera {
    if (captureSession.isRunning) {
#ifdef DEBUG_CAMERA
        NSLog(@"CCCC turning camera off");
#endif
        [captureSession stopRunning];
    }
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
