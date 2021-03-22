//
//  Transforms.m
//  DigitalDarkroom
//
//  Created by ches on 9/16/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

// color effect filters from apple:
// https://developer.apple.com/documentation/coreimage/methods_and_protocols_for_filter_creation/color_effect_filters?language=objc

#import "Transforms.h"
#import "RemapBuf.h"
#import "Defines.h"

// #define DEBUG_TRANSFORMS    1   // bounds checking and a lot of assertions

#define LUM(p)  (channel)((((p).r)*299 + ((p).g)*587 + ((p).b)*114)/1000)
#define CLIP(c) ((c)<0 ? 0 : ((c)>Z ? Z : (c)))
#define CRGB(r,g,b)     SETRGB(CLIP(r), CLIP(g), CLIP(b))

#define R(x) (x).r
#define G(x) (x).g
#define B(x) (x).b

#define CENTER_X    (W/2)
#define CENTER_Y    (H/2)
#define MAX_R   (MAX(CENTER_X, CENTER_Y))

#define RPI(x,y)    (PixelIndex_t)(((y)*self->execute.bytesPerRow) + (x*sizeof(Pixel)))

#ifdef DEBUG_TRANSFORMS
// Some of our transforms might be a little buggy around the edges.  Make sure
// all the indicies are in range.

#define PI(x,y)   dPI((int)(x),(int)(y))   // pixel index in a buffer

static PixelIndex_t dPI(int x, int y) {
    assert(x >= 0);
    assert(x < W);
    assert(y >= 0);
    assert(y < H);
    PixelIndex_t index = RPI(x,y);
    assert(index >= 0 && index < pixelsInImage);
    return index;
}

#else
#define PI(x,y)   RPI((x),(y))
#endif

@interface Transforms ()

@property (strong, nonatomic)   Transform *lastTransform;

@end

@implementation Transforms

@synthesize lastTransform;
@synthesize depthTransformCount;
@synthesize debugTransforms;
@synthesize transforms;


- (id)init {
    self = [super init];
    if (self) {
#ifdef DEBUG_TRANSFORMS
        debugTransforms = YES;
#else
        debugTransforms = NO;
#endif
        transforms = [[NSMutableArray alloc] init];
        depthTransformCount = 0;
        [self buildTransformList];
    }
    return self;
}

- (void) buildTransformList {
    [self addDepthVisualizations];
    [self addPolarTransforms];
    [self addGeometricTransforms];
    [self addTestTransforms];   // empty
    [self addArtTransforms];
    [self addAreaTransforms];   // manu unimplemented
    [self addPointTransforms];  // working:
#ifdef NOTYET
//    [self addColorVisionDeficits];
    [self addMiscTransforms];
    // tested:
    [self addMonochromes];
    [self addOldies];
#endif
}

- (void) addTransform:(Transform *)transform {
    transform.arrayIndex = transforms.count;
    [transforms addObject:transform];
}

// transform at given index, or nil if NO_TRANSFORM

- (Transform * __nullable) transformAtIndex:(long) index {
    if (index == NO_TRANSFORM)
        return nil;
    return [transforms objectAtIndex:index];
}

// For Tom's logo algorithm

int
stripe(PixelArray_t buf, int x, int p0, int p1, int c){
    if(p0==p1){
        if(c>Z){
            buf[p0][x].r = Z;
            return c-Z;
        }
        buf[p0][x].r = c;
        return 0;
    }
    if (c>2*Z) {
        buf[p0][x].r = Z;
        buf[p1][x].r = Z;
        return c-2*Z;
    }
    buf[p0][x].r = c/2;
    buf[p1][x].r = c - c/2;
    return 0;
}

- (void) addTestTransforms {
}

/* Monochrome floyd-steinberg */

#ifdef NOTYET
static void
fs(int depth, int buf[W][H]) {
    int x, y, i;
    int maxp = depth - 1;

    for(y=0; y<H; y++) {
        for(x=0; x<W; x++) {
            int temp;
            int c = 0;
            channel e = buf[x][y];

            switch (depth) {
            case 1:
                    if (e > Z/2) {
                    i=0;
                    c = Z;
                    e -= Z;
                } else {
                    i = 1;
                    c = 0;
                }
                break;
            case 4:    i = (depth*e)/Z;
                if (i<0)
                    i=0;
                else if (i>maxp)
                    i=maxp;
                e -= (i*Z)/3;
                i = maxp-i;
                c = Z - i*Z/(depth-1);
                break;
            }
            buf[x][y] = c;
            temp = 3*e/8;
            if (y < H-1) {
                buf[x][y+1] += temp;
                if (x < W-1)
                    buf[x+1][y+1] += e-2*temp;
            }
            if (x < W-1)
                buf[x+1][y] += temp;
        }
    }
}
#endif

#ifdef TOFIX
void
focus(channel *s[(int)H], channel *d[(int)H]) {
    for (int y=1; y<H-1; y++) {
        for (int x=1; x<W-1; x++) {
            int c =
                5*s[x][y] -
                s[x+1][y] -
                s[x-1][y] -
                s[x][y-1] -
                s[x][y+1];
            d[x][y] = CLIP(c);
        }
    }
}

void
sobel(channel *s[(int)H], channel *d[(int)H]) {
    for (int y=1; y<H-1-1; y++) {
        for (int x=1; x<W-1-1; x++) {
            int aa, bb;
            aa = s[x-1][y-1] + s[x-1][y]*2 + s[x-1][y+1] -
                s[x+1][y-1] - s[x+1][y]*2 - s[x+1][y+1];
            bb = s[x-1][y-1] + s[x][y-1]*2 +
                s[x+1][y-1] -
                s[x-1][y+1] - s[x][y+1]*2 -
                s[x+1][y+1];
            int diff = sqrt(aa*aa + bb*bb);
            if (diff > Z)
                d[x][y] = Z;
            else
                d[x][y] = diff;
        }
    }
}
#endif


- (void) addPolarTransforms {
    
    lastTransform = [Transform areaTransform: @"Can"    // WTF?
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        // I am not sure this matches the original, or that the original didn't
        // have a bug:
        //    return frame[CENTER_Y+(short)(r*cos(a))]
        //            [CENTER_X+(short)((r-(sin(a))/300)*sin(a))];

        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        long sx = centerX + a*5.0/2.0;
        long sy = centerY + r*5.0/2.0;
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Skrunch"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        // I am not sure this matches the original, or that the original didn't
        // have a bug:
        //    return frame[CENTER_Y+(short)(r*cos(a))]
        //            [CENTER_X+(short)((r-(sin(a))/300)*sin(a))];

        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        long sx = centerX + (r-(cos(a)/300.0)*sin(a));
        long sy = centerY + r*sin(a);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Edward Munch #1"        // old twist right
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        double newa = a + (r/3.0)*(M_PI/180.0);
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        long sx = centerX + r*cos(newa);
        long sy = centerY + r*sin(newa);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Edward Munch #2"    // old Ken twist
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        long sx = centerX + r*cos(a);
        long sy = centerY + r*sin(a + r/30.0);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Dali"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        long sx = centerX + r*cos(a);
        long sy = centerY + r*sin(a);
        sx = centerX + (r*cos(a + (sy*sx/(16*17000.0))));
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Andrew"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        int sx = centerX + 0.6*((r - sin(a)*100 + 50) * cos(a));
        int sy = centerY + 0.6*r*sin(a); // - (CENTER_Y/4);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_TO(tX, tY, centerX + r*cos(a), centerX + r*sin(a));
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Fish eye"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        double R = hypot(remapBuf.w,remapBuf.h);
        float zoomFactor = instance.value/10.0; // XXXX this is broken, I think
        double r1 = r*r/(R/zoomFactor);
        int x = (int)remapBuf.w/2 + (int)(r1*cos(a));
        int y = (int)remapBuf.h/2 + (int)(r1*sin(a));
        REMAP_TO(tX, tY, x, y);
    }];
    lastTransform.low = 10; // XXXXXX these are bogus
    lastTransform.value = 20;
    lastTransform.high = 30;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Cone projection"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        float maxR = MAX(centerX, centerY);
        double r1 = sqrt(r*maxR);
        long sx = centerX + (int)(r1*cos(a));
        long sy = centerY + (int)(r1*sin(a));
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Paul"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {

        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        double x = r*cos(a);
        double y = r*sin(a);
        long sx = centerX + (short)(r*sin((y*x)/4.0+a));
        long sy = centerY + (short)(r*cos(a));
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

}

- (void) addAreaTransforms {
    lastTransform = [Transform areaTransform: @"O no!"
                                 description: @"Reflect the right half of the screen on the left"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long centerX = remapBuf.w/2;
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<remapBuf.w; x++) {
                if (x < centerX)
                    REMAP_TO(x, y, remapBuf.w - x - 1, y);
                else
                    REMAP_TO(x, y, x, y);
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Mirror"
                                  description: @"Reflect the image"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<remapBuf.w; x++) {
                REMAP_TO(x, y, remapBuf.w - x - 1, y);
            }
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Wavy shower"
                                 description: @"Through wavy glass"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        int cpp = instance.value;   // pixels per cycle
        int ncyc = (int)remapBuf.w / cpp;
        for (int y=0; y<remapBuf.h; y++) { // why is this loop needed?
            for (int x=0; x<remapBuf.w; x++) {
                REMAP_TO(x,y, x,y);
            }
        }
        for (int y=0; y<remapBuf.h; y++) {  // XX thumbnail not very wavy
            for (int x=0; x<remapBuf.w; x++) {
                int dx = (int)(ncyc*sin(cpp*x*2*M_PI/remapBuf.w));
                    REMAP_TO(x,y, x+dx,y);
            }
        }
    }];
    lastTransform.low = 10;
    lastTransform.value = 18;
    lastTransform.high = 50;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Flip"
                                  description: @"vertical reflection"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<remapBuf.w; x++) {
                REMAP_TO(x, y, x, remapBuf.h - y - 1);
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Pixelate"
                                  description: @"Giant pixels"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        int pixSize = instance.value;
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<remapBuf.w; x++) {
                REMAP_TO(x, y, (x/pixSize)*pixSize, (y/pixSize)*pixSize);
            }
        }
    }];
    lastTransform.low = 4;
    lastTransform.value = 6;
    lastTransform.high = 200;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Terry's kite"
                                 description: @"Designed by an 8-year old"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        for (int y=0; y<remapBuf.h; y++) {
            size_t ndots;
            
            if (y <= centerY)
                ndots = (y*(remapBuf.w-1))/remapBuf.h;
            else
                ndots = ((remapBuf.h-y-1)*(remapBuf.w))/remapBuf.h;

            REMAP_TO(centerX,y, centerX, y);
            REMAP_TO(centerX,y, centerX, y);
            REMAP_COLOR(0,y, Remap_White);
            
            for (int x=1; x<=ndots; x++) {
                size_t dist = (x*(centerX-1))/ndots;

                REMAP_TO(centerX+x,y, centerX + dist,y);
                REMAP_TO(centerX-x,y, centerX - dist,y);
            }
            for (size_t x=ndots; x<centerX; x++) {
                REMAP_COLOR(centerX+x,y, Remap_White);
                REMAP_COLOR(centerX-x,y, Remap_White);
             }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @""
                                areaFunction:^(PixelArray_t src, PixelArray_t dest,
                                               size_t w, size_t h, TransformInstance *instance) {
        channel lum[h][w];  // XXX does this variable array work?
        for (int y=1; y<h-1; y++)
            for (int x=1; x<w-1; x++)
                lum[y][x] = LUM(src[y][x]);

        for (int y=1; y<h-1; y++) {
            for (int x=1; x<w-1; x++) {
                channel aa, bb, s;
                aa = lum[y-1][x-1] + 2*lum[y-1][x] + lum[y-1][x+1] -
                     lum[y+1][x-1] - 2*lum[y+1][x] - lum[y+1][x+1];
                bb = lum[y-1][x-1] + 2*lum[y][x-1] + lum[y+1][x-1] -
                     lum[y-1][x+1] - 2*lum[y][x+1] - lum[y+1][x+1];

                channel c;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    c = Z;
                else
                    c = s;
                dest[y][x] = SETRGB(c,c,c);
            }
        }
    }];
    [self addTransform:lastTransform];

    // this should be a general kernel convolution
    lastTransform = [Transform areaTransform: @"Old blur"
                                  description: @"non-general"
                                areaFunction: ^(PixelArray_t src, PixelArray_t dest,
                                                size_t w, size_t h, TransformInstance *instance) {
        for (int y=1; y<h-1; y++) {
            for (int x=1; x<w-1; x++) {
                Pixel p = {0,0,0,Z};
                p.r = (src[y][x].r +
                       src[y][x+1].r +
                       src[y][x-1].r +
                       src[y-1][x].r +
                       src[y+1][x].r)/5;
                p.g = (src[y][x].g +
                       src[y][x+1].g +
                       src[y][x-1].g +
                       src[y-1][x].g +
                       src[y+1][x].g)/5;
                p.b = (src[y][x].b +
                       src[y][x+1].b +
                       src[y][x-1].b +
                       src[y-1][x].b +
                       src[y+1][x].b)/5;
                dest[y][x] = p;
            }
        }
    }];
    [self addTransform:lastTransform];

     // this destroys src
     lastTransform = [Transform areaTransform: @"Old AT&T logo"
                                   description: @"Tom Duff's logo transform"
                                  areaFunction: ^(PixelArray_t src, PixelArray_t dest,
                                                  size_t w, size_t h, TransformInstance *instance) {
         for (int y=0; y<h; y++) {
             for (int x=0; x<w; x++) {
                 channel c = LUM(src[y][x]);
                 src[y][x] = SETRGB(c,c,c);
             }
         }
         
         int hgt = instance.value;
         assert(hgt > 0);
         int c;
         int y0, y1;

         for (int y=0; y<h; y+= hgt) {
             if (y+hgt>h)
                 hgt = (int)h-(int)y;
             for (int x=0; x < w; x++) {
                 c=0;
                 for(y0=0; y0<hgt; y0++)
                     c += src[y+y0][x].r;
                 y0 = y+(hgt-1)/2;
                 y1 = y+(hgt-1-(hgt-1)/2);
                 for (; y0 >= y; --y0, ++y1)
                     c = stripe(src, x, y0, y1, c);
             }
         }
                     
         for (int y=0; y<h; y++) {
             for (int x=0; x<w; x++) {
                 channel c = src[y][x].r;
                 dest[y][x] = SETRGB(c, c, c);
             }
         }
     }];
     lastTransform.value = 12; lastTransform.low = 4; lastTransform.high = 50;
     lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

#ifdef NOTYET   // channel-based
    lastTransform = [Transform areaTransform: @"Color Sobel"
                                          description: @"Edge detection"
                                        areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int w, int h) {
        for (int y=0; y<h; y++) {    // red
            for (int x=0; x<w; x++) {
                sChan[x][y] = srcBuf[PI(x,y)].r;
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].r = dChan[x][y];    // install red
                sChan[x][y] = srcBuf[PI(x,y)].g;    // get green
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].g = dChan[x][y];    // install green
                sChan[x][y] = srcBuf[PI(x,y)].b;    // get blue
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].b = dChan[x][y];    // install blue
            }
        }
    }];
    [self addTransform:lastTransform];
    ADD_TO_OLIVE(lastTransform);
    
    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @"oil paint"
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        int b[W][H];
        
        int depth = (param == 1) ? 1 : 4;
        
        for (int y=0; y<H; y++)
           for (int x=0; x<W; x++)
                b[x][y] = LUM(src[PI(x,y)]);
        
        fs(depth, b);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                Pixel p = {0,0,0,Z};
                p.r = p.g = p.b = b[x][y];
                dest[PI(x,y)] = p;
            }
        }
    }];
    lastTransform.value = 1;
    lastTransform.low = 1;
    lastTransform.high = 2;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Shear"
                                                  description: @"Shear"
                                                areaFunction: ^(RemapBuf_t src, RemapBuf_t dest, int p) {
        int x, y, dx, dy, r, yshift[W];
        memset(yshift, 0, sizeof(yshift));

        for (x = r = 0; x < W; x++) {
            if (irand(256) < 128)
                r--;
            else
                r++;
            yshift[x] = r;
        }
        for (y = 0; y < H; y++) {
            if (irand(256) < 128)
                r--;
            else
                r++;
            for (x = 0; x < W; x++) {
                dx = x+r; dy = y+yshift[x];
                if (dx >= W || dy >= H ||
                    dx < 0 || dy < 0)
                    dest[PI(x,y)] = White;
                else
                    dest[PI(x,y)] = src[PI(dx,dy)];
            }
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Brownian"
                                  description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int wpp) {
        for (int y=1; y<H-1; y++) {
            for (int x=1; x<W-1; x++) {
                long nx = x;
                long ny = y;
                for (int i=0; i<wpp; i++) {
                    nx += irand(3) - 1;
                    ny += irand(3) - 1;
                }
                if (nx < 0)
                    nx = 0;
                else if (nx >= W)
                    nx = W-1;
                if (ny < 0)
                    ny = 0;
                else if (ny >= H)
                    ny = H-1;
                dest[PI(x,y)] = src[PI(nx,ny)];
            }
        }
    }];
    lastTransform.low = 3;
    lastTransform.value = 5;
    lastTransform.high = 10;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];


    lastTransform = [Transform areaTransform: @"Matisse"
                                 description: @"colored Floyd/Steinberg"
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        for (int y=1; y<H-1; y++) {
            for (int x=1; x<W-1; x++) {
                channel aa, bb, s;
                Pixel p = {0,0,0,Z};
                aa = src[PI(x-1,y-1)].r + 2*src[PI(x,y-1)].r + src[PI(x+1,y-1)].r -
                     src[PI(x-1,y+1)].r - 2*src[PI(x,y+1)].r - src[PI(x+1,y+1)].r;
                bb = src[PI(x-1,y-1)].r + 2*src[PI(x-1,y)].r + src[PI(x-1,y+1)].r -
                     src[PI(x+1,y-1)].r - 2*src[PI(x+1,y)].r - src[PI(x+1,y+1)].r;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.r = Z;
                else
                    p.r = s;

                aa = src[PI(x-1,y-1)].g + 2*src[PI(x,y-1)].g + src[PI(x+1,y-1)].g -
                     src[PI(x-1,y+1)].g - 2*src[PI(x,y+1)].g - src[PI(x+1,y+1)].g;
                bb = src[PI(x-1,y-1)].g + 2*src[PI(x-1,y)].g + src[PI(x-1,y+1)].g -
                     src[PI(x+1,y-1)].g - 2*src[PI(x+1,y)].g - src[PI(x+1,y+1)].g;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.g = Z;
                else
                    p.g = s;

                aa = src[PI(x-1,y-1)].b + 2*src[PI(x,y-1)].b + src[PI(x+1,y-1)].b -
                     src[PI(x-1,y+1)].b - 2*src[PI(x,y+1)].b - src[PI(x+1,y+1)].b;
                bb = src[PI(x-1,y-1)].b + 2*src[PI(x-1,y)].b + src[PI(x-1,y+1)].b -
                     src[PI(x+1,y-1)].b - 2*src[PI(x+1,y)].b - src[PI(x+1,y+1)].b;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.b = Z;
                else
                    p.b = s;
                p.r = Z - p.r;
                p.g = Z - p.g;
                p.b = Z - p.b;
                dest[PI(x,y)] = p;
            }
        }
    }];
    [self addTransform:lastTransform];

    /* timings for oil on digitalis:
     *
     *            Z    param    f/s
     * original oil        31    3    ~7.0
     *
     * original oil        255    3    1.2
     *
     * new oil        255    3    2.5
     * new oil        255    2    2.7
     * new oil        255    1    2.7    seurat-like
     *
     * new oil        31    3    5.8    notable loss of detail
     * new oil        31    2    6.5    better detail than N==3
     * new oil        31    1    7.2    looks more like seurat
     *
     * new oil        15    2    7.6    isophots visible
     */

#define N_BUCKETS    (32)
#define    BUCKET(x)    ((x)>>3)
#define UNBUCKET(x)    ((x)<<3)

    lastTransform = [Transform areaTransform: @"Oil paint"
                                  description: @"oil paint"
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        int N = param;
        int rmax, gmax, bmax;
        u_int x,y;
        int dx, dy, dz;
        int rh[N_BUCKETS], gh[N_BUCKETS], bh[N_BUCKETS];
        Pixel p = {0,0,0,Z};
        
        // N-pixel white border around the outside
        for (y=0; y<H; y++) {
            for (x=0; x<N; x++)
            dest[PI(x,y)] = dest[PI(W-x-1,y)] = White;
            if (y<N || y>H-N)
                for (x=0; x<W; x++) {
                    dest[PI(x,y)] = White;
                }
        }
        
        for (dz=0; dz<N_BUCKETS; dz++)
            rh[dz] = bh[dz] = gh[dz] = 0;
        
        /*
         * Initialize our histogram with the upper left NxN pixels
         */
        y=N;
        x=N;
        for (dy=y-N; dy<=y+N; dy++) {
            for (dx=x-N; dx<=x+N; dx++) {
                p = src[PI(dx,dy)];
                rh[BUCKET(p.r)]++;
                gh[BUCKET(p.g)]++;
                bh[BUCKET(p.b)]++;
            }}
        rmax=0; gmax=0; bmax=0;
        for (dz=0; dz<N_BUCKETS; dz++) {
            if (rh[dz] > rmax) {
                p.r = UNBUCKET(dz);
                rmax = rh[dz];
            }
            if (gh[dz] > gmax) {
                p.g = UNBUCKET(dz);
                gmax = gh[dz];
            }
            if (bh[dz] > bmax) {
                p.b = UNBUCKET(dz);
                bmax = bh[dz];
            }
        }
        dest[PI(x,y)] = p;
        
        while (1) {
            /*
             * Creep across the row one pixel at a time updating our
             * histogram by subtracting the contribution of the left-most
             * edge and adding the new right edge.
             */
            for (x++; x<W-N; x++) {
                //NSLog(@"x,y = %d, %d", x, y);
                for (dy=y-N; dy<=y+N; dy++) {
                    Pixel op = src[PI(x-N-1,dy)];
                    Pixel ip = src[PI(x+N,dy)];
                    rh[BUCKET(op.r)]--;
                    rh[BUCKET(ip.r)]++;
                    gh[BUCKET(op.g)]--;
                    gh[BUCKET(ip.g)]++;
                    bh[BUCKET(op.b)]--;
                    bh[BUCKET(ip.b)]++;
                }
                rmax=0; gmax=0; bmax=0;
                for (dz=0; dz<N_BUCKETS; dz++) {
                    if (rh[dz] > rmax) {
                        p.r = UNBUCKET(dz);
                        rmax = rh[dz];
                    }
                    if (gh[dz] > gmax) {
                        p.g = UNBUCKET(dz);
                        gmax = gh[dz];
                    }
                    if (bh[dz] > bmax) {
                        p.b = UNBUCKET(dz);
                        bmax = bh[dz];
                    }
                }
                dest[PI(x,y)] = p;
            }
            
            /*
             * Now move our histogram down a pixel on the right hand side,
             * and recompute our histograms.
             */
            y++;
            if (y+N >= H)
                break;        /* unfortunate place to break out of the loop */
            x = (int)W - N - 1;
            for (dx=x-N; dx<=x+N; dx++) {
                Pixel op = src[PI(dx,y-N-1)];
                Pixel ip = src[PI(dx,y+N)];
                rh[BUCKET(op.r)]--;
                rh[BUCKET(ip.r)]++;
                gh[BUCKET(op.g)]--;
                gh[BUCKET(ip.g)]++;
                bh[BUCKET(op.b)]--;
                bh[BUCKET(ip.b)]++;
            }
            rmax=0; gmax=0; bmax=0;
            for (dz=0; dz<N_BUCKETS; dz++) {
                if (rh[dz] > rmax) {
                    p.r = UNBUCKET(dz);
                    rmax = rh[dz];
                }
                if (gh[dz] > gmax) {
                    p.g = UNBUCKET(dz);
                    gmax = gh[dz];
                }
                if (bh[dz] > bmax) {
                    p.b = UNBUCKET(dz);
                    bmax = bh[dz];
                }
            }
            dest[PI(x,y)] = p;

            /*
             * Now creep the histogram back to the left, one pixel at a time
             */
            for (x=x-1; x>=N; x--) {
                for (dy=y-N; dy<=y+N; dy++) {
                    Pixel op = src[PI(x+N+1,dy)];
                    Pixel ip = src[PI(x-N,dy)];
                    rh[BUCKET(op.r)]--;
                    rh[BUCKET(ip.r)]++;
                    gh[BUCKET(op.g)]--;
                    gh[BUCKET(ip.g)]++;
                    bh[BUCKET(op.b)]--;
                    bh[BUCKET(ip.b)]++;
                }
                rmax=0; gmax=0; bmax=0;
                for (dz=0; dz<N_BUCKETS; dz++) {
                    if (rh[dz] > rmax) {
                        p.r = UNBUCKET(dz);
                        rmax = rh[dz];
                    }
                    if (gh[dz] > gmax) {
                        p.g = UNBUCKET(dz);
                        gmax = gh[dz];
                    }
                    if (bh[dz] > bmax) {
                        p.b = UNBUCKET(dz);
                        bmax = bh[dz];
                    }
                }
                dest[PI(x,y)] = p;
            }

            /*
             * Move our histogram down one pixel on the left side.
             */
            y++;
            x = N;
            if (y+N >= H)
                break;        /* unfortunate place to break out of the loop */
            for (dx=x-N; dx<=x+N; dx++) {
                Pixel op = src[PI(dx,y-N-1)];
                Pixel ip = src[PI(dx,y+N)];
                rh[BUCKET(op.r)]--;
                rh[BUCKET(ip.r)]++;
                gh[BUCKET(op.g)]--;
                gh[BUCKET(ip.g)]++;
                bh[BUCKET(op.b)]--;
                bh[BUCKET(ip.b)]++;
            }
            rmax=0; gmax=0; bmax=0;
            for (dz=0; dz<N_BUCKETS; dz++) {
                if (rh[dz] > rmax) {
                    p.r = UNBUCKET(dz);
                    rmax = rh[dz];
                }
                if (gh[dz] > gmax) {
                    p.g = UNBUCKET(dz);
                    gmax = gh[dz];
                }
                if (bh[dz] > bmax) {
                    p.b = UNBUCKET(dz);
                    bmax = bh[dz];
                }
            }
            dest[PI(x,y)] = p;
        }
    }];
    lastTransform.value = 10;
    lastTransform.low = 2;
    lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Monochrome Sobel"
                                          description: @"Edge detection"
                                        areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int p) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                sChan[x][y] = LUM(srcBuf[PI(x,y)]);
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel d = dChan[x][y];
                dstBuf[PI(x,y)] = SETRGB(d,d,d);    // install blue
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Surreal"
                                          description: @"Negative of Sobel filter"
                                        areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int p) {
        for (int y=0; y<H; y++) {    // red
            for (int x=0; x<W; x++) {
                sChan[x][y] = srcBuf[PI(x,y)].r;
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].r = Z - dChan[x][y];    // install red
                sChan[x][y] = srcBuf[PI(x,y)].g;    // get green
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].g = Z - dChan[x][y];    // install green
                sChan[x][y] = srcBuf[PI(x,y)].b;    // get blue
            }
        }
        sobel(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].b = Z - dChan[x][y];    // install blue
            }
        }
    }];
    [self addTransform:lastTransform];

    extern  transform_t do_fs1;
    extern  transform_t do_fs2;
    extern  transform_t do_sampled_zoom;
    extern  transform_t do_mean;
    extern  transform_t do_median;
#endif
}

#define RGB_SPACE   ((float)((1<<24) - 1))

- (void) addDepthVisualizations {
    lastTransform = [Transform depthVis: @"Encode depth"
                            description: @""
                               depthVis: ^(const DepthBuf *depthBuf, PixBuf *pixBuf, int v) {
        size_t bufSize = depthBuf.h * depthBuf.w;
        float min = MAX_DEPTH;
        float max = MIN_DEPTH;
        for (int i=0; i<bufSize; i++) {
            Distance v = depthBuf.db[i];
            if (v < min)
                min = v;
            if (v > max)
                max = v;
            //NSLog(@" v, min, max: %.2f %.2f %.2f", v, min, max);
            Pixel p;
#ifdef HSV
            float frac = (v - MIN_DEPTH)/(MAX_DEPTH - MIN_DEPTH);
            float hue = frac;
            float sat = 1.0;
            float bri = 1.0 - frac;
            UIColor *color = [UIColor colorWithHue: hue saturation: sat
                                        brightness: bri alpha: 1];
            CGFloat r, g, b,a;
            [color getRed:&r green:&g blue:&b alpha:&a];
            p = CRGB(Z*r, Z*g, Z*b);
#else
            if (v < MIN_DEPTH)
                p = Red;
            else if (v >= MAX_DEPTH)
                p = Black;
            else {
                float frac = (v - MIN_DEPTH)/(MAX_DEPTH - MIN_DEPTH);
                UInt32 cv = trunc(RGB_SPACE * frac);
                p.b = cv % 256;
                cv /= 256;
                p.g = cv % 256;
                cv /= 256;
                assert(cv <= 255);
                p.r = cv;
                p.a = Z;    // alpha on, not used at the moment
            }
#endif
            pixBuf.pb[i] = p;
        }
    }];
    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
       
#ifdef DEBUG_TRANSFORMS
#define DIST(x,y)  [depthBuf distAtX:(x) Y:(y)]
#else
#define DIST(x,y)  depthBuf.da[y][x]
#endif
    
#ifdef DEBUG
    lastTransform = [Transform depthVis: @"Mono dist"
                            description: @""
                               depthVis: ^(const DepthBuf *depthBuf, PixBuf *pixBuf, int v) {
        size_t bufSize = depthBuf.h * depthBuf.w;
        assert(depthBuf.h * depthBuf.w == bufSize);
        for (int i=0; i<bufSize; i++) {
            Distance v = depthBuf.db[i];
            float frac = (v - MIN_DEPTH)/(MAX_DEPTH - MIN_DEPTH);
            channel c = trunc(Z - frac*Z);
            Pixel p = SETRGB(0,0,c);
            pixBuf.pb[i] = p;
        }
    }];
    [self addTransform:lastTransform];
#endif
    
    lastTransform = [Transform depthVis: @"Mono log dist"
                            description: @""
                               depthVis: ^(const DepthBuf *depthBuf, PixBuf *pixBuf, int v) {
        size_t bufSize = depthBuf.h * depthBuf.w;
        assert(depthBuf.h * depthBuf.w == bufSize);
        assert(MIN_DEPTH >= 0.1);
        float logMin = log(MIN_DEPTH);
        float logMax = log(MAX_DEPTH);
        for (int i=0; i<bufSize; i++) {
            Distance d = depthBuf.db[i];
            if (d < MIN_DEPTH)
                d = MIN_DEPTH;
            else if (d > MAX_DEPTH)
                d = MAX_DEPTH;
            float v = log(d);
            float frac = (v - logMin)/(logMax - logMin);
            channel c = trunc(Z - frac*Z);
            Pixel p = SETRGB(0,0,c);
            pixBuf.pb[i] = p;
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform depthVis: @"Near depth"
                            description: @""
                               depthVis: ^(const DepthBuf *depthBuf, PixBuf *pixBuf, int v) {
        size_t bufSize = depthBuf.h * depthBuf.w;
        assert(depthBuf.h * depthBuf.w == bufSize);
        float mincm = 10.0;
        float maxcm = mincm + 100.0;
        float depthcm = maxcm - mincm;
        for (int i=0; i<bufSize; i++) {
            Distance d = depthBuf.db[i];
            Distance dcm = d * 100.0;    // distance in centimeters
            Pixel p;
            if (dcm < mincm) {
                p = White;
            } else if (dcm > maxcm) {  // more than a meter of depth -> black
                p = Black;
            } else {
                float adcm = dcm - mincm;
                float frac = adcm/depthcm;
                CGFloat hue = frac;  // each centimeter is a hue change
                CGFloat sat = 1.0;
                CGFloat bri = adcm - trunc(adcm);   // millimeter remainder is brightness
                UIColor *color = [UIColor colorWithHue: hue
                                            saturation: sat
                                            brightness: bri
                                                 alpha: 1];
                CGFloat r, g, b, a;
                [color getRed:&r green:&g blue:&b alpha:&a];
                p = SETRGB(r*Z,g*Z,b*Z);
            }
            pixBuf.pb[i] = p;
        }
    }];
//    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
//    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
    
#ifdef NEW
    lastTransform = [Transform depthVis: @"3D level visualization"
                                 description: @""
                                depthVis: ^(const DepthBuf *depthBuf, Pixel *dest, int v) {
        for (int i=0; i< depthBuf.h * depthBuf.w; i++) {
                Pixel p;
                Distance z = depthBuf.db[i];
                // closest to farthest, even v is dark blue to light blue,
                // odd v is yellow to dark yellow
                if (z >= MAX_DEPTH)
                    p = Black;
                else if (v <= MIN_DEPTH)
                    p = Green;
                else {
                    if (v & 0x1) {  // odd luminance
                        c = Z - (v/2);
                        p = SETRGB(0,0,v);
                    } else {
                        c = Z/2 + v/2;
                        p = SETRGB(c,c,0);
                    }
                }
                dest.pb[i] = p;
            }
        }
    }];
    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
#endif

#ifdef broken
#define mu (1/3.0)
//#define E round(2.5*dpi)
#define E round(dpi)
#define separation(Z) round((1-mu*(Z))*E/(2-mu*(Z)))
#define FARAWAY separation(0)
    
    // SIDRS computation taken from
    // https://courses.cs.washington.edu/courses/csep557/13wi/projects/trace/extra/SIRDS-paper.pdf
    lastTransform = [Transform depthVis: @"SIRDS"
                            description: @""
                               depthVis: ^(const DepthBuf *depthBuf, PixBuf *pixBuf, int v) {
        float scale = 1;
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
            scale = [[UIScreen mainScreen] scale];
        }
        float dpi = (640/8.3) * scale;
        
        // scale the distances from MIN - MAX to mu - 0, near to far.
#define MAX_S_DEP MAX_DEPTH // 2.0
#define MIN_S_DEP   0   // MIN_DEPTH
        
        for (int i=0; i<depthBuf.w * depthBuf.h; i++) {
            float z = depthBuf.db[i];
            if (z > MAX_S_DEP)
                z = MAX_S_DEP;
            else if (z < MIN_S_DEP)
                z = MIN_S_DEP;
            float dz = (z - MIN_DEPTH)/(MAX_S_DEP - MIN_S_DEP);
            float dfz = mu - dz*mu;
            assert(dfz <= mu && dfz >= 0);
            depthBuf.db[i] = dfz;
        }
        
        for (int y=0; y<depthBuf.h; y++) {    // convert scan lines independently
            channel pix[depthBuf.w];
            //  Points to a pixel to the right ... */ /* ... that is constrained to be this color:
            int same[depthBuf.w];
            int s;  // stereo sep at this point
            int left, right;    // x values for left and right eyes
            
            for (int x=0; x < depthBuf.w; x++ ) {  // link initial pixels with themselves
                same[x] = x;
            }
            for (int x=0; x < depthBuf.w; x++ ) {
                float z = DIST(x,y);
                s = separation(z);
                left = x - s/2;
                right = left + s;   // pixels at left and right must be the same
                if (left >= 0 && right < depthBuf.w) {
                    int visible;    // first, perform hidden surface removal
                    int t = 1;      // We will check the points (x-t,y) and (x+t,y)
                    Distance zt;       //  Z-coord of ray at these two points
                    
                    do {
                        zt = DIST(x,y) + 2*(2 - mu*DIST(x,y))*t/(mu*E);
                        BOOL inRange = (x-t >= 0) && (x+t < depthBuf.w);
                        visible = inRange && DIST(x-t,y) < zt && DIST(x+t,y) < zt;  // false if obscured
                        t++;
                    } while (visible && zt < 1);    // end of hidden surface removal
                    if (visible) {  // record that pixels at l and r are the same
                        assert(left >= 0 && left < depthBuf.w);
                        int l = same[left];
                        assert(l >= 0 && l < depthBuf.w);
                        while (l != left && l != right) {
                            if (l < right) {    // first, jiggle the pointers...
                                left = l;       // until either same[left] == left
                                assert(left >= 0 && left < depthBuf.w);
                                l = same[left]; // .. or same[left == right
                                assert(l >= 0 && l < depthBuf.w);
                            } else {
                                assert(left >= 0 && left < depthBuf.w);
                                same[left] = right;
                                left = right;
                                l = same[left];
                                assert(l >= 0 && l < depthBuf.w);
                                right = l;
                            }
                        }
                        same[left] = right; // actually recorded here
                    }
                }
            }
            for (long x=depthBuf.w-1; x>=0; x--)    { // set the pixels in the scan line
                if (same[x] == x)
                    pix[x] = random()&1;  // free choice, do it randomly
                else
                    pix[x] = pix[same[x]];  // constrained choice, obey constraint
                pixBuf.pa[y][x] = pix[x] ? Black : White;
            }
        }

#ifdef notdef
        for (int y=5; y<15; y++) {
            for (int x=10; x < W-10; x++) {
                dest[PI(x,y)] = Green;
            }
        }
#endif
        
#define NW      10
#define BOTTOM_Y   (5)
        int lx = depthBuf.w/2 - FARAWAY/2 - NW/2;
        int rx = depthBuf.w/2 + FARAWAY/2 - NW/2;
        for (int dy=0; dy<6; dy++) {
            for (int dx=0; dx<NW; dx++) {
                pixBuf.pa[BOTTOM_Y+dy][lx+dx] = Yellow;
                pixBuf.pa[BOTTOM_Y+dy][rx+dx] = Yellow;
            }
        }
    }];
    //lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    //lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
#endif

// plywood?

// apple's encoding?

//" random dot anaglyph github"
// in python: https://github.com/sashaperigo/random-dot-stereogram/blob/master/README.md
// no, image only

//[1] Zhaoping L, Ackermann J. Reversed Depth in Anticorrelated Random-Dot Stereograms and the Central-Peripheral Difference in Visual Inference[J]. Perception, 2018, 47(5): 531-539.

// simple SIRDS:  https://github.com/arkjedrz/stereogram.git

// another: https://github.com/CoolProgrammingUser/stereograms.git

// promising anaglyph: https://github.com/JanosRado/StereoMonitorCalibration.git
    depthTransformCount = transforms.count;
}

// used by colorize

channel rl[31] = {0,0,0,0,0,0,0,0,0,0,        5,10,15,20,25,Z,Z,Z,Z,Z,    0,0,0,0,0,5,10,15,20,25,Z};
channel gl[31] = {0,5,10,15,20,25,Z,Z,Z,Z,    Z,Z,Z,Z,Z,Z,Z,Z,Z,Z,        25,20,15,10,5,0,0,0,0,0,0};
channel bl[31] = {Z,Z,Z,Z,Z,25,15,10,5,0,    0,0,0,0,0,5,10,15,20,25,    5,10,15,20,25,Z,Z,Z,Z,Z,Z};

- (void) addPointTransforms {
    lastTransform = [Transform colorTransform: @"Negative"
                                 description: @"Negative"
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(Z-p.r, Z-p.g, Z-p.b);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Solarize"
                                 description: @"Simulate extreme overexposure"
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(p.r < Z/2 ? p.r : Z-p.r,
                                   p.g < Z/2 ? p.g : Z-p.g,
                                   p.b < Z/2 ? p.b : Z-p.r);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Red"
                                  description:@""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(p.r,0,0);
        }
        return ;
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Green"
                                  description:@""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(0,p.g,0);
        }
        return ;
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Blue"
                                  description:@""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(0,0,p.b);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    
    lastTransform = [Transform colorTransform:@"No blue"
                                  description:@""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(p.r,p.g,0);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform:@"No green"
                                  description:@""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(p.r,0,p.b);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform:@"No red"
                                  description:@""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(0,p.g,p.b);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"No color"
                                 description: @"Convert to brightness"
                               inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
       for (int i=0; i<n; i++) {
           channel c = LUM(buf[i]);
           buf[i] = SETRGB(c,c,c);
       }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"Colorize"
                                 description: @""
                               inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
       for (int i=0; i<n; i++) {
           Pixel p = buf[i];
           channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&(Z >> 3);
           buf[i] = SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
       }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"Truncate colors"
                                 description: @""
                               inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        channel mask = ((1<<v) - 1) << (8 - v);
        for (int i=0; i<n; i++) {
           Pixel p = buf[i];
            buf[i] = SETRGB(p.r&mask, p.g&mask, p.b&mask);
       }
    }];
    lastTransform.low = 1; lastTransform.value = 2; lastTransform.high = 7;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Brighten"
                                  description: @""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(p.r+(Z-p.r)/8,
                            p.g+(Z-p.g)/8,
                            p.b+(Z-p.b)/8);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"High contrast"
                                  description: @""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(CLIP((p.r-HALF_Z)*2+HALF_Z),
                            CLIP((p.g-HALF_Z)*2+HALF_Z),
                            CLIP((p.b-HALF_Z)*2+HALF_Z));
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"Swap colors"
                                  description: @"r→g, g→b, b→r"
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            buf[i] = SETRGB(p.g, p.b, p.r);
        }
    }];
    [self addTransform:lastTransform];
    
    // BROKEN: too blue
    lastTransform = [Transform colorTransform: @"Auto contrast"
                                  description: @""
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        u_long ps;
        u_long hist[Z+1];
        float map[Z+1];
        
        for (int i=0; i<Z+1; i++) {
            hist[i] = 0;
            map[i] = 0.0;
        }
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            hist[LUM(p)]++;
        }
        ps = 0;
        for (int i = 0; i < Z+1; i++) {
            map[i] = (float)Z * (float)ps/(float)n;
            ps += hist[i];
        }
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            channel l = LUM(p);
            float a = (map[l] - l)/Z;
            int r = p.r + (a*(Z-p.r));
            int g = p.g + (a*(Z-p.g));
            int b = p.b + (a*(Z-p.b));
            buf[i] = CRGB(r,g,b);
        }
    }];
    [self addTransform:lastTransform];
}

channel
max3(Pixel p) {
    int ab = (p.r > p.g);
    int ac = (p.r > p.b);
    int bc = (p.g > p.b);
    
    if ( ab &&  ac) return p.r;
    if (!ab &&  bc) return p.g;
    if (!bc && !ac) return p.b;
    
    NSLog(@"max3 cannot happen %d %d %d\n", p.r, p.g, p.b);
    return Z/2;
}

channel
min3(Pixel p) {
    int ab = (p.r < p.g);
    int ac = (p.r < p.b);
    int bc = (p.g < p.b);
    
    if ( ab &&  ac) return p.r;
    if (!ab &&  bc) return p.g;
    if (!bc && !ac) return p.b;
    
    NSLog(@"max3 cannot happen %d %d %d\n", p.r, p.g, p.b);
    return Z/2;
}

int
irand(int i) {
    return random() % i;
}

- (void) addOldies {
#ifdef NEW
    lastTransform = [Transform areaTransform: @"Motion blur"
                                  description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int streak) {
        int x, y, dx, nr, ng, nb;

        assert(streak > 0);

        for (y = 0; y < H; y++)
            for (x = 0; x < W; x++) {
                Pixel p;
                p.r = p.b = p.g = 0;
                p.a = src[PI(x,y)].a;
                dest[PI(x,y)] = p;
         }
        // int     Tsz       = 32;         // tile size, e.g., MAX_X/16
        long Tsz = W/16;
        
         for (y = 0; y < H-Tsz; y++) {
                 for (x = 0; x < W-Tsz; x++) {
                     Pixel *a = &dest[PI(x,y)];
                         nr = ng = nb = 0;
                         for (dx = x-1; dx >= 0 && dx > x-streak; dx--) {
                     Pixel *b = &src[PI(x,y)];     // target
                                 nr += b->r;
                                 ng += b->g;
                                 nb += b->b;
                         }
                         nr /= streak;
                         ng /= streak;
                         nb /= streak;
                         a->r = nr;
                         a->g = ng;
                         a->b = nb;
         }       }
    }];
    lastTransform.low = 2;
    lastTransform.value = 16;
    lastTransform.high = 40;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Old blur"
                                  description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int streak) {
        for (int y=1; y<H-1; y++) {
            for (int x=1; x<W-1; x++) {
                Pixel p = {0,0,0,Z};
                p.r = (src[PI(x,y)].r + src[PI(x+1,y)].r +
                       src[PI(x-1,y)].r +
                       src[PI(x,y-1)].r +
                       src[PI(x,y+1)].r)/5;
                p.g = (src[PI(x,y)].g +
                       src[PI(x+1,y)].g +
                       src[PI(x-1,y)].g +
                       src[PI(x,y-1)].g +
                       src[PI(x,y+1)].g)/5;
                p.b = (src[PI(x,y)].b +
                       src[PI(x+1,y)].b +
                       src[PI(x-1,y)].b +
                       src[PI(x,y-1)].b +
                       src[PI(x,y+1)].b)/5;
                dest[PI(x,y)] = p;
            }
        }
    }];
    [self addTransform:lastTransform];
    
#ifdef NOTYET
    lastTransform = [Transform areaTransform: @"Focus"
                                  description: @""
                                areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int streak) {
        for (int y=0; y<H; y++) {    // red
            for (int x=0; x<W; x++) {
                sChan[x][y] = srcBuf[PI(x,y)].r;
            }
        }
        focus(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].r = dChan[x][y];    // install red
                sChan[x][y] = srcBuf[PI(x,y)].g;    // get green
            }
        }
        focus(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].g = dChan[x][y];    // install green
                sChan[x][y] = srcBuf[PI(x,y)].b;    // get blue
            }
        }
        focus(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstBuf[PI(x,y)].b = dChan[x][y];    // install blue
            }
        }
    }];
    [self addTransform:lastTransform];
#endif
    
    lastTransform = [Transform areaTransform: @"Mean (slow and invisible)"   // area
                                  description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int N) {
#define NPIX    ((2*N+1)*(2*N+1))
        for (int y=0; y<H; y++) {    /*border*/
            for (int x=0; x<N; x++)
                dest[PI(x,y)] = dest[PI(W-x-1,y)] = White;
            if (y<N || y>H-N)
                for (int x=0; x<W; x++)
                    dest[PI(x,y)] = White;
        }
        for (int y=N; y<H-N; y++) {
            for (int x=N; x<W-N; x++) {
                int redsum=0, greensum=0, bluesum=0;

                for (int dy=y-N; dy <= y+N; dy++)
                    for (int dx=x-N; dx <=x+N; dx++) {
                        redsum += src[PI(x,y)].r;
                        greensum += src[PI(x,y)].g;
                        bluesum += src[PI(x,y)].b;
                    }
                dest[PI(x,y)] = SETRGB(redsum/NPIX, greensum/NPIX, bluesum/NPIX);
            }
        }
    }];
    lastTransform.low = 1;
    lastTransform.value = 3;
    lastTransform.high = 10;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
#endif
    
}

-(void) addMonochromes {
#ifdef NEW
    lastTransform = [Transform colorTransform:@"Desaturate" description:@"desaturate" pointTransform:^Pixel(Pixel p) {
        channel c = (max3(p) + min3(p))/2;
        return SETRGB(c,c,c);
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Max decomposition" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = max3(p);
        return SETRGB(c,c,c);
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Min decomposition" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = min3(p);
        return SETRGB(c,c,c);
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Ave" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = (p.r + p.g + p.b)/3;
        return SETRGB(c,c,c);
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"NTSC monochrome" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = (299*p.r + 587*p.g + 114*p.b)/1000;
        return SETRGB(c,c,c);
    }];
    [self addTransform:lastTransform];

    // move image
#endif //NEEW
}

#ifdef NOTYET

// if normalize is true, map pixels to range 0..MAX_BRIGHTNESS
// we use the a channel of our pixel buffers.

void convolution(const Pixel *in, Pixel *out,
                 const float *kernel, const int kn, const BOOL normalize) {
    assert(kn % 2 == 1);
    assert(W > kn && H > kn);
    const int khalf = kn / 2;
    float min = FLT_MAX, max = -FLT_MAX;
    
    if (normalize) {
        for (int x = khalf; x < W - khalf; x++) {
            for (int y = khalf; y < H - khalf; y++) {
                float pixel = 0.0;
                size_t c = 0;
                for (int j = -khalf; j <= khalf; j++) {
                    for (int i = -khalf; i <= khalf; i++) {
                        pixel += in[PI(x - i, y - j)].a * kernel[c];
                        c++;
                    }
                }
                if (pixel < min)
                    min = pixel;
                if (pixel > max)
                    max = pixel;
            }
        }
    }
 
    for (int x = khalf; x < W - khalf; x++) {
        for (int y = khalf; y < H - khalf; y++) {
            float pixel = 0.0;
            size_t c = 0;
            for (int j = -khalf; j <= khalf; j++)
                for (int i = -khalf; i <= khalf; i++) {
                    pixel += in[PI(x - i, y - j)].a * kernel[c];
                    c++;
                }
            if (normalize)
                pixel = Z * (pixel - min) / (max - min);
            out[PI(x, y)].a = (channel)pixel;
        }
    }
}
#endif

- (void) addGeometricTransforms {
    lastTransform = [Transform areaTransform: @"Zoom"
                                 description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        float zoom = instance.value;
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<remapBuf.w; x++) {
                long sx = centerX + (x-centerX)/zoom;
                long sy = centerY + (y-centerY)/zoom;
                REMAP_TO(x,y, sx,sy);
            }
        }
#ifdef DEBUG
        [remapBuf verify];
#endif
    }];
    lastTransform.low = 1;
    lastTransform.value = 2;
    lastTransform.high = 10;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

#ifdef NEW
    lastTransform = [Transform areaTransform: @"Shower stall"
                                  description: @"Through the wet glass"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int showerSize) {
        for (int y=0; y<H; y++)
            for (int x=0; x<W; x++)
                table[PI(x,y)] = Remap_White;

        // keep gerard's original density
        int nShower = ((float)(W*H)/(640.0*480.0))*2500;
        for(int i=0; i<nShower; i++) {
            int x = irand((int)W-1);
            int y = irand((int)H-1);
            PixelIndex_t pi = PI(x,y);
            
            for (long y1=y-showerSize; y1<=y+showerSize; y1++) {
                if (y1 < 0 || y1 >= H)
                    continue;
                for (long x1=x-showerSize; x1<=x+showerSize; x1++) {
                    if (x1 < 0 || x1 >= W)
                        continue;
                    table[PI(x1,y1)] = pi;
                }
            }
        }
    }];
    lastTransform.low = 10;
    lastTransform.value = 10;
    lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Horizontal shift"
                                  description: @""
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int n) {
        n = -n;
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                int nx = x + n;
                if (nx < 0 || nx >= W)
                    table[PI(x,y)] = Remap_White;
                else
                    table[PI(x,y)] = PI(nx,y);
            }
        }
    }];
    lastTransform.low = -200;
    lastTransform.value = 0;
    lastTransform.high = +200;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Vertical shift"
                                  description: @""
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int n) {
        n = -n;
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                int ny = y + n;
                if (ny < 0 || ny >= H)
                    table[PI(x,y)] = Remap_White;
                else
                    table[PI(x,y)] = PI(x,ny);
            }
        }
    }];
    lastTransform.low = -200;
    lastTransform.value = 0;
    lastTransform.high = +200;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Through a cylinder"
                                  description: @""
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int D) {
        for (int y=0; y<H; y++)
            for (int x=0; x<=CENTER_X; x++) {
                int fromx = CENTER_X*sin((M_PI/2)*x/CENTER_X);
                assert(fromx >= 0 && fromx < W);
                table[PI(x,y)] = PI(fromx, y);
                table[PI(W-1-x,y)] = PI(W-1-fromx, y);
            }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Tin Type"
                                 description: @"Edge detection"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        Pixel p = {0,0,0,Z};

        for (int y=0; y<H; y++) {
            int x;
            for (x=0; x<W-2; x++) {
                Pixel pin;
                int r, g, b;
                long xin = (x+2) >= W ? W - 1 : x+2;
                long yin = (y+2) >= H ? H - 1 : y+2;
                pin = src[PI(xin,yin)];
                r = src[PI(x,y)].r + Z/2 - pin.r;
                g = src[PI(x,y)].g + Z/2 - pin.g;
                b = src[PI(x,y)].b + Z/2 - pin.b;
                p.r = CLIP(r);  p.g = CLIP(g);  p.b = CLIP(b);
                dest[PI(x,y)] = p;
            }
            dest[PI(x-3,y)] = Grey;
            dest[PI(x-2,y)] = Grey;
            dest[PI(x-1,y)] = Grey;
            dest[PI(x  ,y)] = Grey;
            dest[PI(x+1,y)] = Grey;
        }
    }];
    [self addTransform:lastTransform];

#ifdef NOTYET
    /*
     * gaussianFilter:
     * http://www.songho.ca/dsp/cannyedge/cannyedge.html
     * determine size of kernel (odd #)
     * 0.0 <= sigma < 0.5 : 3
     * 0.5 <= sigma < 1.0 : 5
     * 1.0 <= sigma < 1.5 : 7
     * 1.5 <= sigma < 2.0 : 9
     * 2.0 <= sigma < 2.5 : 11
     * 2.5 <= sigma < 3.0 : 13 ...
     * kernelSize = 2 * int(2*sigma) + 3;
     */
    lastTransform = [Transform areaTransform: @"Gaussian filter (broken)"
                                description: @"Edge detection"
                               areaFunction: ^(Pixel *src, Pixel *dest, int tenSigma) {
        float sigma = (float)tenSigma/10.0;
        const int n = 2 * (int)(2 * sigma) + 3;
        const float mean = (float)floor(n / 2.0);
        float kernel[n * n]; // variable length array for the convolution kernel

        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                sChan[x][y] = LUM(src[PI(x,y)]);
            }
        }

        for (int i=0; i<configuredPixelsInImage; i++) {
            src[i].a = LUM(src[i]);
        }

        size_t c = 0;
         for (int i = 0; i < n; i++) {
             for (int j = 0; j < n; j++) {
                 kernel[c] = exp(-0.5 * (pow((i - mean) / sigma, 2.0) +
                                         pow((j - mean) / sigma, 2.0)))
                    / (2 * M_PI * sigma * sigma);
                 c++;
             }
         }

        convolution(src, dest, kernel, n, true);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel d = dChan[x][y];
                dest[PI(x,y)] = SETRGB(d,d,d);    // install blue
            }
        }
    }];
    lastTransform.low = 0;
    lastTransform.value = 10;
    lastTransform.high = 30;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"convolution sobel filter "
                                description: @"Edge detection"
                               areaFunction: ^(Pixel *src, Pixel *dest, int p) {
        assert(self->execute.bytesPerRow == self.execute.pixelsPerRow * sizeof(Pixel));

        for (int i=0; i<self->execute.pixelsInImage; i++) {
            src[i].a = LUM(src[i]);
        }
        
        const float Gx[] = {-1, 0, 1,
                            -2, 0, 2,
                            -1, 0, 1};
        convolution(src, dest, Gx, 3, false);
     
        const float Gy[] = { 1, 2, 1,
                             0, 0, 0,
                            -1,-2,-1};
        convolution(dest, src, Gy, 3, false);
        
        for (int i=0; i<self->execute.pixelsInImage; i++) {
            dest[i] = SETRGB(src[i].a, src[i].a, src[i].a);
        }
    }];
    [self addTransform:lastTransform];
#endif

#endif  // NEW
}

#ifdef notdef
#define RAD(A)  (M_PI*((double)(A))/180.0)
#define SR(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+2])
#define SG(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+1])
#define SB(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+0])
    // From http://www.rosettacode.org
    // I don't think we want Hough
    lastTransform = [Transform areaTransform: @"Hough "
                                 description: @"Edge detection"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        
//       uint8_t *houghtransform(uint8_t *d, )
         int rho, theta, y, x;
         int th = sqrt(W*W + H*H)/2.0;
         int tw = 360;
         uint8_t *ht = malloc(th*tw*4);
         memset(ht, 0, 4*th*tw); // black bg
        
         for(rho = 0; rho < th; rho++) {
           for(theta = 0; theta < tw/*720*/; theta++) {
             double C = cos(RAD(theta));
             double S = sin(RAD(theta));
             uint32_t totalred = 0;
             uint32_t totalgreen = 0;
             uint32_t totalblue = 0;
             uint32_t totalpix = 0;
             if ( theta < 45 || (theta > 135 && theta < 225) || theta > 315) {
               for(y = 0; y < H; y++) {
                 double dx = W/2.0 + (rho - (H/2.0-y)*S)/C;
                 if ( dx < 0 || dx >= W )
                     continue;
                 x = floor(dx+.5);
                 if (x == W)
                     continue;
                 totalpix++;
                   Pixel p = src[PI(x,y)];
                 totalred += p.r;
                 totalgreen += p.g;
                 totalblue += p.b;
               }
             } else {
               for(x = 0; x < W; x++) {
                 double dy = H/2.0 - (rho - (x - W/2.0)*C)/S;
                 if ( dy < 0 || dy >= H ) continue;
                 y = floor(dy+.5);
                 if (y == H) continue;
                   Pixel p = src[PI(x,y)];
                 totalred += p.r;
                 totalgreen += p.g;
                 totalblue += p.b;
               }
             }
             if ( totalpix > 0 ) {
                double dp = totalpix;
               SR(theta, rho) = (int)(totalred/dp)   &0xff;
               SG(theta, rho) = (int)(totalgreen/dp) &0xff;
               SB(theta, rho) = (int)(totalblue/dp)  &0xff;
             }
           }
         }
        
         *h = th;   // sqrt(W*W+H*H)/2
         *w = tw;   // 360
         *s = 4*tw;
         return ht;
    }];
    [self addTransform:lastTransform];
#endif

#ifdef NOTYET
   /*
    * gaussianFilter:
    * http://www.songho.ca/dsp/cannyedge/cannyedge.html
    * determine size of kernel (odd #)
    * 0.0 <= sigma < 0.5 : 3
    * 0.5 <= sigma < 1.0 : 5
    * 1.0 <= sigma < 1.5 : 7
    * 1.5 <= sigma < 2.0 : 9
    * 2.0 <= sigma < 2.5 : 11
    * 2.5 <= sigma < 3.0 : 13 ...
    * kernelSize = 2 * int(2*sigma) + 3;
    */
   void gaussian_filter(const pixel_t *in, pixel_t *out,
                        const int nx, const int ny, const float sigma)
   {
       const int n = 2 * (int)(2 * sigma) + 3;
       const float mean = (float)floor(n / 2.0);
       float kernel[n * n]; // variable length array
    
       fprintf(stderr, "gaussian_filter: kernel size %d, sigma=%g\n",
               n, sigma);
       size_t c = 0;
       for (int i = 0; i < n; i++)
           for (int j = 0; j < n; j++) {
               kernel[c] = exp(-0.5 * (pow((i - mean) / sigma, 2.0) +
                                       pow((j - mean) / sigma, 2.0)))
                           / (2 * M_PI * sigma * sigma);
               c++;
           }
    
       convolution(in, out, kernel, nx, ny, n, true);
   }
    
   /*
    * Links:
    * http://en.wikipedia.org/wiki/Canny_edge_detector
    * http://www.tomgibara.com/computer-vision/CannyEdgeDetector.java
    * http://fourier.eng.hmc.edu/e161/lectures/canny/node1.html
    * http://www.songho.ca/dsp/cannyedge/cannyedge.html
    *
    * Note: T1 and T2 are lower and upper thresholds.
    */
   pixel_t *canny_edge_detection(const pixel_t *in,
                                 const bitmap_info_header_t *bmp_ih,
                                 const int tmin, const int tmax,
                                 const float sigma)
   {
       const int nx = bmp_ih->width;
       const int ny = bmp_ih->height;
    
       pixel_t *G = calloc(nx * ny * sizeof(pixel_t), 1);
       pixel_t *after_Gx = calloc(nx * ny * sizeof(pixel_t), 1);
       pixel_t *after_Gy = calloc(nx * ny * sizeof(pixel_t), 1);
       pixel_t *nms = calloc(nx * ny * sizeof(pixel_t), 1);
       pixel_t *out = malloc(bmp_ih->bmp_bytesz * sizeof(pixel_t));
    
       if (G == NULL || after_Gx == NULL || after_Gy == NULL ||
           nms == NULL || out == NULL) {
           fprintf(stderr, "canny_edge_detection:"
                   " Failed memory allocation(s).\n");
           exit(1);
       }
    
       gaussian_filter(in, out, nx, ny, sigma);
    
       const float Gx[] = {-1, 0, 1,
                           -2, 0, 2,
                           -1, 0, 1};
    
       convolution(out, after_Gx, Gx, nx, ny, 3, false);
    
       const float Gy[] = { 1, 2, 1,
                            0, 0, 0,
                           -1,-2,-1};
    
       convolution(out, after_Gy, Gy, nx, ny, 3, false);
    
       for (int i = 1; i < nx - 1; i++)
           for (int j = 1; j < ny - 1; j++) {
               const int c = i + nx * j;
               // G[c] = abs(after_Gx[c]) + abs(after_Gy[c]);
               G[c] = (pixel_t)hypot(after_Gx[c], after_Gy[c]);
           }
    
       // Non-maximum suppression, straightforward implementation.
       for (int i = 1; i < nx - 1; i++)
           for (int j = 1; j < ny - 1; j++) {
               const int c = i + nx * j;
               const int nn = c - nx;
               const int ss = c + nx;
               const int ww = c + 1;
               const int ee = c - 1;
               const int nw = nn + 1;
               const int ne = nn - 1;
               const int sw = ss + 1;
               const int se = ss - 1;
    
               const float dir = (float)(fmod(atan2(after_Gy[c],
                                                    after_Gx[c]) + M_PI,
                                              M_PI) / M_PI) * 8;
    
               if (((dir <= 1 || dir > 7) && G[c] > G[ee] &&
                    G[c] > G[ww]) || // 0 deg
                   ((dir > 1 && dir <= 3) && G[c] > G[nw] &&
                    G[c] > G[se]) || // 45 deg
                   ((dir > 3 && dir <= 5) && G[c] > G[nn] &&
                    G[c] > G[ss]) || // 90 deg
                   ((dir > 5 && dir <= 7) && G[c] > G[ne] &&
                    G[c] > G[sw]))   // 135 deg
                   nms[c] = G[c];
               else
                   nms[c] = 0;
           }
    
       // Reuse array
       // used as a stack. nx*ny/2 elements should be enough.
       int *edges = (int*) after_Gy;
       memset(out, 0, sizeof(pixel_t) * nx * ny);
       memset(edges, 0, sizeof(pixel_t) * nx * ny);
    
       // Tracing edges with hysteresis . Non-recursive implementation.
       size_t c = 1;
       for (int j = 1; j < ny - 1; j++)
           for (int i = 1; i < nx - 1; i++) {
               if (nms[c] >= tmax && out[c] == 0) { // trace edges
                   out[c] = MAX_BRIGHTNESS;
                   int nedges = 1;
                   edges[0] = c;
    
                   do {
                       nedges--;
                       const int t = edges[nedges];
    
                       int nbs[8]; // neighbours
                       nbs[0] = t - nx;     // nn
                       nbs[1] = t + nx;     // ss
                       nbs[2] = t + 1;      // ww
                       nbs[3] = t - 1;      // ee
                       nbs[4] = nbs[0] + 1; // nw
                       nbs[5] = nbs[0] - 1; // ne
                       nbs[6] = nbs[1] + 1; // sw
                       nbs[7] = nbs[1] - 1; // se
    
                       for (int k = 0; k < 8; k++)
                           if (nms[nbs[k]] >= tmin && out[nbs[k]] == 0) {
                               out[nbs[k]] = MAX_BRIGHTNESS;
                               edges[nedges] = nbs[k];
                               nedges++;
                           }
                   } while (nedges > 0);
               }
               c++;
           }
    
       free(after_Gx);
       free(after_Gy);
       free(G);
       free(nms);
    
       return out;
#endif
       
#ifdef notyet
    // from https://github.com/cynicphoenix/Canny-Edge-Detector.git
    // no, it is in jupyter form.
    // From http://www.rosettacode.org
    lastTransform = [Transform areaTransform: @"Canny edge detector"
                                 description: @"Edge detection"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        Pixel p = {0,0,0,Z};

        for (int y=0; y<H; y++) {
            int x;
            for (x=0; x<W-2; x++) {
                Pixel pin;
                int r, g, b;
                long xin = (x+2) >= W ? W - 1 : x+2;
                long yin = (y+2) >= H ? H - 1 : y+2;
                pin = src[PI(xin,yin)];
                r = src[PI(x,y)].r + Z/2 - pin.r;
                g = src[PI(x,y)].g + Z/2 - pin.g;
                b = src[PI(x,y)].b + Z/2 - pin.b;
                p.r = CLIP(r);  p.g = CLIP(g);  p.b = CLIP(b);
                dest[PI(x,y)] = p;
            }
            dest[PI(x-3,y)] = Grey;
            dest[PI(x-2,y)] = Grey;
            dest[PI(x-1,y)] = Grey;
            dest[PI(x  ,y)] = Grey;
            dest[PI(x+1,y)] = Grey;
        }
    }];
    [self addTransform:lastTransform];
#endif

#ifdef notyet
    extern  init_proc init_rotate_right;
    extern  init_proc init_copy_right;
    extern  init_proc init_droop_right;
    extern  init_proc init_raise_right;
    extern  init_proc init_shower2;
    extern  init_proc init_cylinder;
    extern  init_proc init_shift_left;
    extern  init_proc init_shift_right;
    extern  init_proc init_slicer;
    extern  init_proc init_seurat;

    extern  transform_t do_shear;
    extern  transform_t do_smear;
    extern  transform_t do_shower;
    extern  transform_t do_bleed;
    extern  transform_t do_melt;
    extern  transform_t do_shift_left;
    extern  transform_t do_shift_right;
    
    for (int x=0; x<width/2; x++) { // copy right
        for (int y=0; y<height; y++) {
            pixels[P(width - x - 1,y)] = pixels[P(x,y)];
        }
    }
#endif
       
#ifdef notdef
    extern  transform_t do_diff;
    extern  transform_t do_color_logo;
    extern  transform_t do_spectrum;
#endif

- (void) addColorVisionDeficits {
//    [flattransforms addObjectsFromArray:transformList];
}

#ifdef NOTDEF
static Pixel
ave(Pixel p1, Pixel p2) {
    Pixel p;
    p.r = (p1.r + p2.r + 1)/2;
    p.g = (p1.g + p2.g + 1)/2;
    p.b = (p1.b + p2.b + 1)/2;
    p.a = Z;
    return p;
}
#endif
       
#define     RAN_MASK    0x1fff
#define     LUT_RES        (Z+1)

float
Frand(void) {
    return((double)(rand() & RAN_MASK) / (double)(RAN_MASK));
}

#ifdef notdef

        add_button(right(last_top->r), "neon", "Neon", Green, do_sobel);
        last_top = last_button;
#endif

typedef struct Pt {
    int x,y;
} Pt;

/*
 * The following is used for the Escher transform.
 *
 * corner zero of each block is the unshared corner.  Corners are labeled
 * clockwise, and so are the block faces.
 */

struct block {
    Pt    f[3][4];    // three faces, four corners
} block;

int pixPerSide;
int dxToBlockCenter;

void
make_block(Pt origin, struct block *b) {
    b->f[0][0] = origin;
    b->f[0][1] = b->f[1][3] = (Pt){origin.x,origin.y+pixPerSide};
    b->f[0][2] = b->f[1][2] = b->f[2][2] =
        (Pt){origin.x+dxToBlockCenter,origin.y+(pixPerSide/2)};
    b->f[0][3] = b->f[2][1] = (Pt){origin.x+dxToBlockCenter,origin.y-(pixPerSide/2)};

    b->f[1][0] = (Pt){origin.x+dxToBlockCenter, origin.y + 3*pixPerSide/2};
    b->f[1][1] = b->f[2][3] = (Pt){origin.x+2*dxToBlockCenter, origin.y+pixPerSide};

    b->f[2][0] = (Pt){origin.x+2*dxToBlockCenter, origin.y};
}

- (void) addArtTransforms {
    lastTransform = [Transform colorTransform: @"Warhol"
                                 description: @"cartoon colors"
                                inPlacePtFunc: ^(Pixel *buf, size_t n, int v) {
        int ave_r=0, ave_g=0, ave_b=0;
        
        for (int i=0; i<n; i++) {
            Pixel p = buf[i];
            ave_r += p.r;
            ave_g += p.g;
            ave_b += p.b;
        }
        
        ave_r /= n;
        ave_g /= n;
        ave_b /= n;
        
        for (int i=0; i<n; i++) {
            Pixel p = {0,0,0,Z};
            p.r = (buf[i].r >= ave_r) ? Z : 0;
            p.g = (buf[i].g >= ave_g) ? Z : 0;
            p.b = (buf[i].b >= ave_b) ? Z : 0;
            buf[i] = p;
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Escher"
                                 description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        pixPerSide = instance.value;
        dxToBlockCenter = ((int)(pixPerSide*sqrt(0.75)));
        
        for (int x=0; x<remapBuf.w; x++) {
            for (int y=0; y<remapBuf.h; y++)
                REMAP_COLOR(x, y,Remap_White);
        }

        int nxBlocks = (((int)remapBuf.w/(2*dxToBlockCenter)) + 2);
        int nyBlocks = (int)((remapBuf.h/(3*pixPerSide/2)) + 2);
        
        struct block_list {
            int    x,y;    // the location of the lower left corner
            struct block b;
        } block_list[nxBlocks][nyBlocks];
        
        // layout blocks
        int row, col;
        Pt start = {-irand(dxToBlockCenter/2), -irand(pixPerSide/2)};
        
        for (row=0; row<nyBlocks; ) {
            Pt origin = start;
            for (col=0; col<nxBlocks; col++) {
                make_block(origin, &block_list[col][row].b);
                origin.x = origin.x + 2*dxToBlockCenter;
            }
            if (++row & 1) { /* if odd rows are staggered to the left */
                start.x -= dxToBlockCenter;
                start.y += (3*pixPerSide/2);
            } else {
                start.x += dxToBlockCenter;
                start.y += (3*pixPerSide/2);
            }
        }
        
        for (int row=0; row<nyBlocks; row++) {
            for (int col=0; col<nxBlocks; col++)
            for (int i=0; i<3; i++)    // for each face
            for (int j=0; j<4; j++) {    // each corner
                Pt p = block_list[col][row].b.f[i][j];
                int x = p.x;
                int y = p.y;
                if (IS_IN_REMAP(x, y, remapBuf))
                    REMAP_COLOR(x,y,Remap_Black);
            }
        }
        
        for (int row=0; row<nyBlocks; row++) {
            for (int col=0; col<nxBlocks; col++) {
                for (int i=0; i<3; i++) {
                    float dxx, dxy, dyx, dyy;
#define CORNERS (block_list[col][row].b.f[i])
                    
#ifdef notdef
                    int xstart;
                    int ll = 2;
                    int lr = 1;
                    int ul = 3;
#else
                    int ll = irand(4);
                    int dir = irand(1)*2;
                    int lr = (ll + 3 + dir) % 4;
                    int ul = (ll + 1 + dir) % 4;
#endif
                    
                    dxx = (CORNERS[lr].x - CORNERS[ll].x)/(float)remapBuf.w;
                    dxy = (CORNERS[lr].y - CORNERS[ll].y)/(float)remapBuf.w;
                    dyx = (CORNERS[ul].x - CORNERS[ll].x)/(float)remapBuf.h;
                    dyy = (CORNERS[ul].y - CORNERS[ll].y)/(float)remapBuf.h;
                    
                    for (int y=0; y<remapBuf.h; y++) {    // we could actually skip some of these
                        for (int x=0; x<remapBuf.w; x++)    {
                            int nx = CORNERS[ll].x + y*dyx + x*dxx;
                            int ny = CORNERS[ll].y + y*dyy + x*dxy;
                            if (IS_IN_REMAP(nx, ny, remapBuf))
                                REMAP_TO(nx,ny, x,y);
                        }
                    }
                }
            }
        }
    }];
    lastTransform.low = 100;
    lastTransform.value = 170;
    lastTransform.high = 250;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
    
#ifdef NEW


    lastTransform = [Transform areaTransform: @"Seurat"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        double distortion = (float)param / 10.0;    // range 0.1 to 0.5, original had only those values
        long    x_strt, x_stop, x_incr;
        long    dlut[LUT_RES];            /* distort lut         */
        long    olut[LUT_RES];            /* ran offset lut     */
        
        int    i, j;            /* worst loop counters    */
        long    dmkr, omkr;        /* lut index markers    */
        
        for(i = 0; i < LUT_RES; i++) {
            dlut[i] = (Frand() <= distortion);
            olut[i] = LUT_RES * Frand();
        }
        
        dmkr = omkr = 0;
        
        for (int y = 1; y < H - 1; y++) {
            if ((y % 2)) {
                x_strt = 1; x_stop = W - 1; x_incr = 1;
            } else {
                x_strt = W - 2; x_stop = 0; x_incr = -1;
            }
            for(long x = x_strt; x != x_stop; x += x_incr){
                Pixel val = src[PI(x,y)];
                for(j = -2; ++j < 2;)
                for(i = -2; ++i < 2;) {
                    if (dlut[dmkr])
                        dest[PI(x+i,y+j)] = src[PI(x+i,y+j)] = val;
                    if (++dmkr >= LUT_RES) {
                        dmkr = olut[omkr];
                        if (++omkr >= LUT_RES)
                            omkr = 0;
                    }
                }
            }
        }
    }];
    lastTransform.low = 1;
    lastTransform.value = 1;
    lastTransform.high = 5;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Mondrian"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        int c=0;
        int w = rand()%W;
        int h = rand()%H;
        static int oc = 0;
        
        while (c == 0 || c == oc) {
            c   = (rand()%2)?1:0;
            c  |= (rand()%2)?2:0;
            c  |= (rand()%2)?4:0;
        }
        oc = c;
        
        for (int y=0+h; y<0+2*h && y < H; y++) {
            for (int x=0+w; x < 0+2*w && x < W; x++) {
                Pixel p = src[PI(x,y)];
                if (c&1) p.r = Z;
                if (c&2) p.g = Z;
                if (c&4) p.b = Z;
                dest[PI(x,y)] = p;
            }
        }
    }];
    [self addTransform:lastTransform];

#ifdef NOTYET
    lastTransform = [Transform areaTransform: @"Charcoal sketch"
                                 description: @""
                                areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int p) {
        // monochrome sobel...
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                sChan[x][y] = LUM(srcBuf[PI(x,y)]);
            }
        }
        sobel(sChan, dChan);
        
        // ... + negative + high contrast...
        u_long ps;
        u_long hist[Z+1];
        float map[Z+1];
        for (int i = 0; i < Z+1; i++)
            hist[i] = 0;

        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel c = Z - dChan[x][y];
                dChan[x][y] = c;
                hist[c]++;
            }
        }
        
        ps = 0;
        for (int i = 0; i < Z+1; i++) {
            map[i] = Z*((float)ps/((float)configuredPixelsInImage));
            ps += hist[i];
        }
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                //channel lu = dChan[x][y];
                //float a = (map[lu] - lu)/Z;
                //int nc = lu + (a*(Z-lu));
                //sChan[x][y] = CLIP(nc);
                sChan[x][y] = dChan[x][y];
            }
        }
        
        focus(sChan, dChan);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel c = dChan[x][y];
                // high contrast....
                c = CLIP((c-HALF_Z)*2+HALF_Z);
                dstBuf[PI(x,y)] = SETRGB(c,c,c);
            }
        }
    }];
    [self addTransform:lastTransform];
#endif

    lastTransform = [Transform areaTransform: @"Picasso"
                                  description: @""
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int value) {
        long x, y, r = 0;
        long dx, dy, xshift[H], yshift[W];

        for (y=0; y<h; y++)
            for (x=0; x<w; x++)
        table[PI(x,y)] = PI(x,y);

        for (x = dx = 0; x < w; x++) {
            if (dx == 0) {
                r = (random()&63) - 32;
                dx = 8+(random()&31);
            } else
                dx--;
            yshift[x] = r;
        }

        for (y = dy = 0; y < h; y++) {
            if (dy == 0) {
                r = (random()&63) - 32;
                dy = 8+(random()&31);
            } else
                dy--;
            xshift[y] = r;
        }

        for (y=0; y<h; y++)
            for (x=0; x<w; x++) {
                dx = x + xshift[y];
                dy = y + yshift[x];
                if (dx < W && dy < H && dx>=0 && dy>=0)
                    table[PI(x,y)] = PI(dx,dy);
            }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Monet (broken)"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        channel dlut[Z+1], olut[Z+1];
        int x, y;
        int i, j=0, len=5, k;
        int prob = Z/4;

        for (i=0; i<=Z; i++) {
            dlut[i] = irand(Z+1) <= prob;
            olut[i] = irand(Z+1);
        }

        i = 0;
        memset(dest, 0, self->execute.bytesInImage*sizeof(Pixel));
        for (y=1; y<H-1; y++) {
            for (x=0; x<W-len; x++) {
                if (dlut[i] && LUM(src[PI(x,y-1)]) < prob) {
                    for (k=0; k<len; k++) {
                        dest[PI(x+k,y-1)] = src[PI(x+k,y-1)] = ave(src[PI(x+k,y-1)], src[PI(x,y-1)]);
                        dest[PI(x+k,y  )] = src[PI(x+k,y  )] = ave(src[PI(x+k,y  )], src[PI(x,y  )]);
                        dest[PI(x+k,y+1)] = src[PI(x+k,y+1)] = ave(src[PI(x+k,y+1)], src[PI(x,y+1)]);
                    }
                }
                if (++i > Z) {
                    i = olut[j];
                    j = (j+1)%(Z+1);
                }
            }
        }
    }];
    [self addTransform:lastTransform];

#define CX    ((int)W/4)
#define CY    ((int)H*3/4)
#define OPSHIFT    3 //(3 /*was 0*/)

    lastTransform = [Transform areaTransform: @"Op art (broken)"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                Pixel p = src[PI(x,y)];
                int factor = (CX-(x-CX)*(x-CX) - (y-CY)*(y-CY));
                channel r = p.r^(p.r*factor >> OPSHIFT);
                channel g = p.g^(p.g*factor >> OPSHIFT);
                channel b = p.b^(p.b*factor >> OPSHIFT);
                dest[PI(x,y)] = CRGB(r,g,b);
            }
        }
    }];
    [self addTransform:lastTransform];
#endif  // NEW
}

#ifdef notdef

double r1 = r*r/(R/2);
return (Point){CENTER_X+(int)(r1*cos(a)), CENTER_Y+(int)(r1*sin(a))};

extern  init_proc init_fisheye;
extern  init_proc init_andrew;
extern  init_proc init_twist;
extern  init_proc init_kentwist;
extern  init_proc init_slicer;

extern  init_proc init_high;
extern  init_proc init_auto;


#endif

#ifdef notdef

#define HALF_Z          (Z/2)


typedef Point remap[W][W];
typedef void *init_proc(void);

/* in trans.c */
extern  int irand(int i);
extern  int ptinrect(Point p, Rectangle r);

extern  transform_t do_point;

extern  transform_t do_bleed;
extern  transform_t do_slicer;
extern  transform_t do_melt;
extern  transform_t do_smear;
extern  transform_t monet;
extern  transform_t do_seurat;
extern  transform_t do_crazy_seurat;

extern  transform_t do_cfs;
extern  transform_t do_sobel;
extern  transform_t do_neg_sobel;
extern  transform_t cartoon;
extern  transform_t do_edge;

#endif

@end

#ifdef lsc0
lsc_button(BELOW, "blkwht", do_point, init_lum);
sample_secondary_button = last_button;
lsc_button(BELOW, "brghtr", do_point, init_brighten);
lsc_button(BELOW, "dimmer", do_point, init_truncatepix);
lsc_button(BELOW, "contrast", do_point, init_high);
lsc_button(BELOW, "negative", do_point, init_negative);
lsc_button(BELOW, "colorize", do_point, init_colorize);
lsc_button(BELOW, "outline", do_sobel, 0);
lsc_button(BELOW, "raisedgray", do_edge, 0);

lsc_button(BELOW, "bigpixels", do_remap, init_pixels4);
lsc_button(BELOW, "blur", do_blur, 0);
lsc_button(BELOW, "blurry", do_brownian, 0);
lsc_button(BELOW, "focus", do_focus, 0);
lsc_button(BELOW, "bleed", do_bleed, 0);
lsc_button(BELOW, "crackle", do_shower, 0);
lsc_button(BELOW, "zoom", do_remap, init_zoom);
lsc_button(BELOW, "earthqke", do_shear, 0);
lsc_button(BELOW, "speckle", do_cfs, 0);
lsc_button(BELOW, "fisheye", do_remap, init_fisheye);

#define POINTCOL    0
{"Luminance",        init_lum, do_point, "luminance", "", 0, POINT_COLOR},
{"Brighten",        init_brighten, do_point, "brighter", "", 0, POINT_COLOR},
{"Truncate brightness",    init_truncatepix, do_point, "truncate", "brightness", 0, POINT_COLOR},
{"More Contrast",    init_high, do_point, "contrast", "", 0, POINT_COLOR},
{"Op art",        0, op_art, "op art", "", 0, POINT_COLOR},
{"Auto contrast",     0, do_auto, "auto", "contrast", 0, POINT_COLOR},

{"Negative", init_negative, do_point, "negative", "", 1, POINT_COLOR},
{"Colorize", init_colorize, do_point, "colorize", "", 0, POINT_COLOR},
{"Swap colors", init_swapcolors, do_point, "swap", "colors", 0, POINT_COLOR},
{"Pixels",    init_pixels4, do_remap, "big", "pixels", 0, POINT_COLOR},
{"Brownian pixels", 0, do_brownian, "Brownian", "pixels", 0, POINT_COLOR},

#define AREACOL        2
{"Blur",         0, do_blur, "blur", "", 1, AREA_COLOR},
{"Bleed",        0, do_bleed, "bleed", "", 0, AREA_COLOR},
{"1 bit Floyd/Steinberg",    0, do_fs1, "Floyd/", "Steinberg", 0, AREA_COLOR},
{"2 bit Floyd/Steinberg",    0, do_fs2, "2 bit", "F/S", 0, AREA_COLOR},
{"color Floyd/Steinberg",    0, do_cfs, "color", "F/S", 0, AREA_COLOR},

{"Focus",         0, do_focus, "focus", "", 1, AREA_COLOR},
{"Shear",         0, do_shear, "shear", "", 0, AREA_COLOR},
{"Sobel",        0, do_sobel, "Neon", "", 0, AREA_COLOR},
{"Shower stall",    0, do_shower, "shower", "stall", 0, AREA_COLOR},
{"Zoom",        init_zoom, do_remap, "zoom", "", 0, AREA_COLOR},
{"Sampled zoom",    0, do_sampled_zoom, "sampled", "zoom", 0, AREA_COLOR},

#define GEOMCOL        4
{"Mirror",        init_mirror, do_remap, "mirror", "", 1, GEOM_COLOR},
{"Bignose",        init_fisheye, do_remap, "Fish", "eye", 0, GEOM_COLOR},
{"Cylinder projection",    init_cylinder, do_remap, "cylinder", "", 0, GEOM_COLOR},
{"Shower stall 2",    init_shower2, do_remap, "shower", "stall 2", 0, GEOM_COLOR},

{"Rotate right",    init_rotate_right, do_remap, "rotate", "right", 1, GEOM_COLOR},
{"Shift right",        init_shift_right, do_remap, "shift", "right", 0, GEOM_COLOR},
{"Copy right",         init_copy_right, do_remap, "copy", "right", 0, GEOM_COLOR},
{"Raise right",        init_raise_right, do_remap, "raise", "right", 0, GEOM_COLOR},
{"Smear",        0, do_smear, "sine", "smear", 0, GEOM_COLOR},

{"edge",        0, do_edge, "Edge", "Filter", 0, GEOM_COLOR},
// XXX    {"Difference",        0, do_diff, "difference", "last op", 0, GEOM_COLOR},
/*    {"Monet",        0, monet, "Monet", "(?)", 0, GEOM_COLOR},*/
// XXX    {"Seurat",        0, do_seurat, "Seurat", "", 0, GEOM_COLOR},
// XXX    {"Crazy Seurat",    0, do_crazy_seurat, "Crazy", "Seurat", 0, GEOM_COLOR},

#define OTHERCOL    6
{"Logo",        0, do_logo, "logo", "", 1, OTHER_COLOR},
/*    {"Color logo",        0, do_color_logo, "color", "logo", 0, OTHER_COLOR},*/
{"Spectrum",         0, do_spectrum, "spectrum", "", 0, OTHER_COLOR},
#ifdef test
{"test", 0, cartoon, "Warhol", "", , 0, NEW},
{"Seurat?", 0, do_cfs, "Matisse", "", 0, NEW},
{"Slicer", 0, do_slicer, "Picasso", "", 0, OTHER_COLOR},
{"Neg", 0, do_neg_sobel, "Surreal", "", 0, NEW},
{"Escher", init_escher, do_remap, "Escher", "", 0, NEW},
#endif

#ifdef notused
{"Monet", 0, monet, "Monet", "", 0, NEW},
{"Melt", 0, do_melt, "melt", "", 1, NEW},
#endif

#endif

#ifdef notyet

    // colorblind

    extern  transform_t op_art;
    extern  transform_t do_auto;
    extern  init_proc init_colorize;
    extern  init_proc init_swapcolors;
    extern  init_proc init_lum;
    extern  init_proc init_high;
    extern  init_proc init_lum;
    extern  init_proc init_truncatepix;
    extern  init_proc init_brighten;
    extern  init_proc init_auto;
    extern  init_proc init_negative;

    #ifdef notdef
        for (int y=0; y<height/2; y++) {    // copy bottom
            for (int x=0; x<width; x++) {
                *A(image,x,y)] = *A(image,x,height - y - 1)];
            }
        }


        for (int y=0; y<height/2; y++) {    // copy top
            for (int x=0; x<width; x++) {
                pixels[P(x,height - y - 1)] = pixels[P(x,y)];
            }
        }

        for (int x=0; x<width/2; x++) { // copy right
            for (int y=0; y<height; y++) {
                pixels[P(width - x - 1,y)] = pixels[P(x,y)];
            }
        }

        for (int x=0; x<width/2; x++) { // copy left
            for (int y=0; y<height; y++) {
                pixels[P(x,y)] = pixels[P(width - x - 1,y)];
            }
        }
    #endif
#endif
