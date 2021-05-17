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


NSString * __nullable displayOptionNames[] = {
    @"ControlDisplayOnly",
    @"TightDisplay",
    @"BestDisplay",
    @"LargestImageDisplay",
    @"FullScreenImage",
};

@implementation Layout

@synthesize format;
@synthesize minDisplayFrac, bestMinDisplayFrac;
@synthesize minThumbFrac, bestMinThumbFrac;
@synthesize minThumbRows, minThumbCols;
@synthesize isPortrait, isiPhone;
@synthesize containerFrame;
@synthesize targetDisplaySize;
@synthesize currentDisplayOption;
@synthesize captureSize;
@synthesize transformSize, displayRect;
@synthesize displayFrac, thumbFrac;
@synthesize thumbsPlacement;
@synthesize thumbArrayRect;
@synthesize executeRect, executeOverlayOK, executeIsTight;
@synthesize executeRectBottom;
@synthesize firstThumbRect, thumbImageRect;

@synthesize thumbCount;
@synthesize scale, aspectRatio;
@synthesize status, quality;

- (id)initForOrientation:(BOOL) port
                  iPhone:(BOOL) isPhone
           containerRect:(CGRect) containerRect {
    self = [super init];
    if (self) {
        isPortrait = port;
        isiPhone = isPhone;
        scale = 0.0;
        quality = LAYOUT_NO_GOOD;
        thumbCount = 1000;  // rediculous number
        thumbArrayRect = CGRectZero;
        displayRect = CGRectZero;
        transformSize = CGSizeZero;
        executeRect = CGRectZero;
        status = nil;
        containerFrame = containerRect;    // filled in by caller
        
        // these values are tweaked to satisfy the all the cameras on two
        // different iPhones and two different iPads.
        
        if (isiPhone) {
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

// Can we make an acceptible layout with the given capture size and scaling?
// return no if layout is bad. we return self for readability.

- (Layout *) layoutForSourceSize:(CGSize) cs
                   displaySize:(CGSize) ds
                   displayOption:(DisplayOptions) displayOption {
    captureSize = cs;
    currentDisplayOption = displayOption;
    [self adjustForDisplaySize:ds];
    return self;
}

- (void) adjustForDisplaySize:(CGSize) ds {
    displayRect.size = ds;
    quality = 0;    // assume doable
    
    aspectRatio = captureSize.width / captureSize.height;

    scale = displayRect.size.width / captureSize.width;
    CGSize scaledSize = CGSizeMake(round(displayRect.size.width*scale),
                                   round(displayRect.size.height*scale));

    float captureArea = captureSize.width * captureSize.height;
    float displayArea = displayRect.size.width * displayRect.size.height;

    float captureScoreFrac;
    if (captureArea <= displayArea)
        captureScoreFrac = captureArea / displayArea;
    else
        captureScoreFrac = 1.0; //scale;
    float captureScore = 100.0 * captureScoreFrac;
    
    quality = captureScore;
    status = [NSString stringWithFormat:@"%3d (%.2f)", quality, captureScoreFrac];

    thumbArrayRect = CGRectZero;
    int minThumbCols = MIN_THUMB_COLS;
    int minThumbRows = MIN_THUMB_ROWS;

    CGRect right = CGRectZero;
    CGRect bottom = CGRectZero;
    
    transformSize = scaledSize;
    if (currentDisplayOption == NoDisplay)
        transformSize.width = captureSize.width;        // width on an empty screen...needs thought XXX

    float containerArea = containerFrame.size.width * containerFrame.size.height;
    
//    float transformArea = transformSize.width * transformSize.height;
//    displayRect.origin = CGPointZero;
//    displayRect.size = transformSize;
    displayFrac = displayArea / containerArea;
    
    // Always have at least one line of the executeRect below the transform to make the current
    // transform name (maybe plus others) visible
    
    executeRect.size.width = displayRect.size.width;
    executeRect.size.height = EXECUTE_H_FOR(1);
    executeRect.origin.y = BELOW(displayRect) + SEP;
    CGFloat availableHeight = containerFrame.size.height - BELOW(displayRect);
    if (availableHeight < EXECUTE_FULL_H) {
        if (availableHeight > EXECUTE_MIN_H)
            executeRect.size.height = availableHeight;
        else {
            executeRect.size.height = EXECUTE_MIN_H;
            executeRect.origin.y = containerFrame.size.height - executeRect.size.height;
        }
    }
    
#ifdef OLD
    CGFloat roomUnderneath = containerFrame.size.height - BELOW(executeRect) - SEP;

    if (isiPhone || displayOption == TightDisplay) {
        executeRect.size.height = EXECUTE_MIN_H;
        executeRect.origin.y = BELOW(displayRect) - executeRect.size.height;
        executeOverlayOK = YES;
    } else {
        executeRect.origin.y = BELOW(displayRect) + SEP;
        if (roomUnderneath >= EXECUTE_FULL_H) {
            executeOverlayOK = NO;
            executeRect.size.height = EXECUTE_FULL_H;
        } else {
            // it may overlap if it gets too tall
            executeOverlayOK = NO;
        }
//        executeRect.size.height = roomUnderneath;
    }
#endif
    
    BOOL wfits = scaledSize.width <= containerFrame.size.width;
    BOOL hfits = BELOW(executeRect) <= containerFrame.size.height;
    BOOL fits = wfits && hfits;
    
    if (!fits) {
#ifdef NOTDEF
        if (s != 1.0)
            NSLog(@"reject, too big:  %4.0f x %4.0f @ %.2f", cs.width, cs.height, s);
#endif
        quality = LAYOUT_BAD_TOO_LARGE;
        status = [status stringByAppendingString:
                  [NSString stringWithFormat:@" = BAD Doesn't fit"]];
        return;
    }

    right.origin = CGPointMake(RIGHT(displayRect) + SEP, displayRect.origin.y);
    right.size = CGSizeMake(containerFrame.size.width - right.origin.x, containerFrame.size.height);
    bottom.origin = CGPointMake(0, BELOW(executeRect) + SEP);
    bottom.size = CGSizeMake(containerFrame.size.width, containerFrame.size.height - bottom.origin.y);

    CGSize bestDisplaySize;
    float bestDisplayAreaPct;
    
    firstThumbRect = thumbImageRect = CGRectZero;
    
    thumbImageRect.origin = CGPointZero;
    thumbImageRect.size.width = isiPhone ||
        currentDisplayOption == TightDisplay ? TIGHT_THUMB_W : THUMB_W;
    thumbImageRect.size.height = thumbImageRect.size.width / aspectRatio;
    
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += OLIVE_LABEL_H;
    
    // set up targets sizes and rules for the various display options
    switch (currentDisplayOption) {
        case NoDisplay:
            bestDisplayAreaPct = 0.0;
            // XXXX executeRect
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsOnRight;
            thumbArrayRect = CGRectZero;
            executeOverlayOK = NO;
            break;
        case TightDisplay:
            bestDisplayAreaPct = 20.0;  // should depend on device and orientation
            if (isiPhone) {
                if (isPortrait) {
                    thumbsPlacement = ThumbsUnderneath;
                } else {
                    thumbsPlacement = ThumbsOnRight;
                }
            } else {
                thumbsPlacement = ThumbsUndecided;
            }
            break;
        case BestDisplay:
            bestDisplayAreaPct = 50.0;  // should depend on device and orientation
            if (isiPhone)
                ;
            else
                thumbsPlacement = ThumbsUndecided;
            break;
        case FullScreenDisplay:
            minThumbCols = 0;
            minThumbRows = 0;
            bestDisplaySize = containerFrame.size;
            bestDisplayAreaPct = 100.0;
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsOptional;
            break;
            ; // XXXXX not yet
    }

    [self computeThumbsRect];
    int rightRows = [self thumbsPerColIn:right.size];
    int rightCols = [self thumbsPerRowIn:right.size];
    int rightW = (firstThumbRect.size.width + SEP)*rightCols;   // for centering

    int bottomRows = [self thumbsPerColIn:bottom.size];
    int bottomCols = [self thumbsPerRowIn:bottom.size];
    int bottomW = (firstThumbRect.size.width + SEP)*bottomCols;   // for centering
    
//    CGFloat rightArea = bottom.size.width * bottom.size.height;
//     CGFloat bottomArea = bottom.size.width * bottom.size.height;

    int rightThumbCount = rightRows * rightCols;
    int bottomThumbCount = bottomRows * bottomCols;

    float rightThumbFrac = (float)rightThumbCount/(float)thumbCount;
    float bottomThumbFrac = (float)bottomThumbCount/(float)thumbCount;

    switch (thumbsPlacement) {
        case ThumbsUnderAndRight:
        case ThumbsUndecided:
            thumbsPlacement = rightThumbFrac > bottomThumbFrac ? ThumbsOnRight : ThumbsUnderneath;
            break;
        default:
            ;
    }
    
    switch (thumbsPlacement) {
        case ThumbsOnRight:
            thumbArrayRect = right;
            thumbArrayRect.origin.x += (right.size.width - rightW)/2.0;
            thumbArrayRect.size.width = rightW;
            thumbFrac = rightThumbFrac;
            if (currentDisplayOption != FullScreenDisplay && rightCols < minThumbCols) {
                quality = LAYOUT_BAD_TOO_LARGE;
                status = [status stringByAppendingString:
                          [NSString stringWithFormat:@" = TRR"]];
                return;
            }
            // with thumbs on the right, the execute can go to the bottom of the container
            executeRect.size.height = containerFrame.size.height - executeRect.origin.y;
            break;
        case ThumbsUnderneath:
            thumbArrayRect = bottom;
            thumbArrayRect.origin.x += (bottom.size.width - bottomW)/2.0;
            thumbArrayRect.size.width = bottomW;
            thumbFrac = bottomThumbFrac;
            if (currentDisplayOption != FullScreenDisplay && bottomRows < minThumbRows) {
                quality = LAYOUT_BAD_TOO_LARGE;
                status = [status stringByAppendingString:
                          [NSString stringWithFormat:@" = TBR"]];
                return;
            }
            // with thumbs underneath, the execute can go to the right edge of the container
            executeRect.size.width = containerFrame.size.width;
             // and so can the thumbs
            thumbArrayRect.origin.x = (containerFrame.size.width - thumbArrayRect.size.width)/2.0;
           break;
        default:
            thumbArrayRect = CGRectZero;
    }
    
    [self positionDisplayRect];
    [self positionExecuteRect];

#ifdef notdef
    NSString *thumbStatus = [NSString stringWithFormat:@"%@%@",
              rightThumbsOK ? CHECKMARK : @".",
              bottomThumbsOK ? CHECKMARK : @"."];
#endif
    if (LAYOUT_IS_BAD(quality))
        return;
    
    if (thumbFrac >= minThumbFrac) {
        quality += 10;
        status = [status stringByAppendingString:
                  [NSString stringWithFormat:@" + 10 Tmf"]];
    }
    
    if (displayFrac >= bestMinDisplayFrac) {
        quality += 50;
        status = [status stringByAppendingString:
                  [NSString stringWithFormat:@" + 50 Dbf(%.2f)", displayFrac]];
    } else {
        if (displayFrac >= minDisplayFrac) {
            quality += 10;
            status = [status stringByAppendingString:
                      [NSString stringWithFormat:@" + 10 Dmf (%.2f)", displayFrac]];
        }
    }
//    assert(self.displayRect.size.width == self.executeRect.size.width);

#ifdef DEBUG_LAYOUT
    NSLog(@"LLLL: %4.0f x %4.0f @ %.1f  q:%3d  %@ ",
          captureSize.width, captureSize.height, scale,
          quality, status);
#endif
    return;
}

- (void) positionDisplayRect {
    switch (thumbsPlacement) {
        case ThumbsOnRight:
            displayRect.origin.x = 0;
            break;
        case ThumbsUnderneath:
            displayRect.origin.x = (containerFrame.size.width - displayRect.size.width)/2.0;
           break;
        default:
            thumbArrayRect = CGRectZero;
    }
}

- (void) computeThumbsRect {
    CGRect right;
    CGRect bottom;

    right.origin = CGPointMake(RIGHT(displayRect) + SEP, displayRect.origin.y);
    right.size = CGSizeMake(containerFrame.size.width - right.origin.x,
                            containerFrame.size.height);
    bottom.origin = CGPointMake(0, BELOW(executeRect) + SEP);
    bottom.size = CGSizeMake(containerFrame.size.width,
                             containerFrame.size.height - bottom.origin.y);

    int rightRows = [self thumbsPerColIn:right.size];
    int rightCols = [self thumbsPerRowIn:right.size];
    int rightW = (firstThumbRect.size.width + SEP)*rightCols;   // for centering

    int bottomRows = [self thumbsPerColIn:bottom.size];
    int bottomCols = [self thumbsPerRowIn:bottom.size];
    int bottomW = (firstThumbRect.size.width + SEP)*bottomCols;   // for centering
    
//    CGFloat rightArea = bottom.size.width * bottom.size.height;
//     CGFloat bottomArea = bottom.size.width * bottom.size.height;

    int rightThumbCount = rightRows * rightCols;
    int bottomThumbCount = bottomRows * bottomCols;
    
    float rightThumbFrac = (float)rightThumbCount/(float)thumbCount;
    float bottomThumbFrac = (float)bottomThumbCount/(float)thumbCount;
    
    thumbsPlacement = rightThumbFrac > bottomThumbFrac ? ThumbsOnRight : ThumbsUnderneath;
     
    switch (thumbsPlacement) {
        case ThumbsOnRight:
            thumbArrayRect = right;
            thumbArrayRect.origin.x += (right.size.width - rightW)/2.0;
            thumbArrayRect.size.width = rightW;
            thumbFrac = rightThumbFrac;
            break;
        case ThumbsUnderneath:
            thumbArrayRect = bottom;
            thumbArrayRect.origin.x += (bottom.size.width - bottomW)/2.0;
            thumbArrayRect.size.width = bottomW;
            thumbFrac = bottomThumbFrac;
            thumbArrayRect.origin.x = (containerFrame.size.width - thumbArrayRect.size.width)/2.0;
           break;
        default:
            thumbArrayRect = CGRectZero;
    }
}

- (void) positionExecuteRect {
    if (thumbsPlacement == ThumbsUnderneath) {
        executeRectBottom = thumbArrayRect.origin.y - SEP;
        executeRect.origin.x = SEP;
        executeRect.size.width = containerFrame.size.width - 2*SEP;
    } else {
        executeRectBottom = containerFrame.size.height - SEP;
        executeRect.origin.x = displayRect.origin.x;
        executeRect.size.width = displayRect.size.width;
    }
    executeRect.size.height = executeRectBottom - BELOW(displayRect) - SEP;
    executeOverlayOK = executeRect.size.height < EXECUTE_MIN_H;
    executeIsTight = executeOverlayOK;
    if (executeOverlayOK) {
        executeRect.size.height = EXECUTE_MIN_H;
    }
    executeRect.origin.y = executeRectBottom - executeRect.size.height;
}

- (float) aspectScaleToSize:(CGSize) targetSize {
    float hScale = targetSize.width / captureSize.width;
    float vScale = targetSize.height / captureSize.height;
    return MIN(hScale, vScale);
}

// c.f nextButtonPosition and buttonsContinueOnNextRow in MainVC.m

- (int) thumbsPerColIn:(CGSize) area {
    return (area.height - SEP) / (firstThumbRect.size.height + SEP);
}

- (int) thumbsPerRowIn:(CGSize) area {
    return (area.width - SEP) / (firstThumbRect.size.width + SEP);
}

// I realize that this may give the wrong result if one dimension
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

@end
