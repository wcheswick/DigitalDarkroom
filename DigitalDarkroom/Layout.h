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

#define REJECT_SCORE    (-5)

typedef enum {
    TightDisplay,
    BestDisplay,
    FullScreenDisplay,
} DisplayOptions;

@interface Layout : NSObject {
    AVCaptureDeviceFormat *format;
    BOOL isPortrait;
    DisplayOptions displayOption;
    
    UIView *containerView;  // copied from the caller
    
    CGSize captureSize;
    CGSize transformSize;
    CGRect thumbArrayRect, executeRect;
    CGRect firstThumbRect;
    CGRect thumbImageRect;      // within the thumb
    CGSize thumbArraySize;
    
    size_t thumbsUnderneath, thumbsOnRight;
    float scale, aspectRatio;
    NSString *status;
    
    float score;
}

@property (nonatomic, strong)   AVCaptureDeviceFormat *format;
@property (assign)              DisplayOptions displayOption;
@property (assign)              BOOL isPortrait;
@property (nonatomic, strong)   UIView *containerView;  // the screen real estate we lay out in

@property (assign)              CGSize captureSize;     // what we get from the camera or file
@property (assign)              CGSize transformSize;   // what we give to the transform chain
@property (assign)              CGRect displayRect;     // where the chain puts the (possibly scaled) result
@property (assign)              CGRect thumbArrayRect;  // where the scrollable thumb array goes
@property (assign)              CGRect executeRect;     // where the execution details go

@property (assign)              CGRect firstThumbRect, thumbImageRect;

@property (assign)              float scale, score, aspectRatio;
@property (nonatomic, strong)   NSString *status;

- (id)initForPortrait:(BOOL) port
              displayOption:(DisplayOptions) dopt;

- (int) layoutForFormat:(AVCaptureDeviceFormat *) f scaleOK:(BOOL) scaleOK;
- (int) layoutForSize:(CGSize) s scaleOK:(BOOL) scaleOK;

@end

NS_ASSUME_NONNULL_END
