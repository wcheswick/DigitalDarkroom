//
//  Stats.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/20/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Stats.h"

Stats *stats = nil;

@implementation Stats

@synthesize framesReceived, framesProcessed;
@synthesize lastProcessed;
@synthesize emptyFrames, framesIgnoredLocking, depthMissing, depthDropped;
@synthesize depthFrames, depthNaNs, depthZeros;
@synthesize imageFrames, imagesDropped, noVideoPixelBuffer;
@synthesize depthCopies, pixbufCopies, tooBusyForAFrame;
@synthesize incomingFrameMissing;
@synthesize status;

- (id)init {
    self = [super init];
    if (self) {
        stats = self;
        [self reset];
    }
    return self;
}

- (void) reset {
    framesReceived = framesProcessed = 0;
    emptyFrames = framesIgnoredLocking = depthMissing = depthDropped = 0;
    depthFrames = imageFrames = noVideoPixelBuffer = 0;
    depthNaNs = depthZeros = 0;
    depthCopies = pixbufCopies = 0;
    tooBusyForAFrame = 0;
    incomingFrameMissing = 0;
    status = @"";
    lastProcessed = [NSDate now];
}

- (NSString *) report {
    NSDate *now = [NSDate now];
    NSTimeInterval t = [now timeIntervalSinceDate:lastProcessed];
    NSString *report = [NSString stringWithFormat:@"%3d %3d  %5.1f/%5.1f  cpt: %5.1f/%5.1f  busy: %d  %@",
                        framesReceived, framesProcessed,
                        framesReceived/t, framesProcessed/t,
                        depthCopies/(float)framesProcessed, pixbufCopies/(float)framesProcessed,
                        tooBusyForAFrame,
                        status];
    [self reset];
    return report;
}

@end
