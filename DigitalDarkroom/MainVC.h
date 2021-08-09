//
//  MainVC.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ThumbView.h"
#import "InputSource.h"

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

@protocol videoSampleProcessorDelegate
- (void) processSampleBuffer:(CMSampleBufferRef _Nonnull)sampleBuffer
                       depth:(AVDepthData *__nullable) depthData;
@end

@interface MainVC : UIViewController
        <UICollectionViewDelegate,
//        UICollectionViewDataSource,
//        UICollectionViewDelegateFlowLayout,
//        UIScrollViewDelegate,
        videoSampleProcessorDelegate,
        UIPopoverPresentationControllerDelegate> {
    // layout looks at these:
    BOOL isPortrait, isiPhone;
    UIView *containerView;
    NSMutableArray *thumbViewsArray;
}

@property (assign)              BOOL isPortrait, isiPhone;
@property (nonatomic, strong)   UIView *containerView;
@property (nonatomic, strong)   NSMutableArray *thumbViewsArray; // views that go into thumbsView

//- (void) loadImageWithURL: (NSURL *)URL;    // not implemented yet

- (void) transformsIdle;
- (void) newDeviceOrientation;

extern MainVC *mainVC;

@end

NS_ASSUME_NONNULL_END
