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

@implementation Layout

@synthesize format;
@synthesize displayOption, thumbsPosition;
@synthesize sourceSize;

@synthesize minDisplayFrac, bestMinDisplayFrac;
@synthesize minThumbFrac, bestMinThumbFrac;
@synthesize minThumbRows, minThumbCols;
@synthesize targetDisplaySize;
@synthesize transformSize, displayRect;
@synthesize displayFrac, thumbFrac;
@synthesize thumbArrayRect;
@synthesize executeRect, executeOverlayOK, executeIsTight;
@synthesize firstThumbRect, thumbImageRect;

@synthesize scale, aspectRatio;
@synthesize status;
@synthesize score, thumbScore, displayScore, scaleScore;

- (id)init {
    self = [super init];
    if (self) {
        scale = 0.0;
        score = BAD_LAYOUT;
        format = nil;
        thumbArrayRect = CGRectZero;
        displayRect = CGRectZero;
        transformSize = CGSizeZero;
        executeRect = CGRectZero;
        status = nil;
        
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

// Can we make an acceptible layout with the given capture size and scaling?
// return no if layout is bad. we return self for readability.

- (void) proposeLayoutForSourceSize:(CGSize) size
                           thumbsOn:(ThumbsPosition) position
                      displayOption:(DisplayOptions) displayOption {
    sourceSize = size;
    thumbsPosition = position;
    aspectRatio = sourceSize.width / sourceSize.height;
//    float containerAspect = mainVC.containerView.frame.size.width/mainVC.containerView.frame.size.height;
    int thumbCount = (int)mainVC.thumbViewsArray.count;
    
    score = thumbScore = displayScore = scaleScore = -1;   // unassigned
    scale = -1.0;

#ifdef NOTDEF
    NSLog(@"configureLayoutWithDisplayOption %d", displayOption);
    NSLog(@"     container: %.0f,%.0f  %.0fx%.0f (%4.2f)",
          mainVC.containerView.frame.origin.x, mainVC.containerView.frame.origin.y,
          mainVC.containerView.frame.size.width, mainVC.containerView.frame.size.height,
          mainVC.containerView.frame.size.width/mainVC.containerView.frame.size.height);
    NSLog(@"        source: %.0fx%.0f (%4.2f)",
          captureSize.width, captureSize.height,
          aspectRatio);
#endif
    
    thumbArrayRect = CGRectZero;
    firstThumbRect = thumbImageRect = CGRectZero;
    thumbImageRect.size.width = mainVC.isiPhone || displayOption == TightDisplay ? TIGHT_THUMB_W : THUMB_W;
    thumbImageRect.size.height = round(thumbImageRect.size.width / aspectRatio);
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += THUMB_LABEL_H;
    
    displayRect.origin = CGPointZero;
    // guess appropriate screen size, including executeRect
    
    long thumbsPerCol, thumbsPerRow;
    long rowsNeeded, colsNeeded;
    long thumbsShown = -1;
    
    switch (displayOption) {
        case NoDisplay:     // just controls, no transform view
            displayRect = CGRectZero;
            scale = 0;
            thumbsPerRow = THUMBS_FOR_WIDTH(mainVC.containerView.frame.size.width);
            rowsNeeded = (thumbCount + (thumbsPerRow - 1)) / thumbsPerRow;
            colsNeeded = thumbCount / rowsNeeded;
            thumbsShown = rowsNeeded * colsNeeded;
            thumbScore = displayScore = scaleScore = 1.0;
            [self placeExecuteRectWithSqueeze:NO];
            [self placeThumbsUnderneath];
            break;
        case FullScreenDisplay:
            displayRect.size = [Layout fitSize:sourceSize toSize:mainVC.containerView.frame.size];
            displayRect.origin = CGPointZero;   // needs centering
            [self placeExecuteRectWithSqueeze:YES];
            thumbArrayRect = CGRectZero;
            thumbScore = 1.0;
            break;
        case TightDisplay:
            if (thumbsPosition == Right && RIGHT(mainVC.containerView.frame) < 500) {   // no room on right
                NSLog(@" LLLL reject thumbs on tight right, screen too narrow");
                thumbScore = 0.0;
            }
            executeIsTight = YES;
            if (thumbsPosition == Bottom) {
                CGFloat minThumbsOnBottomHeight = round(1.5*(firstThumbRect.size.height + SEP));
                CGFloat targetHeight = round(mainVC.containerView.frame.size.height -
                                             EXECUTE_MIN_H - minThumbsOnBottomHeight);
                displayRect.size = [Layout fitSize:sourceSize
                                            toSize: CGSizeMake(mainVC.containerView.frame.size.width,
                                                               targetHeight)];
            } else {
                CGFloat minThumbsOnRightWidth = 2*(firstThumbRect.size.width + SEP);
                displayRect.size = [Layout fitSize:sourceSize
                                            toSize: CGSizeMake(mainVC.containerView.frame.size.width - SEP -
                                                               minThumbsOnRightWidth,
                                                               round(mainVC.containerView.frame.size.height -
                                                                     EXECUTE_MIN_H - minThumbsOnRightWidth))];
            }
            [self placeExecuteRectWithSqueeze:YES];
            if (thumbsPosition == Bottom) {
                thumbsShown = [self placeThumbsUnderneath];
            } else {
                thumbsShown = [self placeThumbsOnRight];
            }
            break;
        case BestDisplay:
            executeIsTight = NO;
            if (thumbsPosition == Bottom) {
                thumbsPerRow = THUMBS_FOR_WIDTH(mainVC.containerView.frame.size.width);
                long rowsNeeded = (thumbCount + (thumbsPerRow - 1)) / thumbsPerRow;
                CGFloat fullThumbsHeightNeeded = rowsNeeded * (firstThumbRect.size.width + SEP);
                displayRect.size = [Layout fitSize:sourceSize
                                            toSize: CGSizeMake(mainVC.containerView.frame.size.width,
                                                               round(mainVC.containerView.frame.size.height -
                                                                     EXECUTE_MIN_H - fullThumbsHeightNeeded))];
                [self placeExecuteRectWithSqueeze:YES];
                thumbsShown = [self placeThumbsUnderneath];
            } else {    // thumbs on right
                thumbsPerCol = THUMBS_FOR_HEIGHT(mainVC.containerView.frame.size.height);
                colsNeeded = (thumbCount + (thumbsPerCol - 1)) / thumbsPerCol;
                CGFloat fullThumbsWidthNeeded = colsNeeded * (firstThumbRect.size.width + SEP);
                displayRect.size = [Layout fitSize:sourceSize
                                            toSize: CGSizeMake(mainVC.containerView.frame.size.width - SEP -
                                                               fullThumbsWidthNeeded,
                                                               round(mainVC.containerView.frame.size.height -
                                                                     EXECUTE_FULL_H))];
                [self placeExecuteRectWithSqueeze:NO];
                thumbsShown = [self placeThumbsOnRight];
            }
            break;
    }
    transformSize = displayRect.size;
    if (scale < 0)
        scale = displayRect.size.width / sourceSize.width;
    
    long wastedThumbs = thumbsShown - thumbCount;
    float thumbFrac = wastedThumbs >= 0 ? 1.0 : (float)thumbsShown / (float)thumbCount;
    
#define MIN_TIGHT_DISPLAY_FRAC  0.2
#define MIN_BEST_DISPLAY_FRAC  0.3
    
    switch (displayOption) {
        case NoDisplay:
            scaleScore = 1.0;
            thumbScore = 1.0;
            break;
        case FullScreenDisplay:
            if (scale == 1.0)
                scaleScore = 1.0;
            else if (scale > 1.0)
                scaleScore = 0.8;   // expanding the image
            else
                scaleScore = 0.9;   // cost of scaling, which shouldn't be a thing if fixed image
            thumbScore = 1.0;
            break;
        case TightDisplay:
            if (displayRect.size.width < 1.5*firstThumbRect.size.width ||
                displayRect.size.height < 1.5*firstThumbRect.size.height) {
                displayScore = 0;
            } else
                displayScore = 1.0;
            if (scale == 1.0)
                scaleScore = 1.0;
            else if (scale > 1.0)
                scaleScore = 0.6;   // expanding the image
            else
                scaleScore = 0.9;   // cost of scaling, which shouldn't be a thing if fixed image
            
            thumbScore = thumbsShown < 5 ? 0.0 : thumbFrac;
            break;
        case BestDisplay:
            if (displayRect.size.width < 2*firstThumbRect.size.width ||
                displayRect.size.height < 2*firstThumbRect.size.height) {
                displayScore = 0;
            } else
                displayScore = 1.0; // XXX needs to be subtler
            if (scale == 1.0)
                scaleScore = 1.0;
            else if (scale > 1.0)
                scaleScore = 0.7;   // expanding the image
            else
                scaleScore = 0.9;   // cost of scaling, which shouldn't be a thing if fixed image
            
            if (wastedThumbs >= 0) {
                float wastedPenalty = pow(0.999, wastedThumbs);
                thumbScore = wastedPenalty;  // slight penalty for wasted space
            } else {
                thumbScore = thumbFrac;
            }
            break;
    }
#ifdef NOTDEF
    float captureArea = captureSize.width * captureSize.height;
    float displayArea = displayRect.size.width * displayRect.size.height;
    NSLog(@" thumb fraction: %.2f", thumbFrac);
    [self showThumbArraySize:thumbArrayRect.size];

    float containerArea = mainVC.containerView.frame.size.width * mainVC.containerView.frame.size.height;
    displayFrac = displayArea / containerArea;
    
#ifdef DEBUG_LAYOUT
    NSLog(@"LLLL: %4.0f x %4.0f @ %.1f (%4.2f)  q:%3d  %@ ",
          captureSize.width, captureSize.height, scale, aspectRatio,
          quality, status);
#endif
#endif

    float widthFrac = displayRect.size.width / mainVC.containerView.frame.size.width;
    if (widthFrac < 0.25) {
        NSLog(@"LLLL display too skinny: %0.5f", widthFrac);
        displayScore = 0;
    }
    
    assert(thumbScore >= 0);
    assert(scaleScore >= 0);
    assert(displayScore >= 0);
    score = thumbScore * scaleScore * displayScore;
    
    status = [NSString stringWithFormat:@"%4.0fx%4.0f -> %.0f x %.0f    @%4.2f%%   %@%@  %2.0f   %4.2f  %4.2f %4.2f %4.2f",
              sourceSize.width, sourceSize.height,
              displayRect.size.width, displayRect.size.height, scale,
              displayOptionNames[displayOption], displayThumbsPosition[position],
              round(thumbFrac*100.0),
              score, thumbScore, displayScore, scaleScore];
    if (score == 0.0)
        NSLog(@"     %@", status);

    assert(BELOW(thumbArrayRect) <= mainVC.containerView.frame.size.height);
    assert(RIGHT(thumbArrayRect) <= mainVC.containerView.frame.size.width);
    assert(BELOW(executeRect) <= mainVC.containerView.frame.size.height);
    assert(RIGHT(executeRect) <= mainVC.containerView.frame.size.width);
     return;
}

// return NO if it can't be done, usually too many thumbs. if NO,
// then the score is not computed.

- (BOOL) tryLayoutForSize:(CGSize) sourceSize
          thumbRows:(size_t) rowCount
       thumbColumns:(size_t) columnCount {
    int thumbsShown;
    
    assert(rowCount == 0 || columnCount == 0);  // for now
    
    aspectRatio = sourceSize.width / sourceSize.height;

    firstThumbRect = thumbImageRect = CGRectZero;
    thumbImageRect.size.width = mainVC.isiPhone  ? TIGHT_THUMB_W : THUMB_W;
    thumbImageRect.size.height = round(thumbImageRect.size.width / aspectRatio);
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += THUMB_LABEL_H;

    CGFloat rightThumbWidthNeeded = columnCount * firstThumbRect.size.width + SEP;
    CGFloat bottomThumbHeightNeeded = rowCount * firstThumbRect.size.height + SEP;

    displayRect.size.width = mainVC.containerView.frame.size.width - rightThumbWidthNeeded;
    displayRect.size.height = mainVC.containerView.frame.size.height - EXECUTE_MIN_H - bottomThumbHeightNeeded;
    if (displayRect.size.height < 0 || displayRect.size.width < 0)
        return NO;
    
    displayRect.size = [Layout fitSize:sourceSize toSize:displayRect.size];
    displayRect.origin = CGPointZero;   // needs centering
    [self placeExecuteRectWithSqueeze:YES];
    thumbArrayRect = CGRectZero;

    if (columnCount && !rowCount) {  // nothing underneath at the moment
        thumbsShown = [self placeThumbsOnRight];
    } else if (!columnCount && rowCount) {
        thumbsShown = [self placeThumbsUnderneath];
    } else if (columnCount && rowCount) {
        assert(NO); // both places, not yet
    } else
        thumbsShown = [self placeThumbsUnderneath];

    transformSize = displayRect.size;
    if (scale < 0)
        scale = displayRect.size.width / sourceSize.width;
    
    int thumbCount = (int)mainVC.thumbViewsArray.count;
    long wastedThumbs = thumbsShown - thumbCount;
    float thumbFrac = wastedThumbs >= 0 ? 1.0 : (float)thumbsShown / (float)thumbCount;
    
#define MIN_TIGHT_DISPLAY_FRAC  0.2
#define MIN_BEST_DISPLAY_FRAC  0.3

    if (scale == 1.0)
        scaleScore = 1.0;
    else if (scale > 1.0)
        scaleScore = 0.6;   // expanding the image
    else
        scaleScore = 0.9;   // cost of scaling, which shouldn't be a thing if fixed image

    if (wastedThumbs >= 0) {
        float wastedPenalty = pow(0.999, wastedThumbs);
        thumbScore = wastedPenalty;  // slight penalty for wasted space
    } else {
        thumbScore = thumbFrac;
    }

    displayScore = 1.0; // for now
    
    float widthFrac = displayRect.size.width / mainVC.containerView.frame.size.width;
    if (widthFrac < 0.25) {
        NSLog(@"LLLL display too skinny: %0.5f", widthFrac);
        displayScore = 0;
    } else if (widthFrac < 0.5)
        displayScore = widthFrac;
    
    assert(thumbScore >= 0);
    assert(scaleScore >= 0);
    assert(displayScore >= 0);
    score = thumbScore * scaleScore * displayScore;
    
    status = [NSString stringWithFormat:@"%4.0fx%4.0f -> %.0f x %.0f    @%4.2f%%    %zu %zu   %2.0f   %4.2f  %4.2f %4.2f %4.2f",
              sourceSize.width, sourceSize.height,
              displayRect.size.width, displayRect.size.height, scale,
              rowCount, columnCount,
              round(thumbFrac*100.0),
              score, thumbScore, displayScore, scaleScore];
    if (score == 0.0)
        NSLog(@"     %@", status);

    assert(BELOW(thumbArrayRect) <= mainVC.containerView.frame.size.height);
    assert(RIGHT(thumbArrayRect) <= mainVC.containerView.frame.size.width);
    assert(BELOW(executeRect) <= mainVC.containerView.frame.size.height);
    assert(RIGHT(executeRect) <= mainVC.containerView.frame.size.width);

    return YES;
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
    if (thumbCount < (int)mainVC.thumbViewsArray.count)
        return thumbCount;
    thumbArrayRect.size.width = thumbsInRow * (firstThumbRect.size.width + SEP);
    thumbArrayRect.size.height = thumbsInCol * (firstThumbRect.size.height + SEP);
    return thumbCount;
}

- (void) showThumbArraySize:(CGSize) s {
    int thumbRows = THUMBS_FOR_HEIGHT(s.height);
    int thumbCols = THUMBS_FOR_WIDTH(s.width);
    NSLog(@"********* Thumb array size for %.1f x %.1f: %d x %d = %d",
          s.width, s.height, thumbCols, thumbRows, thumbRows*thumbCols);
}

- (void) placeExecuteRectWithSqueeze:(BOOL) squeeze {
    executeRect.size.width = displayRect.size.width;
    executeRect.origin.x = displayRect.origin.x;
    CGFloat spaceBelowDisplay = mainVC.containerView.frame.size.height - BELOW(displayRect);
    if (squeeze || spaceBelowDisplay < EXECUTE_FULL_H) {
        executeRect.origin.y = BELOW(displayRect);
        executeRect.size.height = EXECUTE_MIN_H;
        executeIsTight = YES;
        executeOverlayOK = YES;
    } else {
        executeRect.origin.y = BELOW(displayRect) + SEP;
        executeRect.size.height = MIN(spaceBelowDisplay, EXECUTE_FULL_H);
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
