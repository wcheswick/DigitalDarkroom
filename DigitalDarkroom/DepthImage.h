//
//  DepthImage.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 11/4/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

// this might be better auto-generated some day
#define MIN_DEPTH   0.1     // meters, must be > 0 since we take the log of it
#define MAX_DEPTH   10.0    // meters

typedef float Distance;     // in meters

@interface DepthImage : NSObject {
    Distance *buf;  // 0, or a size.w x size.h buffer of distances
    CGSize size;    // in floats
}

@property (assign)  float *buf;
@property (assign)  CGSize size;

- (id)initWithSize:(CGSize) s;
- (Distance) distAtX:(int)x Y:(int)y;

@end

NS_ASSUME_NONNULL_END
