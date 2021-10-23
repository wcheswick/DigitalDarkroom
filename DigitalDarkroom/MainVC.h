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

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    Bottom,
    Right,
    Both,
    None,
} ThumbsPosition;

typedef enum {
    NoDisplay,          // only controls
    TightDisplay,       // iPhone and the like
    BestDisplay,        // good standard iPad display
    FullScreenDisplay,    // only the display
} DisplayOptions;

@interface MainVC : UIViewController
        <UICollectionViewDelegate,
        UICollectionViewDataSource,
//        UICollectionViewDelegateFlowLayout,
//        UIScrollViewDelegate,
        MFMailComposeViewControllerDelegate,
        UIPopoverPresentationControllerDelegate> {
    // layout looks at these:
    BOOL isPortrait, isiPhone;
    UIView *containerView;
    NSMutableArray<ThumbView *> *thumbViewsArray;
    Stats *stats;
}

@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;  // Layout uses this
@property (nonatomic, strong)   NSMutableArray<ThumbView *> *thumbViewsArray; // views that go into thumbsView
@property (nonatomic, strong)   Stats *stats;

- (void) tasksReadyFor:(LayoutStatus_t) layoutStatus;
- (void) newDeviceOrientation;

//- (void) loadImageWithURL: (NSURL *)URL;    // not implemented yet

extern MainVC *mainVC;

@end

NS_ASSUME_NONNULL_END
