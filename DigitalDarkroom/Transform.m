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
@synthesize remapPixelF;
@synthesize remapImageF;
@synthesize rowF;
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
        remapPixelF = nil;
        remapImageF = nil;
        rowF = nil;
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

+ (Transform *) colorTransform:(NSString *) n description:(NSString *) d
                rowTransform:(rowFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RowTrans;
    t.rowF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaTransform:(areaFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = AreaTrans;
    t.areaF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapPixel:(remapPixelFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapTrans;
    t.remapPixelF = f;
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
    Transform *copy = [[Transform alloc] init];
    copy.name = name;
    copy.type = type;
    copy.description = description;
    copy.pointF = pointF;
    copy.areaF = areaF;
    copy.remapImageF = remapImageF;
    copy.remapPixelF = remapPixelF;
    copy.rowF = rowF;
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
//          function:(Pixel (^) (Pixel p))pointFunction {
#endif
