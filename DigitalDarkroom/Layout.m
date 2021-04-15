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
@synthesize captureSize;
@synthesize transformSize, displayRect;
@synthesize displayFrac, thumbFrac;
@synthesize thumbsPlacement;
@synthesize thumbArrayRect;
@synthesize executeRect;
@synthesize firstThumbRect, thumbImageRect;

@synthesize thumbCount;
@synthesize scale, aspectRatio;
@synthesize status;

- (id)initForOrientation:(BOOL) port
               iPhone:(BOOL) isPhone
              displayOption:(DisplayOptions) dopt {
    self = [super init];
    if (self) {
        format = nil;
        isPortrait = port;
        isiPhone = isPhone;
        displayOption = dopt;
        scale = 1.0;
        thumbCount = 1000;  // rediculous number
        thumbArrayRect = CGRectZero;
        displayRect = CGRectZero;
        transformSize = CGSizeZero;
        executeRect = CGRectZero;
        status = nil;
        containerView = nil;
    }
    return self;
}

- (BOOL) layoutForFormat:(AVCaptureDeviceFormat *) f scale:(float) scale {
    format = f;
//    NSLog(@" trying format %@", format);
    CMFormatDescriptionRef ref = format.formatDescription;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(ref);
    CGSize capSize = isPortrait ? CGSizeMake(dimensions.height, dimensions.width) :
                CGSizeMake(dimensions.width, dimensions.height);
    return [self layoutForSize:capSize scale:scale];
}

// Can we make an acceptible layout with the given capture size and scaling?

- (BOOL) layoutForSize:(CGSize) cs scale:(float) s {   // for captureSize
    scale = s;
    captureSize = cs;
    aspectRatio = captureSize.width / captureSize.height;
    CGSize scaledSize = CGSizeMake(cs.width*scale, cs.height*scale);
    
    thumbArrayRect = CGRectZero;
    int minThumbCols = MIN_THUMB_COLS;
    int minThumbRows = MIN_THUMB_ROWS;

    CGRect right = CGRectZero;
    CGRect bottom = CGRectZero;
    
    BOOL wfits = scaledSize.width <= containerView.frame.size.width;
    BOOL hfits = scaledSize.height <= containerView.frame.size.height;
    BOOL fits = wfits && hfits;
    
    if (!fits) {
#ifdef NODEF
        if (s != 1.0)
            NSLog(@"reject, too big:  %4.0f x %4.0f @ %.2f", cs.width, cs.height, s);
#endif
        return NO;
    }
    
    transformSize = scaledSize;

    float containerArea = containerView.frame.size.width * containerView.frame.size.height;
    
//    float captureArea = captureSize.width * captureSize.height;
    float transformArea = transformSize.width * transformSize.height;
    displayRect.origin = CGPointZero;
    displayRect.size = transformSize;
    displayFrac = transformArea / containerArea;
    
    // minimum executeRect, to be adjusted later
    executeRect.origin = CGPointMake(0, BELOW(displayRect) + SEP);
    executeRect.size = CGSizeMake(displayRect.size.width,EXECUTE_MIN_BELOW_H);
    
    right.origin = CGPointMake(RIGHT(displayRect) + SEP, displayRect.origin.y);
    right.size = CGSizeMake(containerView.frame.size.width - right.origin.x, containerView.frame.size.height);
    bottom.origin = CGPointMake(0, BELOW(executeRect) + SEP);
    bottom.size = CGSizeMake(containerView.frame.size.width, containerView.frame.size.height - bottom.origin.y);

    CGSize bestDisplaySize;
    float bestDisplayAreaPct;
    
    firstThumbRect = thumbImageRect = CGRectZero;
    
    thumbImageRect.origin = CGPointZero;
    thumbImageRect.size.width = isiPhone || displayOption == TightDisplay ? TIGHT_THUMB_W : THUMB_W;
    thumbImageRect.size.height = thumbImageRect.size.width / aspectRatio;
    
    firstThumbRect = thumbImageRect;
    firstThumbRect.size.height += OLIVE_LABEL_H;
    
    // set up targets sizes and rules for the various display options
    switch (displayOption) {
        case ControlDisplayOnly:
            bestDisplayAreaPct = 0.0;
            // XXXX executeRect
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsUnderneath;
            thumbArrayRect = CGRectZero;
            break;
        case TightDisplay:
            bestDisplayAreaPct = 20.0;  // should depend on device and orientation
            minThumbCols = MIN_IPHONE_THUMB_COLS;
            minThumbRows = MIN_IPHONE_THUMB_ROWS;
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
                thumbsPlacement = ThumbsOnRight;
            break;
        case LargestImageDisplay:
            bestDisplaySize = containerView.frame.size;
            bestDisplayAreaPct = 100.0;
            // just image plus (overlaid) execute, no thumbs unless there is spare room
            thumbsPlacement = ThumbsOptional;
            break;
        case FullScreenImage:
            ; // XXXXX not yet
    }
    
    int rightThumbCount = [self thumbsInArea:right.size];
    int bottomThumbCount = [self thumbsInArea:bottom.size];
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
            thumbFrac = rightThumbFrac;
            // with thumbs on the right, the execute can go to the bottom of the container
            executeRect.size.height = containerView.frame.size.height - executeRect.origin.y;
            break;
        case ThumbsUnderneath:
            thumbArrayRect = bottom;
            thumbFrac = bottomThumbFrac;
            // with thumbs underneath, the execute can go to the right edge of the container
            executeRect.size.width = containerView.frame.size.width;
            // and the transform display can be centered
            displayRect.origin.x = (containerView.frame.size.width - displayRect.size.width)/2.0;
           break;
        default:
            thumbArrayRect = CGRectZero;
    }
    

//    float rightThumbs = right.size.width / (firstThumbRect.size.width);
//    float rightArea = right.width * right.height;
//    float rightPct = 100.0*rightArea/containerArea;
    
//    float bottomThumbs = bottom.size.height / (firstThumbRect.size.height);
//    float bottomArea = bottom.width * bottom.height;
//    float bottomPct = 100.0*bottomArea/containerArea;
    
//    BOOL rightThumbsOK = rightThumbs >= minThumbCols;
//    BOOL bottomThumbsOK = bottomThumbs >= minThumbRows;
    
#ifdef notdef
    NSString *thumbStatus = [NSString stringWithFormat:@"%@%@",
              rightThumbsOK ? CHECKMARK : @".",
              bottomThumbsOK ? CHECKMARK : @"."];
#endif
    
#ifdef DEBUG_LAYOUT
    NSLog(@"    capture size: %4.0f x %4.0f  @ %.1f   fracs: %.3f  %.3f",
          captureSize.width, captureSize.height, scale,
          displayFrac, thumbFrac);
    if (scale != 1.0)
        NSLog(@"     scaled size: %4.0f x %4.0f", scaledSize.width, scaledSize.height);
#endif
    return YES;
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
