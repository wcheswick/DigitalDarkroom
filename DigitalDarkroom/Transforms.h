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
    NSMutableArray *sequence;       // what we are supposed to execute (must be synchronized when changed)
    BOOL volatile sequenceChanged;  // if we need to update our local copy
    
    size_t bytesPerRow;
    NSArray *newTransformList;      // must be locked, set by caller, cleared here
    CGFloat finalScale;   // to reach the desired display dimensions
}

@property (nonatomic, strong)   NSArray *categoryNames;
@property (nonatomic, strong)   NSArray *categoryList;
@property (nonatomic, strong)   NSMutableArray *sequence;
@property (assign)              BOOL volatile sequenceChanged;
@property (assign)              size_t bytesPerRow;
@property (nonatomic, strong)   NSArray *updatedTransformList;
@property (assign)              volatile BOOL paramsChanged;
@property (assign)              CGFloat finalScale;

- (UIImage *) executeTransformsWithImage:(UIImage *) image;

@end

NS_ASSUME_NONNULL_END
