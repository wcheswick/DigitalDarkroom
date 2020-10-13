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

#define LUM(p)  ((((p).r)*299 + ((p).g)*587 + ((p).b)*114)/1000)
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
    [self addPointTransforms];
    [self addGeometricTransforms];
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
    } else {        // whole screen remap
        NSLog(@"transform: %@", transform);
        transform.remapImageF(remapTable,
                              configuredWidth, configuredHeight,
                              transform.p);
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
                if (t.pUpdated) {
                    [t clearRemap];
                    t.pUpdated = NO;
                }
                [executeList addObject:t];
            }
        }
    }
    
    CGImageRef imageRef = [image CGImage];
    UIImageOrientation incomingOrientation = image.imageOrientation;
    
    CGImageRetain(imageRef);
    size_t width = (int)CGImageGetWidth(imageRef);
    size_t height = (int)CGImageGetHeight(imageRef);
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    assert(bitsPerPixel/8 == sizeof(Pixel));
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    assert(bitsPerComponent == 8);
    configuredPixelsInImage = width * height;
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    assert(bytesPerRow == width * sizeof(Pixel));   // we assume no unused bytes in row

    if (configuredBytesPerRow != bytesPerRow ||
        configuredWidth != width ||
        configuredHeight != height) {
        NSLog(@">>> format was %4zu %4zu %4zu   %4zu %4zu %4zu",
              configuredBytesPerRow,
              configuredWidth,
              configuredHeight,
              bytesPerRow, width, height);
        configuredBytesPerRow = bytesPerRow;
        configuredHeight = height;
        configuredWidth = width;
        NSLog(@">>> format is   %4zu %4zu %4zu",
              configuredBytesPerRow,
              configuredWidth,
              configuredHeight);
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
            return;
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
            transform.areaF(srcBuf, dstBuf, transform.p);
            break;
        case EtcTrans:
            NSLog(@"stub - etctrans");
            break;
    }
}

- (void) addAreaTransforms {
    [categoryNames addObject:@"Area transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];

    /* timings on digitalis:
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

    // area transform
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
    lastTransform.initial = 10;
    lastTransform.low = 2;
    lastTransform.high = 20;
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
    lastTransform.initial = 6;
    lastTransform.high = 200;
    [transformList addObject:lastTransform];

    lastTransform = [Transform areaTransform: @"Mirror"
                                  description: @"Reflect the image"
                                        remapImage:^void (PixelIndex_t *table, size_t w, size_t y, int pixsize) {
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                table[PI(x,y)] = PI(w - x - 1,y);
            }
        }
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Mirror right"
                                 description: @"Reflect the right half of the screen on the left"
                                  remapImage:^void (PixelIndex_t *table, size_t w, size_t y, int pixsize) {
        for (int y=0; y<configuredHeight; y++) {
            for (int x=0; x<configuredWidth; x++) {
                if (x < configuredWidth/2)
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
    [categoryNames addObject:@"Point transforms"];
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
    lastTransform.low = 1; lastTransform.initial = 3; lastTransform.high = 7;
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
    lastTransform.low = 1; lastTransform.initial = 3; lastTransform.high = 7;
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


#define CenterX (currentFormat.w/2)
#define CenterY (currentFormat.h/2)
#define MAX_R   (MAX(CenterX, CenterY))

- (void) addGeometricTransforms {
    [categoryNames addObject:@"Geometric transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
#ifdef notyet
    lastTransform = [Transform areaTransform: @"Cone projection"
                                  description: @""
                                  remapImage:^void (PixelIndex_t *table, size_t w, size_t h, int p) {
        for (int y=0; y<h; y++) {
            for (int x=(int)w-100; x<(int)w; x++) {
                table[TI(x,y,w)] = TI(x, y, w);
                table[TI(x - (w-100),y,w)] = TI(x, y, w);
            }
        }
    }];
        double r1 = sqrt(r*MAX_R);
        int y = (int)CenterY+(int)(r1*sin(a));
        if (y < 0)
            y = 0;
        else if (y >= currentFormat.h)
            y = (int)currentFormat.h - 1;
        return (RemapPoint_t){CenterX + (int)(r1*cos(a)), y};
    }];
    [transformList addObject:lastTransform];
#endif

#ifdef notyet
    lastTransform = [Transform areaTransform: @"Cone projection"
                                  description: @""
                             remapPolarPixel:^RemapPoint_t (float r, float a, int p) {
        double r1 = sqrt(r*MAX_R);
        int y = (int)CenterY+(int)(r1*sin(a));
        if (y < 0)
            y = 0;
        else if (y >= currentFormat.h)
            y = (int)currentFormat.h - 1;
        return (RemapPoint_t){CenterX + (int)(r1*cos(a)), y};
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Andrew's projection"
                                  description: @""
                             remapPolarPixel:^RemapPoint_t (float r, float a, int p) {
        int x = CenterX + 0.6*((r - sin(a)*100 + 50) * cos(a));
        int y = CenterY + 0.6*r*sin(a); // - (CENTER_Y/4);
        return (RemapPoint_t){x, y};
#ifdef notdef
        if (x >= 0 && x < currentFormat.w && y >= 0 && y < currentFormat.h)
        else
            return PI(&currentFormat,CenterX + r*cos(a), CenterX + r*sin(a));
#endif
    }];
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Fish eye"
                                  description: @""
                             remapPolarPixel:^RemapPoint_t (float r, float a, int p) {
        double r1 = r*r/(r/2);
        return (RemapPoint_t){CenterX+(int)(r1*cos(a)), CenterY+(int)(r1*sin(a))};
    }];
    [transformList addObject:lastTransform];
#endif
    
#ifdef notyet
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
    [categoryNames addObject:@"Misc. transforms"];
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
    lastTransform.initial = 12; lastTransform.low = 4; lastTransform.high = 50;
    [transformList addObject:lastTransform];

    #ifdef notdef
        extern  transform_t do_diff;
        extern  transform_t do_color_logo;
        extern  transform_t do_spectrum;
    #endif
}


- (void) addArtTransforms {
    [categoryNames addObject:@"Art-style transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
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
    
