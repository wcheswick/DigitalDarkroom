//
//  FormatInfo.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/23/23.
//  Copyright © 2023 Cheswick.com. All rights reserved.
//

#import "FormatInfo.h"

@implementation FormatInfo

@synthesize source, formatIndex, depthFormatIndex;
@synthesize front, rear, threeD, HDR;
@synthesize w, h, dw, dh;

- (id) initWithSource:(InputSource *) s {
    self = [super init];
    if (self) {
        source = s;
        formatIndex = depthFormatIndex = -1;
        front = rear = threeD = HDR = NO;
        w = h = dw = dh = -1.0;
    }
    return self;
}

@end
