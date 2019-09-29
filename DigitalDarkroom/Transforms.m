//
//  Transforms.m
//  DigitalDarkroom
//
//  Created by ches on 9/16/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "Transforms.h"
#import "Defines.h"

#define DEBUG_TRANSFORMS    // bounds checking and a lot of CPU-expensive assertions

#define SETRGB(r,g,b)   (Pixel){b,g,r,Z}
#define Z               ((1<<sizeof(channel)*8) - 1)

#define CENTER_X        (frameSize.width/2)
#define CENTER_Y        (frameSize.height/2)

#define Black           SETRGB(0,0,0)
#define Grey            SETRGB(Z/2,Z/2,Z/2)
#define LightGrey       SETRGB(2*Z/3,2*Z/3,2*Z/3)
#define White           SETRGB(Z,Z,Z)

#define LUM(p)  ((((p).r)*299 + ((p).g)*587 + ((p).b)*114)/1000)
#define CLIP(c) ((c)<0 ? 0 : ((c)>Z ? Z : (c)))

#define R(x) x.r
#define G(x) x.g
#define B(x) x.b

@interface Transforms ()

@property (strong, nonatomic)   NSMutableArray *sourceImageIndicies;
@property (strong, nonatomic)   NSArray *executeList;

@end

@implementation Transforms

@synthesize categoryNames;
@synthesize categoryList;
@synthesize list;
@synthesize listChanged;
@synthesize executeList;
@synthesize frameSize;
@synthesize sourceImageIndicies;

Image sources[2];

- (id)init {
    self = [super init];
    if (self) {
        sources[1].image = 0;
        
        list = [[NSMutableArray alloc] init];
        listChanged = NO;
        categoryNames = [[NSMutableArray alloc] init];
        categoryList = [[NSMutableArray alloc] init];
        
        [self addColorTransforms];
        [self addAreaTransforms];
        [self addGeometricTransforms];
        [self addMiscTransforms];
        [self addArtTransforms];
    }
    return self;
}

- (void) updateFrameSize: (CGSize) newSize {    // XXXX this needs to be protected from changes
    frameSize = newSize;
    listChanged = YES;
    // update transforms:
    // XXXXXX change requires recomputing all remap functions
}


- (void) setupForTransforming {
    // we can't have this routine execute off the official list, because that can get changed
    // by the user in mid-transform.  So we keep a separate copy here.  This copy still
    // points to each individual transform, whose parameter can change in mid-transform,
    // so we have to keep a local copy of that parameter in the actual transform processor.
    
    executeList = [NSArray arrayWithArray:list];
    listChanged = NO;
    
    // source[0] gets all its data from the call context.  If we need a destination image,
    // we have to allocate one.  Set it to the invalid address 1 if we need an alloc.

    // Some transforms are best done in place, but some need to go to a destination
    // other than the source.   Here are the two possible sources.

    for (int i=0; i<executeList.count; i++) {
        Transform *transform = [executeList objectAtIndex:i];
        switch (transform.type) {
            case ColorTrans: {
                break;
            }
            case RemapTrans:    // precompute new pixel locations
                if (transform.remapTable) {
                    free(transform.remapTable);
                    transform.remapTable = nil;
                }
                transform.remapTable = transform.remapF(frameSize.width, frameSize.height, transform.param);
                break;
            case GeometricTrans:
            case AreaTrans:
            case EtcTrans:
                return;
        }
    }
}

- (UIImage *) doTransformsOnContext:(CGContextRef)context {
    if (listChanged) {
        [self setupForTransforming];
    }
    
    size_t channelSize = CGBitmapContextGetBitsPerComponent(context);
    size_t pixelSize = CGBitmapContextGetBitsPerPixel(context);
    
    // These transforms make certain assumptions about the bitmaps encountered
    // that greatly speed up and simplify them.  Make sure these assumptions
    // are valid.
    
    assert(channelSize == 8);   // eight bits per color
    assert(pixelSize == channelSize * sizeof(Pixel));   // GBRA is a Pixel
    
    int sourceImageIndex = 0;   // incoming image is at zero
    
    sources[sourceImageIndex] = (Image){
        (int)CGBitmapContextGetWidth(context),
        (int)CGBitmapContextGetHeight(context),
        (int)CGBitmapContextGetBytesPerRow(context),
        CGBitmapContextGetData(context)};
    assert(sources[sourceImageIndex].bytes_per_row == sources[sourceImageIndex].w * sizeof(Pixel)); //no slop on the rows
    assert(((u_long)sources[sourceImageIndex].image & 0x03 ) == 0); // word-aligned pixels
    
    BOOL needsAlloc = sources[1].image == 0;
    sources[1] = sources[0];
    if (needsAlloc)
        sources[1].image = (Pixel *)calloc(sources[1].w * sources[1].h, sizeof(Pixel));
    
    Image *source= &sources[0];
    Image *dest = 0;
    if (executeList.count == 0)
        assert(sourceImageIndex == 0);
    for (int i=0; i<executeList.count; i++) {
        assert(executeList.count > 0);
        source = &sources[sourceImageIndex];
        dest = &sources[1 - sourceImageIndex];
        Transform *transform = [executeList objectAtIndex:i];
        switch (transform.type) {
            case ColorTrans: {
                transform.pointF(source->image, source->w * source->h);
                break;
            }
            case GeometricTrans:
                break;
            case RemapTrans: {
                [self remapWithTable:transform.remapTable from:source to:dest];
                sourceImageIndex = 1 - sourceImageIndex;
                break;
                }
            case AreaTrans:
                assert(source->image);
                assert(dest->image);
                assert(dest->image != (Pixel *)1);
                
                transform.areaF(source, dest);
                sourceImageIndex = 1 - sourceImageIndex;
                assert(executeList.count > 0);
                break;
            case EtcTrans:
                break;
        }
    }
    // temp kludge, copy bytes back into main context, if needed
    if (sourceImageIndex) {
        assert(executeList.count > 0);
        assert(dest != 0);
        assert(dest->image != (Pixel *)1);
        // XXX bad exec addr 1
        memcpy(dest->image, sources[0].image,
               dest->w * dest->h * sizeof(Pixel));
    }
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    UIImage *out = [UIImage imageWithCGImage:quartzImage];
    CGImageRelease(quartzImage);
    return out;
    //    CIImage * imageFromCoreImageLibrary = [CIImage imageWithCVPixelBuffer: pixelBuffer];
}

// These all assume maxX and maxY are local variables
//
// PI pixel index in an image
// PA: pixel address in an image
// Pixel in an image pixel

#ifdef DEBUG_TRANSFORMS

#define PI(x,y)     dPI((x), (y), maxX, maxY)

int dPI(int x, int y, int maxX, int maxY) {
    assert(x >= 0);
    assert(x < maxX);
    assert(y >= 0);
    assert(y < maxY);
    int i = x + y*maxX;
    assert(i < maxX*maxY);
    return i;
}

#else

#define PI(x,y)     ((x) + (y)*maxX)

#endif

#define PA(im, x,y) &im[PI((x),(y))]
#define P(im, x,y)  (*PA(im,(x),(y)))


- (void) remapWithTable:(size_t *) table from:(Image *)src to:(Image *)dest {
    for (size_t i=0; i<dest->w * dest->h; i++) {
        size_t target = *table++;
        assert(target < dest->w * dest->h);
        dest->image[i] = src->image[target];
    }
}

- (void) addAreaTransforms {
    [categoryNames addObject:@"Area transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    [transformList addObject:[Transform remapTransform: @"Pixelate"
                                          description: @"Giant pixels"
                                                remap:^size_t *(int maxX, int maxY, int pixsize) {
        size_t *table = (size_t *)calloc(maxX * maxY, sizeof(size_t));
        for (int y=0; y<maxY; y++)
            for (int x=0; x<maxX; x++) {
                size_t s = PI((x/pixsize)*pixsize, (y/pixsize)*pixsize);
                size_t d = PI(x,y);
                table[d] = s;
            }
        return table;
    }]];

    [transformList addObject:[Transform areaTransform: @"Mirror right"
                                          description: @"Reflect the right half of the screen on the left"
                                        areaTransform: ^(Image *src, Image *dest) {
        Pixel *in = src->image;
        Pixel *out = dest->image;
        int maxY = src->h;
        int maxX = src->w;
        //        size_t bpr = src->bytes_per_row;
        int x, y;
        
        for (x=0; x<maxX; x++) {
            for (y=0; y<maxY; y++) {
                P(out,maxX-x-1,y) = P(in,x,y);
            }
        }
    }]];
    
    [transformList addObject:[Transform areaTransform: @"Sobel"
                                          description: @"Sobel filter"
                                        areaTransform: ^(Image *src, Image *dest) {
        Pixel *in = src->image;
        Pixel *out = dest->image;
        int maxY = src->h;
        int maxX = src->w;
        //        int bpr = src->bytes_per_row;
        int x, y;
        
        for (y=1; y<maxY-1; y++) {
            for (x=1; x<maxX-1; x++) {
                int aa, bb, s;
                Pixel p = {0,0,0,Z};
                aa = R(P(in,x-1, y-1)) + R(P(in,x-1, y))*2 + R(P(in,x-1, y+1)) -
                    R(P(in,x+1, y-1)) - R(P(in,x+1, y))*2 - R(P(in,x+1, y+1));
                bb = R(P(in,x-1, y-1))+R(P(in,x, y-1))*2+
                    R(P(in,x+1, y-1))-
                    R(P(in,x-1, y+1))-R(P(in,x, y+1))*2-
                    R(P(in,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.r = Z;
                else
                    p.r = s;
                
                aa = G(P(in,x-1, y-1))+G(P(in,x-1, y))*2+
                    G(P(in,x-1, y+1))-
                    G(P(in,x+1, y-1))-G(P(in,x+1, y))*2-
                    G(P(in,x+1, y+1));
                bb = G(P(in,x-1, y-1))+G(P(in,x, y-1))*2+
                    G(P(in,x+1, y-1))-
                    G(P(in,x-1, y+1))-G(P(in,x, y+1))*2-
                    G(P(in,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.g = Z;
                else
                    p.g = s;
                
                aa = B(P(in,x-1, y-1))+B(P(in,x-1, y))*2+
                    B(P(in,x-1, y+1))-
                    B(P(in,x+1, y-1))-B(P(in,x+1, y))*2-
                    B(P(in,x+1, y+1));
                bb = B(P(in,x-1, y-1))+B(P(in,x, y-1))*2+
                    R(P(in,x+1, y-1))-
                    B(P(in,x-1, y+1))-B(P(in,x, y+1))*2-
                    B(P(in,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.b = Z;
                else
                    p.b = s;
                P(out,x,y) = p;
            }
        }
        
    }]];
    
    [transformList addObject:[Transform areaTransform: @"Negative Sobel"
                                          description: @"Negative Sobel filter"
                                        areaTransform: ^(Image *src, Image *dest) {
        Pixel *in = src->image;
        Pixel *out = dest->image;
        int maxY = src->h;
        int maxX = src->w;

        int x, y;
        for (y=1; y<maxY-1; y++) {
            for (x=1; x<maxX-1; x++) {
                int aa, bb, s;
                Pixel p = {0,0,0,Z};
                aa = P(in, x-1,y-1).r + P(in, x-1,y).r * 2 +
                    P(in, (x-1),(y+1)).r -
                    P(in, (x+1),(y-1)).r - P(in, (x+1),(y)).r * 2 -
                    P(in, (x+1),(y+1)).r;
                bb = P(in, (x-1),(y-1)).r + P(in, (x),(y-1)).r * 2 +
                    P(in, (x+1),(y-1)).r -
                    P(in, (x-1),(y+1)).r - P(in, (x),(y+1)).r * 2 -
                    P(in, (x+1),(y+1)).r;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.r = Z;
                else
                    p.r = s;

                aa = P(in, x-1,y-1).g + P(in, x-1,y).g * 2 +
                    P(in, (x-1),(y+1)).g -
                    P(in, (x+1),(y-1)).g - P(in, (x+1),(y)).g * 2 -
                    P(in, (x+1),(y+1)).g;
                bb = P(in, (x-1),(y-1)).g + P(in, (x),(y-1)).g * 2 +
                    P(in, (x+1),(y-1)).g -
                    P(in, (x-1),(y+1)).g - P(in, (x),(y+1)).g * 2 -
                    P(in, (x+1),(y+1)).g;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.g = Z;
                else
                    p.g = s;

                aa = P(in, x-1,y-1).b + P(in, x-1,y).b * 2 +
                     P(in, (x-1),(y+1)).b -
                     P(in, (x+1),(y-1)).b - P(in, (x+1),(y)).b * 2 -
                     P(in, (x+1),(y+1)).b;
                 bb = P(in, (x-1),(y-1)).b + P(in, (x),(y-1)).b * 2 +
                     P(in, (x+1),(y-1)).b -
                     P(in, (x-1),(y+1)).b - P(in, (x),(y+1)).b * 2 -
                     P(in, (x+1),(y+1)).b;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.b = Z;
                else
                    p.b = s;
                p.r = Z - p.r;
                p.g = Z - p.g;
                p.b = Z - p.b;
                P(out,x,y) = p;
            }
        }
        
    }]];
        
    [transformList addObject:[Transform areaTransform: @"Mirror left"
                                          description: @"Reflect the left half of the screen on the right"
                                        areaTransform: ^(Image *src, Image *dest) {
        Pixel *in = src->image;
        Pixel *out = dest->image;
        assert(in);
        assert(out);
        int maxY = src->h;
        int maxX = src->w;
        //        size_t bpr = src->bytes_per_row;
        int x, y;
        
        for (x=0; x<maxX; x++) {
            for (y=0; y<maxY; y++) {
                P(out,x,y) = P(in,maxX-x-1,y);
            }
        }
    }]];

#ifdef notyet
    extern  init_proc init_zoom;
    
    extern  transform_t do_brownian;
    extern  transform_t do_blur;
    extern  transform_t do_fs1;
    extern  transform_t do_fs2;
    extern  transform_t do_focus;
    extern  transform_t do_sampled_zoom;
    extern  transform_t do_mean;
    extern  transform_t do_median;
#endif
}

- (void) addGeometricTransforms {
    [categoryNames addObject:@"Geometric transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
#ifdef notyet
    extern  init_proc init_kite;
    extern  init_proc init_pixels4;
    extern  init_proc init_pixels8;
    extern  init_proc init_rotate_right;
    extern  init_proc init_copy_right;
    extern  init_proc init_mirror;
    extern  init_proc init_droop_right;
    extern  init_proc init_raise_right;
    extern  init_proc init_shower2;
    extern  init_proc init_cylinder;
    extern  init_proc init_shift_left;
    extern  init_proc init_shift_right;
    extern  init_proc init_cone;
    extern  init_proc init_bignose;
    extern  init_proc init_fisheye;
    extern  init_proc init_dali;
    extern  init_proc init_andrew;
    extern  init_proc init_twist;
    extern  init_proc init_kentwist;
    extern  init_proc init_escher;
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
}


- (void) addMiscTransforms {
    [categoryNames addObject:@"Misc. transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
#ifdef notdef
    extern  transform_t do_diff;
    extern  transform_t do_logo;
    extern  transform_t do_color_logo;
    extern  transform_t do_spectrum;
#endif
}


// used by colorize

channel rl[31] = {0,0,0,0,0,0,0,0,0,0,        5,10,15,20,25,Z,Z,Z,Z,Z,    0,0,0,0,0,5,10,15,20,25,Z};
channel gl[31] = {0,5,10,15,20,25,Z,Z,Z,Z,    Z,Z,Z,Z,Z,Z,Z,Z,Z,Z,        25,20,15,10,5,0,0,0,0,0,0};
channel bl[31] = {Z,Z,Z,Z,Z,25,15,10,5,0,    0,0,0,0,0,5,10,15,20,25,    5,10,15,20,25,Z,Z,Z,Z,Z,Z};

- (void) addColorTransforms {
    [categoryNames addObject:@"Color transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    [transformList addObject:[Transform colorTransform: @"Luminance"
                                           description: @"Convert to brightness"
                                        pointTransform: ^(Pixel *p, size_t n) {
        while (n-- > 0) {
            channel lum = LUM(*p);
            *p++ = SETRGB(lum, lum, lum);
        }
    }]];
    
    [transformList addObject:[Transform colorTransform: @"Brighten"
                                           description: @"Make brighter"
                                        pointTransform: ^(Pixel *pp, size_t n) {
        while (n-- > 0) {
            Pixel p = *pp;
            *pp++ = SETRGB(p.r+(Z-p.r)/8,
                           p.g+(Z-p.g)/8,
                           p.b+(Z-p.b)/8);
        }
    }]];
    
    [transformList addObject:[Transform colorTransform: @"Colorize"
                                           description: @"Add color"
                                        pointTransform: ^(Pixel *pp, size_t n) {
        while (n-- > 0) {
            Pixel p = *pp;
            channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&(Z >> 3);
            *pp++ = SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
        }
    }]];
    
    [transformList addObject:[Transform colorTransform: @"Green"
                                           description: @"Set to green"
                                        pointTransform: ^(Pixel *pp, size_t n) {
        while (n-- > 0) {
            *pp++ = SETRGB(0,Z,0);
        }
    }]];
}

- (void) addArtTransforms {
    [categoryNames addObject:@"Art-style transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
#ifdef notdef
extern  init_proc init_seurat;
extern  init_proc init_dali;
extern  init_proc init_escher;
#endif
}

#ifdef notdef
extern  init_proc init_cone;
extern  init_proc init_bignose;
extern  init_proc init_fisheye;
extern  init_proc init_andrew;
extern  init_proc init_twist;
extern  init_proc init_kentwist;
extern  init_proc init_slicer;

extern  init_proc init_colorize;
extern  init_proc init_swapcolors;
extern  init_proc init_lum;
extern  init_proc init_high;
extern  init_proc init_lum;
extern  init_proc init_solarize;
extern  init_proc init_truncatepix;
extern  init_proc init_brighten;
extern  init_proc init_auto;
extern  init_proc init_negative;

extern  void init_polar(void);
#endif

#ifdef notdef

#define CRGB(r,g,b)     SETRGB(CLIP(r), CLIP(g), CLIP(b))
#define HALF_Z          (Z/2)

#define Remap_White     (-1)
#define Remap_Black     (-2)

typedef Point remap[MAX_X][MAX_Y];
typedef void *init_proc(void);

/* in trans.c */
extern  int irand(int i);
extern  int ptinrect(Point p, Rectangle r);

extern  void init_polar(void);

extern  transform_t do_point;

extern  transform_t do_bleed;
extern  transform_t do_slicer;
extern  transform_t do_melt;
extern  transform_t do_smear;
extern  transform_t monet;
extern  transform_t do_seurat;
extern  transform_t do_crazy_seurat;

extern  transform_t do_new_oil;
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
lsc_button(BELOW, "solar", do_point, init_solarize);
lsc_button(BELOW, "colorize", do_point, init_colorize);
lsc_button(BELOW, "outline", do_sobel, 0);
lsc_button(BELOW, "raisedgray", do_edge, 0);

lsc_button(BELOW, "bigpixels", do_remap, init_pixels4);
lsc_button(BELOW, "blur", do_blur, 0);
lsc_button(BELOW, "blurry", do_brownian, 0);
lsc_button(BELOW, "focus", do_focus, 0);
lsc_button(BELOW, "bleed", do_bleed, 0);
lsc_button(BELOW, "oilpaint", do_new_oil, 0);
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
{"Solarize", init_solarize, do_point, "solarize", "", 0, POINT_COLOR},
{"Colorize", init_colorize, do_point, "colorize", "", 0, POINT_COLOR},
{"Swap colors", init_swapcolors, do_point, "swap", "colors", 0, POINT_COLOR},
{"Pixels",    init_pixels4, do_remap, "big", "pixels", 0, POINT_COLOR},
{"Brownian pixels", 0, do_brownian, "Brownian", "pixels", 0, POINT_COLOR},

#define AREACOL        2
{"Blur",         0, do_blur, "blur", "", 1, AREA_COLOR},
{"Bleed",        0, do_bleed, "bleed", "", 0, AREA_COLOR},
{"Oil",            0, do_new_oil, "Oil", "paint", 0, AREA_COLOR},
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
{"Cone projection",    init_cone, do_remap, "Pinhead", "", 0, GEOM_COLOR},
{"Terry's kite",    init_kite, do_remap, "Terry's", "kite", 0, GEOM_COLOR},

{"Rotate right",    init_rotate_right, do_remap, "rotate", "right", 1, GEOM_COLOR},
{"Shift right",        init_shift_right, do_remap, "shift", "right", 0, GEOM_COLOR},
{"Copy right",         init_copy_right, do_remap, "copy", "right", 0, GEOM_COLOR},
{"Twist right",        init_twist, do_remap, "Edward", "Munch", 0, GEOM_COLOR},
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
{"Can",            (proc)do_polar, (subproc)can, GS, "Can", "", 0, OTHER_COLOR},
{"Pg",            (proc)do_polar, (subproc)pg, GS, "Pg", "", 0, OTHER_COLOR},
{"Skrunch",        (proc)do_polar, (subproc)skrunch, GS, "Scrunch", "", 0, OTHER_COLOR},
{"test", 0, cartoon, "Warhol", "", , 0, NEW},
{"Seurat?", 0, do_cfs, "Matisse", "", 0, NEW},
{"Slicer", 0, do_slicer, "Picasso", "", 0, OTHER_COLOR},
{"Neg", 0, do_neg_sobel, "Surreal", "", 0, NEW},
{"Dali", init_dali, do_remap, "Dali", "", 1, AREA_COLOR},
{"Munch 2", init_kentwist, do_remap, "Edward", "Munch 2", 0, AREA_COLOR},
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
    extern  init_proc init_solarize;
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
    
