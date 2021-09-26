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
    if (sx < remapBuf.size.width && sx >= 0 && sy < remapBuf.size.height && sy >= 0)
        UNSAFE_REMAP_TO(tx, ty, sx, sy);
    else
        REMAP_COLOR(tx, ty, Remap_OutOfRange);
}

@implementation RemapBuf

@synthesize size;
@synthesize rb;
@synthesize buffer;

- (id)initWithSize:(CGSize) s {
    self = [super init];
    if (self) {
        self.size = s;
        size_t bufferSize = size.width * sizeof(BufferIndex) * size.height;
        buffer = [[NSMutableData alloc] initWithLength:bufferSize];
        assert(buffer);
        assert(buffer.length >= bufferSize);
        rb = (BufferIndex *)buffer.bytes;
        self.size = size;
    }
    return self;
}

- (void) verify {
#ifdef VERIFY_REMAP_BUFFERS
    size_t bufferSize = size.width * size.height;
    for (int i=0; i<bufferSize; i++) {
        BufferIndex bi = rb[i];
        if (bi < 0)
            assert(bi >= Remap_Unset);
        else
            assert(bi < bufferSize);
    }
#endif
}

@end

