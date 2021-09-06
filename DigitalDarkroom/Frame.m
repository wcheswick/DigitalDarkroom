//
//  Frame.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/6/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Frame.h"

@implementation Frame

@synthesize pixBuf, depthBuf;
@synthesize creationTime;


- (id)init {
    self = [super init];
    if (self) {
        pixBuf = nil;
        depthBuf = Nil;
        creationTime = [NSDate now];
    }
    return self;
}

- (void) save {
    
}

@end
