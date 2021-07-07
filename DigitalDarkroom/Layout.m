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

#define THUMB_ROWS_FOR_HEIGHT(h)  (int)((h+SEP) / (firstThumbRect.size.height + SEP))
#define THUMB_COLS_FOR_WIDTH(w)  (int)((w) / firstThumbRect.size.width)

- (void) configureLayoutWithDisplayOption:(DisplayOptions) displayOption {
    quality = 0;    // assume doable
    aspectRatio = captureSize.width / captureSize.height;
 //   float containerAspect = containerFrame.size.width/containerFrame.size.height;
#ifdef DEBUG_LAYOUT
    NSLog(@"configureLayoutWithDisplayOption %d", displayOption);
    NSLog(@"     container: %.0f,%.0f  %.0fx%.0f (%4.2f)",
          containerFrame.origin.x, containerFrame.origin.y,
          containerFrame.size.width, containerFrame.size.height,
          containerFrame.size.width/containerFrame.size.height);
    NSLog(@"        source: %.0fx%.0f (%4.2f)",
          captureSize.width, captureSize.height,
          aspectRatio);
#endif
    
    thumbArrayRect = CGRectZero;
    
    firstThumbRect = thumbImageRect = CGRectZero;
    thumbImageRect.size.width = isiPhone ||
        displayOption == TightDisplay ? TIGHT_THUMB_W : THUMB_W;
    thumbImageRect.size.height = round(thumbImageRect.size.width / aspectRatio);
    
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += THUMB_LABEL_H;
    thumbsPlacement = ThumbsUndecided;
#ifdef DEBUG_THUMB_PLACEMENT
            NSLog(@"-1 thumbsPlacement -> Undecided");
#endif

    // figure out the best displayrect, given displayoption type, etc.
    float scale;
    displayRect.origin = CGPointZero;
    
    switch (displayOption) {
        case FullScreenDisplay: {
            displayRect.size = [Layout fitSize:captureSize toSize:containerFrame.size];
            displayRect.origin = CGPointZero;   // needs centering
            [self placeExecuteRectWithSqueeze:YES];
            break;
        }
        case TightDisplay:
        case BestDisplay:
            if (RIGHT(containerFrame) < 500) {   // iPhone, portrait
                thumbsPlacement = ThumbsUnderneath;
                executeIsTight = YES;
                displayRect.size = [Layout fitSize:captureSize
                                            toSize: CGSizeMake(containerFrame.size.width,
                                               round(containerFrame.size.height -
                                                     (2.5*firstThumbRect.size.height + EXECUTE_MIN_H)))];
                [self placeExecuteRectWithSqueeze:YES];
                [self placeThumbsUnderneath];
            } else {
                thumbsPlacement = ThumbsOnRight;
                // maybe enough room to put ALL the thumbs on the right.  See if there is, and
                // create display accordingly.
                long thumbsPerCol = THUMB_ROWS_FOR_HEIGHT(containerFrame.size.height);
                long colsNeeded = (thumbCount + (thumbsPerCol - 1)) / thumbsPerCol;
                CGFloat widthNeeded = colsNeeded * (firstThumbRect.size.width + SEP); //for full thumb display
                thumbArrayRect.size = CGSizeMake(widthNeeded, thumbsPerCol * (firstThumbRect.size.height + SEP));
                assert(thumbArrayRect.size.height <= containerFrame.size.height);
                if (containerFrame.size.width - widthNeeded < 400)  // min display width here
                    thumbArrayRect.size = CGSizeMake(containerFrame.size.width*LAYOUT_BEST_DISPLAY_AREA_FRAC, thumbsPerCol * firstThumbRect.size.height);

                displayRect.size = [Layout fitSize:captureSize toSize:
                                    CGSizeMake(containerFrame.size.width - thumbArrayRect.size.width,
                                               containerFrame.size.height - EXECUTE_MIN_H)];
                [self placeExecuteRectWithSqueeze:NO];
                thumbArrayRect.origin = CGPointMake(RIGHT(displayRect), displayRect.origin.y);
            }
            break;
        case NoDisplay:
            displayRect = CGRectZero;
            // just image plus (overlaid) execute, no thumbs unless there is spare room?????
    }
    transformSize = displayRect.size;

    float captureArea = captureSize.width * captureSize.height;
    float displayArea = displayRect.size.width * displayRect.size.height;
    int thumbRows = THUMB_ROWS_FOR_HEIGHT(thumbArrayRect.size.height);
    int thumbCols = THUMB_COLS_FOR_WIDTH(thumbArrayRect.size.width);
    int thumbsDisplayed = thumbCols * thumbRows;
//    float thumbFrac = thumbsDisplayed/thumbCount;
    [self showThumbArraySize:thumbArrayRect.size];

    float captureScoreFrac;
    if (captureArea <= displayArea)
        captureScoreFrac = captureArea / displayArea;
    else
        captureScoreFrac = 1.0; //scale;
    
    float containerArea = containerFrame.size.width * containerFrame.size.height;
    displayFrac = displayArea / containerArea;
    
//    status = [NSString stringWithFormat:@"%3d (%.2f)", quality, captureScoreFrac];

    // displayRect has the display size, and it fits in containerRect somewhere.
    // Figure out this: thumbs on right, or thumbs underneath?  this is the
    // hardest part of the layout

#ifdef DEBUG_LAYOUT
    NSLog(@"LLLL: %4.0f x %4.0f @ %.1f (%4.2f)  q:%3d  %@ ",
          captureSize.width, captureSize.height, scale, aspectRatio,
          quality, status);
#endif
    assert(BELOW(thumbArrayRect) <= containerFrame.size.height);
    assert(RIGHT(thumbArrayRect) <= containerFrame.size.width);
    assert(BELOW(executeRect) <= containerFrame.size.height);
    assert(RIGHT(executeRect) <= containerFrame.size.width);
    
    return;
}

- (void) placeThumbsOnRight {
#ifdef OLD
    if (currentDisplayOption != FullScreenDisplay && rightCols < minThumbCols) {
        quality = 0;
        status = [status stringByAppendingString:
                  [NSString stringWithFormat:@" = TRR"]];
        return;
    }
#endif
}

- (void) showThumbArraySize:(CGSize) s {
    int thumbRows = THUMB_ROWS_FOR_HEIGHT(s.height);
    int thumbCols = THUMB_COLS_FOR_WIDTH(s.width);
    NSLog(@"********* Thumb array size for %.1f x %.1f: %d x %d = %d",
          s.width, s.height, thumbCols, thumbRows, thumbRows*thumbCols);
}

- (void) placeThumbsUnderneath {    // under exec, which is already placed
    CGFloat thumbsTop = BELOW(executeRect);
    thumbArrayRect = CGRectMake(0, thumbsTop, containerFrame.size.width, containerFrame.size.height - thumbsTop);
}

- (void) placeExecuteRectWithSqueeze:(BOOL) squeeze {
    executeRect.size.width = displayRect.size.width;
    executeRect.origin.x = displayRect.origin.x;
    CGFloat spaceBelowDisplay = containerFrame.size.height - BELOW(displayRect);
    if (squeeze || spaceBelowDisplay < EXECUTE_FULL_H) {
        NSLog(@"full: %.0d  space: %.1f", EXECUTE_FULL_H, spaceBelowDisplay);
        executeRect.origin.y = BELOW(displayRect);
        executeRect.size.height = spaceBelowDisplay;
        executeIsTight = YES;
        executeOverlayOK = YES;
        assert(executeRect.size.height > 0);
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
    CGFloat scale = [self scaleToFitSize:srcSize toSize:size];
    CGSize scaledSize;
    scaledSize.width = round(scale*srcSize.width);
    scaledSize.height = round(scale*srcSize.height);
    return scaledSize;
}

@end
