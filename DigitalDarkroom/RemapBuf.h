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

// Since these are stored where we keep distances:

typedef long RemapDist;      // separation in the array of the remap

// We make all these specials negative, and add a bias to make all the moves
// positive.  The keeps testing and moving quite fast.

#define REMAP_MOVE_BIAS 32768

#ifdef notdef
typedef struct RemapPt_t {
    size_t x, y;
} RemapPt_t;

#define RP(a,b)  ((remapPt){a}, (remapPt{b})
#endif

typedef RemapDist *_Nullable *_Nonnull RemapArray_t;

// these macros help computer the distances of the remaps

#define RA   remapBuf.ra
#define REMAP_DIST(t, f)      (RemapDist)((&(t) - &(f))/sizeof(RemapDist) + REMAP_MOVE_BIAS)
#define REMAP_COLOR_TO(rc,t)    remapBuf.ra(t) = (SpecialRemaps)(rc)

@interface RemapBuf : NSMutableData {
    size_t w, h;
    RemapArray_t ra;  // remap array, ra[x][y] in our code
    RemapDist *rb;  // remap buffer
}

@property (assign)  size_t w, h;
@property (assign)  RemapArray_t ra;
@property (assign)  RemapDist *rb;

- (id)initWithWidth:(size_t) w height:(size_t)h;

@end

NS_ASSUME_NONNULL_END
