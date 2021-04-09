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

@interface Layout : NSObject {
    AVCaptureDeviceFormat *format;
    BOOL isPortrait, isiPhone;
    DisplayOptions displayOption;
    
    UIView *containerView;  // copied from the caller
    
    CGSize captureSize;
    CGSize transformSize;
    CGRect thumbArrayRect;
    CGRect firstThumbRect;
    CGRect thumbImageRect;      // within the thumb
    
    size_t thumbCount;
    float scale, aspectRatio;
    NSString *status;
    
    float score;
}

@property (nonatomic, strong)   AVCaptureDeviceFormat *format;
@property (assign)              DisplayOptions displayOption;
@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;  // the screen real estate we lay out in

@property (assign)              CGSize captureSize;     // what we get from the camera or file
@property (assign)              CGSize transformSize;   // what we give to the transform chain
@property (assign)              CGRect displayRect;     // where the transform chain puts the (possibly scaled) result
@property (assign)              CGRect thumbArrayRect;  // where the scrollable thumb array goes

@property (assign)              CGRect firstThumbRect, thumbImageRect;
@property (assign)              size_t thumbCount;

@property (assign)              float scale, score, aspectRatio;
@property (nonatomic, strong)   NSString *status;

- (id)initForOrientation:(BOOL) port
               iPhone:(BOOL) isPhone
              displayOption:(DisplayOptions) dopt;

- (int) layoutForFormat:(AVCaptureDeviceFormat *) f scaleOK:(BOOL) scaleOK;
- (int) layoutForSize:(CGSize) s scaleOK:(BOOL) scaleOK;

extern  NSString * __nullable displayOptionNames[];

@end

NS_ASSUME_NONNULL_END
