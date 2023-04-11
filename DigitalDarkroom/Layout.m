//
//  Layout.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/2/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Layout.h"
#import "Defines.h"

BOOL
same_aspect(CGSize r1, CGSize r2) {
    float ar1 = r1.width/r1.height;
    float ar2 = r2.width/r2.height;
    float diffPct = DIFF_PCT(ar1,ar2);
    return diffPct < ASPECT_PCT_DIFF_OK;
};

NSString * __nullable displayThumbsPosition[] = {
    @"U",
    @"R",
    @"B",
};

NSString * __nullable displayOptionNames[] = {
    @"thum",
    @"ipho",
    @"ipad",
    @"tote",
    @"tot ",
};


#define SCALE_UNINITIALIZED (-1.0)

#define SCREEN  mainVC.containerView.frame

@interface Layout ()

@property (assign)  CGSize imageSourceSize;
@property (assign)  CGRect executeRect;
@property (assign)  ThumbsPosition thumbsPosition;
@property (assign)  float thumbScore, displayScore, scaleScore;
@property (assign)  float thumbFrac;

@end

@implementation Layout

@synthesize format, depthFormat;
@synthesize isCamera;
@synthesize index;

@synthesize transformSize;   // what we give the transform chain
@synthesize displayRect;     // where we put the transformed (and scaled) result
@synthesize fullThumbViewRect;
@synthesize thumbScrollRect;
@synthesize executeRect;     // where the active transform list is shown
@synthesize executeScrollMinH;
@synthesize executeScrollRect;
@synthesize sourceImageSize;
@synthesize plusRect;        // in executeRect
@synthesize paramRect;       // where the parameter slider goes

@synthesize firstThumbRect;  // thumb size and position in fullThumbViewRect
@synthesize thumbImageRect;  // image sample size in each thumb button

@synthesize layoutOption, thumbsPosition;

@synthesize imageSourceSize;
@synthesize executeIsTight;
@synthesize displayFrac, thumbFrac, pctUsed;
@synthesize scale, aspectRatio;
@synthesize executeOverlayOK;
@synthesize status, type;
@synthesize score, thumbScore, displayScore, scaleScore;

- (id)initForSize:(CGSize) iss
      rightThumbs:(size_t) rightThumbs
     bottomThumbs:(size_t) bottomThumbs
     layoutOption:(LayoutOptions) lopt
      cameraInput:(BOOL) isCam
           format:(AVCaptureDeviceFormat *__nullable) form
      depthFormat:(AVCaptureDeviceFormat *__nullable) df {
    self = [super init];
    if (self) {
        assert(rightThumbs == 0 || bottomThumbs == 0); // no fancy stuff
        isCamera = isCam;
        format = form;
        depthFormat = df;
        index = INDEX_UNKNOWN;
        
        imageSourceSize = iss;
        layoutOption = lopt;
        score = BAD_LAYOUT;
        status = nil;   // XXX may be a dreg
        
        aspectRatio = imageSourceSize.width / imageSourceSize.height;
        firstThumbRect = thumbImageRect = CGRectZero;
        thumbImageRect.size = CGSizeMake(THUMB_W, trunc(THUMB_W/aspectRatio));
        firstThumbRect.size = CGSizeMake(thumbImageRect.size.width,
                                         thumbImageRect.size.height + THUMB_LABEL_H);
        paramRect.size = CGSizeMake(LATER, PARAM_VIEW_H);

        CGSize targetSize;
        displayRect.origin = CGPointZero;
        if (rightThumbs) {
            type = @"DPE/T";    // thumbs on right
            thumbScrollRect.size.width = (firstThumbRect.size.width + SEP)*rightThumbs;
            targetSize = CGSizeMake(SCREEN.size.width - thumbScrollRect.size.width - SEP,
                                    SCREEN.size.height - SEP - PARAM_VIEW_H);
            if (targetSize.width < mainVC.minDisplayWidth) {
#ifdef DEBUG_LAYOUT
                NSLog(@"no room for %zu thumb columns on right", rightThumbs);
#endif
                return nil;
            }
            displayRect.size = [Layout fitSize:imageSourceSize toSize:targetSize];
            paramRect.origin.y = BELOW(displayRect) + SEP;

            // adjust thumbs view for actual available width:
            thumbScrollRect.origin = CGPointMake(RIGHT(displayRect) + SEP, 0);
            thumbScrollRect.size.width = SCREEN.size.width - thumbScrollRect.origin.x;
            thumbScrollRect.size.height = mainVC.containerView.frame.size.height;

            plusRect.origin = CGPointMake(0, BELOW(paramRect) + SEP);
            plusRect.size = CGSizeMake(displayRect.size.width, PLUS_H);
            
            executeRect.origin = CGPointMake(0, BELOW(plusRect) + SEP);
            executeRect.size = CGSizeMake(displayRect.size.width, SCREEN.size.height - executeRect.origin.y);
        } else {
            type = @"DT/PE"; // thumbs underneath, P over E on right
            thumbScrollRect.size.width = mainVC.containerView.frame.size.width;
            thumbScrollRect.size.height = (firstThumbRect.size.height + SEP)*bottomThumbs;
            executeRect.size = CGSizeMake(SCREEN.size.width - SEP - mainVC.minExecWidth, LATER);
            targetSize = CGSizeMake(SCREEN.size.width - executeRect.size.width,
                                    SCREEN.size.height - SEP - PARAM_VIEW_H - SEP - thumbScrollRect.size.height);
            if (targetSize.height < mainVC.minDisplayHeight) {
#ifdef DEBUG_LAYOUT
                NSLog(@"no room for %zu thumb rows on bottom", bottomThumbs);
#endif
                return nil;
            }
            displayRect.size = [Layout fitSize:imageSourceSize toSize:targetSize];

            plusRect.origin = CGPointMake(RIGHT(displayRect) + SEP, 0);
            plusRect.size = CGSizeMake(SCREEN.size.width - plusRect.origin.x, PLUS_H);
            
            executeRect.origin = CGPointMake(plusRect.origin.x, BELOW(plusRect) + SEP);
            executeRect.size = CGSizeMake(plusRect.size.width, displayRect.size.height - executeRect.origin.y);

            paramRect.origin.y = BELOW(displayRect) + SEP;
            thumbScrollRect.origin.y = BELOW(paramRect) + SEP;
            thumbScrollRect.size.height = SCREEN.size.height - thumbScrollRect.origin.y;
        }   // XXXX DPET
        
        paramRect.size.width = displayRect.size.width;

        // plus sits at the beginning of the thumbs.  For now.
        firstThumbRect.origin = CGPointMake(RIGHT(plusRect) + SEP, 0);
        
        fullThumbViewRect.origin = CGPointZero;
        fullThumbViewRect.size = CGSizeMake(thumbScrollRect.size.width, LATER);
        
        scale = displayRect.size.width / imageSourceSize.width;
        transformSize = displayRect.size;

        [self scoreLayout];
    }
    return self;
}

- (void) scoreLayout {
#ifdef OLD
    size_t thumbsOnScreen;
    for (thumbsOnScreen=0; thumbsOnScreen < thumbPositionArray.count; thumbsOnScreen++) {
        CGRect thumbRect = thumbPositionArray[thumbsOnScreen].CGRectValue;
        if (thumbRect.origin.y <= BELOW(CONTAINER_FRAME))
            break;
    }
#endif
    
    if (displayRect.size.width < mainVC.minDisplayWidth) {
        score = 0;
#ifdef DEBUG_SCORE
        NSLog(@"DS:  display too narrow");
#endif
        return;
    }
    if (displayRect.size.height < mainVC.minDisplayHeight) {
        score = 0;
#ifdef DEBUG_SCORE
        NSLog(@"DS:  display too short");
#endif
        return;
    }
#ifdef OLD
    if (displayFrac < mainVC.minDisplayFrac) {
        score = 0;
#ifdef DEBUG_SCORE
        NSLog(@"DS:  display too small a fraction");
#endif
        return;
    }
#endif

#define AREA(r) ((r).size.width * (r).size.height)
    
    CGFloat displayArea = AREA(displayRect);
    CGFloat containerArea = AREA(SCREEN);
    displayFrac = displayArea / containerArea;
    CGFloat usedArea = displayArea + AREA(executeRect) + AREA(plusRect) +
        AREA(paramRect) + AREA(thumbScrollRect);
    pctUsed = 100.0*(usedArea/AREA(SCREEN));
    
#ifdef DEBUG_LAYOUT
    NSLog(@"area %4.1f%% = d%4.1f%% e%4.1f%% p%4.1f%% P%4.1f%% T%4.1f%%",
          pctUsed,
          displayArea,
          100.0*(AREA(executeRect))/AREA(SCREEN),
          100.0*(AREA(plusRect))/AREA(SCREEN),
          100.0*(AREA(paramRect))/AREA(SCREEN),
          100.0*(AREA(thumbScrollRect))/AREA(SCREEN));
    
#endif
    
    if (scale == 1.0)
        scaleScore = 1.0;
    else if (scale > 1.0)
        scaleScore = 0.9;   // expanding the image
    else {
        // reducing size isn't a big deal, but we want some penalty for unnecessary reduction
        // 0.8 is the lowest value
        // XXX scaling shouldn't be a factor for fixed images
        scaleScore = 0.8 + 0.2*scale;
    }
    
    // we want the largest display that shows all the thumbs, or, if not
    // room for all the thumbs, the most thumbs with a small display.
    int onScreenThumbsPerRow = thumbScrollRect.size.width / (firstThumbRect.size.width + SEP);
    int onScreenThumbsPerCol = thumbScrollRect.size.height / (firstThumbRect.size.height + SEP);
    int thumbsOnScreen = onScreenThumbsPerRow * onScreenThumbsPerCol;
    float pctThumbsShown = (float)thumbsOnScreen / (float)mainVC.thumbViewsArray.count;
    if (layoutOption != OnlyTransformDisplayed && pctThumbsShown < mainVC.minPctThumbsShown)
        thumbScore = 0;
    else {
        thumbScore = pctThumbsShown + displayFrac;
        long wastedThumbs = thumbsOnScreen - (int)mainVC.thumbViewsArray.count;
        
        if (wastedThumbs >= 0) {
            float wastedPenalty = pow(0.999, wastedThumbs);
            thumbScore *= wastedPenalty;  // slight penalty for wasted space
        }
    }

    displayScore = 1.0; // for now
    assert(thumbScore >= 0);
    assert(scaleScore >= 0);
    assert(displayScore >= 0);
    score = thumbScore * scaleScore * displayScore;
    score = pctUsed * displayFrac;
#ifdef DEBUG_SCORE
    NSLog(@"DS   %3.1f * %3.1f * %3.1f  = %3.1f",
          thumbScore, scaleScore, displayScore, score);
#endif
}

// I realize that the following may give the wrong result if one dimension
// is greater than the other, but the other is shorter.  It isn't
// that important.

- (NSComparisonResult) compare:(Layout *)layout {
    if (displayRect.size.width > layout.displayRect.size.width ||
        displayRect.size.height > layout.displayRect.size.height)
        return NSOrderedAscending;
    if (displayRect.size.width == layout.displayRect.size.width &&
        displayRect.size.height == layout.displayRect.size.height)
        return NSOrderedSame;
    return NSOrderedDescending;
}

+ (CGSize) fitSize:(CGSize)srcSize toSize:(CGSize)size {
    assert(size.height > 0);
    assert(size.width > 0);
    float xScale = size.width/srcSize.width;
    float yScale = size.height/srcSize.height;
    CGFloat scale = MIN(xScale,yScale);
    CGSize scaledSize;
    scaledSize.width = round(scale*srcSize.width);
    scaledSize.height = round(scale*srcSize.height);
    return scaledSize;
}

- (CGFloat) executeHForRowCount:(size_t)rows {
    return ((rows)*EXECUTE_ROW_H + 2*EXECUTE_BORDER_W + 2*SEP);
}

- (NSString *) layoutSum {
    return [NSString stringWithFormat:@"%4.0fx%4.0f %4.0fx%4.0f %4.2f  e%3.0fx%3.0f p%3.0fx%2.0f  df:%5.2f%%  sc:%4.2f %@",
            transformSize.width, transformSize.height,
            displayRect.size.width, displayRect.size.height,
            scale,
            executeRect.size.width, executeRect.size.height,
            paramRect.size.width, paramRect.size.height,
            displayFrac*100.0,
            score, type
    ];
}

- (void) dump {
    NSLog(@"layout dump:  type %@  score %.1f  scale %.2f", type, score, scale);
#ifdef OLD
    NSLog(@"screen format %@", format ? format : @"fixed image");
    if (format && depthFormat)
        NSLog(@"depth format %@", depthFormat);
#endif
    
    NSLog(@"source  %4.0fx%4.0f (%5.3f)",
          imageSourceSize.width, imageSourceSize.height,
          imageSourceSize.width / imageSourceSize.height);
    NSLog(@"trans   %4.0fx%4.0f (%5.3f)",
          imageSourceSize.width, imageSourceSize.height,
          imageSourceSize.width / imageSourceSize.height);
    NSLog(@"display %4.0fx%4.0f (%5.3f) at %.0f,%.0f",
          displayRect.size.width, displayRect.size.height,
          displayRect.size.width / displayRect.size.height,
          displayRect.origin.x, displayRect.origin.y);
    NSLog(@"param   %4.0fx%4.0f         at %.0f,%.0f",
          paramRect.size.width, paramRect.size.height,
          paramRect.origin.x, paramRect.origin.y);
    NSLog(@"exec    %4.0fx%4.0f         at %.0f,%.0f",
          executeRect.size.width, executeRect.size.height,
          executeRect.origin.x, executeRect.origin.y);
    NSLog(@"plus    %4.0fx%4.0f         at %.0f,%.0f",
          plusRect.size.width, plusRect.size.height,
          plusRect.origin.x, plusRect.origin.y);
    NSLog(@"first   %4.0fx%4.0f         at %.0f,%.0f",
          firstThumbRect.size.width, firstThumbRect.size.height,
          firstThumbRect.origin.x, firstThumbRect.origin.y);
}
@end
