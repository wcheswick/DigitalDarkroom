//
//  Transform.h
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Frame.h"
#import "RemapBuf.h"
#import "DepthBuf.h"
#import "ChBuf.h"
#import "TransformInstance.h"
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

@class TransformInstance;


typedef enum {
    ColorTrans,
    GeometricTrans,
    RemapImage,
    RemapPolar,
    RemapSize,
    AreaTrans,
    DepthVis,
    DepthTrans,
    EtcTrans,
    NullTrans,
} transform_t;


typedef void (^ __nullable __unsafe_unretained PtFunc_t)(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v);

typedef void (^ __nullable __unsafe_unretained RemapImage_t)
            (RemapBuf *remapBuf, TransformInstance *instance);

typedef void (^ __nullable __unsafe_unretained RemapPolar_t)
            (RemapBuf *remapBuf, float r, float a, TransformInstance *instance,
             int tX, int tY);

typedef void (^ __nullable __unsafe_unretained RemapSize_t)
            (RemapBuf *remapBuf, CGSize sourceSize, TransformInstance *instance);

#ifdef NOTUSED
typedef void (^ __nullable __unsafe_unretained
              pointFunction_t)(Pixel *src, Pixel *dest, int n);
#endif

typedef void (^ __nullable __unsafe_unretained
              areaFunction_t)(const PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                              ChBuf *chBuf0, ChBuf *chBuf1,
                              TransformInstance *instance);

typedef void (^ __nullable __unsafe_unretained
              depthVis_t)(const PixBuf *srcPixBufe, DepthBuf *depthBuf,
                          PixBuf *dstPixBuf,
                          TransformInstance *instance);

typedef void (^ __nullable __unsafe_unretained
              depthTrans_t)(const PixBuf *srcPixBufe, DepthBuf *srcDepthBuf,
                            Frame *dstFrame,
                            TransformInstance *instance);

@interface Transform : NSObject {
    NSString *name, *description;
    NSString *helpPath;     // URL tags, slash-separated, general to specific
    BOOL broken;
    BOOL needsScaledDepth;   // if cannot work just by changing the source pixbuf
    BOOL modifiesDepthBuf;
    long transformsArrayIndex;
    transform_t type;
    BOOL hasParameters;
    PtFunc_t ipPointF;
    areaFunction_t areaF;
    depthVis_t depthVisF;
    depthTrans_t depthTransF;
    int low, value, high;   // parameter range
    NSString *paramName;
    NSString *lowValueFormat, *highValueFormat;
    RemapImage_t remapImageF;
    RemapPolar_t remapPolarF;
    RemapSize_t remapSizeF;
}

@property (nonatomic, strong)   NSString *name, *description, *helpPath;
@property (assign)              long transformsArrayIndex; 
@property (assign)              PtFunc_t ipPointF;
@property (assign)              BOOL broken;
@property (assign)              BOOL needsScaledDepth, modifiesDepthBuf;
//@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              depthVis_t depthVisF;
@property (assign)              depthTrans_t depthTransF;

@property (unsafe_unretained)   RemapImage_t remapImageF;
@property (unsafe_unretained)   RemapPolar_t remapPolarF;
@property (unsafe_unretained)   RemapSize_t remapSizeF;
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
                        ptFunc:(PtFunc_t) f;

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaFunction:(areaFunction_t) f;

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapImage:(RemapImage_t) f;

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapPolar:(RemapPolar_t) f;

#ifdef NOTNOW
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapSize:(RemapSize_t) f;
#endif

+ (Transform *) depthVis:(NSString *) n description:(NSString *) d
                depthVis:(depthVis_t) f;

- (void) clearRemap;

@end

NS_ASSUME_NONNULL_END
