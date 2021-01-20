//
//  PixBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "PixBuf.h"

@interface PixBuf ()

@property (strong, nonatomic)   NSData *buffer;

@end

@implementation PixBuf

@synthesize w, h;
@synthesize pa, pb;
@synthesize buffer;

- (id)initWithSize:(CGSize)s {
    self = [super init];
    if (self) {
        self.w = s.width;
        self.h = s.height;
        size_t rowSize = sizeof(Pixel) * w;
        size_t arraySize = sizeof(Pixel *) * h;
        buffer = [[NSMutableData alloc] initWithLength:arraySize + rowSize * h];
        pa = (PixelArray_t)buffer.bytes;
        pb = (Pixel *)buffer.bytes + arraySize;
        Pixel *rowPtr = pb;
        // point rows pointer to appropriate location in 2D array

        Pixel **prp = pa;
        for (int y = 0; y < h; y++) {
            *prp++ = rowPtr;
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
    void *bufferEnd = &pb[w*h];
    assert(buffer.length >= (bufferEnd - (void *)pb));
    // troll for access errors:
    assert((void *)pb >= buffer.bytes);
    assert((void *)pb < buffer.bytes + bufferLen);

    // is our pixel buffer addressable?
    for (int i=0; i<h * w; i++) {
        assert((void *)&pb[i] < bufferEnd);
        Pixel p = pb[i];
        USED(p);
    }
    
    // are the row arrays in range? First, the location of each row array pointer.
    // This array is at the beginning of our memory block, before the pixel buffer.
    for (int y=0; y<h; y++) {
        assert((void *)&pa[y] >= buffer.bytes);
        assert((void *)&pa[y] < (void *)pb);
    }
    
    // do their row pointers fall into the pixel buffer area?
    for (int y=0; y<h; y++) {
        assert((void *)pa[y] >= (void *)pb);
        assert((void *)pa[y] < bufferEnd);
    }
    
    for (int y=0; y<h; y++) {
        for (int x=0; x<w; x++) {
            void *pixAddr = (void *)&pa[y][x];
            assert(pixAddr >= (void *)pb);
            assert(pixAddr < bufferEnd);
            long pixIndex = (void *)pb + w * h * sizeof(Pixel) - pixAddr;
            USED(pixIndex);
            Pixel p = pa[y][x];
            USED(p);
        }
    }
}

- (void) copyPixelsTo:(PixBuf *) dest {
    assert(w == dest.w);
    assert(h == dest.h);    // the PixelArray pointers in the destination will do
    memcpy(dest.pb, pb, w * h * sizeof(Pixel));
    [self verify];
}

// not used at the moment, maybe never:
- (id)copyWithZone:(NSZone *)zone {
    PixBuf *copy = [[PixBuf alloc] initWithSize:CGSizeMake(w, h)];
    memcpy(copy.pb, pb, w * h * sizeof(Pixel));
    return copy;
}

@end
