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
@synthesize type;
@synthesize remapTable;


- (id)init {
    self = [super init];
    if (self) {
        remapTable = nil;
        pointF = nil;
        areaF = nil;
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
                areaTransform:(areaFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = AreaTrans;
    t.areaF = f;
    return t;
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
