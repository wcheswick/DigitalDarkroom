//
//  Transform.h
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DepthBuf.h"
#import "PixBuf.h"
#import "RemapBuf.h"
#import "DepthBuf.h"
#import "ChBuf.h"
#import "TransformInstance.h"
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

@class TransformInstance;

#define BITMAP_OPTS kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst

#define NO_DEPTH_TRANSFORM  (100)

typedef enum {
    ColorTrans,
    GeometricTrans,
    RemapTrans,
    RemapPolarTrans,
    AreaTrans,
    DepthVis,
    EtcTrans,
    NullTrans,
} transform_t;


typedef void (^ __nullable __unsafe_unretained inPlacePtFunc_t)(Pixel *buf, size_t n, int v);

typedef void (^ __nullable __unsafe_unretained ComputeRemap_t)
            (RemapBuf *remapBuf, TransformInstance *instance);

typedef void (^ __nullable __unsafe_unretained ComputePolarRemap_t)
            (RemapBuf *remapBuf, float r, float a, TransformInstance *instance,
             int tX, int tY);

#ifdef NOTUSED
typedef void (^ __nullable __unsafe_unretained
              pointFunction_t)(Pixel *src, Pixel *dest, int n);
#endif

typedef void (^ __nullable __unsafe_unretained
              areaFunction_t)(PixBuf *src,
                              PixBuf *dest,
                              ChBuf *chBuf0, ChBuf *chBuf1,
                              TransformInstance *instance);

typedef void (^ __nullable __unsafe_unretained
              depthVis_t)(const DepthBuf *depthBuf,
                          PixBuf *pixBuf,
                          TransformInstance *instance);

@interface Transform : NSObject {
    NSString *name, *description;
    NSString *helpPath;     // URL tags, slash-separated, general to specific
    BOOL broken;
    long transformsArrayIndex;
    transform_t type;
    BOOL hasParameters;
    inPlacePtFunc_t ipPointF;
    areaFunction_t areaF;
    depthVis_t depthVisF;
    int low, value, high;   // parameter range
    NSString *paramName;
    NSString *lowValueFormat, *highValueFormat;
    ComputeRemap_t remapImageF;
    ComputePolarRemap_t polarRemapF;
}

@property (nonatomic, strong)   NSString *name, *description, *helpPath;
@property (assign)              long transformsArrayIndex; 
@property (assign)              inPlacePtFunc_t ipPointF;
@property (assign)              BOOL broken;
//@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              depthVis_t depthVisF;
@property (unsafe_unretained)   ComputeRemap_t remapImageF;
@property (unsafe_unretained)   ComputePolarRemap_t polarRemapF;
@property (assign)              transform_t type;
@property (assign)              int low, value, high;
@property (nonatomic, strong)   NSString *paramName;
@property (nonatomic, strong)   NSString *lowValueFormat, *highValueFormat;
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

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapPolar:(ComputePolarRemap_t) f;

+ (Transform *) depthVis:(NSString *) n description:(NSString *) d
                depthVis:(depthVis_t) f;

- (void) clearRemap;

extern  Transform *nullTransform;

@end

NS_ASSUME_NONNULL_END
