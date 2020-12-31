//
//  RemapBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "RemapBuf.h"

@implementation RemapBuf

@synthesize w, h;
@synthesize ra, rb;

- (id)initWithWidth:(size_t) w height:(size_t)h {
    self = [super initWithCapacity:sizeof(RemapDist *) * h +
            sizeof(RemapDist) * w * h];
    if (self) {
        self.w = w;
        self.h = h;
        ra = self.mutableBytes;
        rb = (RemapDist *)(ra + h);
        RemapDist *rowPtr = rb;
        // point rows pointer to appropriate location in 2D array
        for (int y = 0; y < h; y++)
            ra[y] = rowPtr + w * y * sizeof(RemapDist);
    }
    return self;
}

@end

