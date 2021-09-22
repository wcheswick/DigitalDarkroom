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
@synthesize imageFrames, imagesDropped, noVideoPixelBuffer;

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
    depthFrames = imageFrames = noVideoPixelBuffer = 0;
    depthNaNs = depthZeros = 0;
    lastProcessed = [NSDate now];
}

- (NSString *) report {
    NSDate *now = [NSDate now];
    NSTimeInterval t = [now timeIntervalSinceDate:lastProcessed];
    NSString *report = [NSString stringWithFormat:@"%3d %3d  %5.1f/%5.1f", framesReceived, framesProcessed,
                        framesReceived/t, framesProcessed/t];
    [self reset];
    return report;
}

@end
