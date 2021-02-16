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

#define EXECUTE_TEXT_FONT_SIZE  20
#define EXECUTE_TEXT_MIN_LINES   3// 5   // number of total lines shown on screen (not yet)
#define EXECUTE_H ((EXECUTE_TEXT_FONT_SIZE + 4) * EXECUTE_TEXT_MIN_LINES)

#define OLIVE_W     80
#define OLIVE_FONT_SIZE 14
#define OLIVE_LABEL_H   (2.0*(OLIVE_FONT_SIZE+4))

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
#define DOING_3D    IS_3D_CAMERA(currentSource.sourceType)

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

// in containerview:
@property (nonatomic, strong)   UIView *transformView;  // area reserved for transform display and related
@property (nonatomic, strong)   UIView *thumbArrayView;

// in transformview
@property (nonatomic, strong)   UIImageView *transformImageView;    // transformed image

@property (nonatomic, strong)   UIView *executeView;                 // the whole execute list area
@property (nonatomic, strong)   UIScrollView *executeScrollView;
@property (nonatomic, strong)   UIView *executeListView;
@property (nonatomic, strong)   NSMutableArray *executeListViews;   // array of views in executeListView
@property (assign)              long selectedExecutionStep;         // or NO_TRANSFORM

// in sources view
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;


@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;
@property (nonatomic, strong)   InputSource *nextSource;
@property (nonatomic, strong)   InputSource *fileSource;
@property (assign)              int availableCameraCount;

@property (nonatomic, strong)   Transforms *transforms;
@property (assign)              long currentDepthTransformIndex; // or NO_TRANSFORM

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
@property (nonatomic, strong)   UIButton *stackingButton;

@property (nonatomic, strong)   UIBarButtonItem *stopCamera;
@property (nonatomic, strong)   UIBarButtonItem *startCamera;

@property (assign, atomic)      BOOL capturing;         // camera is on and getting processed
@property (assign)              BOOL busy;              // transforming is busy, don't start a new one

@property (assign)              UIImageOrientation imageOrientation;
@property (assign)              UIMode_t uiMode;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthBuf *depthBuf;
@property (assign)              CGSize transformDisplaySize;

@property (nonatomic, strong)   UISegmentedControl *sourceSelection;
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
@synthesize transformView;
@synthesize transformImageView;
@synthesize selectedExecutionStep;
@synthesize thumbArrayView;

@synthesize executeView;
@synthesize stackingButton;
@synthesize executeScrollView;
@synthesize executeListView;
@synthesize executeListViews;

@synthesize sourcesNavVC;
@synthesize options;

@synthesize inputSources, currentSource;
@synthesize currentDepthTransformIndex;

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
@synthesize imageOrientation;
@synthesize uiMode;

@synthesize rowIsCollapsed;
@synthesize depthBuf;

@synthesize transformDisplaySize;
@synthesize sourceSelection;
@synthesize lastFileSourceUsed;
@synthesize uiSelection;
@synthesize thumbScrollView;
@synthesize currentDeviceOrientation;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        currentDepthTransformIndex = NO_TRANSFORM;
        
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
        currentDeviceOrientation = UIDeviceOrientationUnknown;
        
        screenTasks = [taskCtrl newTaskGroupNamed:@"Screen"];
        thumbTasks = [taskCtrl newTaskGroupNamed:@"Thumbs"];
        //externalTasks = [taskCtrl newTaskGroupNamed:@"External"];

        transformTotalElapsed = 0;
        transformCount = 0;
        depthBuf = nil;
        thumbScrollView = nil;
        busy = NO;
        options = [[Options alloc] init];
        
        cameraController = [[CameraController alloc] init];
        cameraController.delegate = self;

        inputSources = [[NSMutableArray alloc] init];
        executeListViews = [[NSMutableArray alloc] init];
        
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
        
        uiMode = oliveUI;
        [self saveUIMode];
        
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
        
        nextSource = nil; // XXXXX debug
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
        if (DOING_3D)
            selectedExecutionStep = 0;  // depth is selected, even if not available
        else
            selectedExecutionStep = NO_STEP_SELECTED;
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

- (void) saveUIMode {
    NSString *uiStr = [NSString stringWithFormat:@"%d", uiMode];
    [[NSUserDefaults standardUserDefaults] setObject:uiStr
                                              forKey:UI_MODE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

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
#ifdef DEBUG_LAYOUT
    NSLog(@"device rotated to %@", [CameraController
                                     dumpDeviceOrientationName:currentDeviceOrientation]);
#endif
    currentDeviceOrientation = [[UIDevice currentDevice] orientation];
//    [self reconfigure];
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
#ifdef DEBUG_LAYOUT
    NSLog(@" ========= viewDidLoad =========");
#endif
    
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UISegmentedControl class]]] setNumberOfLines:0];
    NSMutableArray *cameraNames = [[NSMutableArray alloc] init];
    for (Cameras c=0; c<NCAMERA; c++) {
        NSString *name = [InputSource cameraNameFor:c];
        [cameraNames addObject:name];
    }

    NSMutableArray *sourceNames = [[NSMutableArray alloc] init];
    for (int cam=0; cam<availableCameraCount; cam++) {
        InputSource *s = [inputSources objectAtIndex:cam];
        [sourceNames addObject:s.label];
    }
    [sourceNames addObject:@"File"];
    
    CGFloat navBarH = self.navigationController.navigationBar.frame.size.height;
    
    sourceSelection = [[UISegmentedControl alloc] initWithItems:sourceNames];
    sourceSelection.frame = CGRectMake(0, 0, 100, navBarH);
    [sourceSelection addTarget:self action:@selector(selectSource:)
              forControlEvents: UIControlEventValueChanged];
    sourceSelection.momentary = NO;
    if (ISCAMERA(currentSource.sourceType))
        sourceSelection.selectedSegmentIndex = currentSource.sourceType;
    else
        sourceSelection.selectedSegmentIndex = sourceSelection.numberOfSegments - 1;    // file segment

    UIBarButtonItem *leftBarItem = [[UIBarButtonItem alloc]
                                    initWithCustomView:sourceSelection];
    self.navigationItem.leftBarButtonItem = leftBarItem;
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                   target:nil action:nil];
    fixedSpace.width = 20;
    
//    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
//                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
//                                      target:nil action:nil];
    
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
                   action:@selector(doRemoveAllTransforms:)];
    
    hiresButton = [[UIBarButtonItem alloc]
                   initWithTitle:@"Hi res" style:UIBarButtonItemStylePlain
                   target:self action:@selector(doToggleHires:)];

    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                   target:self
                                   action:@selector(doSave)];
    
    UIBarButtonItem *undoBarButton = [[UIBarButtonItem alloc]
                                initWithBarButtonSystemItem:UIBarButtonSystemItemUndo
                                target:self
                                action:@selector(doRemoveLastTransform)];

    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:
                                               otherMenuButton,
                                               fixedSpace,
                                               saveButton,
                                               fixedSpace,
                                               undoBarButton,
                                               fixedSpace,
                                               trashBarButton,
                                               nil];

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
#ifdef DEBUG_LAYOUT
    containerView.layer.borderColor = [UIColor greenColor].CGColor;
#endif
    transformView = [[UIView alloc] init];
    
    [containerView addSubview:transformView];
    
    transformImageView = [[UIImageView alloc] init];
    transformImageView.userInteractionEnabled = YES;
    transformImageView.backgroundColor = NAVY_BLUE;
    UITapGestureRecognizer *touch = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTapSceen:)];
    [touch setNumberOfTouchesRequired:1];
    [transformImageView addGestureRecognizer:touch];
    UILongPressGestureRecognizer *longPressScreen = [[UILongPressGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didLongPressScreen:)];
    longPressScreen.minimumPressDuration = 1.0;
    [transformImageView addGestureRecognizer:longPressScreen];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(doDown:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [transformImageView addGestureRecognizer:swipeDown];
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                         action:@selector(doUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [transformImageView addGestureRecognizer:swipeUp];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                         action:@selector(doRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [transformImageView addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc]
                                           initWithTarget:self
                                         action:@selector(doLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [transformImageView addGestureRecognizer:swipeLeft];

    [transformView addSubview:transformImageView];
    
    Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    screenTask = [screenTasks createTaskForTargetImageView:transformImageView
                                                     named:@"main"
                                            depthTransform:depthTransform];

    executeView = [[UIView alloc]
                   initWithFrame: CGRectMake(0, LATER,
                                             EXECUTE_VIEW_W,
                                             EXECUTE_VIEW_MAX_H)];
    executeView.opaque = NO;
    executeView.backgroundColor = [UIColor clearColor];
    executeScrollView.layer.borderWidth = 0.5;
    executeScrollView.layer.borderColor = [UIColor greenColor].CGColor;
    executeView.userInteractionEnabled = YES;

    stackingButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    stackingButton.frame = CGRectMake(0, EXECUTE_VIEW_MAX_H - EXECUTE_BUTTON_H,
                                      EXECUTE_BUTTON_W, EXECUTE_BUTTON_H);
    stackingButton.autoresizingMask = UIViewAutoresizingNone;
    [stackingButton setTitle:@"Stacking" forState:UIControlStateNormal];
    [stackingButton addTarget:self
                       action:@selector(toggleStackingMode:)
          forControlEvents:UIControlEventTouchUpInside];
    stackingButton.selected = options.stackingMode;
    stackingButton.layer.borderColor = [UIColor blueColor].CGColor;
    stackingButton.layer.cornerRadius = 5.0;
    stackingButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    [executeView addSubview:stackingButton];
    
    executeScrollView = [[UIScrollView alloc]
                         initWithFrame:CGRectMake(RIGHT(stackingButton.frame), 0,
                                                  EXECUTE_LIST_W, EXECUTE_LIST_W)];
    executeScrollView.pagingEnabled = NO;
    executeScrollView.showsVerticalScrollIndicator = NO;
    executeScrollView.userInteractionEnabled = NO;
    executeScrollView.exclusiveTouch = NO;
    executeScrollView.bounces = NO;
    //executeScrollView.delaysContentTouches = YES;
    executeScrollView.canCancelContentTouches = YES;
    executeScrollView.delegate = self;
    executeScrollView.scrollEnabled = YES;
    executeScrollView.backgroundColor = [UIColor clearColor];
    executeScrollView.opaque = YES;
    executeScrollView.scrollEnabled = YES;
    executeScrollView.contentOffset = CGPointZero;
    executeScrollView.layer.borderWidth = 0.5;
    executeScrollView.layer.borderColor = [UIColor blueColor].CGColor;

    executeListView =  [[UIView alloc]
                    initWithFrame:CGRectMake(0, 0, EXECUTE_LIST_W, LATER)];
    executeListView.backgroundColor = [UIColor clearColor];
    executeListView.opaque = NO;
    [executeScrollView addSubview:executeListView];
    
    [executeView addSubview:executeScrollView];
    [transformView addSubview:executeView];
    
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

- (void) createThumbArray {
//    NSLog(@"--- createThumbArray");

    UITapGestureRecognizer *touch;
    for (size_t i=0; i<transforms.depthTransformCount; i++) {
        Transform *transform = [transforms.transforms objectAtIndex:i];
        UIView *thumbView = [self makeThumbForTransform:transform];
        [self adjustThumb:thumbView selected:NO];
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
        [task appendTransform:transform];
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
    taskCtrl.reconfiguring++;
#ifdef DEBUG_LAYOUT
    NSLog(@"********* reconfiguring: %d", taskCtrl.reconfiguring);
#endif
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

// this is called when we know the transforms are all Stopped.

#define MIN_TRANS_TABLE_W 275

BOOL roomForThumbsRightTransformView;
BOOL roomForThumbsUnderTransformView;

- (void) doLayout {
#ifdef DEBUG_LAYOUT
    NSLog(@"****** doLayout self.view %0.f x %.0f",
          self.view.frame.size.width, self.view.frame.size.height);
#endif
    BOOL adjustSourceInfo = (nextSource != nil);
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;  // (uiMode == oliveUI);
    self.navigationController.toolbarHidden = YES;
    
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
    // - thumbnail outputs all must fit in OLIVE_W x SOURCE_THUMB_H
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
        [cameraController setupSessionForCurrentDeviceOrientation];
    } else {
        NSLog(@"    file source size: %.0f x %.0f",
              currentSource.imageSize.width, currentSource.imageSize.height);
    }
    
    imageOrientation = [self imageOrientationForDeviceOrientation];
    
    // not room for title in iphones in portrait mode
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPhone)
        self.title = @"Digital Darkroom";
    else
        self.title = @"";
    
#ifdef DEBUG_ORIENTATION
    NSLog(@"device idiom: %ld", (long)[UIDevice currentDevice].userInterfaceIdiom);
    NSLog(@"device is %@", [CameraController
                                     dumpDeviceOrientationName:currentDeviceOrientation]);
    NSLog(@" is portrait: %d", UIDeviceOrientationIsPortrait(currentDeviceOrientation));
#endif
        
    CGRect f = self.view.frame;
#ifdef DEBUG_LAYOUT
    NSLog(@" **** device view frame:  %.0f x %.0f", f.size.width, f.size.height);
#endif

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
    
    f = self.view.frame;
    f.origin.x = leftPadding + SEP;
    f.origin.y = topPadding + BELOW(self.navigationController.navigationBar.frame) + SEP;
    f.size.height = f.size.height - bottomPadding - f.origin.y;
    f.size.width = self.view.frame.size.width - rightPadding - f.origin.x;
    containerView.frame = f;
#ifdef DEBUG_LAYOUT
    NSLog(@"    containerview frame: %.0f,%.0f  %.0f x %.0f",
          f.origin.x, f.origin.y, f.size.width, f.size.height);
#endif
    
    UIDeviceOrientation devo = [[UIDevice currentDevice] orientation];
    BOOL isPortrait = UIDeviceOrientationIsPortrait(devo);
    CGSize availableSize = containerView.frame.size;
    availableSize.height -= EXECUTE_MIN_BELOW_SPACE;

    switch ([UIDevice currentDevice].userInterfaceIdiom) {
        case UIUserInterfaceIdiomPhone:
            roomForThumbsUnderTransformView = isPortrait;
            roomForThumbsRightTransformView = !roomForThumbsUnderTransformView;
            if (isPortrait) {   // thumbs underneath, not on the right
                availableSize.height -= 2*(SOURCE_THUMB_H + SEP);
            } else {
                availableSize.width -= 2*(SOURCE_THUMB_W + SEP);
            }
            break;
        case UIUserInterfaceIdiomPad:
        case UIUserInterfaceIdiomTV:
        case UIUserInterfaceIdiomCarPlay:
        case UIUserInterfaceIdiomMac:
        case UIUserInterfaceIdiomUnspecified:
            roomForThumbsUnderTransformView = !isPortrait;
            roomForThumbsRightTransformView = roomForThumbsUnderTransformView;
            if (isPortrait) {   // thumbs underneath, not on the right
                availableSize.height -= 2*(SOURCE_THUMB_H + SEP);
            } else {
                availableSize.width -= 2*(SOURCE_THUMB_W + SEP);
            }
            break;
    }
    
#ifdef DEBUG_CAMERA_CAPTURE_SIZE
        NSLog(@"  availableSize target size is %.0f x %.0f", availableSize.width, availableSize.height);
#endif
    CGSize displaySize;
    if (ISCAMERA(currentSource.sourceType)) {   // select camera setting for available area
        displaySize = [cameraController setupCameraForSize:availableSize];
    } else {    // scale image into available area
        CGFloat xScale = currentSource.imageSize.width / availableSize.width;
        CGFloat yScale = currentSource.imageSize.height / availableSize.height;
        CGFloat scale = (xScale < yScale) ? xScale : yScale;
        displaySize = CGSizeMake(availableSize.width*scale, availableSize.height*scale);
    }
    if (displaySize.height < 288) {
        NSLog(@" *** size %.0f x %.0f  needs minimum height of 288 for iPhone ***", availableSize.width, availableSize.height);
        NSLog(@" ***  got %.0f x %.0f ***", displaySize.width, displaySize.height);
    }

#ifdef DEBUG_LAYOUT
    NSLog(@"     display size is %.0f x %.0f", displaySize.width, displaySize.height);
#endif
    
    assert(displaySize.height > 0);     // should never happen, of course
    
    f.origin = CGPointZero;
    f.size = displaySize;
    transformImageView.frame = f;

    CGFloat execSpace = containerView.frame.size.height - BELOW(transformImageView.frame);
    assert(execSpace >= EXECUTE_MIN_BELOW_SPACE);
    if (roomForThumbsUnderTransformView) {
        execSpace = EXECUTE_MIN_ROWS_BELOW;
        // XXX maybe we don't need to squeeze here so hard sometimes.
    }
    
    transformView.frame = CGRectMake(0, 0, transformImageView.frame.size.width, BELOW(transformImageView.frame) + execSpace);
    
    SET_VIEW_Y(executeView, transformView.frame.size.height - EXECUTE_VIEW_MAX_H);
    assert(BELOW(executeView.frame) <= BELOW(transformView.frame));
#ifdef DEBUG_LAYOUT
    executeView.layer.borderWidth = 2.0;
#endif
    transformView.frame = CGRectMake(0, 0, displaySize.width, BELOW(executeView.frame));
    [transformView bringSubviewToFront:executeView];
    transformView.clipsToBounds = YES;
    
#ifdef NOTDEF
    // now, overlap exec view on image, if needed, on small devices
    if (execSpace < EXECUTE_MIN_BELOW_SPACE) {
        SET_VIEW_Y(executeView, BELOW(executeView.frame) - EXECUTE_MIN_BELOW_SPACE);
        SET_VIEW_HEIGHT(executeView, EXECUTE_MIN_BELOW_SPACE)
    }

    // lay out execute view
    SET_VIEW_Y(stackingButton, executeView.frame.size.height - stackingButton.frame.size.height);
#endif

    executeScrollView.contentSize = CGSizeMake(EXECUTE_LIST_W, 0);
    executeScrollView.contentOffset = CGPointMake(0, executeScrollView.frame.size.height);
    [screenTasks configureGroupForSize: displaySize];

    //    [externalTask configureForSize: processingSize];
    
    f = containerView.frame;
    f.origin = CGPointMake(0, transformView.frame.origin.y);
    f.size.height -= f.origin.y;
    if (!roomForThumbsRightTransformView) {
        // all thumbs underneath
        f.origin.x = 0;
        f.origin.y = BELOW(executeView.frame);
        f.size.width = containerView.frame.size.width;
        f.size.height = containerView.frame.size.height - f.origin.y;
    } else if (!roomForThumbsUnderTransformView) {
        // all thumbs to the right
        f.origin.x = RIGHT(transformView.frame) + SEP;
        f.origin.y = transformView.frame.origin.y;
        f.size.width = containerView.frame.size.width - f.origin.x;
        f.size.height = containerView.frame.size.height - f.origin.y;
    } else {
        // both places, let the layout figure the available areas
        CGRect f = self->containerView.frame;
        f.origin = CGPointZero;
    }
    thumbScrollView.frame = f;
    f.origin = CGPointZero;
    thumbArrayView.frame = f;   // the final may be higher

    [UIView animateWithDuration:0.5 animations:^(void) {
        // move views to where they need to be now.
        [self layoutThumbArray];
    }];
    
    [containerView bringSubviewToFront:transformView];
    
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

- (void) layoutThumbArray {
#ifdef DEBUG_LAYOUT
    NSLog(@"--- layoutThumbArray");
#endif
    imageRect = CGRectZero;
    imageRect.size.width = OLIVE_W;
    float aspectRatio = transformImageView.frame.size.width/transformImageView.frame.size.height;
    imageRect.size.height = round(imageRect.size.width / aspectRatio);

    [thumbTasks configureGroupForSize:imageRect.size];
    
    nextButtonFrame.size = CGSizeMake(imageRect.size.width,
                                   imageRect.size.height + OLIVE_LABEL_H);
    if (roomForThumbsRightTransformView && roomForThumbsUnderTransformView) {
        nextButtonFrame.origin.x = RIGHT(transformView.frame) + SEP;
        nextButtonFrame.origin.y = transformView.frame.origin.y;
    } else
        nextButtonFrame.origin = CGPointMake(0, 0);
    
    atStartOfRow = YES;

    // Run through all the transforms, computing the corresponding thumb sizes and
    // positions for the current situation. Skip to a new row after depth transforms,
    // which are first.
    
    CGFloat thumbsH = 0;
    BOOL is3D = DOING_3D;
    
    for (size_t i=0; i<transforms.transforms.count; i++) {   // position depth transforms
        Transform *transform = [transforms.transforms objectAtIndex:i];
        UIView *thumb = [thumbArrayView viewWithTag:TRANSFORM_BASE_TAG + i];
        assert(thumb);  // gotta be there

        if (transform.type == DepthVis) {
            if (i == currentDepthTransformIndex) {
                [self adjustThumb:thumb selected:YES];
            } else
                [self adjustThumb:thumb selected:NO];
            if (!is3D) {
                // just push them off to where they are not visible
                CGRect f = nextButtonFrame;
                f.origin = transformView.frame.origin; // hide it
                thumb.frame = f;
//              thumb.hidden = YES;
                continue;
            }
        } else {    // regular transform
            [self adjustThumb:thumb selected:NO];
        }
        
        thumb.frame = nextButtonFrame;
        thumb.hidden = NO;
        thumb.userInteractionEnabled = YES;

        UIImageView *imageView = [thumb viewWithTag:THUMB_IMAGE_TAG];
        imageView.frame = imageRect;
        UILabel *label = [thumb viewWithTag:THUMB_LABEL_TAG];
        label.frame = CGRectMake(0, BELOW(imageView.frame), thumb.frame.size.width, OLIVE_LABEL_H);

        atStartOfRow = NO;
        thumbsH = BELOW(thumb.frame) + 2*SEP;
        
        // next thumb position.  On a new line, if this is the end of the depthvis
        if (is3D && i == transforms.depthTransformCount - 1) {  // end of depth transforms
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

#ifdef NOTDEF
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"     scrollViewDidScroll content size: %.0f x %.0f",
          scrollView.contentSize.width, scrollView.contentSize.height);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    NSLog(@"     scrollViewWillBeginDragging");
}
#endif

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
    if (roomForThumbsRightTransformView && roomForThumbsUnderTransformView &&
            f.origin.y < BELOW(transformView.frame)) {  // we are still on the right
        f.origin.x = RIGHT(transformView.frame) + SEP;
    } else {
        f.origin.x = 0;
    }
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
    [self adjustThumb:oldSelectedDepthThumb selected:NO];
    [self adjustThumb:newView selected:YES];

    currentDepthTransformIndex = newTransformIndex;
    Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    assert(depthTransform.type == DepthVis);
    [self saveDepthTransformName];

    [screenTasks configureGroupWithNewDepthTransform:depthTransform];
    [thumbTasks configureGroupWithNewDepthTransform:depthTransform];
    
    [self adjustExecuteDisplay];
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

- (void) transformThumbTapped: (UIView *) tappedThumb {
    long tappedTransformIndex = tappedThumb.tag - TRANSFORM_BASE_TAG;
    Transform *tappedTransform = [transforms.transforms objectAtIndex:tappedTransformIndex];
    
    if (options.stackingMode || selectedExecutionStep == NO_STEP_SELECTED) {
        selectedExecutionStep = [screenTask appendTransform:tappedTransform];
        [self adjustExecuteDisplay];
    } else {
        assert(screenTask.transformList.count > 1);
        Transform *currentTransform = [screenTask.transformList objectAtIndex:1
                                       
                                       ];
        if ([currentTransform.name isEqual:tappedTransform.name]) {
            // retapped current transform.  Get rid of it, and we are done
            [self deleteLastScreenTransform];
            selectedExecutionStep = NO_STEP_SELECTED;
            [self adjustExecuteDisplay];
        } else {    // switched to a new one
            [self deleteLastScreenTransform];
            [screenTask appendTransform:tappedTransform];
            [self adjustExecuteDisplay];
        }
    }
}

// return YES if we deleted something
- (BOOL) deleteLastScreenTransform {
    assert(screenTask.transformList.count);
    if (screenTask.transformList.count == DEPTH_TRANSFORM+1)
        // We don't delete the depth transform
        return NO;
    
    NSLog(@"  %lu", (unsigned long)screenTask.transformList.count);
    [screenTasks removeLastTransform];
    return YES;
}

- (void) adjustThumb:(UIView *) thumb selected:(BOOL)selected {
    UILabel *label = [thumb viewWithTag:THUMB_LABEL_TAG];
    if (selected) {
        label.font = [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE];
        thumb.layer.borderWidth = 5.0;
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

- (IBAction) didPanSceen:(UIPanGestureRecognizer *)recognizer { // adjust value of selected transform
}

- (IBAction) doSave {
    NSLog(@"saving");   // XXX need full image for a save
    UIImageWriteToSavedPhotosAlbum(transformImageView.image, nil, nil, nil);
    
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


- (UIImageOrientation) imageOrientationForDeviceOrientation {
    UIDeviceOrientation devo = [[UIDevice currentDevice] orientation];
    //NSLog(@"do %ld", (long)devo);
    UIImageOrientation orient;
    switch (devo) {
        case UIDeviceOrientationPortrait:
            orient = UIImageOrientationUpMirrored;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orient = UIImageOrientationUpMirrored;
            break;
        case UIDeviceOrientationLandscapeRight:
            orient = UIImageOrientationDownMirrored;    // fine
            break;
        case UIDeviceOrientationLandscapeLeft:
            orient = UIImageOrientationDownMirrored;    // fine
            break;
        case UIDeviceOrientationUnknown:
            NSLog(@"%ld", (long)devo);
        case UIDeviceOrientationFaceUp:
            NSLog(@"%ld", (long)devo);
        case UIDeviceOrientationFaceDown:
            NSLog(@"%ld", (long)devo);
        default:
            NSLog(@"Inconceivable video orientation: %ld",
                  (long)devo);
            orient = UIImageOrientationUpMirrored;
    }
    //NSLog(@">>> device orientation: %@", [CameraController dumpCurrentDeviceOrientation]);
    //NSLog(@">>>  image orientation: %@", [CameraController dumpImageOrientation:orient]);
    
    return orient;
}

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
        [self->thumbTasks executeTasksWithDepthBuf:self->depthBuf];
        self->busy = NO;
    });
}

- (void) doTransformsOn:(UIImage *)sourceImage {
    [screenTasks executeTasksWithImage:sourceImage];
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
    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer
                                             orientation:imageOrientation];
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

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
                        orientation:(UIImageOrientation) orientation {
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
                                   orientation:orientation];
    CGImageRelease(quartzImage);
    return image;
}

- (IBAction) didPressVideo:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        NSLog(@"video long press");
    }
}

- (void) removeScreenTransformAtIndex:(long) index {
    if (index == 0)
        return;
    [screenTask removeTransformAtIndex:index];
    if (selectedExecutionStep > 0)
        selectedExecutionStep--;
    [self adjustExecuteDisplay];
}

- (IBAction) doRemoveAllTransforms:(UIBarButtonItem *)button {
    [screenTasks removeAllTransforms];
    [self adjustExecuteDisplay];
}

- (IBAction) doToggleHires:(UIBarButtonItem *)button {
    options.needHires = !options.needHires;
    NSLog(@"high res now %d", options.needHires);
    [options save];
    button.style = options.needHires ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
}

- (void) doTick:(NSTimer *)sender {
    if (taskCtrl.layoutNeeded)
        [taskCtrl layoutIfReady];
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
    [self removeScreenTransformAtIndex: screenTask.transformList.count - 1];
}

- (IBAction) toggleStackingMode:(UIButton *)sender {
    options.stackingMode = !options.stackingMode;
    NSLog(@" stackingMode = %d", options.stackingMode);
//    stackingModeButton = options.stackingMode;
    [options save];
    [self adjustExecuteDisplay];
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

- (void) adjustExecuteDisplay { // for the moment, build it from scratch every time
    if (options.stackingMode) {
        stackingButton.titleLabel.text = @"Single";
        stackingButton.titleLabel.font = [UIFont boldSystemFontOfSize:EXECUTE_BUTTON_FONT_H];
        stackingButton.layer.borderWidth = 4.0;
    } else {
        stackingButton.titleLabel.text = @"Stacking";
        stackingButton.titleLabel.font = [UIFont systemFontOfSize:EXECUTE_BUTTON_FONT_H];
        stackingButton.layer.borderWidth = 1.0;
    }
    [stackingButton setNeedsDisplay];
    
    int start = DOING_3D ? 0 : 1;
    [executeListViews removeAllObjects];
    for (int step=start; step<screenTask.transformList.count; step++) {
        ExecuteRowView *executeRowView = [screenTask executeListViewForStep:step];
        executeRowView.backgroundColor = [UIColor whiteColor];
        executeRowView.opaque = YES;
        [executeListViews addObject:executeRowView];
    }
    // clear out the old rows
    [executeListView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];

    SET_VIEW_HEIGHT(executeListView, (executeListViews.count+1) * EXECUTE_ROW_H);
    // XXX needs to move up properly, like a scroll view
    ExecuteRowView *rowView;
    for (int i=0; i<executeListViews.count; i++) {
        rowView = [executeListViews objectAtIndex:i];
        CGFloat y = executeListView.frame.size.height - (i+1) * EXECUTE_ROW_H;
        SET_VIEW_Y(rowView, y);
        [executeListView addSubview:rowView];
    }
    SET_VIEW_HEIGHT(executeListView, BELOW(rowView.frame));
    executeScrollView.contentSize = executeListView.frame.size;
    [executeScrollView setNeedsLayout];
}

- (IBAction) selectSource:(UISegmentedControl *)sender {
    int segment = (Cameras)sender.selectedSegmentIndex;
    if (segment == sender.numberOfSegments - 1) {   // file selection
        sender.selectedSegmentIndex = segment;
        [self doSelecFileSource];
        return;
    }
    nextSource = [inputSources objectAtIndex:segment];
    [self reconfigure];
}

- (IBAction) selectUI:(UISegmentedControl *)sender {
    uiMode = (UIMode_t)sender.selectedSegmentIndex;
    for (UIView *subView in [containerView subviews])
        [subView removeFromSuperview];  // clear the slate
    [self.view setNeedsLayout];
    [self saveUIMode];
}

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


@end
