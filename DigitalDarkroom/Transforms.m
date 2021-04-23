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

//#define DEBUG_TRANSFORMS    1   // bounds checking and a lot of assertions

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

#ifdef NOTUSED
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
    [self addTestTransforms];
    
    [self addPolarTransforms];

    [self addGeometricTransforms];
    [self addArtTransforms];
    [self addAreaTransforms];   // manu unimplemented
    [self addPointTransforms];  // working:
}

// transform at given index, or nil if NO_TRANSFORM

- (Transform * __nullable) transformAtIndex:(long) index {
    if (index == NO_TRANSFORM)
        return nil;
    return [transforms objectAtIndex:index];
}

// if normalize is true, map pixels to range 0..MAX_BRIGHTNESS
// we use the a channel of our pixel buffers.

void convolution(ChBuf *in, ChBuf *out,
                 const float *kernel, const int kn, const BOOL normalize) {
    long W = in.w;
    long H = in.h;
    assert(kn % 2 == 1);
    assert(W > kn && H > kn);
    const int khalf = kn / 2;
    float min = FLT_MAX, max = -FLT_MAX;
    
    if (normalize) {
        for (int x = khalf; x < W - khalf; x++) {
            for (int y = khalf; y < H - khalf; y++) {
                float chan = 0.0;
                size_t c = 0;
                for (int j = -khalf; j <= khalf; j++) {
                    for (int i = -khalf; i <= khalf; i++) {
                        chan += in.ca[y-j][x-i] * kernel[c];
                        c++;
                    }
                }
                if (chan < min)
                    min = chan;
                if (chan > max)
                    max = chan;
            }
        }
    }
 
    for (int x = khalf; x < W - khalf; x++) {
        for (int y = khalf; y < H - khalf; y++) {
            float chan = 0.0;
            size_t c = 0;
            for (int j = -khalf; j <= khalf; j++)
                for (int i = -khalf; i <= khalf; i++) {
                    chan += in.ca[y-j][x-i] * kernel[c];
                    c++;
                }
            if (normalize)
                chan = Z * (chan - min) / (max - min);
            out.ca[y][x] = chan;
        }
    }
}

// derived from Gerard's original code
void
sobel(ChBuf *s, ChBuf *d) {
    long H = s.h;
    long W = s.w;
    for (int y=1; y<H-1-1; y++) {
        for (int x=1; x<W-1-1; x++) {
            int aa, bb;
            aa = s.ca[y-1][x-1] + s.ca[y][x-1]*2 + s.ca[y+1][x-1] -
                s.ca[y-1][x+1] - s.ca[y][x+1]*2 - s.ca[y+1][x+1];
            bb = s.ca[y-1][x-1] + s.ca[y-1][x]*2 +
                s.ca[y-1][x+1] -
                s.ca[y+1][x-1] - s.ca[y+1][x]*2 -
                s.ca[y+1][x+1];
            int diff = sqrt(aa*aa + bb*bb);
            if (diff > Z)
                d.ca[y][x] = Z;
            else
                d.ca[y][x] = diff;
        }
    }
}

// Gerard's original code
void
focus(ChBuf *s, ChBuf *d) {
    long H = s.h;
    long W = s.w;
    for (int y=1; y<H-1; y++) {
        for (int x=1; x<W-1; x++) {
            int c =
                5*s.ca[y][x] -
                  s.ca[y][x+1] -
                  s.ca[y][x-1] -
                  s.ca[y-1][x] -
                  s.ca[y+1][x];
            d.ca[y][x] = CLIP(c);
        }
    }
}

#ifdef DEBUG_TRANSFORMS
#define GET_PA(p, y, x) [p check_get_Pa: y X:x];
#else
#define GET_PA(p, y, x) (p).pa[y][x]
#endif

#define DA(d,y,x)    (d).pa[y][x]           // this is 0.5% faster than DB
#define DB(d,y,x)    (d).pb[(y)*(d).w + (x)]
#define D(d,y,x)    DA(d,y,x)

typedef struct {
    u_int rh[Z+1], gh[Z+1], bh[Z+1];
} Hist_t;

void
setHistAround(PixelArray_t srcpa, int x, int y, int range, Hist_t *hists) {
    for (int dy=y-range; dy <= y+range; dy++) {
        for (int dx=x-range; dx <= x+range; dx++) {
            Pixel p = srcpa[dy][dx];
            hists->rh[p.r]++;
            hists->gh[p.g]++;
            hists->bh[p.b]++;
        }
    }
}

// For each of these, x,y is the new central pixel.  Remove the ones now
// out of range on the left, and add the new ones from the right. I couldn't
// think of a more efficient way to do this, and Jon Bentley confirmed it.

void
moveHistRight(PixelArray_t srcpa, int x, int y, int range, Hist_t *hists) {
    for (int row=y-range; row<=y+range; row++) {
        Pixel lp = srcpa[row][x-range-1];
        hists->rh[lp.r]--;
        hists->gh[lp.g]--;
        hists->bh[lp.b]--;
        Pixel np = srcpa[row][x+range];
        hists->rh[np.r]++;
        hists->gh[np.g]++;
        hists->bh[np.b]++;
    }
}

void
moveHistLeft(PixelArray_t srcpa, int x, int y, int range, Hist_t *hists) {
    for (int row=y-range; row<=y+range; row++) {
        Pixel rp = srcpa[row][x+range+1];
        hists->rh[rp.r]--;
        hists->gh[rp.g]--;
        hists->bh[rp.b]--;
        Pixel np = srcpa[row][x-range];
        hists->rh[np.r]++;
        hists->gh[np.g]++;
        hists->bh[np.b]++;
    }
}

void
moveHistDown(PixelArray_t srcpa, int x, int y, int range, Hist_t *hists) {
    for (int col=x-range; col<=x+range; col++) {
        Pixel tp = srcpa[y-range-1][col];
        hists->rh[tp.r]--;
        hists->gh[tp.g]--;
        hists->bh[tp.b]--;
        Pixel np = srcpa[y+range][col];
        hists->rh[np.r]++;
        hists->gh[np.g]++;
        hists->bh[np.b]++;
    }
}

Pixel
mostCommonColorInHist(Hist_t *hists) {
    int rmax=0, gmax=0, bmax=0;
    channel r=0, g=0, b=0;
    
    for (int i=0; i<=Z; i++) {
        if (hists->rh[i] > rmax) {
            r = i;
            rmax = hists->rh[i];
        }
        if (hists->gh[i] > gmax) {
            g = i;
            gmax = hists->gh[i];
        }
        if (hists->bh[i] > bmax) {
            b = i;
            bmax = hists->bh[i];
        }
    }
    return SETRGB(r,g,b);
}

- (void) addTestTransforms {
    lastTransform = [Transform areaTransform: @"Kaleidoscope"
                                 description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
        long maxR = MIN(remapBuf.w, remapBuf.h)/2.0;
        float theta = M_2_PI/(float)instance.value; // angle of one sector
        float halfTheta = theta/2.0;
        
        // the incoming circle of pixels is divided into sectors. The original
        // data is in the top half of the half sector at theta >= 0.  That live sector
        // is mirrored on the half sector below theta = 0. Through the wonders of
        // modular arithmetic, the original pixels are mapped, mirrored or not
        // mirrored, to all the other pixels.
        
        // we fix out the remap ())or color) for each pixel
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<remapBuf.w; x++) {
                float xc = x - centerX;
                float yc = y - centerY;
                float r = hypot(xc, yc);
                if (r > maxR || r == 0) {
                    REMAP_COLOR(x, y, Remap_White);
                    continue;
                }
                float a = atan2f(yc, xc);
                float sourceSectorTheta = fmod((a + halfTheta), theta) - halfTheta;
                float sourceTheta = fabs(sourceSectorTheta);
                int xs = centerX + cos(sourceTheta)*a;
                int ys = centerY + sin(sourceTheta)*a;
                UNSAFE_REMAP_TO(x, y, xs, ys);
            }
        }
        UNSAFE_REMAP_TO(centerX, centerY, centerX, centerY);    // fix the center
    }];
    lastTransform.low = 2;
    lastTransform.value = 5;
    lastTransform.high = 15;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    /* timings for oil on digitalis:
     *
     *                  Z    param    f/s
     * original oil     31    3    ~7.0
     *
     * original oil     255    3    1.2
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
    lastTransform = [Transform areaTransform: @"Oil paint"
                                 description: @""
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        int x, y;
        int oilD = 1 << instance.value; // powers of two
        Hist_t hists;

        long W = src.w;
        long H = src.h;

        // set the border
        for (y=0; y<H; y++) {
            for (x=0; x<oilD; x++) {
                dest.pa[y][x] = dest.pa[y][W - x - 1] = White;
            }
            if (y < oilD || y > H - oilD)
                for (int x=0; x < W; x++)
                    dest.pa[y][x] = White;
        }
        
        x = y = oilD;   // start in the upper left corner
        BOOL goingRight = YES;
        memset(&hists, 0, sizeof(hists));   // clear the histograms
        setHistAround(src.pa, x, y, oilD, &hists);
        do {
            dest.pa[y][x] = mostCommonColorInHist(&hists);
            if (goingRight) {
                if (x + oilD - 1 < W) {
                    x++;
                    moveHistRight(src.pa, x, y, oilD, &hists);
                } else {
                    // go down one pixel and change directions
                    y++;
                    if (y + oilD == H)
                        break;  // hit the bottom
                    goingRight = NO;
                    moveHistDown(src.pa, x, y, oilD, &hists);
                }
            } else {    // going left
                if (x > oilD) {
                    x--;
                    moveHistLeft(src.pa, x, y, oilD, &hists);
                } else {
                    y++;
                    if (y + oilD == H)
                        break;  // hit the bottom
                    moveHistDown(src.pa, x, y, oilD, &hists);
                    goingRight = YES;
                }}
        } while (1);

#ifdef SIMPLEST
        // simplest loop: compute and analyze the full histogram around each point.
        // speeds for oilD:
        // 0    4.3
        // 1    4.8
        // 2    6.264
        // 3    11.6
        // 4    31.9
        for (y=oilD; y<H-oilD; y++) {
            for (x=oilD; x<W-oilD; x++) {
                memset(&hists, 0, sizeof(hists));   // clear the histograms
                setHistAround(src.pa, x, y, oilD, &hists);
                dest.pa[y][x] = mostCommonColorAround(src.pa, x, y, oilD, &hists);
            }
        }
#endif
    }];
    lastTransform.low = 1;      // 2^1
    lastTransform.value = 2;    // 2^2.  2^3 is MUCH shower
    lastTransform.high = 4;     // 2^4
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Charcoal sketch"
                                 description: @""
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        // monochrome sobel...
        long N = src.w * src.h;
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = LUM(src.pb[i]);
        }
        // gerard's sobol, which is right
        sobel(chBuf0, chBuf1);

        // ... negate and high contrast...
        // ... + negative + high contrast...
        
        for (int i=0; i<N; i++) {
            channel c = chBuf1.cb[i];
            channel nc = Z - CLIP((c-HALF_Z)*2+HALF_Z);
            Pixel p = SETRGB(nc, nc, nc);
            dest.pb[i] = p;
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Mono Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long W = src.w;
        long H = src.h;
        for (int i=0; i<src.h*src.w; i++) {
            chBuf0.cb[i] = LUM(src.pb[i]);
        }
        // gerard's sobol, which is right
        sobel(chBuf0, chBuf1);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel d = chBuf1.ca[y][x];
                dest.pa[y][x] = SETRGB(d,d,d);
            }
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Negative Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long W = src.w;
        long H = src.h;
        long N = W * H;
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = LUM(src.pb[i]);
        }
        // gerard's sobol, which is right
        sobel(chBuf0, chBuf1);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel d = Z - chBuf1.ca[y][x];
                dest.pa[y][x] = SETRGB(d,d,d);
            }
        }
    }];
    [self addTransform:lastTransform];
    
    // channel-based
    lastTransform = [Transform areaTransform: @"Color Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long N = src.w * src.h;
        for (int i=0; i<N; i++) { // do the red channel
            chBuf0.cb[i] = src.pb[i].r;
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) {
            dest.pb[i] = SETRGB(chBuf1.cb[i], 0, 0);    // init target, including 'a' channel
            chBuf0.cb[i] = src.pb[i].g;     // ... and get green
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dest.pb[i].g = chBuf1.cb[i];     // store green...
            chBuf0.cb[i] = src.pb[i].b;     // ... and get blue
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dest.pb[i].b = chBuf1.cb[i];     // store blue
        }
    }];
    [self addTransform:lastTransform];
    
    // channel-based
    lastTransform = [Transform areaTransform: @"Negative Color Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long N = src.w * src.h;
        for (int i=0; i<N; i++) { // do the red channel
            chBuf0.cb[i] = src.pb[i].r;
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) {
            dest.pb[i] = SETRGB(Z - chBuf1.cb[i], 0, 0);    // init target, including 'a' channel
            chBuf0.cb[i] = src.pb[i].g;     // ... and get green
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dest.pb[i].g = Z - chBuf1.cb[i];     // store green...
            chBuf0.cb[i] = src.pb[i].b;     // ... and get blue
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dest.pb[i].b = Z - chBuf1.cb[i];     // store blue
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"convolution sobel filter "
                                description: @"Edge detection"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {

        for (int i=0; i<src.h*src.w; i++) {
            chBuf0.cb[i] = LUM(src.pb[i]);
        }
        const float Gx[] = {-1, 0, 1,
                            -2, 0, 2,
                            -1, 0, 1};
        convolution(chBuf0, chBuf1, Gx, 3, NO);
     
        const float Gy[] = { 1, 2, 1,
                             0, 0, 0,
                            -1,-2,-1};
        convolution(chBuf1, chBuf0, Gy, 3, NO);
        
        for (int i=0; i<src.h*src.w; i++) {
            int c = chBuf0.cb[i];
            dest.pb[i] = SETRGB(c,c,c);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Focus"
                                  description: @""
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long W = src.w;
        long H = src.h;
        long N = W * H;
        for (int i=0; i<N; i++) {           // red
            chBuf0.cb[i] = src.pb[i].r;
        }
        focus(chBuf0, chBuf1);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dest.pa[y][x] = SETRGB(chBuf1.ca[y][x], 0, 0);    // init target, including 'a' channel
            }
        }
        for (int i=0; i<N; i++) {           // green
            chBuf0.cb[i] = src.pb[i].g;
        }
        focus(chBuf0, chBuf1);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dest.pa[y][x].g = chBuf1.ca[y][x];
            }
        }
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = src.pb[i].b;
        }
        focus(chBuf0, chBuf1);              // blue
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dest.pa[y][x].b = chBuf1.ca[y][x];
            }
        }
    }];
    [self addTransform:lastTransform];

#ifdef NOTDEF
    lastTransform = [Transform areaTransform: @"Null test"
                                  description: @""
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long W = src.w;
        long H = src.h;
//        long N = W * H;
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel r = src.pa[y][x].r;
                channel g = src.pa[y][x].g;
                channel b = src.pa[y][x].b;
                dest.pa[y][x].r = r;
                dest.pa[y][x].g = g;
                dest.pa[y][x].b = b;
                dest.pa[y][x].a = Z;
            }
        }
    }];
    [self addTransform:lastTransform];
#endif
}

- (void) addTransform:(Transform *)transform {
    transform.arrayIndex = transforms.count;
    [transforms addObject:transform];
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

    lastTransform = [Transform areaTransform: @"Edvard Munch #1"        // old twist right
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
    
    lastTransform = [Transform areaTransform: @"Edvard Munch #2"    // old Ken twist
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
        assert(remapBuf.w > 0 && remapBuf.h > 0);
        long centerX = remapBuf.w/2;
        long centerY = remapBuf.h/2;
//        NSLog(@" kite %zu x %zu", remapBuf.w, remapBuf.h);
        for (int y=0; y<remapBuf.h; y++) {
            size_t ndots;
            
            if (y <= centerY)
                ndots = (y*(remapBuf.w-1))/remapBuf.h;
            else
                ndots = ((remapBuf.h-y-1)*(remapBuf.w))/remapBuf.h;
            
//            NSLog(@" kite %d, %zu", y, ndots);

            assert(y>= 0 && y < remapBuf.h);
            REMAP_TO(centerX,y, centerX, y);
            REMAP_TO(centerX,y, centerX, y);
            REMAP_COLOR(0,y, Remap_White);
            
            for (int x=1; x<=ndots; x++) {
                size_t dist = (x*(centerX-1))/ndots;
                assert(centerX - dist >= 0 && centerX - dist < remapBuf.w);
                assert(centerX + dist >= 0 && centerX + dist < remapBuf.w);
                REMAP_TO(centerX+x,y, centerX + dist,y);
                REMAP_TO(centerX-x,y, centerX - dist,y);
            }
            for (size_t x=ndots; x<centerX; x++) {
                assert(centerX - x >= 0 && centerX - x < remapBuf.w);
                assert(centerX + x >= 0 && centerX + x < remapBuf.w);
                REMAP_COLOR(centerX+x,y, Remap_White);
                REMAP_COLOR(centerX-x,y, Remap_White);
             }
//            NSLog(@" kite %d done", y);
        }
//        NSLog(@" kite verifying");
        [remapBuf verify];
//        NSLog(@" kite Z");
    }];
    [self addTransform:lastTransform];
//    NSLog(@" post kite");

    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @""
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        size_t h = src.h;
        size_t w = src.w;
#define L chBuf0.ca
        assert(chBuf0.w == w && chBuf0.h == h);
        for (int y=1; y<h-1; y++)
            for (int x=1; x<w-1; x++)
                L[y][x] = LUM(src.pa[y][x]);

        for (int y=1; y<h-1; y++) {
            for (int x=1; x<w-1; x++) {
                channel aa, bb, s;
                aa = L[y-1][x-1] + 2*L[y-1][x] + L[y-1][x+1] -
                    L[y+1][x-1] - 2*L[y+1][x] - L[y+1][x+1];
                bb = L[y-1][x-1] + 2*L[y][x-1] + L[y+1][x-1] -
                    L[y-1][x+1] - 2*L[y][x+1] - L[y+1][x+1];

                channel c;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    c = Z;
                else
                    c = s;
                dest.pa[y][x] = SETRGB(c,c,c);
            }
        }
    }];
    [self addTransform:lastTransform];
    
    // this destroys src
    lastTransform = [Transform areaTransform: @"Old AT&T logo"
                                 description: @"Tom Duff's logo transform"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        size_t h = src.h;
        size_t w = src.w;
        for (int y=0; y<h; y++) {
            for (int x=0; x<w; x++) {
                channel c = LUM(src.pa[y][x]);
                src.pa[y][x] = SETRGB(c,c,c);
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
                c += src.pa[y+y0][x].r;
                y0 = y+(hgt-1)/2;
                y1 = y+(hgt-1-(hgt-1)/2);
                for (; y0 >= y; --y0, ++y1)
                c = stripe(src.pa, x, y0, y1, c);
            }
        }
        
        for (int y=0; y<h; y++) {
            for (int x=0; x<w; x++) {
                channel c = src.pa[y][x].r;
                dest.pa[y][x] = SETRGB(c, c, c);
            }
        }
    }];
    lastTransform.value = 12; lastTransform.low = 4; lastTransform.high = 50;
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];
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

    lastTransform = [Transform areaTransform: @"Through a cylinder"
                                  description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long centerX = remapBuf.w/2;
        for (int y=0; y<remapBuf.h; y++) {
            for (int x=0; x<=centerX; x++) {
                int fromX = centerX*sin((M_PI/2.0)*x/centerX);
                assert(fromX >= 0 && fromX < remapBuf.w);
                REMAP_TO(x,y, fromX, y);
                REMAP_TO(remapBuf.w-1-x,y, remapBuf.w-1-fromX, y);
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Tin Type"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *src, PixBuf *dest,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        Pixel p = {0,0,0,Z};
        size_t h = src.h;
        size_t w = src.w;

        for (int y=0; y<h; y++) {
            int x;
            for (x=0; x<w-2; x++) {
                Pixel pin;
                int r, g, b;
                long xin = (x+2) >= w ? w - 1 : x+2;
                long yin = (y+2) >= h ? h - 1 : y+2;
                pin = src.pa[yin][xin];
                r = src.pa[y][x].r + Z/2 - pin.r;
                g = src.pa[y][x].g + Z/2 - pin.g;
                b = src.pa[y][x].b + Z/2 - pin.b;
                p.r = CLIP(r);  p.g = CLIP(g);  p.b = CLIP(b);
                dest.pa[y][x] = p;
            }
            dest.pa[y][x-3] = Grey;
            dest.pa[y][x-2] = Grey;
            dest.pa[y][x-1] = Grey;
            dest.pa[y][x  ] = Grey;
            dest.pa[y][x+1] = Grey;
        }
    }];
    [self addTransform:lastTransform];
}


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

int
irand(int i) {
    return random() % i;
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
        
        // XXX we really should just compute one block, and point all the necessary
        // pixels to it.  The speed-up will be terrific.
        
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
    
}

@end
