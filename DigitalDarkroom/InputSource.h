//
//  InputSource.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CameraController.h"

NS_ASSUME_NONNULL_BEGIN

#define LAST_SOURCE_ARCHIVE   @"./LastSourc.archive"

#define IS_CAMERA(i)        ((i).imagePath == nil)
#define CAMERA_FUNCTION_NOT_AVAILABLE   (-1)

@interface InputSource : NSObject {
    NSString *label;
    BOOL isCamera, isThreeD, isFront;
    NSInteger otherSideIndex;    // or CAMERA_FUNCTION_NOT_AVAILABLE
    NSInteger otherDepthIndex;    // or CAMERA_FUNCTION_NOT_AVAILABLE
    NSString *__nullable imagePath; // where a file image is
    UIImage *__nullable thumbImageCache;
}

@property (nonatomic, strong)   NSString *label;
@property (assign)              BOOL isCamera, isThreeD, isFront;
@property (assign)              NSInteger otherSideIndex, otherDepthIndex;
@property (nonatomic, strong)   UIImage *capturedImage;
@property (nonatomic, strong)   NSString *__nullable imagePath;
@property (nonatomic, strong)   NSArray *cameraNames;
@property (nonatomic, strong)   UIImage *__nullable thumbImageCache;

- (void) makeCameraSource:(NSString *)name onFront:(BOOL)onFront threeD:(BOOL) threeD;
- (void) setUpImageAt:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
