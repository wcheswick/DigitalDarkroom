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
    RowTrans,
    GeometricTrans,
    RemapTrans,
    AreaTrans,
    EtcTrans,
} transform_t;

typedef u_char channel;

typedef struct {
    channel b, g, r, a;
} Pixel;

typedef struct Image_t {
    int w, h;
    int bytes_per_row;
    Pixel *image;
} Image_t;

// PixelIndex_t: index into only pixel addresses, 0..w-1 X 0..h-1
typedef UInt32 PixelIndex_t;

// BitmapIndex_t: index into bitmap, 0..EOR X 0..h-1
// where EOR is number of bytes in row / sizeof(Pixel)
typedef int32_t BitmapIndex_t;

#define Remap_White     (-1)    // special bitmap index for White
#define Remap_Black     (-2)    // special bitmap index for Black


typedef void (^ __nullable __unsafe_unretained pointFunction_t)(Pixel *p, size_t count);
typedef void (^ __nullable __unsafe_unretained areaFunction_t)(Image_t *src, Image_t *dest);
typedef void (^ __nullable __unsafe_unretained rowFunction_t)(Pixel *srcRow, Pixel *destRow, int w);
typedef BitmapIndex_t (^ __nullable __unsafe_unretained remapPixelFunction_t)(Image_t *im, int x, int y, int p);
typedef void (^ __nullable __unsafe_unretained remapImageFunction_t)(Image_t *im, BitmapIndex_t *remapTable, int p);

// typedef int transform_t(void *param, int low, int high);
//typedef void *b_init_func();

@interface Transform : NSObject {
    NSString *name, *description;
    transform_t type;
    pointFunction_t pointF;
    areaFunction_t areaF;
    remapPixelFunction_t remapPixelF;
    remapImageFunction_t remapImageF;
    rowFunction_t rowF;
    int low, param, high;   // parameter setting and range for transform
    BitmapIndex_t * _Nullable remapTable;      // PixelIndex_t long table of BitmapTable_t values
    volatile BOOL changed;
}

@property (nonatomic, strong)   NSString *name, *description;
@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              remapPixelFunction_t remapPixelF;
@property (assign)              remapImageFunction_t remapImageF;
@property (assign)              rowFunction_t rowF;
@property (assign)              transform_t type;
@property (assign)              BitmapIndex_t * _Nullable remapTable;
@property (assign)              int low, param, high;
@property (assign)              volatile BOOL changed;

+ (Transform *)colorTransform:(NSString *)n description:(NSString *)d
               pointTransform: (pointFunction_t) f;
+ (Transform *) colorTransform:(NSString *) n description:(NSString *) d
                  rowTransform:(rowFunction_t) f;
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaTransform:(areaFunction_t) f;
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                         remapPixel:(remapPixelFunction_t) f;
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapImage:(remapImageFunction_t) f;
@end

NS_ASSUME_NONNULL_END

//           function:(Pixel (^) (Pixel p))pointFunction;
//function:(Pixel (^) (Pixel p))pointFunction;

