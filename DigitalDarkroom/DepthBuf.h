//
//  DepthBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

#define NAN_DEPTH   -2.0    // NaN or soemthing
#define ZERO_DEPTH  -1.0
#define BAD_DEPTH(d)    (d < 0)


typedef float Distance;     // in meters
typedef Distance *_Nullable *_Nonnull DepthArray_t;

@interface DepthBuf : NSObject {
    CGSize size;
    int badDepths;      // number of invalid entries
    Distance minDepth, maxDepth;
    DepthArray_t da;    // depth array, da[y][x]
    Distance *db;       // depth buffer, pointer to w*h contiguous depths in da
}

@property (assign)  Distance minDepth, maxDepth;    // some depth values are NAN, skip them and assume something
@property (assign)  DepthArray_t da;
@property (assign)  Distance *db;
@property (assign)  CGSize size;
@property (assign)  int badDepths;

- (id)initWithSize:(CGSize) s;
//- (Distance) distAtX:(int)x Y:(int)y;
- (void) copyDepthsTo:(DepthBuf *) dest;
- (void) findDepthRange;
- (void) scaleFrom:(DepthBuf *) sourceDepthBuf;
- (void) verifyDatastructure;
- (void) verifyDepths;
- (void) stats;

NS_ASSUME_NONNULL_END

@end
