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

typedef u_char channel;

typedef struct {
    channel b, g, r, a;
} Pixel;

typedef struct Image {
    size_t w, h;
    Pixel *image;
} Image;

typedef void (^pointFunction_t)(Pixel *);
typedef void (^transform_f)(void);

// typedef int transform_t(void *param, int low, int high);
//typedef void *b_init_func();

@interface Transform : NSObject {
    NSString *name, *description;
    pointFunction_t __unsafe_unretained pointF;
}

@property (nonatomic, strong)   NSString *name, *description;
@property (assign)              pointFunction_t __unsafe_unretained pointF;

- (id)initWithName:(NSString *)n description:(NSString *)d
          PointF:(pointFunction_t)f;

@end

NS_ASSUME_NONNULL_END

//           function:(Pixel (^) (Pixel p))pointFunction;
//function:(Pixel (^) (Pixel p))pointFunction;

