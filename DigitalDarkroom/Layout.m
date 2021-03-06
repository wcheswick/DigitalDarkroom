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

@property (assign)              size_t thumbsUnderneath, thumbsOnRight;

@end

@implementation Layout

@synthesize format;
@synthesize isPortrait, isiPhone, displayOption;
@synthesize containerView;
@synthesize captureSize, transformSize;
@synthesize displayRect, thumbArrayRect, executeRect;
@synthesize firstThumbRect, thumbImageRect;

@synthesize thumbsUnderneath, thumbsOnRight;
@synthesize scale, score, aspectRatio;
@synthesize status;

- (id)initForPortrait:(BOOL) port
              displayOption:(DisplayOptions) dopt {
    self = [super init];
    if (self) {
        format = nil;
        isPortrait = port;
        displayOption = dopt;
        scale = 1.0;
        score = 0;
        displayRect = thumbArrayRect = executeRect = CGRectZero;
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
    // thumb sizes are based on certain constants, plus the aspect ratio of the capture image
    captureSize = cs;
    score = 0;
    scale = 1;
    aspectRatio = captureSize.width / captureSize.height;
    firstThumbRect = thumbImageRect = CGRectZero;
    thumbArrayRect = CGRectZero;
    
    CGSize availableSize = containerView.frame.size;
    CGSize right, bottom;

    float capturePct = 0;
    
    BOOL wfits = captureSize.width <= availableSize.width;
    BOOL hfits = captureSize.height <= availableSize.height;
    BOOL fits = wfits && hfits;
    
    if (!fits && !scaleOK)
        return REJECT_SCORE;
    
    float captureArea = captureSize.width * captureSize.height;
    float totalArea = availableSize.width * availableSize.height;

    if (displayOption == FullScreenDisplay) {
        // just image plus (overlaid) execute, no thumbs
        thumbsUnderneath = thumbsOnRight = NO;
        thumbArrayRect = CGRectZero;
        
        if (!fits && scaleOK) {    // scale
            scale = [self aspectScaleToSize:availableSize];
            transformSize = CGSizeMake(captureSize.width*scale,
                                     captureSize.height*scale);
            score -= 3;
        } else
            transformSize = captureSize;
        
        // center at the top
        CGRect f;
        f.size = transformSize;
        f.origin.y = 0;
        f.origin.x = 0; // (availableSize.width - f.size.width)/2.0;
//        NSLog(@">> x %.1f  %.1f  %.1f", f.origin.x, availableSize.width, f.size.width);
        displayRect = f;
        
        f.size = CGSizeMake(EXECUTE_VIEW_W, EXECUTE_VIEW_H);
        f.origin.y = BELOW(displayRect);
        f.origin.x = (displayRect.size.width - f.size.width)/2.0;
        CGFloat spaceBelow = BELOW(f);
        if (spaceBelow > availableSize.height) {
            // doesn't fit underneath, ok to overlap transform image
            f.origin.y -= spaceBelow - availableSize.height;
            score -= 3;
        }
        executeRect = f;
        
        // At this point, we have taken a pretty good shot at a near-full screen image.
        // Even so, is there room for some thumbs?
        bottom = CGSizeMake(availableSize.width, availableSize.height - BELOW(executeRect));
        
        // the image and execute are centered, but see what it looks like if we left-adjust it
        // and put thumbs on the right.
        right = CGSizeMake(availableSize.width - RIGHT(displayRect) - SEP, availableSize.height);
        
        firstThumbRect = thumbImageRect = CGRectZero;
        firstThumbRect.size.width = thumbImageRect.size.width = isiPhone ? SMALL_THUMB_W : THUMB_W;
        thumbImageRect.size.height = thumbImageRect.size.width / aspectRatio;
        firstThumbRect.size.height = thumbImageRect.size.height + OLIVE_LABEL_H;

        int rightThumbCount = [self thumbsInArea:right];
        int bottomThumbCount = [self thumbsInArea:bottom];
        
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
        
        capturePct = 100.0*captureArea/totalArea;
        if (scale == 1.0)
            score += (capturePct - 50.0)/10;
        else {
            score = 1.00 - captureArea/totalArea;
        }
    } else {
        
    }
    
#ifdef NOTYET
    // displayRect and executeRect are computed. Place thumbs, even for "fullscreen",
    // if there is room.
    
    
    right.width = availableSize.width - captureSize.width;
    right.height = availableSize.height;
    bottom.height = availableSize.height - captureSize.height;
    bottom.width = availableSize.width;

    int minThumbCols, minThumbRows;
    firstThumbRect = thumbImageRect = CGRectZero;
    switch (displayOption) {
        case TightDisplay:
            minThumbCols = MIN_IPHONE_THUMB_COLS;
            minThumbRows = MIN_IPHONE_THUMB_ROWS;
            firstThumbRect.size.width = SMALL_THUMB_W;
            break;
        default:
            minThumbCols = MIN_THUMB_COLS;
            minThumbRows = MIN_THUMB_ROWS;
            firstThumbRect.size.width = THUMB_W;
    }
    thumbImageRect.size.height = thumbImageRect.size.width / aspectRatio;
    firstThumbRect.size.height = thumbImageRect.size.height + OLIVE_LABEL_H;
    
    int thumbsUnderneath = bottomThumbCount > rightThumbCount;
    
    float rightThumbs = right.width / (firstThumbRect.size.width + SEP);
    float rightArea = right.width * right.height;
    float rightPct = 100.0*rightArea/totalArea;

    float bottomThumbs = bottom.height / (firstThumbRect.size.height + SEP);
    float bottomArea = bottom.width * bottom.height;
    float bottomPct = 100.0*bottomArea/totalArea;
    
    BOOL rightThumbsOK = rightThumbs >= minThumbCols;
    BOOL bottomThumbsOK = bottomThumbs >= minThumbRows;
    
    if (!(hfits || wfits))
        score = REJECT_SCORE;
    if (!(rightThumbsOK || bottomThumbsOK))
        score = REJECT_SCORE;

    if (score >= 0 && scale == 1.0)
        score += 5;     // avoids execution performance hit

    status = [NSString stringWithFormat:@"%@%@ %@",
                        rightThumbsOK ? CHECKMARK : @".",
                        bottomThumbsOK ? CHECKMARK : @".",
                        (wfits & hfits) ? CHECKMARK : @"." ];
    NSLog(@"%4.0f x %4.0f  %4.2f  %4.0f%%\t%5.1f,%2.0f%%\t%5.1f,%2.0f%%\t%@\t%.0f",
          captureSize.width, captureSize.height, aspectRatio,
          capturePct,
          rightThumbs, rightPct,
          bottomThumbs, bottomPct,
          status, score);
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
