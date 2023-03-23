//
//  FormatInfo.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/23/23.
//  Copyright © 2023 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "InputSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface FormatInfo: NSObject {
    InputSource *source;
    int formatIndex, depthFormatIndex;
    BOOL front, rear, threeD, HDR;
    CGFloat w, h, dw, dh;
}

@property (nonatomic, strong)   InputSource *source;
@property (assign)    int cameraIndex, formatIndex, depthFormatIndex;
@property (assign)    BOOL front, rear, threeD, HDR;
@property (assign)    CGFloat w, h, dw, dh;

- (id) initWithSource:(InputSource *) s;

@end

NS_ASSUME_NONNULL_END
