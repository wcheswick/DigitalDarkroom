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

#define LAYOUT_IS_BAD(q)   (q < 0)

#define LAYOUT_NO_GOOD          (-1)    // default whining
#define LAYOUT_BAD_TOO_SMALL    (-2)    // if needs larger display screen
#define LAYOUT_BAD_TOO_LARGE    (-3)    // if needs smaller display screen

typedef enum {
    NoDisplay,          // only controls
    TightDisplay,       // iPhone and the like
    BestDisplay,        // good standard iPad display
    FullScreenDisplay,    // only the display
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
    AVCaptureDeviceFormat * __nullable format;
    BOOL isPortrait, isiPhone;
    CGRect containerFrame;  // copied from the caller
    size_t thumbCount;        // copied from the caller
    DisplayOptions currentDisplayOption;
    
    float scale;            // how we scale the capture image.  1.0 (no scaling) is most efficient
    float aspectRatio;      // of the input source
    int quality;

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
    BOOL executeIsTight;    // if save verticle space
    CGFloat executeRectBottom;
    NSString *status;
}

@property (nonatomic, strong)   AVCaptureDeviceFormat * __nullable format;
@property (assign)              BOOL isPortrait, isiPhone;
@property (assign)              CGRect containerFrame;
@property (assign)              CGSize targetDisplaySize;
@property (assign)              DisplayOptions currentDisplayOption;


@property (assign)              ThumbsPlacement thumbsPlacement;
@property (assign)              float displayFrac, thumbFrac;

@property (assign)              CGSize captureSize;     // what we get from the camera or file
@property (assign)              CGSize transformSize;   // what we give to the transform chain
@property (assign)              CGRect displayRect;     // where the transform chain puts the (possibly scaled) result
@property (assign)              CGRect thumbArrayRect;  // where the scrollable thumb array goes
@property (assign)              CGRect executeRect;     // total area available for the execute list
@property (assign)              BOOL executeOverlayOK, executeIsTight;  // text placement guidance
@property (assign)              CGFloat executeRectBottom;

@property (assign)              CGRect firstThumbRect, thumbImageRect;
@property (assign)              size_t thumbCount;

@property (assign)              float scale, aspectRatio;
@property (assign)              int quality;        // -1 = no, more positive is better

@property (nonatomic, strong)   NSString *status;

- (id)initForOrientation:(BOOL) port
                  iPhone:(BOOL) isPhone
           containerRect:(CGRect) containerRect;

- (Layout *) layoutForSourceSize:(CGSize) cs
                  displaySize:(CGSize) ds
                   displayOption:(DisplayOptions) displayOption;

- (void) adjustForDisplaySize:(CGSize) ds;
- (NSComparisonResult) compare:(Layout *)layout;

extern  NSString * __nullable displayOptionNames[];

@end

NS_ASSUME_NONNULL_END
