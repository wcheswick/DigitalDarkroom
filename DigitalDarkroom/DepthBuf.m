//
//  DepthBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "DepthBuf.h"
#import "Stats.h"

#import "Defines.h"

@interface DepthBuf ()

@property (strong, nonatomic)   NSData *buffer;

@end

@implementation DepthBuf

@synthesize da, db;
@synthesize minDepth, maxDepth;
@synthesize size, badDepths;
@synthesize buffer;

- (id)initWithSize:(CGSize) s {
    self = [super init];
    if (self) {
        self.size = s;
        minDepth = maxDepth = 0.0;   // this is computed and updated each time through an image
        badDepths = 0;
        size_t rowSize = sizeof(Distance) * size.width;
        size_t arraySize = sizeof(Distance *) * size.height;
        buffer = [[NSMutableData alloc] initWithLength:arraySize + rowSize * size.height];
        assert(buffer);
        da = (DepthArray_t)buffer.bytes;
        db = (Distance *)buffer.bytes + arraySize;
        Distance *rowPtr = db;
        // point rows pointer to appropriate location in 2D array

        Distance **drp = da;
        for (int y = 0; y < size.height; y++) {
            *drp++ = rowPtr;
            rowPtr += (int)size.width;
        }
#ifdef EARLYDEBUG
        size_t bytes = (void *)rowPtr - (void *)db;
        size_t nPixels = bytes/sizeof(Distance);
        NSLog(@" BBB  %zu  %zu %d %lu", bytes, nPixels, w*h, sizeof(Distance)*w*h);
        assert(rowPtr == (void *)db + w * h * sizeof(Distance));
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
#ifdef VERIFY_DEPTH_BUFFERS
    //    NSLog(@"&pa[%3d] %p is %p", 0, &pa[0], pa[0]);
    //    NSLog(@"&pa[%3lu] %p is %p", w-1, &pa[w-1], pa[w-1]);
    //    NSLog(@"&pb[0]   = %p", &pb[0]);

    size_t bufferLen = buffer.length;
    void *bufferEnd = &db[(int)(size.width * size.height)];
    assert(buffer.length >= (bufferEnd - (void *)db));
    // troll for access errors:
    assert((void *)db >= buffer.bytes);
    assert((void *)db < buffer.bytes + bufferLen);

    // is our depth buffer addressable?
    for (int i=0; i<(int)(size.width * size.height); i++) {
        assert((void *)&db[i] < bufferEnd);
        Distance p = db[i];
        USED(p);
    }
    
    // are the row arrays in range? First, the location of each row array pointer.
    // This array is at the beginning of our memory block, before the pixel buffer.
    for (int y=0; y<size.height; y++) {
        assert((void *)&da[y] >= buffer.bytes);
        assert((void *)&da[y] < (void *)db);
    }
    
    // do their row pointers fall into the pixel buffer area?
    for (int y=0; y<size.height; y++) {
        assert((void *)da[y] >= (void *)db);
        assert((void *)da[y] < bufferEnd);
    }
    
    for (int y=0; y<size.height; y++) {
        for (int x=0; x<size.width; x++) {
            void *pixAddr = (void *)&da[y][x];
            assert(pixAddr >= (void *)db);
            assert(pixAddr < bufferEnd);
            long pixIndex = (void *)db + (int)(size.width * size.height) * sizeof(Distance) - pixAddr;
            Distance d = da[y][x];  // try an access
            USED(pixIndex);
            USED(d);
        }
    }
    int i = 0;
    for (int y=0; y<size.height; y++) {
        for (int x=0; x<size.width; x++, i++) {
            float *p1 = &da[y][x];
            float *p2 = &db[i];
//            NSLog(@"%3d,%3d:  %p %p  %5.1f   %5.1f", x, y, &da[y][x], &db[i], *p1, *p2);
            assert(p1 == p2);
            assert(*p1 == *p2);
        }
    }
#endif
}

// moving averages to smooth out changes in minimum and maximum depths used

#define MA_COUNT    4   // (MAX_FRAME_RATE/2)  // half second is too long for slow depth viz

typedef struct ma_buf {
    int n;
    float sum;
    int next;
    float buf[MA_COUNT];
} ma_buff_t;

ma_buff_t min_dist_buf = {0, 0.0};
ma_buff_t max_dist_buf = {0, 0.0};

float
ma(ma_buff_t *b, float v) {
    if (b->n < MA_COUNT) {
        b->n++;
        b->sum += v;
    } else {
        b->sum += v - b->buf[b->next];
    }
    b->buf[b->next] = v;
    b->next = (b->next + 1) % MA_COUNT;
    return b->sum/b->n;
}

- (void) findDepthRange {
    minDepth = MAXFLOAT;
    maxDepth = 0.0;
    int okCount = 0;
    for (int i=0; i<(int)(size.width * size.height); i++) {
        float z = db[i];
        if (isnan(z))
            continue;
        assert(z >= 0);
        okCount++;
        if (z > maxDepth)
            maxDepth = z;
        if (z < minDepth)
            minDepth = z;
    }
    assert(okCount);
    if (minDepth <= maxDepth) {
        minDepth = ma(&min_dist_buf, minDepth);
        maxDepth = ma(&max_dist_buf, maxDepth);
    }
    assert(minDepth <= maxDepth);
    [self verifyDepths];
}

// NOTUSED at the moment
- (void) copyDepthsTo:(DepthBuf *) dest {
    assert(size.width == dest.size.width);
    assert(size.height == dest.size.height);    // the PixelArray pointers in the destination will do
    memcpy(dest.db, db, (int)(size.width * size.height) * sizeof(Distance));
    dest.badDepths = self.badDepths;
    stats.depthCopies++;
    [self verify];
}

- (id)copyWithZone:(NSZone *)zone {
    DepthBuf *copy = [[DepthBuf alloc] initWithSize:size];
    memcpy(copy.db, db, (int)(size.width * size.height) * sizeof(Distance));
    copy.maxDepth = self.maxDepth;
    copy.minDepth = self.minDepth;
    copy.size = self.size;
    copy.badDepths = self.badDepths;
    stats.depthCopies++;
    return copy;
}

- (void) scaleFrom:(DepthBuf *) sourceDepthBuf {
    minDepth = sourceDepthBuf.minDepth; // preserve original range
    maxDepth = sourceDepthBuf.maxDepth;
//    [self verifyDepthRange];
    double yScale = size.height/sourceDepthBuf.size.height;
    double xScale = size.width/sourceDepthBuf.size.width;
    for (int y=0; y<size.height; y++) {
        int sy = trunc(y/yScale);
        assert(sy < sourceDepthBuf.size.height);
        for (int x=0; x<size.width; x++) {
            int sx = trunc(x/xScale);
            assert(sx < sourceDepthBuf.size.width);
            Distance d = sourceDepthBuf.da[sy][sx];
            if (d == BAD_DEPTH)
                d = maxDepth;
            assert(d >= minDepth);
            assert(d <= maxDepth);
            da[y][x] = d;   // XXXXXX died here during reconfiguration
        }
    }
//    [self verifyDepthRange];
}

- (void) verifyDepths {
#ifdef VERIFY_DEPTHS
    assert(minDepth > 0);
    assert(maxDepth > 0);
    assert(minDepth <= maxDepth);
    int zeroDepths = 0;
    for (int i=0; i<size.width*size.height; i++) {
        Distance d = db[i];
        if (d == 0) {
            zeroDepths++;
            continue;
        }
        assert(d >= minDepth);
        assert(d <= maxDepth);
    }
    NSLog(@"verifyDepths: zeros, bads  %d %d", zeroDepths, badDepths);
#endif
}

@end
