//
//  Transform.m
//  DigitalDarkroom
//
//  Created by ches on 9/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "Transform.h"

@implementation Transform

@synthesize name, description, helpPath;
@synthesize broken;
@synthesize transformsArrayIndex, thumbView;
@synthesize type;
@synthesize hasParameters;
@synthesize ipPointF;
@synthesize areaF;
@synthesize depthVisF, depthTransF;
@synthesize remapImageF;
@synthesize remapPolarF;
@synthesize remapSizeF;
@synthesize low, value, high;
@synthesize paramName, lowValueFormat, highValueFormat;
@synthesize newValue;
@synthesize remapTable;
@synthesize needsScaledDepth, modifiesDepthBuf;


- (id)init {
    self = [super init];
    if (self) {
        transformsArrayIndex = -1;    // assigned in transforms
        type = NullTrans;
        ipPointF = nil;
        broken = NO;
        helpPath = nil;
//        pointF = nil;
        areaF = nil;
        remapImageF = nil;
        remapPolarF = nil;
        remapSizeF = nil;
        depthVisF = nil;
        depthTransF = nil;
        low = high = 0;
        newValue = NO;
        hasParameters = NO;
        remapTable = NULL;
        paramName = nil;
        lowValueFormat = highValueFormat = @"%d";
        needsScaledDepth = modifiesDepthBuf = NO;
    }
    return self;
}

// From a frame with incoming depth and pixbuf, and outgoing pixbuf
+ (Transform *) depthVis:(NSString *) n description:(NSString *) d
                depthVis:(depthVis_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = DepthVis;
    t.depthVisF = f;
    t.needsScaledDepth = YES;
    return t;
}

// From a frame with incoming depth and pixbuf, and outgoing depth and frame
// must output a modified or copied depthBuf.
+ (Transform *) depthTrans:(NSString *) n description:(NSString *) d
                depthTrans:(depthTrans_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = DepthVis;
    t.depthTransF = f;
    t.needsScaledDepth = YES;
    t.modifiesDepthBuf = YES;
    return t;
}

+ (Transform *) colorTransform:(NSString *) n
                   description:(NSString *) d
                 ptFunc:(PtFunc_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = ColorTrans;
    t.ipPointF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                areaFunction:(areaFunction_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = AreaTrans;
    t.areaF = f;
    return t;
}

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                remapImage:(RemapImage_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapImage;
    t.remapImageF = f;
    return t;
}

// sets up pixel remap from pixbuf to another pixbuf, using polar coordinates

+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapPolar:(RemapPolar_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapPolar;
    t.remapPolarF = f;
    return t;
}

#ifdef NOTUSED
+ (Transform *) areaTransform:(NSString *) n description:(NSString *) d
                   remapSize:(RemapSize_t) f {
    Transform *t = [[Transform alloc] init];
    t.name = n;
    t.description = d;
    t.type = RemapSize;
    t.remapSizeF = f;
    return t;
}
#endif

- (void) clearRemap {
    if (remapTable) {
        free(remapTable);
        remapTable = nil;
    }
}

- (void) dealloc {
    [self clearRemap];
}

@end
