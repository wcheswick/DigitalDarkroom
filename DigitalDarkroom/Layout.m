//
//  Layout.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/2/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Layout.h"
#import "Defines.h"

@interface Layout ()

@property (assign)  float minDisplayFrac, bestMinDisplayFrac;
@property (assign)  float minThumbFrac, bestMinThumbFrac;
@property (assign)  int minThumbRows, minThumbCols;

@end


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
    @"n",
    @"t",
    @"B",
    @"F",
};

@interface Layout ()

@property (assign)  CGSize imageSourceSize;

@end

@implementation Layout

@synthesize format, depthFormat;
@synthesize displayOption, thumbsPosition;

@synthesize minDisplayFrac, bestMinDisplayFrac;
@synthesize minThumbFrac, bestMinThumbFrac;
@synthesize minThumbRows, minThumbCols;
@synthesize imageSourceSize;
@synthesize transformSize, displayRect;
@synthesize displayFrac, thumbFrac;
@synthesize thumbArrayRect;
@synthesize executeRect, executeOverlayOK, executeIsTight;
@synthesize firstThumbRect, thumbImageRect;

@synthesize scale, aspectRatio;
@synthesize status, shortStatus;
@synthesize score, thumbScore, displayScore, scaleScore;

- (id)init {
    self = [super init];
    if (self) {
        scale = 0.0;
        score = BAD_LAYOUT;
        format = depthFormat = nil;
        thumbArrayRect = CGRectZero;
        displayRect = CGRectZero;
        transformSize = CGSizeZero;
        executeRect = CGRectZero;
        status = shortStatus = nil;
        imageSourceSize = CGSizeZero;
        
        // these values are tweaked to satisfy the all the cameras on two
        // different iPhones and two different iPads.
        
        if (mainVC.isiPhone) {
            bestMinDisplayFrac = 0.4;
            minDisplayFrac = 0.3;
            bestMinThumbFrac = 0.4; // unused
            minThumbFrac = 0.249;   // 0.3 for large iphones
            minThumbRows = MIN_IPHONE_THUMB_ROWS;
            minThumbCols = MIN_IPHONE_THUMB_COLS;
        } else {
            bestMinDisplayFrac = 0.65;  // 0.42;
            minDisplayFrac = 0.5;   // 0.40
            bestMinThumbFrac = 0.5;
            minThumbFrac = 0.3;
            minThumbRows = MIN_THUMB_ROWS;
            minThumbCols = MIN_THUMB_COLS;
       }
    }
    return self;
}


#define THUMBS_FOR_HEIGHT(h)  (int)((h+SEP) / (firstThumbRect.size.height + SEP))
#define THUMBS_FOR_WIDTH(w)  (int)((w+SEP) / (firstThumbRect.size.width + SEP))

//static float scales[] = {0.8, 0.6, 0.5, 0.4, 0.2};


// Figure out a reasonable layout for a particular incoming size.
// return NO if it can't be done. if NO,
// then the score is not computed.

- (BOOL) tryLayoutForSize:(CGSize) ss
          thumbRows:(int) rowsWanted
       thumbColumns:(int) columnsWanted {
    int thumbsShown;
    imageSourceSize = ss;
    
    if (rowsWanted == 0 && columnsWanted == 0)
        thumbsPosition = None;
    else if (rowsWanted == 0 && columnsWanted > 0)
        thumbsPosition = Right;
    else if (rowsWanted > 0 && columnsWanted == 0)
        thumbsPosition = Bottom;
    else
        thumbsPosition = Both;  // not implemented
    
    aspectRatio = imageSourceSize.width / imageSourceSize.height;

#define NO_SCALE    (-2.0)
#define SCALE_UNINITIALIZED (-1.0)
    scale = SCALE_UNINITIALIZED;
    
    firstThumbRect = thumbImageRect = CGRectZero;
    thumbImageRect.size.width = THUMB_W;
    thumbImageRect.size.height = round(thumbImageRect.size.width / aspectRatio);
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += THUMB_LABEL_H;

    CGFloat rightThumbWidthNeeded = [self widthForColumns:columnsWanted];
    CGFloat bottomThumbHeightNeeded = [self heightForRows:rowsWanted];

    displayRect.size.width = mainVC.containerView.frame.size.width - rightThumbWidthNeeded;
    displayRect.size.height = mainVC.containerView.frame.size.height - EXECUTE_MIN_H - bottomThumbHeightNeeded;
    if (displayRect.size.height <= 0 || displayRect.size.width <= 0)
        return NO;
    
    displayRect.size = [Layout fitSize:imageSourceSize toSize:displayRect.size];
    displayRect.origin = CGPointZero;   // needs centering
    thumbArrayRect = CGRectZero;

    if (columnsWanted && !rowsWanted) {  // nothing underneath at the moment
        [self placeExecuteRectWithSqueeze:NO];
        thumbsShown = [self placeThumbsOnRight];
    } else if (!columnsWanted && rowsWanted) {
        [self placeExecuteRectWithSqueeze:YES];
        thumbsShown = [self placeThumbsUnderneath];
    } else if (columnsWanted && rowsWanted) {
        [self placeExecuteRectWithSqueeze:YES];
        assert(NO); // both places, not yet
    } else {
        [self placeExecuteRectWithSqueeze:YES];
        thumbsShown = [self placeThumbsUnderneath];
    }

    // after placing the thumbs, the displayrect may be trimmed.  Find the
    // number of thumb rows/columns actually used, and apply penalty for
    // shortages.
    
    switch (thumbsPosition) {
        case Right: {
            int columnsUsed = [self columnsInThumbArray];
            if (columnsUsed > columnsWanted)
                thumbScore = 0;
            else
                thumbScore = (float)columnsUsed/(float)columnsWanted;
            break;
        }
        case Bottom: {
            int rowsUsed = [self rowsInThumbArray];
            if (rowsUsed > rowsWanted)
                thumbScore = 0;
            else
                thumbScore = (float)rowsUsed/(float)rowsWanted;
            break;
        }
        case None:
            thumbScore = 1.0;
            break;
        default:
            break;  // XXX stub for thumbs in both places
    }
    
    // A bit of a penalty needed for fewer thumbs displayed, about 1 point per
    // four missing.
//    float thumbFracMissing = (float)thumbsShown/(float)mainVC.thumbViewsArray.count;
    if (thumbScore) {
        long thumbsMissing = mainVC.thumbViewsArray.count - thumbsShown;
        if (thumbsMissing > 0)
            thumbScore -= (thumbsMissing/2.0)/100.0;
    }
    
    float displayArea = displayRect.size.width * displayRect.size.height;
    float containerArea = mainVC.containerView.frame.size.width * mainVC.containerView.frame.size.height;
    displayFrac = displayArea / containerArea;

    transformSize = displayRect.size;
    if (scale == SCALE_UNINITIALIZED)
        scale = displayRect.size.width / imageSourceSize.width;
    
    int thumbCount = (int)mainVC.thumbViewsArray.count;
    long wastedThumbs = thumbsShown - thumbCount;
//    float thumbFrac = wastedThumbs >= 0 ? 1.0 : (float)thumbsShown / (float)thumbCount;
    
#define MIN_TIGHT_DISPLAY_FRAC  0.2
#define MIN_BEST_DISPLAY_FRAC  0.3

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

    if (wastedThumbs >= 0) {
        float wastedPenalty = pow(0.999, wastedThumbs);
        thumbScore *= wastedPenalty;  // slight penalty for wasted space
    }
#ifdef MAYBE
    else {
        float maxThumbScore;
        switch (columnsWanted) {
            case 0:
            case 1:
                maxThumbScore = 0.4;
                break;
            case 2:
                maxThumbScore = 0.8;
                break;
            default:
                maxThumbScore = 1.0;
        }
        thumbScore = pow(maxThumbScore, 1.0 - thumbFrac);
    }
#endif
    
    displayScore = 1.0; // for now
    
    float widthFrac = displayRect.size.width / mainVC.containerView.frame.size.width;
    float heightFrac = displayRect.size.height / mainVC.containerView.frame.size.height;
    if (widthFrac < 0.25) {
        score = displayScore = 0;
        return NO;
    } else {
        if (widthFrac >= 0.55 && heightFrac >= 0.58)    // good enough
            displayScore = 1.0;
        else
            displayScore = MAX(widthFrac, heightFrac);
    }
    
    assert(thumbScore >= 0);
    assert(scaleScore >= 0);
    assert(displayScore >= 0);
    score = thumbScore * scaleScore * displayScore;
    
#ifdef LONG
    status = [NSString stringWithFormat:@"%4.0f %4.0f@%4.2f%%\t%@%@ %4.2f=f(%4.2f %4.2f %4.2f) T%2.0f",
              displayRect.size.width, displayRect.size.height, scale,
              displayOptionNames[displayOption], displayThumbsPosition[thumbsPosition],
              score, thumbScore, displayScore, scaleScore,
              round(thumbFrac*100.0)
              ];
#endif
    // the use of trunc here is to make 100% -> 99%, saving space in the tight display
    int displayWPct = trunc(100.0*(displayRect.size.width/mainVC.containerView.frame.size.width) - 0.1);
    int displayHPct = trunc(100.0*(displayRect.size.height/mainVC.containerView.frame.size.height) - 0.1);
    
    NSString *stats = [NSString stringWithFormat:@"%2.0f  %2.0f %2.0f %2.0f  %1d %1d  %2d %2d",
                       trunc(100.0*score),
                       trunc(100.0*displayScore - 0.1),
                       trunc(100.0*thumbScore - 0.1),
                       trunc(100.0*scaleScore - 0.1),
                       rowsWanted, columnsWanted,
                       displayWPct, displayHPct
                       ];
    status = [NSString stringWithFormat:@"%.0fx%.0f\t%4.2f%%\t%@\t%.0fx%.0f",
              displayRect.size.width, displayRect.size.height, scale, stats,
              displayRect.size.width, displayRect.size.height];
    shortStatus = stats;

    assert(same_aspect(imageSourceSize, displayRect.size));
    assert(BELOW(thumbArrayRect) <= mainVC.containerView.frame.size.height);
    assert(RIGHT(thumbArrayRect) <= mainVC.containerView.frame.size.width);
    assert(BELOW(executeRect) < mainVC.containerView.frame.size.height);
    assert(RIGHT(executeRect) < mainVC.containerView.frame.size.width);

    return YES;
}

- (CGFloat) widthForColumns:(size_t) nc {
    return nc * (firstThumbRect.size.width + SEP);
}

- (CGFloat) heightForRows:(size_t) nr {
    return nr * firstThumbRect.size.height + SEP;
}

- (int) columnsInThumbArray {
    return trunc(thumbArrayRect.size.width / (firstThumbRect.size.width + SEP) + 0.1);
}

- (int) rowsInThumbArray {
    return trunc(thumbArrayRect.size.height / (firstThumbRect.size.height + SEP) + 0.1);
}

- (int) placeThumbsUnderneath {
    thumbArrayRect = CGRectMake(0, BELOW(executeRect)+SEP, mainVC.containerView.frame.size.width,
                                LATER);
    thumbArrayRect.size.height = mainVC.containerView.frame.size.height - thumbArrayRect.origin.y;
    return [self trimThumbArray];
}

- (int) placeThumbsOnRight {
    thumbArrayRect = CGRectMake(RIGHT(displayRect)+SEP, displayRect.origin.y, LATER,
                                mainVC.containerView.frame.size.height);
    thumbArrayRect.size.width = mainVC.containerView.frame.size.width - thumbArrayRect.origin.x;
    return [self trimThumbArray];
}

// if the array holds all our thumbs, trim extra width and height as needed
// in any case, return number of thumbs displayed in the array
- (int) trimThumbArray {
    int thumbsInRow = THUMBS_FOR_WIDTH(thumbArrayRect.size.width);
    int thumbsInCol = THUMBS_FOR_HEIGHT(thumbArrayRect.size.height);
    int thumbCount = thumbsInCol * thumbsInRow;
//    if (thumbCount < (int)mainVC.thumbViewsArray.count)
//        return thumbCount;
    thumbArrayRect.size.width = thumbsInRow * (firstThumbRect.size.width + SEP) - SEP;
    thumbArrayRect.size.height = thumbsInCol * (firstThumbRect.size.height + SEP) - SEP;
    return thumbCount;
}

- (void) showThumbArraySize:(CGSize) s {
    int thumbRows = THUMBS_FOR_HEIGHT(s.height);
    int thumbCols = THUMBS_FOR_WIDTH(s.width);
    NSLog(@"********* Thumb array size for %.1f x %.1f: %d x %d = %d",
          s.width, s.height, thumbCols, thumbRows, thumbRows*thumbCols);
}

- (void) placeExecuteRectWithSqueeze:(BOOL) squeeze {
    executeRect.size.width = displayRect.size.width - 1;
    executeRect.origin.x = displayRect.origin.x;
    CGFloat spaceBelowDisplay = mainVC.containerView.frame.size.height -
        BELOW(displayRect) - SEP - 1;
    if (squeeze || spaceBelowDisplay < EXECUTE_FULL_H) {
        executeRect.origin.y = BELOW(displayRect);
        executeRect.size.height = EXECUTE_MIN_H;
        executeIsTight = YES;
        executeOverlayOK = YES;
    } else {
        executeRect.origin.y = BELOW(displayRect) + SEP;
        executeRect.size.height = spaceBelowDisplay;
        executeIsTight = NO;
        executeOverlayOK = NO;
    }
}

// I realize that teh following may give the wrong result if one dimension
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

+ (CGFloat) scaleToFitSize:(CGSize)srcSize toSize:(CGSize)size {
    float xScale = size.width/srcSize.width;
    float yScale = size.height/srcSize.height;
    return MIN(xScale,yScale);
}

+ (CGSize) fitSize:(CGSize)srcSize toSize:(CGSize)size {
    assert(size.height > 0);
    assert(size.width > 0);
    CGFloat scale = [self scaleToFitSize:srcSize toSize:size];
    CGSize scaledSize;
    scaledSize.width = round(scale*srcSize.width);
    scaledSize.height = round(scale*srcSize.height);
    return scaledSize;
}

@end
