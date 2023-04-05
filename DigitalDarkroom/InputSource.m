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
@synthesize camera;
@synthesize sourceIndex;
@synthesize imagePath;
//@synthesize image;
@synthesize thumbImageCache;
@synthesize sourceMenuSections;

- (id)init {
    self = [super init];
    if (self) {
        label = @"";
        imagePath = nil;
        thumbImageCache = nil;
        camera = nil;
        sourceIndex = NO_SOURCE_INDEX;
//        sourceMenuSections = [NSArray arrayWithObjects:@"Front cameras", @"Back cameras",
//                              @"Sample files", @"Saved files", nil]
    }
    return self;
}

- (AVCaptureDevicePosition) position {
    if (camera) {
        return camera.position;
    } else
        return AVCaptureDevicePositionUnspecified;
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
