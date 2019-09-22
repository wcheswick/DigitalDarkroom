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


- (id)initWithName:(NSString *)n description:(NSString *)d
            PointF:(pointFunction_t)f; {
    self = [super init];
    if (self) {
        name = n;
        description = d;
        pointF = f;
    }
    return self;
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
