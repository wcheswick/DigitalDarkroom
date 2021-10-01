//
//  DepthBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

#define BAD_DEPTH   0    // NaN or zero

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
- (void) verify;
- (void) findDepthRange;
- (void) scaleFrom:(DepthBuf *) sourceDepthBuf;
- (void) verifyDepths;

NS_ASSUME_NONNULL_END

@end
