//
//  ChBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "ChBuf.h"

@interface ChBuf ()

@property (strong, nonatomic)   NSData *buffer;

@end

@implementation ChBuf

@synthesize w, h;
@synthesize ca, cb;
@synthesize buffer;

- (id)initWithSize:(CGSize)s {
    self = [super init];
    if (self) {
        self.w = s.width;
        self.h = s.height;
        size_t rowSize = sizeof(channel) * w;
        assert(rowSize % sizeof(int) == 0);   // must fit in ints
        size_t arraySize = sizeof(channel *) * h;
        buffer = [[NSMutableData alloc] initWithLength:arraySize + rowSize * h];
        assert(buffer);
        ca = (ChannelArray_t)buffer.bytes;
        cb = (channel *)buffer.bytes + arraySize;
        channel *rowPtr = cb;
        // point rows pointer to appropriate location in 2D array

        channel **crp = ca;
        for (int y = 0; y < h; y++) {
            *crp++ = rowPtr;
            rowPtr += w;
        }
#ifdef EARLYDEBUG
        size_t bytes = (void *)rowPtr - (void *)pb;
        size_t nPixels = bytes/sizeof(Pixel);
        NSLog(@" BBB  %zu  %zu %d %lu", bytes, nPixels, w*h, 4*w*h);
        assert(rowPtr == (void *)pb + w * h * sizeof(Pixel));
#endif
#ifdef DEBUG
        [self verify];
#endif

    }
    return self;
}

// This code offers a lot of opportunities for memory leaks and such,
// which are particularly hard to figure out in iOS.  Make sure our
// pointers and sizes make sense.

- (void) verify {
    //    NSLog(@"&pa[%3d] %p is %p", 0, &pa[0], pa[0]);
    //    NSLog(@"&pa[%3lu] %p is %p", w-1, &pa[w-1], pa[w-1]);
    //    NSLog(@"&pb[0]   = %p", &pb[0]);

    size_t bufferLen = buffer.length;
    void *bufferEnd = &cb[w*h];
    assert(buffer.length >= (bufferEnd - (void *)cb));
    // troll for access errors:
    assert((void *)cb >= buffer.bytes);
    assert((void *)cb < buffer.bytes + bufferLen);

    // is our pixel buffer addressable?
    for (int i=0; i<h * w; i++) {
        assert((void *)&cb[i] < bufferEnd);
        channel c = cb[i];
        USED(c);
    }
    
    // are the row arrays in range? First, the location of each row array pointer.
    // This array is at the beginning of our memory block, before the pixel buffer.
    for (int y=0; y<h; y++) {
        assert((void *)&ca[y] >= buffer.bytes);
        assert((void *)&ca[y] < (void *)cb);
    }
    
    // do their row pointers fall into the pixel buffer area?
    for (int y=0; y<h; y++) {
        assert((void *)ca[y] >= (void *)cb);
        assert((void *)ca[y] < bufferEnd);
    }
    
    for (int y=0; y<h; y++) {
        for (int x=0; x<w; x++) {
            void *chAddr = (void *)&ca[y][x];
            assert(chAddr >= (void *)cb);
            assert(chAddr < bufferEnd);
            long chIndex = (void *)cb + w * h * sizeof(channel) - chAddr;
            USED(chIndex);
            channel c = ca[y][x];
            USED(c);
        }
    }
}

#ifdef NEEDED_QM
- (void) copyPixelsTo:(PixBuf *) dest {
    assert(dest);
    if (w != dest.w || h != dest.h) {
        NSLog(@"copyPixelsTo: size mismatch %zu x %zu to %zu x %zu",
              w, h, dest.w, dest.h);
        abort();
    }
    assert(w == dest.w);
    assert(h == dest.h);    // the PixelArray pointers in the destination will do
    memcpy(dest.pb, pb, w * h * sizeof(Pixel));
    [self verify];
}
#endif

@end
