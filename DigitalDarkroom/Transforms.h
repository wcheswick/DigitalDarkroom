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

@interface Transforms : NSObject {
    NSMutableArray *categoryNames;
    NSMutableArray *categoryList;
    CGSize frameSize;
    NSMutableArray *list;
    volatile BOOL listChanged;
}

@property (nonatomic, strong)   NSArray *categoryNames;
@property (nonatomic, strong)   NSArray *categoryList;
@property (assign)              NSMutableArray *transforms;
@property (assign)              CGSize frameSize;
@property (nonatomic, strong)   NSMutableArray *list;
@property (assign)              volatile BOOL listChanged;

- (void) updateFrameSize: (CGSize) newSize;
- (void) setupForTransforming;
- (UIImage *) doTransformsOnContext:(CGContextRef)context;

@end

NS_ASSUME_NONNULL_END
