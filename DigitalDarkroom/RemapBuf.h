//
//  RemapBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

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
    Remap_Unset = -7,
};

// The remap buffer contains w*h entries describing where the corresponding
// pixel should come from, or what color it should be. Corresponding pixel is
// a simple index.  The colors are a negative number.
//
// Use these macros to compute entries.  They assume some version of "remapBuf" is in scope.

typedef int BufferIndex;      // index into a buffer at x,y

#define RBI(x,y)                ((x) + remapBuf.w*(y))  // buffer index as function of x,y
#define REMAP_TO(tx,ty, fx,fy)  remapBuf.rb[RBI((tx),(ty))] = (int)RBI(fx,fy)
#define REMAP_COLOR(tx, ty, rc) remapBuf.rb[RBI((tx),(ty))] = rc
#define IS_IN_REMAP(x,y)    ((x) >= 0 && (x) < remapBuf.w && (y) >= 0 && (y) < remapBuf.h)

@interface RemapBuf : NSMutableData {
    size_t w, h;
    BufferIndex *rb;  // remap buffer
}

@property (assign)  size_t w, h;
@property (assign)  BufferIndex *rb;

- (id)initWithWidth:(size_t) w height:(size_t)h;
- (void) verify;

@end

NS_ASSUME_NONNULL_END
