//
//  PixBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "PixBuf.h"

@interface PixBuf ()

@property (strong, nonatomic)   NSData *buffer;

@end

@implementation PixBuf

@synthesize w, h;
@synthesize pa, pb;
@synthesize buffer;

- (id)initWithWidth:(size_t) w height:(size_t)h {
    self = [super init];
    if (self) {
        size_t bufSize = sizeof(Pixel *) * h +     // array of row arrays into ...
            sizeof(Pixel) * h * w;      // ... pixel buffer
        buffer = [[NSMutableData alloc] initWithLength:bufSize];
        self.w = w;
        self.h = h;
        pa = (PixelArray_t)buffer.bytes;
        pb = (Pixel *)(pa + h);
        Pixel *rowPtr = pb;
        // point rows pointer to appropriate location in 2D array
        for (int y = 0; y < h; y++)
            pa[y] = (rowPtr + w * y * sizeof(Pixel));
    }
    return self;
}

@end
