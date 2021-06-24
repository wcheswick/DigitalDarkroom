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
    [self configureLayoutForDisplaySize:ds];
    return self;
}

- (void) configureLayoutForDisplaySize:(CGSize) ds {
#ifdef DEBUG_LAYOUT
    NSLog(@"configureLayoutForDisplaySize %.0f x %.0f (%4.2f)", ds.width, ds.height, ds.width/ds.height);
#endif

    float bestDisplayAreaPct;
    displayRect.size = ds;
    quality = 0;    // assume doable
    
    aspectRatio = captureSize.width / captureSize.height;
    
    if (aspectRatio < 1.0)
        scale = displayRect.size.height / captureSize.height;
    else
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
    
    transformSize = scaledSize;
    if (currentDisplayOption == NoDisplay)
        transformSize.width = captureSize.width;        // width on an empty screen...needs thought XXX
    float containerArea = containerFrame.size.width * containerFrame.size.height;
    
//    float transformArea = transformSize.width * transformSize.height;
//    displayRect.origin = CGPointZero;
//    displayRect.size = transformSize;
    displayFrac = displayArea / containerArea;
    
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
    
    // displayRect has the display size, and it fits in containerRect somewhere.
    // Figure out this: thumbs on right, or thumbs underneath?  this is the
    // hardest part of the layout

    thumbArrayRect = CGRectZero;
    int minThumbCols = MIN_THUMB_COLS;
    int minThumbRows = MIN_THUMB_ROWS;
    
    firstThumbRect = thumbImageRect = CGRectZero;
    
    thumbImageRect.origin = CGPointZero;
    thumbImageRect.size.width = isiPhone ||
        currentDisplayOption == TightDisplay ? TIGHT_THUMB_W : THUMB_W;
    thumbImageRect.size.height = thumbImageRect.size.width / aspectRatio;
    
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += THUMB_LABEL_H;
    thumbsPlacement = ThumbsUndecided;
#ifdef DEBUG_THUMB_PLACEMENT
            NSLog(@"-1 thumbsPlacement -> Undecided");
#endif

    // set up targets sizes and rules for the various display options
    switch (currentDisplayOption) {
        case NoDisplay:
            bestDisplayAreaPct = 0.0;
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsUnderneath;
#ifdef DEBUG_THUMB_PLACEMENT
            NSLog(@"0 thumbsPlacement -> Underneath");
#endif
            executeOverlayOK = NO;
            break;
        case TightDisplay:
            bestDisplayAreaPct = 20.0;  // should depend on device and orientation
            if (isiPhone) {
                if (isPortrait) {
                    thumbsPlacement = ThumbsUnderneath;
#ifdef DEBUG_THUMB_PLACEMENT
                    NSLog(@"1 thumbsPlacement -> Underneath");
#endif
                } else {
                    thumbsPlacement = ThumbsOnRight;
#ifdef DEBUG_THUMB_PLACEMENT
                    NSLog(@"1 thumbsPlacement -> Right");
#endif
                }
            } else {
                thumbsPlacement = ThumbsUndecided;
#ifdef DEBUG_THUMB_PLACEMENT
                    NSLog(@"1 thumbsPlacement -> Undecided");
#endif
            }
            break;
        case BestDisplay:
            bestDisplayAreaPct = 50.0;  // should depend on device and orientation
            thumbsPlacement = ThumbsUndecided;
#ifdef DEBUG_THUMB_PLACEMENT
                    NSLog(@"2 thumbsPlacement -> Unknown");
#endif
            break;
        case FullScreenDisplay:
            minThumbCols = 0;
            minThumbRows = 0;
            bestDisplayAreaPct = 100.0;
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsOptional;
#ifdef DEBUG_THUMB_PLACEMENT
                    NSLog(@"3 thumbsPlacement -> Optional");
#endif
            break;
    }

    CGSize possibleRightSize = CGSizeMake(containerFrame.size.width - displayRect.size.width, containerFrame.size.height);
    int rightRows = [self thumbsPerColIn:possibleRightSize];
    int rightCols = [self thumbsPerRowIn:possibleRightSize];
    int rightW = (firstThumbRect.size.width + SEP)*rightCols;   // for centering

    CGSize possibleBottomSize = CGSizeMake(containerFrame.size.width, containerFrame.size.height - BELOW(displayRect));
    int bottomRows = [self thumbsPerColIn:possibleBottomSize];
    int bottomCols = [self thumbsPerRowIn:possibleBottomSize];
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
#ifdef DEBUG_THUMB_PLACEMENT
            NSLog(@"4 %3d %4.1f  %3d %4.1f  ->%@",
                  rightThumbCount, rightThumbFrac,
                  bottomThumbCount, bottomThumbFrac,
                  thumbsPlacement == ThumbsOnRight ? @"Right" : @"Underneath");
#endif
            break;
        default:
            ;
    }

    // layout stuff based on thumb position.  Display...
    switch (thumbsPlacement) {
        case ThumbsOnRight:
#ifdef DEBUG_THUMB_PLACEMENT
            NSLog(@"placing thumbs on right");
#endif
            displayRect.origin.x = 0;
            
            thumbArrayRect = CGRectMake(RIGHT(displayRect)+SEP, displayRect.origin.y,
                                             rightW, containerFrame.size.height);
            thumbFrac = rightThumbFrac;
            if (currentDisplayOption != FullScreenDisplay && rightCols < minThumbCols) {
                quality = LAYOUT_BAD_TOO_LARGE;
                status = [status stringByAppendingString:
                          [NSString stringWithFormat:@" = TRR"]];
                return;
            }
            // with thumbs on the right, the execute can go to the bottom of the container
            executeRect.origin.y = BELOW(displayRect) + SEP;
            executeRect.size.height = containerFrame.size.height - executeRect.origin.y - SEP;
            assert(executeRect.size.height > 0);
            executeRect.origin.x = displayRect.origin.x;
            executeRect.size.width = displayRect.size.width;
            break;
        case ThumbsUnderneath:
#ifdef DEBUG_THUMB_PLACEMENT
            NSLog(@"placing thumbs underneath");
#endif
            // Always have at least one line of the executeRect below the transform to make the current
            // transform name (maybe plus others) visible
            
            executeRect.size.width = containerFrame.size.width;
            executeRect.size.height = EXECUTE_H_FOR(1);
            executeRect.origin = CGPointMake(0, BELOW(displayRect) + SEP);
            CGFloat availableHeight = containerFrame.size.height - BELOW(displayRect);
            if (availableHeight < EXECUTE_FULL_H) {
                if (availableHeight > EXECUTE_MIN_H)
                    executeRect.size.height = availableHeight;
                else {
                    executeRect.size.height = EXECUTE_MIN_H;
                    executeRect.origin.y = containerFrame.size.height - executeRect.size.height;
                }
            }

            displayRect.origin.x = (containerFrame.size.width - displayRect.size.width)/2.0;
            CGRect f = CGRectMake(LATER, LATER, bottomW, LATER);
            f.size.height = containerFrame.size.height - BELOW(executeRect) - SEP;
            f.origin.y = containerFrame.size.height - f.size.height;
            f.origin.x = (containerFrame.size.width - f.size.width)/2.0;
            thumbArrayRect = f;
            
            thumbFrac = bottomThumbFrac;
            if (currentDisplayOption != FullScreenDisplay && bottomRows < minThumbRows) {
                quality = LAYOUT_BAD_TOO_LARGE;
                status = [status stringByAppendingString:
                          [NSString stringWithFormat:@" = TBR"]];
                return;
            }
           break;
        default:
            NSLog(@"no thumb placement");
            thumbArrayRect = CGRectZero;
    }

#ifdef NOTDEF
    executeRect.size.height = executeRectBottom - BELOW(displayRect) - SEP;
    executeOverlayOK = executeRect.size.height < EXECUTE_MIN_H;
    executeIsTight = executeOverlayOK;
    if (executeOverlayOK) {
        executeRect.size.height = EXECUTE_MIN_H;
    }
    executeRect.origin.y = executeRectBottom - executeRect.size.height;
    
#endif

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
    NSLog(@"LLLL: %4.0f x %4.0f @ %.1f (%4.2f)  q:%3d  %@ ",
          captureSize.width, captureSize.height, scale, aspectRatio,
          quality, status);
#endif
    return;
}


// c.f nextButtonPosition and buttonsContinueOnNextRow in MainVC.m
- (int) thumbsPerColIn:(CGSize) area {
    return (area.height - SEP) / (firstThumbRect.size.height + SEP);
}

- (int) thumbsPerRowIn:(CGSize) area {
    return (area.width - SEP) / (firstThumbRect.size.width + SEP);
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

@end
