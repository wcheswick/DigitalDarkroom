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

#define NO_INPUT_SOURCE   (-1)

@interface MainVC : UIViewController
    <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate,
    UIPopoverPresentationControllerDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout,
    AVCaptureVideoDataOutputSampleBufferDelegate> {
}


//-(void)deviceRotated;

@end
