//
//  InputSource.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define IS_CAMERA(i)        ((i).imagePath == nil)
#define IS_3D_CAMERA(i)     (IS_CAMERA(i) && i.threeDCamera)

@interface InputSource : NSObject {
    NSString *label;
    NSString *__nullable imagePath;        // if file set, then not a camera
    BOOL frontCamera;           // if imagePath == nil, which camera is selected
    BOOL threeDCamera;          // ... and it it the depth camera
    CGSize imageSize;
    UIImageView *__nullablethumbImage;
}

@property (nonatomic, strong)   NSString *label;
@property (assign)              BOOL frontCamera, threeDCamera;
@property (nonatomic, strong)   NSString *__nullable imagePath;
@property (nonatomic, strong)   UIImageView *__nullable thumbImage;
@property (assign)              CGSize imageSize;
@property (nonatomic, strong)   NSArray *cameraNames;

- (void) makeCameraSource;
- (void) setUpImageAt:(NSString *)path;
+ (NSData *) lastSourceArchive;
- (void) save;

@end

NS_ASSUME_NONNULL_END
