//
//  Transform.h
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    ColorTrans,
    GeometricTrans,
    RemapTrans,
    AreaTrans,
    EtcTrans,
} transform_t;

typedef Pixel (^ __nullable __unsafe_unretained pointFunction_t)(Pixel p);
typedef void (^ __nullable __unsafe_unretained areaFunction_t)(Pixel *src, Pixel *dest,
                                                               int p);
typedef PixelIndex_t (^ __unsafe_unretained remapPolarFunction_t)(float r, float a, int p);
typedef void (^ __nullable /*__unsafe_unretained*/ remapImageFunction_t)(PixelIndex_t *remapTable,
                                                                         size_t w, size_t h, int p);

@interface Transform : NSObject {
    NSString *name, *description;
    transform_t type;
    pointFunction_t pointF;
    areaFunction_t areaF;
    remapPolarFunction_t remapPolarF;
    remapImageFunction_t remapImageF;
    int low, value, high;   // parameter setting and range for transform
    BOOL hasParameters;
    BOOL newValue;
    PixelIndex_t * _Nullable remapTable;
    NSTimeInterval elapsedProcessingTime;
}

@property (nonatomic, strong)   NSString *name, *description;
@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              remapPolarFunction_t remapPolarF;
@property (copy)                remapImageFunction_t remapImageF;
@property (assign)              transform_t type;
@property (assign)              int low, value, high;
@property (assign)              BOOL hasParameters;
@property (assign)              BOOL newValue;
@property (assign)              PixelIndex_t * _Nullable remapTable;
@property (assign)              NSTimeInterval elapsedProcessingTime;

// not used
+ (Transform *)colorTransform:(NSString *)n description:(NSString *)d
               pointTransform: (pointFunction_t) f;
// works:
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                 areaFunction:(areaFunction_t) f;
// sometimes?
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapImage:(remapImageFunction_t) f;
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
              remapPolar:(remapPolarFunction_t) f;

- (void) clearRemap;

@end

NS_ASSUME_NONNULL_END
