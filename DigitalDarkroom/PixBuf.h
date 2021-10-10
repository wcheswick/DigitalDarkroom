//
//  PixBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN


typedef Pixel *_Nullable *_Nonnull PixelArray_t;

@interface PixBuf : NSMutableData {
    CGSize size;    // always integer values here
    PixelArray_t pa;  // pixel array, pb[y][x] in our code
    Pixel *pb;      // pixel buffer, w*h contiguous pixels
}

@property (assign)  CGSize size;;
@property (assign)  PixelArray_t pa;
@property (assign)  Pixel *pb;

- (id)initWithSize:(CGSize)s;
- (void) copyPixelsTo:(PixBuf *) dest;
- (void) verify;

- (void) assertPaInrange: (int) y x:(int)x;
- (Pixel) check_get_Pa:(int) y X:(int)x;
- (void) scaleFrom:(PixBuf *) sourcePixBuf;

- (void) loadPixelsFromImage:(UIImage *) image;
- (UIImage *) toImage;

@end

NS_ASSUME_NONNULL_END
