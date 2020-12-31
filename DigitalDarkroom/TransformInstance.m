//
//  TransformInstance.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/14/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "TransformInstance.h"

@implementation TransformInstance

@synthesize value;
@synthesize remapTable;
@synthesize elapsedProcessingTime;


- (id)init {
    self = [super init];
    if (self) {
        remapTable = NULL;
        elapsedProcessingTime = 0;
    }
    return self;
}

@end
