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

#define DEBUG_TRANSFORMS    1   // bounds checking and a lot of assertions

#define SETRGB(r,g,b)   (Pixel){b,g,r,Z}
#define Z               ((1<<sizeof(channel)*8) - 1)
#define HALF_Z          (Z/2)

#define CENTER_X        (configuredWidth/2)
#define CENTER_Y        (configuredHeight/2)

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

size_t configuredWidth, configuredHeight;
size_t configuredBytesPerRow, configuredPixelsInImage;

Pixel *imBufs[2];


#define RPI(x,y)    (PixelIndex_t)(((y)*configuredWidth) + (x))

#ifdef DEBUG_TRANSFORMS
// Some of our transforms might be a little buggy around the edges.  Make sure
// all the indicies are in range.

#define PI(x,y)   dPI((int)(x),(int)(y))   // pixel index in a buffer

PixelIndex_t dPI(int x, int y) {
    assert(x >= 0);
    assert(x < configuredWidth);
    assert(y >= 0);
    assert(y < configuredHeight);
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

- (id)init {
    self = [super init];
    if (self) {
        configuredBytesPerRow = 0;    // no current configuration
        categoryNames = [[NSMutableArray alloc] init];
        categoryList = [[NSMutableArray alloc] init];
        sequence = [[NSMutableArray alloc] init];
        sequenceChanged = YES;
        finalScale = 1.0;
        imBufs[0] = imBufs[1] = NULL;
        executeList = [[NSMutableArray alloc] init];
        [self buildTransformList];
    }
    return self;
}

- (void) buildTransformList {
    [self addArtTransforms];
    [self addNewGerardTransforms];
    [self addGeometricTransforms];
    [self addPointTransforms];
    [self addMiscTransforms];
    // tested:
    [self addAreaTransforms];
}

#ifdef notyet
- (void) setRemapForTransform:(Transform *)transform
                            x:(int)x y:(int)y
                         from:(RemapPoint_t) point {
    if (point.x < 0)
        point.x = 0;
    else if (point.x >= configuredWidth)
        point.x = configuredWidth - 1;
    if (point.y < 0)
        point.y = 0;
    else if (point.y >= configuredHeight)
        point.y = configuredHeight - 1;
    transform.remapTable[PI(x,y)] = PI(point.x, point.y);
}

- (void) setRemapForTransform:(Transform *)transform
                            x:(int)x y:(int)y
                         color: (enum SpecialRemaps) remapColor {
    transform.remapTable[PI(x,y)] = remapColor;
}
#endif

#ifdef NOTDEF
// remap table source for pixel x,y

#define dRT(x,y) (*(dRT(remapTable, im, x, y)))

PixelIndex_t dRT(PixelIndex_t * _Nullable remapTable, Image_t *im, int x, int y) {
    assert(remapTable);
    assert(im);
    assert(x >= 0);
    assert(x < im->w);
    assert(y >= 0);
    assert(y < im->h);
    return remapTable[(y)*((im)->w) + (x)];
}

- (void) remapPixel:(RemapPoint_t)p color:(enum SpecialRemaps) color {
    assert(p.x >= 0);
    assert(p.x < currentFormat.w);
    assert(p.y >= 0);
    assert(p.y < currentFormat.h);
    //RT(p.x, p.y, currentFormat.w) = color;
}

- (void) remapPixel:(RemapPoint_t)p from:(RemapPoint_t) src {
    NSLog(@"unused?");
    NSLog(@"unused?");
}
#endif

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
        size_t centerX = configuredWidth/2;
        size_t centerY = configuredHeight/2;
        for (int dx=0; dx<centerX; dx++) {
            for (int dy=0; dy<centerY; dy++) {
                double r = hypot(dx, dy);
                double a;
                if (dx == 0 && dy == 0)
                    a = 0;
                else
                    a = atan2(dy, dx);
                remapTable[PI(centerX-dx, centerY-dy)] = transform.remapPolarF(r, M_PI + a, transform.value);
                if (centerY+dy < configuredHeight)
                    remapTable[PI(centerX-dx, centerY+dy)] = transform.remapPolarF(r, M_PI - a, transform.value);
                if (centerX+dx < configuredWidth) {
                    if (centerY+dy < configuredHeight)
                        remapTable[PI(centerX+dx, centerY+dy)] = transform.remapPolarF(r, a, transform.value);
                    remapTable[PI(centerX+dx, centerY-dy)] = transform.remapPolarF(r, -a, transform.value);
                }
            }
        }

#ifdef OLDNEW
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                double rx = x - centerX;
                double ry = y - centerY;
                double r = hypot(rx, ry);
                double a = atan2(ry, rx);
                remapTable[PI(x,y)] = transform.remapPolarF(r, /* M_PI+ */ a,
                                                            transform.p,
                                                            configuredWidth,
                                                            configuredHeight);
            }
        }
#endif
    } else {        // whole screen remap
        NSLog(@"transform: %@", transform);
        transform.remapImageF(remapTable,
                              configuredWidth, configuredHeight,
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

- (UIImage *) executeTransformsWithImage:(UIImage *) image {
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
    configuredPixelsInImage = width * height;
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    if (!bytesPerRow) { // bad, but punt.  Seems to work just fine.
        NSLog(@"**** empty bytes per row");
        bytesPerRow = width*sizeof(Pixel);
    }
    //assert(bytesPerRow == width * sizeof(Pixel));   // we assume no unused bytes in row

    if (configuredBytesPerRow != bytesPerRow ||
        configuredWidth != width ||
        configuredHeight != height) {
#ifdef OLD
        NSLog(@">>> format was %4zu %4zu %4zu   %4zu %4zu %4zu",
              configuredBytesPerRow,
              configuredWidth,
              configuredHeight,
              bytesPerRow, width, height);
#endif
        configuredBytesPerRow = bytesPerRow;
        configuredHeight = height;
        configuredWidth = width;
        assert(configuredBytesPerRow % sizeof(Pixel) == 0); //no slop on the rows
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
    }
    
    int sourceImageIndex = 0;
    int destImageIndex = 1;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(imBufs[sourceImageIndex], width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 BITMAP_OPTS);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGImageRelease(imageRef);
    
    for (int i=0; i<executeList.count; i++) {
        Transform *transform = [executeList objectAtIndex:i];
        
        NSDate *transformStart = [NSDate now];
        [self performTransform:transform
                          from:imBufs[sourceImageIndex]
                            to:imBufs[destImageIndex]
                        height:height
                         width:width];
        int t = sourceImageIndex;     // swap
        sourceImageIndex = destImageIndex;
        destImageIndex = t;
        NSTimeInterval elapsed = -[transformStart timeIntervalSinceNow];
        transform.elapsedProcessingTime += elapsed;
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
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
    }
}

#ifdef OLD
/* Monochrome floyd-steinberg */

static void
fs(int depth, int buf[configuredWidth][configuredHeight]) {
    int x, y, i;
    int maxp = depth - 1;

    for(y=0; y<configuredHeight; y++) {
        for(x=0; x<configuredWidth; x++) {
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
            if (y < configuredHeight-1) {
                buf[x][y+1] += temp;
                if (x < configuredWidth-1)
                    buf[x+1][y+1] += e-2*temp;
            }
            if (x < configuredWidth-1)
                buf[x+1][y] += temp;
        }
    }
}
#endif

- (void) addAreaTransforms {
    [categoryNames addObject:@"Area"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
#ifdef OLD
    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @"oil paint"
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        int b[configuredWidth][configuredHeight];
        
        int depth = (param == 1) ? 1 : 4;
        
        for (int y=0; y<configuredHeight; y++)
           for (int x=0; x<configuredWidth; x++)
                b[x][y] = LUM(src[PI(x,y)]);
        
        fs(depth, b);
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
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
#endif
    
    lastTransform = [Transform areaTransform: @"Floyd Steinberg"
                                 description: @"oil paint"
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        channel lum[configuredWidth][configuredHeight];
        for (int y=1; y<configuredHeight-1; y++)
            for (int x=1; x<configuredWidth-1; x++)
                lum[x][y] = LUM(src[PI(x,y)]);

        for (int y=1; y<configuredHeight-1; y++) {
            for (int x=1; x<configuredWidth-1; x++) {
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

    lastTransform = [Transform areaTransform: @"color Floyd Steinberg"
                                 description: @"oil paint"
                                areaFunction:^(Pixel * _Nonnull src, Pixel * _Nonnull dest, int param) {
        for (int y=1; y<configuredHeight-1; y++) {
            for (int x=1; x<configuredWidth-1; x++) {
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
        for (y=0; y<configuredHeight; y++) {
            for (x=0; x<N; x++)
            dest[PI(x,y)] = dest[PI(configuredWidth-x-1,y)] = White;
            if (y<N || y>configuredHeight-N)
                for (x=0; x<configuredWidth; x++) {
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
            for (x++; x<configuredWidth-N; x++) {
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
            if (y+N >= configuredHeight)
                break;        /* unfortunate place to break out of the loop */
            x = (int)configuredWidth - N - 1;
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
            if (y+N >= configuredHeight)
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

#ifdef NOTYET
        lastTransform = [Transform areaTransform: @"remap test"
                                         description: @"testing"
                                          remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int p) {
                for (int y=0; y<h; y++) {
                    for (int x=(int)w-100; x<(int)w; x++) {
                        table[TI(x,y,w)] = TI(x, y, w);
                        table[TI(x - (w-100),y,w)] = TI(x, y, w);
                    }
                }
            }];
        [transformList addObject:lastTransform];
#endif
    // geom:
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

    lastTransform = [Transform areaTransform: @"Pixelate"
                                  description: @"Giant pixels"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t y, int pixsize) {
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                table[PI(x,y)] = PI((x/pixsize)*pixsize, (y/pixsize)*pixsize);
            }
        }
    }];
    lastTransform.low = 4;
    lastTransform.value = 6;
    lastTransform.high = 200;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];

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

    lastTransform = [Transform areaTransform: @"Sobel"
                                          description: @"Sobel filter"
                                        areaFunction: ^(Pixel *srcBuf, Pixel *dstBuf, int p) {
#define P(b,x,y)    (b)[PI(x,y)]
        for (int y=1; y<configuredHeight-1-1; y++) {
            for (int x=1; x<configuredWidth-1-1; x++) {
                int aa, bb, s;
                Pixel p = {0,0,0,Z};
                aa = R(P(srcBuf,x-1, y-1)) + R(P(srcBuf,x-1, y))*2 + R(P(srcBuf,x-1, y+1)) -
                    R(P(srcBuf,x+1, y-1)) - R(P(srcBuf,x+1, y))*2 - R(P(srcBuf,x+1, y+1));
                bb = R(P(srcBuf,x-1, y-1)) + R(P(srcBuf,x, y-1))*2+
                    R(P(srcBuf,x+1, y-1)) -
                    R(P(srcBuf,x-1, y+1)) - R(P(srcBuf,x, y+1))*2-
                    R(P(srcBuf,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.r = Z;
                else
                    p.r = s;
                
                aa = G(P(srcBuf,x-1, y-1))+G(P(srcBuf,x-1, y))*2+
                    G(P(srcBuf,x-1, y+1))-
                    G(P(srcBuf,x+1, y-1))-G(P(srcBuf,x+1, y))*2-
                    G(P(srcBuf,x+1, y+1));
                bb = G(P(srcBuf,x-1, y-1))+G(P(srcBuf,x, y-1))*2+
                    G(P(srcBuf,x+1, y-1))-
                    G(P(srcBuf,x-1, y+1))-G(P(srcBuf,x, y+1))*2-
                    G(P(srcBuf,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.g = Z;
                else
                    p.g = s;
                
                aa = B(P(srcBuf,x-1, y-1))+B(P(srcBuf,x-1, y))*2+
                    B(P(srcBuf,x-1, y+1))-
                    B(P(srcBuf,x+1, y-1))-B(P(srcBuf,x+1, y))*2-
                    B(P(srcBuf,x+1, y+1));
                bb = B(P(srcBuf,x-1, y-1))+B(P(srcBuf,x, y-1))*2+
                    R(P(srcBuf,x+1, y-1))-
                    B(P(srcBuf,x-1, y+1))-B(P(srcBuf,x, y+1))*2-
                    B(P(srcBuf,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.b = Z;
                else
                    p.b = s;
                dstBuf[PI(x,y)] = p;
            }
        }
    }];
    [transformList addObject:lastTransform];

#ifdef notdef
    [transformList addObject:[Transform areaTransform: @"Negative Sobel"
                                          description: @"Negative Sobel filter"
                                        areaFunction: ^(Pixel *src, Pixel *dest, int p, size_t maxX, size_t maxY) {
        int x, y;
        for (y=1; y<maxY-1; y++) {
            for (x=1; x<maxX-1; x++) {
                int aa, bb, s;
                Pixel p = {0,0,0,Z};
                aa = P(src, x-1,y-1).r + P(src, x-1,y).r * 2 +
                    P(src, (x-1),(y+1)).r -
                    P(src, (x+1),(y-1)).r - P(src, (x+1),(y)).r * 2 -
                    P(src, (x+1),(y+1)).r;
                bb = P(src, (x-1),(y-1)).r + P(src, (x),(y-1)).r * 2 +
                    P(src, (x+1),(y-1)).r -
                    P(src, (x-1),(y+1)).r - P(src, (x),(y+1)).r * 2 -
                    P(src, (x+1),(y+1)).r;
                s = sqrt(aa*aa + bb*bb);
                p.r = CLIP(s);

                aa = P(src, x-1,y-1).g + P(src, x-1,y).g * 2 +
                    P(src, (x-1),(y+1)).g -
                    P(src, (x+1),(y-1)).g - P(src, (x+1),(y)).g * 2 -
                    P(src, (x+1),(y+1)).g;
                bb = P(src, (x-1),(y-1)).g + P(src, (x),(y-1)).g * 2 +
                    P(src, (x+1),(y-1)).g -
                    P(src, (x-1),(y+1)).g - P(src, (x),(y+1)).g * 2 -
                    P(src, (x+1),(y+1)).g;
                s = sqrt(aa*aa + bb*bb);
                p.g = CLIP(s);

                aa = P(src, x-1,y-1).b + P(src, x-1,y).b * 2 +
                     P(src, (x-1),(y+1)).b -
                     P(src, (x+1),(y-1)).b - P(src, (x+1),(y)).b * 2 -
                     P(src, (x+1),(y+1)).b;
                 bb = P(src, (x-1),(y-1)).b + P(src, (x),(y-1)).b * 2 +
                     P(src, (x+1),(y-1)).b -
                     P(src, (x-1),(y+1)).b - P(src, (x),(y+1)).b * 2 -
                     P(src, (x+1),(y+1)).b;
                s = sqrt(aa*aa + bb*bb);
                p.b = CLIP(s);

                p.r = Z - p.r;
                p.g = Z - p.g;
                p.b = Z - p.b;
                dest[PI(x,y)] = p
            }
        }
        
    }]];
#endif

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
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                Pixel p = src[PI(x,y)];
                dest[PI(x,y)] = SETRGB(Z-p.r, Z-p.g, Z-p.b);
                }
            }
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Solarize"
                                 description: @"Simulate extreme overexposure"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                PixelIndex_t pi = PI(x,y);
                Pixel p = src[pi];
                dest[pi] = SETRGB(p.r < Z/2 ? p.r : Z-p.r,
                                       p.g < Z/2 ? p.g : Z-p.g,
                                       p.b < Z/2 ? p.b : Z-p.r);
            }
        }
    }];
    [transformList addObject:lastTransform];
    
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
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                PixelIndex_t pi = PI(x,y);
                Pixel p = src[pi];
                int v = LUM(p);
                dest[pi] = SETRGB(v,v,v);
            }
        }
#endif
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Colorize"
                                 description: @"Add color"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                Pixel p = src[PI(x,y)];
                channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&(Z >> 3);
                dest[PI(x,y)] = SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
            }
        }
    }];
    [transformList addObject:lastTransform];
    
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
    
    lastTransform = [Transform areaTransform: @"Swap colors"
                                 description: @"r->, g->b, b->r"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (PixelIndex_t pi=0; pi<configuredPixelsInImage; pi++) {
            Pixel p = *src++;
            *dest++ = SETRGB(p.g, p.b, p.r);
        }
    }];
    [transformList addObject:lastTransform];

    lastTransform = [Transform areaTransform: @"Auto contrast"
                                 description: @"auto contrast"
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        u_long ps;
        u_long hist[Z+1];
        float map[Z+1];
        
        for (int i = 0; i < Z+1; i++)
            hist[i] = 0;
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

- (void) addNewGerardTransforms {
    [categoryNames addObject:@"New Gerard"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    lastTransform = [Transform areaTransform: @"Shear"
                                                  description: @"Shear"
                                                areaFunction: ^(Pixel *src, Pixel *dest, int p) {
        int x, y, dx, dy, r, yshift[configuredWidth];
        memset(yshift, 0, sizeof(yshift));

        for (x = r = 0; x < configuredWidth; x++) {
            if (irand(256) < 128)
                r--;
            else
                r++;
            yshift[x] = r;
        }
        for (y = 0; y < configuredHeight; y++) {
            if (irand(256) < 128)
                r--;
            else
                r++;
            for (x = 0; x < configuredWidth; x++) {
                dx = x+r; dy = y+yshift[x];
                if (dx >= configuredWidth || dy >= configuredHeight ||
                    dx < 0 || dy < 0)
                    dest[PI(x,y)] = White;
                else
                    dest[PI(x,y)] = src[PI(dx,dy)];
            }
        }
    }];
    [transformList addObject:lastTransform];

    lastTransform = [Transform areaTransform: @"Slicer"
                                  description: @"Slicer"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int value) {
        long x, y, r = 0;
        long dx, dy, xshift[configuredHeight], yshift[configuredWidth];

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
                if (dx < configuredWidth && dy < configuredHeight && dx>=0 && dy>=0)
                    table[PI(x,y)] = PI(dx,dy);
            }
    }];
    [transformList addObject:lastTransform];

    lastTransform = [Transform areaTransform: @"Motion blur"
                                  description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int streak) {
        int x, y, dx, nr, ng, nb;

        assert(streak > 0);

        for (y = 0; y < configuredHeight; y++)
            for (x = 0; x < configuredWidth; x++) {
                Pixel p;
                p.r = p.b = p.g = 0;
                p.a = src[PI(x,y)].a;
                dest[PI(x,y)] = p;
         }
        // int     Tsz       = 32;         // tile size, e.g., MAX_X/16
        long Tsz = configuredWidth/16;
        
         for (y = 0; y < configuredHeight-Tsz; y++) {
                 for (x = 0; x < configuredWidth-Tsz; x++) {
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

    [categoryNames addObject:@"Monochromes"];
    transformList = [[NSMutableArray alloc] init];
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
        return SETRGB(p.r,p.r,p.r);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Green channel" description:@"" pointTransform:^Pixel(Pixel p) {
        return SETRGB(p.g,p.g,p.g);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform colorTransform:@"Blue channel" description:@"" pointTransform:^Pixel(Pixel p) {
        return SETRGB(p.b,p.b,p.b);
    }];
    [transformList addObject:lastTransform];
    
    // move image
    
}

#define CenterX (configuredWidth/2)
#define CenterY (configuredHeight/2)
#define MAX_R   (MAX(CenterX, CenterY))

#define INRANGE(x,y)    (x >= 0 && x < configuredWidth && y >= 0 && y < configuredHeight)

- (void) addGeometricTransforms {
    [categoryNames addObject:@"Geometric"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    lastTransform = [Transform areaTransform: @"Edges"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        Pixel p = {0,0,0,Z};

        for (int y=0; y<configuredHeight; y++) {
            int x;
            for (x=0; x<configuredWidth-2; x++) {
                Pixel pin;
                int r, g, b;
                long xin = (x+2) >= configuredWidth ? configuredWidth - 1 : x+2;
                long yin = (y+2) >= configuredHeight ? configuredHeight - 1 : y+2;
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

    lastTransform = [Transform areaTransform: @"Cone projection"
                                 description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int p) {
        double r1 = sqrt(r*MAX_R);
        int y = (int)CenterY+(int)(r1*sin(a));
        if (y < 0)
            y = 0;
        else if (y >= configuredHeight)
            y = (int)configuredHeight - 1;
        int x = CenterX + r1*cos(a);
        if (x < 0)
            x = 0;
        else if (x >= configuredWidth)
            x = (int)configuredWidth - 1;
        return PI(x, y);
   }];
    [transformList addObject:lastTransform];

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
    
    lastTransform = [Transform areaTransform: @"Fish eye"
                                  description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int p) {
        double R = hypot(configuredWidth, configuredHeight);
        double r1 = r*r/(R/2.0);
        int x = (int)CenterX + (int)(r1*cos(a));
        int y = (int)CenterY + (int)(r1*sin(a));
        return PI(x,y);
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Twist"
                                  description: @""
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
    lastTransform.low = 17000;
    lastTransform.value = 4*lastTransform.low;
    lastTransform.high = 10*lastTransform.low;
    lastTransform.hasParameters = YES;
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Ken twist"
                                  description: @""
                                  remapPolar:^PixelIndex_t (float r, float a, int param) {
        int x = CENTER_X + r*cos(a);
        int y = CENTER_Y + (r*sin(a+r/30.0));
        if (INRANGE(x,y))
            return PI(x,y);
        else
            return Remap_White;
    }];
    [transformList addObject:lastTransform];
    

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
}

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
        size_t maxY = configuredHeight;
        size_t maxX = configuredWidth;
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

    #ifdef notdef
        extern  transform_t do_diff;
        extern  transform_t do_color_logo;
        extern  transform_t do_spectrum;
    #endif
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



- (void) addArtTransforms {
    [categoryNames addObject:@"Art-style"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    
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
        
        for (int y = 1; y < configuredHeight - 1; y++) {
            if ((y % 2)) {
                x_strt = 1; x_stop = configuredWidth - 1; x_incr = 1;
            } else {
                x_strt = configuredWidth - 2; x_stop = 0; x_incr = -1;
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

#define CX    ((int)configuredWidth/4)
#define CY    ((int)configuredHeight*3/4)
#define OPSHIFT    3 //(3 /*was 0*/)

    lastTransform = [Transform areaTransform: @"Op art (broken)"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
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

    lastTransform = [Transform areaTransform: @"Mondrian"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        int c=0;
        int w = rand()%configuredWidth;
        int h = rand()%configuredHeight;
        static int oc = 0;
        
        while (c == 0 || c == oc) {
            c   = (rand()%2)?1:0;
            c  |= (rand()%2)?2:0;
            c  |= (rand()%2)?4:0;
        }
        oc = c;
        
        for (int y=0+h; y<0+2*h && y < configuredHeight; y++) {
            for (int x=0+w; x < 0+2*w && x < configuredWidth; x++) {
                Pixel p = src[PI(x,y)];
                if (c&1) p.r = Z;
                if (c&2) p.g = Z;
                if (c&4) p.b = Z;
                dest[PI(x,y)] = p;
            }
        }
    }];
    [transformList addObject:lastTransform];

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
        for (y=1; y<configuredHeight-1; y++) {
            for (x=0; x<configuredWidth-len; x++) {
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

    lastTransform = [Transform areaTransform: @"Cartoon"
                                 description: @""
                                areaFunction: ^(Pixel *src, Pixel *dest, int param) {
        int ave_r=0, ave_g=0, ave_b=0;

        for (int y=0; y<configuredHeight; y++)
            for (int x=0; x<configuredWidth; x++) {
                Pixel p = src[PI(x,y)];
                ave_r += p.r;
                ave_g += p.g;
                ave_b += p.b;
            }

        ave_r /= configuredWidth*configuredHeight;
        ave_g /= configuredWidth*configuredHeight;
        ave_b /= configuredWidth*configuredHeight;

        for (int y=0; y<configuredHeight; y++)
            for (int x=0; x<configuredWidth; x++) {
                Pixel p = {0,0,0,Z};
                p.r = (src[PI(x,y)].r >= ave_r) ? Z : 0;
                p.g = (src[PI(x,y)].g >= ave_g) ? Z : 0;
                p.b = (src[PI(x,y)].b >= ave_b) ? Z : 0;
                dest[PI(x,y)] = p;
            }
    }];
    [transformList addObject:lastTransform];

#ifdef notdef
extern  init_proc init_seurat;
extern  init_proc init_dali;
extern  init_proc init_escher;
#endif
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


typedef Point remap[configuredWidth][configuredWidth];
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
    
