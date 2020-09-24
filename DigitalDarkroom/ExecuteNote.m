//
//  ExecuteNote.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/22/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "ExecuteNote.h"

@implementation ExecuteNote

@synthesize p, updatedP;
@synthesize remapTable;

- (id) init {
    self = [super init];
    if (self) {
        remapTable = nil;
    }
    return self;
}

@end
