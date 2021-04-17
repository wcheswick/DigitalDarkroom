//
//  Layout.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/2/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

#define REJECT_SCORE    (-9000000)

typedef enum {
    ControlDisplayOnly,
    TightDisplay,
    BestDisplay,
    LargestImageDisplay,
    FullScreenImage,
} DisplayOptions;


typedef enum {
    ThumbsUnderneath,
    ThumbsOnRight,
    ThumbsUnderAndRight,        // not implemented
    ThumbsOff,              // Internal use ...
    ThumbsUndecided,        // ...
    ThumbsOptional,         // ... only
} ThumbsPlacement;

@interface Layout : NSObject {
    AVCaptureDeviceFormat *format;
    BOOL isPortrait, isiPhone;
    DisplayOptions displayOption;
    UIView *containerView;  // copied from the caller
    size_t thumbCount;        // copied from the caller
    
    float scale;            // how we scale the capture image.  1.0 (no scaling) is most efficient
    float aspectRatio;

    // layout stats and results:

    ThumbsPlacement thumbsPlacement;
    float displayFrac;      // fraction of total display used by the transformed image
    float thumbFrac;        // fraction of thumbs shown
    
    CGSize captureSize;     // what we get from the input source
    CGSize transformSize;   // what we give the transform chain
    CGRect displayRect;     // what we give to the main display
    CGRect thumbArrayRect;  // where the thumbs go
    CGRect firstThumbRect;  // thumb size for device, orientation, and aspect ratio
    CGRect thumbImageRect;  // image sample size in the thumb
    CGRect executeRect;     // where the description text goes
    BOOL executeOverlayOK;  // if execute can creep up onto the transform display
    
    NSString *status;
}

@property (nonatomic, strong)   AVCaptureDeviceFormat *format;
@property (assign)              DisplayOptions displayOption;
@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;  // the screen real estate we lay out in

@property (assign)              ThumbsPlacement thumbsPlacement;
@property (assign)              float displayFrac, thumbFrac;

@property (assign)              CGSize captureSize;     // what we get from the camera or file
@property (assign)              CGSize transformSize;   // what we give to the transform chain
@property (assign)              CGRect displayRect;     // where the transform chain puts the (possibly scaled) result
@property (assign)              CGRect thumbArrayRect;  // where the scrollable thumb array goes
@property (assign)              CGRect executeRect;     // text list location
@property (assign)              BOOL executeOverlayOK;

@property (assign)              CGRect firstThumbRect, thumbImageRect;
@property (assign)              size_t thumbCount;

@property (assign)              float scale, aspectRatio;
@property (nonatomic, strong)   NSString *status;

- (id)initForOrientation:(BOOL) port
               iPhone:(BOOL) isPhone
              displayOption:(DisplayOptions) dopt;

- (BOOL) layoutForFormat:(AVCaptureDeviceFormat *) f scale:(float) scale;
- (BOOL) layoutForSize:(CGSize) cs scale:(float) scale;

extern  NSString * __nullable displayOptionNames[];

@end

NS_ASSUME_NONNULL_END
