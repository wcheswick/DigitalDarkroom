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

#define IS_CAMERA(i)        ((i).imagePath == nil)

@interface InputSource : NSObject {
    NSString *label;
    BOOL isCamera;
    NSString *__nullable imagePath; // where a file image is
    CameraSide currentSide;
    BOOL usingDepthCamera;
    UIImage *__nullable thumbImageCache;
}

@property (nonatomic, strong)   NSString *label;
@property (assign)              BOOL isCamera;
@property (nonatomic, strong)   UIImage *capturedImage;
@property (assign)              CameraSide currentSide;
@property (assign)              BOOL usingDepthCamera;
@property (nonatomic, strong)   NSString *__nullable imagePath;
@property (nonatomic, strong)   NSArray *cameraNames;
@property (nonatomic, strong)   UIImage *__nullable thumbImageCache;

- (void) makeCameraSourceOnSide:(CameraSide) side threeD:(BOOL) threeD;
- (void) setUpImageAt:(NSString *)path;
+ (NSData *) lastSourceArchive;
- (void) save;

@end

NS_ASSUME_NONNULL_END
