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

// slow, range-checking debug version
- (Distance) distAtX:(int)x Y:(int)y {
    assert(x >= 0 && x < self.size.width);
    assert(y >= 0 && y < self.size.height);
    return buf[x + y*(int)size.width];
}

- (void) dealloc {
    if (buf) {
        free(buf);
        buf = nil;
    }
}

@end
