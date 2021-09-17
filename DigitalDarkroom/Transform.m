//
//  Transform.m
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "Transform.h"

@implementation Transform

@synthesize name, description, helpPath;
@synthesize broken;
@synthesize transformsArrayIndex;
@synthesize type;
@synthesize hasParameters;
@synthesize ipPointF;
@synthesize areaF;
@synthesize depthVisF;
@synthesize remapImageF;
@synthesize remapPolarF;
@synthesize remapSizeF;
@synthesize low, value, high;
@synthesize paramName, lowValueFormat, highValueFormat;
@synthesize newValue;
@synthesize remapTable;


- (id)init {
    self = [super init];
    if (self) {
        transformsArrayIndex = -1;    // assigned in transforms
        type = NullTrans;
        ipPointF = nil;
        broken = NO;
        helpPath = nil;
//        pointF = nil;
        areaF = nil;
        remapImageF = nil;
        remapPolarF = nil;
        remapSizeF = nil;
        depthVisF = nil;
        low = high = 0;
        newValue = NO;
        hasParameters = NO;
        remapTable = NULL;
        paramName = nil;
        lowValueFormat = highValueFormat = @"%d";
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
                remapImage:(RemapImage_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapImage;
    t.remapImageF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapPolar:(RemapPolar_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapPolar;
    t.remapPolarF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapSize:(RemapSize_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapSize;
    t.remapSizeF = f;
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
    copy.transformsArrayIndex = transformsArrayIndex;
    copy.description = description;
//    copy.pointF = pointF;
    copy.areaF = areaF;
    NSLog(@" **** copy areaTransform %@,   areaF: %p:", copy.name, copy.areaF);
    copy.depthVisF = depthVisF;
    copy.remapImageF = remapImageF;
    copy.remapPolarF = remapPolarF;
    copy.remapSizeF = remapSizeF;
    copy.low = low;
    copy.high = high;
    copy.value = value;
    copy.newValue = newValue;
    copy.hasParameters = hasParameters;
    copy.remapTable = NULL;
    return copy;
}

@end
