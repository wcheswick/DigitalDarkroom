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


#define EXECUTE_ROW_H       (mainVC.execFontSize + SEP)
#define EXECUTE_H_FOR(n)    ((n)*EXECUTE_ROW_H + 2*EXECUTE_BORDER_W + 2*SEP)
#define EXECUTE_MIN_H       MIN(PLUS_SIZE, EXECUTE_H_FOR(1))
#define EXECUTE_FULL_H      [self executeHForRowCount:6]

#define SCALE_UNINITIALIZED (-1.0)

#define SCREEN  mainVC.containerView.frame

@interface Layout ()


@property (assign)  ThumbsPosition thumbsPosition;
@property (assign)  float thumbScore, displayScore, scaleScore;
@property (assign)  float thumbFrac;

@end

@implementation Layout

@synthesize transformSize;   // what we give the transform chain
@synthesize displayRect;     // where we put the transformed (and scaled) result
@synthesize fullThumbViewRect;
@synthesize thumbScrollRect;
@synthesize executeRect;     // where the active transform list is shown
@synthesize plusRect;        // in executeRect
@synthesize paramRect;       // where the parameter slider goes

@synthesize firstThumbRect;  // thumb size and position in fullThumbViewRect
@synthesize thumbImageRect;  // image sample size in each thumb button

@synthesize format, depthFormat;
@synthesize displayOption, thumbsPosition;

@synthesize maxThumbRows, maxThumbCols;
@synthesize imageSourceSize;
@synthesize executeIsTight;
@synthesize displayFrac, thumbFrac;
@synthesize scale, aspectRatio;
@synthesize executeOverlayOK;
@synthesize status, type;
@synthesize score, thumbScore, displayScore, scaleScore;

- (id)initForSize:(CGSize) ss
      rightThumbs:(size_t) rightThumbs
     bottomThumbs:(size_t) bottomThumbs
    displayOption:(DisplayOptions) dopt
              format:(AVCaptureDeviceFormat * __nullable) fmt {
    self = [super init];
    if (self) {
        assert(rightThumbs == 0 || bottomThumbs == 0); // no fancy stuff
        
        imageSourceSize = ss;
        format = fmt;
        displayOption = dopt;
        depthFormat = nil;
        score = BAD_LAYOUT;
        status = nil;   // XXX may be a dreg
        
        aspectRatio = imageSourceSize.width / imageSourceSize.height;
        firstThumbRect = thumbImageRect = CGRectZero;
        thumbImageRect.size = CGSizeMake(THUMB_W, trunc(THUMB_W/aspectRatio));
        firstThumbRect.size = CGSizeMake(thumbImageRect.size.width,
                                         thumbImageRect.size.height + THUMB_LABEL_H);
        BOOL narrowScreen = mainVC.isiPhone;
        CGSize basicExecuteSize = CGSizeMake(narrowScreen ? mainVC.minExecWidth : mainVC.minExecWidth,
                                             narrowScreen ? EXECUTE_MIN_H : EXECUTE_FULL_H);

        CGSize targetSize;
        displayRect.origin = CGPointZero;
        if (rightThumbs) {
            type = @"DP/ET";    // display and params on left, execute and thumbs on right
            thumbScrollRect.size.height = mainVC.containerView.frame.size.height - basicExecuteSize.height;
            thumbScrollRect.size.width = (thumbImageRect.size.width + SEP)*rightThumbs;
            targetSize = CGSizeMake(SCREEN.size.width - thumbScrollRect.size.width - SEP,
                                    SCREEN.size.height - SEP - PARAM_VIEW_H);
            displayRect.size = [Layout fitSize:imageSourceSize toSize:targetSize];
            if (displayRect.size.width < mainVC.minDisplayWidth) {
                NSLog(@"rejected: too many thumbs on right: %zu", rightThumbs);
                return nil;
            }
            paramRect.origin.y = BELOW(displayRect) + SEP;

            // adjust thumbs view for actual available width:
            thumbScrollRect.size.width = thumbScrollRect.size.width - thumbScrollRect.origin.x;
            
            executeRect.origin = CGPointMake(RIGHT(displayRect) + SEP, 0);
            executeRect.size = CGSizeMake(thumbScrollRect.size.width, basicExecuteSize.height);
            thumbScrollRect.origin = CGPointMake(executeRect.origin.x, BELOW(executeRect) + SEP);
            thumbScrollRect.size.height = SCREEN.size.height - thumbScrollRect.origin.y;
        } else {
            type = @"DPET"; // all in a column
            thumbScrollRect.size.width = mainVC.containerView.frame.size.width;
            thumbScrollRect.size.height = thumbImageRect.size.height + (bottomThumbs - 1)*SEP;
            targetSize = CGSizeMake(SCREEN.size.width,
                                    SCREEN.size.height - SEP - PARAM_VIEW_H - SEP - thumbScrollRect.size.height);
            displayRect.size = [Layout fitSize:imageSourceSize toSize:targetSize];
            if (displayRect.size.height < mainVC.minDisplayHeight) {
                NSLog(@"rejected: too many thumbs on bottom: %zu", bottomThumbs);
                return nil;
            }
            paramRect.origin.y = BELOW(displayRect) + SEP;
            thumbScrollRect.origin.y = BELOW(paramRect) + SEP;
            thumbScrollRect.size.height = SCREEN.size.height - thumbScrollRect.origin.y;
        }
        
        plusRect = CGRectMake(0, 0, PLUS_SIZE, PLUS_SIZE);
        // plus sits at the beginning of the thumbs.  For now.
        firstThumbRect.origin = CGPointMake(RIGHT(plusRect) + SEP, 0);
        
        fullThumbViewRect.origin = CGPointZero;
        fullThumbViewRect.size = CGSizeMake(thumbScrollRect.size.width, LATER);
        
        scale = displayRect.size.width / imageSourceSize.width;
        transformSize = displayRect.size;

        maxThumbRows = [self thumbsForWidth:SCREEN.size.height];
        maxThumbCols = [self thumbsForHeight:SCREEN.size.height];

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
    
    CGFloat displayArea = displayRect.size.width * displayRect.size.height;
    CGFloat containerArea = SCREEN.size.width * SCREEN.size.height;
    displayFrac = displayArea / containerArea;
    if (displayFrac < mainVC.minDisplayFrac) {
        score = 0;
        return;
    }

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
    float pctThumbsShown = thumbsOnScreen / mainVC.thumbViewsArray.count;
    if (displayOption != OnlyTransformDisplayed && pctThumbsShown < mainVC.minPctThumbsShown)
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
    NSLog(@"//////// %3.1f = %3.1f * %3.1f * %3.1f",
          score, thumbScore, scaleScore, displayScore);
}

- (CGFloat) executeHForRowCount:(size_t)rows {
    return ((rows)*EXECUTE_ROW_H + 2*EXECUTE_BORDER_W + 2*SEP);
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

#ifdef NOTDEF
// Figure out a reasonable layout for a particular incoming size.
// return NO if it can't be done. if NO, then the score is not computed.

// no display, just exec (maybe narrow) and thumbs.  Exec starts in upper left hand
// corner, and may stretch out to the width of the screen.  Thumbs are placed possibly
// to the right of the exec, and then an array underneath, filling the screen.

- (void) tryLayoutsForThumbsAndExecOnly:(BOOL) narrowExec {
    type = @"ET";
    displayRect = CGRectZero;
    executeRect = CGRectMake(0, 0,
                             narrowExec ? mainVC.minExecWidth : mainVC.minExecWidth,
                             narrowExec ? EXECUTE_MIN_H : EXECUTE_FULL_H);
    CGFloat widthRightOfExec = CONTAINER_FRAME.size.width - executeRect.size.width;
    int thumbsRightOfExec = widthRightOfExec/THUMB_W;
    executeRect.size.width = CONTAINER_FRAME.size.width - thumbsRightOfExec*THUMB_W;
    [self positionThumbs:thumbsRightOfExec];
}
#endif

#ifdef NOTDEF
- (void) tryLayoutsOnRight:(BOOL) narrowExec {
    displayRect.origin = CGPointZero;
    CGSize minDisplaySize;
    if (displayOption == ThumbsOnly) {
        minDisplaySize = CGSizeZero;
        displayRect.size = CGSizeZero;
    } else {
        minDisplaySize = CGSizeMake(mainVC.minDisplayWidth, mainVC.containerView.frame.size.height -
                                    PARAM_VIEW_H);
        displayRect.size = [Layout fitSize:imageSourceSize toSize:minDisplaySize];
    }
    scale = displayRect.size.width / imageSourceSize.width;
    CGSize basicExecuteSize = CGSizeMake(narrowExec ? mainVC.minExecWidth : mainVC.minExecWidth,
                                         narrowExec ? EXECUTE_MIN_H : EXECUTE_FULL_H);
    CGFloat maxWidthRightOfExec = CONTAINER_FRAME.size.width - displayRect.size.width - basicExecuteSize.width;
    int maxThumbsRightOfExec = maxWidthRightOfExec/(THUMB_W + SEP);

#ifdef DEBUG_LAYOUT
    NSLog(@"tryLayouts of %4.0f x %4.0f to %4.0f x %4.0f  scale %5.3f",
          imageSourceSize.width, imageSourceSize.height,
          displayRect.size.width, displayRect.size.height,
          scale);
#endif
    
    for (int nThumbs=maxThumbsRightOfExec; nThumbs >= 0; nThumbs--) {
        executeRect.size = basicExecuteSize;
        CGFloat thumbsWidth = nThumbs*THUMB_W;
        CGSize s = CGSizeMake(CONTAINER_FRAME.size.width - executeRect.size.width - thumbsWidth,
                              CONTAINER_FRAME.size.height - PARAM_VIEW_H);
        displayRect.size = [Layout fitSize:imageSourceSize toSize:s];
        scale = displayRect.size.width / imageSourceSize.width;
        paramRect = CGRectMake(displayRect.origin.x, BELOW(displayRect),
                               displayRect.size.width, PARAM_VIEW_H);
        executeRect.origin.x = RIGHT(displayRect);
        executeRect.size.width = (CONTAINER_FRAME.size.width -
                                  displayRect.size.width - thumbsWidth);
        firstThumbRect.origin = CGPointMake(RIGHT(executeRect), executeRect.origin.y);
#ifdef DEBUG_LAYOUT
        NSLog(@"   display %4.0f x %4.0f   for %d thumbs",
              displayRect.size.width, displayRect.size.height, nThumbs);
        NSLog(@"   param   %4.0f x %4.0f         at %4.0f,%4.0f",
              paramRect.size.width, paramRect.size.height,
              paramRect.origin.x, paramRect.origin.y);
        NSLog(@"    exec   %4.0f x %4.0f         at %4.0f,%4.0f",
              executeRect.size.width, executeRect.size.height,
              executeRect.origin.x, executeRect.origin.y);
        NSLog(@"   first   %4.0f x %4.0f         at %4.0f,%4.0f",
              firstThumbRect.size.width, firstThumbRect.size.height,
              firstThumbRect.origin.x, firstThumbRect.origin.y);
#endif
        [self positionThumbs:nThumbs];
    }
}

// with the given exec and display width, layout the thumbs down the right,
// first to the right of exec, if room, them to the right of the display,
// if room, then using the whole screen width for the rest.
- (void) positionThumbs:(size_t) thumbsRightOfExec {
    size_t thumbsPerRow = 0;   // undetermined at the moment
    CGRect r;
    
    if (thumbsRightOfExec) {
        thumbsPerRow = thumbsRightOfExec;
        type = displayRect.size.width == 0 ? @"ET" : @"DET";
        
        firstThumbRect.origin = CGPointMake(RIGHT(executeRect) + SEP, 0);
#ifdef OLD
        size_t thumbIndex = 0;
        r = firstThumbRect;
        do {
            for (int i=0; i<thumbsPerRow; i++) {
                thumbPositionArray[thumbIndex++] = [NSValue valueWithCGRect:r];
                if (thumbIndex == mainVC.thumbViewsArray.count) {
                    [self addLayout];
                    return; // finished
                }
                r.origin.x += firstThumbRect.size.width + SEP;
            }
            r.origin = CGPointMake(RIGHT(executeRect), r.origin.y + firstThumbRect.size.height);
        } while (r.origin.y < BELOW(executeRect));
#endif
    }
    
    // Here the first thumb is below the executeRect.  Start on the right of the displayRect
    CGFloat thumbSpaceRightOfDisplay = (CONTAINER_FRAME.size.width - RIGHT(displayRect) - SEP) ;
    int thumbsRightOfDisplay = thumbSpaceRightOfDisplay / (firstThumbRect.size.width + SEP);
    if (thumbsRightOfDisplay > 0) {
        type = displayRect.size.width == 0 ? @"T" : @"DT";
        if (!thumbsPerRow) {
            thumbsPerRow = thumbsRightOfDisplay;
            firstThumbRect.origin = CGPointMake(RIGHT(displayRect), 0);
            r = firstThumbRect;
        }
#ifdef OLD
        r.origin.x = RIGHT(displayRect) + SEP;
        do {
            for (int i=0; i<thumbsPerRow; i++) {
                thumbPositionArray[thumbIndex++] = [NSValue valueWithCGRect:r];
                [self addLayout];
                if (thumbIndex == mainVC.thumbViewsArray.count) {
                    return; // finished
                }
                r.origin.x += firstThumbRect.size.width + SEP;
//                NSLog(@" %.1f %.1f", RIGHT(r), CONTAINER_FRAME.size.width);
//                assert(RIGHT(r) <= CONTAINER_FRAME.size.width);
            }
            r.origin = CGPointMake(RIGHT(displayRect), r.origin.y + firstThumbRect.size.height);
        } while (r.origin.y < BELOW(displayRect));
#endif
    }
    
#ifdef OLD
    // finally we have the whole width of the screen for thumbs
    int fullThumbRowCount = CONTAINER_FRAME.size.width / firstThumbRect.size.width;
    assert(fullThumbRowCount);
    if (!thumbsPerRow) {    // first layout.  Really?!
        thumbsPerRow = fullThumbRowCount;
        firstThumbRect.origin = CGPointMake(0, 0);
        r = firstThumbRect;
    } else
        assert(r.origin.y > 0); // already laid out above
    r.origin.x = 0;
    for (int i=0; i<thumbsPerRow; i++) {
        thumbPositionArray[thumbIndex++] = [NSValue valueWithCGRect:r];
        if (thumbIndex == mainVC.thumbViewsArray.count) {
            break;
        }
        r.origin.x += firstThumbRect.size.width;
        assert(RIGHT(r) < CONTAINER_FRAME.size.width);
    }
#endif
    r.origin = CGPointMake(RIGHT(displayRect), r.origin.y + firstThumbRect.size.height);
        type = @"D/T";
    [self addLayout];
}
#endif

#ifdef MAYBENOT
// execute is to the right of the display, with thumbs going below it, and
// possibly below the display itself.

- (void) tryLayoutsForExecOnTopRight:(BOOL) narrowExec {
    executeRect = CGRectZero;
    executeRect.size.width = minExecWidth;
    executeRect.size.height = EXECUTE_FULL_H;
    [self placeThumbsRightOfExec];
    [self theRestIsThumbsStartingBelowExec:!roomForThumbsToTheRightOfExec];

    BOOL maxRoomForThumbsToTheRightOfDisplay = CONTAINER_FRAME.size.width - RIGHT(executeRect);
    int thumbsToTheRightOfExec = maxRoomForThumbsToTheRightOfDisplay / THUMB_W;
    do {
        CGSize s = CGSizeMake(CONTAINER_FRAME.size.width - executeRect.size.width,
                              CONTAINER_FRAME.size.height);
        displayRect.size = [Layout fitSize:imageSourceSize toSize:s];
        // insert thumbs, emit, decrease thumbs by one row/column, fit, emit, etc.
        [self scoreAndAddLayout];
    }
}
#endif

#ifdef OLD
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

    CGFloat columnWidthNeeded = [self widthForColumns:columnsWanted];
    CGFloat rowHeightNeeded = [self heightForRows:rowsWanted];
    
    displayRect.size.width = CONTAINER_FRAME.size.width - rightThumbWidthNeeded;
    displayRect.size.height = CONTAINER_FRAME.size.height - EXECUTE_MIN_H - bottomThumbHeightNeeded;

    displayRect.size = CONTAINER_FRAME.size;
    
    if (mainVC.isiPhone) {
        switch (thumbsPosition) {
            case Bottom:    // check display height limits
                if (mainVC.isPortrait) {    // exec and thumbs on the bottom
                    displayRect.size.height -= EXECUTE_MIN_H + bottomThumbHeightNeeded;
                } else
                    return NO;  // no thumbs on landscape iphone bottom
                } else {    // exec under, thumbs to the right
                        displayRect.size.height -= EXECUTE_MIN_H;
                        displayRect.size.width -= rightThumbWidthNeeded;
                    }
                } else {    // iPad
                    
                }
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
    } else {    // iPad
        switch (thumbsPosition) {
            case Bottom:    // check display height limits
                if (mainVC.isPortrait) {    // exec and thumbs on the bottom
                    displayRect.size.height -= EXECUTE_MIN_H + bottomThumbHeightNeeded;
                } else
                    return NO;
                } else {    // exec under, thumbs to the right
                        displayRect.size.height -= EXECUTE_MIN_H;
                        displayRect.size.width -= rightThumbWidthNeeded;
                    }
                } else {    // iPad
                    
                }
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
    }

    scale = SCALE_UNINITIALIZED;
    displayRect.size = [Layout fitSize:imageSourceSize toSize:displayRect.size];
    displayRect.origin = CGPointZero;   // needs centering
    
if (displayRect.size.height <= 0 || displayRect.size.width <= 0)
if (displayOption != ThumbsOnly)
return NO;
if (displayRect.size.height <= minDisplayHeight ||
    displayRect.size.width <= minDisplayWidth)
return NO;  // display just too tiny

thumbArrayRect = CGRectZero;
int thumbsShown;

    switch (thumbsPosition) {
        case Bottom:    // check display height limits
            break;
        case Right:     // check display width limits
            break;
        default:
            break;
    }

    executeRect.size.width = displayRect.size.width - 1;
        executeRect.origin.x = displayRect.origin.x;
        CGFloat spaceBelowDisplay = CONTAINER_FRAME.size.height -
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
    

    return YES;
}

#ifdef OLD
- (int) placeThumbsOnRight {
    thumbArrayRect = CGRectMake(RIGHT(displayRect)+SEP, displayRect.origin.y, LATER,
                                CONTAINER_FRAME.size.height);
    thumbArrayRect.size.width = CONTAINER_FRAME.size.width - thumbArrayRect.origin.x;
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
#endif
#endif

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

#ifdef NOTDEF
- (NSString *) info {
    int thumbsShown = thumbsInRow * thumbsInCol;
    
    return [NSString stringWithFormat:@"%4.0f x%4.0f   %@  %6.2f  %2dx%2d=%3d",
          displayRect.size.width, displayRect.size.height,
          displayOptionNames[displayOption],
            score,
            thumbsInRow, thumbsInCol, thumbsShown];
    return @"<layout info>";
}
#endif

- (NSString *) layoutSum {
    return [NSString stringWithFormat:@"%4.0fx%4.0f  %4.0fx%4.0f   %5.3f%%  e%3.0fx%3.0f p%3.0fx%3.0f %4.2f score:%4.2f %@",
            transformSize.width, transformSize.height,
            displayRect.size.width, displayRect.size.height,
            scale,
            executeRect.size.width, executeRect.size.height,
            paramRect.size.width, paramRect.size.height,
            displayFrac,
            score, type
    ];
}

- (void) dump {
    NSLog(@"layout dump:  type %@  score %.1f  scale %.2f", type, score, scale);
    NSLog(@"screen format %@", format ? format : @"fixed image");
    if (format && depthFormat)
        NSLog(@"depth format %@", depthFormat);
    
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

#ifdef OLD
- (id)copyWithZone:(NSZone *)zone {
    Layout *copy = [[Layout alloc] initWithOption:displayOption
                                           sourceSize:imageSourceSize
                                               format:format];
    copy.depthFormat = self.depthFormat;
    copy.scale = self.scale;
    copy.aspectRatio = self.aspectRatio;
    copy.score = self.score;
    copy.type = self.type;
    copy.executeIsTight = self.executeIsTight;
    copy.transformSize = self.transformSize;
    copy.displayRect = self.displayRect;
    copy.displayFrac = self.displayFrac;
    copy.firstThumbRect = self.firstThumbRect;
    copy.plusRect = self.plusRect;
    copy.firstThumbRect = self.firstThumbRect;
    copy.thumbImageRect = self.thumbImageRect;
    copy.executeRect = self.executeRect;
    copy.paramRect = self.paramRect;
    copy.executeOverlayOK = executeOverlayOK;
    copy.status = self.status;
//    copy.maxThumbRows = self.maxThumbRows;
//    copy.maxThumbColumns = self.maxThumbColumns;
    copy.minExecWidth = self.minExecWidth;
    return copy;
}
#endif

@end

#ifdef NOTYET
    // A bit of a penalty needed for fewer thumbs displayed, about 1 point per
    // four missing.
//    float thumbFracMissing = (float)thumbsShown/(float)mainVC.thumbViewsArray.count;
    if (thumbScore) {
        long thumbsMissing = mainVC.thumbViewsArray.count - thumbsShown;
        if (thumbsMissing > 0)
            thumbScore -= (thumbsMissing/2.0)/100.0;
    }
    
    float displayArea = displayRect.size.width * displayRect.size.height;
    float containerArea = CONTAINER_FRAME.size.width * CONTAINER_FRAME.size.height;
    
#define MIN_TIGHT_DISPLAY_FRAC  0.2
#define MIN_BEST_DISPLAY_FRAC  0.3

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
    
    
    float widthFrac = displayRect.size.width / CONTAINER_FRAME.size.width;
    float heightFrac = displayRect.size.height / CONTAINER_FRAME.size.height;
    if (widthFrac < 0.25) {
        score = displayScore = 0;
        return NO;
    } else {
        if (widthFrac >= 0.55 && heightFrac >= 0.58)    // good enough
            displayScore = 1.0;
        else
            displayScore = MAX(widthFrac, heightFrac);
    }
    
    
#ifdef LONG
    status = [NSString stringWithFormat:@"%4.0f %4.0f@%4.2f%%\t%@%@ %4.2f=f(%4.2f %4.2f %4.2f) T%2.0f",
              displayRect.size.width, displayRect.size.height, scale,
              displayOptionNames[displayOption], displayThumbsPosition[thumbsPosition],
              score, thumbScore, displayScore, scaleScore,
              round(thumbFrac*100.0)
              ];
#endif
    // the use of trunc here is to make 100% -> 99%, saving space in the tight display
    int displayWPct = trunc(100.0*(displayRect.size.width/CONTAINER_FRAME.size.width) - 0.1);
    int displayHPct = trunc(100.0*(displayRect.size.height/CONTAINER_FRAME.size.height) - 0.1);
    
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
    assert(BELOW(thumbArrayRect) <= CONTAINER_FRAME.size.height);
    assert(RIGHT(thumbArrayRect) <= CONTAINER_FRAME.size.width);
    assert(BELOW(executeRect) < CONTAINER_FRAME.size.height);
    assert(RIGHT(executeRect) < CONTAINER_FRAME.size.width);
#endif
