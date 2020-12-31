//
//  Params.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/17/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "Params.h"

@implementation Params

@synthesize hasValue, value;
@synthesize remapBuf;
@synthesize elapsedProcessingTime;

- (id)init {
    self = [super init];
    if (self) {
        hasValue = NO;
        value = 0;
        remapBuf = nil;
    }
    return self;
}

@end
