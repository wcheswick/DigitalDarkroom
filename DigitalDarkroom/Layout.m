//
//  Layout.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/2/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Layout.h"
#import "Defines.h"

typedef enum {
    ThumbsUndecided,
    ThumbsOptional,
    ThumbsUnderneath,
    ThumbsOnRight,
    ThumbsUnderAndRight,
    ThumbsOff,
} ThumbPlacement;

@interface Layout ()

@property (assign)  size_t thumbsUnderneath, thumbsOnRight;
@property (assign)  ThumbPlacement thumbsPlacement;

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
@synthesize isPortrait, isiPhone, displayOption;
@synthesize containerView;
@synthesize captureSize, transformSize;
@synthesize displayRect, thumbArrayRect;
@synthesize firstThumbRect, thumbImageRect;

@synthesize thumbsPlacement;
@synthesize thumbCount;
@synthesize scale, score, aspectRatio;
@synthesize status;

- (id)initForPortrait:(BOOL) port
               iPhone:(BOOL) isPhone
              displayOption:(DisplayOptions) dopt {
    self = [super init];
    if (self) {
        format = nil;
        isPortrait = port;
        isiPhone = isPhone;
        displayOption = dopt;
        scale = 1.0;
        score = 0;
        thumbCount = 1000;  // rediculous number
        displayRect = thumbArrayRect = CGRectZero;
        status = nil;
        containerView = nil;
    }
    return self;
}

- (int) layoutForFormat:(AVCaptureDeviceFormat *) f scaleOK:(BOOL) scaleOK {
    format = f;
//    NSLog(@" trying format %@", format);
    CMFormatDescriptionRef ref = format.formatDescription;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
    CGSize capSize = isPortrait ? CGSizeMake(dimensions.height, dimensions.width) :
                CGSizeMake(dimensions.width, dimensions.height);
#ifdef DEBUG_CAMERA_CAPTURE_SIZE
    NSLog(@"capture size  %4.0f  x %4.0f", capSize.width, capSize.height);
#endif
    return [self layoutForSize:capSize scaleOK:scaleOK];
}

- (int) layoutForSize:(CGSize) cs scaleOK:(BOOL) scaleOK {   // for captureSize
    captureSize = cs;
    aspectRatio = captureSize.width / captureSize.height;

    CGSize fullThumbSize = CGSizeMake(THUMB_W, OLIVE_LABEL_H + THUMB_W / aspectRatio);
    CGSize tightThumbSize = CGSizeMake(SMALL_THUMB_W, OLIVE_LABEL_H + SMALL_THUMB_W / aspectRatio);

    score = 0;
    
    float scaleScore = 0;
    
    firstThumbRect = thumbImageRect = CGRectZero;
    thumbArrayRect = CGRectZero;
    int minThumbCols = MIN_THUMB_COLS;
    int minThumbRows = MIN_THUMB_ROWS;
    
    firstThumbRect.size.width = THUMB_W;

    CGSize containerSize = containerView.frame.size;
    CGSize right, bottom;
    
    float capturePct = 0;
    
    BOOL wfits = captureSize.width <= containerSize.width;
    BOOL hfits = captureSize.height <= containerSize.height;
    BOOL fits = wfits && hfits;
    
    if (!fits && !scaleOK)
        return REJECT_SCORE;
    
    if (!fits && scaleOK) {    // scale
        scale = [self aspectScaleToSize:containerSize];
        // scaling takes CPU time.  We don't want that overhead, but
        // sometimes the available captures are best if they are a bit
        // larger than the display area.  But there can be way too
        // much useless scaling. So any scaling has a score of zero, at
        // best. Scores generated look like this:
        //  1/2 -100
        //  1/3 -200
        //  1/4 -300
        //  1/5 -400
        //  >- 0.5, serious negative scores
        if (scale > 0.5)
            scaleScore = 0;
        else {
            assert(scale != 0.0);
            scaleScore = -((1.0/scale) - 1.0)*100;
        }
        transformSize = CGSizeMake(captureSize.width*scale,
                                   captureSize.height*scale);
    } else {
        scale = 1.0;
        scaleScore = 100;
        transformSize = captureSize;
    }

    float captureArea = captureSize.width * captureSize.height;
    float containerArea = containerSize.width * containerSize.height;
    
    displayRect.origin = CGPointZero;
    displayRect.size = transformSize;

    right = CGSizeMake(containerSize.width - RIGHT(displayRect) - SEP, containerSize.height);
    bottom = CGSizeMake(containerSize.width, containerSize.height - BELOW(displayRect));

    CGSize bestDisplaySize;
    CGSize thumbSize;
    float bestDisplayAreaPct;
    
    // set up targets sizes and rules for the various display options
    switch (displayOption) {
        case ControlDisplayOnly:
            thumbSize = fullThumbSize;
            bestDisplayAreaPct = 0.0;
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsUnderneath;
            thumbArrayRect = CGRectZero;
            break;
        case TightDisplay:
            thumbSize = tightThumbSize;
            bestDisplayAreaPct = 20.0;  // should depend on device and orientation
            minThumbCols = MIN_IPHONE_THUMB_COLS;
            minThumbRows = MIN_IPHONE_THUMB_ROWS;
            if (isiPhone) {
                if (isPortrait)
                    thumbsPlacement = ThumbsUnderneath;
                else
                    thumbsPlacement = ThumbsOnRight;
            } else {
                thumbsPlacement = ThumbsUndecided;
            }
            break;
        case BestDisplay:
            thumbSize = isiPhone ? tightThumbSize : fullThumbSize;
            bestDisplayAreaPct = 50.0;  // should depend on device and orientation
            break;
        case LargestImageDisplay:
            thumbSize = isiPhone ? tightThumbSize : fullThumbSize;
            bestDisplaySize = containerSize;
            bestDisplayAreaPct = 100.0;
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsOptional;
            break;
        case FullScreenImage:
            thumbSize = CGSizeZero;
            ; // XXXXX not yet
    }
    
    firstThumbRect.size = thumbSize;
    firstThumbRect.origin = CGPointZero;
    thumbImageRect = firstThumbRect;
    thumbImageRect.size.height -= OLIVE_LABEL_H;
    
    int rightThumbCount = [self thumbsInArea:right];
    int bottomThumbCount = [self thumbsInArea:bottom];
    float rightThumbScore = 100.0 * (float)rightThumbCount / (float)thumbCount;
    float bottomThumbScore = 100.0 * (float)bottomThumbCount / (float)thumbCount;
    float thumbScore = 0.0;
    
    switch (thumbsPlacement) {
        case ThumbsUnderAndRight:
        case ThumbsUndecided:
            thumbsPlacement = rightThumbScore > bottomThumbScore ? ThumbsOnRight : ThumbsUnderneath;
            break;
        default:
            ;
    }

    switch (thumbsPlacement) {
       case ThumbsOptional:
            break;
        case ThumbsUnderneath:
            thumbScore = bottomThumbScore;
            // center display for thumbs on bottom
            displayRect.origin.x = (containerView.frame.size.width - displayRect.size.width)/2.0;
            break;
        case ThumbsOnRight:
            thumbScore = rightThumbScore;
            break;
        case ThumbsOff:
            thumbScore = 100;
            break;
        default:
            assert(0); // should not happen
    }
   
    switch (thumbsPlacement) {
        case ThumbsOnRight:
            thumbArrayRect.origin = CGPointMake(RIGHT(displayRect) + SEP, displayRect.origin.y);
            thumbArrayRect.size = right;
            break;
        case ThumbsUnderneath:
            thumbArrayRect.origin = CGPointMake(0, BELOW(displayRect));
            thumbArrayRect.size = CGSizeMake(containerView.frame.size.width,
                                             containerView.frame.size.height - thumbArrayRect.origin.y);
            break;
        default:
            thumbArrayRect = CGRectZero;
    }
    
#ifdef OLD
    if (rightThumbCount > 0 && rightThumbCount > bottomThumbCount ) {   // free thumbs on the right
        thumbArrayRect.size = right;
        thumbArrayRect.origin = CGPointMake(RIGHT(displayRect) + SEP, 0);
        // shift main stuff to the left
        executeRect.origin.x -= displayRect.origin.x;
        displayRect.origin.x = 0;
        // expand thumbs to fit space width
        int thumbsInRow = right.width / firstThumbRect.size.width;
        CGFloat extra = right.width - thumbsInRow * firstThumbRect.size.width;
        extra -= (thumbsInRow - 1)*SEP;
        extra = extra / (float)thumbsInRow;
        NSLog(@" right %4.0f x %4.0f:  %d %3.1f", right.width, right.height, thumbsInRow, extra);
        if (extra > 0.0)
            firstThumbRect.size.width += extra; // wider thumbs, to fit the space
    } else if (bottomThumbCount > 0) {
        thumbArrayRect.size = bottom;
        thumbArrayRect.origin = CGPointMake(0, BELOW(executeRect));
        // expand thumbs to fit the width
        int thumbsInRow = bottom.width / firstThumbRect.size.width;
        CGFloat extra = bottom.width - thumbsInRow * firstThumbRect.size.width;
        extra -= (thumbsInRow - 1)*SEP;
        extra = extra / (float)thumbsInRow;
        if (extra > 0.0)
            firstThumbRect.size.width += extra; // wider thumbs, to fit the space
    } else
        thumbArrayRect = CGRectZero;    // no thumbs
#endif
    
    capturePct = 100.0*captureArea/containerArea;
    if (scale == 1.0)
        score += (capturePct - 50.0)/10;
    else {
        score = 1.00 - captureArea/containerArea;
    }
    
    
//    int thumbsUnderneath = bottomThumbCount > rightThumbCount;
    
    float rightThumbs = right.width / (firstThumbRect.size.width + SEP);
    float rightArea = right.width * right.height;
    float rightPct = 100.0*rightArea/containerArea;
    
    float bottomThumbs = bottom.height / (firstThumbRect.size.height + SEP);
    float bottomArea = bottom.width * bottom.height;
    float bottomPct = 100.0*bottomArea/containerArea;
    
    BOOL rightThumbsOK = rightThumbs >= minThumbCols;
    BOOL bottomThumbsOK = bottomThumbs >= minThumbRows;
    
    if (score >= 0 && scale == 1.0)
        score += 5;     // avoids execution performance hit
    
    if (!(hfits || wfits))
        score = REJECT_SCORE;
    if (!(rightThumbsOK || bottomThumbsOK))
        score = REJECT_SCORE;

    
    status = [NSString stringWithFormat:@"%@%@ %@",
              rightThumbsOK ? CHECKMARK : @".",
              bottomThumbsOK ? CHECKMARK : @".",
              (wfits & hfits) ? CHECKMARK : @"." ];
#ifdef DEBUG_LAYOUT
    NSLog(@"%4.0f x %4.0f  %4.2f  %4.0f%%\t%5.1f,%2.0f%%\t%5.1f,%2.0f%%\t%@\t%.0f",
          captureSize.width, captureSize.height, aspectRatio,
          capturePct,
          rightThumbs, rightPct,
          bottomThumbs, bottomPct,
          status, score);
#endif
    
    // screen %
    //XXX thumbs %
    // % of capture image
    // score
    
    float transformArea = transformSize.width * transformSize.height;
    float screenPct = 100.0*transformArea / containerArea;
    capturePct = 100.0 * transformArea / captureArea;
    
    status = [NSString stringWithFormat:@"for screen %4.0f x %4.0f:\n%@\n\ntransform %4.0f x %4.0f  (%5.1f%%)\nfrom capture %4.0f x %4.0f  (%5.1f%%)\nscale score %.0f\nthumb score %.0f\nscore:%5.0f",
              containerSize.width, containerSize.height,
              displayOptionNames[displayOption],
              transformSize.width, transformSize.height,
              screenPct,
              captureSize.width, captureSize.height,
              100.0*scale,
              scaleScore, thumbScore,
              score];
#ifdef DEBUG_LAYOUT
    NSLog(@"*** final layout status: %@", status);
#endif
    return score;
}

- (float) aspectScaleToSize:(CGSize) targetSize {
    float hScale = targetSize.width / captureSize.width;
    float vScale = targetSize.height / captureSize.height;
    return MIN(hScale, vScale);
}

- (int) thumbsInArea:(CGSize) area {
    int ncols = area.width / firstThumbRect.size.width;
    int nrows = area.height / firstThumbRect.size.height;
    return ncols * nrows;
}

@end
