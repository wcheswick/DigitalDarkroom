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
    int emptyFrames, framesIgnoredLocking, depthMissing;
    int depthFrames, depthDropped, imageFrames, imagesDropped;
    int depthNaNs, depthZeros, noVideoPixelBuffer;
    int depthCopies, pixbufCopies, transformsBusy;
    NSString *status;
    NSDate *lastProcessed;
}

@property (assign)              int framesReceived, framesProcessed;
@property (assign)              int emptyFrames, framesIgnoredLocking, depthMissing, depthDropped;
@property (assign)              int depthFrames, depthNaNs, depthZeros;
@property (assign)              int imageFrames, imagesDropped, noVideoPixelBuffer;
@property (assign)              int depthCopies, pixbufCopies, transformsBusy;
@property (nonatomic, strong)   NSString *status;
@property (nonatomic, strong)   NSDate *lastProcessed;

- (NSString *) report;

extern Stats *stats;

@end

NS_ASSUME_NONNULL_END
