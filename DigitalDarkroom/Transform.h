//
//  Transform.h
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DepthImage.h"
#import "PixBuf.h"
#import "RemapBuf.h"
#import "Params.h"
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN


#define BITMAP_OPTS kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst

#define NO_DEPTH_TRANSFORM  (100)

typedef enum {
    ColorTrans,
    GeometricTrans,
    RemapTrans,
    AreaTrans,
    DepthVis,
    EtcTrans,
} transform_t;


typedef void (^ __nullable __unsafe_unretained inPlacePtFunc_t)(Pixel *buf, size_t n);

typedef void (^ __nullable __unsafe_unretained ComputeRemap_t)(RemapBuf *remapBuf, Params *params);

#ifdef NOTUSED
typedef void (^ __nullable __unsafe_unretained
              pointFunction_t)(Pixel *src, Pixel *dest, int n);
#endif

typedef void (^ __nullable __unsafe_unretained
              areaFunction_t)(PixelArray_t src, PixelArray_t dest,
                              size_t w, size_t h, Params * __nullable param);

typedef void (^ __nullable __unsafe_unretained
              depthVis_t)(DepthImage *depthBuf,
                          Pixel *dest,
                          int p);

@interface Transform : NSObject {
    NSString *name, *description;
    transform_t type;
    BOOL hasParameters;
    inPlacePtFunc_t ipPointF;
//    pointFunction_t pointF;
    areaFunction_t areaF;
    depthVis_t depthVisF;
    ComputeRemap_t remapImageF;
}

@property (nonatomic, strong)   NSString *name, *description;
@property (assign)              inPlacePtFunc_t ipPointF;
//@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              depthVis_t depthVisF;
@property (unsafe_unretained)   ComputeRemap_t remapImageF;
@property (assign)              transform_t type;
@property (assign)              int low, value, high;
@property (assign)              BOOL hasParameters;
@property (assign)              BOOL newValue;
@property (assign)              PixelIndex_t * _Nullable remapTable;

#ifdef NOTUSED
+ (Transform *) colorTransform:(NSString *) n description:(NSString *) d
                 pointFunction:(pointFunction_t) f;
#endif

+ (Transform *) colorTransform:(NSString *) n
                    description:(NSString *) d
                    inPlacePtFunc:(inPlacePtFunc_t) f;

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaFunction:(areaFunction_t) f;

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapImage:(ComputeRemap_t) f;

+ (Transform *) depthVis:(NSString *) n description:(NSString *) d
                depthVis:(depthVis_t) f;

- (void) clearRemap;

@end

NS_ASSUME_NONNULL_END
