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
@class Layout;

NS_ASSUME_NONNULL_BEGIN


typedef enum {
    OnlyTransformDisplayed,
    OnlyThumbsDisplayed,
    BestiPhoneLayout,
    BestIPadLayout,
//    ModifiedLayout,     // larger or smaller by layoutSteps
} LayoutOptions;

@interface MainVC : UIViewController
        <UICollectionViewDelegate,
        UICollectionViewDataSource,
//        UICollectionViewDelegateFlowLayout,
        UIScrollViewDelegate,
        MFMailComposeViewControllerDelegate,
        UIContentContainer,
        UIPopoverPresentationControllerDelegate> {
    // layout looks at these:
    BOOL isPortrait, isiPhone;
    UIView *containerView;
    NSMutableArray<ThumbView *> *thumbViewsArray;
    Stats *stats;
    CameraController *cameraController;
    
    // screen limits
    CGFloat minExecWidth;
    CGFloat execFontSize, executeLabelH;
    float minDisplayFrac, bestMinDisplayFrac;
    float minThumbFrac, bestMinThumbFrac;
    float minPctThumbsShown;
    int minThumbRows, minThumbCols;
    int minDisplayWidth, maxDisplayWidth, minDisplayHeight, maxDisplayHeight;
    LayoutOptions layoutStyle;
    int layoutSteps;
}

@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;  // Layout uses this
@property (nonatomic, strong)   NSMutableArray<ThumbView *> *thumbViewsArray; // views that go into thumbsView
@property (nonatomic, strong)   Stats *stats;
@property (nonatomic, strong)   CameraController *cameraController;

@property (assign)  CGFloat minExecWidth;
@property (assign)  CGFloat executeLabelH;
@property (assign)  float minDisplayFrac, bestMinDisplayFrac;
@property (assign)  float minThumbFrac, bestMinThumbFrac;
@property (assign)  float minPctThumbsShown;
@property (assign)  int minThumbRows, minThumbCols;
@property (assign)  int minDisplayWidth, maxDisplayWidth, minDisplayHeight, maxDisplayHeight;
@property (assign)  LayoutOptions layoutStyle;
@property (assign)  int layoutSteps;

- (void) reconfigureDisplay;
- (void) adjustOrientation;

//- (void) loadImageWithURL: (NSURL *)URL;    // not implemented yet

extern MainVC *mainVC;

@end

NS_ASSUME_NONNULL_END
