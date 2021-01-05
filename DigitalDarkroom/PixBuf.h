//
//  PixBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

typedef Pixel *_Nullable *_Nonnull PixelArray_t;

@interface PixBuf : NSMutableData {
    size_t w, h;
    PixelArray_t pa;  // pixel array, pb[y][x] in our code
    Pixel *pb;      // pixel buffer, w*h contiguous pixels
}

@property (assign)  size_t w, h;
@property (assign)  PixelArray_t pa;
@property (assign)  Pixel *pb;

- (id)initWithSize:(CGSize)s;
- (void) copyPixelsTo:(PixBuf *) dest;
- (void) verify;

@end

NS_ASSUME_NONNULL_END
