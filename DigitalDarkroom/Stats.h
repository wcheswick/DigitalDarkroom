//
//  Stats.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/20/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Stats : NSObject {
    int framesReceived, framesProcessed;
    int emptyFrames, framesIgnored, depthMissing;
    int depthFrames, depthDropped, imageFrames, imagesDropped;
    int depthNaNs, depthZeros, noVideoPixelBuffer;
    int depthCopies, pixbufCopies;
    NSDate *lastProcessed;
}

@property (assign)              int framesReceived, framesProcessed;
@property (assign)              int emptyFrames, framesIgnored, depthMissing, depthDropped;
@property (assign)              int depthFrames, depthNaNs, depthZeros;
@property (assign)              int imageFrames, imagesDropped, noVideoPixelBuffer;
@property (assign)              int depthCopies, pixbufCopies;
@property (nonatomic, strong)   NSDate *lastProcessed;

- (NSString *) report;

extern Stats *stats;

@end

NS_ASSUME_NONNULL_END
