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
        if (![self formatHasUsefulSubtype:format])
            continue;
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
//    NSLog(@" --- depthcount: %d", depthCount);
    if (depthCount)
        depthDataAvailable = YES;
    return YES;
}

- (BOOL) formatHasUsefulSubtype: (AVCaptureDeviceFormat *)format {
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
            return NO;
       case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: // We want only the formats with full range
            return YES;
        default:
            NSLog(@"??? Unknown media subtype encountered in format: %@", format);
            return NO;
    }
}

- (BOOL) depthFormatHasUsefulSubtype: (AVCaptureDeviceFormat *)format {
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    //NSLog(@"  mediaSubType %u", (unsigned int)mediaSubType);
    switch (mediaSubType) {
        case kCVPixelFormatType_DisparityFloat16:   // 'hdis'
            //IEEE754-2008 binary16 (half float), describing the normalized shift
            // when comparing two images. Units are 1/meters: ( pixelShift / (pixelFocalLength * baselineInMeters) )
            return NO;
        case kCVPixelFormatType_DisparityFloat32:   //'fdis'
            // IEEE754-2008 binary32 float, describing the normalized shift when comparing two images. Units
            // are 1/meters: ( pixelShift / (pixelFocalLength * baselineInMeters) )
            return NO;
        case kCVPixelFormatType_DepthFloat16:       //'hdep'
            //IEEE754-2008 binary16 (half float), describing the depth (distance to an object) in meters */
            return NO;
        case kCVPixelFormatType_DepthFloat32:       //'fdep'
            // IEEE754-2008 binary32 float, describing the depth (distance to an object) in meters */
            return YES;
      default:
            NSLog(@"??? Unknown depth subtype encountered in format: %@", format);
            return NO;
    }
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
    
    NSLog(@"SSSS setupCameraSessionWithFormat %@", format);
    NSArray<AVCaptureDeviceFormat *> *depthFormats = format.supportedDepthDataFormats;
    AVCaptureDeviceFormat *chosenDepthFormat = nil;
    
    for (AVCaptureDeviceFormat *depthFormat in depthFormats) {
        if (![self depthFormatHasUsefulSubtype:depthFormat])
            continue;
        chosenDepthFormat = depthFormat;    // we will be more selective later.  Use the largest for now
    }
    NSLog(@"SSSS chosen depth format: %@", chosenDepthFormat);
    
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
    [captureSession beginConfiguration];
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput
                                        deviceInputWithDevice:captureDevice
                                        error:&error];
    if (error) {
        NSLog(@"*** startSession, AVCaptureDeviceInput: error %@",
              [error localizedDescription]);
        return;
    }
    
    // insist on our activeFormat selection:
    [captureSession setSessionPreset:AVCaptureSessionPresetInputPriority];
    if ([captureSession canAddInput:videoInput]) {
        [captureSession addInput:videoInput];
    } else {
        NSLog(@"**** could not add camera input");
    }
    
#ifdef DEBUG_CAMERA
    NSLog(@" CCCC setupCameraSessionWithFormat: %@", captureDevice.activeFormat);
    NSLog(@"                       DepthFormat: %@", captureDevice.activeFormat.supportedDepthDataFormats);
#endif
    
    // configure video capture...
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    assert(videoDataOutput);
    videoDataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
    videoDataOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    };
    videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    // ????    dispatch_queue_t videoQueue = dispatch_queue_create("VideoCaptureQueue", NULL);
    // ?????    [videoDataOutput setSampleBufferDelegate:self queue:videoQueue];
    
    if (depthDataAvailable) {
        depthDataOutput = [[AVCaptureDepthDataOutput alloc] init];
        assert(depthDataOutput);
        
        // XXXXXX        depthConnection.enabled = YES;
        
        if ([captureSession canAddOutput:depthDataOutput]) {
            [captureSession addOutput:depthDataOutput];
            [captureSession addOutput:videoDataOutput];
        } else {
            NSLog(@"**** could not add depth data output");
        }
        depthDataOutput.filteringEnabled = YES; // XXXX does this need to be last, after delegate?
        depthDataOutput.alwaysDiscardsLateDepthData = YES;
        dispatch_queue_t depthQueue = dispatch_queue_create("DepthCaptureQueue", DISPATCH_QUEUE_CONCURRENT);
        [depthDataOutput setDelegate:self callbackQueue:depthQueue];
    } else {
        if ([captureSession canAddOutput:videoDataOutput]) {
            [captureSession addOutput:videoDataOutput];
        } else {
            NSLog(@"**** could not add video data output");
        }
        // depthDataByApplyingExifOrientation
        
        // XXXXXX before or after???
    }
    [captureDevice lockForConfiguration:&error];
    if (error) {
        NSLog(@"startSession: could not lock camera: %@",
              [error localizedDescription]);
        return;
    }
    assert(format);
    captureDevice.activeFormat = format;
    if (chosenDepthFormat)
        captureDevice.activeDepthDataFormat = chosenDepthFormat;
    
    // these must be after the activeFormat is set.  there are other conditions, see
    // https://stackoverflow.com/questions/34718833/ios-swift-avcapturesession-capture-frames-respecting-frame-rate
    
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FRAME_RATE );
    [captureDevice unlockForConfiguration];
    
    AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:videoOrientation];
    videoConnection.videoMirrored = YES;
    
    if (depthDataAvailable) {
        AVCaptureConnection *depthConnection = [depthDataOutput connectionWithMediaType:AVMediaTypeDepthData];
        assert(depthConnection);  // we were told it is available
        [depthConnection setVideoOrientation:videoOrientation];
        depthConnection.videoMirrored = YES; // XXXXXX depthDataAvailable;
    }
    
#ifdef NOPE
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.frame = videoView.layer.bounds
    previewLayer.videoGravity = .resizeAspectFill
    videoView.layer.addSublayer(previewLayer)
#endif
    captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    [captureSession commitConfiguration];
    
    syncer = [[AVCaptureDataOutputSynchronizer alloc]
              initWithDataOutputs:
              depthDataAvailable ? @[videoDataOutput, depthDataOutput] : @[videoDataOutput]];
    dispatch_queue_t syncQueue = dispatch_queue_create("CameraSyncQueue", DISPATCH_QUEUE_CONCURRENT);
    [syncer setDelegate:self queue:syncQueue];
    return;
}

#pragma mark - AVCaptureDataOutputSynchronizer (Video + Depth)

// from https://git.fuwafuwa.moe/mindcrime/Source-SCCamera/commit/402429fa18b08aef139b44700fb44a4d6310c076

static int outOfBuffers = 0;
static int lateFrames = 0;
static int frameCount = 0;
static int depthFrames = 0;
static int videoFrames = 0;

- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer
didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)synchronizedDataCollection {
    frameCount++;

    AVCaptureSynchronizedDepthData *syncedDepthData =
        (AVCaptureSynchronizedDepthData *)[synchronizedDataCollection
                                       synchronizedDataForCaptureOutput:depthDataOutput];
    AVDepthData *depthData = nil;
    if (syncedDepthData) {
        if (syncedDepthData.depthDataWasDropped) {
            switch (syncedDepthData.droppedReason) {
                case AVCaptureOutputDataDroppedReasonLateData:
                    lateFrames++;
                    break;
                case AVCaptureOutputDataDroppedReasonOutOfBuffers:
                    outOfBuffers++;
                    NSLog(@"depth buff full");
                    break;
                default:
                    NSLog(@"*** unknown dropped depth reason");
            }
            NSLog(@"BBBB dropped depth.  reason: %ld",
                  (long)syncedDepthData.droppedReason);
            NSLog(@"ssssync: %@", synchronizedDataCollection);
            return;
        } else {
            depthData = syncedDepthData.depthData;
            assert(depthData);
        }
        depthFrames++;
    }
    
    AVCaptureSynchronizedSampleBufferData *syncedVideoData =
        (AVCaptureSynchronizedSampleBufferData *)[synchronizedDataCollection
                                              synchronizedDataForCaptureOutput:videoDataOutput];
    if (!syncedVideoData)
        return;
    if (syncedVideoData.sampleBufferWasDropped) {
//        NSLog(@"BBBB dropped video buffers: %ld", (long)syncedVideoData.droppedReason);
        switch (syncedVideoData.droppedReason) {
            case AVCaptureOutputDataDroppedReasonLateData:
                lateFrames++;
                break;
            case AVCaptureOutputDataDroppedReasonOutOfBuffers:
                NSLog(@"video buff full");
                outOfBuffers++;
                break;
            default:
                NSLog(@"*** unknown dropped frame reason");
        }
//        NSLog(@"BBBB dropped video. %3d, %3d  reason: %ld",
//              lateFrames, outOfBuffers,
//              (long)syncedVideoData.droppedReason);
        return;
    }
    videoFrames++;
#ifdef NOTNEEDED
    if (frameCount % 500 == 0)
        NSLog(@"frames: %5d  v: %5d  dp:%5d   late:%3d  buf:%3d",
              frameCount, videoFrames, depthFrames,
              lateFrames, outOfBuffers);
#endif
    UIImage *capturedImage = [self imageFromSampleBuffer:syncedVideoData.sampleBuffer];
    if (!capturedImage)
        return;
    [(id<videoSampleProcessorDelegate>)videoProcessor processVideoCapture:capturedImage
                                                                    depth:depthData];
}

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    assert(sampleBuffer);
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        NSLog(@" image buffer missing: %@", sampleBuffer);
        return nil;
    }
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    assert(baseAddress);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"image  orientation %@", width > height ? @"panoramic" : @"portrait");
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, BITMAP_OPTS);
    assert(context);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:(CGFloat)1.0
                                   orientation:UIImageOrientationUp];
    CGImageRelease(quartzImage);
    return image;
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
