//
//  RemapBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "RemapBuf.h"

@interface RemapBuf ()

@property (strong, nonatomic)   NSData *buffer;

@end

// #define REMAP_TO(tx,ty, fx,fy)  remapBuf.rb[RBI((tx),(ty))] = (int)RBI(fx,fy)

void
remapTo(RemapBuf *remapBuf, long tx, long ty, long sx, long sy) {
    if (sx < remapBuf.w && sx >= 0 && sy < remapBuf.h && sy >= 0)
        UNSAFE_REMAP_TO(tx, ty, sx, sy);
    else
        REMAP_COLOR(tx, ty, Remap_OutOfRange);
}

@implementation RemapBuf

@synthesize w, h;
@synthesize rb;
@synthesize buffer;

- (id)initWithWidth:(size_t) w height:(size_t)h {
    self = [super init];
    if (self) {
        size_t bufferSize = w * sizeof(BufferIndex) * h;
        buffer = [[NSMutableData alloc] initWithLength:bufferSize];
        assert(buffer);
        assert(buffer.length >= bufferSize);
        rb = (BufferIndex *)buffer.bytes;
        self.w = w;
        self.h = h;
    }
    return self;
}

- (void) verify {
    size_t bufferSize = w * h;
    for (int i=0; i<bufferSize; i++) {
        BufferIndex bi = rb[i];
        if (bi < 0)
            assert(bi >= Remap_Unset);
        else
            assert(bi < bufferSize);
    }
}

@end

