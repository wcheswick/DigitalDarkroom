//
//  Transforms.h
//  DigitalDarkroom
//
//  Created by ches on 9/16/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Transform.h"

NS_ASSUME_NONNULL_BEGIN

#define A(im, x,y)  (Pixel *)((im).image + (x) + (y)*(im).bytes_per_row) // address of Pixel at x, y

#define BITMAP_OPTS kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst

@interface Transforms : NSObject {
    NSMutableArray *categoryNames;
    NSMutableArray *categoryList;
    size_t bytesPerRow;
    NSMutableArray *masterTransformList;
    volatile BOOL listChanged, paramsChanged, busy;
}

@property (nonatomic, strong)   NSArray *categoryNames;
@property (nonatomic, strong)   NSArray *categoryList;
@property (assign)              NSMutableArray *transforms;
@property (assign)              size_t bytesPerRow;
@property (nonatomic, strong)   NSMutableArray *masterTransformList;
@property (assign)              volatile BOOL listChanged, paramsChanged, busy;

- (UIImage *) executeTransformsWithContext:(CGContextRef)context;
- (UIImage *) executeTransformsWithImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
