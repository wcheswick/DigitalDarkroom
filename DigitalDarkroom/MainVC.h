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
#import "ThumbView.h"

typedef enum {
    Bottom,
    Right,
    Both,
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
    UICollectionViewDelegateFlowLayout,
    UIScrollViewDelegate,
    UIPopoverPresentationControllerDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureDepthDataOutputDelegate> {
    // layout looks at these:
    BOOL isPortrait, isiPhone;
    UIView *containerView;
    NSMutableArray *thumbViewsArray;
}

@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;
@property (nonatomic, strong)   NSMutableArray *thumbViewsArray; // views that go into thumbsView

//- (void) loadImageWithURL: (NSURL *)URL;    // not implemented yet

- (void) tasksAreIdle;
- (void) newDeviceOrientation;

extern MainVC *mainVC;

@end
