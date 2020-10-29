//
//  MainVC.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "InputSource.h"

typedef enum {
    small,  // mostly for iPhones
    medium,
    fullScreen,
    alternateScreen,
} DisplayMode_t;

@interface MainVC : UIViewController
    <UITableViewDelegate,
    UITableViewDataSource,
    UIScrollViewDelegate,
    UIPopoverPresentationControllerDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureDepthDataOutputDelegate> {
}

- (void) loadImageWithURL: (NSURL *)URL;

@end
