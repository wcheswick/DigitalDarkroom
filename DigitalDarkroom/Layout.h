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
    
    CGSize availableSize;
    CGSize captureSize, displaySize;
    CGSize thumbSize, thumbImageSize;
    CGSize thumbArraySize;
    
    size_t thumbsUnderneath, thumbsOnRight;
    float scale;
    
    float score;
}

@property (nonatomic, strong)   AVCaptureDeviceFormat *format;
@property (assign)              DisplayOptions displayOption;
@property (assign)              BOOL isPortrait;
@property (assign)              CGSize availableSize;
@property (assign)              CGSize captureSize, displaySize;
@property (assign)              CGSize thumbSize, thumbImageSize, thumbArraySize;
@property (assign)              size_t thumbsUnderneath, thumbsOnRight;
@property (assign)              float scale, score;

- (id)initForSize:(CGSize) as
            portrait:(BOOL) port
    displayOption:(DisplayOptions) dopt;

- (int) layoutForFormat:(AVCaptureDeviceFormat *) f scaleOK:(BOOL) scaleOK;
- (int) layoutForSize:(CGSize) s scaleOK:(BOOL) scaleOK;

@end

NS_ASSUME_NONNULL_END
