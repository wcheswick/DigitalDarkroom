//
//  InputSource.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "InputSource.h"

#define LAST_SOURCE_ARCHIVE   @"LastSource.archive"

#define kLabel                  @"Label"
#define kImagePath              @"ImagePath"
#define kFrontCameraSelected    @"FrontCameraSelected"
#define kThreeDCamera           @"ThreeDCamera"

@implementation InputSource

@synthesize label;
@synthesize frontCamera, threeDCamera;
@synthesize imagePath;
@synthesize thumbImage;
@synthesize imageSize;

- (id)init {
    self = [super init];
    if (self) {
        label = @"";
        imagePath = nil;
        imageSize = CGSizeZero;
        thumbImage = nil;
        frontCamera = YES;
        threeDCamera = NO;
    }
    return self;
}

- (void) makeCameraSource {
    label = @"Cameras";
    imagePath = nil;   // signifies camera input
    frontCamera = YES;
    threeDCamera = NO;
    imageSize = CGSizeZero;
    thumbImage = nil;
}

- (id) initWithCoder: (NSCoder *)coder {
    self = [super init];
    if (self) {
        self.label = [coder decodeObjectForKey:kLabel];
        self.imagePath = [coder decodeObjectForKey: kImagePath];
        self.frontCamera = [coder decodeBoolForKey: kFrontCameraSelected];
        self.threeDCamera = [coder decodeBoolForKey: kThreeDCamera];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:label forKey:kLabel];
    [coder encodeObject:imagePath forKey:kImagePath];
    [coder encodeBool:frontCamera forKey:kFrontCameraSelected];
    [coder encodeBool:threeDCamera forKey:kThreeDCamera];
}

- (void) setUpImageAt:(NSString *)path {
    imagePath = path;
    label = [path lastPathComponent];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    if (!image) {
        imageSize = CGSizeZero;
        label = [label stringByAppendingString:@" (missing)"];
    } else {
        imageSize = image.size;
    }
}

+ (NSData *) lastSourceArchive {
    return [NSData dataWithContentsOfFile:LAST_SOURCE_ARCHIVE];
}

- (void) save {
    NSError *error;
    NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:self
                                                requiringSecureCoding:NO error:&error];
    [archiveData writeToFile:LAST_SOURCE_ARCHIVE atomically:YES];
}

- (id)copyWithZone:(NSZone *)zone {
    InputSource *copy = [[InputSource alloc] init];
    copy.label = label;
    copy.imagePath = imagePath;
    copy.frontCamera = frontCamera;
    copy.threeDCamera = threeDCamera;
    copy.imageSize = imageSize;
    copy.thumbImage = thumbImage;
    return copy;
}

@end
