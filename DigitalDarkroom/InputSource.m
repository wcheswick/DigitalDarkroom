//
//  InputSource.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "InputSource.h"


@implementation InputSource

@synthesize sourceType;
@synthesize label;
@synthesize imagePath;
@synthesize thumbImage;
@synthesize imageSize;
@synthesize cameraNames;

- (id)init {
    self = [super init];
    if (self) {
        sourceType = NotACamera;
        imageSize = CGSizeZero;
    }
    return self;
}


static NSString * const cameraNames[] = {
    @"Front camera",
    @"Rear camera",
    @"Front 3D camera",
    @"Rear 3D camera"
};

+ (NSString *)cameraNameFor:(Cameras)camera {
    assert(ISCAMERA(camera));
    return cameraNames[camera];
}

@end
