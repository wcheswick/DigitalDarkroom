//
//  InputSource.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "InputSource.h"

#define kLabel      @"Label"
#define kImagePath  @"ImagePath"
#define kIsFront    @"isFront"
#define kIsDepth    @"isDepth"
#define kIsCamera   @"IsCamera"

@implementation InputSource

@synthesize label;
@synthesize isThreeD, isFront;
@synthesize cameraIndex;
@synthesize otherSideIndex, otherDepthIndex;
@synthesize imagePath;
@synthesize thumbImageCache;
@synthesize capturedImage;

- (id)init {
    self = [super init];
    if (self) {
        label = @"";
        imagePath = nil;
        thumbImageCache = nil;
        cameraIndex = NOT_A_CAMERA;
        otherSideIndex = otherDepthIndex = CAMERA_FUNCTION_NOT_AVAILABLE;
        capturedImage = nil;
    }
    return self;
}

- (void) makeCameraSource:(NSString *)name onFront:(BOOL)onFront threeD:(BOOL) threeD {
    label = name;
    isFront = onFront;
    capturedImage = nil;
    thumbImageCache = nil;
    self.isFront = onFront;
    self.isThreeD = threeD;
}

- (void) setUpImageAt:(NSString *)path {
    imagePath = path;
    label = [[path lastPathComponent] stringByDeletingPathExtension];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    if (!image) {
        label = [label stringByAppendingString:@" (missing)"];
    }
}

@end
