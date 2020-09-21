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

typedef u_char channel;

typedef struct {
    channel b, g, r, a;
} Pixel;

// PixelIndex_t: index into only pixel addresses, 0..w-1 X 0..h-1
typedef size_t PixelIndex_t;

typedef Pixel (^ __nullable __unsafe_unretained pointFunction_t)(Pixel p);
typedef void (^ __nullable __unsafe_unretained areaFunction_t)(Pixel *src, Pixel *dest, int p);

typedef PixelIndex_t (^ __unsafe_unretained remapPolarPixelFunction_t)(float r, float a, int p, size_t w, size_t h);
typedef void (^ __nullable /*__unsafe_unretained*/ remapImageFunction_t)(PixelIndex_t *remapTable, size_t w, size_t h, int p);

// typedef int transform_t(void *param, int low, int high);
//typedef void *b_init_func();

@interface Transform : NSObject {
    NSString *name, *description;
    transform_t type;
    pointFunction_t pointF;
    areaFunction_t areaF;
    remapPolarPixelFunction_t remapPolarF;
    remapImageFunction_t remapImageF;
    int low, param, high;   // parameter setting and range for transform
    PixelIndex_t * _Nullable remapTable;      // PixelIndex_t table of where to move pixels to
    volatile BOOL changed;
}

@property (nonatomic, strong)   NSString *name, *description;
@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              remapPolarPixelFunction_t remapPolarF;
@property (copy)                remapImageFunction_t remapImageF;
@property (assign)              transform_t type;
@property (assign)              PixelIndex_t * _Nullable remapTable;
@property (assign)              int low, param, high;
@property (assign)              volatile BOOL changed;

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
              remapPolarPixel:(remapPolarPixelFunction_t) f;

@end

NS_ASSUME_NONNULL_END
