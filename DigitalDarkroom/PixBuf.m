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

@synthesize size;
@synthesize pa, pb;
@synthesize buffer;

- (id)initWithSize:(CGSize)s {
    self = [super init];
    if (self) {
        self.size = s;
        size_t rowSize = sizeof(Pixel) * size.width;
        size_t arraySize = sizeof(Pixel *) * size.height;
        buffer = [[NSMutableData alloc] initWithLength:arraySize + rowSize * size.height];
        assert(buffer);
        pa = (PixelArray_t)buffer.bytes;
        pb = (Pixel *)buffer.bytes + arraySize;
        Pixel *rowPtr = pb;
        // point rows pointer to appropriate location in 2D array

        Pixel **prp = pa;
        for (int y = 0; y < size.height; y++) {
            *prp++ = rowPtr;
            rowPtr += (int)size.width;
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
    void *bufferEnd = &pb[(int)(size.height * size.width)];
    assert(buffer.length >= (bufferEnd - (void *)pb));
    // troll for access errors:
    assert((void *)pb >= buffer.bytes);
    assert((void *)pb < buffer.bytes + bufferLen);

    // is our pixel buffer addressable?
    for (int i=0; i<size.height * size.width; i++) {
        assert((void *)&pb[i] < bufferEnd);
        Pixel p = pb[i];
        USED(p);
    }
    
    // are the row arrays in range? First, the location of each row array pointer.
    // This array is at the beginning of our memory block, before the pixel buffer.
    for (int y=0; y<size.height; y++) {
        assert((void *)&pa[y] >= buffer.bytes);
        assert((void *)&pa[y] < (void *)pb);
    }
    
    // do their row pointers fall into the pixel buffer area?
    for (int y=0; y<size.height; y++) {
        assert((void *)pa[y] >= (void *)pb);
        assert((void *)pa[y] < bufferEnd);
    }
    
    for (int y=0; y<size.height; y++) {
        for (int x=0; x<size.width; x++) {
            void *pixAddr = (void *)&pa[y][x];
            assert(pixAddr >= (void *)pb);
            assert(pixAddr < bufferEnd);
            long pixIndex = (void *)(pb) + (int)(size.width * size.height) * sizeof(Pixel) - pixAddr;
            USED(pixIndex);
            Pixel p = pa[y][x];
            USED(p);
        }
    }
    
    // contiguous and consistent addressing?
    int i=0;
    for (int y=0; y<size.height; y++) {
        for (int x=0; x<size.width; x++) {
            void *pixAddr = (void *)&pa[y][x];
            void *bAddr = (void *)&pb[i++];
            assert(pixAddr == bAddr);
        }
    }
}

- (void) copyPixelsTo:(PixBuf *) dest {
    assert(dest);
    if (!SAME_SIZE(self.size, dest.size)) {
        NSLog(@"copyPixelsTo: size mismatch %.0f x %.0f to %.0f x %.0f",
              size.width, size.height, dest.size.width, dest.size.height);
        abort();
    }
    assert(size.width == dest.size.width);
    assert(size.height == dest.size.height);    // the PixelArray pointers in the destination will do
    memcpy(dest.pb, pb, size.width * size.height * sizeof(Pixel));
    [dest verify];
}

- (void) assertPaInrange: (int) y x:(int)x {
    assert(x >= 0 && x < size.width);
    assert(y >= 0 && y < size.height);
}

- (Pixel) check_get_Pa:(int) y X:(int)x {
    [self assertPaInrange:y x:x];
    return self.pa[y][x];
}

// This should be cleverer than just picking pixels
- (void) scaleFrom:(PixBuf *) sourcePixBuf {
    double yScale = size.height/sourcePixBuf.size.height;
    double xScale = size.width/sourcePixBuf.size.width;
    for (int x=0; x<size.width; x++) {
        int sx = trunc(x/xScale);
        assert(sx <= sourcePixBuf.size.width);
        for (int y=0; y<size.height; y++) {
            int sy = trunc(y/yScale);
            assert(sy < sourcePixBuf.size.height);
            pa[y][x] = sourcePixBuf.pa[sy][sx];   // XXXXXX died here during reconfiguration
// and again...
            
        }
    }
}

- (id)copyWithZone:(NSZone *)zone {
    PixBuf *copy = [[PixBuf alloc] initWithSize:size];
    memcpy(copy.pb, pb, size.width * size.height * sizeof(Pixel));
    [copy verify];
    return copy;
}

@end
