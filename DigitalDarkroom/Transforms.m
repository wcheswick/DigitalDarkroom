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
#import "Defines.h"

// #define DEBUG_TRANSFORMS    1   // bounds checking and a lot of assertions

#define SETRGBA(r,g,b,a)   (Pixel){b,g,r,a}
#define SETRGB(r,g,b)   SETRGBA(r,g,b,Z)
#define Z               ((1<<sizeof(channel)*8) - 1)
#define HALF_Z          (Z/2)

#define CENTER_X        (W/2)
#define CENTER_Y        (H/2)

#define Black           SETRGB(0,0,0)
#define Grey            SETRGB(Z/2,Z/2,Z/2)
#define LightGrey       SETRGB(2*Z/3,2*Z/3,2*Z/3)
#define White           SETRGB(Z,Z,Z)
#define Red             SETRGB(Z,0,0)
#define Green           SETRGB(0,Z,0)
#define Blue            SETRGB(0,0,Z)
#define Yellow          SETRGB(Z,Z,0)
#define UnsetColor      (Pixel){Z,Z/2,Z,Z-1}

#define LUM(p)  (channel)((((p).r)*299 + ((p).g)*587 + ((p).b)*114)/1000)
#define CLIP(c) ((c)<0 ? 0 : ((c)>Z ? Z : (c)))
#define CRGB(r,g,b)     SETRGB(CLIP(r), CLIP(g), CLIP(b))

#define R(x) (x).r
#define G(x) (x).g
#define B(x) (x).b

enum SpecialRemaps {
    Remap_White = -1,
    Remap_Red = -2,
    Remap_Green = -3,
    Remap_Blue = -4,
    Remap_Black = -5,
    Remap_Yellow = -6,
    Remap_Unset = -7,
};

@interface Transforms ()

@property (strong, nonatomic)   NSMutableArray *executeList;
@property (strong, nonatomic)   Transform *lastTransform;

@end

static int W, H;   // local size values, easy for C routines

size_t configuredBytesPerRow, configuredPixelsInImage, configuredPixelsPerRow;

Pixel *imBufs[2];
channel **sChan = 0;
channel **dChan = 0;
int chanColumns = 0;

#define RPI(x,y)    (PixelIndex_t)(((y)*configuredPixelsPerRow) + (x))

#ifdef DEBUG_TRANSFORMS
// Some of our transforms might be a little buggy around the edges.  Make sure
// all the indicies are in range.

#define PI(x,y)   dPI((int)(x),(int)(y))   // pixel index in a buffer

PixelIndex_t dPI(int x, int y) {
    assert(x >= 0);
    assert(x < W);
    assert(y >= 0);
    assert(y < H);
    PixelIndex_t index = RPI(x,y);
    assert(index >= 0 && index < configuredPixelsInImage);
    return index;
}

#else
#define PI(x,y)   RPI((x),(y))
#endif

@implementation Transforms

@synthesize categoryNames;
@synthesize categoryList;
@synthesize sequence, sequenceChanged;
@synthesize executeList;
@synthesize bytesPerRow;
@synthesize lastTransform;
@synthesize finalScale;
@synthesize debugTransforms;
@synthesize depthTransform;
@synthesize transformSize;
@synthesize flatTransformList;


- (id)init {
    self = [super init];
    if (self) {
#ifdef DEBUG_TRANSFORMS
        debugTransforms = YES;
#else
        debugTransforms = NO;
#endif
        depthTransform = nil;
        configuredBytesPerRow = 0;    // no current configuration
        categoryNames = [[NSMutableArray alloc] init];
        categoryList = [[NSMutableArray alloc] init];
        sequence = [[NSMutableArray alloc] init];
        flatTransformList = [[NSMutableArray alloc] init];
        sequenceChanged = YES;
        finalScale = 1.0;
        imBufs[0] = imBufs[1] = NULL;
        executeList = [[NSMutableArray alloc] init];
        [self buildTransformList];
    }
    return self;
}

- (void) depthToPixels: (DepthImage *)depthImage pixels:(Pixel *)depthPixelVisImage {
    assert(depthTransform);
    assert(depthImage.size.width == transformSize.width);
    assert(depthImage.size.height == transformSize.height);
    //transformSize = depthImage.size;
    H = transformSize.height;
    W = transformSize.width;
    depthTransform.depthVisF(depthImage, depthPixelVisImage, depthTransform.value);
}

#ifdef OLD
#define PIXEL_EQ(p1,p2)   ((p1).r == (p2).r && (p1).g == (p2).g && (p1).b == (p2).b)

float RGBtoDistance(Pixel p) {
    if (PIXEL_EQ(p, Black))
        return MAX_DIST;
    else if (PIXEL_EQ(p, Red))
        return MIN_DIST;
    UInt32 cv = ((p.r * 256) + p.g)*256 + p.b;
    float frac = (float)cv / RGB_SPACE;
    float v = frac*(MAX_DIST - MIN_DIST) + MIN_DIST;
    return v;
}
#endif

- (void) buildTransformList {
    [self addDepthVisualizations];
//    [self addColorVisionDeficits];
    [self addGeometricTransforms];
    [self addPointTransforms];
    [self addMiscTransforms];
    // tested:
    [self addAreaTransforms];
    [self addArtTransforms];
    [self addMonochromes];
    [self addOldies];
}

- (PixelIndex_t *) computeMappingFor:(Transform *) transform {
    assert(configuredBytesPerRow);
    assert(transform.type == RemapTrans);
    NSLog(@"remap %@", transform.name);
    PixelIndex_t *remapTable = (PixelIndex_t *)calloc(configuredPixelsInImage, sizeof(PixelIndex_t));
    
#ifdef DEBUG_TRANSFORMS
    for (int i=0; i<configuredPixelsInImage; i++)
        remapTable[i] = Remap_Unset;
#endif
    transform.remapTable = remapTable;

    if (transform.remapPolarF) {     // polar remap
        size_t centerX = W/2;
        size_t centerY = H/2;
        for (int dx=0; dx<centerX; dx++) {
            for (int dy=0; dy<centerY; dy++) {
                double r = hypot(dx, dy);
                double a;
                if (dx == 0 && dy == 0)
                    a = 0;
                else
                    a = atan2(dy, dx);
                remapTable[PI(centerX-dx, centerY-dy)] = transform.remapPolarF(r, M_PI + a, transform.value);
                if (centerY+dy < H)
                    remapTable[PI(centerX-dx, centerY+dy)] = transform.remapPolarF(r, M_PI - a, transform.value);
                if (centerX+dx < W) {
                    if (centerY+dy < H)
                        remapTable[PI(centerX+dx, centerY+dy)] = transform.remapPolarF(r, a, transform.value);
                    remapTable[PI(centerX+dx, centerY-dy)] = transform.remapPolarF(r, -a, transform.value);
                }
            }
        }

#ifdef OLDNEW
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                double rx = x - centerX;
                double ry = y - centerY;
                double r = hypot(rx, ry);
                double a = atan2(ry, rx);
                remapTable[PI(x,y)] = transform.remapPolarF(r, /* M_PI+ */ a,
                                                            transform.p,
                                                            W,
                                                            H);
            }
        }
#endif
    } else {        // whole screen remap
        NSLog(@"transform: %@", transform);
        transform.remapImageF(remapTable,
                              W, H,
                              transform.value);
    }
    return remapTable;
}


// It is important that the user interface doesn't change the transform list
// while we are running through it.  There are several changes of interest:
//  1) adding or deleting one or more transforms
//  2) changing the parameter on a particular transform
//  3) changing the display area size (via source or orientation change
//
// The master list of transforms to be executed is 'sequence', and is managed by
// the GUI. We can't run from this list, because a change in the middle of transforming would
// mess up everything.
//
// So the GUI changes this sequence as it wants to, using @synchronize on the array. It sets
// a flag, sequenceChanged, when changes occur.  Right here, just before we run through a
// transform sequence, we check for changes, and update our current transform sequence,
// 'executeList' from a locked copy of the sequence list.
//
// We keep our own local list of current transforms, and keep the parameters
// for each (a transform could appear more than once, with different params.)
//
// A number of transforms simply involve moving pixels around just based on position.
// we recompute the table of pixel indicies and just use that.  That table needs to
// be computed the first time the transform is used, whenever the param changes, or
// when the screen size changes.  If it needs updating, the table pointer is NULL.
// Only this routine changes this pointer.


int sourceImageIndex, destImageIndex;

BOOL transformsBusy = NO;

- (UIImage * __nullable) executeTransformsWithImage:(UIImage *) image {
    if (transformsBusy) {
        return nil; // drop frame
    }
    transformsBusy = YES;
    
    if (sequenceChanged) {
        [executeList removeAllObjects];
        
        @synchronized (sequence) {
            for (Transform *t in sequence) {
                if (t.newValue) {
                    [t clearRemap];
                    t.newValue = NO;
                }
                [executeList addObject:t];
            }
        }
        sequenceChanged = NO;
    } else {
        @synchronized (sequence) {
            for (Transform *t in sequence) {
                if (t.newValue) {
                    [t clearRemap];
                    t.newValue = NO;
                }
            }
        }
    }
    
    CGImageRef imageRef = [image CGImage];
    CGImageRetain(imageRef);
    UIImageOrientation incomingOrientation = image.imageOrientation;
    
    size_t width = (int)CGImageGetWidth(imageRef);
    size_t height = (int)CGImageGetHeight(imageRef);
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    assert(bitsPerPixel/8 == sizeof(Pixel));
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    assert(bitsPerComponent == 8);
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    assert(bytesPerRow);
    size_t pixelsInImage = (bytesPerRow * height)/sizeof(Pixel);

    if (configuredBytesPerRow != bytesPerRow ||
        pixelsInImage != configuredPixelsInImage ||
        W != width ||
        H != height) {
        NSLog(@">>> format was %4zu %4d %4d   %4zu %4zu %4zu",
              configuredBytesPerRow,
              W,
              H,
              bytesPerRow, width, height);
        if (sChan) {    // release previous memory
            for (int x=0; x<chanColumns; x++) {
                free((void *)sChan[x]);
                free((void *)dChan[x]);
            }
            chanColumns = 0;
        }
        configuredBytesPerRow = bytesPerRow;    // ** may be larger than width*sizeof(Pixel)
        assert(configuredBytesPerRow % sizeof(Pixel) == 0); // ensure 32-bit boundary
        configuredPixelsPerRow = configuredBytesPerRow / sizeof(Pixel);
        configuredPixelsInImage = pixelsInImage;
        H = transformSize.height;
        W = transformSize.width;
        for (Transform *t in executeList) {
            [t clearRemap];
        }
        
        // reallocate source and destination image buffers
        NSLog(@" ** reallocate image buffers to new size");
        for (int i=0; i<2; i++) {
            if (imBufs[i])
                free(imBufs[i]);
            imBufs[i] = (Pixel *)calloc(configuredPixelsInImage, sizeof(Pixel));
        }
        // also allocate a channel-sized buffer, for single channel ops

        chanColumns = W;
        sChan = (channel **)malloc(chanColumns*sizeof(channel *));
        dChan = (channel **)malloc(chanColumns*sizeof(channel *));
        for (int x=0; x<W; x++) {
            sChan[x] = (channel *)malloc(H*sizeof(channel));
            dChan[x] = (channel *)malloc(H*sizeof(channel));
        }
        NSLog(@">>>         is %4zu %4d %4d   %4zu %4zu %4zu",
              configuredBytesPerRow,
              W,
              H,
              bytesPerRow, width, height);
    }
    
    int sourceImageIndex = 0;
    int destImageIndex = 1;

    assert(W == width);
    assert(H == height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRetain(colorSpace);
    CGContextRef context = CGBitmapContextCreate(imBufs[sourceImageIndex], width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 BITMAP_OPTS);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    
    NSDate *transformStart = [NSDate now];
    for (int i=0; i<executeList.count; i++) {
        Transform *transform = [executeList objectAtIndex:i];
        
        [self performTransform:transform
                          from:imBufs[sourceImageIndex]
                            to:imBufs[destImageIndex]
                        height:height
                         width:width];
        int t = sourceImageIndex;     // swap
        sourceImageIndex = destImageIndex;
        destImageIndex = t;
        NSDate *transformEnd = [NSDate now];
        transform.elapsedProcessingTime += [transformEnd timeIntervalSinceDate:transformStart];
        transformStart = transformEnd;
    }
    
    // copy our bytes into the context.  This is a kludge.
    
    if (sourceImageIndex) {
        memcpy(imBufs[0], imBufs[sourceImageIndex], configuredPixelsInImage*sizeof(Pixel));
    }
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    UIImage *transformed = [UIImage imageWithCGImage:quartzImage
                                               scale:finalScale
                                         orientation:incomingOrientation];

    //UIImage *transformed = [UIImage imageWithCGImage:quartzImage];
    
    CGImageRelease(quartzImage);
    CGContextRelease(context);
    transformsBusy = NO;
    return transformed;
}

- (void) performTransform:(Transform *)transform
                     from:(Pixel *)srcBuf
                       to:(Pixel *)dstBuf
                   height:(size_t) h
                    width:(size_t) w {
    switch (transform.type) {
        case ColorTrans: {
            for (int i=0; i<configuredPixelsInImage; i++) {
                dstBuf[i] = transform.pointF(srcBuf[i]);
            }
            return;
        }
        case GeometricTrans:
        case RemapTrans:
            if (!transform.remapTable) {
                transform.remapTable = [self computeMappingFor:transform];
            }
            for (int i=0; i<configuredPixelsInImage; i++) {
                PixelIndex_t pixelSource = transform.remapTable[i];
                Pixel p;
                switch (pixelSource) {
                    case Remap_White:
                        p = White;
                        break;
                    case Remap_Red:
                        p = Red;
                        break;
                    case Remap_Green:
                        p = Green;
                        break;
                    case Remap_Blue:
                        p = Blue;
                        break;
                    case Remap_Black:
                        p = Black;
                        break;
                    case Remap_Yellow:
                        p = Yellow;
                        break;
                    case Remap_Unset:
                        p = UnsetColor;
                        break;
                    default:
                        p = srcBuf[pixelSource];
                }
                dstBuf[i] = p;
            }
            break;
        case AreaTrans:
            transform.areaF(srcBuf, dstBuf, transform.value);
            break;
        case DepthVis:
            /// should not be reached
            break;
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
    }
}

#ifdef OLD
/* Monochrome floyd-steinberg */

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

#define ADD_TO_OLIVE(t)     [flatTransformList addObject:t];

- (void) addAreaTransforms {
    [categoryNames addObject:@"Area"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    lastTransform = [Transform areaTransform: @"Shear"
                                                  description: @"Shear"
                                                areaFunction: ^(Pixel *src, Pixel *dest, int p) {
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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);
    
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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

#ifdef OLD
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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);
#endif
    
    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @""
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        channel lum[W][H];
        for (int y=1; y<H-1; y++)
            for (int x=1; x<W-1; x++)
                lum[x][y] = LUM(src[PI(x,y)]);

        for (int y=1; y<H-1; y++) {
            for (int x=1; x<W-1; x++) {
                channel aa, bb, s;
                aa = lum[x-1][y-1] + 2*lum[x][y-1] + lum[x+1][y-1] -
                     lum[x-1][y+1] - 2*lum[x][y+1] - lum[x+1][y+1];
                bb = lum[x-1][y-1] + 2*lum[x-1][y] + lum[x-1][y+1] -
                     lum[x+1][y-1] - 2*lum[x+1][y] - lum[x+1][y+1];

                channel c;
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    c = Z;
                else
                    c = s;
                dest[PI(x,y)] = SETRGB(c,c,c);
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Terry's kite"
                                 description: @"Designed by an 8-year old"
                                  remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int p) {
        size_t centerY = h/2;
        size_t centerX = w/2;
        for (int y=0; y<h; y++) {
            size_t ndots;
            
            if (y <= centerY)
                ndots = (y*(w-1))/h;
            else
                ndots = ((h-y-1)*(w))/h;

            table[PI(centerX,y)] = PI(centerX,y);
            table[PI(0,y)] = Remap_White;
            
            for (int x=1; x<=ndots; x++) {
                size_t dist = (x*(CENTER_X-1))/ndots;

                table[PI(centerX+x,y)] = PI(centerX + dist,y);
                table[PI(centerX-x,y)] = PI(centerX - dist,y);
            }
            for (size_t x=ndots; x<centerX; x++) {
                table[PI(centerX+x,y)] = Remap_White;
                table[PI(centerX-x,y)] = Remap_White;
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Pixelate"
                                  description: @"Giant pixels"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t y, int pixsize) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                table[PI(x,y)] = PI((x/pixsize)*pixsize, (y/pixsize)*pixsize);
            }
        }
    }];
    lastTransform.low = 4;
    lastTransform.value = 6;
    lastTransform.high = 200;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Mirror"
                                  description: @"Reflect the image"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int pixsize) {
        for (int y=0; y<h; y++) {
            for (int x=0; x<w; x++) {
                table[PI(x,y)] = PI(w - x - 1,y);
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Mirror right"
                                 description: @"Reflect the right half of the screen on the left"
                                  remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int pixsize) {
        for (int y=0; y<h; y++) {
            for (int x=0; x<w; x++) {
                if (x < w/2)
                    table[PI(x,y)] = PI(w - x - 1,y);
                else
                    table[PI(x,y)] = PI(x,y);
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Color Sobel"
                                          description: @"Edge detection"
                                        areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int p) {
        for (int y=0; y<H; y++) {    // red
            for (int x=0; x<W; x++) {
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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

#ifdef notyet
    extern  transform_t do_fs1;
    extern  transform_t do_fs2;
    extern  transform_t do_sampled_zoom;
    extern  transform_t do_mean;
    extern  transform_t do_median;
#endif
}

- (void) selectDepthTransform:(int)index {
    if (index == NO_DEPTH_TRANSFORM) {
        depthTransform = nil;
        return;
    }
    NSArray *depthTransformList = [categoryList objectAtIndex:DEPTH_TRANSFORM_SECTION];
    depthTransform = [depthTransformList objectAtIndex:index];
}

- (void) addDepthVisualizations {
    [categoryNames addObject:@"Depth visuals"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    assert(categoryList.count - 1 == DEPTH_TRANSFORM_SECTION);
    
#ifdef DEBUG_TRANSFORMS
#define DIST(x,y)  [depthImage distAtX:(x) Y:(y)]
#else
#define DIST(x,y)  depthImage.buf[(x) + (y)*(int)depthImage.size.width]
#endif
   
    lastTransform = [Transform depthVis: @"Monochrome dist."
                            description: @""
                               depthVis: ^(DepthImage *depthImage, Pixel *dest, int v) {
        size_t bufSize = H*W;
        assert(depthImage.size.height * depthImage.size.width == bufSize);
        for (int i=0; i<bufSize; i++) {
            Distance v = depthImage.buf[i];
            float frac = (v - MIN_DEPTH)/(MAX_DEPTH - MIN_DEPTH);
            channel c = trunc(Z - frac*Z);
            Pixel p = SETRGB(0,0,c);
            dest[i] = p;
        }
    }];
    [transformList addObject:lastTransform];

    lastTransform = [Transform depthVis: @"Monochrome log dist."
                            description: @""
                               depthVis: ^(DepthImage *depthImage, Pixel *dest, int v) {
        size_t bufSize = H*W;
        assert(depthImage.size.height * depthImage.size.width == bufSize);
        assert(MIN_DEPTH >= 0.1);
        float logMin = log(MIN_DEPTH);
        float logMax = log(MAX_DEPTH);
        for (int i=0; i<bufSize; i++) {
            Distance d = depthImage.buf[i];
            if (d < MIN_DEPTH)
                d = MIN_DEPTH;
            else if (d > MAX_DEPTH)
                d = MAX_DEPTH;
            float v = log(d);
            float frac = (v - logMin)/(logMax - logMin);
            channel c = trunc(Z - frac*Z);
            Pixel p = SETRGB(0,0,c);
            dest[i] = p;
        }
    }];
    [transformList addObject:lastTransform];

    lastTransform = [Transform depthVis: @"Near depth"
                            description: @""
                               depthVis: ^(DepthImage *depthImage, Pixel *dest, int v) {
        size_t bufSize = H*W;
        assert(depthImage.size.height * depthImage.size.width == bufSize);
        float mincm = 10.0;
        float maxcm = mincm + 100.0;
        float depthcm = maxcm - mincm;
        for (int i=0; i<bufSize; i++) {
            Distance d = depthImage.buf[i];
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
            dest[i] = p;
        }
    }];
//    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
//    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];

#define RGB_SPACE   ((float)((1<<24) - 1))

    lastTransform = [Transform depthVis: @"Encode depth"
                            description: @""
                               depthVis: ^(DepthImage *depthImage, Pixel *dest, int v) {
        size_t bufSize = H*W;
        assert(depthImage.size.height * depthImage.size.width == bufSize);
        float min = MAX_DEPTH;
        float max = MIN_DEPTH;
        for (int i=0; i<bufSize; i++) {
            Distance v = depthImage.buf[i];
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
            dest[i] = p;
        }
    }];
    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    
    // plywood?
    
    // apple's encoding?
    
    //" random dot anaglyph github"
    // in python: https://github.com/sashaperigo/random-dot-stereogram/blob/master/README.md
    // no, image only
    
    //[1] Zhaoping L, Ackermann J. Reversed Depth in Anticorrelated Random-Dot Stereograms and the Central-Peripheral Difference in Visual Inference[J]. Perception, 2018, 47(5): 531-539.
    
    // simple SIRDS:  https://github.com/arkjedrz/stereogram.git
    
    // another: https://github.com/CoolProgrammingUser/stereograms.git
    
    // promising anaglyph: https://github.com/JanosRado/StereoMonitorCalibration.git
    

#ifdef notyet
    lastTransform = [Transform depthVis: @"3D level visualization"
                                 description: @""
                                depthVis: ^(DepthImage *depthImage, Pixel *dest, int v) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                Pixel p;
                Distance z = DIST(x,y);
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
                dest[PI(x,y)] = p;
            }
        }
    }];
    lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
#endif
    
    
#define mu (1/3.0)
//#define E round(2.5*dpi)
#define E round(dpi)
#define separation(Z) round((1-mu*(Z))*E/(2-mu*(Z)))
#define FARAWAY separation(0)
    
    // SIDRS computation taken from
    // https://courses.cs.washington.edu/courses/csep557/13wi/projects/trace/extra/SIRDS-paper.pdf
    lastTransform = [Transform depthVis: @"SIRDS (broken)"
                            description: @""
                               depthVis: ^(DepthImage *depthImage, Pixel *dest, int v) {
        float scale = 1;
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
            scale = [[UIScreen mainScreen] scale];
        }
        float dpi = (640/8.3) * scale;
        
        // scale the distances from MIN - MAX to mu - 0, near to far.
#define MAX_S_DEP MAX_DEPTH // 2.0
#define MIN_S_DEP   0   // MIN_DEPTH
        
        for (int i=0; i<depthImage.size.width * depthImage.size.height; i++) {
            float z = depthImage.buf[i];
            if (z > MAX_S_DEP)
                z = MAX_S_DEP;
            else if (z < MIN_S_DEP)
                z = MIN_S_DEP;
            float dz = (z - MIN_DEPTH)/(MAX_S_DEP - MIN_S_DEP);
            float dfz = mu - dz*mu;
            assert(dfz <= mu && dfz >= 0);
            depthImage.buf[i] = dfz;
        }
        
        for (int y=0; y<H; y++) {    // convert scan lines independently
            channel pix[W];
            //  Points to a pixel to the right ... */ /* ... that is constrained to be this color:
            int same[W];
            int s;  // stereo sep at this point
            int left, right;    // x values for left and right eyes
            
            for (int x=0; x < W; x++ ) {  // link initial pixels with themselves
                same[x] = x;
            }
            for (int x=0; x < W; x++ ) {
                float z = DIST(x,y);
                s = separation(z);
                left = x - s/2;
                right = left + s;   // pixels at left and right must be the same
                if (left >= 0 && right < W) {
                    int visible;    // first, perform hidden surface removal
                    int t = 1;      // We will check the points (x-t,y) and (x+t,y)
                    Distance zt;       //  Z-coord of ray at these two points
                    
                    do {
                        zt = DIST(x,y) + 2*(2 - mu*DIST(x,y))*t/(mu*E);
                        BOOL inRange = (x-t >= 0) && (x+t < W);
                        visible = inRange && DIST(x-t,y) < zt && DIST(x+t,y) < zt;  // false if obscured
                        t++;
                    } while (visible && zt < 1);    // end of hidden surface removal
                    if (visible) {  // record that pixels at l and r are the same
                        assert(left >= 0 && left < W);
                        int l = same[left];
                        assert(l >= 0 && l < W);
                        while (l != left && l != right) {
                            if (l < right) {    // first, jiggle the pointers...
                                left = l;       // until either same[left] == left
                                assert(left >= 0 && left < W);
                                l = same[left]; // .. or same[left == right
                                assert(l >= 0 && l < W);
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
                    pix[x] = random()&1;  // free choice, do it randomly
                else
                    pix[x] = pix[same[x]];  // constrained choice, obey constraint
                dest[PI(x,y)] = pix[x] ? Black : White;
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
        int lx = W/2 - FARAWAY/2 - NW/2;
        int rx = W/2 + FARAWAY/2 - NW/2;
        for (int dy=0; dy<6; dy++) {
            for (int dx=0; dx<NW; dx++) {
                dest[PI(lx+dx,BOTTOM_Y+dy)] = Yellow;
                dest[PI(rx+dx,BOTTOM_Y+dy)] = Yellow;
            }
        }
    }];
    //lastTransform.low = 1; lastTransform.value = 5; lastTransform.high = 20;
    //lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    
#ifdef SPECTRUMTEST
    
    for (int di=0; di < 100; di++) {
        Distance d;
        if (di % 10 == 0)
            d = -1.0;
        else
            d = (float)di/10.0;
        for (int i=0; i<5; i++) {
            int x = di*5 + i;
            for (int y=0; y<height; y++) {
                DI(x,y) = d;
            }
        }
    }
#endif

}

// used by colorize

channel rl[31] = {0,0,0,0,0,0,0,0,0,0,        5,10,15,20,25,Z,Z,Z,Z,Z,    0,0,0,0,0,5,10,15,20,25,Z};
channel gl[31] = {0,5,10,15,20,25,Z,Z,Z,Z,    Z,Z,Z,Z,Z,Z,Z,Z,Z,Z,        25,20,15,10,5,0,0,0,0,0,0};
channel bl[31] = {Z,Z,Z,Z,Z,25,15,10,5,0,    0,0,0,0,0,5,10,15,20,25,    5,10,15,20,25,Z,Z,Z,Z,Z,Z};

- (void) addPointTransforms {
    [categoryNames addObject:@"Point"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];

    lastTransform = [Transform areaTransform: @"Negative"
                                 description: @"Negative"
                                areaFunction: ^(Pixel *src, Pixel *dest, int p) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                Pixel p = src[PI(x,y)];
                dest[PI(x,y)] = SETRGB(Z-p.r, Z-p.g, Z-p.b);
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Solarize"
                                 description: @"Simulate extreme overexposure"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                PixelIndex_t pi = PI(x,y);
                Pixel p = src[pi];
                dest[pi] = SETRGB(p.r < Z/2 ? p.r : Z-p.r,
                                       p.g < Z/2 ? p.g : Z-p.g,
                                       p.b < Z/2 ? p.b : Z-p.r);
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Luminance"
                                 description: @"Convert to brightness"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        // 5.2ms
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = *src++;
            int v = LUM(p);
            *dest++ = SETRGB(v,v,v);
        }
#ifdef notdef
        // 5.4ms
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            int v = LUM(src[pi]);
            dest[pi] = SETRGB(v,v,v);
        }
        // 6ms:
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                PixelIndex_t pi = PI(x,y);
                Pixel p = src[pi];
                int v = LUM(p);
                dest[pi] = SETRGB(v,v,v);
            }
        }
#endif
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Colorize"
                                 description: @"Add color"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                Pixel p = src[PI(x,y)];
                channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&(Z >> 3);
                dest[PI(x,y)] = SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
            }
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Truncate pixels"
                                 description: @"Truncate pixel colors"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        channel mask = ((1<<param) - 1) << (8 - param);
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = *src++;
            *dest++ = SETRGB(p.r&mask, p.g&mask, p.b&mask);
        }
    }];
    lastTransform.low = 1; lastTransform.value = 3; lastTransform.high = 7;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Brighten"
                                 description: @"brighten"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = *src++;
            *dest++ = SETRGB(p.r+(Z-p.r)/8,
                             p.g+(Z-p.g)/8,
                             p.b+(Z-p.b)/8);
        }
    }];
#ifdef notdef
    lastTransform.low = 1; lastTransform.value = 3; lastTransform.high = 7;
    lastTransform.hasParameters = YES;
#endif
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"High contrast"
                                 description: @"high contrast"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = *src++;
            *dest++ = SETRGB(CLIP((p.r-HALF_Z)*2+HALF_Z),
                             CLIP((p.g-HALF_Z)*2+HALF_Z),
                             CLIP((p.b-HALF_Z)*2+HALF_Z));
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Swap colors"
                                 description: @"r→g, g→b, b→r"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = *src++;
            *dest++ = SETRGB(p.g, p.b, p.r);
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Auto contrast"
                                 description: @"auto contrast"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        u_long ps;
        u_long hist[Z+1];
        float map[Z+1];
        
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = src[pi];
            hist[LUM(p)]++;
        }
        ps = 0;
        for (int i = 0; i < Z+1; i++) {
            map[i] = Z*((float)ps/((float)configuredPixelsInImage));
            ps += hist[i];
        }
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = src[pi];
            channel l = LUM(p);
            float a = (map[l] - l)/Z;
            int r = p.r + (a*(Z-p.r));
            int g = p.g + (a*(Z-p.g));
            int b = p.b + (a*(Z-p.b));
            dest[pi] = CRGB(r,g,b);
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);
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
    [categoryNames addObject:@"Old routines"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
}

-(void) addMonochromes {
    [categoryNames addObject:@"Monochromes"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];

    lastTransform = [Transform colorTransform:@"Desaturate" description:@"desaturate" pointTransform:^Pixel(Pixel p) {
        channel c = (max3(p) + min3(p))/2;
        return SETRGB(c,c,c);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Max decomposition" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = max3(p);
        return SETRGB(c,c,c);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Min decomposition" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = min3(p);
        return SETRGB(c,c,c);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Ave" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = (p.r + p.g + p.b)/3;
        return SETRGB(c,c,c);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"NTSC monochrome" description:@"" pointTransform:^Pixel(Pixel p) {
        channel c = (299*p.r + 587*p.g + 114*p.b)/1000;
        return SETRGB(c,c,c);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Red channel" description:@"" pointTransform:^Pixel(Pixel p) {
        return SETRGB(p.r,0,0);
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform colorTransform:@"Green channel" description:@"" pointTransform:^Pixel(Pixel p) {
        return SETRGB(0,p.g,0);
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform colorTransform:@"Blue channel" description:@"" pointTransform:^Pixel(Pixel p) {
        return SETRGB(0,0,p.b);
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    // move image
    
}

#define CenterX (W/2)
#define CenterY (H/2)
#define MAX_R   (MAX(CenterX, CenterY))

#define INRANGE(x,y)    (x >= 0 && x < W && y >= 0 && y < H)

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

- (void) addGeometricTransforms {
    [categoryNames addObject:@"Geometric"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

#define CPP    20    /*cycles/picture*/

    lastTransform = [Transform areaTransform: @"Wavy shower"
                                  description: @"Through wavy glass"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int D) {
        for (int y=0; y<H; y++)
            for (int x=0; x<W; x++)
                table[PI(x,y)] = PI(x,y);
        for (int y=0; y<H; y++)
            for (int x=0+D; x<W-D; x++)
                table[PI(x,y)]  = PI(x+(int)(D*sin(CPP*x*2*M_PI/W)), y);
    }];
    lastTransform.low = 4;
    lastTransform.value = 23;
    lastTransform.high = 30;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];

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
    [transformList addObject:lastTransform];

    lastTransform = [Transform areaTransform: @"Zoom"
                                  description: @""
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int z) {
        float zoom = z/10.0;
        for (int y=0; y<H; y++) {
            for (int x=0; x<W; x++) {
                long sx = CENTER_X + (x-CENTER_X)/zoom;
                long sy = CENTER_Y + (y-CENTER_Y)/zoom;
                table[PI(x,y)] = PI(sx,sy);
            }
    }
    }];
    lastTransform.low = 1;
    lastTransform.value = 2;
    lastTransform.high = 10;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"convolution sobel filter "
                                description: @"Edge detection"
                               areaFunction: ^(Pixel *src, Pixel *dest, int p) {
        for (int i=0; i<configuredPixelsInImage; i++) {
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
        
        for (int i=0; i<configuredPixelsInImage; i++) {
            dest[i] = SETRGB(src[i].a, src[i].a, src[i].a);
        }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Cone projection"
                                 description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int p) {
        double r1 = sqrt(r*MAX_R);
        int y = (int)CenterY+(int)(r1*sin(a));
        if (y < 0)
            y = 0;
        else if (y >= H)
            y = (int)H - 1;
        int x = CenterX + r1*cos(a);
        if (x < 0)
            x = 0;
        else if (x >= W)
            x = (int)W - 1;
        return PI(x, y);
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Andrew's projection"
                                  description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int p) {
        int x = CenterX + 0.6*((r - sin(a)*100 + 50) * cos(a));
        int y = CenterY + 0.6*r*sin(a); // - (CENTER_Y/4);
        return PI(x, y);
#ifdef notdef
        if (x >= 0 && x < currentFormat.w && y >= 0 && y < currentFormat.h)
        else
            return PI(&currentFormat,CenterX + r*cos(a), CenterX + r*sin(a));
#endif
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Fish eye"
                                 description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int p) {
        double R = hypot(W, H);
        double r1 = r*r/(R/2.0);
        int x = (int)CenterX + (int)(r1*cos(a));
        int y = (int)CenterY + (int)(r1*sin(a));
        return PI(x,y);
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);
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
    [transformList addObject:lastTransform];
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
    [transformList addObject:lastTransform];
#endif

#ifdef notdef
pixel
pg(double r, double a) {
    double x = r*cos(a);
    double y = r*sin(a);
    return frame[CENTER_Y+(short)(r*cos(a))]
            [CENTER_X+(short)(r*sin((y*x)/4+a))];
}

pixel
can(double r, double a) {
    return frame[CENTER_Y+(short)(r*5/2)][CENTER_X+(short)(a*5/2)];
}
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
    extern  init_proc init_bignose;
    extern  init_proc init_dali;
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

// For Tom's logo algorithm

int
stripe(Pixel *buf, int x, int p0, int p1, int c){
    if(p0==p1){
        if(c>Z){
            buf[PI(x,p0)].r = Z;
            return c-Z;
        }
        buf[PI(x,p0)].r = c;
        return 0;
    }
    if (c>2*Z) {
        buf[PI(x,p0)].r = Z;
        buf[PI(x,p1)].r = Z;
         return c-2*Z;
    }
    buf[PI(x,p0)].r = c/2;
    buf[PI(x,p1)].r = c - c/2;
    return 0;
}

- (void) addMiscTransforms {
    [categoryNames addObject:@"Misc."];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];

    lastTransform = [Transform areaTransform: @"Old AT&T logo"
                                                  description: @"Tom Duff's logo transform"
                                                areaFunction: ^(Pixel *src, Pixel *dest, int p) {
        size_t maxY = H;
        size_t maxX = W;
        int x, y;
            
        for (y=0; y<maxY; y++) {
            for (x=0; x<maxX; x++) {
                    channel c = LUM(src[PI(x,y)]);
                    src[PI(x,y)] = SETRGB(c,c,c);
                }
            }
            
        int hgt = p;
        int c;
        int y0, y1;

        for (y=0; y<maxY; y+= hgt) {
            if (y+hgt>maxY)
                hgt = (int)maxY-(int)y;
            for (x=0; x < maxX; x++) {
                c=0;
                for(y0=0; y0<hgt; y0++)
                    c += R(src[PI(x,y+y0)]);

                y0 = y+(hgt-1)/2;
                y1 = y+(hgt-1-(hgt-1)/2);
                for (; y0 >= y; --y0, ++y1)
                    c = stripe(src, x, y0, y1, c);
            }
        }
                    
        for (y=0; y<maxY; y++) {
            for (x=0; x<maxX; x++) {
                channel c = R(src[PI(x,y)]);
                dest[PI(x,y)] = SETRGB(c, c, c);
            }
        }
    }];
    lastTransform.value = 12; lastTransform.low = 4; lastTransform.high = 50;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);
}
       
#ifdef notdef
    extern  transform_t do_diff;
    extern  transform_t do_color_logo;
    extern  transform_t do_spectrum;
#endif

- (void) addColorVisionDeficits {
//    [flatTransformList addObjectsFromArray:transformList];
}


static Pixel
ave(Pixel p1, Pixel p2) {
    Pixel p;
    p.r = (p1.r + p2.r + 1)/2;
    p.g = (p1.g + p2.g + 1)/2;
    p.b = (p1.b + p2.b + 1)/2;
    p.a = Z;
    return p;
}

#define        RAN_MASK    0x1fff
#define     LUT_RES        (Z+1)

float
Frand(void) {
    return((double)(rand() & RAN_MASK) / (double)(RAN_MASK));
}

#ifdef CHAT
#ifdef notdef
        {"Cone projection", init_cone, do_remap, "Pinhead", "", 0, FRAME_COLOR},
        {"Fish eye",    init_fisheye, do_remap, "Fish", "eye", 0 ,AREA_COLOR},
#endif

#ifdef notdef

        add_button(right(last_top->r), "neon", "Neon", Green, do_sobel);
        last_top = last_button;
        add_button(below(last_button->r), "fisheye", "Fish eye", OLD, do_remap);
        last_button->init = (void *)init_fisheye;

        add_button(right(last_top->r), "pixels", "Pixels", Green, do_remap);
        last_button->init = (void *)init_pixels4;

        add_button(exit_r, "exit", "(Exit)", Red, bparam(do_exit,0));
#endif

#endif

typedef struct Pt {
    int x,y;
} Pt;

/*
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
    [categoryNames addObject:@"Art simulations"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    lastTransform = [Transform areaTransform: @"Escher"
                                 description: @""
                                  remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int pps) {
        pixPerSide = pps;
        dxToBlockCenter = ((int)(pixPerSide*sqrt(0.75)));
        
        for (int x=0; x<W; x++) {
            for (int y=0; y<H; y++)
            table[PI(x,y)] = Remap_White;
        }

        int nxBlocks = (((int)W/(2*dxToBlockCenter)) + 2);
        int nyBlocks = (int)((H/(3*pixPerSide/2)) + 2);
        
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
                if (INRANGE(x,y))
                    table[PI(x,y)] = Remap_Black;
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
                    
                    dxx = (CORNERS[lr].x - CORNERS[ll].x)/(float)W;
                    dxy = (CORNERS[lr].y - CORNERS[ll].y)/(float)W;
                    dyx = (CORNERS[ul].x - CORNERS[ll].x)/(float)H;
                    dyy = (CORNERS[ul].y - CORNERS[ll].y)/(float)H;
                    
                    for (int y=0; y<H; y++) {    // we could actually skip some of these
                        for (int x=0; x<W; x++)    {
                            int nx = CORNERS[ll].x + y*dyx + x*dxx;
                            int ny = CORNERS[ll].y + y*dyy + x*dxy;
                            if (INRANGE(nx,ny))
                                table[PI(nx,ny)] = PI(x,y);
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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Edward Much #1"
                                  description: @"twist"
                                  remapPolar:^PixelIndex_t (float r, float a, int param) {
        double newa = a + (r/3.0)*(M_PI/180.0);
        int x = CENTER_X + r*cos(newa);
        int y = CENTER_Y + r*sin(newa);
        if (INRANGE(x,y))
            return PI(x,y);
        else
            return Remap_White;
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Edward Munch #2"
                                  description: @"Ken's twist"
                                  remapPolar:^PixelIndex_t (float r, float a, int param) {
        int x = CENTER_X + r*cos(a);
        int y = CENTER_Y + (r*sin(a+r/30.0));
        if (INRANGE(x,y))
            return PI(x,y);
        else
            return Remap_White;
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Dali"
                                  description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int param) {
        int x = CENTER_X + r*cos(a);
        int y = CENTER_Y + r*sin(a);
        x = CENTER_X + (r*cos(a + (y*x/(16*17000.0))));
        if (INRANGE(x,y))
            return PI(x,y);
        else
            return Remap_White;
    }];
    lastTransform.low = 17;
    lastTransform.value = 4*lastTransform.low;
    lastTransform.high = 10*lastTransform.low;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

    lastTransform = [Transform areaTransform: @"Warhol"
                                 description: @"cartoon colors"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        int ave_r=0, ave_g=0, ave_b=0;

        for (int y=0; y<H; y++)
            for (int x=0; x<W; x++) {
                Pixel p = src[PI(x,y)];
                ave_r += p.r;
                ave_g += p.g;
                ave_b += p.b;
            }

        ave_r /= W*H;
        ave_g /= W*H;
        ave_b /= W*H;

        for (int y=0; y<H; y++)
            for (int x=0; x<W; x++) {
                Pixel p = {0,0,0,Z};
                p.r = (src[PI(x,y)].r >= ave_r) ? Z : 0;
                p.g = (src[PI(x,y)].g >= ave_g) ? Z : 0;
                p.b = (src[PI(x,y)].b >= ave_b) ? Z : 0;
                dest[PI(x,y)] = p;
            }
    }];
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
    [transformList addObject:lastTransform];
    ADD_TO_OLIVE(lastTransform);

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
        memset(dest, 0, configuredPixelsInImage*sizeof(Pixel));
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
    [transformList addObject:lastTransform];

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
    [transformList addObject:lastTransform];
}

#ifdef notdef

double r1 = r*r/(R/2);
return (Point){CENTER_X+(int)(r1*cos(a)), CENTER_Y+(int)(r1*sin(a))};

extern  init_proc init_cone;
extern  init_proc init_bignose;
extern  init_proc init_fisheye;
extern  init_proc init_andrew;
extern  init_proc init_twist;
extern  init_proc init_kentwist;
extern  init_proc init_slicer;

extern  init_proc init_high;
extern  init_proc init_auto;


extern  void init_polar(void);
#endif

#ifdef notdef

#define HALF_Z          (Z/2)


typedef Point remap[W][W];
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
