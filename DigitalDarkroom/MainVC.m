//
//  MainVC.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "MainVC.h"
#import "CollectionHeaderView.h"
#import "PopoverMenuVC.h"
#import "ExternalScreenVC.h"
#import "Layout.h"
#import "Transforms.h"  // includes DepthImage.h
#import "OptionsVC.h"
#import "ReticleView.h"
#import "HelpVC.h"
#import "Defines.h"


// last settings

#define LAST_FILE_SOURCE_KEY    @"LastFileSource"
#define UI_MODE_KEY             @"UIMode"
#define LAST_SOURCE_KEY      @"Current source index"

#define BUTTON_FONT_SIZE    20
#define STATS_W             75

#define VALUE_W         45
#define VALUE_LIMITS_W  35
#define VALUE_FONT_SIZE 22
#define VALUE_LIMIT_FONT_SIZE   14

#define CURRENT_VALUE_LABEL_TAG     1
#define TRANSFORM_BASE_TAG          100

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
#define SOURCE_IPHONE_SCALE 0.75
#define SOURCE_THUMB_FONT_H 20

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

#define SHOW_LAYOUT_FONT_SIZE   14
#define MAIN_STATS_FONT_SIZE 28

#define STATS_HEADER_INDEX  1   // second section is just stats
#define TRANSFORM_USES_SLIDER(t) ((t).p != UNINITIALIZED_P)

#define RETLO_GREEN [UIColor colorWithRed:0 green:.4 blue:0 alpha:1]
#define NAVY_BLUE   [UIColor colorWithRed:0 green:0 blue:0.5 alpha:1]

#define EXECUTE_STATS_TAG   1

#define DEPTH_TABLE_SECTION     0

#define NO_STEP_SELECTED    -1
#define NO_LAYOUT_SELECTED   (-1)
#define NO_SOURCE       (-1)

#define SOURCE(si)   ((InputSource *)inputSources[si])

#define CURRENT_SOURCE_IS_CAMERA    (inputSources[currentSourceIndex].cameraPosition != AVCaptureDevicePositionUnspecified)

#define SOURCE_INDEX_IS_FRONT(si)   (possibleCameras[SOURCE(si).cameraIndex].front)
#define SOURCE_INDEX_IS_3D(si)   (possibleCameras[SOURCE(si).cameraIndex].threeD)

#define DEVICE_ORIENTATION  [[UIDevice currentDevice] orientation]

typedef enum {
    TransformTable,
    ActiveTable,
} TableTags;

typedef enum {
    sourceCollection,
    transformCollection
} CollectionTags;

typedef enum {
    FrontCameraSource,
    BackCameraSource,
    SampleSource,
    LibrarySource,
} SourceTypes;
#define N_SOURCES 3

typedef enum {
    PlusUnavailable,
    PlusAvailable,
    PlusSelected,
    PlusLocked,
} PlusStatus_t;

NSString * __nullable plusStatusNames[] = {
    @"PlusUnavailable",
    @"PlusAvailable",
    @"PlusSelected",
    @"PlusLocked",
};


MainVC *mainVC = nil;

@interface MainVC ()

@property (nonatomic, strong)   ExternalScreenVC *extScreenVC;
@property (nonatomic, strong)   UIImageView *extImageView;  // not yet implemented...use native screen mirror
@property (nonatomic, strong)   Options *options;

@property (nonatomic, strong)   NSMutableArray *frontCameras, *backCameras;

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   TaskGroup *screenTasks; // only one task in this group
@property (nonatomic, strong)   TaskGroup *thumbTasks;
@property (nonatomic, strong)   TaskGroup *externalTasks;   // not yet, only one task in this group
@property (nonatomic, strong)   TaskGroup *hiresTasks;       // not yet, only one task in this group

@property (nonatomic, strong)   Task *screenTask;
@property (nonatomic, strong)   Task *externalTask;

@property (nonatomic, strong)   UIBarButtonItem *flipBarButton;
@property (nonatomic, strong)   UIBarButtonItem *sourceBarButton;
@property (nonatomic, strong)   UIBarButtonItem *cameraBarButton;
@property (nonatomic, strong)   UIBarButtonItem *extScreenBarButton;

@property (nonatomic, strong)   UIBarButtonItem *trashBarButton;
@property (nonatomic, strong)   UIBarButtonItem *hiresButton;
@property (nonatomic, strong)   UIBarButtonItem *undoBarButton;
@property (nonatomic, strong)   UIBarButtonItem *shareBarButton;

@property (nonatomic, strong)   Frame *lastDisplayedFrame;  // what's on the screen

// in containerview:
@property (nonatomic, strong)   UIView *paramView;
@property (nonatomic, strong)   UILabel *paramLabel;
@property (nonatomic, strong)   UISlider *paramSlider;

@property (nonatomic, strong)   UIView *flashView;
@property (nonatomic, strong)   UILabel *layoutValuesView;
@property (nonatomic, strong)   UILabel *mainStatsView;

@property (assign)              BOOL showControls, showStats, live;
@property (assign)              BOOL transformChainChanged;
@property (assign)              BOOL busy;      // transforming is busy, don't start a new one
@property (nonatomic, strong)   UILabel *paramLow, *paramName, *paramHigh, *paramValue;

@property (nonatomic, strong)   NSString *overlayDebugStatus;
@property (nonatomic, strong)   UIButton *runningButton, *snapButton;
@property (nonatomic, strong)   UIButton *plusButton;
@property (assign)              PlusStatus_t plusStatus;

@property (nonatomic, strong)   UIImageView *transformView; // transformed image
@property (nonatomic, strong)   UIView *thumbsView;         // transform thumbs view of thumbArray
@property (nonatomic, strong)   UIScrollView *executeScrollView;    // active transform list area
@property (nonatomic, strong)   NSMutableArray<Layout *> *layouts;    // approved list of current layouts
@property (assign)              BOOL layoutIsBroken;    // for debugging

// current camera is in cameracontroller
@property (nonatomic, strong)   AVCaptureDevice *nextCamera;
@property (assign)              UIDeviceOrientation nextOrientation;

@property (nonatomic, strong)   Layout *currentLayout;
@property (nonatomic, strong)   Layout *nextLayout;

@property (nonatomic, strong)   UINavigationController *helpNavVC;
// in sources view
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (nonatomic, strong)   UIImageView *cameraSourceThumb; // non-nil if selecting source
@property (nonatomic, strong)   Frame *fileSourceFrame;    // what we are transforming, or nil if get an image from the camera
@property (nonatomic, strong)   InputSource *currentSource, *nextSource;
@property (nonatomic, strong)   NSMutableArray<InputSource *> *inputSources;
@property (assign)              int cameraCount;

@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   UILabel *allStatsLabel;

@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;
@property (assign)              CGFloat execFontSize;


@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthBuf *rawDepthBuf;
@property (assign)              CGSize transformDisplaySize;

@property (nonatomic, strong)   UISegmentedControl *sourceSelectionView;

@property (nonatomic, strong)   UISegmentedControl *uiSelection;
@property (nonatomic, strong)   UIScrollView *thumbScrollView;

@end

@implementation MainVC

@synthesize layouts, currentLayout, nextLayout;

@synthesize nextCamera;
@synthesize nextOrientation;

@synthesize extScreenVC, extImageView;

@synthesize plusButton, plusStatus;
@synthesize taskCtrl;
@synthesize screenTasks, thumbTasks, externalTasks;
@synthesize hiresTasks;
@synthesize screenTask, externalTask;

@synthesize containerView;
@synthesize flipBarButton, sourceBarButton, cameraBarButton, extScreenBarButton;
@synthesize transformView;
@synthesize transformChainChanged;
@synthesize overlayDebugStatus;
@synthesize runningButton, snapButton;
@synthesize thumbViewsArray, thumbsView;
@synthesize helpNavVC;
@synthesize mainStatsView;

@synthesize paramView, paramLabel, paramSlider;
@synthesize showControls, showStats, flashView;
@synthesize paramLow, paramName, paramHigh, paramValue;

@synthesize executeScrollView;
@synthesize layoutValuesView;

@synthesize isPortrait, isiPhone;

@synthesize sourcesNavVC;
@synthesize options;

@synthesize currentSource, nextSource;
@synthesize inputSources;
@synthesize cameraSourceThumb;
@synthesize fileSourceFrame;
@synthesize live;
@synthesize cameraCount;

@synthesize cameraController;
@synthesize layoutIsBroken;

@synthesize undoBarButton, shareBarButton, trashBarButton;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize hiresButton;
@synthesize frontCameras, backCameras;

@synthesize rowIsCollapsed;
@synthesize rawDepthBuf;
@synthesize transformDisplaySize;
@synthesize sourceSelectionView;
@synthesize uiSelection;
@synthesize thumbScrollView;
@synthesize lastDisplayedFrame;
@synthesize stats;

@synthesize minDisplayFrac, bestMinDisplayFrac;
@synthesize minThumbFrac, bestMinThumbFrac, minPctThumbsShown;
@synthesize minThumbRows, minThumbCols;
@synthesize layoutStyle, layoutSteps;
@synthesize minExecWidth;
@synthesize minDisplayWidth, maxDisplayWidth;
@synthesize minDisplayHeight, maxDisplayHeight;
@synthesize execFontSize, executeLabelH;

- (id) init {
    self = [super init];
    if (self) {
        mainVC = self;  // a global is easier
        
        isiPhone  = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
        layoutStyle = isiPhone ? BestiPhoneLayout : BestIPadLayout;
        layoutSteps = 0;    // unmodified best layout

        transforms = [[Transforms alloc] init];
        
        nextCamera = nil;
        nextOrientation = UIDeviceOrientationUnknown;
        currentLayout = nextLayout = nil;
        
        fileSourceFrame = nil;
        layoutIsBroken = NO;
        helpNavVC = nil;
        showControls = NO;
        extScreenVC = nil;
        extImageView = nil;
        transformChainChanged = NO;
        lastDisplayedFrame = nil;
        layouts = [[NSMutableArray alloc] init];
        taskCtrl = [[TaskCtrl alloc] init];
        stats = [[Stats alloc] init];
#ifdef DEBUG
        showStats = YES;
#else
        showStats = NO;
#endif
        
        screenTasks = [taskCtrl newTaskGroupNamed:@"Screen"];
        [taskCtrl.activeGroups setObject:screenTasks forKey:screenTasks.groupName];
        
        thumbTasks = [taskCtrl newTaskGroupNamed:@"Thumbs"];
        [taskCtrl.activeGroups setObject:thumbTasks forKey:thumbTasks.groupName];
#ifdef DEBUG_OMIT_THUMBS
        thumbTasks.groupEnabled = NO;
#endif
        externalTasks = [taskCtrl newTaskGroupNamed:@"External"];
        externalTasks.groupEnabled = NO;    // not implemented
        
        transformTotalElapsed = 0;
        transformCount = 0;
        rawDepthBuf = nil;
        busy = NO;
        options = [[Options alloc] init];
        
        overlayDebugStatus = nil;
        
#if TARGET_OS_SIMULATOR
        cameraController = nil;
        NSLog(@"No camera on simulator");
#else
        cameraController = [[CameraController alloc] init];
        cameraController.videoProcessor = self;
        cameraController.stats = self.stats;
        cameraController.taskCtrl = taskCtrl;
#endif
        
        inputSources = [[NSMutableArray alloc] init];
        frontCameras = [[NSMutableArray alloc] init];
        backCameras = [[NSMutableArray alloc] init];

        currentSource = nil;
        cameraSourceThumb = nil;
        
        cameraCount = 0;

        [self addSources];
    }
    return self;
}

- (void) addSources {
    if (cameraController) { // add camera sources
        for (int ci=0; ci<cameraController.cameraList.count; ci++) {
            InputSource *source = [[InputSource alloc] init];
            source.camera = cameraController.cameraList[ci];
            source.label = source.camera.localizedName;
            source.sourceIndex = (int)inputSources.count;
            [inputSources addObject:source];
            
            if (SOURCE_IS_FRONT(source))
                [frontCameras addObject:source];
            else
                [backCameras addObject:source];
        }
    }
    
    // file sources
#ifdef DEBUG
    [self addFileSource:@"Olive.png" label:@"Olive"];
#endif
//        [self addFileSource:@"olive640.png" label:@"Olive"];
    [self addFileSource:@"ches-1024.jpeg" label:@"Ches"];
    [self addFileSource:@"PM5644-1920x1080.gif" label:@"Color test pattern"];
#ifdef wrongformat
    [self addFileSource:@"800px-RCA_Indian_Head_test_pattern.jpg"
                  label:@"RCA test pattern"];
#endif
    [self addFileSource:@"ishihara6.jpeg" label:@"Ishihara 6"];
    [self addFileSource:@"cube.jpeg" label:@"Rubix cube"];
    [self addFileSource:@"ishihara8.jpeg" label:@"Ishihara 8"];
    [self addFileSource:@"ishihara25.jpeg" label:@"Ishihara 25"];
    [self addFileSource:@"ishihara45.jpeg" label:@"Ishihara 45"];
    [self addFileSource:@"ishihara56.jpeg" label:@"Ishihara 56"];
    [self addFileSource:@"rainbow.gif" label:@"Rainbow"];
    [self addFileSource:@"hsvrainbow.jpeg" label:@"HSV Rainbow"];
}

- (void) addFileSource:(NSString *)fn label:(NSString *)l {
    InputSource *source = [[InputSource alloc] init];
    NSString *file = [@"images/" stringByAppendingPathComponent:fn];
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@""];
    if (!imagePath) {
        NSLog(@"**** Image not found: %@", fn);
        return;
    }
    [source loadImage:imagePath];
    source.sourceIndex = (int)inputSources.count;
    [inputSources addObject:source];
}

- (void) saveSourceIndex:(int) si {
//    NSLog(@"III saving source index %ld, %@", (long)currentSourceIndex, CURRENT_SOURCE.label);
}

#ifdef NOTYET
// for current camera and orientation
- (int) bestFormatIndexForCamera {
    assert(cameraController);
    assert(cameraController.currentCamera);
    
    NSMutableArray<Layout *> *)candidates;
//    long bestFormatIndex = [self editAndSortLayouts:  {
        
        for (int i=0; i<(int)cameraController.sortedFormatIndicies.count; i++) {
            AVCaptureDeviceFormat *format = CURRENT_FORMAT_AT_INDEX(fi);
        }
    }
}
#endif

- (void) createThumbArray {
    thumbViewsArray = [[NSMutableArray alloc] init];

    UITapGestureRecognizer *touch;
    NSString *lastSection = nil;

    for (size_t ti=0; ti<transforms.transforms.count; ti++) {
        Transform *transform = [transforms.transforms objectAtIndex:ti];
        ThumbView *thumbView = [[ThumbView alloc] init];

        NSString *section = [transform.helpPath pathComponents][0];
        
        // insert section button if new section
        if (!lastSection || ![lastSection isEqualToString:section]) {
            [thumbView configureSectionThumbNamed:section];
            [thumbViewsArray addObject:thumbView];  // Add section thumb, then...
            
            thumbView = [[ThumbView alloc] init];   // a new thumbview for the actual transform
            thumbView.transform = transform;
            lastSection = section;
        }
        
        // append thumb
        [thumbView configureForTransform:transform];
        transform.thumbView = thumbView;
        thumbView.tag = ti + TRANSFORM_BASE_TAG;
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.tag = THUMB_IMAGE_TAG;
        [thumbView addSubview:imageView];
        
        if (transform.broken) {
            [thumbView adjustStatus:ThumbTransformBroken];
        } else {
            touch = [[UITapGestureRecognizer alloc]
                     initWithTarget:self
                     action:@selector(didTapThumb:)];
            thumbView.task = [thumbTasks createTaskForTargetImageView:imageView
                                                           named:transform.name];
            [thumbView.task appendTransformToTask:transform];
            [thumbView addGestureRecognizer:touch];
            UILongPressGestureRecognizer *thumbHelp = [[UILongPressGestureRecognizer alloc]
                                                             initWithTarget:self
                                                       action:@selector(doHelp:)];
            thumbHelp.minimumPressDuration = 1.0;
            [thumbView addGestureRecognizer:thumbHelp];
            [thumbView adjustThumbEnabled];
        }

        [thumbViewsArray addObject:thumbView];
    }

    // contains transform thumbs and sections.  Positions and sizes decided
    // as needed.
    
    for (ThumbView *thumbView in thumbViewsArray) {
        [thumbsView addSubview:thumbView];
//        NSLog(@"TTTTT: %d  %@", thumbView.task.enabled, thumbView.task.taskName);
    }
#ifdef DEBUG_LAYOUT
    NSLog(@"Number of thumbViews: %d", (int)thumbViewsArray.count);
#endif
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


// Transform thumb layout needs to be checked at
// - every display size change
// - device rotation
// - 3D selection change
//
//  The ordered list of transform and section thumbs are in thumbViewsArray,
//  and are subViews of thumbsView.  Their positions need adjustment. If there
//  no current 3D selected, hide those thumbs behind the section header.

- (void) layoutThumbs:(Layout *)layout {
    nextButtonFrame = layout.firstThumbRect;
    assert(layout.thumbImageRect.size.width > 0 && layout.thumbImageRect.size.height > 0);

    CGRect transformNameRect;
    transformNameRect.origin = CGPointMake(0, BELOW(layout.thumbImageRect));
    transformNameRect.size = CGSizeMake(nextButtonFrame.size.width, THUMB_LABEL_H);
    CGRect sectionNameRect = CGRectMake(THUMB_LABEL_SEP, SEP,
                                        nextButtonFrame.size.width - 2*THUMB_LABEL_SEP,
                                        nextButtonFrame.size.height - 2*SEP);

    // Run through all the transform and section thumbs, computing the corresponding thumb sizes and
    // positions for the current situation. These thumbs come in section, each of which has
    // their own section header thumb display. This header starts on a new line (if vertical
    // thumb placement) or after a space on horizontal placements.
    
    atStartOfRow = YES;
    CGFloat thumbsH = 0;
//    NSString *lastSection = nil;
    
    // run through the thumbview array
    for (ThumbView *thumbView in thumbViewsArray) {
        switch (thumbView.status) {
            case SectionHeader: {
#ifdef DEBUG_THUMB_LAYOUT
                NSLog(@"%3.0f,%3.0f  %3.0fx%3.0f   Section %@",
                      nextButtonFrame.origin.x, nextButtonFrame.origin.y,
                      nextButtonFrame.size.width, nextButtonFrame.size.height,
                      thumbView.sectionName);
#endif
#ifdef OLD
                if (lastSection) {  // not our first section, make space
                    if (!atStartOfRow) {
                        [self nextTransformButtonPosition];
                    }
                }
#endif
                UILabel *label = [thumbView viewWithTag:THUMB_LABEL_TAG];
                label.frame = sectionNameRect;
                thumbView.frame = nextButtonFrame;  // this is a little incomplete
                //            lastSection = thumbView.sectionName;
                break;
            }
            default:    // regular thumb button
                [thumbView adjustThumbEnabled];
#ifdef DEBUG_THUMB_LAYOUT
                NSLog(@"%3.0f,%3.0f  %3.0fx%3.0f   Transform %@",
                      nextButtonFrame.origin.x, nextButtonFrame.origin.y,
                      nextButtonFrame.size.width, nextButtonFrame.size.height,
                      transform.name);
#endif
                UIImageView *thumbImage = [thumbView viewWithTag:THUMB_IMAGE_TAG];
                thumbImage.frame = layout.thumbImageRect;
                thumbView.task.targetImageView = thumbImage;
                
                UILabel *label = [thumbView viewWithTag:THUMB_LABEL_TAG];
                label.frame = transformNameRect;
                thumbView.frame = nextButtonFrame;
        }
        atStartOfRow = NO;
        thumbsH = BELOW(thumbView.frame);
        
        [self nextTransformButtonPosition];
    }
    
    SET_VIEW_HEIGHT(thumbsView, thumbsH);
    thumbScrollView.contentSize = thumbsView.frame.size;
    thumbScrollView.contentOffset = thumbsView.frame.origin;
    
    [thumbScrollView setContentOffset:CGPointMake(0, 0) animated:YES];
}

- (void) viewDidLoad {
    [super viewDidLoad];

#ifdef DEBUG_RECONFIGURATION
    NSLog(@"DR viewDidLoad");
#endif

#ifdef DEBUG_ORIENTATION
    NSLog(@"OOOO viewDidLoad orientation: %@",
          DEVICE_ORIENTATION);
#else
#ifdef DEBUG_LAYOUT
    NSLog(@"viewDidLoad");
#endif
#endif

    self.navigationController.navigationBar.opaque = YES;
    self.navigationController.toolbarHidden = YES;
//    self.navigationController.toolbar.opaque = NO;
    
    sourceBarButton = [[UIBarButtonItem alloc]
                       initWithImage:[UIImage systemImageNamed:@"filemenu.and.selection"]
                       style:UIBarButtonItemStylePlain
                       target:self
                       action:@selector(selectSourceFromMenu:)];
    
    flipBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath.camera"]
                     style:UIBarButtonItemStylePlain
                     target:self
                     action:@selector(flipCamera:)];
    
#ifdef DISABLED
    UIBarButtonItem *otherMenuButton = [[UIBarButtonItem alloc]
                                        initWithImage:[UIImage systemImageNamed:@"ellipsis"]
                                        style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(goSelectOptions:)];
#endif
    
    extScreenBarButton = [[UIBarButtonItem alloc]
                          initWithImage:[UIImage systemImageNamed:@"tv"]
                          style:UIBarButtonItemStylePlain
                          target:self
                          action:@selector(didTapAlternateDisplay:)];
    extScreenBarButton.enabled = NO;
    
    trashBarButton = [[UIBarButtonItem alloc]
                      initWithImage:[UIImage systemImageNamed:@"trash"]
                      style:UIBarButtonItemStylePlain
                      target:self
                      action:@selector(doRemoveAllTransforms)];
    
    hiresButton = [[UIBarButtonItem alloc]
                   initWithTitle:@"Hi res" style:UIBarButtonItemStylePlain
                   target:self action:@selector(doToggleHires:)];
    
#ifdef NOTDEF
    shareBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                     style:UIBarButtonItemStylePlain
                     target:self
                      action:@selector(doShare:)];

    plusBar = [[UISegmentedControl alloc]
                                   initWithItems:@[[UIImage systemImageNamed:@"plus.rectangle.on.rectangle"],
                                                   [UIImage systemImageNamed:@"plus.rectangle"]]];
    [plusBar addTarget:self
                action:@selector(doPlus:)
      forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *plusBarSelectionButton = [[UIBarButtonItem alloc]
                                               initWithCustomView:plusBar];
#endif
    
    undoBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"arrow.uturn.backward"]
                     style:UIBarButtonItemStylePlain
                     target:self
                     action:@selector(doRemoveLastTransform)];
    
    UIBarButtonItem *docBarButton = [[UIBarButtonItem alloc]
//                                   initWithImage:[UIImage systemImageNamed:@"doc.text"]
                                     initWithTitle:@"?"
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(doHelp:)];
    
#define NAVBAR_H   self.navigationController.navigationBar.frame.size.height
    
    cameraBarButton = [[UIBarButtonItem alloc] initWithImage:nil
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(doCamera:)];
    
    self.navigationItem.leftBarButtonItems = [[NSArray alloc] initWithObjects:
                                              sourceBarButton,
                                              cameraBarButton,
                                              flipBarButton,
                                              nil];
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                   target:nil action:nil];
    fixedSpace.width = 10;
    
#ifdef NOTUSED
    UIBarButtonItem *flexiableItem = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:self
                                      action:nil];
#endif
    
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:
                                               undoBarButton,
                                               trashBarButton,
                                               fixedSpace,
                                               extScreenBarButton,
                                               docBarButton,
                                               nil];

    containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor whiteColor];
    containerView.userInteractionEnabled = YES;
    containerView.clipsToBounds = YES;  // this shouldn't be needed
#ifdef DEBUG_LAYOUT
    containerView.layer.borderWidth = 1.0;
    containerView.layer.borderColor = [UIColor blueColor].CGColor;
#endif
    
    transformView = [[UIImageView alloc] init];
    transformView.backgroundColor = NAVY_BLUE;
    transformView.clipsToBounds = YES;
    transformView.userInteractionEnabled = YES;
#ifdef DEBUG_BORDERS
    transformView.layer.borderColor = [UIColor redColor].CGColor;
    transformView.layer.borderWidth = 3.0;
#endif

    flashView = [[UIView alloc] init];  // used to show a flash on the screen
    flashView.opaque = NO;
    flashView.hidden = YES;
    [containerView addSubview:flashView];

    mainStatsView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, LATER, MAIN_STATS_FONT_SIZE)];
    mainStatsView.hidden = NO;
    mainStatsView.text = @"";
    mainStatsView.font = [UIFont fontWithName:@"Courier-Bold" size:MAIN_STATS_FONT_SIZE];
    mainStatsView.textAlignment = NSTextAlignmentLeft;
    mainStatsView.textColor = [UIColor whiteColor];
    mainStatsView.adjustsFontSizeToFitWidth = YES;
    //mainStatsView.lineBreakMode = NSLineBreakByTruncatingTail;
    //    mainStatsView.lineBreakMode = NSLineBreakByWordWrapping;
    mainStatsView.opaque = NO;
    mainStatsView.numberOfLines = 0;
    mainStatsView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    [transformView addSubview:mainStatsView];
    [transformView bringSubviewToFront:mainStatsView];
    
    [UIFont boldSystemFontOfSize:SHOW_LAYOUT_FONT_SIZE];

    layoutValuesView = [[UILabel alloc] init];
    layoutValuesView.hidden = YES;
    layoutValuesView.font = [UIFont fontWithName:@"Courier-Bold" size:SHOW_LAYOUT_FONT_SIZE];
    layoutValuesView.textAlignment = NSTextAlignmentLeft;
    layoutValuesView.textColor = [UIColor whiteColor];
    layoutValuesView.adjustsFontSizeToFitWidth = YES;
    //layoutValuesView.lineBreakMode = NSLineBreakByTruncatingTail;
    //    layoutValuesView.lineBreakMode = NSLineBreakByWordWrapping;
    layoutValuesView.opaque = NO;
    layoutValuesView.numberOfLines = 0;
    layoutValuesView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
#ifdef DEBUG_BORDERS
    layoutValuesView.layer.borderColor = [UIColor orangeColor].CGColor;
    layoutValuesView.layer.borderWidth = 3.0;
#endif
    [containerView addSubview:layoutValuesView];

//#define FIT_TO_BUTTON(si)   [self fitImage:[UIImage systemImageNamed:si] \
//            toSize:CGSizeMake(CONTROL_BUTTON_SIZE,CONTROL_BUTTON_SIZE) centered:YES]]

    runningButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    runningButton.frame = CGRectMake(LATER, LATER,
                                         CONTROL_BUTTON_SIZE*4, CONTROL_BUTTON_SIZE*4);
    [runningButton addTarget:self
                          action:@selector(togglePauseResume:)
                forControlEvents:UIControlEventTouchUpInside];
    [runningButton setTintColor:[UIColor whiteColor]];
    runningButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    runningButton.layer.cornerRadius = CONTROL_BUTTON_SIZE/2.0;
    [transformView addSubview:runningButton];

    snapButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    snapButton.frame = CGRectMake(LATER, LATER,
                                         CONTROL_BUTTON_SIZE, CONTROL_BUTTON_SIZE);
    snapButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    snapButton.imageView.contentScaleFactor = 4.0;
    snapButton.backgroundColor = [UIColor clearColor];
    [snapButton setImage:[self fitImage:[UIImage systemImageNamed:@"largecircle.fill.circle"]
                                 toSize:snapButton.frame.size centered:YES]
                       forState:UIControlStateNormal];
    snapButton.tintColor = [UIColor whiteColor];
    [snapButton addTarget:self
                          action:@selector(doSave)
                forControlEvents:UIControlEventTouchUpInside];
    [transformView addSubview:snapButton];
    [transformView bringSubviewToFront:snapButton];

    paramView = [[UIView alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
#ifdef OLD
    paramView.backgroundColor = [UIColor colorWithRed:0.5 green:1.0 blue:0.0 alpha:0.5];
    paramView.opaque = NO;
    paramView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
#endif
    paramView.layer.cornerRadius = 6.0;
    paramView.clipsToBounds = YES;
    paramView.layer.borderWidth = VIEW_BORDER_W;
    paramView.layer.borderColor = VIEW_BORDER_COLOR;
    paramView.hidden = YES;     // initialized as hidden
    [transformView addSubview:paramView];
    [transformView bringSubviewToFront:paramView];

    paramLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, SEP, LATER, PARAM_LABEL_H)];
    paramLabel.textAlignment = NSTextAlignmentCenter;
    paramLabel.font = [UIFont boldSystemFontOfSize:PARAM_LABEL_FONT_SIZE];
    paramLabel.textColor = [UIColor blackColor];
    [paramView addSubview:paramLabel];
    
    paramSlider = [[UISlider alloc]
                   initWithFrame:CGRectMake(0, BELOW(paramLabel.frame) + SEP,
                                            LATER, PARAM_SLIDER_H)];
    paramSlider.continuous = YES;
    [paramSlider addTarget:self action:@selector(doParamSlider:)
          forControlEvents:UIControlEventValueChanged];
    [paramView addSubview:paramSlider];

    SET_VIEW_HEIGHT(paramView, BELOW(paramSlider.frame) + SEP);
    
    [containerView addSubview:paramView];
    
    executeScrollView = [[UIScrollView alloc] init];
//    executeScrollView.backgroundColor = [UIColor yellowColor];
    executeScrollView.layer.borderColor = VIEW_BORDER_COLOR;
    executeScrollView.layer.borderWidth = VIEW_BORDER_W;
    executeScrollView.userInteractionEnabled = NO;
    executeScrollView.scrollEnabled = YES;
    executeScrollView.showsHorizontalScrollIndicator = NO;
    executeScrollView.showsVerticalScrollIndicator = YES;
    [containerView addSubview:executeScrollView];
    
    plusButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [plusButton addTarget:self
                   action:@selector(doPlusTapped:)
         forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self
                                               action:@selector(doPlusPressed:)];
    longPress.minimumPressDuration = 0.7;
    [plusButton addGestureRecognizer:longPress];
    
    [self changePlusStatusTo: PlusUnavailable];
    plusButton.layer.borderColor = [UIColor blackColor].CGColor;
    plusButton.layer.cornerRadius = isiPhone ? 3.0 : 5.0;
#ifdef UNDEF
    plusButton.layer.borderWidth = isiPhone ? 1.0 : 5.0;
    plusButton.layer.cornerRadius = isiPhone ? 3.0 : 5.0;
#endif
    [containerView addSubview:plusButton];
    
    // select overlaied stuff
    UITapGestureRecognizer *transformTap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(didTapTransformView:)];
    [transformTap setNumberOfTouchesRequired:1];
    [transformView addGestureRecognizer:transformTap];

    // same as tap, but with debugging stuff.
    UILongPressGestureRecognizer *longPressScreen = [[UILongPressGestureRecognizer alloc]
                                                     initWithTarget:self action:@selector(didLongPressTransformView:)];
    longPressScreen.minimumPressDuration = 1.0;
    [longPressScreen setNumberOfTouchesRequired:1];
    [transformView addGestureRecognizer:longPressScreen];

#ifdef SWIPE_NOT_PINCH
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]
                                         initWithTarget:self action:@selector(doUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [transformView addGestureRecognizer:swipeUp];

    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc]
                                         initWithTarget:self action:@selector(doDown:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [transformView addGestureRecognizer:swipeDown];
#endif
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc]
                                       initWithTarget:self
                                       action:@selector(doPinch:)];
    [transformView addGestureRecognizer:pinch];
    
    [containerView addSubview:transformView];
    
    screenTask = [screenTasks createTaskForTargetImageView:transformView
                                                     named:@"main"];
    //externalTask = [externalTasks createTaskForTargetImage:transformImageView.image];

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
    
    thumbsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [thumbScrollView addSubview:thumbsView];
    [containerView addSubview:thumbScrollView];

    [self.view addSubview:containerView];
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self createThumbArray];
    [self adjustBarButtons];
//    [self updateExecuteView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalScreenDidConnect:)
                                                 name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalScreenDidDisconnect:)
                                                 name:UIScreenDidDisconnectNotification object:nil];

#ifdef DEBUG_RECONFIGURATION
    NSLog(@"DR viewDidLoad: selecting source 0");
#endif
    nextSource = inputSources[0];   // camera or first image
}

-(void)externalScreenDidConnect:(NSNotification *)notification {
    UIScreen *screen = (UIScreen *)[notification object];
    if (!screen)
        return;
    extScreenVC = [[ExternalScreenVC alloc] initWithScreen:[UIScreen screens][1]];
    extScreenBarButton.enabled = YES;
}

-(void)externalScreenDidDisconnect:(NSNotification *)notification {
    id obj = [notification object];
    if (!obj)
        return;
    [extScreenVC deactivateExternalScreen];
    [self turnExternalScreenOn:NO];
    extScreenVC = nil;
    extImageView = nil;
    extScreenBarButton.enabled = NO;
}

- (IBAction) didTapAlternateDisplay:(UIBarButtonItem *)sender {
    NSLog(@"didTapAlternateDisplay tapped");
    assert(extScreenBarButton.enabled);
}

- (void) turnExternalScreenOn:(BOOL) on {
    if (on) {
        extImageView = [extScreenVC activateExternalScreen];
    } else {
         [extScreenVC deactivateExternalScreen];
        extImageView = nil;
    }
}

- (void) dumpViewLimits:(NSString *)label {
#ifdef DEBUG_ORIENTATION
    NSLog(@"%@,   %@", label, [CameraController
                               dumpDeviceOrientationName:DEVICE_ORIENTATION]);
    CGRect safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
    CGRect f = self.view.frame;
    NSLog(@" view.frame  %2.0f,%2.0f  %4.0f x %4.0f", f.origin.x, f.origin.y,
          f.size.width, f.size.height);
    NSLog(@" safe frame  %2.0f,%2.0f  %4.0f x %4.0f", safeFrame.origin.x, safeFrame.origin.y,
          safeFrame.size.width, safeFrame.size.height);
#endif
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#ifdef DEBUG_RECONFIGURATION
    NSLog(@"DR viewWillAppear");
#endif

    [self dumpViewLimits:(@"OOOO viewWillAppear")];
    // not needed: we haven't started anything yet
    
    [taskCtrl suspendTasksForDisplayUpdate];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    
#ifdef DEBUG_RECONFIGURATION
    NSLog(@"DR viewWillAppear");
#endif

    [self dumpViewLimits:(@"OOOO viewDidAppear")];

    frameCount = depthCount = droppedCount = busyCount = 0;
    [self.view setNeedsDisplay];

#define TICK_INTERVAL   1.0
    statsTimer = [NSTimer scheduledTimerWithTimeInterval:TICK_INTERVAL
                                                  target:self
                                                selector:@selector(doTick:)
                                                userInfo:NULL
                                                 repeats:YES];
    lastTime = [NSDate now];
}

- (void)viewWillDisappear:(BOOL)animated {
#ifdef DEBUG_LAYOUT
    NSLog(@"--------- viewWillDisappear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#endif

    [super viewWillDisappear:animated];
    [cameraController stopCamera];
}

- (void) adjustOrientation {
    UIDeviceOrientation nextOrientation = DEVICE_ORIENTATION;
    [self dumpViewLimits:@"viewWillTransitionToSize"];
    if (nextOrientation == UIDeviceOrientationUnknown)
//        nextOrientation = UIDeviceOrientationPortraitUpsideDown;    // klduge, don't know why
        nextOrientation = UIDeviceOrientationPortrait;    // klduge, don't know why
    if (nextOrientation == DEVICE_ORIENTATION)
        return; // nothing new to see here, folks
    [taskCtrl suspendTasksForDisplayUpdate];
    // the rest of orientation update is processed in reconfigureDisplay
}

- (void) viewWillTransitionToSize:(CGSize)size
        withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        ;
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self->taskCtrl suspendTasksForDisplayUpdate];
    }];
}

// something has changed.  We enter here with tasks suspended so we can change their
// underlying display information. Various local variables tell what needs changing.  Some imply
// that others need updating too.

- (void) reconfigureDisplay {
    // XXX assert all tasks are idle
#ifdef DEBUG_RECONFIGURATION
    NSLog(@"DR reconfigureDisplay");
#endif
    
    if (nextSource) {   // new camera or file input
        if (SOURCE_IS_CAMERA(nextSource)) {
            [cameraController selectCamera:nextSource.camera];
            nextOrientation = UIDeviceOrientationUnknown;
            [self liveOn:NO];
        } else {    // file source
            fileSourceFrame = [[Frame alloc] init];
            [fileSourceFrame readImageFromPath: currentSource.imagePath];
        }
        currentSource = nextSource;
        nextSource = nil;
        currentLayout = nil;   // force new layout
    }
   
    if (nextOrientation == UIDeviceOrientationUnknown || nextOrientation != DEVICE_ORIENTATION) {
        if (SOURCE_IS_CAMERA(currentSource)) {
            [cameraController adjustCameraOrientation:DEVICE_ORIENTATION];
        }
        currentLayout = nil;   // force new layout
        nextOrientation = DEVICE_ORIENTATION;
    }
    
    if (nextLayout) {   // next layout already selected, apply it
    }
    
    if (!currentLayout) {
        [self computeLayoutLimits];
        
        NSMutableArray *candidateLayouts = [[NSMutableArray alloc] init];
        
        if (fileSourceFrame) {  // fixed, non-camera input
            [self proposeLayoutsForSize:fileSourceFrame.size into:candidateLayouts];
        } else {        // various camera source size options
            for (AVCaptureDeviceFormat *format in cameraController.currentFormats) {
                CGSize s = [cameraController sizeForFormat:format];
                [self proposeLayoutsForSize:s into:candidateLayouts];
            }
        }
        
        if (!candidateLayouts.count) {
            NSLog(@"Inconceivable: no useful layout found.");
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@"No layout found"
                                         message:@"inconceivable"
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Dismiss"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {}
            ];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
            
//XXXX            taskCtrl.state = LayoutBroken;
            layoutIsBroken = YES;
            return;
        }
        
        [layouts removeAllObjects]; // loaded by the next routine
        Layout *bestLayout = [self editAndSortLayouts:candidateLayouts];
        NSLog(@"LLLL best layout index: %ld", currentLayout.index);
        
        [self applyScreenLayout:bestLayout];

    #ifdef NOTDEF
        int i = 0;
        for (Layout *layout in layouts) {
            NSLog(@"%3d   %.3f  %.3f %.3f    %@", i,
                  layout.displayFrac, layout.score, layout.thumbFrac,
                  i == currentLayout.index ? @"<---" : @"");
            i++;
        }
        
        for (int i=0; i<layouts.count; i++ ) {
            Layout *layout = layouts[i];
            NSLog(@"%2d %@", i, layout.status);
        }
    #endif

    }
    
    [self refreshScreen];

    // finish up
    if (!isiPhone)  // if room for a title
        self.title = currentSource.label;
    transformChainChanged = YES;
    [[NSUserDefaults standardUserDefaults] setInteger:currentSource.sourceIndex
                                               forKey:LAST_SOURCE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    nextSource = nil;
}

- (void) computeLayoutLimits {
    isPortrait = UIDeviceOrientationIsPortrait(DEVICE_ORIENTATION) ||
        UIDeviceOrientationIsFlat(DEVICE_ORIENTATION);
    
    // screen/view limits
    if (mainVC.isiPhone) { // iphone display is very cramped.  Make the best of it.
        execFontSize = EXECUTE_IPHONE_FONT_SIZE;
        minExecWidth = EXECUTE_MIN_TEXT_CHARS * (execFontSize*0.7) + 2*EXECUTE_BORDER_W;
        if (mainVC.isPortrait) {
            minDisplayWidth = layoutStyle == OnlyThumbsDisplayed ? 0 : containerView.frame.size.width / 6.0;
            maxDisplayWidth = 0;    // no max
            minDisplayHeight = PARAM_VIEW_H*3;
            maxDisplayHeight = containerView.frame.size.height / 3.0;
            minPctThumbsShown = 7.0;
        } else {    // iphone landscape
            minDisplayWidth = layoutStyle == OnlyThumbsDisplayed ? 0 : THUMB_W*2.0;
            maxDisplayWidth = containerView.frame.size.width / 3.0;    // no max
            minDisplayHeight = THUMB_W*2;
            maxDisplayHeight = 0;   // no limit
            minPctThumbsShown = 14.0;
        }
        bestMinDisplayFrac = 0.2; // 0.4;
        minDisplayFrac = layoutStyle == OnlyThumbsDisplayed ? 0 : 0.3;
        bestMinThumbFrac = 0.4; // unused
        minThumbFrac = 0.249;   // 0.3 for large iphones
        minThumbRows = MIN_IPHONE_THUMB_ROWS;
        minThumbCols = MIN_IPHONE_THUMB_COLS;
    } else {
        execFontSize = EXECUTE_IPAD_FONT_SIZE;
        minExecWidth = EXECUTE_MIN_TEXT_CHARS * (execFontSize*0.7) + 2*EXECUTE_BORDER_W;
        minDisplayWidth = 2*THUMB_W;
        maxDisplayWidth = containerView.frame.size.width;
        minDisplayHeight = 2*THUMB_W;
        maxDisplayHeight = containerView.frame.size.height;
        bestMinDisplayFrac = 0.65;  // 0.42;
        minDisplayFrac = 0.3; // 0.5;   // 0.40
        bestMinThumbFrac = 0.5;
        minThumbFrac = 0.3;
        minThumbRows = MIN_THUMB_ROWS;
        minThumbCols = MIN_THUMB_COLS;
    }
    executeLabelH = execFontSize + 7;
    
    if (layoutStyle == OnlyTransformDisplayed) {
        minThumbRows = 0;
        minThumbCols = 0;
    }
    assert(minExecWidth > 0);
    
    CGRect safeFrame = CGRectInset(self.view.safeAreaLayoutGuide.layoutFrame, INSET, 0);
    containerView.frame = safeFrame;
#ifdef DEBUG_LAYOUT
    NSLog(@" ******* containerview: @%.0f,%.0f  %.0fx%.0f  %@",
          containerView.frame.origin.x, containerView.frame.origin.y,
          containerView.frame.size.width, containerView.frame.size.height,
          containerView.frame.size.width > containerView.frame.size.height ? @"landscape" : @"portrait");
#endif
    
#ifdef DEBUG_BORDERS
    containerView.layer.borderColor = [UIColor magentaColor].CGColor;
    containerView.layer.borderWidth = 3.0;
#endif
}

- (void) proposeLayoutsForSize:(CGSize) sourceSize into:(NSMutableArray <Layout *> *)candidateLayouts {
    size_t thumbCols = minThumbCols;
    size_t thumbRows = minThumbRows;
    Layout *layout;
    
    switch (layoutStyle) {
        case BestIPadLayout:
            // try right thumbs
            do {
                layout = [[Layout alloc]
                          initForSize: sourceSize
                          rightThumbs:thumbCols++
                          bottomThumbs:0
                          layoutOption:layoutStyle
                          device:nil
                          format:nil
                          depthFormat:nil];
                if (!layout || layout.score == BAD_LAYOUT)
                    continue;
#ifdef DEBUG_LAYOUT
                NSLog(@"%2ld -- %@", candidateLayouts.count, [cameraController dumpFormat:layout.format]);
#endif
                [candidateLayouts addObject:layout];
            } while (layout);
            
            // try bottom thumbs
            do {    // try bottom thumbs
                layout = [[Layout alloc]
                          initForSize: sourceSize
                          rightThumbs:0
                          bottomThumbs:thumbRows++
                          layoutOption:layoutStyle
                          device:nil
                          format:nil
                          depthFormat:nil];                if (/* DISABLES CODE */ (NO) && layout) {
                    NSLog(@"BT  %@", [layout layoutSum]);
                }
                
                if (!layout || layout.score == BAD_LAYOUT)
                    continue;
#ifdef DEBUG_LAYOUT
                NSLog(@"%2ld -- %@", candidateLayouts.count, [cameraController dumpFormat:layout.format]);
#endif
                [candidateLayouts addObject:layout];
            } while (layout);
            
#ifdef NOMORE
            [trialLayout tryLayoutsOnRight:YES];
            [trialLayout tryLayoutsOnRight:NO];
            [trialLayout tryLayoutsForStacked];
            [trialLayout tryLayoutsForExecOnLeft:NO];
            [trialLayout tryLayoutsForExecOnLeft:YES];
            [trialLayout tryLayoutsForJustDisplayOnLeft:YES];
            [trialLayout tryLayoutsForJustDisplayOnLeft:NO];
#endif
            break;
        case BestiPhoneLayout:    // NB: iPhone is suboptimal for this app
            if (isPortrait) {   // portrait iphone
                
            } else {            // landscape iphone
                
            }
#ifdef NOTYET
            [trialLayout tryLayoutsOnRight:YES];
            [trialLayout tryLayoutsOnRight:NO];
            [trialLayout tryLayoutsForExecOnLeft:YES];
            [trialLayout tryLayoutsForExecOnLeft:NO];
            [trialLayout tryLayoutsForStacked];
#endif
            break;
        case OnlyTransformDisplayed:
#ifdef NOTYET
            [trialLayout tryLayoutsForJustDisplay];
#endif
            break;
        case OnlyThumbsDisplayed: {  // execute and thumbs only
            if (isPortrait) {       // portrait iphone
                
            } else {            // landscape iphone
                
            }
            break;
        }
    }
}

- (float) scoreLayout:(Layout *)layout {
    float score = -1;
    
    return score;
}

// make list of approved layouts,  with best guess first
- (Layout *) editAndSortLayouts: (NSMutableArray<Layout *> *)candidates {

    // sort the layouts by descending size, and score. Default is the highest
    // scoring one.  Discard the ones that are close.
    
    [candidates sortUsingComparator:^NSComparisonResult(Layout *l1, Layout *l2) {
        if (l1.displayFrac != l2.displayFrac)
            return [[NSNumber numberWithFloat:l2.displayFrac]
                    compare:[NSNumber numberWithFloat:l1.displayFrac]];

//        return [[NSNumber numberWithFloat:l2.pctUsed]
//                    compare:[NSNumber numberWithFloat:l1.pctUsed]];
        return [[NSNumber numberWithFloat:l2.score]
                    compare:[NSNumber numberWithFloat:l1.score]];
    }];

    // run down through the layouts, from largest display to smallest, removing
    // ones that are essentially duplicates. Find the best scoring one, our default
    // selection.
    
    Layout *bestLayout = nil;
    CMVideoDimensions lastVideoSize = {0,0};
    
    NSLog(@"editAndSortLayouts: checking %lu candidates", (unsigned long)candidates.count);
    for (Layout *layout in candidates) {
        if (layout.format) {
            CMVideoDimensions vs = CMVideoFormatDescriptionGetDimensions(layout.format.formatDescription);
            if (vs.width == lastVideoSize.width && vs.height == lastVideoSize.height)
                continue;
            lastVideoSize = vs;
        }
        layout.index = layouts.count;
        [layouts addObject:layout];
#ifdef DEBUG_LAYOUT
        NSLog(@"--- %3d: %5.1f  %@", i, layout.score, [cameraController dumpFormat:layout.format]);
#endif
        
        if (!layouts.count) {   // first one
            bestLayout = layout;
        } else {
            if (layout.score > bestLayout.score) {
                bestLayout = layout;
            }
        }
    }
#ifdef DEBUG_LAYOUT
    NSLog(@"LLLL %lu trimmed to %lu, top score %.5f at %d",
          candidates.count, layouts.count, bestScore, bestScoreIndex);
    NSLog(@"LLLL %3d: %5.1f  %@", bestScoreIndex, bestScore,
          [cameraController dumpFormat:candidates[bestScoreIndex].format]);
#endif
    assert(bestLayout);
    return bestLayout;
}

- (void) dumpLayouts {
    for (int i=0; i<layouts.count; i++) {
        Layout *layout = layouts[i];
        NSLog(@"%2d %@ %@", i,
            currentLayout.index == i ? @">>" : @"  ",
            [layout layoutSum]);
    }
}

- (void) applyScreenLayout:(Layout *) newLayout {
    assert(newLayout);
    
    currentLayout = newLayout;
#ifdef DEBUG_LAYOUT
    NSLog(@"MainVC: *** applyScreenLayout index %ld, %@",
          layoutIndex, [cameraController dumpFormat:currentLayout.format]);
//    [currentLayout dump];
#endif

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
    // - I suppose there will be a video file capture option some day.  That would be another target.
    
    transformView.frame = currentLayout.displayRect;
    CGRect f = transformView.frame;
    f.origin.x = f.size.width - CONTROL_BUTTON_SIZE - SEP;
    f.origin.y = f.size.height - CONTROL_BUTTON_SIZE - SEP;
    f.size = snapButton.frame.size;
    snapButton.frame = f;
    
    f.origin.x -= f.size.width + SEP;
    runningButton.frame = f;
    
    paramView.frame = currentLayout.paramRect;
    SET_VIEW_WIDTH(paramLabel, paramView.frame.size.width);
    SET_VIEW_WIDTH(paramSlider, paramView.frame.size.width);
    [self checkParamsFor:[screenTask.transformList lastObject]];
    
    thumbScrollView.frame = currentLayout.thumbScrollRect;
#ifdef DEBUG_BORDERS
    thumbScrollView.layer.borderColor = [UIColor cyanColor].CGColor;
    thumbScrollView.layer.borderWidth = 3.0;
#endif
    
    CGFloat below = BELOW(thumbScrollView.frame);
    assert(below <= BELOW(containerView.frame));
    
    thumbsView.frame = CGRectMake(0, 0,
                                  thumbScrollView.frame.size.width,
                                  thumbScrollView.frame.size.height);

#ifdef NOTDEF
    NSLog(@"layout selected:");

    NSLog(@"        capture:               %4.0f x %4.0f (%4.2f)  @%.1f",
          currentLayout.captureSize.width, currentLayout.captureSize.height,
          currentLayout.captureSize.width/currentLayout.captureSize.height, currentLayout.scale);
    NSLog(@" transform size:               %4.0f x %4.0f (%4.2f)  @%.1f",
          currentLayout.transformSize.width,
          currentLayout.transformSize.height,
          currentLayout.transformSize.width/currentLayout.transformSize.height,
          currentLayout.scale);
    NSLog(@"           view:  %4.0f, %4.0f   %4.0f x %4.0f (%4.2f)",
          transformView.frame.origin.x,
          transformView.frame.origin.y,
          transformView.frame.size.width,
          transformView.frame.size.height,
          transformView.frame.size.width/transformView.frame.size.height);

    NSLog(@"      container:               %4.0f x %4.0f (%4.2f)",
          containerView.frame.size.width,
          containerView.frame.size.height,
          containerView.frame.size.width/containerView.frame.size.height);
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
    NSLog(@"    display frac: %.3f", currentLayout.displayFrac);
    NSLog(@"      thumb frac: %.3f", currentLayout.thumbFrac);
    NSLog(@"           scale: %.3f", currentLayout.scale);
#endif
    
    // currentLayout.transformSize is what the tasks get to run.  They
    // then display (possibly scaled) onto transformView.
    
    CGSize imageSize, depthSize;
    if (currentLayout.device) { // camera input: set format and get raw sizes
        [cameraController selectCameraFormat:currentLayout.format depthFormat:currentLayout.depthFormat];
        //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformImageView.layer;
        //cameraController.captureVideoPreviewLayer = previewLayer;
        [cameraController currentRawSizes:&imageSize
                             rawDepthSize:&depthSize];
    } else {
        imageSize = currentLayout.sourceImageSize;
        depthSize = CGSizeZero;
    }

//    [taskCtrl updateRawSourceSizes:imageSize depthSize:depthSize];
    screenTasks.targetSize = currentLayout.transformSize;
    thumbTasks.targetSize = currentLayout.thumbImageRect.size;
//    [externalTask newTargetSize:processingSize];
//  externalTask.targetSize = currentLayout.processing.size;
    
    executeScrollView.frame = currentLayout.executeScrollRect;
    
    thumbScrollView.contentOffset = thumbsView.frame.origin;
    [thumbScrollView setContentOffset:CGPointMake(0, 0) animated:YES];

    plusButton.frame = currentLayout.plusRect;
    [UIView animateWithDuration:0.5 animations:^(void) {
        // move views to where they need to be now.
        [self layoutThumbs: self->currentLayout];
    }];
    
    layoutValuesView.frame = transformView.frame;
    [containerView bringSubviewToFront:layoutValuesView];
    NSString *formatList = @"";
    long start = 0;
    long finish = layouts.count;
    for (long i=start; i<finish; i++) {
        if (i > start)
            formatList = [formatList stringByAppendingString:@"\n"];
        NSString *cursor = currentLayout.index == i ? @">" : @" ";
        Layout *layout = layouts[i];
        NSString *line = [NSString stringWithFormat:@"%@%@", cursor, layout.status];
        formatList = [formatList stringByAppendingString:line];
#ifdef DEBUG_LAYOUT
            NSLog(@"%1ld%@%@", i,
                  i == newLayoutIndex ? @"->" : @"  ",
                  [layout layoutSum]);
#endif
    }
    //    [layoutValuesView sizeToFit];
    layoutValuesView.text = formatList;
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;

    NSDictionary *attributes = @{NSFontAttributeName : layoutValuesView.font,
                                   NSParagraphStyleAttributeName: paragraph};
    
    CGRect textRect = [formatList
                       boundingRectWithSize:transformView.frame.size
                       options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                       attributes:attributes
                       context:nil];
    SET_VIEW_HEIGHT(layoutValuesView, textRect.size.height)
    SET_VIEW_WIDTH(layoutValuesView, textRect.size.width);
    [layoutValuesView setNeedsDisplay];
    
    SET_VIEW_WIDTH(mainStatsView, transformView.frame.size.width);
    
    [self updateExecuteView];
    
    if (SOURCE_IS_CAMERA(currentSource)) {
        [self setLive:YES];
    }

    [taskCtrl enableTasks];
    if (fileSourceFrame) {
#ifdef OLD
        [self doTransformsOnFrame:fileSourceFrame];
#endif
        ;
    } else {
        [cameraController startCamera];
    }
    [self updateThumbAvailability];
}

- (void) adjustBarButtons {
    trashBarButton.enabled = screenTask.transformList.count > 0;
    undoBarButton.enabled = screenTask.transformList.count > 0;

#ifdef NOTDEF
    NSString *imageName;
    if (!cameraCount) { // never a camera here
        flipBarButton.enabled = depthBarButton.enabled = NO;
        imageName = @"video";
    } else {
        if (!IS_CAMERA(CURRENT_SOURCE)) {   // not using a camera at the moment
            depthBarButton.enabled = YES;   // to select the camera
            imageName = @"video";
        } else {
            struct camera_t cam = possibleCameras[CURRENT_SOURCE.cameraIndex];
            flipBarButton.image = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath.camera"];
            flipBarButton.enabled = [self flipOfCurrentSource] != NO_SOURCE;
 //           NSLog(@"AAAA flip enabled: %d for front: %d 3d:%d", flipBarButton.enabled, cam.front, cam.threeD);
            depthBarButton.enabled = [self otherDepthOfCurrentSource] != nil;
            imageName = !cam.threeD ? @"view.3d" : @"view.2d";
        }
    }
    depthBarButton.image = [UIImage systemImageNamed:imageName];
#endif
}

// do we have an input camera source that is the flip of the current source?
// search the camera inputs.
- (InputSource *) flipOfCurrentSource {
#ifdef NOTYET
    for (int i=0; i < inputSources.count && SOURCE_IS_CAMERA(SOURCE(i)); i++) {
        if (SOURCE_INDEX_IS_3D(currentSourceIndex) != SOURCE_INDEX_IS_3D(i))
            continue;
        if (SOURCE_INDEX_IS_FRONT(currentSourceIndex) != SOURCE_INDEX_IS_FRONT(i))
            return inputSources[i];
    }
#endif
    return nil;
}

// do we have an input camera source that is the depth alternative to the current source?
// search the camera inputs.
- (InputSource *) otherDepthOfCurrentSource {
    for (int i=0; i < inputSources.count && SOURCE_IS_CAMERA(currentSource); i++) {
        InputSource *otherSource = inputSources[i];
        if (SOURCE_IS_FRONT(otherSource) != SOURCE_IS_FRONT(currentSource))
            continue;
        if (SOURCE_IS_3D (otherSource) != SOURCE_IS_3D(currentSource))
            return otherSource;
    }
    return nil;
}

- (void) nextTransformButtonPosition {
    CGRect f = nextButtonFrame;
    if (RIGHT(f) + SEP + f.size.width > thumbsView.frame.size.width) {   // on to next line
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

- (IBAction) didTapThumb:(UITapGestureRecognizer *)recognizer {
    ThumbView *tappedThumb = (ThumbView *)[recognizer view];
    Transform *tappedTransform = tappedThumb.transform;
    Transform *oldTransform = [screenTask.transformList lastObject];
    
    BOOL firstTransform = (oldTransform == nil);
    if (firstTransform) {
        [screenTask appendTransformToTask:tappedTransform];
        [self checkParamsFor: tappedTransform];
        [tappedThumb adjustStatus:ThumbActive];
        if (plusStatus != PlusLocked) {
            [self changePlusStatusTo:PlusAvailable];
        }
    } else if (plusStatus == PlusSelected || plusStatus == PlusLocked) {
//        [self removeParamsFor: oldTransform];
        ThumbView *oldThumb = oldTransform.thumbView;
        [oldThumb adjustStatus:ThumbAvailable];
        [screenTask appendTransformToTask:tappedTransform];
        [self checkParamsFor:tappedTransform];
        [tappedThumb adjustStatus:ThumbActive];
        if (plusStatus == PlusSelected) {
            plusStatus = PlusAvailable;
            [self adjustPlusStatus];
        }
    } else {    // no plus, just a tap.
        if (tappedThumb.status == ThumbActive) {    // current transform, deselect
//            [self removeParamsFor: tappedTransform];
            [tappedThumb adjustStatus:ThumbAvailable];
            [screenTask removeLastTransform];
            [self adjustPlusStatus];
        } else {    // simply change the current transform
//            [self removeParamsFor: oldTransform];
            ThumbView *oldThumb = oldTransform.thumbView;
            [oldThumb adjustStatus:ThumbAvailable];
            [screenTask changeLastTransformTo:tappedTransform];
            [self checkParamsFor:tappedTransform];
            [tappedThumb adjustStatus:ThumbActive];
       }
    }
    [screenTask configureTaskForSize];
    transformChainChanged = YES;
    [self updateThumbAvailability];
    [self updateExecuteView];
    [self adjustBarButtons];
    [self refreshScreen];
}

- (void) refreshScreen {
    if (SOURCE_IS_CAMERA(currentSource) && live)
        return; // updates when the camera is ready
    Frame *frame = [[Frame alloc] init];
    [frame readImageFromPath:currentSource.imagePath];
    [taskCtrl processFrame:frame];
    [self.view setNeedsDisplay];
}

#ifdef NOTDEF
- (void) removeParamsFor:(Transform *) oldTransform {
    BOOL oldParameters = oldTransform && oldTransform.hasParameters;
    if (!oldParameters)
        return;
#ifdef NOTDEF
#endif
}
#endif

- (void) checkParamsFor:(Transform *) newTransform {
    BOOL newParameters = newTransform && newTransform.hasParameters;
    if (!newParameters) {
        return;
    }
    paramSlider.minimumValue = newTransform.low;
    paramSlider.maximumValue = newTransform.high;
    paramSlider.value = newTransform.value;
    transformChainChanged = YES;
    [self adjustParamView];
//    [UIView animateWithDuration:0.5 animations:^(void) {
 //       SET_VIEW_Y(self->paramView, self->transformView.frame.size.height - self->paramView.frame.size.height);
 //   }];
}

- (IBAction) doPlusTapped:(UIButton *)caller {
    switch (plusStatus) {
        case PlusUnavailable:
            NSLog(@"doPlusTapped: ignored");
            return;
        case PlusAvailable:
            [self changePlusStatusTo:PlusSelected];
            NSLog(@"doPlusTapped: selected");
            break;
        case PlusSelected:
       case PlusLocked:
            NSLog(@"doPlusTapped: oops");
            [self changePlusStatusTo:PlusUnavailable];
            break;
    }
    [self updateExecuteView];
}

- (IBAction) doPlusPressed:(UIButton *)caller {
    NSLog(@"doPlusPressed");
    UILongPressGestureRecognizer *gesture = (UILongPressGestureRecognizer *)caller;
    if (gesture.state != UIGestureRecognizerStateBegan)
        return;
    
    switch (plusStatus) {
        case PlusUnavailable:
        case PlusAvailable:
        case PlusSelected:
            [self changePlusStatusTo:PlusLocked];
            return;
        case PlusLocked:
            [self changePlusStatusTo:PlusUnavailable];
            break;
    }
    [self updateExecuteView];
}

// adjust plus based on current transform list
- (void) adjustPlusStatus {
    switch (plusStatus) {
        case PlusUnavailable:
        case PlusAvailable:
            if (![screenTask.transformList lastObject]) {
                [self changePlusStatusTo:PlusUnavailable];
            }
            return;
        case PlusSelected:
            if (![screenTask.transformList lastObject]) {
                [self changePlusStatusTo:PlusUnavailable];
            }
            return;
        case PlusLocked:
            return;
    }
}

#define PLUS_UNLOCKED_BORDER_W  (isiPhone ? 1.0 : 2.0)
#define PLUS_LOCKED_BORDER_W  (isiPhone ? 3.0 : 7.0)

- (void) changePlusStatusTo:(PlusStatus_t) newStatus {
//    NSLog(@"new plus status: %@ -> %@", plusStatusNames[plusStatus],
//          plusStatusNames[newStatus]);
    UIFontWeight weight;
    UIColor *color = [UIColor blackColor];
    NSString *plusString = @"+";
    
    plusButton.layer.borderWidth = PLUS_UNLOCKED_BORDER_W;
    switch (newStatus) {
        case PlusUnavailable:
            weight = UIFontWeightLight;
            color = [UIColor lightGrayColor];
            break;
        case PlusAvailable:
            weight = UIFontWeightRegular;
            break;
        case PlusSelected:
            weight = UIFontWeightBold;
            break;
        case PlusLocked:
            plusButton.layer.borderWidth = PLUS_LOCKED_BORDER_W;
            weight = UIFontWeightBold;
            break;
    }
    
    plusStatus = newStatus;
    UIFont *font = [UIFont
                    systemFontOfSize:PLUS_H
                    weight:weight];
    [plusButton setAttributedTitle:[[NSAttributedString alloc]
                                    initWithString:plusString
                                    attributes:@{ NSFontAttributeName : font,
                                                  NSForegroundColorAttributeName: color,
                                               }] forState:UIControlStateNormal];
    [plusButton setNeedsDisplay];
}

// If the camera is off, turn it on, to the first possible setting,
// almost certainly the front camera, 2d. //  Otherwise, change the depth.

- (IBAction) doCamera:(UIBarButtonItem *)caller {
#ifdef NOTYET
    if (!CURRENT_SOURCE_IS_CAMERA) { // select default camera
        nextSourceIndex = 0;
    } else {
        long ci = CURRENT_SOURCE.cameraIndex;
        nextSourceIndex = 0;
        do {
#ifdef DEBUG_FORMAT
            [self dumpInputCameraSources];
#endif
            InputSource *s = inputSources[nextSourceIndex];
            long nci = s.cameraIndex;
            assert(nci != NOT_A_CAMERA);
            if (possibleCameras[nci].front == possibleCameras[ci].front)
                break;
            nextSourceIndex++;
        } while (nextSourceIndex < N_POSS_CAM);
        assert(nextSourceIndex < N_POSS_CAM); // this loop should never be called unless there is a useful answer
    }
    [taskCtrl idleFor:NeedsNewLayout];
#endif
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

// pause/unpause video
- (IBAction) togglePauseResume:(UITapGestureRecognizer *)recognizer {
    assert(SOURCE_IS_CAMERA(currentSource));
    [self liveOn:!live];
}

- (void) liveOn:(BOOL) state {
    live = state;
#ifdef DEBUG_RECONFIGURATION
    NSLog(@"DR live: %@", state ? @"ON" : @"OFF");
#endif
    if (live) {
        fileSourceFrame = nil;
        runningButton.selected = NO;
        [runningButton setNeedsDisplay];
//        [taskCtrl idleTransforms];
        [runningButton setImage:[self fitImage:[UIImage systemImageNamed:@"pause.fill"]
                                            toSize:runningButton.frame.size centered:YES]
                           forState:UIControlStateNormal];
        [cameraController startCamera];
    } else {
        [cameraController stopCamera];
        [runningButton setImage:[self fitImage:[UIImage systemImageNamed:@"play.fill"]
                                            toSize:runningButton.frame.size centered:YES]
                           forState:UIControlStateNormal];
        if (taskCtrl.lastFrame)
            [taskCtrl processFrame:taskCtrl.lastFrame];
    }
    [runningButton setNeedsDisplay];
    [self adjustControls];
}

// tapping transform presents or clears the controls
- (IBAction) didTapTransformView:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded)
        return;
    showControls = !showControls;
    [self adjustControls];
    [self refreshScreen];
}

// debug: create a pnm file from current live image, and email it

- (IBAction) didLongPressTransformView:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded)
        return;
    showStats = !showStats;
    mainStatsView.hidden = !showStats;
    [mainStatsView setNeedsDisplay];
    [self updateExecuteView];
//    layoutValuesView.hidden = !layoutValuesView.hidden;
//    [self didTapTransformView:recognizer];
}

#define MAIL_HOME   @"ches@cheswick.com"

- (void) doMail:(NSString *)imageFilePath {
    if (![MFMailComposeViewController canSendMail]) {
       NSLog(@"Mail services are not available.");
       return;
    }
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setToRecipients:[NSArray arrayWithObject:MAIL_HOME]];
    NSString *emailTitle = [NSString
                            stringWithFormat:@"DigitalDarkroom image"];
    [mc setSubject:emailTitle];
    [mc setMessageBody:@"ASCII image data from the DigitalDarkroom" isHTML:NO];
    NSData *imageData = [NSData dataWithContentsOfFile:imageFilePath];
    [mc addAttachmentData:imageData mimeType:@"image/text" fileName:@"DD image"];
    [self presentViewController:mc animated:YES completion:NULL];
}

- (void) mailComposeController:(MFMailComposeViewController *)controller
           didFinishWithResult:(MFMailComposeResult)result
                         error:(NSError *)error {
    if (error)
        NSLog(@"mail error %@", [error localizedDescription]);
    switch (result) {
        case MFMailComposeResultCancelled:
            break;
        case MFMailComposeResultSaved:
            break;
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed: {
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@"Mail failed"
                                         message:[error localizedDescription]
                                         preferredStyle:UIAlertControllerStyleAlert];
            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
        default:
            NSLog(@"inconceivable: unknown mail result %ld", (long)result);
            break;
    }
    
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void) adjustControls {
    runningButton.enabled = SOURCE_IS_CAMERA(currentSource);
    runningButton.hidden = !showControls;
    snapButton.hidden = !showControls;
    [runningButton setNeedsDisplay];
}

- (IBAction)doParamSlider:(UISlider *)slider {
    assert(!paramView.hidden);
    Transform *lastTransform = LAST_TRANSFORM_IN_TASK(screenTask);
//    NSLog(@"slider value %.1f", slider.value);
    if (lastTransform && lastTransform.hasParameters) {
        if ([screenTask updateParamOfLastTransformTo:paramSlider.value]) {
            transformChainChanged = YES;
        }
    }
    [self adjustParamView];
}

- (void) adjustParamView {
    Transform *lastTransform = LAST_TRANSFORM_IN_TASK(screenTask);
    CGFloat paramDeltaY = 0;
    if (!lastTransform || !lastTransform.hasParameters) {
        if (!paramView.hidden) {    // hide param view
            paramDeltaY -= self->paramView.frame.size.height + SEP;
            paramView.hidden = YES;
        }
    } else if (lastTransform && lastTransform.hasParameters) {
        if (paramView.hidden) { // reveal param view
            paramDeltaY += self->paramView.frame.size.height + SEP;
            paramView.hidden = NO;
        }
        paramLabel.textColor = [UIColor blackColor];
        [paramLabel setNeedsDisplay];
        if (transformChainChanged) {
            paramLabel.text = [NSString stringWithFormat:@"%@:    %@: %.0f",
                               lastTransform.name,
                               lastTransform.paramName,
                               paramSlider.value];
            [paramSlider setNeedsDisplay];
            [paramView setNeedsDisplay];
            [self refreshScreen];
        }
    }
    [UIView animateWithDuration:0.5 animations:^(void) {
        // slide old parameters off the bottom of the display
        SET_VIEW_Y(self->paramView, self->paramView.frame.origin.y + paramDeltaY);
        SET_VIEW_Y(self->plusButton, BELOW(self->paramView.frame) + SEP);
        SET_VIEW_Y(self->executeScrollView, BELOW(self->plusButton.frame) + SEP);
        SET_VIEW_HEIGHT(self->executeScrollView,
                        self->containerView.frame.size.height -
                        self->executeScrollView.frame.origin.y);
    } completion:^(BOOL finished) {
        self->paramView.hidden = YES;
    }];
}

- (IBAction) didThreeTapSceen:(UITapGestureRecognizer *)recognizer {
    NSLog(@"did three-tap screen: save image and screen");
}

- (IBAction) doHelp:(UIView *)caller {
    UIView *sourceView = nil;
    NSString *helpPath = nil;
    
    if ([caller isKindOfClass:[UILongPressGestureRecognizer class]]) {
        UILongPressGestureRecognizer *gesture = (UILongPressGestureRecognizer *)caller;
        if (gesture.state != UIGestureRecognizerStateBegan)
            return;
        ThumbView *thumbView = (ThumbView *)gesture.view;
        sourceView = thumbView;
        
        Transform *transform = thumbView.transform;
        helpPath = transform.helpPath;
        if (!helpPath) {
            UILabel *thumbLabel = [thumbView viewWithTag:THUMB_LABEL_TAG];
            if (thumbLabel) {
                helpPath = thumbLabel.text;
            }
        }
    } else {    // calleed from the "?" bar button
        helpPath = nil;
    }
    
    HelpVC *hvc = [[HelpVC alloc] initWithSection:helpPath];
//    hvc.preferredContentSize = CGSizeMake(100, 200);
    
    UINavigationController *helpNavVC = [[UINavigationController alloc]
                                                 initWithRootViewController:hvc];
    helpNavVC.navigationController.navigationBarHidden = NO;
    helpNavVC.modalPresentationStyle = UIModalPresentationPopover;

    UIPopoverPresentationController *popController = helpNavVC.popoverPresentationController;
    popController.delegate = self;
    
    if (sourceView) {
        popController.sourceView = sourceView;
    } else {
        popController.barButtonItem = (UIBarButtonItem *)caller;
    }
    [self presentViewController:helpNavVC animated:YES completion:nil];
}

- (IBAction) doShare:(UIBarButtonItem *)shareButton {
    NSArray *items = @[transformView.image]; // build an activity view controller
    UIActivityViewController *activityController = [[UIActivityViewController alloc]
                                                    initWithActivityItems:items
                                                    applicationActivities:nil];
    // exclude the ones we want to be displayed:
    activityController.excludedActivityTypes = @[
        UIActivityTypeAddToReadingList,
        UIActivityTypeOpenInIBooks,
        UIActivityTypePostToVimeo,
        UIActivityTypeMarkupAsPDF,
        @"com.apple.mobilenotes.SharingExtension",
        @"com.apple.reminders.RemindersEditorExtension"
    //      UIActivityTypeAssignToContact,
    //      UIActivityTypePrint,
    //      UIActivityTypeSaveToCameraRoll,
    //  UIActivityTypePostToFacebook,
    //  UIActivityTypePostToTwitter,
    //  UIActivityTypePostToWeibo,
    //  UIActivityTypePostToTencentWeibo
    //  UIActivityTypeCopyToPasteboard,
    //  UIActivityTypePostToFlickr,
    //  UIActivityTypeMail,
    //  UIActivityTypeMessage,
    //  UIActivityTypeAirDrop,
    ];
    activityController.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:activityController animated:YES completion:^{
        
    }];
    
    UIPopoverPresentationController *popController = [activityController popoverPresentationController];
    popController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    popController.barButtonItem = shareButton;

  // access the completion handler
    activityController.completionWithItemsHandler = ^(NSString *activityType,
                                                      BOOL completed,
                                                      NSArray *returnedItems,
                                                      NSError *error) {
        // react to the completion
        if (completed) {
            // user shared an item
            NSLog(@"We used activity type%@", activityType);
        } else {
            // user cancelled
            NSLog(@"We didn't want to share anything after all.");
        }
        if (error) {
            NSLog(@"An Error occured: %@, %@", error.localizedDescription, error.localizedFailureReason);
        }
    };
}

#ifdef NOTDEF
- (IBAction) didLongPressScreen:(UILongPressGestureRecognizer *)recognizer {
    // XXXXX use this for something else
    if (recognizer.state != UIGestureRecognizerStateBegan)
        return;
    options.reticle = !options.reticle;
    [options save];
}
#endif

- (IBAction) didLongPressExecute:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan)
        return;
    options.executeDebug = !options.executeDebug;
    [options save];
    NSLog(@" debugging execute: %d", options.executeDebug);
    [self updateExecuteView];
}

-(void) flash {
    flashView.frame = transformView.frame;
    flashView.hidden = NO;
    flashView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    [containerView bringSubviewToFront:flashView];
    [UIView animateWithDuration:0.40 animations:^(void) {
        self->flashView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0];
    } completion:^(BOOL finished) {
        self->flashView.hidden = YES;
        [self->containerView sendSubviewToBack:self->flashView];
    }];
}

// this should be copy to paste buffer, or the send-it-out option
- (IBAction) doSave {
    UIImageWriteToSavedPhotosAlbum(transformView.image, nil, nil, nil);
    [self flash];

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

- (UIImage *)fitImage:(UIImage *)image
               toSize:(CGSize)size
             centered:(BOOL) centered {
    CGRect scaledRect;
    scaledRect.size = [Layout fitSize:image.size toSize:size];
    scaledRect.origin = CGPointZero;
    if (centered) {
        scaledRect.origin.x = (size.width - scaledRect.size.width)/2.0;
        scaledRect.origin.y = (size.height - scaledRect.size.height)/2.0;
    }
    
//    NSLog(@"scaled image at %.0f,%.0f  size: %.0fx%.0f",
//          scaledRect.origin.x, scaledRect.origin.y,
//          scaledRect.size.width, scaledRect.size.height);
    
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

#ifdef OLD
#define IMAGE_DUMP_FILE @"ImageDump"

- (void) doTransformsOnFrame:(Frame *)frame {
    if (!frame)
        return;
    if (imageDumpRequested) {
        NSString *tmpImageFile = [NSTemporaryDirectory() stringByAppendingPathComponent:IMAGE_DUMP_FILE];
        
        if (![[NSFileManager defaultManager] createFileAtPath:tmpImageFile contents:NULL attributes:NULL]) {
            NSLog(@"tmp create failed, inconceivable");
            return;
        }
        NSFileHandle *imageFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:tmpImageFile];
        [screenTasks executeTasksWithFrame:frame
                                  dumpFile:(NSFileHandle *)imageFileHandle];
        [imageFileHandle closeFile];
        imageDumpRequested = NO;
        [self doMail:tmpImageFile];
        return;
    }
    
    // update the screen with transforms on the incoming image
    [frame.depthBuf verifyDepths];
    Frame *displayedFrame = [screenTasks executeTasksWithFrame:frame dumpFile:nil];
    if (displayedFrame) {
        lastDisplayedFrame = displayedFrame;
    }
    if (transformChainChanged)
        [self updateThumbAvailability];
    
    if (displayedFrame)
        [thumbTasks executeTasksWithFrame:displayedFrame dumpFile:nil];
    if (cameraSourceThumb) {
        [cameraSourceThumb setImage:[frame toUIImage]];
        [cameraSourceThumb setNeedsDisplay];
    }
}
#endif

- (IBAction) didPressVideo:(UILongPressGestureRecognizer *)recognizer {
    NSLog(@" === didPressVideo");
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        NSLog(@"video long press");
    }
}

- (IBAction) doRemoveAllTransforms {
    [screenTasks removeAllTransforms];
    [self deselectAllThumbs];
    [self adjustPlusStatus];
//    transformDisplayNeedsUpdate = YES;
//    [self updateOverlayView];
    [self updateExecuteView];
    [self adjustBarButtons];
    [self reloadSourceImage];
}

- (void) deselectAllThumbs {
    for (ThumbView *thumbView in thumbViewsArray) {
        // deselect all selected thumbs
        if (thumbView.status == ThumbActive) {
            [thumbView adjustStatus:ThumbAvailable];
        }
    }
}

- (IBAction) doToggleHires:(UIBarButtonItem *)button {
    options.needHires = !options.needHires;
    NSLog(@" === high res now %d", options.needHires);
    [options save];
    button.style = options.needHires ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
}

- (void) doTick:(NSTimer *)sender {
//    [taskCtrl checkReadyForLayout];
    NSString *taskStats = [taskCtrl stats];
    mainStatsView.text = [stats report:taskStats];
    [mainStatsView setNeedsDisplay];
    // needs to update execute view, not layout
//    if (showStats)
//        [self updateExecuteView];
//    [taskCtrl checkForIdle];
    if (showStats)
        self.title = [NSString stringWithFormat:@"\"%@\",    layout %ld/%lu  %@",
                      currentSource.label,
                      currentLayout.index, (unsigned long)layouts.count,
                      currentLayout.type];

#ifdef OLD
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
    if (screenTask.transformList.count) {
        Transform *lastTransform = screenTask.transformList[screenTask.transformList.count - 1];
        ThumbView *thumbView = [self thumbForTransform:lastTransform];
        [thumbView adjustStatus:ThumbAvailable];
        [screenTask removeLastTransform];
        // XXXXXX transformDisplayNeedsUpdate [self doTransformsOnFrame:currentSourceFrame];
//        [self updateOverlayView];
        [self updateExecuteView];
        [self adjustBarButtons];
    }
}

- (ThumbView *) thumbForTransform:(Transform *) transform {
    return [thumbsView viewWithTag:TRANSFORM_BASE_TAG + transform.transformsArrayIndex];
}

//
// The executeView is the source name followed by a list of transforms.
//
// There could be a regular list mode, and a compressed
// mode for small, tight screens or long lists of transforms (which should be rare.)
//
// we update the plus button here, too.


- (void) updateExecuteView {
    [self adjustParamView];
    
    int plusIndex = (int)[self nextTransformTapIndex];
    int activeSteps = (int)screenTask.transformList.count;
    BOOL plusActive = (plusStatus == PlusSelected || plusStatus == PlusLocked);
    
    int totalLines = activeSteps;
    if (plusActive || activeSteps == 0)
        // room for next plus, or first transform if not there yet
        totalLines++;

    int maxLinesVisible = executeScrollView.frame.size.height / executeLabelH;
    assert(maxLinesVisible >= 1);
    
    int linesVisible;
    CGPoint offset = CGPointMake(0, LATER);
    if (totalLines >= maxLinesVisible) {
        linesVisible = maxLinesVisible;
        offset.y += (totalLines - maxLinesVisible) * executeLabelH;
    } else {
        linesVisible = totalLines;
        offset.y = 0;
    }
    
    // fresh view to scroll....
    NSArray *viewsToRemove = [executeScrollView subviews];
    for (UIView *v in viewsToRemove) {
        [v removeFromSuperview];
    }
    UIView *executeView = [[UIView alloc]
                           initWithFrame:CGRectMake(0, 0,
                                                    executeScrollView.frame.size.width,
                                                    totalLines*executeLabelH)];
    [executeScrollView addSubview:executeView];
    
    SET_VIEW_HEIGHT(executeScrollView, linesVisible*executeLabelH);
    [executeScrollView setContentSize:CGSizeMake(executeScrollView.frame.size.width, totalLines*executeLabelH)];
    [executeScrollView setContentOffset:offset animated:YES];
    
    if ((YES) || (!currentLayout.executeIsTight)) {
        CGFloat execFontW = execFontSize*0.9;       // rough approximation
        int startLine = totalLines - linesVisible;
        for (int line=startLine; line < totalLines; line++) {
            UIView *execLine = [[UIView alloc]
                                initWithFrame:CGRectMake(2*INSET, (line - startLine)*executeLabelH,
                                                         executeView.frame.size.width - 2*2*INSET,
                                                         executeLabelH)];
            execLine.tag = line;
            int step = line;
            
            UILabel *ptr = [[UILabel alloc]
                            initWithFrame:CGRectMake(2*INSET, 0,
                                                     2*execFontW,
                                                     executeLabelH)];
            ptr.text = (plusIndex == step) ? POINTING_HAND : @"";
            ptr.font = [UIFont systemFontOfSize:execFontSize];
            [execLine addSubview:ptr];
            
            CGFloat descTextLen;
            if (showStats && step < activeSteps) {
                CGFloat w = EXEC_STATS_W_CHARS*execFontW;
                UILabel *statsLabel = [[UILabel alloc]
                                       initWithFrame:CGRectMake(execLine.frame.size.width - w, 0,
                                                                w, executeLabelH)];
                statsLabel.font = [UIFont fontWithName:@"Courier" size:execFontSize];
                statsLabel.textAlignment = NSTextAlignmentRight;
                TransformInstance *instance = [screenTask instanceForStep:step];
                statsLabel.text = instance.timesCalled ? [instance timeInfo] : @"";
                [execLine addSubview:statsLabel];
                descTextLen = statsLabel.frame.origin.x - RIGHT(ptr.frame);
            } else
                descTextLen = execLine.frame.size.width - RIGHT(ptr.frame);
            
            UILabel *desc = [[UILabel alloc]
                             initWithFrame:CGRectMake(RIGHT(ptr.frame) + SEP, 0,
                                                      descTextLen, executeLabelH)];
            desc.font = [UIFont systemFontOfSize:execFontSize];
            if (step < activeSteps) {
                desc.text = [screenTask displayInfoForStep:step shortForm:NO];
            } else
                desc.text = @"";
            [execLine addSubview:desc];
            if (plusIndex == step) {
                execLine.layer.borderWidth = 0.50;
                execLine.layer.borderColor = [UIColor darkGrayColor].CGColor;
            } else {
                execLine.layer.borderWidth = 0.10;
                execLine.layer.borderColor = [UIColor lightGrayColor].CGColor;
            }
            [execLine setNeedsDisplay];
            [executeView addSubview:execLine];
        }
    }else {    // compressed layout. XXX: STUB
        //        executeView.text = text;
    }
    [executeScrollView setNeedsDisplay];
}

- (size_t) nextTransformTapIndex {
    switch (plusStatus) {
        case PlusUnavailable:
        case PlusAvailable:
            if (screenTask.transformList.count)
                return screenTask.transformList.count - 1;
            return 0;
        case PlusSelected:
        case PlusLocked:
            return screenTask.transformList.count;
    }
}

static CGSize startingPinchSize;

- (IBAction) doPinch:(UIPinchGestureRecognizer *)pinch {
    if (!currentLayout) {
        NSLog(@"pinch ignored, no layout available");
        return;
    }
    switch (pinch.state) {
        case UIGestureRecognizerStateBegan:
            startingPinchSize = currentLayout.displayRect.size;
            break;
        case UIGestureRecognizerStateEnded: {
            float currentScale = currentLayout.displayFrac;
            NSUInteger i;
            if (pinch.scale < 1.0) {    // go smaller
                float targetScale = currentScale*pinch.scale;
                for (i=currentLayout.index + 1; i < layouts.count; i++)
                    if (layouts[i].displayFrac <= targetScale)
                        break;
                if (i >= layouts.count)
                    i = layouts.count - 1;
            } else {
                float targetScale = currentScale + 0.1 * trunc(pinch.scale);
                for (i=currentLayout.index - 1; i >= 0; i--)
                    if (layouts[i].displayFrac >= targetScale)
                        break;
                if (i < 0)
                    i = 0;
            }
            nextLayout = layouts[i];
            [taskCtrl suspendTasksForDisplayUpdate];
            break;
        }
        default:
            return;
    }
}

- (IBAction) doRight:(UISwipeGestureRecognizer *)sender {
    NSLog(@"doRight");
    [self doSave];
}

- (IBAction) doLeft:(UISwipeGestureRecognizer *)sender {
    NSLog(@"doLeft");
#define PHOTO_APP_URL   @"photo-redirect://"
    NSURL *URL = [NSURL URLWithString:PHOTO_APP_URL];
    [[UIApplication sharedApplication] openURL:URL
                                       options:@{}
                             completionHandler:^(BOOL success) {
        NSLog(@"photo app open success: %d", success);
    }];
}

#ifdef NOTDEF
- (IBAction) doUp:(UISwipeGestureRecognizer *)sender {
    NSLog(@"doUp");
    [self updateExecuteView];
}

- (IBAction) doDown:(UISwipeGestureRecognizer *)sender {
    NSLog(@"doDown");
    [self updateExecuteView];
}
#endif

- (IBAction) flipCamera:(UIButton *)button {
    NSLog(@"flip camera tapped");
    nextSource = [self flipOfCurrentSource];
    assert(nextSource);
    [taskCtrl suspendTasksForDisplayUpdate];
}

- (IBAction) processDepthSwitch:(UISwitch *)depthsw {
    NSLog(@"change camera deoth");
    InputSource *otherDepth = [self otherDepthOfCurrentSource];
    if (!otherDepth)
        return;
    nextSource = otherDepth;
    [taskCtrl suspendTasksForDisplayUpdate];
}

- (void) reloadSourceImage {
    if (!currentSource)
        return;
   if (SOURCE_IS_CAMERA(currentSource) && live)
       return;  // no need: the camera will refresh
    [taskCtrl suspendTasksForDisplayUpdate];    // XXXX is this needed?
    transformChainChanged = YES;
}

- (IBAction) selectOptions:(UIButton *)button {
    OptionsVC *oVC = [[OptionsVC alloc] initWithOptions:options];
    UINavigationController *optionsNavVC = [[UINavigationController alloc]
                                            initWithRootViewController:oVC];
    [self presentViewController:optionsNavVC
                       animated:YES
                     completion:^{
        [self adjustBarButtons];
        self->currentLayout = nil;   // XXX is this right?  Is this what options change?
        [self->taskCtrl suspendTasksForDisplayUpdate];    // XXXX
    }];
}

CGSize sourceCellImageSize;
CGFloat sourceFontSize;
CGFloat sourceLabelH;
CGSize sourceCellSize;

#define SELECTION_CELL_ID  @"fileSelectCell"
#define SELECTION_HEADER_CELL_ID  @"fileSelectHeaderCell"

- (IBAction) selectSourceFromMenu:(UIBarButtonItem *)button {
    float scale = isiPhone ? SOURCE_IPHONE_SCALE : 1.0;
    sourceCellImageSize = CGSizeMake(SOURCE_THUMB_W*scale,
                                     SOURCE_THUMB_W*scale/currentLayout.aspectRatio);
    sourceFontSize = SOURCE_THUMB_FONT_H*scale;
    sourceLabelH = 2*(sourceFontSize + 2);
    sourceCellSize = CGSizeMake(sourceCellImageSize.width,
                                sourceCellImageSize.height + sourceLabelH);
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.sectionInset = UIEdgeInsetsMake(2*INSET, 2*INSET, INSET, 2*INSET);
    flowLayout.itemSize = sourceCellSize;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    //flowLayout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);
    //flowLayout.minimumInteritemSpacing = 16;
    //flowLayout.minimumLineSpacing = 16;
    flowLayout.headerReferenceSize = CGSizeMake(0, COLLECTION_HEADER_H);
    
    UICollectionView *collectionView = [[UICollectionView alloc]
                                        initWithFrame:containerView.frame
                                        collectionViewLayout:flowLayout];
    collectionView.dataSource = self;
    collectionView.delegate = self;
    collectionView.tag = sourceCollection;
    [collectionView registerClass:[UICollectionViewCell class]
       forCellWithReuseIdentifier:SELECTION_CELL_ID];
    collectionView.backgroundColor = [UIColor whiteColor];
    
    [collectionView registerClass:[CollectionHeaderView class]
       forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
              withReuseIdentifier:SELECTION_HEADER_CELL_ID];
    
    UIViewController __block *cVC = [[UIViewController alloc] init];
    cVC.view = collectionView;
    cVC.modalPresentationStyle = UIModalPresentationPopover;
    
    sourcesNavVC = [[UINavigationController alloc]
                    initWithRootViewController:cVC];
    cVC.title = @"Select source";
    cVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithTitle:@"Dismiss"
                                                style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(dismissSourceVC:)];

    [self presentViewController:sourcesNavVC animated:YES completion:nil];
}

- (IBAction) dismissSourceVC:(UIBarButtonItem *)dismissButton {
    cameraSourceThumb = nil;
    [sourcesNavVC dismissViewControllerAnimated:YES
                                     completion:NULL];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return N_SOURCES;
}

static NSString * const sourceSectionTitles[] = {
    [FrontCameraSource] = @"    Front Camera",
    [BackCameraSource] =  @"    Back Camera",
    [SampleSource] =      @"    Samples",
    [LibrarySource] =     @"    From library",
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
    switch ((SourceTypes) section) {
        case FrontCameraSource:
            return cameraController.frontCameras.count;
        case BackCameraSource:
            return cameraController.backCameras.count;
       case SampleSource:
            return inputSources.count;
        case LibrarySource:
            return 0;   // XXX not yet
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return sourceCellSize;
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

    f.size = sourceCellImageSize;
    UIImageView *thumbImageView = [[UIImageView alloc] initWithFrame:f];
    thumbImageView.layer.borderWidth = 1.0;
    thumbImageView.layer.borderColor = [UIColor blackColor].CGColor;
    thumbImageView.layer.cornerRadius = 4.0;
    [cellView addSubview:thumbImageView];
    
    f.origin.y = BELOW(f);
    f.size.height = sourceLabelH;
    UILabel *thumbLabel = [[UILabel alloc] initWithFrame:f];
    thumbLabel.lineBreakMode = NSLineBreakByWordWrapping;
    thumbLabel.numberOfLines = 0;
    thumbLabel.adjustsFontSizeToFitWidth = YES;
    thumbLabel.textAlignment = NSTextAlignmentCenter;
    thumbLabel.font = [UIFont systemFontOfSize:sourceFontSize];
    thumbLabel.textColor = [UIColor blackColor];
    thumbLabel.backgroundColor = [UIColor whiteColor];
    [cellView addSubview:thumbLabel];
    
    switch ((SourceTypes)indexPath.section) {
        case FrontCameraSource:
            cameraSourceThumb = thumbImageView;
            thumbLabel.text = @"Front Cameras";
            break;
        case BackCameraSource:
            cameraSourceThumb = thumbImageView;
            thumbLabel.text = @"Back Cameras";
            break;
        case SampleSource: {
            InputSource *source = [inputSources objectAtIndex:indexPath.row];
            thumbLabel.text = source.label;
            UIImage *sourceImage = [UIImage imageWithContentsOfFile:source.imagePath];
            if (source.thumbImageCache)
                thumbImageView.image = source.thumbImageCache;
            else {
                source.thumbImageCache = [self fitImage:sourceImage
                                                 toSize:thumbImageView.frame.size
                                               centered:YES];
                thumbImageView.image = source.thumbImageCache;
            }
            break;
        }
        case LibrarySource:
            ; // XXX stub
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    nextSource = inputSources[indexPath.row];
    [sourcesNavVC dismissViewControllerAnimated:YES completion:^(void) {
        [self->taskCtrl suspendTasksForDisplayUpdate];
    }];
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
        self->currentLayout = nil;   // force new layout after option change
        [self->taskCtrl suspendTasksForDisplayUpdate];
    }];
}


// update the thumbs to show which are available for the end of the new transform chain
// displayedFrame has the source frame.  if nil?
- (void) updateThumbAvailability {
    for (ThumbView *thumbView in thumbViewsArray) {
        [thumbView adjustThumbEnabled];
    }
    transformChainChanged = NO;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray *)keyCommands {
    UIKeyCommand *uKey = [UIKeyCommand keyCommandWithInput:@"u" // UIKeyInputUpArrow
                                                modifierFlags:0
                                                       action:@selector(upLayout:)];
    UIKeyCommand *dKey = [UIKeyCommand keyCommandWithInput:@"d" // UIKeyInputDownArrow
                                                  modifierFlags:0
                                                         action:@selector(downLayout:)];
    UIKeyCommand *spaceKey = [UIKeyCommand keyCommandWithInput:@" " // UIKeyInputDownArrow
                                                  modifierFlags:0
                                                         action:@selector(cycleLayout:)];
    return @[uKey, dKey, spaceKey];
}

- (void)upLayout:(UIKeyCommand *)keyCommand {
    if (![self keyTimeOK])
        return;
    if (currentLayout.index == 0)
        return;
    nextLayout = layouts[currentLayout.index - 1];
    [taskCtrl suspendTasksForDisplayUpdate];
}

- (void)downLayout:(UIKeyCommand *)keyCommand {
    if (![self keyTimeOK])
        return;
    if (currentLayout.index+1 >= layouts.count)
        return;
    nextLayout = layouts[currentLayout.index + 1];
    [taskCtrl suspendTasksForDisplayUpdate];
}

- (void)cycleLayout:(UIKeyCommand *)keyCommand {
    if (![self keyTimeOK])
        return;
    nextLayout = layouts[(currentLayout.index + 1) % layouts.count];
    [taskCtrl suspendTasksForDisplayUpdate];
}

NSDate *lastArrowKeyNotice = 0;
#define KEY_TIME    0.15    // suppress duplicate presses

- (BOOL) keyTimeOK {
    NSDate *now = [NSDate now];
    if (lastArrowKeyNotice && [now timeIntervalSinceDate:lastArrowKeyNotice] < KEY_TIME) {
        lastArrowKeyNotice = now;
        return NO;
    }
    lastArrowKeyNotice = now;
    return YES;
}

- (void) dumpInputCameraSources {
    NSLog(@"Camera sources:");
    for (long i=0; i < inputSources.count && SOURCE_IS_CAMERA(currentSource); i++) {
        InputSource *source = SOURCE(i);
        
        NSLog(@"  %@   %2ld  si %d   %@  %@",
              (i == currentSource.sourceIndex) ? @"->" : @"  ",
              i, SOURCE(i).sourceIndex,
              SOURCE_IS_FRONT(source) ? @"front" : @"rear ",
              SOURCE_IS_3D(source) ? @"3D" : @"2D"
        );
    }
}

@end

#ifdef OLD
- (NSMutableArray<Layout *> *) selectLayoutsByFormats {
    NSMutableArray *usableFormats = [[NSMutableArray alloc] init];
    
    assert(cameraController);
    [self selectCurrentCamera];
    
    for (AVCaptureDeviceFormat *format in cameraController.formatList) {
        if (cameraController.depthDataAvailable) {
            // at the moment, accept all formats if depth is not an issue
            [usableFormats addObject:format];
            continue;
        }
        if (!format.supportedDepthDataFormats || !format.supportedDepthDataFormats.count))
            // depth available, but not for this format, skip it
            continue;
        
        // must have a suitable depth available
        NSArray<AVCaptureDeviceFormat *> *depthFormats = currentLayout.format.supportedDepthDataFormats;
        for (AVCaptureDeviceFormat *depthFormat in depthFormats) {
            if (![CameraController depthFormat:depthFormat isSuitableFor:currentLayout.format])
                continue;
            break;
        }
    }
    
    if (! == 0)
        continue;   // we want depth if needed and available
}

#ifdef DEBUG_LAYOUT
NSLog(@" *** findLayouts: %lu", (unsigned long)layouts.count);
[self dumpLayouts];

#endif

}
if (currentLayout.format) {
    // find best depth format for this.  Must have same aspect ratio, and correct type.
    NSArray<AVCaptureDeviceFormat *> *depthFormats = currentLayout.format.supportedDepthDataFormats;
    currentLayout.depthFormat = nil;
    for (AVCaptureDeviceFormat *depthFormat in depthFormats) {
        if ([CameraController depthFormat:depthFormat isSuitableFor:currentLayout.format]) {
            currentLayout.depthFormat = depthFormat;
//                    NSLog(@"DDDD 1 >>    %@", depthFormat.formatDescription);
            NSLog(@"LLL layout %d has depth", i);
            break;
        }
    }
}
#endif
