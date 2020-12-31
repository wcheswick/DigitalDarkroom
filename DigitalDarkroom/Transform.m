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
//@synthesize pointF;
@synthesize ipPointF;
@synthesize areaF;
@synthesize depthVisF;
@synthesize remapImageF;
@synthesize type;
@synthesize low, value, high;
@synthesize newValue;
@synthesize hasParameters;
@synthesize remapTable;


- (id)init {
    self = [super init];
    if (self) {
        ipPointF = nil;
//        pointF = nil;
        areaF = nil;
        remapImageF = nil;
        depthVisF = nil;
        low = high = 0;
        newValue = NO;
        hasParameters = NO;
        remapTable = NULL;
    }
    return self;
}

+ (Transform *) depthVis:(NSString *) n description:(NSString *) d
                depthVis:(depthVis_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = DepthVis;
    t.depthVisF = f;
    return t;
}

+ (Transform *) colorTransform:(NSString *) n
                   description:(NSString *) d
                 inPlacePtFunc:(inPlacePtFunc_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = ColorTrans;
    t.ipPointF = f;
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
                remapImage:(ComputeRemap_t) f {
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
//    copy.pointF = pointF;
    copy.areaF = areaF;
    copy.depthVisF = depthVisF;
    copy.remapImageF = remapImageF;
    copy.low = low;
    copy.high = high;
    copy.value = value;
    copy.newValue = newValue;
    copy.hasParameters = hasParameters;
    copy.remapTable = NULL;
    return copy;
}

@end
