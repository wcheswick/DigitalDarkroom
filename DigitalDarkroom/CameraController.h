//
//  CameraController.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "TaskCtrl.h"
#import "TaskGroup.h"
#import "Stats.h"
#import "MainVC.h"

NS_ASSUME_NONNULL_BEGIN

#define CAMERA_NOT_AVAILABLE    (-1)

typedef enum {
    NotACamera,
    FrontCamera,
    BackCamera,
} CameraType;

#define IS_CAMERA_DEVICE(t)   (t == FrontCamera || t == BackCamera)

@interface CameraController : NSObject
        <AVCaptureVideoDataOutputSampleBufferDelegate,
        AVCaptureDepthDataOutputDelegate,
        AVCaptureDataOutputSynchronizerDelegate> {
    NSArray <AVCaptureDevice *> *cameraList;
    NSMutableArray <AVCaptureDeviceFormat *> *currentFormats;

    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    __unsafe_unretained id videoProcessor;
    
    AVCaptureDevicePosition currentPosition;
    AVCaptureDevice *currentCamera;

    NSMutableArray<AVCaptureDevice *> *frontCameras;
    NSMutableArray<AVCaptureDevice *> *backCameras;
    
    BOOL hasSome3D;
    BOOL depthDataAvailable;
    
    Stats *stats;
    Frame *lastRawFrame;
    TaskCtrl *taskCtrl;
}

@property (strong, nonatomic)   NSArray <AVCaptureDevice *> *cameraList;

@property (assign)              AVCaptureDevicePosition currentPosition;
@property (assign)              int currentCaptureDeviceIndex;
@property (nonatomic, strong)   AVCaptureDevice *currentCamera;

@property (nonatomic, strong)   NSMutableArray<AVCaptureDevice *> *frontCameras;
@property (nonatomic, strong)   NSMutableArray<AVCaptureDevice *> *backCameras;

@property (nonatomic, strong)   NSMutableArray <AVCaptureDeviceFormat *> *currentFormats;

@property (assign)              UIDeviceOrientation deviceOrientation;

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (assign)              __unsafe_unretained id videoProcessor;
@property (assign)              volatile BOOL depthDataAvailable;
@property (assign)              BOOL hasSome3D;

@property (nonatomic, strong)   Stats *stats;
@property (nonatomic, strong)   Frame *lastRawFrame;
@property (nonatomic, strong)   TaskCtrl *taskCtrl;

@property (strong, nonatomic)   AVCaptureDevice *frontDevice, *backDevice;

- (void) selectCamera:(AVCaptureDevice *)newCamera;
- (void) adjustCameraOrientation:(UIDeviceOrientation) newDeviceOrientation;
- (void) selectCameraFormat:(AVCaptureDeviceFormat *) format
                depthFormat:(AVCaptureDeviceFormat *__nullable)depthFormat;

- (void) startCamera;
- (void) stopCamera;

+ (BOOL) depthFormat:(AVCaptureDeviceFormat *)depthFormat
       isSuitableFor:(AVCaptureDeviceFormat *)format;
- (CGSize) sizeForFormat:(AVCaptureDeviceFormat *)format;

- (void) currentRawSizes:(CGSize *)rawImageSize
            rawDepthSize:(CGSize *) rawDepthSize;

- (NSString *) dumpFormatType:(OSType) t;
+ (NSString *) dumpDeviceOrientationName: (UIDeviceOrientation) o;
- (NSString *)dumpFormat:(AVCaptureDeviceFormat *)fmt;

// this makes accessing easy.  This never changes after init

extern  CameraController *cameraController;

@end

NS_ASSUME_NONNULL_END
