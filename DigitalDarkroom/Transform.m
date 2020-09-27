//
//  Transform.m
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "Transform.h"

@implementation Transform

@synthesize name, description;
@synthesize pointF;
@synthesize areaF;
@synthesize remapImageF;
@synthesize remapPolarF;
@synthesize type;
@synthesize low, initial, high;
@synthesize p, pUpdated;
@synthesize remapTable;
@synthesize elapsedProcessingTime;


- (id)init {
    self = [super init];
    if (self) {
        pointF = nil;
        areaF = nil;
        remapImageF = nil;
        remapPolarF = nil;
        low = initial = high = 0;
        p = initial;
        pUpdated = NO;
        remapTable = NULL;
        elapsedProcessingTime = 0;
    }
    return self;
}

+ (Transform *) colorTransform:(NSString *) n description:(NSString *) d
                pointTransform:(pointFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = ColorTrans;
    t.pointF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaFunction:(areaFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = AreaTrans;
    t.areaF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapPolarPixel:(remapPolarPixelFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapTrans;
    t.remapPolarF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapImage:(remapImageFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapTrans;
    t.remapImageF = f;
    return t;
}

- (void) clearRemap {
    if (remapTable) {
        free(remapTable);
        remapTable = nil;
    }
}

- (void) dealloc {
    [self clearRemap];
}

- (id)copyWithZone:(NSZone *)zone {
    Transform *copy = [[Transform alloc] init];
    copy.name = name;
    copy.type = type;
    copy.description = description;
    copy.pointF = pointF;
    copy.areaF = areaF;
    copy.remapImageF = remapImageF;
    copy.remapPolarF = remapPolarF;
    copy.low = low;
    copy.high = high;
    copy.initial = initial;
    copy.p = p;
    copy.pUpdated = NO;
    copy.remapTable = NULL;
    return copy;
}

@end
