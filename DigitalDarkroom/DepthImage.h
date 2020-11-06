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

#define MIN_DEPTH   0.0     // meters/ a constant, for now
#define MAX_DEPTH   10.0    // meters

@interface DepthImage : NSObject {
    float *buf;    // 0, or a size.w x size.h buffer of depths, in meters
    CGSize size;        // in floats
}

@property (assign)  float *buf;
@property (assign)  CGSize size;

- (id)initWithSize:(CGSize) s;

@end

NS_ASSUME_NONNULL_END
