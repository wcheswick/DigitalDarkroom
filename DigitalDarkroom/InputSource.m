//
//  InputSource.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "InputSource.h"

#define LAST_SOURCE_ARCHIVE   @"LastSource.archive"

#define kLabel      @"Label"
#define kImagePath  @"ImagePath"
#define kSide       @"UseFrontCamera"
#define kDepth      @"UseDepthMode"

@implementation InputSource

@synthesize label;
@synthesize currentSide, usingDepthCamera;
@synthesize imagePath;
@synthesize thumbImageCache;
@synthesize imageSize;

- (id)init {
    self = [super init];
    if (self) {
        label = @"";
        imagePath = nil;
        imageSize = CGSizeZero;
        thumbImageCache = nil;
    }
    return self;
}

- (void) makeCameraSourceOnSide:(CameraSide) side threeD:(BOOL) threeD {
    label = @"Cameras";
    imagePath = nil;   // signifies camera input
    imageSize = CGSizeZero;
    thumbImageCache = nil;
    self.currentSide = side;
    self.usingDepthCamera = threeD;
}

- (id) initWithCoder: (NSCoder *)coder {
    self = [super init];
    if (self) {
        self.label = [coder decodeObjectForKey:kLabel];
        self.imagePath = [coder decodeObjectForKey: kImagePath];
        self.currentSide = [coder decodeIntForKey: kSide];
        self.usingDepthCamera = [coder decodeBoolForKey: kDepth];
        thumbImageCache = nil;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:label forKey:kLabel];
    [coder encodeObject:imagePath forKey:kImagePath];
    [coder encodeInt:currentSide forKey:kSide];
    [coder encodeBool:usingDepthCamera forKey:kDepth];
}

- (void) setUpImageAt:(NSString *)path {
    imagePath = path;
    label = [[path lastPathComponent] stringByDeletingPathExtension];
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
    copy.currentSide = currentSide;
    copy.usingDepthCamera = usingDepthCamera;
    copy.imageSize = imageSize;
    copy.thumbImageCache = thumbImageCache;
    return copy;
}

@end
