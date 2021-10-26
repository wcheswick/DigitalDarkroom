//
//  Transforms.m
//  DigitalDarkroom
//
//  Created by ches on 9/16/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

// color effect filters from apple:
// https://developer.apple.com/documentation/coreimage/methods_and_protocols_for_filter_creation/color_effect_filters?language=objc

#include <sys/types.h>
#include <sys/sysctl.h>

#import "Transforms.h"
#import "RemapBuf.h"
#import "Defines.h"

//#define DEBUG_TRANSFORMS    1   // bounds checking and a lot of assertions
#define SHOW_GRID   1             // 1 in marks to check display dpu

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

// From https://stackoverflow.com/questions/3018313/algorithm-to-convert-rgb-to-hsv-and-hsv-to-rgb-in-range-0-255-for-both

static
Pixel HSVtoRGB(HSVPixel hsv) {
    Pixel rgb;
    unsigned char region, remainder, p, q, t;

    rgb.a = hsv.a;

    if (hsv.s == 0) {
        rgb.r = hsv.v;
        rgb.g = hsv.v;
        rgb.b = hsv.v;
        return rgb;
    }

    region = hsv.h / 43;
    remainder = (hsv.h - (region * 43)) * 6;

    p = (hsv.v * (Z - hsv.s)) >> 8;
    q = (hsv.v * (Z - ((hsv.s * remainder) >> 8))) >> 8;
    t = (hsv.v * (Z - ((hsv.s * (Z - remainder)) >> 8))) >> 8;

    switch (region) {
        case 0:
            rgb.r = hsv.v; rgb.g = t; rgb.b = p;
            break;
        case 1:
            rgb.r = q; rgb.g = hsv.v; rgb.b = p;
            break;
        case 2:
            rgb.r = p; rgb.g = hsv.v; rgb.b = t;
            break;
        case 3:
            rgb.r = p; rgb.g = q; rgb.b = hsv.v;
            break;
        case 4:
            rgb.r = t; rgb.g = p; rgb.b = hsv.v;
            break;
        default:
            rgb.r = hsv.v; rgb.g = p; rgb.b = q;
            break;
    }
    return rgb;
}

static
HSVPixel RGBtoHSV(Pixel rgb) {
    HSVPixel hsv;
    long rgbMin = MIN(MIN(rgb.r,rgb.g), rgb.b);
    long rgbMax = MAX(MAX(rgb.r,rgb.g), rgb.b);

    hsv.a = rgb.a;
    hsv.v = rgbMax;
    if (hsv.v == 0) {
        hsv.h = 0;
        hsv.s = 0;
        return hsv;
    }

    hsv.s = Z * (rgbMax - rgbMin) / hsv.v;
    if (hsv.s == 0) {
        hsv.h = 0;
        return hsv;
    }
    assert(rgbMax != rgbMin);
    if (rgbMax == rgb.r)
        hsv.h = 0 + 43 * (rgb.g - rgb.b) / (rgbMax - rgbMin);
    else if (rgbMax == rgb.g)
        hsv.h = 85 + 43 * (rgb.b - rgb.r) / (rgbMax - rgbMin);
    else
        hsv.h = 171 + 43 * (rgb.r - rgb.g) / (rgbMax - rgbMin);
    return hsv;
}

static float screenScale;
static int dpi;


@interface Transforms ()

@property (strong, nonatomic)   Transform *lastTransform;
@property (strong, nonatomic)   NSString *helpPath;

@end

@implementation Transforms

@synthesize lastTransform;
@synthesize helpPath;
@synthesize debugTransforms;
@synthesize transforms;

- (id)init {
    self = [super init];
    if (self) {
#ifdef OLD
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
            screenScale = [[UIScreen mainScreen] scale];
        } else
            screenScale = 1.0;
#endif

        CGRect bounds = [[UIScreen mainScreen] bounds];
        CGRect nativeBounds = [[UIScreen mainScreen] nativeBounds];
        float nativeScale = [[UIScreen mainScreen] nativeScale];
        NSLog(@"TTTT screen scale is %.1f, DPI: %.0d",
              screenScale, dpi);
        NSLog(@"         bounds: %.0f, %.0f",
              bounds.size.width, bounds.size.height);
        NSLog(@"    native size: %.0f, %.0f",
              nativeBounds.size.width, nativeBounds.size.height);
        NSLog(@"   native scale: %.0f", nativeScale);
        NSString *model = [UIDevice currentDevice].model;
        NSLog(@"          model: %@", model);

        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        NSString *platform = [NSString stringWithUTF8String:machine];
        free(machine);
        NSLog(@"       platform: %@", platform);

        // iPhone 12 Max - 6.1-inch, 2532 x 1170 OLED display, 460 ppi.
        // iPhone 12 Pro - 6.1-inch, 2532 x 1170 OLED Display, 460 ppi.
        // iPhone 12 Pro Max - 6.7-inch, 2778 x 1284 OLED Display, 458 ppi.
        
        // see https://everyi.com/by-identifier/ipod-iphone-ipad-specs-by-model-identifier.html
        
        int ppi;
        if ([platform isEqual:@"iPad8,7"]) // ipad pro 12.9 in 3rd gen
            ppi = 264;
        else if ([model isEqual:@"iPad5,4"]) // ipad air 2
            ppi = 264;
        else if ([model isEqual:@"iPad7,3"]) // ipad pro 10.5 inch
            ppi = 264;
        else if ([model hasPrefix:@"iPad8"]) // generic ipad
            ppi = 265;
        else if ([platform isEqual:@"iPhone13,4"]) // iphone pro max
            ppi = 458;
        else if ([platform isEqual:@"iPhone10,6"]) // iphone X
            ppi = 458;
        else if ([model hasPrefix:@"iPhoneX"]) // generic ipad
             ppi = 458;
       else if ([model hasPrefix:@"iPhone13"]) // generic ipad
            ppi = 459;
        else if ([model hasPrefix:@"iPhone"]) // generic ipad
            ppi = 459;
        else if ([model hasPrefix:@"iPad"]) // generic ipad
            ppi = 240*nativeScale;
        else if ([model hasPrefix:@"iPad"]) // generic ipad
             ppi = 266;
        else    // generic iPhone
            ppi = 240*nativeScale;

        dpi = ppi / nativeScale;
        NSLog(@"       ppi: %d", ppi);
        NSLog(@"       dpi: %d", dpi);

#ifdef DEBUG_TRANSFORMS
        debugTransforms = YES;
#else
        debugTransforms = NO;
#endif
        transforms = [[NSMutableArray alloc] init];
        [self buildTransformList];
    }
    return self;
}

- (void) addTransform:(Transform *)transform {
    transform.transformsArrayIndex = transforms.count;
    if (!helpPath)
        transform.helpPath = transform.name;
    else {
        transform.helpPath = [helpPath stringByAppendingPathComponent:transform.name];
    }
    [transforms addObject:transform];
}

- (void) buildTransformList {
    helpPath = @"Test";
    [self addTestTransforms];
    
    helpPath = @"Depth";
    [self addDepthVisualizations];

    helpPath = @"Remap";
    [self addGeometricTransforms];
    
    helpPath = @"Polar remap";
    [self addPolarTransforms];

    helpPath = @"Convolutions";
    [self addConvolutions];

    helpPath = @"Area";
    [self addAreaTransforms];

    helpPath = @"Point";
    [self addPointTransforms];
    
    helpPath = @"Art";
    [self addArtTransforms];
    
    helpPath = @"Bugs";
    [self addBugTransforms];
}

// transform at given index, or nil if NO_TRANSFORM

- (Transform * __nullable) transformAtIndex:(long) index {
    if (index == NO_TRANSFORM)
        return nil;
    return [transforms objectAtIndex:index];
}

// if normalize is true, map channels to range 0..MAX_BRIGHTNESS

void
channelConvolution(ChBuf *in, ChBuf *out,
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

#define KERNEL_SIZE(kernel)   (sizeof(kernel)/sizeof(float))

// kernel is a kn x kn matrix
void
pixelConvolution(PixBuf *in, PixBuf *out,
                 const float *kernel, const int kernel_size, const BOOL normalize) {
    int kn = round(sqrt(kernel_size));
    long W = in.size.width;
    long H = in.size.height;
    assert(kn % 2 == 1);    // kernels must have an odd number of rows and columns
    assert(W > kn && H > kn);   // width must be larger than the kernel
    const int khalf = kn / 2;
    
    int normalizer; // if normalized, the sum of the kernel entries, for consistent brightness
    if (normalize) {
        normalizer = 0;
        for (int i=0; i<kn*kn; i++)
            normalizer += kernel[i];
        assert(normalizer); // no divide by zero
    } else
        normalizer = 1;
    
#ifdef WRONG
    float min = FLT_MAX, max = -FLT_MAX;
    
    if (normalize) {
        for (int x = khalf; x < W - khalf; x++) {
            for (int y = khalf; y < H - khalf; y++) {
                float rchan = 0.0;
                float gchan = 0.0;
                float bchan = 0.0;
                size_t kernelIndex = 0;
                for (int j = -khalf; j <= khalf; j++) {
                    for (int i = -khalf; i <= khalf; i++) {
                        rchan += in.pa[y+j][x+i].r * kernel[kernelIndex];
                        gchan += in.pa[y+j][x+i].g * kernel[kernelIndex];
                        bchan += in.pa[y+j][x+i].b * kernel[kernelIndex];
                        kernelIndex++;
                    }
                }
                min = MIN(min, rchan);
                min = MIN(min, gchan);
                min = MIN(min, bchan);
                max = MAX(min, rchan);
                max = MAX(min, gchan);
                max = MAX(min, bchan);
           }
        }
    }
#endif
    
    for (int x = khalf; x < W - khalf; x++) {
        for (int y = khalf; y < H - khalf; y++) {
            float rchan = 0.0;
            float gchan = 0.0;
            float bchan = 0.0;
            size_t kernelIndex = 0;
            for (int j = -khalf; j <= khalf; j++)
                for (int i = -khalf; i <= khalf; i++) {
                    rchan += in.pa[y+j][x+i].r * kernel[kernelIndex]/normalizer;
                    gchan += in.pa[y+j][x+i].g * kernel[kernelIndex]/normalizer;
                    bchan += in.pa[y+j][x+i].b * kernel[kernelIndex]/normalizer;
                    kernelIndex++;
                }
#ifdef WRONG
            if (normalize) {
                rchan = Z * (rchan - min) / (max - min);
                gchan = Z * (gchan - min) / (max - min);
                bchan = Z * (bchan - min) / (max - min);
            }
#endif
            out.pa[y][x] = SETRGB(rchan, gchan, bchan);
        }
    }
}

// sobel kernel derived from Gerard's original code
void
sobel(ChBuf *s, ChBuf *d) {
    long H = s.h;
    long W = s.w;
    for (int y=1; y<H-1-1; y++) {
        for (int x=1; x<W-1-1; x++) {
            int aa, bb;
            aa = s.ca[y-1][x-1] + s.ca[y][x-1]*2 + s.ca[y+1][x-1] -
                s.ca[y-1][x+1] - s.ca[y][x+1]*2 - s.ca[y+1][x+1];
            bb = s.ca[y-1][x-1] + s.ca[y-1][x]*2 + s.ca[y-1][x+1] -
                s.ca[y+1][x-1] - s.ca[y+1][x]*2 - s.ca[y+1][x+1];
            int diff = sqrt(aa*aa + bb*bb);
            if (diff > Z)
                d.ca[y][x] = Z;
            else
                d.ca[y][x] = diff;
        }
    }
}

// Gerard's original focus kernel
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

// Gerard's histogram code for oil paint
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

// convert double hypens to soft hyphen
- (NSString *) hyphenate:(NSString *) s {
    return [s stringByReplacingOccurrencesOfString:@"--" withString:SHY];
}

- (void) addTestTransforms {
    lastTransform = [Transform depthVis: @"Depth errors"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf,
                                           PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        // not: the depthbuf may be a different size
        //assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        for (int i=0; i<W * H; i++) {
            Distance z = depthBuf.db[i];
            Pixel p;
            if (z == NAN_DEPTH)
                p = Red;
            else if (z == ZERO_DEPTH)
                p = Orange;
            else if (z == 0.0)
                p = Yellow;
            else if (z > depthBuf.maxDepth)
                p = Magenta;
            else if (z < depthBuf.minDepth)
                p = Cyan;
            else if (z == depthBuf.maxDepth)
                p = Black;
            else if (z == depthBuf.minDepth)
                p = White;
            else {
                float frac = z/depthBuf.maxDepth;
                float h = 0.3333 + 0.333*frac;
                p = HSVtoRGB((HSVPixel){h,1.0,0.5});
            }
            dstPixBuf.pb[i] = p;
        }
    }];
    lastTransform.hasParameters = NO;
    [self addTransform:lastTransform];

    lastTransform = [Transform depthVis: @"HSV test"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        for (int i=0; i<srcPixBuf.size.width*srcPixBuf.size.height; i++) {
            Pixel p = srcPixBuf.pb[i];
            HSVPixel hsv = RGBtoHSV(p);
//            Distance z = depthBuf.db[i];
            dstPixBuf.pb[i] = HSVtoRGB(hsv);
        }
    }];
    [self addTransform:lastTransform];
}

- (void) addPolarTransforms {
#ifdef TEST
    lastTransform = [Transform areaTransform: @"Flat polar test"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
        long sx = centerX + r*cos(a);
        long sy = centerY + r*sin(a);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_Yellow);
    }];
    [self addTransform:lastTransform];
#endif
    
   lastTransform = [Transform areaTransform: @"Rotate"        // old twist right
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        double newa = a + DEGRAD((float)instance.value);
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
        long sx = centerX + r*cos(newa);
        long sy = centerY + r*sin(newa);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    lastTransform.low = -180;
    lastTransform.value = 45;
    lastTransform.high = 180;    // was 15
    lastTransform.paramName = @"Angle";
    lastTransform.hasParameters = YES;
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Twist"        // old twist right
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        double newa = a + ((float)instance.value/50.0)*r*(M_PI/180.0);
//        double newa = a + DEGRAD((float)instance.value/100.0)((float)instance.value/100.0)*r*(M_PI/180.0);
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
        long sx = centerX + r*cos(newa);
        long sy = centerY + r*sin(newa);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    lastTransform.low = -360;
    lastTransform.value = 50;
    lastTransform.high = 360;    // was 15
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Angle";
    [self addTransform:lastTransform];
    
#ifdef BROKEN
    // Now this one:  $1[x + (r*cos(a))/F, y + (r-sin(a)*sin(a))/F]
    // (with F=10000)  is cool!  See attached.
    
    lastTransform = [Transform areaTransform: @"Daisy"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        float F = 10000.0;
        long sx = tX + (r*cos(a))/F;
        long sy = tY + (r-sin(a)*sin(a))/F;
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    lastTransform.low = 1;
    lastTransform.value = 10;
    lastTransform.high = 90;    // was 15
    lastTransform.paramName = @"Angle";
    lastTransform.hasParameters = NO;
    [self addTransform:lastTransform];
#endif

    lastTransform = [Transform areaTransform: @"Fish eye"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a,
                                               TransformInstance *instance, int tX, int tY) {
        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        double R = hypot(W, H);
        float zoomFactor = instance.value/10.0; // XXXX this is broken, I think
        double r1 = r*r/(R/zoomFactor);
        int x = (int)W/2 + (int)(r1*cos(a));
        int y = (int)H/2 + (int)(r1*sin(a));
        REMAP_TO(tX, tY, x, y);
    }];
    lastTransform.low = 10; // XXXXXX these are bogus
    lastTransform.value = 20;
    lastTransform.high = 30;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Zoom in?";  // broken: zoom not so hot
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Cone projection"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        float maxR = MIN(centerX, centerY);
        double r1 = sqrt(r*maxR);
        long sx = centerX + (int)(r1*cos(a));
        long sy = centerY + (int)(r1*sin(a));
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: [self hyphenate:@"Kaleido--scope"]
                                 description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        float maxR = MIN(W-1, H-1)/2.0;
        float theta = 2.0*M_PI/(float)instance.value; // angle of one sector
        float halfTheta = theta/2.0;
        
        // the incoming circle of pixels is divided into sectors. The original
        // data is in the top half of the half sector at theta >= 0.  That live sector
        // is mirrored on the half sector below theta = 0. Through the wonders of
        // modular arithmetic, the original pixels are mapped, mirrored or not
        // mirrored, to all the other pixels.
        
        // we fix out the remap ())or color) for each pixel
        for (int yi=0; yi<H; yi++) {
            // for computation, it is easier to thing of the top of the image
            // as y > 0.
            int y = ((int)H - yi) - 1;
            for (int x=0; x<W; x++) {
                float xc = x - centerX;
                // we use standard cartesian angles, with y==0 on the bottom
                float yc = y - centerY;
                float r = hypot(xc, yc) / 2.0;
                if (r > maxR || r == 0) {
                    REMAP_COLOR(x, y, Remap_White);
                    continue;
                }
#define RADEG(a)    ((a)* 180.0 / M_PI)     // for debugging
                float a = atan2f(yc, xc);
                a = fmod(a + 2.0*M_PI, 2*M_PI);     // 0 <= a <= 2*M_PI
                //assert(a >= 0.0 && a < 2*M_PI);
                float sourceSectorTheta = fmod((a + halfTheta), theta) - halfTheta;
                assert(sourceSectorTheta <= halfTheta && sourceSectorTheta >= -halfTheta);
                float sourceTheta = fabs(sourceSectorTheta) - M_PI;
//                assert(sourceTheta >= 0.0 && sourceTheta <= halfTheta);
                int scx = r * cos(sourceTheta);
                int scy = r * sin(sourceTheta);
                long xs = centerX + scx;
                long ys = centerY + scy;
                UNSAFE_REMAP_TO(x, yi, xs, ys);
            }
        }
        UNSAFE_REMAP_TO(centerX, centerY, centerX, centerY);    // fix the center
    }];
    lastTransform.low = 1;
    lastTransform.value = 5;
    lastTransform.high = 12;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Mirror count";
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Skrunch"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        // I am not sure this matches the original, or that the original didn't
        // have a bug:
        //    return frame[CENTER_Y+(short)(r*cos(a))]
        //            [CENTER_X+(short)((r-(sin(a))/300)*sin(a))];

        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        long sx = centerX + (r-(cos(a)/300.0)*sin(a));
        long sy = centerY + r*sin(a);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Andrew"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        int sx = centerX + 0.6*((r - sin(a)*100 + 50) * cos(a));
        int sy = centerY + 0.6*r*sin(a); // - (CENTER_Y/4);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_TO(tX, tY, centerX + r*cos(a), centerX + r*sin(a));
    }];
    [self addTransform:lastTransform];

#ifdef BROKEN
    lastTransform = [Transform areaTransform: @"Paul"
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        double x = r*cos(a);
        double y = r*sin(a);
        long sx = centerX + r*sin((y*x)/4.0+a);
        long sy = centerY + r*cos(a);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
//    lastTransform.broken = YES;
    [self addTransform:lastTransform];
#endif
    
    lastTransform = [Transform areaTransform: @"Can"    // WTF?
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        // I am not sure this matches the original, or that the original didn't
        // have a bug:
        //    return frame[CENTER_Y+(short)(r*cos(a))]
        //            [CENTER_X+(short)((r-(sin(a))/300)*sin(a))];
        //
        // or
        //          return frame[CENTER_Y+(short)(r*5/2)][CENTER_X+(short)(a*5/2)];

        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        float p = instance.value/10.0;
        long sx = centerX + a*p;
        long sy = centerY + r*p;
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    lastTransform.low = 4;
    lastTransform.value = 8;
    lastTransform.high = 16;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Angle mult.";
    [self addTransform:lastTransform];
    
#ifdef DEFINITELY_NOT
    lastTransform = [Transform areaTransform: @"Can 2"    // WTF?
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        // I am not sure this matches the original, or that the original didn't
        // have a bug:
        //    return frame[CENTER_Y+(short)(r*cos(a))]
        //            [CENTER_X+(short)((r-(sin(a))/300)*sin(a))];
        //
        // or
        //          return frame[CENTER_Y+(short)(r*5/2)][CENTER_X+(short)(a*5/2)];

        float p = instance.value/10.0;
        float W = remapBuf.size.width;
        float H = remapBuf.size.height;
        long centerX = W/2;
        long centerY = H/2;
        long sx = centerX + ((r - sin(a))/300.0)*sin(a);
        long sy = centerY + cos(a);
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    lastTransform.low = 4;
    lastTransform.value = 8;
    lastTransform.high = 16;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Angle mult.";
    [self addTransform:lastTransform];
#endif
    
#ifdef NOTDEF
    lastTransform = [Transform areaTransform: @"Null test"
                                  description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long W = srcFrame.pixBuf.w;
        long H = srcFrame.pixBuf.h;
//        long N = W * H;
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                channel r = srcFrame.pixBuf.pa[y][x].r;
                channel g = srcFrame.pixBuf.pa[y][x].g;
                channel b = srcFrame.pixBuf.pa[y][x].b;
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

- (void) addConvolutions {
    lastTransform = [Transform areaTransform: @"Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        for (int i=0; i<srcPixBuf.size.height*srcPixBuf.size.width; i++) {
            chBuf0.cb[i] = LUM(srcPixBuf.pb[i]);
        }
        // gerard's sobol, which is right
        sobel(chBuf0, chBuf1);
        for (int y=0; y<srcPixBuf.size.height; y++) {
            for (int x=0; x<srcPixBuf.size.width; x++) {
                channel d = chBuf1.ca[y][x];
                dstPixBuf.pa[y][x] = SETRGB(d,d,d);
            }
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Neg. Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        for (int i=0; i<srcPixBuf.size.height*srcPixBuf.size.width; i++) {
            chBuf0.cb[i] = LUM(srcPixBuf.pb[i]);
        }
        // gerard's sobol, which is right
        sobel(chBuf0, chBuf1);
        for (int y=0; y<srcPixBuf.size.height; y++) {
            for (int x=0; x<srcPixBuf.size.width; x++) {
                channel d = Z - chBuf1.ca[y][x];
                dstPixBuf.pa[y][x] = SETRGB(d,d,d);
            }
        }
    }];
    [self addTransform:lastTransform];
    
    // channel-based
    lastTransform = [Transform areaTransform: @"Color\nSobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) { // do the red channel
            chBuf0.cb[i] = srcPixBuf.pb[i].r;
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) {
            dstPixBuf.pb[i] = SETRGB(chBuf1.cb[i], 0, 0);    // init target, including 'a' channel
            chBuf0.cb[i] = srcPixBuf.pb[i].g;     // ... and get green
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dstPixBuf.pb[i].g = chBuf1.cb[i];     // store green...
            chBuf0.cb[i] = srcPixBuf.pb[i].b;     // ... and get blue
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dstPixBuf.pb[i].b = chBuf1.cb[i];     // store blue
        }
    }];
    [self addTransform:lastTransform];
    
    // channel-based
    lastTransform = [Transform areaTransform: @"Neg. Color Sobel"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) { // do the red channel
            chBuf0.cb[i] = srcPixBuf.pb[i].r;
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) {
            dstPixBuf.pb[i] = SETRGB(Z - chBuf1.cb[i], 0, 0);    // init target, including 'a' channel
            chBuf0.cb[i] = srcPixBuf.pb[i].g;     // ... and get green
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dstPixBuf.pb[i].g = Z - chBuf1.cb[i];     // store green...
            chBuf0.cb[i] = srcPixBuf.pb[i].b;     // ... and get blue
        }
        sobel(chBuf0, chBuf1);
        for (int i=0; i<N; i++) { // do the red channel
            dstPixBuf.pb[i].b = Z - chBuf1.cb[i];     // store blue
        }
    }];
    [self addTransform:lastTransform];
    
#ifdef SLOW
    lastTransform = [Transform areaTransform: @"conv. sobel filter "
                                description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = LUM(srcPixBuf.pb[i]);
        }
        const float Gx[] = {-1, 0, 1,
                            -2, 0, 2,
                            -1, 0, 1};
        convolution(chBuf0, chBuf1, Gx, 3, NO);
     
        const float Gy[] = { 1, 2, 1,
                             0, 0, 0,
                            -1,-2,-1};
        convolution(chBuf1, chBuf0, Gy, 3, NO);
        
        for (int i=0; i<N; i++) {
            int c = chBuf0.cb[i];
            dstPixBuf.pb[i] = SETRGB(c,c,c);
        }
    }];
    [self addTransform:lastTransform];
#endif

    lastTransform = [Transform areaTransform: @"Focus"
                                  description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long W = srcPixBuf.size.width;
        long H = srcPixBuf.size.height;
        long N = W * H;
        for (int i=0; i<N; i++) {           // red
            chBuf0.cb[i] = srcPixBuf.pb[i].r;
        }
        focus(chBuf0, chBuf1);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstPixBuf.pa[y][x] = SETRGB(chBuf1.ca[y][x], 0, 0);    // init target, including 'a' channel
            }
        }
        for (int i=0; i<N; i++) {           // green
            chBuf0.cb[i] = srcPixBuf.pb[i].g;
        }
        focus(chBuf0, chBuf1);
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstPixBuf.pa[y][x].g = chBuf1.ca[y][x];
            }
        }
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = srcPixBuf.pb[i].b;
        }
        focus(chBuf0, chBuf1);              // blue
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                dstPixBuf.pa[y][x].b = chBuf1.ca[y][x];
            }
        }
    }];
    [self addTransform:lastTransform];

    // not very blurry
    // XX this should be a general kernel convolution
    lastTransform = [Transform areaTransform: @"Blur"
                                  description: @""
                                areaFunction: ^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                                ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        for (int y=1; y<srcPixBuf.size.height-1; y++) {
            for (int x=1; x<srcPixBuf.size.width-1; x++) {
                Pixel p = {0,0,0,Z};
                p.r = (srcPixBuf.pa[y][x].r +
                       srcPixBuf.pa[y][x+1].r +
                       srcPixBuf.pa[y][x-1].r +
                       srcPixBuf.pa[y-1][x].r +
                       srcPixBuf.pa[y+1][x].r)/5;
                p.g = (srcPixBuf.pa[y][x].g +
                       srcPixBuf.pa[y][x+1].g +
                       srcPixBuf.pa[y][x-1].g +
                       srcPixBuf.pa[y-1][x].g +
                       srcPixBuf.pa[y+1][x].g)/5;
                p.b = (srcPixBuf.pa[y][x].b +
                       srcPixBuf.pa[y][x+1].b +
                       srcPixBuf.pa[y][x-1].b +
                       srcPixBuf.pa[y-1][x].b +
                       srcPixBuf.pa[y+1][x].b)/5;
                dstPixBuf.pa[y][x] = p;
            }
        }
    }];
    [self addTransform:lastTransform];
    
    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"3x3 sharpen"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            0, -1, 0,
            -1, 5, -1,
            0, -1, 0,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"3x3 Gausian blur"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            1, 2, 1,
            2, 4, 2,
            1, 2, 1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"5x5 Gausian blur"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            1, 4, 6, 4, 1,
            4, 16,24, 16, 4,
            6, 24, 36, 24, 6,
            4, 16,24, 16, 4,
            1, 4, 6, 4, 1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"7x7 Gausian blur"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            0, 0, 0, 5, 0, 0, 0,
            0, 5, 18, 32, 18, 5, 0,
            0, 18, 64, 100, 64, 18, 0,
            5, 32, 100, 100, 100, 32, 5,
            0, 18, 64, 100, 64, 18, 0,
            0, 5, 18, 32, 18, 5, 0,
            0, 0, 0, 5, 0, 0, 0,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"5x5 unsharp masking"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            1, 4, 6, 4, 1,
            4, 16, 24, 16, 4,
            6, 24, -476, 24, 6,
            4, 16, 24, 16, 4,
            1, 4, 6, 4, 1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"edge 1"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            1, 0, -1,
            0, 0, 0,
            -1, 0, 1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), NO);
    }];
    [self addTransform:lastTransform];

#ifdef BROKEN
    lastTransform = [Transform areaTransform: @"edge 1 norm"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            1, 0, -1,
            0, 0, 0,
            -1, 0, 1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];
#endif

    lastTransform = [Transform areaTransform: @"edge 2 norm"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            0, -1, 0,
            -1, 4, -1,
            0, 1, 0,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"edge 3"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            -1, -1, -1,
            -1, 8, -1,
            -1, -1, -1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), NO);
    }];
    [self addTransform:lastTransform];

#ifdef BROKEN
    lastTransform = [Transform areaTransform: @"edge 3 norm"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            -1, -1, -1,
            -1, 8, -1,
            -1, -1, -1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];
#endif
    
    lastTransform = [Transform areaTransform: @"Tin Type"
                                 description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        Pixel p = {0,0,0,Z};
        size_t h = srcPixBuf.size.height;
        size_t w = srcPixBuf.size.width;

        for (int y=0; y<h; y++) {
            int x;
            for (x=0; x<w-2; x++) {
                Pixel pin;
                int r, g, b;
                long xin = (x+2) >= w ? w - 1 : x+2;
                long yin = (y+2) >= h ? h - 1 : y+2;
                pin = srcPixBuf.pa[yin][xin];
                r = srcPixBuf.pa[y][x].r + Z/2 - pin.r;
                g = srcPixBuf.pa[y][x].g + Z/2 - pin.g;
                b = srcPixBuf.pa[y][x].b + Z/2 - pin.b;
                p.r = CLIP(r);  p.g = CLIP(g);  p.b = CLIP(b);
                dstPixBuf.pa[y][x] = p;
            }
            dstPixBuf.pa[y][x-3] = Grey;
            dstPixBuf.pa[y][x-2] = Grey;
            dstPixBuf.pa[y][x-1] = Grey;
            dstPixBuf.pa[y][x  ] = Grey;
            dstPixBuf.pa[y][x+1] = Grey;
        }
    }];
    [self addTransform:lastTransform];

    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"Box blur"   // needs norming
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {    // box blur
            1, 1, 1,
            1, 1, 1,
            1, 1, 1
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), YES);
    }];
    [self addTransform:lastTransform];

#ifdef SINGLE_CHAN_BROKEN
    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"Box blur"
                                description: @"Edge detection"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        long N = srcPixBuf.size.width * srcPixBuf.size.height;
        // Box blur
        const float kernel[] = {
            1, 1, 1,
            1, 1, 1,
            1, 1, 1
        };
        
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = srcPixBuf.pb[i].r;
        }
        channelConvolution(chBuf0, chBuf1, BoxBlur, 3, YES);
        for (int i=0; i<N; i++) {
            dstPixBuf.pb[i].r = chBuf1.cb[i];
            chBuf0.cb[i] = srcPixBuf.pb[i].g;
        }
        channelConvolution(chBuf0, chBuf1, BoxBlur, 3, YES);
        for (int i=0; i<N; i++) {
            dstPixBuf.pb[i].g = chBuf1.cb[i];
            chBuf0.cb[i] = srcPixBuf.pb[i].b;
        }
        channelConvolution(chBuf0, chBuf1, BoxBlur, 3, YES);
        for (int i=0; i<N; i++) {
            dstPixBuf.pb[i].b = chBuf1.cb[i];
        }
    }];
    [self addTransform:lastTransform];
#endif

    lastTransform = [Transform areaTransform: @"Cylinder"
                                  description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long centerX = remapBuf.size.width/2;
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<=centerX; x++) {
                int fromX = centerX*sin((M_PI/2.0)*x/centerX);
                assert(fromX >= 0 && fromX < remapBuf.size.width);
                REMAP_TO(x,y, fromX, y);
                REMAP_TO(remapBuf.size.width-1-x,y, remapBuf.size.width-1-fromX, y);
            }
        }
    }];
    [self addTransform:lastTransform];

#ifdef TEST
    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"trival conv. 1x1"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            1,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), NO);
    }];
    [self addTransform:lastTransform];
    
    // https://en.wikipedia.org/wiki/Kernel_(image_processing)
    lastTransform = [Transform areaTransform: @"3x3 identity conv"
                                description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            0, 0, 0,
            0, 1, 0,
            0, 0, 0,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), NO);
    }];
    [self addTransform:lastTransform];
#endif

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


- (void) addAreaTransforms {
    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        size_t h = srcPixBuf.size.height;
        size_t w = srcPixBuf.size.width;
#define L chBuf0.ca
        assert(chBuf0.w == w && chBuf0.h == h);
        for (int y=1; y<h-1; y++)
            for (int x=1; x<w-1; x++)
                L[y][x] = LUM(srcPixBuf.pa[y][x]);

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
                dstPixBuf.pa[y][x] = SETRGB(c,c,c);
            }
        }
#ifdef SHOW_GRID
        for (int x = 0; x<w; x += dpi) {
            for (int y=0; y<40 && y < h; y++)
                dstPixBuf.pa[y][x] = Red;
        }
#endif
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Old AT&T logo"
                                 description: @"Tom Duff's logo transform"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        size_t h = srcPixBuf.size.height;
        size_t w = srcPixBuf.size.width;
        for (int y=0; y<h; y++) {
            for (int x=0; x<w; x++) {
                channel c = LUM(srcPixBuf.pa[y][x]);
                dstPixBuf.pa[y][x] = SETRGB(c,c,c);
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
                    c += dstPixBuf.pa[y+y0][x].r;
                y0 = y+(hgt-1)/2;
                y1 = y+(hgt-1-(hgt-1)/2);
                for (; y0 >= y; --y0, ++y1)
                    c = stripe(dstPixBuf.pa, x, y0, y1, c);
            }
        }
        
        for (int y=0; y<h; y++) {
            for (int x=0; x<w; x++) {
                channel c = dstPixBuf.pa[y][x].r;
                dstPixBuf.pa[y][x] = SETRGB(c, c, c);
            }
        }
    }];
    lastTransform.value = 12; lastTransform.low = 4; lastTransform.high = 50;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Band thickness";
    [self addTransform:lastTransform];
}

#define RGB_SPACE   ((float)((1<<24) - 1))

- (void) addDepthVisualizations {
    
    // we have depthVis and depthTrans types.  DepthVis generates a PixMap based
    // on the supplied depth data, which is not changed.
    // depthTrans does what depthVis does, plus generates a (possibly-modified) depthBuf.
    
    lastTransform = [Transform depthVis: @"Fog"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        float backgroundDepth = depthBuf.maxDepth;
        float paramMaxDepth = instance.value/1000.0;
        if (backgroundDepth > paramMaxDepth && backgroundDepth > depthBuf.minDepth)
            backgroundDepth = paramMaxDepth;
        float D = backgroundDepth - depthBuf.minDepth;
        assert(D);
#define FADE(d) (d)               // linear
//#define FADE(d) ((d)*(d))           // quadratic
// #define FADE(d) ((d)*(d)*(d))    // cubic
        
        // fading needs a number between 0 (closest) to 1 (farthest)
        float maxFade = FADE(D);
        Pixel background = LightGrey;
        for (int i=0; i<W*H; i++) {
            Distance d = depthBuf.db[i];
            if (BAD_DEPTH(d) || d > backgroundDepth)
                d = backgroundDepth;
            float fadeFrac = FADE(d - depthBuf.minDepth)/maxFade;
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = CRGB(
                                         (1.0 - fadeFrac)*p.r + fadeFrac*background.r,
                                         (1.0 - fadeFrac)*p.g + fadeFrac*background.g,
                                         (1.0 - fadeFrac)*p.b + fadeFrac*background.b);
        }
#ifdef SHOW_GRID
        for (int x = 0; x<W; x += dpi) {
            for (int y=0; y<40 && y < H; y++)
                dstPixBuf.pa[y][x] = Red;
        }
#endif
    }];
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Max depth (mm)";
    lastTransform.low = 20; // millimeters
    lastTransform.value = 1000;
    lastTransform.high = 10000;
    [self addTransform:lastTransform];
    
    lastTransform = [Transform depthVis: @"cm. contours"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        float backgroundDepth = depthBuf.maxDepth;
        float paramMaxDepth = instance.value/1000.0;
        if (backgroundDepth > paramMaxDepth && backgroundDepth > depthBuf.minDepth)
            backgroundDepth = paramMaxDepth;
        for (int i=0; i<H * W; i++) {
            int mm = round(depthBuf.db[i]*1000.0);
            Pixel p;
            if (mm > backgroundDepth)
                p = White;
            else if (mm % 1000 == 0)
                p = BrightPurple;
            else if (mm % 100 == 0)
                p = Cyan;
            else if (mm % 10 == 0)
                p = Yellow;
            else
                p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = p;
        }
    }];
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Max depth (mm)";
    lastTransform.low = 20; // millimeters
    lastTransform.value = 4000;
    lastTransform.high = 10000;
    [self addTransform:lastTransform];

    lastTransform = [Transform depthVis: @"Encode depth"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        float backgroundDepth = depthBuf.maxDepth;
        float paramMaxDepth = instance.value/1000.0;
        if (backgroundDepth > paramMaxDepth && backgroundDepth > depthBuf.minDepth)
            backgroundDepth = paramMaxDepth;
        float D = backgroundDepth - depthBuf.minDepth;
        assert(D);
#ifdef OLD
        Distance newMinDepth = MAXFLOAT;
        Distance newMaxDepth = 0.0;

        float min = srcFrame.depthBuf.maxDepth;
        float max = srcFrame.depthBuf.minDepth;
#define VSCALE  10.0
        float selectedMax = instance.value/VSCALE;
#endif
        for (int i=0; i<W * H; i++) {
            Distance z = depthBuf.db[i];
            Pixel p;
#ifdef OLD
            if (z < min)
                min = z;
            if (z > selectedMax)
                max = z;
            if (z > newMaxDepth)
                newMaxDepth = z;
            if (z < newMinDepth)
                newMinDepth = z;
#endif
#ifdef HSV
            float frac = (d - depthBuf.minDepth)/(selectedMax - depthBuf.minDepth);
            float hue = frac;
            float sat = 1.0;
            float bri = 1.0 - frac;
            UIColor *color = [UIColor colorWithHue: hue saturation: sat
                                        brightness: bri alpha: 1];
            CGFloat r, g, b,a;
            [color getRed:&r green:&g blue:&b alpha:&a];
            p = CRGB(Z*r, Z*g, Z*b);
#else
            if (z < depthBuf.minDepth)
                p = Red;
            else if (z >= D)
                p = Black;
            else {
                float frac = (z - depthBuf.minDepth)/(D - depthBuf.minDepth);
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
            dstPixBuf.pb[i] = p;
        }
    }];
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Max depth (mm)";
    lastTransform.low = 20; // millimeters
    lastTransform.value = 4000;
    lastTransform.high = 10000;
    [self addTransform:lastTransform];

#ifdef DEBUG_TRANSFORMS
#define DIST(x,y)  [depthBuf distAtX:(x) Y:(y)]
#else
#define DIST(x,y)  depthBuf.da[y][x]
#endif
    
#ifdef BROKEN   // sometimes mindepth == 0
    lastTransform = [Transform depthVis: @"Mono log dist"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;

        Distance newMinDepth = MAXFLOAT;
        Distance newMaxDepth = 0.0;
        assert(depthBuf.minDepth > 0.0);    // no log of zero
        float logMin = log(depthBuf.minDepth);
        float logMax = log(depthBuf.maxDepth);
        for (int i=0; i<W * H; i++) {
            Distance d = depthBuf.db[i];
            if (d > newMaxDepth)
                newMaxDepth = d;
            if (d < newMinDepth)
                newMinDepth = d;
            float v = log(d);
            float frac = (v - logMin)/(logMax - logMin);
            channel c = trunc(Z - frac*Z);
            Pixel p = SETRGB(0,0,c);
            dstPixBuf.pb[i] = p;
        }
    }];
    lastTransform.broken = NO;
    [self addTransform:lastTransform];
#endif
    
    lastTransform = [Transform depthVis: @"Near depth"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        float mincm = 10.0;
        float maxcm = mincm + 100.0;
        float depthcm = maxcm - mincm;
        for (int i=0; i<H * W; i++) {
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
            dstPixBuf.pb[i] = p;
        }
    }];
//    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
//    lastTransform.hasParameters = YES;
//    lastTransform.paramName = @"Depth scale";
    lastTransform.broken = YES;
//   broken XXXXXX    [self addTransform:lastTransform];
    
    lastTransform = [Transform depthVis: @"3D level visualization"
                            description: @""
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        Distance newMinDepth = MAXFLOAT;
        Distance newMaxDepth = 0.0;
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;

        for (int i=0; i< H * W; i++) {
            Pixel p;
            channel c;
            Distance z = depthBuf.db[i];
            if (z > newMaxDepth)
                newMaxDepth = z;
            if (z < newMinDepth)
                newMinDepth = z;
            
            // closest to farthest, even v is dark blue to light blue,
            // odd v is yellow to dark yellow
            if (z >= depthBuf.maxDepth)
                p = Black;
            else if (instance.value <= depthBuf.minDepth)
                p = Green;
            else {
                if (instance.value & 0x1) {  // odd luminance
                    c = Z - (instance.value/2);
                    p = SETRGB(c,c,instance.value);
// was:                    p = SETRGB(0,0,instance.value);
                } else {
                    c = Z/2 + instance.value/2;
                    p = SETRGB(c,c,0);
                }
            }
            dstPixBuf.pb[i] = p;
        }
    }];
    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    lastTransform.broken = YES;
    lastTransform.paramName = @"Color scale?";
    [self addTransform:lastTransform];
    
#define MM_PER_IN   25.4
#define CHES_EYESEP_MM  62
#define EYESEP_PIX ((int)(CHES_EYESEP_MM*dpi/MM_PER_IN))
#define ZD(d)    (depthRange - ((d) - depthBuf.minDepth)/depthRange)
//#define separation(zd) round((1.0-mu*zd)*EYESEP/(2.0-mu*zd))
//#define FARAWAY separation(0)
#define Z_TO_SEP_X(z)   round((1.0-mu*z)*EYESEP_PIX/(2.0-mu*z))

// Z ranges from 0.0 to 1.0, for farthest to nearest distance.
    
    // SIRDS computation taken from
    // https://courses.cs.washington.edu/courses/csep557/13wi/projects/trace/extra/SIRDS-paper.pdf
    //
    // Displaying 3D Images: Algorithms for Single Image Random Dot Stereograms
    //  Thimbleby, Inglis, and Witten.
    
    lastTransform = [Transform depthVis: @"SIRDS"
                            description: @"Random dot stereogram"
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        
        float mu = (float)instance.value/100.0;
        float depthRange = depthBuf.maxDepth - depthBuf.minDepth;
        assert(depthRange);
        BOOL darkPixel[W];
        int same[W];
        
        for (int y=0; y<H; y++) {    // convert scan lines independently
            int stereoSepX;
            int left, right;    // x values for left and right eyes
            
            for (int x=0; x < W; x++ ) {  // link initial pixels with themselves
                same[x] = x;
            }
            
            for (int x=0; x < W; x++ ) {
                Distance d = depthBuf.da[y][x];
                if (d == 0) {   // bad depth
//                    NSLog(@"bad depth at %d,%d  of %d", x, y, srcFrame.depthBuf.badDepths);
                    d = depthBuf.maxDepth;
                }
                assert(d);
                float z = 1.0 - (d - depthBuf.minDepth)/depthRange;
                // z = 0 is max depth, 1.0 is vision plane.
                assert(z >= 0 && z <= 1.0);
                stereoSepX = round((1.0-mu*z)*EYESEP_PIX/(2.0-mu*z));
                if (W > 100) {
                    NSLog(@"mu, z, EYESEP_PIX: %.3f %.3f  %d", mu, z, EYESEP_PIX);
                    NSLog(@"   sep X = %d", stereoSepX);
                    NSLog(@"sepx range: %.2f,  %.2f,  %.f2", Z_TO_SEP_X(0.0), Z_TO_SEP_X(z), Z_TO_SEP_X(1.0));
                }
//                stereoSepX = Z_TO_SEP_X(z);
                //stereoSep = separation(zd);
                assert(stereoSepX >= 0);
                left = x - stereoSepX/2;
                right = left + stereoSepX;   // pixels at left and right must be the same
                if (left >= 0 && right < W) {
                    int visible;    // first, perform hidden surface removal
                    int t = 1;      // We will check the points (x-t,y) and (x+t,y)
                    float zt;       //  Z-coord of ray at these two points
                    do {
                        zt = ZD(depthBuf.da[y][x]) + 2*(2 - mu*ZD(depthBuf.da[y][x]))*t/(mu*EYESEP_PIX);
                        BOOL inRange = (x-t >= 0) && (x+t < W);
                        visible = inRange && ZD(depthBuf.da[y][x-t]) < zt &&
                            ZD(depthBuf.da[y][x+t]) < zt;  // false if obscured
                        t++;
                    } while (visible && zt < 1);    // end of hidden surface removal
                    if (visible) {  // record that pixels at l and r are the same
                        assert(left >= 0 && left < W);
                        int l = same[left];
                        assert(l >= 0 && l < W);
                        while (l != left && l != right) {
                            if (l < right) {    // first, jiggle the pointers...
                                left = l;       // until either same[left] == left
                                assert(left >= 0 && left < depthBuf.size.width);
                                l = same[left]; // .. or same[left == right
                                assert(l >= 0 && l < depthBuf.size.width);
                            } else {
                                assert(left >= 0 && left < W);
                                same[left] = right;
                                left = right;
                                l = same[left];
                                assert(l >= 0 && l < W);
                                right = l;
                            }
                        }
                        same[left] = right; // actually recorded here
                    }
                }
            }
            for (long x=W-1; x>=0; x--)    { // set the pixels in the scan line
                if (same[x] == x)
                    darkPixel[x] = random()&1;  // free choice, do it randomly
                else
                    darkPixel[x] = darkPixel[same[x]];  // constrained choice, obey constraint
                dstPixBuf.pa[y][x] = darkPixel[x] ? Black : White;
            }
        }
        
#ifdef notdef
#define NW      10
#define BOTTOM_Y   (5)
        int lx = W/2 - FARAWAY/2 - NW/2;
        int rx = W/2 + FARAWAY/2 - NW/2;
        for (int dy=0; dy<6; dy++) {
            for (int dx=0; dx<NW; dx++) {
                dstPixBuf.pa[BOTTOM_Y+dy][lx+dx] = Yellow;
                dstPixBuf.pa[BOTTOM_Y+dy][rx+dx] = Yellow;
            }
        }
#endif
    }];
    lastTransform.low = 0;
    lastTransform.high = 100;
    lastTransform.value = 100/3;    // recommended value, non-crosseyed
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Depth of field";
// XXXXXX debug    [self addTransform:lastTransform];

    // https://en.wikipedia.org/wiki/Anaglyph_3D#Stereo_conversion_(single_2D_image_to_3D)
#define EYE_SEP 62  // mm
#define PDOT    0.2
    lastTransform = [Transform depthVis: @"Anaglyph"
                            description: @"Complementary color anaglyph"
                               depthVis: ^(PixBuf *srcPixBuf, DepthBuf *depthBuf, PixBuf *dstPixBuf,
                                           TransformInstance *instance) {
        assert(SAME_SIZE(srcPixBuf.size, depthBuf.size));
        assert(SAME_SIZE(srcPixBuf.size, dstPixBuf.size));
        int W = depthBuf.size.width;
        int H = depthBuf.size.height;
        float backgroundDepth = depthBuf.maxDepth;
        float paramMaxDepth = instance.value/1000.0;
        if (backgroundDepth > paramMaxDepth && backgroundDepth > depthBuf.minDepth)
            backgroundDepth = paramMaxDepth;
        float D = backgroundDepth - depthBuf.minDepth;
        assert(D);
        for (int i=0; i<W*H; i++)
            if (depthBuf.db[i] > D)
                dstPixBuf.pb[i] = White;
            else
                dstPixBuf.pb[i] = srcPixBuf.pb[i];     // was White;

        for (int y=0; y<H; y++) {    // convert scan lines independently
            for (int x=0; x<W; x++) {
                float z = depthBuf.da[y][x];
                float r = (rand() % 100) / 100.0;
                if (r > PDOT) {
                    dstPixBuf.pa[y][x] = srcPixBuf.pa[y][x];
                    continue;
                }
                
                float sep = (EYE_SEP/2.0) * ((depthBuf.maxDepth - z)/depthBuf.maxDepth);
                int leftX = x - sep;
                int rightX = x + sep;
                if (leftX < 0 || rightX >= W)
                    continue;
                dstPixBuf.pa[y][leftX] = Cyan;
                dstPixBuf.pa[y][rightX] = Red;
            }
        }
    }];
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Max depth (mm)";
    lastTransform.low = 20; // millimeters
    lastTransform.value = 1000;
    lastTransform.high = 10000;
#ifdef NOTDEF
    lastTransform.hasParameters = YES;
    lastTransform.low = 10;
    lastTransform.value = 62;
    lastTransform.high = 100;
    lastTransform.broken = NO;
    lastTransform.paramName = @"Pupil separation";
#endif
    [self addTransform:lastTransform];
}

// used by colorize

channel rl[31] = {0,0,0,0,0,0,0,0,0,0,        5,10,15,20,25,Z,Z,Z,Z,Z,    0,0,0,0,0,5,10,15,20,25,Z};
channel gl[31] = {0,5,10,15,20,25,Z,Z,Z,Z,    Z,Z,Z,Z,Z,Z,Z,Z,Z,Z,        25,20,15,10,5,0,0,0,0,0,0};
channel bl[31] = {Z,Z,Z,Z,Z,25,15,10,5,0,    0,0,0,0,0,5,10,15,20,25,    5,10,15,20,25,Z,Z,Z,Z,Z,Z};

- (void) addPointTransforms {
    lastTransform = [Transform colorTransform: @"Negative"
                                 description: @""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(Z-p.r, Z-p.g, Z-p.b);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Solarize"
                                 description: @"Simulate extreme overexposure"
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.r < Z/2 ? p.r : Z-p.r,
                                   p.g < Z/2 ? p.g : Z-p.g,
                                   p.b < Z/2 ? p.b : Z-p.r);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Red"
                                  description:@""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.r,0,0);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Green"
                                  description:@""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(0,p.g,0);
        }
        return ;
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Blue"
                                  description:@""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(0,0,p.b);
        }
        return ;
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform:@"No blue"
                                  description:@""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.r,p.g,0);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform:@"No green"
                                  description:@""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.r,0,p.b);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform:@"No red"
                                  description:@""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(0,p.g,p.b);
        }
        return ;
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"No color"
                                 description: @"Convert to brightness"
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
           channel c = LUM(srcPixBuf.pb[i]);
            dstPixBuf.pb[i] = SETRGB(c,c,c);
       }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Colorize"
                                  description: @""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&(Z >> 3);
            dstPixBuf.pb[i] = SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"Truncate colors"
                                 description: @""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        channel mask = ((1<<v) - 1) << (8 - v);
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
           Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.r&mask, p.g&mask, p.b&mask);
       }
    }];
    lastTransform.low = 1; lastTransform.value = 2; lastTransform.high = 7;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Truncation level";
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Brighten"
                                  description: @""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.r+(Z-p.r)/8,
                            p.g+(Z-p.g)/8,
                            p.b+(Z-p.b)/8);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"High contrast"
                                  description: @""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(CLIP((p.r-HALF_Z)*2+HALF_Z),
                            CLIP((p.g-HALF_Z)*2+HALF_Z),
                            CLIP((p.b-HALF_Z)*2+HALF_Z));
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform colorTransform: @"Swap colors"
                                  description: @"r→g, g→b, b→r"
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            dstPixBuf.pb[i] = SETRGB(p.g, p.b, p.r);
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Auto contrast"
                                  description: @""
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.width * srcPixBuf.size.height;
        u_long ps;
        u_long hist[Z+1];
        float map[Z+1];
        
        for (int i=0; i<Z+1; i++) {
            hist[i] = 0;
            map[i] = 0.0;
        }
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            hist[LUM(p)]++;
        }
        ps = 0;
        for (int i = 0; i < Z+1; i++) {
            map[i] = (float)Z * (float)ps/(float)N;
            ps += hist[i];
        }
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            channel l = LUM(p);
            float a = (map[l] - l)/(float)Z;
            int r = p.r + (a*(Z-p.r));
            int g = p.g + (a*(Z-p.g));
            int b = p.b + (a*(Z-p.b));
            dstPixBuf.pb[i] = CRGB(r,g,b);
        }
    }];
    [self addTransform:lastTransform];
}

- (void) addGeometricTransforms {
    lastTransform = [Transform areaTransform: @"Mirror"
                                  description: @"Reflect the image"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
                REMAP_TO(x, y, remapBuf.size.width - x - 1, y);
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Flip"
                                  description: @"vertical reflection"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
                REMAP_TO(x, y, x, remapBuf.size.height - y - 1);
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Horizontal shift"
                                  description: @"shift left/right"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long xPixelShift = remapBuf.size.width * (instance.value/100.0);
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
                long sx = x - xPixelShift;
                if (REMAPBUF_IN_RANGE(sx, y))
                    REMAP_TO(x, y, sx, y);
                else
                    REMAP_COLOR(x, y, Remap_White);
            }
        }
    }];
    lastTransform.low = -100;   // percent of screen width
    lastTransform.value = -12;
    lastTransform.high = 100;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Shift amount";
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Vertical shift"
                                  description: @"shift up/down"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long yPixelShift = remapBuf.size.height * (instance.value/100.0);
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
                long sy = y + yPixelShift;
                if (REMAPBUF_IN_RANGE(x, sy))
                    REMAP_TO(x, y, x, sy);
                else
                    REMAP_COLOR(x, y, Remap_White);
            }
        }
    }];
    lastTransform.low = -100;   // percent of screen width
    lastTransform.value = 10;
    lastTransform.high = 100;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Shift amount";
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"O no!"
                                 description: @"Reflect the right half of the screen on the left"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        long centerX = remapBuf.size.width/2;
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
                if (x < centerX)
                    REMAP_TO(x, y, remapBuf.size.width - x - 1, y);
                else
                    REMAP_TO(x, y, x, y);
            }
        }
    }];
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Zoom"
                                 description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        float zoom = instance.value;
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
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
    lastTransform.paramName = @"amount";
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Wavy shower"
                                 description: @"Through wavy glass"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        int cpp = instance.value;   // pixels per cycle
        int ncyc = (int)remapBuf.size.width / cpp;
#ifdef UNNEEDED
        for (int y=0; y<remapBuf.size.height; y++) { // why is this loop needed?
            for (int x=0; x<remapBuf.size.width; x++) {
                REMAP_TO(x,y, x,y);
            }
        }
#endif
        for (int y=0; y<remapBuf.size.height; y++) {  // XX thumbnail not very wavy
            for (int x=0; x<remapBuf.size.width; x++) {
                int fx = x + (int)(ncyc*sin(cpp*x*2*M_PI/remapBuf.size.width));
                REMAP_TO(x,y, fx,y);
            }
        }
    }];
    lastTransform.low = 10;
    lastTransform.value = 18;
    lastTransform.high = 50;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Pixels per wave";
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Pixelate"
                                  description: @"Giant pixels"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        int pixSize = instance.value;
        for (int y=0; y<remapBuf.size.height; y++) {
            for (int x=0; x<remapBuf.size.width; x++) {
                REMAP_TO(x, y, (x/pixSize)*pixSize, (y/pixSize)*pixSize);
            }
        }
    }];
    lastTransform.low = 1;
    lastTransform.value = 6;
    lastTransform.high = 120;
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Pixel size";
    [self addTransform:lastTransform];

    lastTransform = [Transform areaTransform: @"Terry's kite"
                                 description: @"Designed by an 8-year old"
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        assert(remapBuf.size.width > 0 && remapBuf.size.height > 0);
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
//        NSLog(@" kite %zu x %zu", remapBuf.size.width, remapBuf.size.height);
        for (int y=0; y<remapBuf.size.height; y++) {
            size_t ndots;
            
            if (y <= centerY)
                ndots = (y*(remapBuf.size.width-1))/remapBuf.size.height;
            else
                ndots = ((remapBuf.size.height-y-1)*(remapBuf.size.width))/remapBuf.size.height;
            
//            NSLog(@" kite %d, %zu", y, ndots);

            assert(y>= 0 && y < remapBuf.size.height);
            REMAP_TO(centerX,y, centerX, y);
            REMAP_TO(centerX,y, centerX, y);
            REMAP_COLOR(0,y, Remap_White);
            
            for (int x=1; x<=ndots; x++) {
                size_t dist = (x*(centerX-1))/ndots;
                assert(centerX - dist >= 0 && centerX - dist < remapBuf.size.width);
                assert(centerX + dist >= 0 && centerX + dist < remapBuf.size.width);
                REMAP_TO(centerX+x,y, centerX + dist,y);
                REMAP_TO(centerX-x,y, centerX - dist,y);
            }
            for (size_t x=ndots; x<centerX; x++) {
                assert(centerX - x >= 0 && centerX - x < remapBuf.size.width);
                assert(centerX + x >= 0 && centerX + x < remapBuf.size.width);
                REMAP_COLOR(centerX+x,y, Remap_White);
                REMAP_COLOR(centerX-x,y, Remap_White);
             }
        }
        [remapBuf verify];
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
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        int x, y;
        int oilD = 1 << instance.value; // powers of two
        Hist_t hists;

        long W = srcPixBuf.size.width;
        long H = srcPixBuf.size.height;

        // set the border
        for (y=0; y<H; y++) {
            for (x=0; x<oilD; x++) {
                dstPixBuf.pa[y][x] = srcPixBuf.pa[y][W - x - 1] = White;
            }
            if (y < oilD || y > H - oilD)
                for (int x=0; x < W; x++)
                    dstPixBuf.pa[y][x] = White;
        }
        
        x = y = oilD;   // start in the upper left corner
        BOOL goingRight = YES;
        memset(&hists, 0, sizeof(hists));   // clear the histograms
        setHistAround(srcPixBuf.pa, x, y, oilD, &hists);
        do {
            dstPixBuf.pa[y][x] = mostCommonColorInHist(&hists);
            if (goingRight) {
                if (x + oilD - 1 < W) {
                    x++;
                    moveHistRight(srcPixBuf.pa, x, y, oilD, &hists);
                } else {
                    // go down one pixel and change directions
                    y++;
                    if (y + oilD == H)
                        break;  // hit the bottom.  XXXXXX unobvious control structure
                    goingRight = NO;
                    moveHistDown(srcPixBuf.pa, x, y, oilD, &hists);
                }
            } else {    // going left
                if (x > oilD) {
                    x--;
                    moveHistLeft(srcPixBuf.pa, x, y, oilD, &hists);
                } else {
                    y++;
                    if (y + oilD == H)
                        break;  // hit the bottom  XXXXXX unobvious control structure
                    moveHistDown(srcPixBuf.pa, x, y, oilD, &hists);
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
                setHistAround(srcFrame.pixBuf.pa, x, y, oilD, &hists);
                dstPixBuf.pa[y][x] = mostCommonColorAround(srcFrame.pixBuf.pa, x, y, oilD, &hists);
            }
        }
#endif
    }];
    lastTransform.low = 1;      // 2^1
    lastTransform.value = 2;    // 2^2.  2^3 is MUCH shower
    lastTransform.high = 4;     // 2^4
    lastTransform.hasParameters = YES;
    lastTransform.paramName = @"Blob size";
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Charcoal sketch"
                                 description: @""
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        // monochrome sobel...
        long N = srcPixBuf.size.width * srcPixBuf.size.height;
        for (int i=0; i<N; i++) {
            chBuf0.cb[i] = LUM(srcPixBuf.pb[i]);
        }
        // gerard's sobol, which is right
        sobel(chBuf0, chBuf1);
        
        // ... negate and high contrast...
        // ... + negative + high contrast...
        
        for (int i=0; i<N; i++) {
            channel c = chBuf1.cb[i];
            channel nc = Z - CLIP((c-HALF_Z)*2+HALF_Z);
            Pixel p = SETRGB(nc, nc, nc);
            dstPixBuf.pb[i] = p;
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform colorTransform: @"Warhol"
                                  description: @"cartoon colors"
                                       ptFunc: ^(const PixBuf *srcPixBuf, PixBuf *dstPixBuf, int v) {
        int N = srcPixBuf.size.height * srcPixBuf.size.width;
        int ave_r=0, ave_g=0, ave_b=0;
        
        for (int i=0; i<N; i++) {
            Pixel p = srcPixBuf.pb[i];
            ave_r += p.r;
            ave_g += p.g;
            ave_b += p.b;
        }
        
        ave_r /= N;
        ave_g /= N;
        ave_b /= N;
        
        for (int i=0; i<N; i++) {
            Pixel p = {0,0,0,Z};
            p.r = (srcPixBuf.pb[i].r >= ave_r) ? Z : 0;
            p.g = (srcPixBuf.pb[i].g >= ave_g) ? Z : 0;
            p.b = (srcPixBuf.pb[i].b >= ave_b) ? Z : 0;
            dstPixBuf.pb[i] = p;
        }
    }];
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Escher"
                                 description: @""
                                  remapImage:^(RemapBuf *remapBuf, TransformInstance *instance) {
        pixPerSide = instance.value;
        dxToBlockCenter = ((int)(pixPerSide*sqrt(0.75)));
        
        for (int x=0; x<remapBuf.size.width; x++) {
            for (int y=0; y<remapBuf.size.height; y++)
                REMAP_COLOR(x, y,Remap_White);
        }

        int nxBlocks = (((int)remapBuf.size.width/(2*dxToBlockCenter)) + 2);
        int nyBlocks = (int)((remapBuf.size.height/(3*pixPerSide/2)) + 2);
        
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
                    
                    dxx = (CORNERS[lr].x - CORNERS[ll].x)/(float)remapBuf.size.width;
                    dxy = (CORNERS[lr].y - CORNERS[ll].y)/(float)remapBuf.size.width;
                    dyx = (CORNERS[ul].x - CORNERS[ll].x)/(float)remapBuf.size.height;
                    dyy = (CORNERS[ul].y - CORNERS[ll].y)/(float)remapBuf.size.height;
                    
                    for (int y=0; y<remapBuf.size.height; y++) {    // we could actually skip some of these
                        for (int x=0; x<remapBuf.size.width; x++)    {
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
    lastTransform.paramName = @"Block edge length";
    [self addTransform:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Edvard Munch #1"        // old twist right
                                 description: @""
                                  remapPolar:^(RemapBuf *remapBuf, float r, float a, TransformInstance *instance, int tX, int tY) {
        double newa = a + (r/3.0)*(M_PI/180.0);
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
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
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
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
        long centerX = remapBuf.size.width/2;
        long centerY = remapBuf.size.height/2;
        long sx = centerX + r*cos(a);
        long sy = centerY + r*sin(a);
        sx = centerX + (r*cos(a + (sy*sx/(16*17000.0))));
        if (REMAPBUF_IN_RANGE(sx, sy))
            UNSAFE_REMAP_TO(tX, tY, sx, sy);
        else
            REMAP_COLOR(tX, tY, Remap_White);
    }];
    [self addTransform:lastTransform];

}
- (void) addBugTransforms {
    lastTransform = [Transform areaTransform: @"Pretty bug"
                                description: @"edge 2 needs norm"
                                areaFunction:^(PixBuf *srcPixBuf, PixBuf *dstPixBuf,
                                               ChBuf *chBuf0, ChBuf *chBuf1, TransformInstance *instance) {
        const float kernel[] = {
            0, -1, 0,
            -1, 4, -1,
            0, 1, 0,
        };
        pixelConvolution(srcPixBuf, dstPixBuf, kernel, KERNEL_SIZE(kernel), NO);
    }];
    [self addTransform:lastTransform];
}

@end
