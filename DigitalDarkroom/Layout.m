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

@interface Layout ()

@property (assign)  ThumbsPosition thumbsPosition;
@property (assign)  float thumbScore, displayScore, scaleScore;
@property (assign)  float thumbFrac;
@property (assign)  float minDisplayFrac, bestMinDisplayFrac;
@property (assign)  float minThumbFrac, bestMinThumbFrac;
@property (assign)  int minThumbRows, minThumbCols;
@property (assign)  int minDisplayWidth, maxDisplayWidth, minDisplayHeight, maxDisplayHeight;

@end

@implementation Layout

@synthesize format, depthFormat;
@synthesize displayOption, thumbsPosition;

@synthesize minDisplayFrac, bestMinDisplayFrac;
@synthesize minThumbFrac, bestMinThumbFrac;
@synthesize minThumbRows, minThumbCols;
@synthesize maxThumbRows, maxThumbColumns;
@synthesize imageSourceSize;
@synthesize transformSize, displayRect;
@synthesize displayFrac, thumbFrac;
@synthesize thumbArrayRect, plusRect;
@synthesize executeRect, executeOverlayOK, executeIsTight;
@synthesize firstThumbRect, thumbImageRect;

@synthesize scale, aspectRatio;
@synthesize status;
@synthesize score, thumbScore, displayScore, scaleScore;
@synthesize minDisplayWidth, maxDisplayWidth, minDisplayHeight, maxDisplayHeight;

- (id)initWithOption:(DisplayOptions) disopt
          sourceSize:(CGSize) ss
              format:(AVCaptureDeviceFormat * __nullable) fmt {
    self = [super init];
    if (self) {
        displayOption = disopt;
        imageSourceSize = ss;
        format = fmt;
        depthFormat = nil;
        
        aspectRatio = imageSourceSize.width / imageSourceSize.height;
        firstThumbRect = thumbImageRect = CGRectZero;
        thumbImageRect.size = CGSizeMake(THUMB_W, trunc(THUMB_W/aspectRatio));
        firstThumbRect.size = CGSizeMake(thumbImageRect.size.width,
                                         thumbImageRect.size.height + THUMB_LABEL_H);
        
        maxThumbRows = [self thumbsForWidth:mainVC.containerView.frame.size.height];
        maxThumbColumns = [self thumbsForHeight:mainVC.containerView.frame.size.height];
        
        scale = 0.0;
        score = BAD_LAYOUT;
        thumbArrayRect = CGRectZero;
        displayRect = CGRectZero;
        transformSize = CGSizeZero;
        executeRect = CGRectZero;
        status = nil;
        
        // these values are tweaked to satisfy the all the cameras on two
        // different iPhones and two different iPads.
      
        [self updateScreenLimits];
    }
    return self;
}

- (void) updateScreenLimits {
    if (mainVC.isiPhone) {
        if (mainVC.isPortrait) {
            minDisplayWidth = mainVC.containerView.frame.size.width / 3.0;
            maxDisplayWidth = 0;    // no max
            minDisplayHeight = THUMB_W*2;
            maxDisplayHeight = mainVC.containerView.frame.size.height / 3.0;
        } else {
            minDisplayWidth = THUMB_W*2.0;
            maxDisplayWidth = mainVC.containerView.frame.size.width / 3.0;    // no max
            minDisplayHeight = THUMB_W*2;
            maxDisplayHeight = 0;   // no limit
        }
        bestMinDisplayFrac = 0.4;
        minDisplayFrac = 0.3;
        bestMinThumbFrac = 0.4; // unused
        minThumbFrac = 0.249;   // 0.3 for large iphones
        minThumbRows = MIN_IPHONE_THUMB_ROWS;
        minThumbCols = MIN_IPHONE_THUMB_COLS;
    } else {
        minDisplayWidth = maxDisplayWidth = minDisplayHeight = maxDisplayHeight = 0; // XXXX STUB
        bestMinDisplayFrac = 0.65;  // 0.42;
        minDisplayFrac = 0.5;   // 0.40
        bestMinThumbFrac = 0.5;
        minThumbFrac = 0.3;
        minThumbRows = MIN_THUMB_ROWS;
        minThumbCols = MIN_THUMB_COLS;
   }
}

- (CGFloat) thumbsForHeight:(CGFloat) height {
    return (int)((height+SEP) / (firstThumbRect.size.height + SEP));
}

- (CGFloat) thumbsForWidth:(CGFloat) width {
    return (int)((width+SEP) / (firstThumbRect.size.width + SEP));
}

- (CGFloat) widthForColumns:(size_t) nc {
    return nc * (firstThumbRect.size.width + SEP);
}

- (CGFloat) heightForRows:(size_t) nr {
    return nr * firstThumbRect.size.height + SEP;
}

// Figure out a reasonable layout for a particular incoming size.
// return NO if it can't be done. if NO, then the score is not computed.

- (BOOL) tryLayoutForThumbRowCount:(int) rowsWanted
                       columnCount:(int) columnsWanted {
    if (rowsWanted == 0 && columnsWanted == 0)
        thumbsPosition = None;
    else if (rowsWanted == 0 && columnsWanted > 0)
        thumbsPosition = Right;
    else if (rowsWanted > 0 && columnsWanted == 0)
        thumbsPosition = Bottom;
    else
        thumbsPosition = Both;  // not implemented

#define NO_SCALE    (-2.0)
#define SCALE_UNINITIALIZED (-1.0)
    scale = SCALE_UNINITIALIZED;

    CGFloat rightThumbWidthNeeded = [self widthForColumns:columnsWanted];
    CGFloat bottomThumbHeightNeeded = [self heightForRows:rowsWanted];
    
    displayRect.size.width = mainVC.containerView.frame.size.width - rightThumbWidthNeeded;
    displayRect.size.height = mainVC.containerView.frame.size.height - EXECUTE_MIN_H - bottomThumbHeightNeeded - EXECUTE_MIN_H;
    if (displayRect.size.height <= 0 || displayRect.size.width <= 0)
        if (displayOption != ThumbsOnly)
            return NO;
    if (displayRect.size.height <= minDisplayHeight ||
        displayRect.size.width <= minDisplayWidth)
        return NO;  // display just too tiny

    displayRect.size = [Layout fitSize:imageSourceSize toSize:displayRect.size];
    displayRect.origin = CGPointZero;   // needs centering
    
    switch (thumbsPosition) {
        case Bottom:    // check display height limits
            if (minDisplayHeight && displayRect.size.height < minDisplayHeight)
                return NO;
            if (maxDisplayHeight && displayRect.size.height < maxDisplayHeight)
                return NO;
            break;
        case Right:     // check display width limits
            if (minDisplayWidth && displayRect.size.width < minDisplayWidth)
                return NO;
//            if (maxDisplayWidth && displayRect.size.width > maxDisplayWidth)
//                return NO;
            break;
        default:
            break;
    }
    
    transformSize = displayRect.size;
    if (scale == SCALE_UNINITIALIZED)
        scale = displayRect.size.width / imageSourceSize.width;

    thumbArrayRect = CGRectZero;
    int thumbsShown;
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
    
    // we want the largest display that shows all the thumbs, or, if not
    // room for all the thumbs, the most thumbs with a small display.
    switch (displayOption) {
        case iPhoneScreen: {
            float pctThumbsShown = round(100.0*((float)thumbsShown/mainVC.thumbViewsArray.count));
            if (pctThumbsShown < 7.0)
                return NO;
            score = pctThumbsShown + displayFrac;
            return YES;
        }
        default:
            ; // iPhone display stub
    }
    
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

    assert(same_aspect(imageSourceSize, displayRect.size));
    assert(BELOW(thumbArrayRect) <= mainVC.containerView.frame.size.height);
    assert(RIGHT(thumbArrayRect) <= mainVC.containerView.frame.size.width);
    assert(BELOW(executeRect) < mainVC.containerView.frame.size.height);
    assert(RIGHT(executeRect) < mainVC.containerView.frame.size.width);

    return YES;
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
    int thumbsInRow = [self thumbsForWidth:thumbArrayRect.size.width];
    int thumbsInCol = [self thumbsForHeight:thumbArrayRect.size.height];

    thumbArrayRect.size.width = thumbsInRow * (firstThumbRect.size.width + SEP) - SEP;
    thumbArrayRect.size.height = thumbsInCol * (firstThumbRect.size.height + SEP) - SEP;
    return thumbsInCol * thumbsInRow;
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

- (NSString *) info {
    int thumbsInRow = [self thumbsForWidth:thumbArrayRect.size.width];
    int thumbsInCol = [self thumbsForHeight:thumbArrayRect.size.height];
    int thumbsShown = thumbsInRow * thumbsInCol;
    
    return [NSString stringWithFormat:@"%4.0f x%4.0f   %@  %6.2f  %2dx%2d=%3d",
          displayRect.size.width, displayRect.size.height,
          displayOptionNames[displayOption],
            score,
            thumbsInRow, thumbsInCol, thumbsShown];
}

- (id)copyWithZone:(NSZone *)zone {
    Layout *copy = [[Layout alloc] initWithOption:displayOption
                                           sourceSize:imageSourceSize
                                               format:format];
    copy.depthFormat = self.depthFormat;
    copy.score = self.score;
    copy.executeIsTight = self.executeIsTight;
    copy.transformSize = self.transformSize;
    copy.displayRect = self.displayRect;
    copy.displayFrac = self.displayFrac;
    copy.thumbArrayRect = self.thumbArrayRect;
    copy.firstThumbRect = self.firstThumbRect;
    copy.thumbImageRect = self.thumbImageRect;
    copy.executeRect = self.executeRect;
    copy.executeOverlayOK = executeOverlayOK;
    copy.status = self.status;
    copy.maxThumbRows = self.maxThumbRows;
    copy.maxThumbColumns = self.maxThumbColumns;
    return copy;
}

@end
