//
//  ChBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "ChBuf.h"

@implementation ChBuf

@synthesize w, h;
@synthesize ca, cb;

- (id)initForWidth:(size_t) w height:(size_t)h{
    self = [super initWithCapacity:sizeof(channel *) * h +
            sizeof(channel) * w * h];
    if (self) {
        size_t w = 40;
        size_t h = 20;
        self.w = w;
        assert(w % sizeof(int) == 0);   // hey, we've got standards!
        self.h = h;
        ca = self.mutableBytes;
        cb = (channel *)(ca + h);
        channel *rowPtr = cb;
        // point rows pointer to appropriate location in 2D array
        for (int y = 0; y < h; y++)
            ca[y] = (rowPtr + w * y * sizeof(channel));
    }
    return self;
}

@end
