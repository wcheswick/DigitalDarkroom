//
//  TransformInstance.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/14/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "TransformInstance.h"

@implementation TransformInstance

@synthesize hasParams;
@synthesize value;
@synthesize remapBuf;
@synthesize elapsedProcessingTime;
@synthesize timesCalled;


- (id) initFromTransform:(Transform *)transform {
    self = [super init];
    if (self) {
        remapBuf = nil;
        hasParams = transform.hasParameters;
        value = transform.value;
        timesCalled = 0;
        elapsedProcessingTime = 0;
    }
    return self;
}

- (NSString *) valueInfo {
    if (hasParams)
        return [NSString stringWithFormat:@"%d", value];
    else
        return @" ";
}

- (NSString *) timeInfo {
    if (timesCalled == 0 || elapsedProcessingTime == 0)
        return @" ";
    else
        return [NSString stringWithFormat:@"%5.1f", 1000.0*elapsedProcessingTime/timesCalled];
}

@end
