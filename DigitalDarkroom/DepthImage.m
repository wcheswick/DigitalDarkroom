//
//  DepthImage.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 11/4/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "DepthImage.h"

@implementation DepthImage

@synthesize buf, size;

- (id)initWithSize:(CGSize) s {
    self = [super init];
    if (self) {
        size = s;
        buf = (float *)malloc(s.width * s.height * sizeof(float));
    }
    return self;
}

- (void) dealloc {
    if (buf) {
        free(buf);
        buf = nil;
    }
}

@end
