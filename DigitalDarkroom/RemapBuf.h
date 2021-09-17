//
//  RemapBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

// In a remap transform, the pixels are simply moved around in the buffer, mostly.  We precompute
// these moves, and store the distance the pixel moves.  The move may not be more than 2^32 Pixel
// addresses.  Some of the destination pixels are simply set to a particular color, shown here:

enum SpecialRemaps {
    Remap_White = -1,
    Remap_Red = -2,
    Remap_Green = -3,
    Remap_Blue = -4,
    Remap_Black = -5,
    Remap_Yellow = -6,
    Remap_OutOfRange = -7,
    Remap_Unset = -8,
};

// The remap buffer contains w*h entries describing where the corresponding
// pixel should come from, or what color it should be. Corresponding pixel is
// a simple index.  The colors are a negative number.
//
// Use these macros to compute entries.  They assume some version of "remapBuf" is in scope.

typedef int BufferIndex;      // index into a buffer at x,y

#define CLIPX(x)      (((x) < 0) ? 0 : (((x) >= remapBuf.size.width) ? remapBuf.size.width - 1 : (x)))

// These macros all assume that remapBuf is available

#define RBI(x,y)    (int)((CLIPX(x)) + ((int)remapBuf.size.width)*(y))  // buffer index as function of x,y
#define REMAP_TO(tx,ty, fx,fy)  remapTo(remapBuf, tx, ty, fx, fy)
#define UNSAFE_REMAP_TO(tx,ty, fx,fy)  remapBuf.rb[RBI((tx),(ty))] = (int)RBI((fx),(fy))
#define REMAP_COLOR(tx, ty, rc) remapBuf.rb[RBI((tx),(ty))] = rc
#define IS_IN_REMAP(x,y,rb)    ((x) >= 0 && (x) < rb.size.width && \
    (y) >= 0 && (y) < rb.size.height)

#define REMAPBUF_IN_RANGE(x,y)   ((x) >= 0 && (x) < remapBuf.size.width && \
    (y) >= 0 && (y) < remapBuf.size.height)

@interface RemapBuf : NSMutableData {
    CGSize size;
    BufferIndex *rb;  // remap buffer
}

@property (assign)  CGSize size;
@property (assign)  BufferIndex *rb;

- (id)initWithSize:(CGSize) s;
- (void) verify;

extern void remapTo(RemapBuf *remapBuf, long tx, long ty, long sx, long sy);

@end

NS_ASSUME_NONNULL_END
