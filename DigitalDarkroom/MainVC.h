//
//  MainVC.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MessageUI/MessageUI.h>

#import "TaskCtrl.h"
#import "ThumbView.h"
#import "InputSource.h"
#import "Frame.h"
#import "Stats.h"

@class CameraController;

NS_ASSUME_NONNULL_BEGIN

typedef enum {  // the transformed display on the main screen
    ThumbsOnly,         // maybe for external screen of transformed image
    iPhoneScreen,       // small image on iPhone to show more thumbs
    iPadScreen,         // standard options for an iPad
    TransformedPlusExecOnly,
    TransformedOnly,    // only the display
} DisplayOptions;

@interface MainVC : UIViewController
        <UICollectionViewDelegate,
        UICollectionViewDataSource,
//        UICollectionViewDelegateFlowLayout,
//        UIScrollViewDelegate,
        MFMailComposeViewControllerDelegate,
        UIContentContainer,
        UIPopoverPresentationControllerDelegate> {
    // layout looks at these:
    BOOL isPortrait, isiPhone;
    UIView *containerView;
    NSMutableArray<ThumbView *> *thumbViewsArray;
    Stats *stats;
    CameraController *cameraController;
}

@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;  // Layout uses this
@property (nonatomic, strong)   NSMutableArray<ThumbView *> *thumbViewsArray; // views that go into thumbsView
@property (nonatomic, strong)   Stats *stats;
@property (nonatomic, strong)   CameraController *cameraController;

- (void) tasksReadyFor:(LayoutStatus_t) layoutStatus;

//- (void) loadImageWithURL: (NSURL *)URL;    // not implemented yet

extern MainVC *mainVC;

@end

NS_ASSUME_NONNULL_END
