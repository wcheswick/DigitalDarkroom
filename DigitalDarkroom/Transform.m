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
@synthesize remapTable;
@synthesize low, param, high;
@synthesize changed;


- (id)init {
    self = [super init];
    if (self) {
        remapTable = nil;
        pointF = nil;
        areaF = nil;
        remapImageF = nil;
        remapPolarF = nil;
        low = param = high = 0;
        changed = YES;
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

- (id)copyWithZone:(NSZone *)zone {
    Transform *copy = [[self class] allocWithZone:zone];
    copy.name = name;
    copy.type = type;
    copy.description = description;
    copy.pointF = pointF;
    copy.areaF = areaF;
    copy.remapPolarF = remapPolarF;
    NSLog(@"remapImageF: %p", remapImageF);
    copy.remapImageF = remapImageF;
    NSLog(@"remapImageF: %p", remapImageF);
    NSLog(@"remaps: %p", copy.remapImageF);
    copy.low = low;
    copy.param = param;
    copy.high = high;
    copy.remapTable = nil;
    return copy;
}

- (void) dealloc {
    if (remapTable)
        free(remapTable);
}

@end

#ifdef notdef
initWithName:@"Luminance"
description:@"Convert to pixel brightness"
function:^(Pixel p) {
    channel lum = LUM(p);   /* wasteful, but cleaner code */
    return SETRGB(lum, lum, lum);
}];
#endif
