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
#define RED             SETRGB(Z,0,0)
#define GREEN           SETRGB(0,Z,0)
#define BLUE            SETRGB(0,0,Z)

#define LUM(p)  ((((p).r)*299 + ((p).g)*587 + ((p).b)*114)/1000)
#define CLIP(c) ((c)<0 ? 0 : ((c)>Z ? Z : (c)))

#define R(x) x.r
#define G(x) x.g
#define B(x) x.b


#ifdef DEBUG_TRANSFORMS

#define PI(imt, x,y)    dPI((imt), (x), (y))    // DEBUG version

int dPI(Image_t *im, int x, int y) {
    assert(x >= 0);
    assert(x < im->w);
    assert(y >= 0);
    assert(y < im->h);
    return im->bytes_per_row/sizeof(Pixel) * y + x;
}

#else

// Pixel array index for pixel x,y
#define PI(imt, x,y)     (((y)*imt->bytes_per_row/sizeof(Pixel)) + (x))

#endif

// Pixel at coordinates in image
#define P(imt, x,y)  imt->image[PI(imt, x, y)]

// Address Pixel at coordinates in image
#define PA(imt, x,y)    (&P(imt, x,y))

@interface Transforms ()

@property (strong, nonatomic)   NSMutableArray *sourceImageIndicies;
@property (strong, nonatomic)   NSArray *executeList;
@property (strong, nonatomic)   Transform *lastTransform;

@end

@implementation Transforms

@synthesize categoryNames;
@synthesize categoryList;
@synthesize list;
@synthesize listChanged, paramsChanged;
@synthesize executeList;
@synthesize bytesPerRow;
@synthesize sourceImageIndicies;
@synthesize lastTransform;
@synthesize busy;

Image_t currentFormat;

Image_t sources[2];

- (id)init {
    self = [super init];
    if (self) {
        sources[1].image = 0;
        currentFormat.bytes_per_row = 0;    // no current format
        
        list = [[NSMutableArray alloc] init];
        listChanged = NO;
        busy = NO;
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

// Some of our transforms might be a little buggy around the edges.  Make sure
// all the points are in range.

#define TA(x,y) table[(x) + currentFormat.w * (y)]

- (void) setRemapInTable:(BitmapIndex_t *)table x:(int)x y:(int)y from:(RemapPoint_t) point {
    if (point.x < 0)
        point.x = 0;
    else if (point.x >= currentFormat.w)
        point.x = currentFormat.w - 1;
    if (point.y < 0)
        point.y = 0;
    else if (point.y >= currentFormat.h)
        point.y = currentFormat.h - 1;
    TA(x,y) = PI(&currentFormat, point.x, point.y);
}

- (void) precomputeTransform:(Transform *) transform {
    assert(currentFormat.bytes_per_row != 0);
    switch (transform.type) {
        case RowTrans:
        case ColorTrans: {
            break;
        }
        case RemapTrans:    // precompute new pixel locations
            if (transform.remapTable) {
                free(transform.remapTable);
                transform.remapTable = nil;
            }
            NSLog(@"remap %@", transform.name);
            // we compute a table of indices into a bitmap, which may have extra unused Pixels
            // at the end of each row.  Our computed index takes these into account, but we
            // only have to compute entries for actual useful x,y coordinates.
            
            size_t entryCount = currentFormat.w * currentFormat.h;
            BitmapIndex_t *table = (BitmapIndex_t *)calloc(entryCount, sizeof(BitmapIndex_t));
            NSLog(@"table size is %lu, %lu, %lu bytes",
                  entryCount, sizeof(BitmapIndex_t), entryCount * sizeof(BitmapIndex_t));
            assert(table);
            BitmapIndex_t bmi;
            
            if (transform.remapPixelF) {    // compute remap one pixel at a time
                int i = 0;
                for (int y=0; y<currentFormat.h; y++)
                    for (int x=0; x<currentFormat.w; x++) {
                        bmi = transform.remapPixelF(&currentFormat, x, y, transform.param);
                        table[i++] = bmi;
                    }
            } else if (transform.remapPolarF) {     // polar remap
                int centerX = currentFormat.w/2;
                int centerY = currentFormat.h/2;
                for (int x=0; x<centerX; x++) {
                    for (int y=0; y<centerY; y++) {
                        double r = hypot(x, y);
                        double a;
                        if (x == 0 && y == 0)
                            a = 0;
                        else
                            a = atan2(y, x);
                        [self setRemapInTable:table x:centerX-x y:centerY-y from:transform.remapPolarF(r, M_PI+a, transform.param)];
                        if (centerY+y < currentFormat.h)
                            [self setRemapInTable:table x:centerX-x y:centerY+y from:transform.remapPolarF(r, M_PI-a, transform.param)];
                        if (centerX+x < currentFormat.w) {
                            if (centerY+y < currentFormat.h)
                                [self setRemapInTable:table x:centerX+x y:centerY+y from:transform.remapPolarF(r, a, transform.param)];
                            [self setRemapInTable:table x:centerX+x y:centerY-y from:transform.remapPolarF(r, -a, transform.param)];
                        }
                    }
                }
            } else {        // whole screen remap
                transform.remapImageF(&currentFormat, table, transform.param);
            }
            transform.remapTable = table;
            break;
        case GeometricTrans:
        case AreaTrans:
        case EtcTrans:
            return;
    }
    transform.changed = NO;
}


// currentFormat has the bitmap details
- (void) setupForTransforming {
    // we can't have this routine execute off the official list, because that can get changed
    // by the user in mid-transform.  So we keep a separate copy here.  This copy still
    // points to each individual transform, whose parameter can change in mid-transform,
    // so we have to keep a local copy of that parameter in the actual transform processor.
    
    assert(currentFormat.bytes_per_row != 0);   // we need real values now
    
    executeList = [NSArray arrayWithArray:list];
    listChanged = NO;
    NSLog(@"recompute transforms");
    // source[0] gets all its data from the call context.  If we need a destination image,
    // we have to allocate one.  Set it to the invalid address 1 if we need an alloc.

    // Some transforms are best done in place, but some need to go to a destination
    // other than the source.   Here are the two possible sources.

    for (int i=0; i<executeList.count; i++) {
        Transform *transform = [executeList objectAtIndex:i];
        [self precomputeTransform:transform];
    }
}

- (void) updateParams {
    for (int i=0; i<executeList.count; i++) {
        Transform *transform = [executeList objectAtIndex:i];
        if (!transform.changed)
            continue;
        [self precomputeTransform:transform];
    }
}


- (UIImage *) executeTransformsWithContext:(CGContextRef)context {
    if (listChanged) {
        [self setupForTransforming];
    } else if (paramsChanged) { // recompute one or more parameter changes
        [self updateParams];
    }
    
    size_t channelSize = CGBitmapContextGetBitsPerComponent(context);
    size_t pixelSize = CGBitmapContextGetBitsPerPixel(context);
    
    // These transforms make certain assumptions about the bitmaps encountered
    // that greatly speed up and simplify them.  Make sure these assumptions
    // are valid.
    
    assert(channelSize == 8);   // eight bits per color
    assert(pixelSize == channelSize * sizeof(Pixel));   // GBRA is a Pixel
    
    int w = (int)CGBitmapContextGetWidth(context);
    int h = (int)CGBitmapContextGetHeight(context);
    int bpr = (int)CGBitmapContextGetBytesPerRow(context);
    
    if (currentFormat.bytes_per_row == 0 |
        currentFormat.bytes_per_row != bpr ||
        currentFormat.w != w ||
        currentFormat.h != h) {     // first or changed format, compute new transforms
        currentFormat = (Image_t){w,h,bpr,(Pixel *)0};
        busy = YES;
        [self setupForTransforming];
        busy = NO;
        return nil;     // We don't even try, this probably took too long
    }
    
    int sourceImageIndex = 0;   // incoming image is at zero
    
    sources[sourceImageIndex] = currentFormat;
    sources[sourceImageIndex].image = CGBitmapContextGetData(context);

    // We can have extra bytes at the end of a bitmap row, but it has to come out
    // to an integer number of Pixels.  The code assumes this.
    assert(sources[sourceImageIndex].bytes_per_row % sizeof(Pixel) == 0); //no slop on the rows
    assert(((u_long)sources[sourceImageIndex].image & 0x03 ) == 0); // word-aligned pixels
    
    BOOL needsAlloc = sources[1].image == 0;
    sources[1] = sources[0];
    if (needsAlloc)
        sources[1].image = (Pixel *)calloc(sources[1].bytes_per_row * sources[1].h, sizeof(Pixel));
    
    Image_t *source= &sources[0];
    Image_t *dest = 0;
    if (executeList.count == 0)
        assert(sourceImageIndex == 0);
    
    // for debugging, three useful pixels
    source->image[0] = RED;
    source->image[1] = GREEN;
    source->image[2] = BLUE;
    
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
            case RowTrans: {
                assert(transform.rowF);
                for (int y=0; y<source->h; y++) {
                    transform.rowF(PA(source, 0, y), PA(dest,0,y), source->w);
                }
                sourceImageIndex = 1 - sourceImageIndex;
                break;
            }
            case GeometricTrans:
                break;
            case RemapTrans:     // all these pixel moves are recomputed, for speed
                assert(transform.remapTable);
                [self remapWithTable:transform.remapTable from:source to:dest];
                sourceImageIndex = 1 - sourceImageIndex;
                break;
            case AreaTrans:
                assert(source->image);
                assert(dest->image);
                assert(dest->image != (Pixel *)1);
                
                transform.areaF(source, dest, transform.param);
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


- (void) remapWithTable:(BitmapIndex_t *)table from:(Image_t *)src to:(Image_t *)dest {
    int i=0;
    for (int y=0; y<dest->h; y++) {
        Pixel *p = PA(dest, 0, y);    // start of row
        for (int x=0; x<dest->w; x++) {
            BitmapIndex_t target = table[i++];
            *p++ = src->image[target];
        }
    }
}

    #define RT(x,y) remapTable[(y)*(im)->w + x]

- (void) addAreaTransforms {
    [categoryNames addObject:@"Area transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    lastTransform = [Transform areaTransform: @"Terry's kite"
                                  description: @"Designed by an 8-year old"
                                  remapImage: ^void (Image_t *im, BitmapIndex_t *remapTable, int p) {
        int centerX = im->w/2;
        int centerY = im->h/2;
        for (int y=0; y<im->h; y++) {
            int ndots;
            if (y <= centerY)
                ndots = (y*(im->w-1))/im->h;
            else
                ndots = ((im->h-y-1)*(im->w))/im->h;

            RT(centerX, y) = PI(im, centerX,y);
            RT(0,y) = Remap_White;
                 
            for (int x=1; x<=ndots; x++) {
                int dist = (x*(centerX-1))/ndots;
                assert(centerX+x < im->w);
                assert(centerX+dist < im->w);
                RT(centerX+x, y) = PI(im, centerX + dist,y);
                assert(centerX-x >= 0);
                assert(centerX-dist >= 0);
                RT(centerX-x, y) = PI(im, centerX - dist,y);
            }
            for (int x=ndots; x<centerX; x++) {
                assert(centerX+x < im->w);
                RT(centerX+x, y) = Remap_White;
                assert(centerX-x >= 0);
                RT(centerX-x, y) = Remap_White;
            }
        }
    }];
    [transformList addObject:lastTransform];
    
#ifdef notdef
    for (y=0; y<MAX_Y; y++) {
        int ndots;

        if (y <= CENTER_Y)
            ndots = (y*(MAX_X-1))/MAX_Y;
        else
            ndots = ((MAX_Y-y-1)*(MAX_X))/MAX_Y;

        (*rmp)[CENTER_X][y] = (Point){CENTER_X,y};
        (*rmp)[0][y] = (Point){Remap_White,0};
        
        for (x=1; x<=ndots; x++) {
            int dist = (x*(CENTER_X-1))/ndots;

            (*rmp)[CENTER_X+x][y] = (Point){CENTER_X + dist,y};
            (*rmp)[CENTER_X-x][y] = (Point){CENTER_X - dist,y};
        }
        for (x=ndots; x<CENTER_X; x++)
            (*rmp)[CENTER_X+x][y] = (*rmp)[CENTER_X-x][y] =
                (Point){Remap_White,0};
    }
#endif

    lastTransform = [Transform areaTransform: @"Pixelate"
                                  description: @"Giant pixels"
                                        remapPixel:^BitmapIndex_t (Image_t *im, int x, int y, int pixsize) {
        return PI(im, (x/pixsize)*pixsize, (y/pixsize)*pixsize);
    }];
    lastTransform.param = 20; lastTransform.low = 4; lastTransform.high = 200;
    [transformList addObject:lastTransform];
    
    lastTransform = [Transform areaTransform: @"Mirror right"
                                  description: @"Reflect the right half of the screen on the left"
                                        remapPixel:^BitmapIndex_t (Image_t *im, int x, int y, int v) {
        if (x < im->w/2)
            return PI(im, im->w - 1 - x, y);
        else
            return PI(im, x,y);
    }];
    [transformList addObject:lastTransform];
    
    [transformList addObject:[Transform areaTransform: @"Sobel"
                                          description: @"Sobel filter"
                                        areaTransform: ^(Image_t *src, Image_t *dest, int p) {
        int maxY = src->h;
        int maxX = src->w;
        //        int bpr = src->bytes_per_row;
        int x, y;
        
        for (y=1; y<maxY-1; y++) {
            for (x=1; x<maxX-1; x++) {
                int aa, bb, s;
                Pixel p = {0,0,0,Z};
                aa = R(P(src,x-1, y-1)) + R(P(src,x-1, y))*2 + R(P(src,x-1, y+1)) -
                    R(P(src,x+1, y-1)) - R(P(src,x+1, y))*2 - R(P(src,x+1, y+1));
                bb = R(P(src,x-1, y-1)) + R(P(src,x, y-1))*2+
                    R(P(src,x+1, y-1)) -
                    R(P(src,x-1, y+1)) - R(P(src,x, y+1))*2-
                    R(P(src,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.r = Z;
                else
                    p.r = s;
                
                aa = G(P(src,x-1, y-1))+G(P(src,x-1, y))*2+
                    G(P(src,x-1, y+1))-
                    G(P(src,x+1, y-1))-G(P(src,x+1, y))*2-
                    G(P(src,x+1, y+1));
                bb = G(P(src,x-1, y-1))+G(P(src,x, y-1))*2+
                    G(P(src,x+1, y-1))-
                    G(P(src,x-1, y+1))-G(P(src,x, y+1))*2-
                    G(P(src,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.g = Z;
                else
                    p.g = s;
                
                aa = B(P(src,x-1, y-1))+B(P(src,x-1, y))*2+
                    B(P(src,x-1, y+1))-
                    B(P(src,x+1, y-1))-B(P(src,x+1, y))*2-
                    B(P(src,x+1, y+1));
                bb = B(P(src,x-1, y-1))+B(P(src,x, y-1))*2+
                    R(P(src,x+1, y-1))-
                    B(P(src,x-1, y+1))-B(P(src,x, y+1))*2-
                    B(P(src,x+1, y+1));
                s = sqrt(aa*aa + bb*bb);
                if (s > Z)
                    p.b = Z;
                else
                    p.b = s;
                P(dest,x,y) = p;
            }
        }
        
    }]];
    
    [transformList addObject:[Transform areaTransform: @"Negative Sobel"
                                          description: @"Negative Sobel filter"
                                        areaTransform: ^(Image_t *src, Image_t *dest, int p) {
        int maxY = src->h;
        int maxX = src->w;

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
                P(dest,x,y) = p;
            }
        }
        
    }]];
        
    lastTransform = [Transform areaTransform: @"Mirror left"
                                  description: @"Reflect the left half of the screen to the right"
                                        remapPixel:^BitmapIndex_t (Image_t *im, int x, int y, int v) {
        if (x < im->w/2)
            return PI(im, x,y);
        else
            return PI(im, im->w - 1 - x, y);
    }];
    [transformList addObject:lastTransform];

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

#define CenterX (currentFormat.w/2)
#define CenterY (currentFormat.h/2)
#define MAX_R   (MAX(CenterX, CenterY))

- (void) addGeometricTransforms {
    [categoryNames addObject:@"Geometric transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];
    
    lastTransform = [Transform areaTransform: @"Cone projection"
                                  description: @""
                             remapPolarPixel:^RemapPoint_t (float r, float a, int p) {
        double r1 = sqrt(r*MAX_R);
        int y = CenterY+(int)(r1*sin(a));
        if (y < 0)
            y = 0;
        else if (y >= currentFormat.h)
            y = currentFormat.h - 1;
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

// For Tom's logo algorithm

int
stripe(Image_t *buf, int x, int p0, int p1, int c){
    if(p0==p1){
        if(c>Z){
            P(buf,x,p0).r = Z;
            return c-Z;
        }
        P(buf,x,p0).r = c;
        return 0;
    }
    if (c>2*Z) {
        P(buf,x,p0).r = Z;
        P(buf,x,p1).r = Z;
         return c-2*Z;
    }
    P(buf,x,p0).r = c/2;
    P(buf,x,p1).r = c - c/2;
    return 0;
}

- (void) addMiscTransforms {
    [categoryNames addObject:@"Misc. transforms"];
    NSMutableArray *transformList = [[NSMutableArray alloc] init];
    [categoryList addObject:transformList];

    lastTransform = [Transform areaTransform: @"Old AT&T logo"
                                                  description: @"Tom Duff's logo transform"
                                                areaTransform: ^(Image_t *src, Image_t *dest, int p) {
        int maxY = src->h;
        int maxX = src->w;
        int x, y;
            
        for (y=0; y<maxY; y++) {
            for (x=0; x<maxX; x++) {
                    channel c = LUM(P(src, x,y));
                    P(src,x,y) = SETRGB(c,c,c);
                }
            }
            
        int hgt = p;
        int c;
        int y0, y1;

        for (y=0; y<maxY; y+= hgt) {
            if (y+hgt>maxY)
                hgt = maxY-y;
            for (x=0; x < maxX; x++) {
                c=0;
                for(y0=0; y0<hgt; y0++)
                    c += R(P(src, x, y+y0));

                y0 = y+(hgt-1)/2;
                y1 = y+(hgt-1-(hgt-1)/2);
                for (; y0 >= y; --y0, ++y1)
                    c = stripe(src, x, y0, y1, c);
            }
        }
                    
        for (y=0; y<maxY; y++) {
            for (x=0; x<maxX; x++) {
                channel c = R(P(src, x, y));
                    P(dest, x,y) = SETRGB(c, c, c);
            }
        }
    }];
    lastTransform.param = 12; lastTransform.low = 4; lastTransform.high = 50;
    [transformList addObject:lastTransform];

    #ifdef notdef
        extern  transform_t do_diff;
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
    
    [transformList addObject:[Transform colorTransform: @"Colorize"
                                           description: @"Add color"
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&(Z >> 3);
                    *destRow++ = SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
                }
    }]];
    
    [transformList addObject:[Transform colorTransform: @"Solarize"
                                           description: @""
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    *destRow++ = SETRGB(    p.r < Z/2 ? p.r : Z-p.r,
                                            p.g < Z/2 ? p.g : Z-p.g,
                                        p.b < Z/2 ? p.b : Z-p.r);
                }
    }]];

    [transformList addObject:[Transform colorTransform: @"Luminance"
                                           description: @"Convert to brightness"
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    int v = LUM(p);
                    *destRow++ = SETRGB(v,v,v);
                }
    }]];
    
#define TMASK 0xe0  // XX make variable

    [transformList addObject:[Transform colorTransform: @"Truncate pixels"
                                           description: @"Truncate pixel values"
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    *destRow++ = SETRGB(p.r&TMASK, p.g&TMASK, p.b&TMASK);
                }
    }]];
    
    [transformList addObject:[Transform colorTransform: @"Swap colors"
                                           description: @"R -> G -> B -> Ryy"
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    *destRow++ = SETRGB(p.g, p.b, p.r);
                }
    }]];

    [transformList addObject:[Transform colorTransform: @"Negative"
                                           description: @"Invert pixel colors"
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    *destRow++ = SETRGB(Z-p.r, Z-p.g, Z-p.b);
                }
    }]];

    [transformList addObject:[Transform colorTransform: @"Brighten" // XXX needs parameter
                                           description: @"Make brighter"
                                          rowTransform:^(Pixel * _Nonnull srcRow, Pixel * _Nonnull destRow, int w) {
                for (int x=0; x<w; x++) {
                    Pixel p = *srcRow++;
                    *destRow++ = SETRGB(p.r+(Z-p.r)/8,
                                        p.g+(Z-p.g)/8,
                                        p.b+(Z-p.b)/8);
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

#define CRGB(r,g,b)     SETRGB(CLIP(r), CLIP(g), CLIP(b))
#define HALF_Z          (Z/2)


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
    
