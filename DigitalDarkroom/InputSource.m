//
//  InputSource.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import "InputSource.h"

#define kLabel      @"Label"
#define kImagePath  @"ImagePath"
#define kIsFront    @"isFront"
#define kIsDepth    @"isDepth"
#define kIsCamera   @"IsCamera"

@implementation InputSource

@synthesize label;
@synthesize cameraIndex;
@synthesize imagePath;
//@synthesize image;
@synthesize thumbImageCache;

- (id)init {
    self = [super init];
    if (self) {
        label = @"";
        imagePath = nil;
        thumbImageCache = nil;
        cameraIndex = NOT_A_CAMERA;
    }
    return self;
}

- (void) makeCameraSource:(NSString *)name cameraIndex:(int) ci {
    label = name;
    cameraIndex = ci;
    thumbImageCache = nil;
}

- (void) loadImage:(NSString *)path {
    imagePath = path;
    label = [[path lastPathComponent] stringByDeletingPathExtension];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    if (!image) {
        label = [label stringByAppendingString:@" (missing)"];
    }
}

@end
