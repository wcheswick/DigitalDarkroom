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

#define NO_TRANSFORM    (-1)    // for indicies into transform array

#define SETRGBA(r,g,b,a)   (Pixel){b,g,r,a}
#define SETRGB(r,g,b)   SETRGBA(r,g,b,Z)
#define Z               ((1<<sizeof(channel)*8) - 1)
#define HALF_Z          (Z/2)

#define Black           SETRGB(0,0,0)
#define Grey            SETRGB(Z/2,Z/2,Z/2)
#define LightGrey       SETRGB(2*Z/3,2*Z/3,2*Z/3)
#define White           SETRGB(Z,Z,Z)
#define Red             SETRGB(Z,0,0)
#define Orange          SETRGB(Z,165,0)
#define Green           SETRGB(0,Z,0)
#define Blue            SETRGB(0,0,Z)
#define Yellow          SETRGB(Z,Z,0)
#define Magenta         SETRGB(Z,0,Z)
#define Cyan            SETRGB(0,Z,Z)
#define Amaranth        SETRGB(159,43,104)
#define BrightPurple    SETRGB(191,64,191)
#define Burgundy        SETRGB(128,0,32)
#define UnsetColor      SETRGBA(Z,Z/2,Z,Z-1)

@interface Transforms : NSObject {
    NSMutableArray<Transform *> *transforms;     // the depth transforms are first in the list
    BOOL debugTransforms;
    
    size_t bytesPerRow;
    NSArray *newTransformList;      // must be locked, set by caller, cleared here
    CGFloat finalScale;   // to reach the desired display dimensions
//    CGSize volatile transformSize;
}

@property (nonatomic, strong)   NSMutableArray<Transform *> *transforms;

//@property (assign)              size_t bytesPerRow;
//@property (nonatomic, strong)   NSArray *updatedTransformList;
//@property (assign)              volatile BOOL paramsChanged;
@property (assign)              BOOL debugTransforms;

- (Transform * __nullable) transformAtIndex:(long) index;

@end

NS_ASSUME_NONNULL_END
