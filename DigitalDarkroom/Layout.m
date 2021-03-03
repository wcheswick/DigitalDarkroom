//
//  Layout.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/2/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "Layout.h"
#import "Defines.h"

@implementation Layout

@synthesize format;
@synthesize isPortrait, displayOption;
@synthesize availableSize;
@synthesize captureSize, displaySize;
@synthesize thumbSize, thumbImageSize, thumbArraySize;
@synthesize thumbsUnderneath, thumbsOnRight;
@synthesize scale, score;

- (id)initForSize:(CGSize) as
            portrait:(BOOL) port
              displayOption:(DisplayOptions) dopt {
    self = [super init];
    if (self) {
        format = nil;
        availableSize = as;
        isPortrait = port;
        displayOption = dopt;
        scale = 1.0;
        score = 0;
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
    return [self layoutForSize:capSize scaleOK:scaleOK];
}


- (int) layoutForSize:(CGSize) s scaleOK:(BOOL) scaleOK {   // for captureSize
    captureSize = s;
    float captureAR = captureSize.width / captureSize.height;
    
    int minThumbCols, minThumbRows;
    switch (displayOption) {
        case TightDisplay:
            minThumbCols = MIN_IPHONE_THUMB_COLS;
            minThumbRows = MIN_IPHONE_THUMB_ROWS;
            thumbSize.width = SMALL_THUMB_W;
            break;
        default:
            minThumbCols = MIN_THUMB_COLS;
            minThumbRows = MIN_THUMB_ROWS;
            thumbSize.width = THUMB_W;
    }
    thumbSize.height = thumbSize.width / captureAR;
    
    float captureArea = captureSize.width * captureSize.height;
    float totalArea = availableSize.width * availableSize.height;
    float capturePct = 100.0*captureArea/totalArea;
    if (capturePct >= 50.0)
        score += 5;     // efficient use of screen
    
    CGSize right, bottom;
    right.width = availableSize.width - captureSize.width;
    right.height = availableSize.height;
    bottom.height = availableSize.height - captureSize.height;
    bottom.width = availableSize.width;
    
    int rightThumbCount = [self thumbsInArea:right];
    int bottomThumbCount = [self thumbsInArea:bottom];
    
    thumbsUnderneath = bottomThumbCount > rightThumbCount;
    thumbArraySize = thumbsUnderneath ? bottom : right;
    
    float rightThumbs = right.width / (thumbSize.width + SEP);
    float rightArea = right.width * right.height;
    float rightPct = 100.0*rightArea/totalArea;

    float bottomThumbs = bottom.height / (thumbSize.height + SEP);
    float bottomArea = bottom.width * bottom.height;
    float bottomPct = 100.0*bottomArea/totalArea;
    
    BOOL wfits = captureSize.width <= availableSize.width;
    BOOL hfits = captureSize.height <= availableSize.height;
    
    BOOL rightThumbsOK = rightThumbs >= minThumbCols;
    BOOL bottomThumbsOK = bottomThumbs >= minThumbRows;

    NSString *status = [NSString stringWithFormat:@"%@%@ %@",
                        rightThumbsOK ? CHECKMARK : @".",
                        bottomThumbsOK ? CHECKMARK : @".",
                        (wfits & hfits) ? CHECKMARK : @"." ];
    NSLog(@"%4.0f x %4.0f  %4.2f  %4.0f%%\t%5.1f,%2.0f%%\t%5.1f,%2.0f%%\t%@",
          captureSize.width, captureSize.height, captureSize.width/captureSize.height,
          capturePct,
          rightThumbs, rightPct,
          bottomThumbs, bottomPct,
          status);
    
    if (!(hfits || wfits))
        return REJECT_SCORE;
    if (!(rightThumbsOK || bottomThumbsOK))
        return REJECT_SCORE;

#ifdef NOPE
    if (captureAR > availableAR)
        arscale = size.height / availableSize.height;
    else
        arscale = size.width / availableSize.width;
    CGSize arscaled = CGSizeMake(availableSize.width*arscale, availableSize.height*arscale);
#endif
    if (scale == 1.0)
        score += 5;     // avoids execution performance hit
    
    displaySize = captureSize;
    return score;
}

- (int) thumbsInArea:(CGSize) area {
    int ncols = area.width / thumbSize.width;
    int nrows = area.height / thumbSize.height;
    return ncols * nrows;
}

@end
