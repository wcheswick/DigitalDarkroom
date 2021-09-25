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
#define NOT_A_CAMERA    (-1)

@interface InputSource : NSObject {
    NSString *label;
    long cameraIndex;
    NSString *__nullable imagePath; // where a file image is
    UIImage *__nullable thumbImageCache;
}

@property (nonatomic, strong)   NSString *label;
@property (assign)              long cameraIndex;
@property (nonatomic, strong)   NSString *__nullable imagePath;
@property (nonatomic, strong)   NSArray *cameraNames;
@property (nonatomic, strong)   UIImage *__nullable thumbImageCache;

- (void) makeCameraSource:(NSString *)name cameraIndex:(int) ci;
- (void) setUpImageAt:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
