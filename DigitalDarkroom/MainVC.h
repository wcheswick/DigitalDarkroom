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
//    exhibitUI,
    oliveUI,
} UIMode_t;

@interface MainVC : UIViewController
<UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout,
    UIScrollViewDelegate,
    UIPopoverPresentationControllerDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureDepthDataOutputDelegate> {
        UIDeviceOrientation currentDeviceOrientation;
}

@property (assign)  UIDeviceOrientation currentDeviceOrientation;

//- (void) loadImageWithURL: (NSURL *)URL;    // not implemented yet
- (void) doLayout;
- (void) deviceRotated;

@end
