//
//  InputSource.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "CameraController.h"

NS_ASSUME_NONNULL_BEGIN

#define LAST_SOURCE_ARCHIVE   @"./LastSourc.archive"

#define SOURCE_IS_CAMERA(s) ((s).camera != nil)
#define SOURCE_IS_FILE(s)   ((s).camera == nil)

#define SOURCE_IS_FRONT(s)  ((s).camera.position == AVCaptureDevicePositionFront)
#define SOURCE_IS_3D(s)  ((s).camera.activeDepthDataFormat) // XXXX wrong, not active, but  could be active

#define NO_SOURCE_INDEX (-1)

@interface InputSource : NSObject {
    NSString *label;
    int sourceIndex;            // in sources array
    AVCaptureDevice *camera;    // nil is uninitialized or file source
    NSString *__nullable imagePath; // where a file image is
    UIImage *__nullable thumbImageCache;
    NSMutableArray *sourceMenuSections;
}

@property (nonatomic, strong)   NSMutableArray *frontCameras, *backCameras;
@property (nonatomic, strong)   NSString *label;
@property (assign)              int sourceIndex;
@property (nonatomic, strong)   AVCaptureDevice *camera;
@property (nonatomic, strong)   NSString *__nullable imagePath;
@property (nonatomic, strong)   UIImage *__nullable thumbImageCache;
//@property (nonatomic, strong)   UIImage *__nullable image;
@property (nonatomic, strong)   NSMutableArray *sourceMenuSections;

- (void) loadImage:(NSString *)path;
- (AVCaptureDevicePosition) position;

@end

NS_ASSUME_NONNULL_END
