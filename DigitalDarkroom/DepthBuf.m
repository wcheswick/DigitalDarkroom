//
//  DepthBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "DepthBuf.h"
#import "Defines.h"

@interface DepthBuf ()

@property (strong, nonatomic)   NSData *buffer;

@end

@implementation DepthBuf

@synthesize da, db;
@synthesize minDepth, maxDepth;
@synthesize w, h;
@synthesize buffer;

- (id)initWithSize:(CGSize) s {
    self = [super init];
    if (self) {
        w = s.width;
        h = s.height;
        minDepth = maxDepth = 0.0;   // this is computed and updated each time through an image
        size_t rowSize = sizeof(Distance) * w;
        size_t arraySize = sizeof(Distance *) * h;
        buffer = [[NSMutableData alloc] initWithLength:arraySize + rowSize * h];
        assert(buffer);
        da = (DepthArray_t)buffer.bytes;
        db = (Distance *)buffer.bytes + arraySize;
        Distance *rowPtr = db;
        // point rows pointer to appropriate location in 2D array

        Distance **drp = da;
        for (int y = 0; y < h; y++) {
            *drp++ = rowPtr;
            rowPtr += w;
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
    //    NSLog(@"&pa[%3d] %p is %p", 0, &pa[0], pa[0]);
    //    NSLog(@"&pa[%3lu] %p is %p", w-1, &pa[w-1], pa[w-1]);
    //    NSLog(@"&pb[0]   = %p", &pb[0]);

    size_t bufferLen = buffer.length;
    void *bufferEnd = &db[w*h];
    assert(buffer.length >= (bufferEnd - (void *)db));
    // troll for access errors:
    assert((void *)db >= buffer.bytes);
    assert((void *)db < buffer.bytes + bufferLen);

    // is our pixel buffer addressable?
    for (int i=0; i<h * w; i++) {
        assert((void *)&db[i] < bufferEnd);
        Distance p = db[i];
        USED(p);
    }
    
    // are the row arrays in range? First, the location of each row array pointer.
    // This array is at the beginning of our memory block, before the pixel buffer.
    for (int y=0; y<h; y++) {
        assert((void *)&da[y] >= buffer.bytes);
        assert((void *)&da[y] < (void *)db);
    }
    
    // do their row pointers fall into the pixel buffer area?
    for (int y=0; y<h; y++) {
        assert((void *)da[y] >= (void *)db);
        assert((void *)da[y] < bufferEnd);
    }
    
    for (int y=0; y<h; y++) {
        for (int x=0; x<w; x++) {
            void *pixAddr = (void *)&da[y][x];
            assert(pixAddr >= (void *)db);
            assert(pixAddr < bufferEnd);
            long pixIndex = (void *)db + w * h * sizeof(Distance) - pixAddr;
            Distance d = da[y][x];  // try an access
            USED(pixIndex);
            USED(d);
        }
    }
}

// moving averages to smooth out changes in minimum and maximum depths used

#define MA_COUNT    (MAX_FRAME_RATE/2)

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
    for (int i=0; i<w * h; i++) {
        float z = db[i];
        if (!isnan(z) && z > 0) {   // ignore bad depth data
            if (z > maxDepth)
                maxDepth = z;
            if (z < minDepth)
                minDepth = z;
        }
    }
    minDepth = ma(&min_dist_buf, minDepth);
    maxDepth = ma(&max_dist_buf, maxDepth);
}

- (void) copyDepthsTo:(DepthBuf *) dest {
    assert(w == dest.w);
    assert(h == dest.h);    // the PixelArray pointers in the destination will do
    memcpy(dest.db, db, w * h * sizeof(Distance));
    [self verify];
}

// not used at the moment, maybe never:
- (id)copyWithZone:(NSZone *)zone {
    DepthBuf *copy = [[DepthBuf alloc] initWithSize:CGSizeMake(w, h)];
    memcpy(copy.db, db, w * h * sizeof(Distance));
    return copy;
}

@end
