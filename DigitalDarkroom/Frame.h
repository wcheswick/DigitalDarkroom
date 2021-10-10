//
//  Frame.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/6/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "PixBuf.h"
#import "DepthBuf.h"

NS_ASSUME_NONNULL_BEGIN

@interface Frame : NSObject {
    NSDate *creationTime;
    PixBuf *__nullable pixBuf;
    DepthBuf *__nullable depthBuf;
    UIImage *__nullable image;  // alternative to pixBuf
    BOOL pixBufNeedsUpdate;
    BOOL locked;
}

@property (nonatomic, strong)   NSDate *creationTime;
@property (nonatomic, strong)   PixBuf *__nullable pixBuf;
@property (nonatomic, strong)   DepthBuf *__nullable depthBuf;
@property (nonatomic, strong)   UIImage *__nullable image;  // alternative to pixBuf
@property (assign, atomic)      BOOL locked, pixBufNeedsUpdate;

- (void) save;
- (void) readImageFromPath:(NSString *) path;
- (UIImage *) toUIImage;
- (void) copyTo:(Frame *) dest;
- (void) scaleFrom:(const Frame *)srcFrame;

@end

NS_ASSUME_NONNULL_END
