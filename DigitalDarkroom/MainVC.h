//
//  MainVC.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SelectInputVC.h"

@interface MainVC : UIViewController
    <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate,
    UIPopoverPresentationControllerDelegate,
    SelectInputProto,
    AVCaptureVideoDataOutputSampleBufferDelegate> {
}


//-(void)deviceRotated;

@end
