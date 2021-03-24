//
//  MainVC.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "MainVC.h"
#import "CollectionHeaderView.h"
#import "CameraController.h"

#import "Transforms.h"  // includes DepthImage.h
#import "TaskCtrl.h"
#import "OptionsVC.h"
#import "ExecuteRowView.h"
#import "Layout.h"
#import "HelpVC.h"
#import "Defines.h"

// last settings

#define LAST_SOURCE_KEY         @"LastSource"
#define LAST_FILE_SOURCE_KEY    @"LastFileSource"
#define UI_MODE_KEY             @"UIMode"
#define LAST_DEPTH_TRANSFORM    @"LastDepthTransform"

#define BUTTON_FONT_SIZE    20
#define STATS_W             75
#define STATS_FONT_SIZE     18

#define VALUE_W         45
#define VALUE_LIMITS_W  35
#define VALUE_FONT_SIZE 22
#define VALUE_LIMIT_FONT_SIZE   14

#define CURRENT_VALUE_LABEL_TAG     1
#define TRANSFORM_BASE_TAG          100
#define THUMB_LABEL_TAG         98
#define THUMB_IMAGE_TAG         97

#define CONTROL_H   45
#define TRANSFORM_LIST_W    280
#define MIN_TRANSFORM_TABLE_H    140
#define MAX_TRANSFORM_W 1024
#define TABLE_ENTRY_H   40

#define COLLECTION_HEADER_H 50

#define MIN_ACTIVE_TABLE_H    200
#define MIN_ACTIVE_NAME_W   150
#define ACTIVE_TABLE_ENTRY_H   40
#define ACTIVE_SLIDER_H     ACTIVE_TABLE_ENTRY_H

#define SOURCE_THUMB_W  120
#define SOURCE_THUMB_H  SOURCE_THUMB_W
#define SOURCE_BUTTON_FONT_SIZE 24
#define SOURCE_LABEL_H  (2*TABLE_ENTRY_H)
#define SOURCE_CELL_W   SOURCE_THUMB_W
#define SOURCE_CELL_H   (SOURCE_THUMB_H + SOURCE_LABEL_H)

#define TRANS_INSET 2
#define TRANS_BUTTON_FONT_SIZE 12
//#define SOURCE_LABEL_H  (2*TABLE_ENTRY_H)
#define TRANS_CELL_W   120
#define TRANS_CELL_H   80 // + SOURCE_LABEL_H)

#define SECTION_HEADER_ARROW_W  55

#define MIN_SLIDER_W    100
#define MAX_SLIDER_W    200
#define SLIDER_H        50

#define SLIDER_LIMIT_W  20
#define SLIDER_LABEL_W  130
#define SLIDER_VALUE_W  50

#define SLIDER_AREA_W   200

#define STATS_HEADER_INDEX  1   // second section is just stats
#define TRANSFORM_USES_SLIDER(t) ((t).p != UNINITIALIZED_P)

#define RETLO_GREEN [UIColor colorWithRed:0 green:.4 blue:0 alpha:1]
#define NAVY_BLUE   [UIColor colorWithRed:0 green:0 blue:0.5 alpha:1]

#define TRANS_SEC_VIS_ARCHIVE  @"trans_sec_vis.archive"

#define EXECUTE_STATS_TAG   1

#define DEPTH_TABLE_SECTION     0

#define NO_STEP_SELECTED    -1
#define DOING_3D    IS_3D_CAMERA(self->currentSource.sourceType)
#define DISPLAYING_THUMBS   (self->thumbScrollView && self->thumbScrollView.frame.size.width > 0)

typedef enum {
    TransformTable,
    ActiveTable,
} TableTags;

typedef enum {
    sourceCollection,
    transformCollection
} CollectionTags;

typedef enum {
    sampleSource,
    librarySource,
} FixedSources;

typedef enum {
    overlayClear,
    overlayShowing,
    overlayShowingDebug,
} OverlayState;
#define OVERLAY_STATES  (overlayShowingDebug+1)

#define N_FIXED_SOURCES 2

@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   Options *options;

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   TaskGroup *screenTasks; // only one task in this group
@property (nonatomic, strong)   TaskGroup *thumbTasks;
@property (nonatomic, strong)   TaskGroup *externalTasks;   // not yet, only one task in this group
@property (nonatomic, strong)   TaskGroup *hiresTasks;       // not yet, only one task in this group

@property (nonatomic, strong)   Task *screenTask;
@property (nonatomic, strong)   Task *externalTask;

@property (nonatomic, strong)   UIView *containerView;

@property (nonatomic, strong)   UIButton *depthSelectButton;
@property (nonatomic, strong)   UIButton *flipCameraButton;
@property (nonatomic, strong)   UIButton *photoStackButton;

// in containerview:
@property (nonatomic, strong)   UIView *overlayView;        // transparency over transformView
@property (assign)              OverlayState overlayState;
@property (nonatomic, strong)   NSString *overlayDebugStatus;
@property (nonatomic, strong)   UIImageView *transformView; // transformed image
@property (nonatomic, strong)   UIView *thumbArrayView;     // transform thumb selection array
@property (nonatomic, strong)   UIView *executeView;        // active transform list and details

// in executeView
@property (nonatomic, strong)   UIView *executeListView;
@property (assign)              long selectedExecutionStep;         // or NO_TRANSFORM
@property (assign)              long nextInputRow;                  // or NO_TRANSFORM

// in sources view
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;
@property (nonatomic, strong)   InputSource *nextSource;
@property (nonatomic, strong)   InputSource *fileSource;
@property (assign)              int availableCameraCount;

@property (nonatomic, strong)   Transforms *transforms;
@property (assign)              long currentDepthTransformIndex; // or NO_TRANSFORM
@property (assign)              long currentTransformIndex; // or NO_TRANSFORM

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   UILabel *allStatsLabel;

@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;

@property (nonatomic, strong)   UIBarButtonItem *trashBarButton;
@property (nonatomic, strong)   UIBarButtonItem *hiresButton;
@property (nonatomic, strong)   UIBarButtonItem *snapButton;
@property (nonatomic, strong)   UIBarButtonItem *undoBarButton;
@property (nonatomic, strong)   UIButton *plusButton;

@property (nonatomic, strong)   UIBarButtonItem *stopCamera;
@property (nonatomic, strong)   UIBarButtonItem *startCamera;

@property (assign, atomic)      BOOL capturing; // camera is on and getting processed
@property (assign)              BOOL busy;      // transforming is busy, don't start a new one

//@property (assign)              UIImageOrientation imageOrientation;
@property (assign)              UIDeviceOrientation deviceOrientation;
@property (assign)              BOOL isPortrait;
@property (assign)              BOOL isiPhone;
@property (assign)              Layout *layout;

@property (assign)              DisplayOptions displayOption;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthBuf *depthBuf;
@property (assign)              CGSize transformDisplaySize;

@property (nonatomic, strong)   UISegmentedControl *sourceSelectionView;
@property (nonatomic, strong)   NSString *lastFileSourceUsed;

@property (nonatomic, strong)   UISegmentedControl *uiSelection;
@property (nonatomic, strong)   UIScrollView *thumbScrollView;

@end

@implementation MainVC

@synthesize taskCtrl;
@synthesize screenTasks, thumbTasks, externalTasks;
@synthesize hiresTasks;
@synthesize screenTask, externalTask;

@synthesize containerView;
@synthesize depthSelectButton, flipCameraButton, photoStackButton;
@synthesize transformView, overlayView, overlayState;
@synthesize overlayDebugStatus;
@synthesize selectedExecutionStep;
@synthesize thumbArrayView;

@synthesize executeView;
@synthesize plusButton;
@synthesize executeListView;

@synthesize deviceOrientation;
@synthesize isPortrait;
@synthesize isiPhone;

@synthesize sourcesNavVC;
@synthesize options;

@synthesize inputSources, currentSource;
@synthesize currentDepthTransformIndex;
@synthesize currentTransformIndex;
@synthesize nextInputRow;

@synthesize nextSource;
@synthesize availableCameraCount;

@synthesize cameraController;

@synthesize undoBarButton;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize capturing, busy;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize trashBarButton, hiresButton;
@synthesize snapButton;
@synthesize stopCamera, startCamera;
@synthesize displayOption;

@synthesize rowIsCollapsed;
@synthesize depthBuf;

@synthesize transformDisplaySize;
@synthesize sourceSelectionView;
@synthesize lastFileSourceUsed;
@synthesize uiSelection;
@synthesize thumbScrollView;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        currentDepthTransformIndex = NO_TRANSFORM;
        currentTransformIndex = NO_TRANSFORM;
        nextInputRow = NO_INPUT_ROW;
        
        NSString *depthTransformName = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:LAST_DEPTH_TRANSFORM];
        assert(transforms.depthTransformCount > 0);
        currentDepthTransformIndex = 0; // gotta have a default, use first one
        for (int i=0; i < transforms.depthTransformCount; i++) {
            Transform *transform = [transforms.transforms objectAtIndex:i];
            if ([transform.name isEqual:depthTransformName]) {
                currentDepthTransformIndex = i;
                break;
            }
        }
        [self saveDepthTransformName];
        
        taskCtrl = [[TaskCtrl alloc] init];
        taskCtrl.mainVC = self;
        deviceOrientation = UIDeviceOrientationUnknown;
        
        screenTasks = [taskCtrl newTaskGroupNamed:@"Screen"];
        thumbTasks = [taskCtrl newTaskGroupNamed:@"Thumbs"];
        //externalTasks = [taskCtrl newTaskGroupNamed:@"External"];

        transformTotalElapsed = 0;
        transformCount = 0;
        depthBuf = nil;
        thumbScrollView = nil;
        busy = NO;
        options = [[Options alloc] init];
        
        overlayState = overlayShowingDebug;
        overlayDebugStatus = nil;
        
        isiPhone  = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
        
        // set some device defauls
        displayOption = isiPhone ? TightDisplay : BestDisplay;
        
        cameraController = [[CameraController alloc] init];
        cameraController.delegate = self;

        inputSources = [[NSMutableArray alloc] init];
        
        availableCameraCount = 0;
        for (Cameras c=0; c<NCAMERA; c++) {
            if ([cameraController isCameraAvailable:c]) {
                [inputSources addObject:[InputSource sourceForCamera:c]];
                availableCameraCount++;
            }
        }

        [self addFileSource:@"ches-1024.jpeg" label:@"Ches"];
        [self addFileSource:@"PM5644-1920x1080.gif" label:@"Color test pattern"];
#ifdef wrongformat
        [self addFileSource:@"800px-RCA_Indian_Head_test_pattern.jpg"
                      label:@"RCA test pattern"];
#endif
        [self addFileSource:@"ishihara6.jpeg" label:@"Ishibara 6"];
        [self addFileSource:@"cube.jpeg" label:@"Rubix cube"];
        [self addFileSource:@"ishihara8.jpeg" label:@"Ishibara 8"];
        [self addFileSource:@"ishihara25.jpeg" label:@"Ishibara 25"];
        [self addFileSource:@"ishihara45.jpeg" label:@"Ishibara 45"];
        [self addFileSource:@"ishihara56.jpeg" label:@"Ishibara 56"];
        [self addFileSource:@"rainbow.gif" label:@"Rainbow"];
        [self addFileSource:@"hsvrainbow.jpeg" label:@"HSV Rainbow"];
        
//        [self saveUIMode];
        
#ifdef OLD
        NSString *lastUIMode = [[NSUserDefaults standardUserDefaults]
                                     stringForKey:UI_MODE_KEY];
        if (lastUIMode) {
            uiMode = [lastUIMode intValue];
        } else {
            uiMode = oliveUI;
            [self saveUIMode];
        }
#endif
        
        nextSource = nil;
        lastFileSourceUsed = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:LAST_FILE_SOURCE_KEY];
        NSString *lastSourceUsedLabel = [[NSUserDefaults standardUserDefaults]
                                         stringForKey:LAST_SOURCE_KEY];
        if (lastSourceUsedLabel) {
            for (int sourceIndex=0; sourceIndex<inputSources.count; sourceIndex++) {
                nextSource = [inputSources objectAtIndex:sourceIndex];
                if ([lastSourceUsedLabel isEqual:nextSource.label]) {
#ifdef DEBUG_SOURCE
                    NSLog(@"  - initializing source index %d", sourceIndex);
#endif
                    break;
                }
            }
        }
        
//        nextSource = nil; // XXXXX debug
        if (!nextSource)  {   // no known default, pick the first camera
            for (int sourceIndex=0; sourceIndex<NCAMERA; sourceIndex++) {
                if ([cameraController isCameraAvailable:sourceIndex]) {
                    nextSource = [inputSources objectAtIndex:sourceIndex];
#ifdef DEBUG_SOURCE
                    NSLog(@"  - no previous source, using %d, %@", sourceIndex, nextSource.label);
#endif
                    break;
                }
            }
        }
        currentSource = nextSource;
    }
    return self;
}

- (void) saveDepthTransformName {
    assert(currentDepthTransformIndex != NO_TRANSFORM);
    Transform *transform = [transforms.transforms objectAtIndex:currentDepthTransformIndex];
    [[NSUserDefaults standardUserDefaults] setObject:transform.name
                                              forKey:LAST_DEPTH_TRANSFORM];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) saveCurrentSource {
//    NSLog(@"Saving source %d, %@", currentSource.sourceType, currentSource.label);
    assert(currentSource);
    [[NSUserDefaults standardUserDefaults] setObject:currentSource.label
                                              forKey:LAST_SOURCE_KEY];
    if (lastFileSourceUsed)
        [[NSUserDefaults standardUserDefaults] setObject:lastFileSourceUsed
                                                  forKey:LAST_FILE_SOURCE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#ifdef OLD
- (void) saveUIMode {
    NSString *uiStr = [NSString stringWithFormat:@"%d", uiMode];
    [[NSUserDefaults standardUserDefaults] setObject:uiStr
                                              forKey:UI_MODE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
#endif

#ifdef notdef
- (void) loadImageWithURL: (NSURL *)URL {
    NSString *path = [URL absoluteString];
    NSLog(@"startNewDocumentWithURL: LibVC starting document %@", path);
    if (![URL isFileURL]) {
        DownloadVC *dVC = [[DownloadVC alloc]
                           initWithURL: URL
                           from: self];
        dVC.modalPresentationStyle = UIModalPresentationFormSheet;
        dVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:dVC animated:YES completion:NULL];
        // download will call back to processIncomingFile when
        // the download is complete
        return;
    }
    
    NSString *newPath = [URL path];
    [self processIncomingFile:newPath
                suggestedName:[newPath lastPathComponent]
                      fromURL:nil];
}
#endif

#ifdef notdef
- (void) newDisplayMode:(DisplayMode_t) newMode {
    switch (newMode) {
        case fullScreen:
        case alternateScreen:
        case small:
            break;
        case medium:    // iPad size, but never for iPhone
            switch ([UIDevice currentDevice].userInterfaceIdiom) {
                case UIUserInterfaceIdiomMac:
                case UIUserInterfaceIdiomPad:
                    newMode = medium;
                    break;
                case UIUserInterfaceIdiomPhone:
                    newMode = small;
                    break;
                case UIUserInterfaceIdiomUnspecified:
                case UIUserInterfaceIdiomTV:
                case UIUserInterfaceIdiomCarPlay:
                    newMode = medium;
            }
            break;
    }
    displayMode = newMode;
}
#endif

- (void) addCameraSource:(Cameras)c label:(NSString *)l {
    InputSource *is = [[InputSource alloc] init];
    is.sourceType = c;
    is.label = l;
}

- (void) addFileSource:(NSString *)fn label:(NSString *)l {
    InputSource *source = [[InputSource alloc] init];
    source.sourceType = NotACamera;
    source.label = l;
    NSString *file = [@"images/" stringByAppendingPathComponent:fn];
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@""];
    if (!imagePath) {
        source.label = [fn stringByAppendingString:@" missing"];
        NSLog(@"**** Image not found: %@", fn);
    } else {
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (!image) {
            source.label = [fn stringByAppendingString:@" Missing"];
            source.imageSize = CGSizeZero;
        } else {
            source.imagePath = imagePath;
            source.imageSize = image.size;
        }
    }
    [inputSources addObject:source];
}

- (void) deviceRotated {
    deviceOrientation = [[UIDevice currentDevice] orientation];
//    imageOrientation = UIImageOrientationUp; // not needed [self imageOrientationForDeviceOrientation];
#ifdef DEBUG_ORIENTATION
    NSLog(@"device rotated to %@", [CameraController
                                     dumpDeviceOrientationName:deviceOrientation]);
//    NSLog(@" image orientation %@", imageOrientationName[imageOrientation]);
#endif
}

#ifdef NOTUSED
static NSString * const imageOrientationName[] = {
    @"default",            // default orientation
    @"rotate 180",
    @"rotate 90 CCW",
    @"rotate 90 CW",
    @"Up Mirrored",
    @"Down Mirrored",
    @"Left Mirrored",
    @"Right Mirrored"
};
#endif

typedef enum {
    CameraTypeSelect,
    CameraFlip,
    ChooseFile,
} SourceSelectOptions;

#define SOURCE_TYPE_TAG_OFFSET  30

- (void) adjustSourceSelectionView {
    NSString *cameraIconName = IS_3D_CAMERA(currentSource.sourceType) ? @"images/3Dcamera.png" : @"images/2Dcamera.png";
    NSString *cameraIconPath = [[NSBundle mainBundle] pathForResource:cameraIconName ofType:@""];
    UIImage *cameraIconView = [UIImage imageNamed:cameraIconPath];
    
    [sourceSelectionView setImage:cameraIconView forSegmentAtIndex:CameraTypeSelect];
    
    sourceSelectionView.selectedSegmentIndex = ISCAMERA(currentSource.sourceType) ? CameraTypeSelect : ChooseFile;
    [sourceSelectionView setNeedsDisplay];
}

- (UIImage *) barIconFrom:(NSString *) fileName {
    NSString *fullName = [[@"images" stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"png"];
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:fullName ofType:@""];
    assert(imagePath);
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    assert(image);
    float scale = image.size.width / self.navigationController.navigationBar.frame.size.height;
    UIImage *iconImage = [UIImage imageWithCGImage:image.CGImage
                                             scale:scale
                                       orientation:UIImageOrientationUp];
    return iconImage;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
#ifdef DEBUG_LAYOUT
    NSLog(@" ========= viewDidLoad =========");
#endif
    
#define SLIDER_OFF  (-1)
    
    //    UIBarButtonItem *sliderBarButton = [[UIBarButtonItem alloc] initWithCustomView:valueSlider];
    //    [self displayValueSlider:SLIDER_OFF];     // XXX not displayed, for the moment
    
    NSArray *toolBarItems = [[NSArray alloc] initWithObjects:
                             stopCamera,
                             startCamera,
                             nil];
    self.toolbarItems = toolBarItems;
    
    containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor whiteColor];
    containerView.userInteractionEnabled = YES;
    containerView.clipsToBounds = YES;  // this shouldn't be needed
#ifdef DEBUG_LAYOUT
    containerView.layer.borderWidth = 3.0;
    containerView.layer.borderColor = [UIColor greenColor].CGColor;
#endif
    
    transformView = [[UIImageView alloc] init];
    transformView.backgroundColor = NAVY_BLUE;

    overlayView = [[UIView alloc] init];
    overlayView.opaque = NO;
    overlayView.userInteractionEnabled = YES;
    overlayView.backgroundColor = [UIColor clearColor];
    [overlayView addSubview:transformView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTapSceen:)];
    [tap setNumberOfTouchesRequired:1];
    [overlayView addGestureRecognizer:tap];

    UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTwoTapSceen:)];
    [twoTap setNumberOfTouchesRequired:2];
    [overlayView addGestureRecognizer:twoTap];

    UILongPressGestureRecognizer *longPressScreen = [[UILongPressGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didLongPressScreen:)];
    longPressScreen.minimumPressDuration = 1.0;
    [overlayView addGestureRecognizer:longPressScreen];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(doDown:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [overlayView addGestureRecognizer:swipeDown];
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                         action:@selector(doUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [overlayView addGestureRecognizer:swipeUp];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                         action:@selector(doRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [overlayView addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                         action:@selector(doLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [overlayView addGestureRecognizer:swipeLeft];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc]
                                       initWithTarget:self
                                       action:@selector(doPinch:)];
    [overlayView addGestureRecognizer:pinch];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                       initWithTarget:self
                                       action:@selector(doPan:)];
    [overlayView addGestureRecognizer:pan];

    [containerView addSubview:transformView];
    [containerView addSubview:overlayView];
    [containerView bringSubviewToFront:overlayView];
    
    Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    screenTask = [screenTasks createTaskForTargetImageView:transformView
                                                     named:@"main"
                                            depthTransform:depthTransform];

    executeView = [[UIView alloc]
                   initWithFrame: CGRectMake(LATER, LATER,
                                             EXECUTE_VIEW_W,
                                             EXECUTE_MAX_VISIBLE_VIEW_H)];
    executeView.opaque = NO;
    executeView.backgroundColor = [UIColor clearColor];
    executeView.userInteractionEnabled = YES;
    
    executeListView =  [[UIView alloc]
                    initWithFrame:CGRectMake(0, 0,
                                             EXECUTE_LIST_W, LATER)];
    executeListView.backgroundColor = [UIColor clearColor];
    executeListView.opaque = NO;
    executeListView.layer.borderWidth = EXECUTE_BORDER_W;
    executeListView.layer.cornerRadius = 10;
    executeListView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    [executeView addSubview:executeListView];
    
    [self initExecList];
    
    [containerView addSubview:executeView];
    
    thumbScrollView = [[UIScrollView alloc] init];
    thumbScrollView.pagingEnabled = NO;
    //thumbScrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    thumbScrollView.showsVerticalScrollIndicator = YES;
    thumbScrollView.userInteractionEnabled = YES;
    thumbScrollView.exclusiveTouch = NO;
    thumbScrollView.bounces = NO;
    thumbScrollView.delaysContentTouches = YES;
    thumbScrollView.canCancelContentTouches = YES;
    thumbScrollView.delegate = self;
    thumbScrollView.scrollEnabled = YES;
    [containerView addSubview:thumbScrollView];
    
    thumbArrayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [thumbScrollView addSubview:thumbArrayView];
    [containerView addSubview:thumbScrollView];

    [self createThumbArray];    // animate to correct positions later
    
    [self.view layoutIfNeeded];
    [self.view addSubview:containerView];
    
    //externalTask = [externalTasks createTaskForTargetImage:transformImageView.image];
    
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) configureNavBar {
    CGFloat navBarH = self.navigationController.navigationBar.frame.size.height;

//    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UISegmentedControl class]]] setNumberOfLines:0];
    
    depthSelectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    depthSelectButton.frame = CGRectMake(0, 0, navBarH+SEP, navBarH);
    [depthSelectButton setImage: [self barIconFrom:@"3Dcamera"] forState:UIControlStateNormal];
    [depthSelectButton setImage: [self barIconFrom:@"2Dcamera"] forState:UIControlStateSelected];
    [depthSelectButton addTarget:self
                           action:@selector(chooseDepth:)
                 forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *depthBarButton = [[UIBarButtonItem alloc]
                                        initWithCustomView:depthSelectButton];
    
    flipCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    flipCameraButton.frame = CGRectMake(0, 0, navBarH+SEP, navBarH);
    [flipCameraButton setImage:[self barIconFrom:@"flipcamera"] forState:UIControlStateNormal];
    [flipCameraButton addTarget:self
                           action:@selector(flipCamera:)
                 forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *flipBarButton = [[UIBarButtonItem alloc]
                                      initWithCustomView:flipCameraButton];

    photoStackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    photoStackButton.frame = CGRectMake(0, 0, navBarH+SEP, navBarH);
    [photoStackButton setImage:[self barIconFrom:@"photostack"]
                      forState:UIControlStateNormal];
    [photoStackButton addTarget:self
                           action:@selector(selectPhoto:)
                 forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *photoBarButton = [[UIBarButtonItem alloc]
                                        initWithCustomView:photoStackButton];
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                   target:nil action:nil];
    fixedSpace.width = 10;
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];

    UIBarButtonItem *otherMenuButton = [[UIBarButtonItem alloc]
                                        initWithTitle:@"⋯"
                                        style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(goSelectOptions:)];
    [otherMenuButton setTitleTextAttributes:@{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:navBarH],
        //NSBaselineOffsetAttributeName: @-3
    } forState:UIControlStateNormal];

    trashBarButton = [[UIBarButtonItem alloc]
                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                   target:self
                   action:@selector(doRemoveAllTransforms)];
    
    hiresButton = [[UIBarButtonItem alloc]
                   initWithTitle:@"Hi res" style:UIBarButtonItemStylePlain
                   target:self action:@selector(doToggleHires:)];

    UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                   target:self
                                   action:@selector(doSave)];
    
    UIBarButtonItem *undoBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemUndo
                                      target:self
                                      action:@selector(doRemoveLastTransform)];
    
    self.navigationItem.leftBarButtonItems = [[NSArray alloc] initWithObjects:
                                              depthBarButton,
                                              flexibleSpace,
                                              flipBarButton,
                                              flexibleSpace,
                                              photoBarButton,
                                              nil];

    if (!isiPhone || !isPortrait)
        self.title = @"Digital Darkroom";
#ifdef NOTDEF
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:
                                               otherMenuButton,
                                               flexibleSpace,
                                               saveBarButton,
                                               flexibleSpace,
                                               undoBarButton,
                                               flexibleSpace,
                                               trashBarButton,
                                               nil];
#endif
    
    UIBarButtonItem *helpButton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"?"
                                   style:UIBarButtonItemStylePlain
                                   target:self
                                   action:@selector(doHelp:)];
    
    self.navigationItem.rightBarButtonItem = helpButton;
    
    
    CGFloat toolBarH = self.navigationController.toolbar.frame.size.height;
    plusButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    plusButton.frame = CGRectMake(0, 0, toolBarH+SEP, toolBarH);
    [plusButton setAttributedTitle:[[NSAttributedString alloc] initWithString:BIGPLUS attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:toolBarH
                                               weight:UIFontWeightUltraLight],
        //NSBaselineOffsetAttributeName: @-3
    }] forState:UIControlStateNormal];
    [plusButton setAttributedTitle:[[NSAttributedString alloc] initWithString:BIGPLUS attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:toolBarH
                                               weight:UIFontWeightHeavy],
        //NSBaselineOffsetAttributeName: @-3
    }] forState:UIControlStateSelected];
    [plusButton addTarget:self action:@selector(toggleStackMode:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *plusBarButton = [[UIBarButtonItem alloc] initWithCustomView:plusButton];
    [self configureStackMode];

    self.toolbarItems = [[NSArray alloc] initWithObjects:
                         plusBarButton,
                         flexibleSpace,
                         saveBarButton,
                         fixedSpace,
                         undoBarButton,
                         fixedSpace,
                         trashBarButton,
                         fixedSpace,
                         otherMenuButton,
                         nil];
}


#ifdef NOTDEF
UIImage *oneFrameImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle]
                                                           pathForResource:@"images/1sq.png"
                                                           ofType:@""]];
UIImage *threeFrameImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle]
                                                             pathForResource:@"images/3sq.png"
                                                             ofType:@""]];
stackingButton.userInteractionEnabled = YES;
// maybe not so clear using these
[stackingButton setBackgroundImage:oneFrameImage forState:UIControlStateNormal];
[stackingButton setBackgroundImage:threeFrameImage forState:UIControlStateSelected];
#endif

- (void) createThumbArray {
//    NSLog(@"--- createThumbArray");

    UITapGestureRecognizer *touch;
    for (size_t i=0; i<transforms.depthTransformCount; i++) {
        Transform *transform = [transforms.transforms objectAtIndex:i];
        UIView *thumbView = [self makeThumbForTransform:transform];
        [self adjustThumbView:thumbView selected:NO];
        touch = [[UITapGestureRecognizer alloc]
                 initWithTarget:self
                 action:@selector(doTapDepthVis:)];
        [thumbView addGestureRecognizer:touch];
        
         // a depth thumb always has only its own depth transform in the task transform list.
        UIImageView *imageView = [thumbView viewWithTag:THUMB_IMAGE_TAG];
        Task *task = [thumbTasks createTaskForTargetImageView:imageView
                                                        named:transform.name
                                               depthTransform:transform];
        // these thumbs display their own transform of the depth input only, and don't
        // change when they are used.
        task.depthLocked = YES;

        thumbView.tag = TRANSFORM_BASE_TAG + i;     // encode the index of this transform
        [thumbArrayView addSubview:thumbView];
    }
    
    Transform *depthTransform = [transforms.transforms objectAtIndex:currentDepthTransformIndex];
    for (size_t i=transforms.depthTransformCount; i<transforms.transforms.count; i++) {
        Transform *transform = [transforms.transforms objectAtIndex:i];
        UIView *thumbView = [self makeThumbForTransform:transform];
        
        touch = [[UITapGestureRecognizer alloc]
                 initWithTarget:self
                 action:@selector(doTapThumb:)];
        touch.enabled = YES;
        [thumbView addGestureRecognizer:touch];
        thumbView.tag = TRANSFORM_BASE_TAG + i;     // encode the index of this transform
        [thumbArrayView addSubview:thumbView];
        
        UIImageView *imageView = [thumbView viewWithTag:THUMB_IMAGE_TAG];
        Task *task = [thumbTasks createTaskForTargetImageView:imageView
                                                        named:transform.name
                                               depthTransform:depthTransform];
        [task appendTransformToTask:transform];
   }
}

- (UIView *) makeThumbForTransform:(Transform *)transform {
    UIView *newThumbView = [[UIView alloc] initWithFrame:CGRectMake(LATER, LATER, LATER, LATER)];
    newThumbView.layer.cornerRadius = 1.0;
    [thumbArrayView addSubview:newThumbView];

    UILabel *transformLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    transformLabel.tag = THUMB_LABEL_TAG;
    transformLabel.textAlignment = NSTextAlignmentCenter;
    transformLabel.adjustsFontSizeToFitWidth = YES;
    transformLabel.numberOfLines = 0;
    //transformLabel.backgroundColor = [UIColor whiteColor];
    transformLabel.lineBreakMode = NSLineBreakByWordWrapping;
    transformLabel.text = transform.name;
    transformLabel.textColor = [UIColor blackColor];
    transformLabel.font = [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE];
#ifdef NOTDEF
    transformLabel.attributedText = [[NSMutableAttributedString alloc]
                                     initWithString:transform.name
                                     attributes:labelAttributes];
    CGSize labelSize =  [transformLabel.text
                         boundingRectWithSize:f.size
                         options:NSStringDrawingUsesLineFragmentOrigin
                         attributes:@{
                             NSFontAttributeName : transformLabel.font,
                             NSShadowAttributeName: shadow
                         }
                         context:nil].size;
    transformLabel.contentMode = NSLayoutAttributeTop;
#endif
    transformLabel.opaque = NO;
    transformLabel.layer.borderWidth = 0.5;
    [newThumbView addSubview:transformLabel];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(LATER, LATER, LATER, LATER)];
    imageView.tag = THUMB_IMAGE_TAG;
    imageView.backgroundColor = [UIColor whiteColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.opaque = YES;
    [newThumbView addSubview:imageView];   // empty placeholder at the moment
    
    return newThumbView;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
#ifdef DEBUG_LAYOUT
    NSLog(@"--------- viewwillappear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#endif
    [self reconfigure];
}

- (void) viewWillTransitionToSize:(CGSize)newSize
        withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
#ifdef DEBUG_LAYOUT
    NSLog(@"********* viewWillTransitionToSize: %.0f x %.0f", newSize.width, newSize.height);
#endif
    [self reconfigure];
}

- (void) reconfigure {
    isPortrait = UIDeviceOrientationIsPortrait(deviceOrientation) ||
    UIDeviceOrientationIsFlat(deviceOrientation);
#ifdef DEBUG_LAYOUT
    NSLog(@"== reconfigure for %@,    option %@",
          isPortrait ? @"port" : @"land",
          displayOptionNames[displayOption]);
#endif
    [self configureNavBar];
    
    taskCtrl.reconfiguring++;
    [taskCtrl needLayout];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

#ifdef DEBUG_LAYOUT
    NSLog(@"--------- viewDidAppear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#endif
    
    frameCount = depthCount = droppedCount = busyCount = 0;
    [self.view setNeedsDisplay];
    
#define TICK_INTERVAL   0.1
    statsTimer = [NSTimer scheduledTimerWithTimeInterval:TICK_INTERVAL
                                                  target:self
                                                selector:@selector(doTick:)
                                                userInfo:NULL
                                                 repeats:YES];
    lastTime = [NSDate now];
}

- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"********* viewWillDisappear *********");
    
    [super viewWillDisappear:animated];
    if (currentSource && ISCAMERA(currentSource.sourceType)) {
        [self cameraOn:NO];
    }
}

- (Layout *) chooseLayoutFrom:(NSArray *)availableFormats scaleOK:(BOOL)scaleOK {
//    NSLog(@"  %4.0f x %4.0f   ar %4.2f   chooseFormatForSize",
//          availableSize.width, availableSize.height,
//          availableSize.width/availableSize.height);
//    NSLog(@"  ----");
    
    int bestScore = REJECT_SCORE;
    Layout *bestLayout = nil;
    
    for (AVCaptureDeviceFormat *format in availableFormats) {
        Layout *layout = [[Layout alloc] initForPortrait:isPortrait
                                                  iPhone:isiPhone
                                           displayOption:displayOption];
        layout.containerView = containerView;
        layout.thumbCount = transforms.transforms.count;
        
        int score = [layout layoutForFormat:format
                                    scaleOK:scaleOK];
        if (score > bestScore) {
            bestScore = score;
            bestLayout = layout;
        }
    }
    return bestLayout;
}

// this is called when we know the transforms are all Stopped.

- (void) doLayout {
#ifdef DEBUG_LAYOUT
    NSLog(@"doLayout self.view %0.f x %.0f",
          self.view.frame.size.width, self.view.frame.size.height);
#endif
    BOOL adjustSourceInfo = (nextSource != nil);
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.toolbarHidden = self.navigationController.navigationBarHidden;
    self.navigationController.navigationBar.opaque = YES;  // (uiMode == oliveUI);
    self.navigationController.toolbar.opaque = NO;  // (uiMode == oliveUI);

//    multipleViewLabel.frame = stackingModeBarButton.customView.frame;
    
    // set up new source, if needed
    if (nextSource) {
        if (currentSource && ISCAMERA(currentSource.sourceType)) {
            [self cameraOn:NO];
        }
        if (!ISCAMERA(nextSource.sourceType)) {
            lastFileSourceUsed = nextSource.label;
        }
        currentSource = nextSource;
        nextSource = nil;
        [self saveCurrentSource];
        [self changeStepInExecuteList:DEPTH_STEP];  // reflect possibly-new depth state
    }
    assert(currentSource);
    
    
    // We have several image sizes to consider and process:
    //
    // currentSource.imageSize  is the size of the source image.  For images from files, it is
    //      just the available size.  For cameras, we can adjust it by changing the capture parameters,
    //      adjusting for the largest image we need, shown below.
    //
    // Each taskgroup runs an image through zero or more translation chains.  The task group shares
    //      a common transform size and caches certain common transform processing computations.
    //      The results of each task chain in a taskgroup goes to a UIImage of a certain size, based
    //      on the size of the resulting image:
    //
    // - the displayed transformed image size (computed just below) is based on layout considerations
    // for the device screen size and orientation.
    //      size in screenTasks.transformSize
    //
    // - thumbnail outputs all must fit in THUMB_W x SOURCE_THUMB_H
    //      size in thumbTasks.transformSize
    //
    // - the external window image size, if implemented and connected.
    //      size in externalTasks.transformSize, if externalTasks exists
    //
    // - If "hidef" is selected, the full image possible is captured, transformed, and made available
    // for saving.
    //      size in hiresTasks.transformSize, iff hiresTasks exists
    //
    // - I suppose there will be a video capture option some day.  That would be another target.
    
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController selectCamera:currentSource.sourceType];
        [cameraController setupSessionForOrientation:deviceOrientation];
    } else {
        NSLog(@"    file source size: %.0f x %.0f",
              currentSource.imageSize.width, currentSource.imageSize.height);
    }

    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [containerView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor].active = YES;
    [containerView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor].active = YES;
    [containerView.topAnchor constraintEqualToAnchor:guide.topAnchor].active = YES;
    [containerView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor].active = YES;
    
    UIWindow *window = self.view.window; // UIApplication.sharedApplication.keyWindow;
    CGFloat topPadding = window.safeAreaInsets.top;
    CGFloat bottomPadding = window.safeAreaInsets.bottom;
    CGFloat leftPadding = window.safeAreaInsets.left;
    CGFloat rightPadding = window.safeAreaInsets.right;
    
#ifdef DEBUG_LAYOUT
    NSLog(@"padding, L, R, T, B: %0.f %0.f %0.f %0.f",
          leftPadding, rightPadding, topPadding, bottomPadding);
#endif
    
    CGRect f = self.view.frame;
    f.origin.x = leftPadding; // + SEP;
    f.origin.y = BELOW(self.navigationController.navigationBar.frame) + SEP;
    f.size.height -= f.origin.y + bottomPadding;
    f.size.width = self.view.frame.size.width - rightPadding - f.origin.x;
    containerView.frame = f;
#ifdef DEBUG_LAYOUT
    NSLog(@"     containerview: %.0f,%.0f  %.0f x %.0f",
          f.origin.x, f.origin.y, f.size.width, f.size.height);
#endif
    
#ifdef NOTDEF
    if (availableSize.width < EXECUTE_VIEW_W) {
        NSLog(@"*** execute view is too wide to fit by %.0f",
              EXECUTE_VIEW_W - availableSize.width);
    }
#endif

    Layout *layout;
    if (ISCAMERA(currentSource.sourceType)) {   // select camera setting for available area
        NSArray *availableFormats = [cameraController formatsForSelectedCameraNeeding3D:DOING_3D];
        layout = [self chooseLayoutFrom:availableFormats
                                scaleOK:NO];
#ifdef DEBUG_LAYOUT
        NSLog(@" score for best unscaled layout: %.1f", layout.score);
#endif
        if (!layout || layout.score < 0) {
            layout = [self chooseLayoutFrom:availableFormats
                                    scaleOK:YES];
#ifdef DEBUG_LAYOUT
            NSLog(@"   score for best scaled layout: %.1f", layout.score);
#endif
        }
        if (!layout)
            NSLog(@"!!! could not layout camera image");
        else
            [cameraController setupCameraWithFormat:layout.format];
    } else {
        layout = [[Layout alloc] initForPortrait:isPortrait
                                          iPhone:isiPhone
                                   displayOption:displayOption];
        layout.containerView = containerView;
        layout.thumbCount = transforms.transforms.count;
        
        int score = [layout layoutForSize:currentSource.imageSize scaleOK:NO];
        if (score == REJECT_SCORE)
            score = [layout layoutForSize:currentSource.imageSize scaleOK:YES];
        if (score == REJECT_SCORE)
            NSLog(@"!!! could not layout image");
    }

    overlayView.frame = layout.displayRect;
    overlayDebugStatus = layout.status;
    transformView.frame = overlayView.frame;
    executeView.frame = layout.executeRect;
    thumbScrollView.frame = layout.thumbArrayRect;
    thumbArrayView.frame = CGRectMake(0, 0,
                                      thumbScrollView.frame.size.width,
                                      thumbScrollView.frame.size.height);

#ifdef DEBUG_LAYOUT
    NSLog(@"layout selected:");

    NSLog(@"        capture:               %4.0f x %4.0f\tscale=%.1f score=%.0f",
          layout.captureSize.width, layout.captureSize.height,
          layout.scale, layout.score);

    NSLog(@"      container:               %4.0f x %4.0f",
          containerView.frame.size.width,
          containerView.frame.size.height);

    NSLog(@" transform size:               %4.0f x %4.0f",
          layout.transformSize.width,
          layout.transformSize.height);

    NSLog(@"           view:  %4.0f, %4.0f   %4.0f x %4.0f",
          transformView.frame.origin.x,
          transformView.frame.origin.y,
          transformView.frame.size.width,
          transformView.frame.size.height);

    NSLog(@"        execute:  %4.0f, %4.0f   %4.0f x %4.0f",
          executeView.frame.origin.x,
          executeView.frame.origin.y,
          executeView.frame.size.width,
          executeView.frame.size.height);

    NSLog(@"         thumbs:  %4.0f, %4.0f   %4.0f x %4.0f",
          thumbScrollView.frame.origin.x,
          thumbScrollView.frame.origin.y,
          thumbScrollView.frame.size.width,
          thumbScrollView.frame.size.height);

    overlayView.layer.borderColor = [UIColor redColor].CGColor;
//    transformView.layer.borderWidth = 5.0;
    executeView.layer.borderColor = [UIColor blackColor].CGColor;
    executeView.layer.borderWidth = 2.0;
    executeView.layer.cornerRadius = 5;
    executeView.clipsToBounds = YES;
    thumbScrollView.layer.borderColor = [UIColor blueColor].CGColor;
//    thumbScrollView.layer.borderWidth = 5.0;
#endif
    
    // layout.transformSize is what the tasks get to run.  They
    // then display (possibly scaled) onto transformView.
    
    [screenTasks configureGroupForSize: layout.transformSize];
    //    [externalTask configureForSize: processingSize];

    if (DISPLAYING_THUMBS) { // if we are displaying thumbs...
        [UIView animateWithDuration:0.5 animations:^(void) {
            // move views to where they need to be now.
            [self placeThumbsForLayout: layout];
        }];
    }
    
    if (adjustSourceInfo) {
        [self adjustCameraButtons];
    }
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformImageView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;
    
    [taskCtrl layoutCompleted];

    if (ISCAMERA(currentSource.sourceType)) {
        [self cameraOn:YES];
    } else {
        [self doTransformsOn:[UIImage imageWithContentsOfFile:currentSource.imagePath]];
    }
    [self adjustExecuteDisplay];
    [self updateOverlayView];
}

#define DEBUG_FONT_SIZE 16

-(void) updateOverlayView {
    // start fresh
    [overlayView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    UILabel *overlayDebug = nil;
    
    switch (overlayState) {
        case overlayClear:
            break;
        case overlayShowingDebug:
            overlayDebug = [[UILabel alloc] init];
            overlayDebug.text = overlayDebugStatus;
            overlayDebug.textColor = [UIColor whiteColor];
            overlayDebug.opaque = NO;
            overlayDebug.numberOfLines = 0;
            overlayDebug.lineBreakMode = NSLineBreakByWordWrapping;
            overlayDebug.font = [UIFont boldSystemFontOfSize:DEBUG_FONT_SIZE];
            overlayDebug.backgroundColor = [UIColor colorWithWhite:0.4 alpha:0.2];
            [overlayView addSubview:overlayDebug];
            // FALLTHROUGH
        case overlayShowing: {
            if (overlayDebug) {
                CGRect f;
                f.size = overlayView.frame.size;
                f.origin = CGPointMake(5, 5);
                overlayDebug.frame = f;
                [overlayDebug sizeToFit];
                [overlayView bringSubviewToFront:overlayDebug];
            }
            break;
        }
    }
    [overlayView setNeedsDisplay];
}

- (void) adjustCameraButtons {
//    NSLog(@"****** adjustCameraButtons ******");
    trashBarButton.enabled = screenTask.transformList.count > DEPTH_TRANSFORM;
    undoBarButton.enabled = screenTask.transformList.count > DEPTH_TRANSFORM;
    stopCamera.enabled = capturing;
    startCamera.enabled = !stopCamera.enabled;
}

// A thumb can have three states:
//  - disabled
//  - enabled, but not selected
//  - selected
//
// This information is stored in the touch and view properties of each thumb.

CGRect imageRect;
CGRect nextButtonFrame;
BOOL atStartOfRow;
CGFloat topOfNonDepthArray = 0;

// layout the 3d transforms.  If the input isn't a 3D source, these will always be
// scrolled off the top of the view.

- (void) placeThumbsForLayout:(Layout *)layout {
    nextButtonFrame = layout.firstThumbRect;
    [thumbTasks configureGroupForSize:layout.thumbImageRect.size];

    atStartOfRow = YES;

    // Run through all the transforms, computing the corresponding thumb sizes and
    // positions for the current situation. Skip to a new row after depth transforms,
    // which are first.
    
    CGFloat thumbsH = 0;
    
    for (size_t i=0; i<transforms.transforms.count; i++) {   // position depth transforms
        Transform *transform = [transforms.transforms objectAtIndex:i];
        UIView *thumb = [thumbArrayView viewWithTag:TRANSFORM_BASE_TAG + i];
        assert(thumb);  // gotta be there
        
        if (transform.type == DepthVis) {
            [self adjustThumbView:thumb selected:(i == currentDepthTransformIndex && DOING_3D)];
            if (!DOING_3D) {
                // just push them off to where they are not visible
                CGRect f = nextButtonFrame;
                f.origin = transformView.frame.origin; // hide it
                thumb.frame = f;
                //              thumb.hidden = YES;
                continue;
            }
        } else {    // regular transform
            [self adjustThumbView:thumb selected:i == currentTransformIndex];
        }
        
        thumb.frame = nextButtonFrame;
        thumb.hidden = NO;
        thumb.userInteractionEnabled = YES;

        UIImageView *imageView = [thumb viewWithTag:THUMB_IMAGE_TAG];
        imageView.frame = layout.thumbImageRect;
        UILabel *label = [thumb viewWithTag:THUMB_LABEL_TAG];
        label.frame = CGRectMake(0, BELOW(imageView.frame), thumb.frame.size.width, OLIVE_LABEL_H);

        atStartOfRow = NO;
        thumbsH = BELOW(thumb.frame) + 2*SEP;
        
        // next thumb position.  On a new line, if this is the end of the depthvis
        if (DOING_3D && i == transforms.depthTransformCount - 1) {  // end of depth transforms
            [self buttonsContinueOnNextRow];
            topOfNonDepthArray = nextButtonFrame.origin.y;
        } else
            [self nextButtonPosition];
    }
    
    SET_VIEW_HEIGHT(thumbArrayView, thumbsH);
    thumbScrollView.contentSize = thumbArrayView.frame.size;
    thumbScrollView.contentOffset = thumbArrayView.frame.origin;
    
    // adjust scroll depending on depth buttons
    if (DOING_3D)
        [thumbScrollView setContentOffset:CGPointMake(0, 0) animated:YES];
    else
        [thumbScrollView setContentOffset:CGPointMake(0, topOfNonDepthArray) animated:YES];
}

- (void) nextButtonPosition {
    CGRect f = nextButtonFrame;
    if (RIGHT(f) + SEP + f.size.width > thumbArrayView.frame.size.width) {   // on to next line
        [self buttonsContinueOnNextRow];
    } else {
        f.origin.x = RIGHT(f) + SEP;
        nextButtonFrame = f;
        atStartOfRow = NO;
    }
}

- (void) buttonsContinueOnNextRow {
    if (atStartOfRow)
        return;
    CGRect f = nextButtonFrame;
    f.origin.y = BELOW(f) + SEP;
        f.origin.x = 0;
    nextButtonFrame = f;
    atStartOfRow = YES;
}

// select a new depth visualization.
- (IBAction) doTapDepthVis:(UITapGestureRecognizer *)recognizer {
    UIView *newView = recognizer.view;
    long newTransformIndex = newView.tag - TRANSFORM_BASE_TAG;
    assert(newTransformIndex >= 0 && newTransformIndex < transforms.transforms.count);
    if (newTransformIndex == currentDepthTransformIndex)
        return;

    UIView *oldSelectedDepthThumb = [thumbArrayView viewWithTag:currentDepthTransformIndex + TRANSFORM_BASE_TAG];
    [self adjustThumbView:oldSelectedDepthThumb selected:NO];
    [self adjustThumbView:newView selected:YES];

    currentDepthTransformIndex = newTransformIndex;
    Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    assert(depthTransform.type == DepthVis);
    [self saveDepthTransformName];

    [screenTasks configureGroupWithNewDepthTransform:depthTransform];
    if (DISPLAYING_THUMBS)
        [thumbTasks configureGroupWithNewDepthTransform:depthTransform];
    
    [self changeStepInExecuteList:DEPTH_STEP];
}

- (IBAction) doTapThumb:(UITapGestureRecognizer *)recognizer {
#ifdef OLD
    @synchronized (transforms.sequence) {
        [transforms.sequence removeAllObjects];
        transforms.sequenceChanged = YES;
    }
#endif
    UIView *tappedThumb = [recognizer view];
    [self transformThumbTapped: tappedThumb];
}


#define EXECUTE_ROW_COUNT   (self->executeListView.subviews.count)

size_t nextExecuteAppendStep;
size_t topExecuteStepDisplayed;

- (void) transformThumbTapped: (UIView *) tappedThumb {
    long tappedTransformIndex = tappedThumb.tag - TRANSFORM_BASE_TAG;
    Transform *tappedTransform = [transforms.transforms objectAtIndex:tappedTransformIndex];
    NSLog(@" === transformThumbTapped, transform index %ld, %@", tappedTransformIndex, tappedTransform.name);
    [self dumpRows:@"transformThumbTapped"];

    ExecuteRowView *nextAppendRowView = [executeListView
                                       viewWithTag:nextExecuteAppendStep + EXECUTE_STEP_TAG];
    assert(nextAppendRowView);
    
    if (IS_EMPTY_ROW(nextAppendRowView)) {
        [screenTask appendTransformToTask:tappedTransform];
        [screenTask updateRowView:nextAppendRowView depthActive:DOING_3D];
        if (options.stackingMode) { // append an empty cell for next transform
            nextExecuteAppendStep = [self appendEmptyRow];
        }
    } else {
        // this can only be in non-stacking mode, where we are clearing
        // or replacing the current transform
        assert(!options.stackingMode);
        Transform *lastTransform = [screenTask.transformList lastObject];
        UIView *oldThumb = [self thumbViewForTransform:lastTransform];
        [self adjustThumbView:oldThumb selected:NO];
        [screenTask removeLastTransform];
        if ([tappedTransform.name isEqual:lastTransform.name]) {
            // current transform just retapped.  Empty it, and done
            [nextAppendRowView makeRowEmpty];
        } else {
            [screenTask appendTransformToTask:tappedTransform];
            [screenTask updateRowView:nextAppendRowView depthActive:DOING_3D];
        }
    }
    [self adjustExecuteDisplay];
}

- (UIView *) thumbViewForTransform:(Transform *) transform {
    long transformIndex = transform.arrayIndex;
    return [thumbArrayView viewWithTag:transformIndex + TRANSFORM_BASE_TAG];
}

#ifdef DONOTUSE
- (CGFloat) rowViewYForStep:(size_t) step {
    if (step == 0 && !DOING_3D)
        return -1.0;
    long screenRowIndex = executeListView.subviews.count - step - 1;
    CGFloat y = EXECUTE_BORDER_W + screenRowIndex*EXECUTE_ROW_H;
    NSLog(@"-------->  yForStep %ld:  %.0f", step, y);
    return y;
}
#endif

- (size_t) appendRowView:(ExecuteRowView *) rowView {
    size_t step = rowView.step;
    assert(step == executeListView.subviews.count);
    [executeListView addSubview:rowView];
    [rowView setNeedsDisplay];
    [executeListView setNeedsDisplay];
//XXXXX    [self changeExecuteLengthBy: 1];
// y is set later
//    SET_VIEW_Y(rowView, [self rowViewYForStep:step]);
    return step;
}

- (size_t) appendEmptyRow {
    ExecuteRowView *emptyRow = [[ExecuteRowView alloc]
                                initForStep:executeListView.subviews.count];
    [emptyRow makeRowEmpty];
    return [self appendRowView:emptyRow];
}

- (void) initExecList {
    ExecuteRowView *rowView = [screenTask listViewForStep:DEPTH_STEP
                                                      depthActive:DOING_3D];
    [self appendRowView: rowView];
    nextExecuteAppendStep = [self appendEmptyRow];
}

// change the size and position of the execute list as needed
- (void) adjustExecuteDisplay {
    long rows = EXECUTE_ROW_COUNT;
#ifdef DEBUG_EXECUTE
    [self dumpRows:@"adjustExecuteDisplay"];
    NSLog(@"adjustExecuteDisplay, rows=%ld oldheight=%.0f",
          rows, executeListView.frame.size.height);
#endif

    [UIView animateWithDuration:0.5 animations:^(void) {
        // Adjust the row positions
        CGFloat y = EXECUTE_BORDER_W;
        for (int step = 0; step < rows; step++) {
            ExecuteRowView *rowView = [self->executeListView viewWithTag:step + EXECUTE_STEP_TAG];
            rowView.hidden = step == DEPTH_STEP && !DOING_3D;
            if (rowView.hidden) {
                continue;
            }
            SET_VIEW_Y(rowView, y);
            if (step == nextExecuteAppendStep)
                rowView.statusChar.text = BIGPLUS;
            else
                rowView.statusChar.text = @"";
            rowView.backgroundColor= [UIColor colorWithWhite:1.0 alpha:0.3];
            [rowView setNeedsDisplay];
            y += EXECUTE_ROW_H;
        }
        SET_VIEW_HEIGHT(self->executeListView, y + EXECUTE_BORDER_W);
        self->executeListView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        [self->executeListView setNeedsDisplay];
        [self dumpRows:@"adjustExecuteDisplay adjusted"];

    }];
}

- (void) appendStepToExecuteList:(long) step {
    ExecuteRowView *rowView = [[ExecuteRowView alloc] initForStep:step];
    [screenTask updateRowView:rowView depthActive:DOING_3D];
    [executeListView addSubview:rowView];
    [self adjustExecuteDisplay];
}

- (void) changeStepInExecuteList:(long) step {
    ExecuteRowView *rowView = [executeListView viewWithTag:EXECUTE_STEP_TAG + step];
    assert(rowView);
    [screenTask updateRowView:rowView depthActive:DOING_3D];
    [self adjustExecuteDisplay];
}

- (void) dumpRows:(NSString *)label {
#ifdef DEBUG_EXECUTE
    NSLog(@" -- dumpRows  %@, %ld", label, EXECUTE_ROW_COUNT);
    for (long step=0; step<EXECUTE_ROW_COUNT; step++) {
        ExecuteRowView *rowView = [executeListView viewWithTag:EXECUTE_STEP_TAG + step];
        NSLog(@"    %2ld  tag:%2ld @ %2.0f  %@", step, (long)rowView.tag,
              rowView.frame.origin.y,
              IS_EMPTY_ROW(rowView) ? @"*empty*": rowView.name.text );
    }
#endif
}

- (IBAction) toggleStackMode:(UIButton *)sender {
    options.stackingMode = !options.stackingMode;
    NSLog(@" === stacking mode now %d", options.stackingMode);
    [options save];
    [self configureStackMode];
}

- (void) adjustThumbView:(UIView *) thumb selected:(BOOL)selected {
    UILabel *label = [thumb viewWithTag:THUMB_LABEL_TAG];
    if (selected) {
        label.font = [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE];
        thumb.layer.borderWidth = 5.0;
        currentTransformIndex = thumb.tag - TRANSFORM_BASE_TAG;
    } else {
        label.font = [UIFont systemFontOfSize:OLIVE_FONT_SIZE];
        thumb.layer.borderWidth = 1.0;
    }
    [label setNeedsDisplay];
    [thumb setNeedsDisplay];
}

- (void) updateThumbImage:(size_t) index to:(UIImage *)newImage {
    if (!thumbArrayView)
        return;
    UIImageView *v = [thumbArrayView viewWithTag:index + TRANSFORM_BASE_TAG];
    if (!v) {
        NSLog(@"olive view not found: %zu", index);
        return;
    }
}

#ifdef OLD
    [fuitable.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    // show the list in reverse order
    CGRect f = executeControlView.frame;
    f.origin = CGPointMake(0, f.size.height);
    f.size = CGSizeMake(f.size.width, EXECUTE_LABEL_H);
    for (int i=0; i<EXECUTE_SHOWN && i < screenTask.transformList.count; i++) {
        Transform *transform = screenTask.transformList[screenTask.transformList.count - 1 - i];
        UILabel *label = [[UILabel alloc] initWithFrame:f];
        label.text = [NSString stringWithFormat:@"%@", transform.name];
        label.textAlignment = NSTextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.font = [UIFont systemFontOfSize:EXECUTE_LABEL_FONT];
        label.opaque = YES;
        [executeControlView addSubview:label];
        f.origin.y -= f.size.height;
    }
    [executeControlView setNeedsDisplay];

- (void) displayValueSlider: (int) executeIndex {
    if (executeIndex == SLIDER_OFF) {
        valueSlider.hidden = YES;
        return;
    }
    SET_VIEW_WIDTH(valueSlider, MAX_SLIDER_W);
    valueSlider.hidden = NO;
    valueSlider.tag = executeIndex;
    
    @synchronized (transforms.sequence) {
        Transform *transform = [transforms.sequence objectAtIndex:executeIndex];
        valueSlider.minimumValue = transform.low;
        valueSlider.maximumValue = transform.high;
        valueSlider.value = transform.value;
        if (valueSlider.value != transform.value) {
            NSLog(@"  new value is %.0f", valueSlider.value);
            transform.value = valueSlider.value;
            transform.newValue = YES;
        }
    }
    [self transformCurrentImage];   // XXX if video capturing is off, we still need to update.  check
}

- (IBAction) moveValueSlider:(UISlider *)slider {
    long executeIndex = slider.tag;
    @synchronized (transforms.sequence) {
        Transform *transform = [transforms.sequence objectAtIndex:executeIndex];
        if (slider.value != transform.value) {
            NSLog(@"  new value is %.0f", slider.value);
            transform.value = slider.value;
            transform.newValue = YES;
        }
    }
    [self transformCurrentImage];   // XXX if video capturing is off, we still need to update.  check
}
#endif

- (void) cameraOn:(BOOL) on {
    capturing = on;
    if (capturing)
        [cameraController startCamera];
    else
        [cameraController stopCamera];
    [self adjustCameraButtons];
}

- (void) updateStats: (float) fps
         depthPerSec:(float) depthps
       droppedPerSec:(float)dps
          busyPerSec:(float)bps
        transformAve:(double) tams {
    NSString *debug = transforms.debugTransforms ? @"(debug)  " : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        if (fps) {
            self->allStatsLabel.text = [NSString stringWithFormat:@"%@  %.0f ms   ", debug, tams];
        } else {
            self->allStatsLabel.text = [NSString stringWithFormat:@"%@  ---   x", debug];
        }
        [self->allStatsLabel setNeedsDisplay];
    });
}

- (IBAction) didTapSceen:(UITapGestureRecognizer *)recognizer {
    BOOL hide = !self.navigationController.navigationBarHidden;
    [self.navigationController setNavigationBarHidden:hide animated:YES];
    [self.navigationController setToolbarHidden:hide animated:YES];
    return;
    
    overlayState++;
    if (overlayState == OVERLAY_STATES) {
        overlayState = overlayClear;
    }
    [self updateOverlayView];
}

// freeze/unfreeze video
- (IBAction) didTwoTapSceen:(UITapGestureRecognizer *)recognizer {
    
//    BOOL isHidden = self.navigationController.navigationBarHidden;
//    [self.navigationController setNavigationBarHidden:!isHidden animated:YES];
//    [self.navigationController setToolbarHidden:!isHidden animated:YES];
    capturing = !capturing;
    if (capturing) {
        if (![cameraController isCameraOn]) {
            [cameraController startCamera];
        }
    } else {
        if ([cameraController isCameraOn]) {
            [cameraController stopCamera];
        }
    }
    // XXXX show frozen on screen
}


- (IBAction) doHelp:(UIBarButtonItem *)button {
    NSURL *helpURL = [NSURL fileURLWithPath:
                      [[NSBundle mainBundle] pathForResource:@"help.html" ofType:@""]];
    assert(helpURL);
    HelpVC *hvc = [[HelpVC alloc] initWithURL:helpURL];
    hvc.modalPresentationStyle = UIModalPresentationPopover;
    hvc.preferredContentSize = CGSizeMake(320, 300);
    
    UIPopoverPresentationController *popvc = hvc.popoverPresentationController;
    popvc.sourceRect = CGRectMake(100, 100, 100, 100);
    popvc.delegate = self;
    popvc.sourceView = hvc.view;
    popvc.barButtonItem = button;
    [self presentViewController:hvc animated:YES completion:nil];
}

- (IBAction) didLongPressScreen:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan)
        return;
    options.reticle = !options.reticle;
    [options save];
}

- (IBAction) didLongPressExecute:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan)
        return;
    options.executeDebug = !options.executeDebug;
    [options save];
    NSLog(@" debugging execute: %d", options.executeDebug);
    [self adjustExecuteDisplay];
}

- (IBAction) doPan:(UIPanGestureRecognizer *)recognizer { // adjust value of selected transform
}

- (IBAction) doSave {
    NSLog(@"saving");   // XXX need full image for a save
    UIImageWriteToSavedPhotosAlbum(transformView.image, nil, nil, nil);
    
    // UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIWindow* keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene* wScene in [UIApplication sharedApplication].connectedScenes) {
            if (wScene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = wScene.windows.firstObject;
                break;
            }
        }
    }
    CGRect rect = [keyWindow bounds];
    UIGraphicsBeginImageContextWithOptions(rect.size,YES,0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [keyWindow.layer renderInContext:context];
    UIImage *capturedScreen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();    //UIImageWriteToSavedPhotosAlbum([UIScreen.image, nil, nil, nil);
    UIImageWriteToSavedPhotosAlbum(capturedScreen, nil, nil, nil);
}

- (IBAction) doPinch:(UIPinchGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded)
        return;
    // crude processing, better when more displays are implemented
    if (recognizer.scale < 1.0 && displayOption == LargestImageDisplay) {
        displayOption = BestDisplay;
        [self reconfigure];
    } else if (recognizer.scale > 1.0 && displayOption == BestDisplay) {
        displayOption = LargestImageDisplay;
        [self reconfigure];
    }
}

- (IBAction) doLeft:(UISwipeGestureRecognizer *)recognizer {
    [self doSave];
}

- (IBAction) doRight:(UISwipeGestureRecognizer *)recognizer {
    NSLog(@"did swipe video right");
    [self doRemoveLastTransform];
}

- (CGFloat) scaleToFitSize:(CGSize)srcSize toSize:(CGSize)size {
    float xScale = size.width/srcSize.width;
    float yScale = size.height/srcSize.height;
    return MIN(xScale,yScale);
}

- (CGSize) fitSize:(CGSize)srcSize toSize:(CGSize)size {
    CGFloat scale = [self scaleToFitSize:srcSize toSize:size];
    CGSize scaledSize;
    scaledSize.width = scale*srcSize.width;
    scaledSize.height = scale*srcSize.height;
    return scaledSize;
}

- (UIImage *)fitImage:(UIImage *)image
               toSize:(CGSize)size
             centered:(BOOL) centered {
    CGRect scaledRect;
    scaledRect.size = [self fitSize:image.size toSize:size];
    scaledRect.origin = CGPointZero;
    if (centered) {
        scaledRect.origin.x = (size.width - scaledRect.size.width)/2.0;
        scaledRect.origin.y = (size.height - scaledRect.size.height)/2.0;
    }
    
    NSLog(@"scaled image at %.0f,%.0f  size: %.0fx%.0f",
          scaledRect.origin.x, scaledRect.origin.y,
          scaledRect.size.width, scaledRect.size.height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        NSLog(@"inconceivable, no image context");
        return nil;
    }
    CGContextSetFillColorWithColor(ctx, [UIColor clearColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    //CGContextConcatCTM(ctx, CGAffineTransformMakeScale(scale, scale));
    [image drawInRect:scaledRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    //NSLog(@"new image size: %.0fx%.0f", newImage.size.width, newImage.size.height);
    UIGraphicsEndImageContext();
    return newImage;
}

#ifdef NOTNEEDED
// Apparently, this translation is not needed
- (UIImageOrientation) imageOrientationForDeviceOrientation {
    UIImageOrientation orient;
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationFaceUp:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationFaceDown:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationUnknown:
            orient = UIImageOrientationUp;
            break;
        default:
            NSLog(@"***** Inconceivable video orientation: %ld",
                  (long)deviceOrientation);
            orient = UIImageOrientationUpMirrored;
    }
    
    return orient;
}
#endif

#ifdef XXXX
if captureDevice.position == AVCaptureDevicePosition.back {
    if let image = context.createCGImage(ciImage, from: imageRect) {
        return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .right)
    }
        }

if captureDevice.position == AVCaptureDevicePosition.front {
    if let image = context.createCGImage(ciImage, from: imageRect) {
        return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .leftMirrored)
        
    }
        }

#endif

- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output
        didOutputDepthData:(AVDepthData *)rawDepthData
        timestamp:(CMTime)timestamp connection:(AVCaptureConnection *)connection {
    if (!capturing)
        return;
    if (taskCtrl.reconfiguring)
        return;
    depthCount++;
    if (busy) {
        busyCount++;
        return;
    }
    busy = YES;
    
    AVDepthData *depthData;
    if (rawDepthData.depthDataType != kCVPixelFormatType_DepthFloat32)
        depthData = [rawDepthData depthDataByConvertingToDepthDataType:kCVPixelFormatType_DepthFloat32];
    else
        depthData = rawDepthData;
            
    CVPixelBufferRef pixelBufferRef = depthData.depthDataMap;
    size_t width = CVPixelBufferGetWidth(pixelBufferRef);
    size_t height = CVPixelBufferGetHeight(pixelBufferRef);
    if (!depthBuf || depthBuf.w != width || depthBuf.h != height) {
        depthBuf = [[DepthBuf alloc]
                    initWithSize: CGSizeMake(width, height)];
    }
    
    CVPixelBufferLockBaseAddress(pixelBufferRef,  kCVPixelBufferLock_ReadOnly);
    assert(sizeof(Distance) == sizeof(float));
    float *capturedDepthBuffer = (float *)CVPixelBufferGetBaseAddress(pixelBufferRef);
    memcpy(depthBuf.db, capturedDepthBuffer, width*height*sizeof(Distance));
    CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->screenTasks executeTasksWithDepthBuf:self->depthBuf];
        if (DISPLAYING_THUMBS)
            [self->thumbTasks executeTasksWithDepthBuf:self->depthBuf];
        self->busy = NO;
    });
}

- (void) doTransformsOn:(UIImage *)sourceImage {
    [screenTasks executeTasksWithImage:sourceImage];

    if (DISPLAYING_THUMBS)
        [thumbTasks executeTasksWithImage:sourceImage];
}
    
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    if (!capturing)
        return;
    if (taskCtrl.layoutNeeded)
        return;
    if (taskCtrl.reconfiguring)
        return;
    if (busy) {
        busyCount++;
        return;
    }
    busy = YES;
    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self doTransformsOn:capturedImage];
        self->busy = NO;
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
       fromConnection:(nonnull AVCaptureConnection *)connection {
    //NSLog(@"dropped");
    droppedCount++;
}

- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output
       didDropDepthData:(AVDepthData *)depthData
              timestamp:(CMTime)timestamp
             connection:(AVCaptureConnection *)connection
                 reason:(AVCaptureOutputDataDroppedReason)reason {
    //NSLog(@"depth data dropped: %ld", (long)reason);
    droppedCount++;
}

#ifdef DEBUG_TASK_CONFIGURATION
BOOL haveOrientation = NO;
UIImageOrientation lastOrientation;
#endif

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
#ifdef DEBUG_TASK_CONFIGURATION
    if (!haveOrientation) {
        lastOrientation = orientation;
        NSLog(@" OOOO first capture orientation is %ld", (long)orientation);
        haveOrientation = YES;
    } else if (orientation != lastOrientation) {
        NSLog(@" OOOO new capture orientation: %ld", (long)orientation);
        lastOrientation = orientation;
    }
#endif
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"image  orientation %@", width > height ? @"panoramic" : @"portrait");
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, BITMAP_OPTS);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:(CGFloat)1.0
                                   orientation:UIImageOrientationUp];
    CGImageRelease(quartzImage);
    return image;
}

- (IBAction) didPressVideo:(UILongPressGestureRecognizer *)recognizer {
    NSLog(@" === didPressVideo");
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        NSLog(@"video long press");
    }
}

- (IBAction) doRemoveAllTransforms {
    NSLog(@" === doRemoveAllTransforms");
    [screenTasks removeAllTransforms];
    [executeListView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self initExecList];
    [self adjustExecuteDisplay];
}

- (IBAction) doToggleHires:(UIBarButtonItem *)button {
    options.needHires = !options.needHires;
    NSLog(@" === high res now %d", options.needHires);
    [options save];
    button.style = options.needHires ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
}

- (void) doTick:(NSTimer *)sender {
    if (taskCtrl.layoutNeeded)
        [taskCtrl layoutIfReady];
    
    for (ExecuteRowView *rowView in executeListView.subviews) {
        [screenTask updateRowView:rowView depthActive:DOING_3D];
    }

    
#ifdef NOTYET
    NSDate *now = [NSDate now];
    NSTimeInterval elapsed = [now timeIntervalSinceDate:lastTime];
    lastTime = now;
    float transformAveTime;
    if (transformCount)
        transformAveTime = 1000.0 *(transformTotalElapsed/transformCount);
    else
        transformAveTime = NAN;
    for (size_t i=0; i<transforms.sequence.count; i++) {
        Transform *t = [transforms.sequence objectAtIndex:i];
        NSString *ave;
        if (transformAveTime)
            ave = [NSString stringWithFormat:@"%.0f ms   ", 1000.0 * t.elapsedProcessingTime/transformCount];
        else
            ave = @"---   ";
        t.elapsedProcessingTime = 0.0;
        UITableViewCell *cell = [executeTableVC.tableView
                                 cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        UILabel *stepStatsLabel = (UILabel *)[cell viewWithTag:EXECUTE_STATS_TAG];
        stepStatsLabel.text = ave;
        [stepStatsLabel setNeedsDisplay];
    }
    
    [self updateStats: frameCount/elapsed
          depthPerSec:depthCount/elapsed
        droppedPerSec:droppedCount/elapsed
           busyPerSec:busyCount/elapsed
         transformAve:transformAveTime];
    frameCount = depthCount = droppedCount = busyCount = 0;
    transformCount = transformTotalElapsed = 0;
#endif
}

- (IBAction) doRemoveLastTransform {
    [self dumpRows:@"doRemoveLastTransform"];
    int lastStep = (int)screenTask.transformList.count - 1;
    if (lastStep == DEPTH_STEP)
        return; // never delete this step
    ExecuteRowView *rowView = [executeListView viewWithTag:lastStep + EXECUTE_STEP_TAG];
    [rowView removeFromSuperview];
    nextExecuteAppendStep = [screenTask removeLastTransform];
    [self adjustExecuteDisplay];
    [self dumpRows:@"doRemoveLastTransform after"];
    // appendstep needs adjustment for plus case XXXXX
// XXXXX    [self adjustBarButtons];    // disable undo if input = 1 and row is empty
}

- (void) configureStackMode {
    ExecuteRowView *inputRowView = [self->executeListView
                                       viewWithTag:nextExecuteAppendStep + EXECUTE_STEP_TAG];
    assert(inputRowView);
    
    plusButton.selected = options.stackingMode;
    [plusButton setNeedsDisplay];
    
    if (options.stackingMode) { // initiate stacking mode
         [UIView animateWithDuration:EXECUTE_VIEW_ANIMATION_TIME
                         animations:^(void) {
            // if the current input row view is empty, do nothing, else append an empty row
            // and point to it
            if (!IS_EMPTY_ROW(inputRowView)) {
                nextExecuteAppendStep = [self appendEmptyRow];
            }
            [self adjustExecuteDisplay];
        }];
        return;
    }
    
    // to turn off stacking, remove the empty cell at the end, unless it is
    // DEPTH_STEP + 1, in which case just clear the row.
     [UIView animateWithDuration:EXECUTE_VIEW_ANIMATION_TIME
                     animations:^(void) {
        if (IS_EMPTY_ROW(inputRowView)) {
            if (inputRowView.step > DEPTH_STEP + 1) {
                [inputRowView removeFromSuperview];
                nextExecuteAppendStep--;
            }
        }
        [self adjustExecuteDisplay];
    }];
}

- (IBAction) doUp:(UISwipeGestureRecognizer *)sender {
    NSLog(@"doUp");
    selectedExecutionStep--;
    [self adjustExecuteDisplay];
}

- (IBAction) doDown:(UISwipeGestureRecognizer *)sender {
    NSLog(@"doDown");
    selectedExecutionStep++;
    [self adjustExecuteDisplay];
}

- (IBAction) chooseDepth:(UIButton *)button {
    InputSource *newSource;
    switch (currentSource.sourceType) {
        case FrontCamera:
            newSource = [inputSources objectAtIndex:Front3DCamera];
            break;
        case Front3DCamera:
            newSource = [inputSources objectAtIndex:FrontCamera];
            break;
        case RearCamera:
            newSource = [inputSources objectAtIndex:Rear3DCamera];
            break;
       case Rear3DCamera:
            newSource = [inputSources objectAtIndex:RearCamera];
            break;
       default:
            newSource = [inputSources objectAtIndex:FrontCamera];
    }
    if (![cameraController isCameraAvailable:newSource.sourceType])
        return;
    nextSource = newSource;
    [self reconfigure];
}

- (IBAction) flipCamera:(UIButton *)button {
    switch (currentSource.sourceType) {
        case FrontCamera:
            nextSource = [inputSources objectAtIndex:RearCamera];
            break;
        case RearCamera:
            nextSource = [inputSources objectAtIndex:FrontCamera];
            break;
        case Front3DCamera:
            nextSource = [inputSources objectAtIndex:Rear3DCamera];
            break;
       case Rear3DCamera:
            nextSource = [inputSources objectAtIndex:Front3DCamera];
            break;
       default:
            return;
    }
    [self reconfigure];
}

- (IBAction) selectPhoto:(UIButton *)button {
    depthSelectButton.selected = NO;
    [self doSelecFileSource];
    [self reconfigure];
}

#ifdef OLD
- (IBAction) selectSource:(UISegmentedControl *)sender {
    SourceSelectOptions option = (SourceSelectOptions)sender.selectedSegmentIndex;
    Cameras source = currentSource.sourceType;
    switch (option) {
        case CameraTypeSelect:
            if (!ISCAMERA(source)) { // selecting camera.
                nextSource = [inputSources objectAtIndex:FrontCamera];
                [sourceSelectionView setSelectedSegmentIndex:CameraTypeSelect];
                break;
            }
            // FALLTHROUGH
        case CameraFlip:
            if (!ISCAMERA(source))
                return;
            if (source == FrontCamera)
                nextSource = [inputSources objectAtIndex:RearCamera];
            else
                nextSource = [inputSources objectAtIndex:FrontCamera];
            break;
        case ChooseFile:
            // not yet available
            [self doSelecFileSource];
            [sourceSelectionView setSelectedSegmentIndex:ChooseFile]
            ;;
    }
    [self reconfigure];
}
#endif

#ifdef OLD
- (IBAction) selectUI:(UISegmentedControl *)sender {
    uiMode = (UIMode_t)sender.selectedSegmentIndex;
    for (UIView *subView in [containerView subviews])
        [subView removeFromSuperview];  // clear the slate
    [self.view setNeedsLayout];
    [self saveUIMode];
}
#endif

#define SELECTION_CELL_ID  @"fileSelectCell"
#define SELECTION_HEADER_CELL_ID  @"fileSelectHeaderCell"

- (void) doSelecFileSource {
    UIViewController *collectionVC = [[UIViewController alloc] init];
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.sectionInset = UIEdgeInsetsMake(2*INSET, 2*INSET, INSET, 2*INSET);
    flowLayout.itemSize = CGSizeMake(SOURCE_CELL_W, SOURCE_CELL_H);
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    //flowLayout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);
    //flowLayout.minimumInteritemSpacing = 16;
    //flowLayout.minimumLineSpacing = 16;
    flowLayout.headerReferenceSize = CGSizeMake(0, COLLECTION_HEADER_H);
    
    UICollectionView *collectionView = [[UICollectionView alloc]
                                        initWithFrame:self.view.frame
                                        collectionViewLayout:flowLayout];
    collectionView.dataSource = self;
    collectionView.delegate = self;
    collectionView.tag = sourceCollection;
    [collectionView registerClass:[UICollectionViewCell class]
       forCellWithReuseIdentifier:SELECTION_CELL_ID];
    collectionView.backgroundColor = [UIColor whiteColor];
    collectionVC.view = collectionView;
    [collectionView registerClass:[CollectionHeaderView class]
       forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
              withReuseIdentifier:SELECTION_HEADER_CELL_ID];
    sourcesNavVC = [[UINavigationController alloc]
                    initWithRootViewController:collectionVC];
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc]
                                       initWithTitle:@"Dismiss"
                                       style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(dismissSourceVC:)];
    rightBarButton.enabled = YES;
    collectionVC.navigationItem.rightBarButtonItem = rightBarButton;
    collectionVC.title = @"Image and video sources";
    [self presentViewController:sourcesNavVC
                       animated:YES
                     completion:NULL];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return N_FIXED_SOURCES;
}

static NSString * const sourceSectionTitles[] = {
    [sampleSource] = @"    Samples",
    [librarySource] = @"    From library",
};

#ifdef BROKEN
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    assert([kind isEqual:UICollectionElementKindSectionHeader]);
    UICollectionReusableView *headerView = [collectionView
                                            dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                            withReuseIdentifier:SELECTION_HEADER_CELL_ID
                                            forIndexPath:indexPath];
    assert(headerView);
    if (collectionView.tag == sourceCollection) {
        UILabel *sectionTitle = [headerView viewWithTag:SECTION_TITLE_TAG];
        sectionTitle.text = sourceSectionTitles[indexPath.section];
    }
    return headerView;
}
#endif

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    switch ((FixedSources) section) {
        case sampleSource:
            return inputSources.count - NCAMERA;
        case librarySource:
            return 0;   // XXX not yet
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(SOURCE_CELL_W, SOURCE_CELL_H);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell=[collectionView
                                dequeueReusableCellWithReuseIdentifier:SELECTION_CELL_ID
                                forIndexPath:indexPath];
    assert(cell);
    CGRect f = cell.contentView.frame;
    UIView *cellView = [[UIView alloc] initWithFrame:f];
    [cell.contentView addSubview:cellView];
    
    f.size = CGSizeMake(SOURCE_THUMB_W, SOURCE_THUMB_H);
    UIImageView *thumbImageView = [[UIImageView alloc] initWithFrame:f];
    thumbImageView.layer.borderWidth = 1.0;
    thumbImageView.layer.borderColor = [UIColor blackColor].CGColor;
    thumbImageView.layer.cornerRadius = 4.0;
    [cellView addSubview:thumbImageView];
    
    f.origin.y = BELOW(f);
    f.size.height = SOURCE_LABEL_H;
    UILabel *thumbLabel = [[UILabel alloc] initWithFrame:f];
    thumbLabel.lineBreakMode = NSLineBreakByWordWrapping;
    thumbLabel.numberOfLines = 0;
    thumbLabel.adjustsFontSizeToFitWidth = YES;
    thumbLabel.textAlignment = NSTextAlignmentCenter;
    thumbLabel.font = [UIFont
                       systemFontOfSize:SOURCE_BUTTON_FONT_SIZE];
    thumbLabel.textColor = [UIColor blackColor];
    thumbLabel.backgroundColor = [UIColor whiteColor];
    [cellView addSubview:thumbLabel];
    
    switch ((FixedSources)indexPath.section) {
        case sampleSource: {
            InputSource *source = [inputSources objectAtIndex:indexPath.row + NCAMERA];
            thumbLabel.text = source.label;
            UIImage *sourceImage = [UIImage imageWithContentsOfFile:source.imagePath];
            thumbImageView.image = [self fitImage:sourceImage
                                           toSize:thumbImageView.frame.size
                                         centered:YES];
            break;
        }
        case librarySource:
            ; // XXX stub
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    switch ((FixedSources)indexPath.section) {
        case sampleSource:
            nextSource = [inputSources objectAtIndex:indexPath.row + NCAMERA];
            break;
        case librarySource:
            ; // XXX stub
    }
    [sourcesNavVC dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"    ***** collectionView setneedslayout");
    [self reconfigure];
}

- (IBAction) dismissSourceVC:(UIBarButtonItem *)sender {
    [sourcesNavVC dismissViewControllerAnimated:YES
                                     completion:NULL];
}

#define CELL_H  44

- (IBAction)goSelectOptions:(UIBarButtonItem *)barButton {
    OptionsVC *oVC = [[OptionsVC alloc] initWithOptions:options];
    CGRect f = oVC.view.frame;
    f.origin.y = 44;
    f.origin.x = containerView.frame.size.width - f.size.width;
    f.size.height = 5*CELL_H;
    oVC.view.frame = f;
    
    [self presentViewController:oVC animated:YES completion:^{
        [self doLayout];
    }];
}

#ifdef OLD

#ifdef NOTDEF
    // The chosen capture size may be bigger than the display size. Figure out
    // the final display size.  The transform stuff will have to scale the
    // incoming stuff, hopefully efficiently, if needed.
    // At present, we don't expand small captures, just use them.

#ifdef DEBUG_LAYOUT
    NSLog(@" >>> captureSize %.0f x %.0f  AR %4.2f",
          captureSize.width, captureSize.height,
          captureSize.width/captureSize.height);
#endif

    CGSize displaySize;
    if (captureSize.width <= bestSize.width && captureSize.height <= bestSize.height)
        displaySize = captureSize;
    else {
        double captureAR = captureSize.width/captureSize.height;
        double finalAR = bestSize.width/bestSize.height;
        CGFloat scale;
        if (finalAR > captureAR)
            scale = bestSize.height / captureSize.height;
        else
            scale = bestSize.width / captureSize.width;
        NSLog(@"  ** scaling by %.2f", scale);
        displaySize = CGSizeMake(round(captureSize.width*scale), round(captureSize.height*scale));
    }
#endif
    
    if (layout.displaySize.height < 288) {
        NSLog(@"  ** needs minimum height of 288 for iPhone ***");
        NSLog(@" >>>  got %.1f x %.1f ***", layout.displaySize.width, layout.displaySize.height);
    }
    
    assert(layout.displaySize.height > 0);
    if (layout.displaySize.width < EXECUTE_VIEW_W) {
        NSLog(@"!!! execute view will not fit by %.0f",
              EXECUTE_VIEW_W - layout.displaySize.width);
    }
    
#ifdef NOTDEF
    f.origin.y = 0;
    if (layout.thumbsUnderneath) { // transform view spans the width of the screen
        f.size.width = containerView.frame.size.width;
        f.size.height = layout.displaySize.height + LATER;
    } else {
        f.size.height = containerView.frame.size.height;
        f.size.width = layout.displaySize.width;
    }
    transformView.frame = layout.displayRect;
    
    if (layout.thumbsUnderneath) { // center view in container view
        f.origin.x = (transformView.frame.size.width - layout.displaySize.width)/2.0;
        f.origin.y = 0;
    } else      // upper left hand corner
        f.origin = CGPointZero;
    f.size = layout.displaySize;
#endif

#ifdef DEBUG_LAYOUT
    NSLog(@" >>> displaySize %.0f x %.0f  AR %4.2f",
          layout.displaySize.width, layout.displaySize.height,
          layout.displaySize.width/layout.displaySize.height);
#endif

#ifdef FORIPHONENOTYET
    CGFloat execSpace = containerView.frame.size.height - BELOW(transformImageView.frame);
    assert(execSpace >= EXECUTE_MIN_BELOW_SPACE);
    if (thumbsUnderneath) {
        execSpace = EXECUTE_MIN_ROWS_BELOW;
        // XXX maybe we don't need to squeeze here so hard sometimes.
    }
    
    f = executeView.frame;
    f.origin.y = BELOW(transformImageView.frame);
    if (layout.thumbsUnderneath) { // center in the whole container width
        f.origin.x = (transformView.frame.size.width - f.size.width)/2.0;
        f.size.width = transformView.frame.size.width;
        if (isiPhone) { // not much room below image
            f.size.height = EXECUTE_MIN_BELOW_H;
        } else {
            f.size.height = EXECUTE_BEST_BELOW_H;
        }
    } else {    // thumbs on the right, center this under the image
        f.origin.x = (transformImageView.frame.size.width - executeView.frame.size.width)/2.0;
    }
#endif
    
    SET_VIEW_HEIGHT(transformView, BELOW(executeView.frame));
    [transformView bringSubviewToFront:executeView];
    transformView.clipsToBounds = YES;

f = containerView.frame;
f.origin = CGPointMake(0, transformView.frame.origin.y);
f.size.height -= f.origin.y;
if (layout.thumbsUnderneath) {
    f.origin.x = 0;
    f.origin.y = BELOW(transformView.frame);
    f.size = layout.thumbArraySize;
} else {
    f.origin.x = RIGHT(transformView.frame) + SEP;
    f.origin.y = transformView.frame.origin.y;
}
f.size = layout.thumbArraySize;
thumbScrollView.frame = f;
f.origin = CGPointZero;
thumbArrayView.frame = f;   // the final may be higher

#endif

@end
