//
//  Stats.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/20/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Stats.h"

@implementation Stats

@synthesize framesReceived, framesProcessed;
@synthesize lastProcessed;
@synthesize emptyFrames, framesIgnored, depthMissing, depthDropped;
@synthesize depthFrames, depthNaNs, depthZeros;
@synthesize imageFrames, imagesDropped;

- (id)init {
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (void) reset {
    framesReceived = framesProcessed = 0;
    emptyFrames = framesIgnored = depthMissing = depthDropped = 0;
    depthFrames = imageFrames = 0;
    depthNaNs = depthZeros = 0;
    lastProcessed = [NSDate now];
}

@end
