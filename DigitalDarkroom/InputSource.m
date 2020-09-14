//
//  InputSource.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "InputSource.h"

@implementation InputSource

@synthesize sourceType;
@synthesize label;
@synthesize image;
@synthesize button;

- (id)init {
    self = [super init];
    if (self) {
        label = nil;
        image = nil;
        button = nil;
    }
    return self;
}

@end
