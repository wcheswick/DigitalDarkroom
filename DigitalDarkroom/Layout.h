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
#import "MainVC.h"

NS_ASSUME_NONNULL_BEGIN

#define LAYOUT_IS_BAD(q)   (q < 0)
#define IS_CAMERA_LAYOUT(l) ((l) != nil)

#define BAD_LAYOUT          (0.0)    // no quality. 1.0 is perfect
#define NO_FORMAT   (-1)
#define INDEX_UNKNOWN   (-1)

typedef enum {
    Bottom,
    Right,
    None,
} ThumbsPosition;

@interface Layout : NSObject {
    LayoutOptions layoutOption;
    CGSize sourceImageSize;  // file or camera output size
    AVCaptureDevice *device;    // nil if file or undecided
    AVCaptureDeviceFormat *format;
    AVCaptureDeviceFormat *depthFormat;
    NSUInteger index;  // index of this layout in layouts in Main, or -1

    // computed layout rectangles:
    CGSize transformSize;   // what we give the transform chain
    CGRect displayRect;     // where we put the transformed (and scaled) result
    CGRect fullThumbViewRect;
    CGRect thumbScrollRect;
    CGRect executeScrollRect;     // where the active transform list is shown
    CGFloat executeScrollMinH;
    CGRect executeRect;
    CGRect plusRect;        // in executeRect
    CGRect paramRect;       // where the parameter slider goes
    
    CGRect firstThumbRect;  // thumb size and position in fullThumbViewRect
    CGRect thumbImageRect;  // image sample size in each thumb button
    
    // details about this layout
    float scale;            // how we scale the capture image.  1.0 (no scaling) is most efficient
    float aspectRatio;      // of the input source

    
    float score;            // quality of layout from 0.0 (reject) to 1.0 (perfect)
    NSString *type;         // layout type (coded text)

    // layout stats and results:
    BOOL executeIsTight;    // if save verticle space
    float displayFrac;      // fraction of total display used by the transformed image
    float pctUsed;         // non-wasted screen use
    
    BOOL executeOverlayOK;  // if execute can creep up onto the transform display
    NSString *status;
}

@property (nonatomic, strong)   AVCaptureDevice *device;
@property (nonatomic, strong)   AVCaptureDeviceFormat *format;
@property (nonatomic, strong)   AVCaptureDeviceFormat *depthFormat;
@property (assign)              NSUInteger index;

@property (assign)              LayoutOptions layoutOption;
@property (assign)              CGSize sourceImageSize;
@property (assign)              CGSize transformSize;
@property (assign)              CGRect displayRect;
@property (assign)              CGRect fullThumbViewRect;
@property (assign)              CGRect thumbScrollRect;
@property (assign)              CGRect executeScrollRect;
@property (assign)              CGRect plusRect;
@property (assign)              CGRect paramRect;
@property (assign)              CGFloat executeScrollMinH;

@property (assign)              CGRect firstThumbRect, thumbImageRect;

@property (assign)              float scale, aspectRatio;
@property (assign)              float score;
@property (nonatomic, strong)   NSString *type;
@property (assign)              BOOL executeIsTight;
@property (assign)              float displayFrac, pctUsed;

@property (assign)              BOOL executeOverlayOK;  // text placement guidance
@property (nonatomic, strong)   NSString *status;

- (id)initForSize:(CGSize) iss
      rightThumbs:(size_t) rightThumbs
     bottomThumbs:(size_t) bottomThumbs
     layoutOption:(LayoutOptions) lopt
           device:(AVCaptureDevice *__nullable)dev
           format:(AVCaptureDeviceFormat *__nullable) form
      depthFormat:(AVCaptureDeviceFormat *__nullable) df;

- (NSComparisonResult) compare:(Layout *)layout;
+ (CGSize) fitSize:(CGSize)srcSize toSize:(CGSize)size;

#ifdef NOTDEF
- (void) tryLayoutsForThumbsAndExecOnly:(BOOL) narrowExec;

- (void) tryLayoutsOnRight:(BOOL) narrowExec;
- (void) tryLayoutsForExecOnLeft:(BOOL) narrowExec;
- (void) tryLayoutsForStacked;
- (void) tryLayoutsForJustDisplayOnLeft:(BOOL) narrowExec;
- (void) tryLayoutsForJustDisplay;
#endif

- (NSString *) layoutSum;
- (void) dump;

extern  NSString * __nullable displayOptionNames[];

@end

NS_ASSUME_NONNULL_END
