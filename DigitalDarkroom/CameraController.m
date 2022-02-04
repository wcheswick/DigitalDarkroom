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

CameraController *cameraController = nil;

@interface CameraController ()

@property (strong, nonatomic)   AVCaptureDevice *captureDevice;
@property (nonatomic, strong)   AVCaptureSession *captureSession;
@property (assign)              AVCaptureVideoOrientation videoOrientation;
@property (assign)              UIDeviceOrientation deviceOrientation;

@property (nonatomic, strong)   AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong)   AVCaptureDepthDataOutput *depthDataOutput;
@property (nonatomic, strong)   AVCaptureDataOutputSynchronizer *outputSynchronizer;

@property (assign)              BOOL busy;

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
@synthesize usefulFormatList;
@synthesize hasSome3D;
@synthesize stats;
@synthesize busy;
@synthesize lastRawFrame;
@synthesize taskCtrl;

- (id)init {
    self = [super init];
    if (self) {
        captureVideoPreviewLayer = nil;
        captureDevice = nil;
        captureSession = nil;
        lastRawFrame = nil;
        videoOrientation = -1;  // not initialized
        usefulFormatList = [[NSMutableArray alloc] init];
        cameraController = self;
       busy = NO;
    }
    return self;
}

- (BOOL) cameraDeviceOnFront:(BOOL)onFront needs3D:(BOOL) needs3D {
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
    hasSome3D = NO;
    if (!discSess.devices.count)
        return NO;
    
    captureDevice = discSess.devices[0];
    //    NSLog(@" top device: %@", activeDevice);
    //    NSLog(@"    formats: %@", activeDevice.formats);    // need to select supports depth
    
    // first, scan for depth formats.  If available at all, then reject all formats
    // that do not have a useable depth format
    
    NSMutableArray *usefulVideoFormats = [[NSMutableArray alloc]
                                          initWithCapacity:captureDevice.formats.count];
    NSMutableArray *usefulVideoWithDepthFormats = [[NSMutableArray alloc]
                                                   initWithCapacity:captureDevice.formats.count];

    AVCaptureDeviceFormat *lastFormat;
    CMVideoDimensions lastSize;

    for (int i=0; i<captureDevice.formats.count; i++) {
        AVCaptureDeviceFormat *thisFormat = captureDevice.formats[i];
        BOOL has3D = thisFormat.supportedDepthDataFormats && thisFormat.supportedDepthDataFormats.count;
        if (needs3D && has3D)
            continue;
        hasSome3D |= has3D;
        CMVideoDimensions thisSize = CMVideoFormatDescriptionGetDimensions(thisFormat.formatDescription);
        if (i > 0 && SAME_SIZE(thisSize, lastSize)) {
            // same size.  Is this better than the previous?  If so, replace
            if (lastFormat.videoHDRSupported && !thisFormat.videoHDRSupported)
                continue;
            usefulVideoFormats[usefulVideoFormats.count - 1] = thisFormat;
            lastFormat = thisFormat;
            continue;
        }
        [usefulVideoFormats addObject:thisFormat];
        lastSize = thisSize;
        lastFormat = thisFormat;
    }
    usefulFormatList = usefulVideoFormats;
    
//    NSLog(@"useful: %@", usefulFormatList);
    
#ifdef NOTYET
    if (depthDataAvailable) {
        assert(usefulVideoWithDepthFormats.count);
        usefulFormatList = usefulVideoWithDepthFormats;
    } else
        usefulFormatList = usefulVideoFormats;
    NSLog(@"%d:  %@", onFront, usefulFormatList);
#endif
    
    assert(usefulFormatList.count);   // we need at least one format!
    if (!usefulFormatList.count) {
        return NO;
    }
    return YES;
}

- (BOOL) formatHasUsefulSubtype: (AVCaptureDeviceFormat *)format {
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    u_char *typeCode = (u_char *)&mediaSubType;
    //NSLog(@"  mediaSubType %u", (unsigned int)mediaSubType);
    switch (mediaSubType) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange: // 'x420'
            /* 2 plane YCbCr10 4:2:0, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
        case kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange:  //'x422'
            /* 2 plane YCbCr10 4:2:2, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
        case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange: // 'x444'
            /* 2 plane YCbCr10 4:4:4, each 10 bits in the MSBs of 16bits, video-range (luma=[64,940] chroma=[64,960]) */
//#ifdef DEBUG_CAMERA
//            NSLog(@"Rejecting media subtype %1c%1c%1c%1c",
//                  typeCode[0], typeCode[1], typeCode[2], typeCode[3]);
//#endif
            return NO;
       case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: // We want only the formats with full range
//#ifdef DEBUG_CAMERA
//            NSLog(@"** Accepting media subtype %1c%1c%1c%1c",
//                  typeCode[0], typeCode[1], typeCode[2], typeCode[3]);
//#endif
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
    
    // is it the same size?
    CMVideoDimensions depthSize = CMVideoFormatDescriptionGetDimensions(depthFormat.formatDescription);
    CMVideoDimensions videoSize = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    
    if (SAME_SIZE(depthSize, videoSize))
        return YES;
    
#ifdef ASPECT_CHECK // not working
    // Weird pixel line lengths?
#ifdef NOTDEF
    CGSize rawDepthSize = CGSizeMake(CVPixelBufferGetWidth(depthPixelBufferRef),
                                     CVPixelBufferGetHeight(depthPixelBufferRef));
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(depthPixelBufferRef);
    size_t bpplane = CVPixelBufferGetWidthOfPlane(depthPixelBufferRef, 0);
    size_t bprp = CVPixelBufferGetBytesPerRowOfPlane(depthPixelBufferRef, 0);
    assert(bytesPerRow == rawDepthSize.width * sizeof(Distance));
#endif
    
    // Do the aspect ratios match?
    float depthAR = (float)depthSize.width / (float)depthSize.height;
    float videoAr = (float)videoSize.width / (float)videoSize.height;
    float aspectDiffPct = DIFF_PCT(depthAR, videoAr);
    return (aspectDiffPct < ASPECT_PCT_DIFF_OK);
#endif
    return NO;
}

- (BOOL) selectCameraOnFront:(BOOL)front needs3D:(BOOL) needs3D {
#ifdef DEBUG_CAMERA
    NSLog(@"CCC selecting camera on side %@ 3d:%@", front ? @"Front" : @"Rear ",
          needs3D ?@"YES" : @"NO");
#endif
    if (![self cameraDeviceOnFront:front needs3D:needs3D])
        return NO;
#ifdef DEBUG_CAMERA
    NSLog(@"CCC found %ld", cameraController.usefulFormatList.count);
#endif
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
    assert(depthFormat);    // XXXXXX for the moment
    NSLog(@"depth format: %@", depthFormat);
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
#ifdef notdef
        kCVPixelFormatType_32ARGB   // broken
        kCVPixelFormatType_32BGRA   // mostly blue
        kCVPixelFormatType_32ABGR  // broken
        kCVPixelFormatType_32RGBA   // broken
#endif
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

// if depth date not available, return size zero
- (void) currentRawSizes:(CGSize *)rawImageSize
            rawDepthSize:(CGSize *) rawDepthSize {
    assert(captureDevice.activeFormat);
    CMFormatDescriptionRef ref = captureDevice.activeFormat.formatDescription;
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(ref);
    *rawImageSize = CGSizeMake(size.width, size.height);
    if (!depthDataAvailable)
        *rawDepthSize = CGSizeZero;
    else {
        AVCaptureDeviceFormat *depthFormat = captureDevice.activeDepthDataFormat;
        NSLog(@"DDDDDD Depth format: %@", depthFormat);
        CMFormatDescriptionRef ref = depthFormat.formatDescription;
        CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(ref);
        *rawDepthSize = CGSizeMake(size.width, size.height);
    }
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

    BOOL needAFrame = NO;
    for (NSString *groupName in taskCtrl.activeGroups) {
        TaskGroup *taskGroup = [taskCtrl.activeGroups objectForKey:groupName];
        if (taskGroup.groupBusy)
            continue;
        needAFrame = YES;
        break;
    }
    
    if (!needAFrame) {
        stats.tooBusyForAFrame++;
        return;
    }

    AVCaptureSynchronizedData *syncedVideoData = [synchronizedDataCollection
                                                synchronizedDataForCaptureOutput:self.videoDataOutput];
    AVCaptureSynchronizedSampleBufferData *syncedSampleBufferData = (AVCaptureSynchronizedSampleBufferData *)syncedVideoData;
    AVCaptureSynchronizedData *syncedDepthData = [synchronizedDataCollection
                                                  synchronizedDataForCaptureOutput:depthDataOutput];
    AVCaptureSynchronizedDepthData *syncedDepthBufferData = (AVCaptureSynchronizedDepthData *)syncedDepthData;
    
    if(syncedSampleBufferData.sampleBufferWasDropped) {
        stats.imagesDropped++;
        stats.status = @"imD";
        return;
    }
    
    stats.imageFrames++;
    CVPixelBufferRef videoPixelBufferRef = CMSampleBufferGetImageBuffer(syncedSampleBufferData.sampleBuffer);
    //                NSLog(@"FR: %5d  v: %4d  dp:%4d   vd:%3d  dd:%3d  dm:%d  nr:%d",
    //                      frameCount, videoFrames, depthFrames,
    //                      videoDropped, depthDropped, depthMissing, notRespond);
    if (!videoPixelBufferRef) {
        stats.noVideoPixelBuffer++;
        stats.status = @"drV";
        return;
    }
    
    if (depthDataAvailable) {
        if (!syncedDepthBufferData) {
            stats.depthMissing++;       // not so rare, maybe 5% in one test
            stats.status = @"noD";
            busy = NO;
            return;
        }
        if (syncedDepthBufferData.depthDataWasDropped) {
            stats.depthDropped++; // this should be rare
            stats.status = @"drD";
            busy = NO;
            return;
        }
        stats.depthFrames++;
    }
    if (!lastRawFrame) {
        lastRawFrame = [[Frame alloc] init];
    }

    @synchronized (lastRawFrame) {
        lastRawFrame.useCount++;
        
        CVPixelBufferLockBaseAddress(videoPixelBufferRef, 0);
        CGSize rawImageSize = CGSizeMake(CVPixelBufferGetWidth(videoPixelBufferRef),
                                         CVPixelBufferGetHeight(videoPixelBufferRef));
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(videoPixelBufferRef);
        //    OSType type = CVPixelBufferGetPixelFormatType(videoPixelBufferRef);
        
        void *videoBaseAddress = CVPixelBufferGetBaseAddress(videoPixelBufferRef);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(videoBaseAddress, rawImageSize.width, rawImageSize.height,
                                                     8, bytesPerRow, colorSpace, BITMAP_OPTS);
        assert(context);
        CGImageRef quartzImage = CGBitmapContextCreateImage(context);
        
        lastRawFrame.image = [[UIImage alloc] initWithCGImage:quartzImage
                                                        scale:1.0
                                                  orientation:UIImageOrientationUp];
        if (!lastRawFrame.pixBuf ||
            !SAME_SIZE(lastRawFrame.pixBuf.size, rawImageSize)) {
            lastRawFrame.pixBuf = [[PixBuf alloc] initWithSize:rawImageSize];
        }
        memcpy(lastRawFrame.pixBuf.pb, (Pixel *)videoBaseAddress,
               rawImageSize.width * rawImageSize.height*sizeof(Pixel));
        CVPixelBufferUnlockBaseAddress(videoPixelBufferRef,0);
        CGImageRelease(quartzImage);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        
        Distance *capturedDepthBuffer = nil;
        if (!depthDataAvailable) {
            if (lastRawFrame.depthBuf)
                lastRawFrame.depthBuf = nil;
        } else {
            CVPixelBufferRef depthPixelBufferRef = [syncedDepthBufferData.depthData depthDataMap];
            assert(depthPixelBufferRef);
            CVPixelBufferLockBaseAddress(depthPixelBufferRef, 0);
            
            CGSize rawDepthSize = CGSizeMake(CVPixelBufferGetWidth(depthPixelBufferRef),
                                             CVPixelBufferGetHeight(depthPixelBufferRef));
//            size_t bpr = CVPixelBufferGetBytesPerRow(depthPixelBufferRef);
//            size_t bufSize = CVPixelBufferGetDataSize(depthPixelBufferRef);
            if (!lastRawFrame.depthBuf || !SAME_SIZE(lastRawFrame.depthBuf.size, rawDepthSize)) {
                lastRawFrame.depthBuf = [[DepthBuf alloc] initWithSize:rawDepthSize];
            }
            capturedDepthBuffer = (float *)CVPixelBufferGetBaseAddress(depthPixelBufferRef);
            assert(capturedDepthBuffer);
            Distance *rowPtr = capturedDepthBuffer;
            size_t bytesPerRow = CVPixelBufferGetBytesPerRow(depthPixelBufferRef);
            size_t width = CVPixelBufferGetWidth(depthPixelBufferRef);

            assert(bytesPerRow/width == sizeof(Distance));
            
            size_t distancesPerRow = rawDepthSize.width;
            size_t goodBytesPerRow = distancesPerRow * sizeof(Distance);
//            size_t bytesPerSourceRow = CVPixelBufferGetBytesPerRow(depthPixelBufferRef);
            for (int row=0; row<rawDepthSize.height; row++) {
                memcpy(&lastRawFrame.depthBuf.da[row][0], rowPtr, goodBytesPerRow);
                rowPtr += bytesPerRow;
            }
           lastRawFrame.depthBuf.size = rawDepthSize;
            //            [lastRawFrame.depthBuf stats];
            CVPixelBufferUnlockBaseAddress(depthPixelBufferRef, 0);
        }
        
        [taskCtrl processFrame: lastRawFrame];
        lastRawFrame.useCount--;    // decremented by this routine:
        assert(lastRawFrame.useCount >= 0);
    }
    self->stats.framesProcessed++;
    stats.status = @"ok";
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
