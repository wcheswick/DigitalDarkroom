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

typedef struct Image {
    int w, h;
    int bytes_per_row;
    Pixel *image;
} Image;


typedef void (^ __nullable __unsafe_unretained pointFunction_t)(Pixel *p, size_t count);
typedef void (^ __nullable __unsafe_unretained areaFunction_t)(Image *src, Image *dest);

// typedef int transform_t(void *param, int low, int high);
//typedef void *b_init_func();

@interface Transform : NSObject {
    NSString *name, *description;
    transform_t type;
    pointFunction_t pointF;
    areaFunction_t areaF;
    size_t *remapTable;      // where to remap pixels, or nil
}

@property (nonatomic, strong)   NSString *name, *description;
@property (assign)              pointFunction_t pointF;
@property (assign)              areaFunction_t areaF;
@property (assign)              transform_t type;
@property (assign)              size_t *remapTable;

+ (Transform *)colorTransform:(NSString *)n description:(NSString *)d
               pointTransform: (pointFunction_t) f;
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaTransform:(areaFunction_t) f;

@end

NS_ASSUME_NONNULL_END

//           function:(Pixel (^) (Pixel p))pointFunction;
//function:(Pixel (^) (Pixel p))pointFunction;

