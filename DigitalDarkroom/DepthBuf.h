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

typedef float Distance;     // in meters
typedef Distance *_Nullable *_Nonnull DepthArray_t;

@interface DepthBuf : NSObject {
    size_t w, h;
    Distance minDepth, maxDepth;
    DepthArray_t da;  // pixel array, pb[y][x] in our code
    Distance *db;      // pixel buffer, w*h contiguous pixels
}

@property (assign)  Distance minDepth, maxDepth;
@property (assign)  DepthArray_t da;
@property (assign)  Distance *db;
@property (assign)  size_t w, h;

- (id)initWithSize:(CGSize) s;
//- (Distance) distAtX:(int)x Y:(int)y;
- (void) copyDepthsTo:(DepthBuf *) dest;
- (void) verify;

NS_ASSUME_NONNULL_END

@end
