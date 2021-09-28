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

@interface CameraController ()

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;
@property (assign)              AVCaptureVideoOrientation videoOrientation;
@property (assign)              UIDeviceOrientation deviceOrientation;

@property (nonatomic, strong)   AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong)   AVCaptureDepthDataOutput *depthDataOutput;
@property (nonatomic, strong)   AVCaptureDataOutputSynchronizer *outputSynchronizer;

@property (nonatomic, strong)   Frame *capturedFrame;
@property (assign)              BOOL depthCaptureEnabled;

@end

@implementation CameraController

@synthesize videoDataOutput, depthDataOutput, outputSynchronizer;

@synthesize captureSession;
@synthesize videoProcessor;

@synthesize depthDataAvailable;

@synthesize captureDevice;
@synthesize deviceOrientation;
@synthesize captureVideoPreviewLayer;
@synthesize videoOrientation;
@synthesize formatList;
@synthesize capturedFrame;
@synthesize stats;

- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        captureDevice = nil;
        captureSession = nil;
        capturedFrame = nil;
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

+ (BOOL) depthFormat:(AVCaptureDeviceFormat *)depthFormat
       isSuitableFor:(AVCaptureDeviceFormat *)format {
    // is subtype what we want?
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(depthFormat.formatDescription);
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
            break;
      default:
            NSLog(@"??? Unknown depth subtype encountered in format: %@", format);
            return NO;
    }
    // Do the aspect ratios match?
    CMVideoDimensions depthSize = CMVideoFormatDescriptionGetDimensions(depthFormat.formatDescription);
    float depthAR = depthSize.width / depthSize.height;
    CMVideoDimensions videoSize = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    float videoAr = videoSize.width / videoSize.height;
    float aspectDiffPct = DIFF_PCT(depthAR, videoAr);
    return (aspectDiffPct < ASPECT_PCT_DIFF_OK);
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
- (void) setupCameraSessionWithFormat:(AVCaptureDeviceFormat *)format
                          depthFormat:(AVCaptureDeviceFormat *__nullable)depthFormat {
    NSError *error;
    dispatch_queue_t outputQueue = dispatch_queue_create("output queue", DISPATCH_QUEUE_SERIAL);

#pragma mark - Capture session

    if (captureSession) {
        [captureSession stopRunning];
        captureSession = nil;
    }
    captureSession = [[AVCaptureSession alloc] init];
    [captureSession beginConfiguration];

#pragma mark - Capture device
    [captureDevice lockForConfiguration:&error];
    if (error) {
        NSLog(@"startSession: could not lock camera: %@",
              [error localizedDescription]);
        [captureSession commitConfiguration];
        return;
    }
    assert(format);

    [captureSession setSessionPreset:AVCaptureSessionPresetInputPriority];
    captureDevice.activeFormat = format;
    if (depthFormat)
        captureDevice.activeDepthDataFormat = depthFormat;

#pragma mark - video input

    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput
                                        deviceInputWithDevice:captureDevice
                                        error:&error];
    if (error) {
        NSLog(@"*** startSession, AVCaptureDeviceInput: error %@",
              [error localizedDescription]);
        [captureSession commitConfiguration];
        return;
    }
    if ([captureSession canAddInput:videoInput]) {
        [captureSession addInput:videoInput];
    } else {
        NSLog(@"**** could not add camera input");
        [captureSession commitConfiguration];
        return;
    }

    // these must be after the activeFormat is set.  there are other conditions:
    // On iOS, the receiver's activeVideoMinFrameDuration resets to its default value under the following conditions:
    //
    // The receiver's activeFormat changes
    // The receiver's AVCaptureDeviceInput's session's sessionPreset changes
    // The receiver's AVCaptureDeviceInput is added to a session
        //
    // https://stackoverflow.com/questions/34718833/ios-swift-avcapturesession-capture-frames-respecting-frame-rate

    captureDevice.activeVideoMaxFrameDuration = CMTimeMake( 1, MAX_FPS );
    captureDevice.activeVideoMinFrameDuration = CMTimeMake( 1, MAX_FPS );
    [captureDevice unlockForConfiguration];

    
    
#pragma mark - video output
    
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    assert(videoDataOutput);
    videoDataOutput.automaticallyConfiguresOutputBufferDimensions = YES;
    videoDataOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    };
//  videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    [videoDataOutput setSampleBufferDelegate:self queue:outputQueue];
    if ([captureSession canAddOutput:videoDataOutput]) {
        [captureSession addOutput:videoDataOutput];
    } else {
        NSLog(@"**** could not add video data output");
        [captureSession commitConfiguration];
        return;
    }
    AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:videoOrientation];
    videoConnection.videoMirrored = YES;

#pragma mark - depth output
    
    depthDataOutput = nil;
    if (depthDataAvailable) {
        depthDataOutput = [[AVCaptureDepthDataOutput alloc] init];
        assert(depthDataOutput);
        if ([captureSession canAddOutput:depthDataOutput]) {
            [captureSession addOutput:depthDataOutput];
        } else {
            NSLog(@"**** could not add depth data output");
            [captureSession commitConfiguration];
            return;
        }
        [depthDataOutput setDelegate:self callbackQueue:outputQueue];
        depthDataOutput.filteringEnabled = NO; // XXXX does this need to be last, after delegate?
        depthDataOutput.alwaysDiscardsLateDepthData = YES;
        AVCaptureConnection *depthConnection = [depthDataOutput connectionWithMediaType:AVMediaTypeDepthData];
        assert(depthConnection);  // we were told it is available
        [depthConnection setVideoOrientation:videoOrientation];
        depthConnection.videoMirrored = YES;
    }
   
#ifdef NOPE
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.frame = videoView.layer.bounds
    previewLayer.videoGravity = .resizeAspectFill
    videoView.layer.addSublayer(previewLayer)
#endif
    
    outputSynchronizer = [[AVCaptureDataOutputSynchronizer alloc]
              initWithDataOutputs:
              depthDataAvailable ? @[videoDataOutput, depthDataOutput] : @[videoDataOutput]];
    [outputSynchronizer setDelegate:self queue:outputQueue];

    [captureSession commitConfiguration];
#ifdef DEBUG_CAMERA
    NSLog(@"CCCC format: %@", captureDevice.activeFormat);
    NSLog(@"      depth: %@", captureDevice.activeDepthDataFormat);
#endif
    return;
}

#pragma mark - AVCaptureDataOutputSynchronizer (Video + Depth)

// From:
//   https://github.com/sjy234sjy234/Learn-Metal/blob/master/TrueDepthStreaming/
//      TrueDepthStreaming/Utility/Device/FrontCamera.m


- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer
didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)synchronizedDataCollection {
    stats.framesReceived++;
    
    //    NSLog(@"synchronizedDataCollection: %@", synchronizedDataCollection);
    //    NSLog(@"           depthDataOutput: %@", depthDataOutput);
    if (synchronizedDataCollection.count == 0) {
        // no data, I wonder why
        stats.emptyFrames++;
        return;
    }
    if (!capturedFrame) {
        capturedFrame = [[Frame alloc] init];
        NSLog(@"dataOutputSynchronizer    new frame");
    }
    @synchronized (capturedFrame) {
        if (capturedFrame.locked) {
            stats.framesIgnored++;
            return;
        }
    }
    
    @synchronized (capturedFrame) {
        capturedFrame.locked = YES;
        // Only us can write this, and only now.  No updates until we are done with the frame.
    }

    AVCaptureSynchronizedData *syncedDepthData = [synchronizedDataCollection
                                                  synchronizedDataForCaptureOutput:depthDataOutput];
    AVCaptureSynchronizedDepthData *syncedDepthBufferData = (AVCaptureSynchronizedDepthData *)syncedDepthData;
    
    if (depthDataAvailable) {
        if (!syncedDepthBufferData) {
            stats.depthMissing++;       // not so rare, maybe 5% in one test
            @synchronized (capturedFrame) {
                capturedFrame.locked = NO;
            }
            return;
        }
        if(syncedDepthBufferData.depthDataWasDropped) {
            stats.depthDropped++; // this should be rare
            @synchronized (capturedFrame) {
                capturedFrame.locked = NO;
            }
            return;
        }
        stats.depthFrames++;
        CVPixelBufferRef depthPixelBufferRef = [syncedDepthBufferData.depthData depthDataMap];
        if (depthPixelBufferRef) {
            CVPixelBufferLockBaseAddress(depthPixelBufferRef,  kCVPixelBufferLock_ReadOnly);
            // copy the given depth data to our capture.  It seems to change under us, so
            // save most processing until after the depths are firmed up
            size_t width = CVPixelBufferGetWidth(depthPixelBufferRef);
            size_t height = CVPixelBufferGetHeight(depthPixelBufferRef);
            CGSize ds = CGSizeMake(width, height);
            // reuse the previous depthbuf, if it exists and is the right size
            if (!capturedFrame.depthBuf || !SAME_SIZE(capturedFrame.depthBuf.size, ds)) {
                capturedFrame.depthBuf = [[DepthBuf alloc] initWithSize:ds];
                NSLog(@"dataOutputSynchronizer    new depth     %.0f X %.0f",
                      capturedFrame.depthBuf.size.width,
                      capturedFrame.depthBuf.size.height);
            }
            assert(sizeof(Distance) == sizeof(float));
            float *capturedDepthBuffer = (float *)CVPixelBufferGetBaseAddress(depthPixelBufferRef);
            capturedFrame.depthBuf.minDepth = MAXFLOAT;
            capturedFrame.depthBuf.maxDepth = -1.0;
            for (size_t i=0; i < width*height; i++) {
                float d = capturedDepthBuffer[i];
                if (isnan(d)) {
                    stats.depthNaNs++;
                    d = BAD_DEPTH;
                } else if (d == 0.0) {
                    stats.depthZeros++;
                    d = BAD_DEPTH;
                } else {
                    if (d < capturedFrame.depthBuf.minDepth)
                        capturedFrame.depthBuf.minDepth = d;
                    if (d > capturedFrame.depthBuf.maxDepth)
                        capturedFrame.depthBuf.maxDepth = d;
                }
                capturedFrame.depthBuf.db[i] = d;
            }
            CVPixelBufferUnlockBaseAddress(depthPixelBufferRef, 0);
            assert(capturedFrame.depthBuf.minDepth > 0);
            assert(capturedFrame.depthBuf.maxDepth > 0 || capturedFrame.depthBuf.maxDepth < MAXFLOAT);
            assert(capturedFrame.depthBuf.minDepth <= capturedFrame.depthBuf.maxDepth);
            // NB: the depth data is dirty, with BAD_DEPTH values
        }
    }
    
    AVCaptureSynchronizedData *syncedVideoData=[synchronizedDataCollection
                                                synchronizedDataForCaptureOutput:self.videoDataOutput];
    AVCaptureSynchronizedSampleBufferData *syncedSampleBufferData = (AVCaptureSynchronizedSampleBufferData *)syncedVideoData;
    
    if(syncedSampleBufferData.sampleBufferWasDropped) {
        stats.imagesDropped++;
        return;
    } else {
        stats.imageFrames++;
        CVPixelBufferRef videoPixelBufferRef = CMSampleBufferGetImageBuffer(syncedSampleBufferData.sampleBuffer);
        //                NSLog(@"FR: %5d  v: %4d  dp:%4d   vd:%3d  dd:%3d  dm:%d  nr:%d",
        //                      frameCount, videoFrames, depthFrames,
        //                      videoDropped, depthDropped, depthMissing, notRespond);
        if (!videoPixelBufferRef) {
            stats.noVideoPixelBuffer++;
            capturedFrame.locked = NO;
            return;
        }
        
        CVPixelBufferLockBaseAddress(videoPixelBufferRef, 0);
        size_t width = CVPixelBufferGetWidth(videoPixelBufferRef);
        size_t height = CVPixelBufferGetHeight(videoPixelBufferRef);
        CGSize imageSize = CGSizeMake(width, height);
        
        // reuse the pixbuf, if it exists and is the same size
        if (!capturedFrame.pixBuf || !SAME_SIZE(capturedFrame.pixBuf.size, imageSize)) {
            capturedFrame.pixBuf = [[PixBuf alloc] initWithSize:imageSize];
            NSLog(@"dataOutputSynchronizer    new pixBuf  %.0f X %.0f",
                  capturedFrame.pixBuf.size.width,
                  capturedFrame.pixBuf.size.height);
        }
        
        void *baseAddress = CVPixelBufferGetBaseAddress(videoPixelBufferRef);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(videoPixelBufferRef);
        assert(bytesPerRow == width*sizeof(Pixel));
        memcpy(capturedFrame.pixBuf.pb, baseAddress, bytesPerRow * height);
        CVPixelBufferUnlockBaseAddress(videoPixelBufferRef,0);
    }
    if (depthDataAvailable)
        assert(capturedFrame.depthBuf); // depth must be available at this point
    assert(capturedFrame.pixBuf);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id<videoSampleProcessorDelegate>)self->videoProcessor processCapturedFrame:self->capturedFrame];
        self->stats.framesProcessed++;
        @synchronized (self->capturedFrame) {
            self->capturedFrame.locked = NO;
        }
    });
    
#ifdef UNDEF
    if (NO && (frameCount-1) % 500 == 0)
        NSLog(@"frames: %5d  v: %5d  dp:%5d   vd:%3d  dd:%3d  dm:%d",
              frameCount, videoFrames, depthFrames,
              videoDropped, depthDropped, depthMissing);
#endif
    return;
}

#ifdef OLD
- (UIImage *) imageFromSampleBuffer:(CVImageBufferRef) videoPixelBuffer {
    if (!videoPixelBuffer) {
//        NSLog(@" image buffer missing");
        return nil;
    }
    CVPixelBufferLockBaseAddress(videoPixelBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(videoPixelBuffer);
    assert(baseAddress);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(videoPixelBuffer);
    size_t width = CVPixelBufferGetWidth(videoPixelBuffer);
    size_t height = CVPixelBufferGetHeight(videoPixelBuffer);
    //NSLog(@"image  orientation %@", width > height ? @"panoramic" : @"portrait");
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, BITMAP_OPTS);
    assert(context);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(videoPixelBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:(CGFloat)1.0
                                   orientation:UIImageOrientationUp];
    CGImageRelease(quartzImage);
    return image;
}
#endif

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
