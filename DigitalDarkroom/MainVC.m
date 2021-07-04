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
#import "ReticleView.h"
#import "Layout.h"
#import "HelpVC.h"
#import "Defines.h"

#define HAVE_CAMERA (cameraController != nil)

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

#ifdef OLD
#define SOURCE_THUMB_H  SOURCE_THUMB_W
#define SOURCE_BUTTON_FONT_SIZE 20
#define SOURCE_LABEL_H  (2*TABLE_ENTRY_H)

#define SOURCE_CELL_W   SOURCE_THUMB_W
#define SOURCE_CELL_H   (SOURCE_THUMB_H + SOURCE_LABEL_H)
#define SOURCE_CELL_IPHONE_SCALE    0.75
#endif

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

#define EXECUTE_STATS_TAG   1

#define DEPTH_TABLE_SECTION     0

#define NO_STEP_SELECTED    -1
#define NO_LAYOUT_SELECTED   (-1)

#define DEPTH_AVAILABLE (IS_CAMERA(self->currentSource) && self->currentSource.cameraHasDepthMode)
#define DISPLAYING_THUMBS   (self->thumbScrollView && self->thumbScrollView.frame.size.width > 0)

#define PAUSED      (IS_CAMERA(currentSource) && !pausedLabel.hidden)
#define LIVE        (currentSource && !PAUSED)

typedef enum {
    TransformTable,
    ActiveTable,
} TableTags;

typedef enum {
    sourceCollection,
    transformCollection
} CollectionTags;

typedef enum {
    CameraSource,
    SampleSource,
    LibrarySource,
} SourceTypes;
#define N_SOURCES 3

typedef enum {
    overlayClear,
    overlayShowing,
    overlayShowingDebug,
} OverlayState;
#define OVERLAY_STATES  (overlayShowingDebug+1)


@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   Options *options;

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   TaskGroup *screenTasks; // only one task in this group
@property (nonatomic, strong)   TaskGroup *thumbTasks, *depthThumbTasks;
@property (nonatomic, strong)   TaskGroup *externalTasks;   // not yet, only one task in this group
@property (nonatomic, strong)   TaskGroup *hiresTasks;       // not yet, only one task in this group

@property (nonatomic, strong)   Task *screenTask;
@property (nonatomic, strong)   Task *externalTask;

@property (nonatomic, strong)   UIView *containerView;

@property (nonatomic, strong)   UIBarButtonItem *flipBarButton;
@property (nonatomic, strong)   UIBarButtonItem *sourceBarButton;
@property (nonatomic, strong)   UIBarButtonItem *reticleBarButton;

@property (nonatomic, strong)   UISwitch *depthSwitch;

// in containerview:
@property (nonatomic, strong)   UIView *overlayView;        // transparency over transformView
@property (assign)              OverlayState overlayState;
@property (nonatomic, strong)   ReticleView *reticleView;   // nil if reticle not selected
@property (nonatomic, strong)   UILabel *paramView;
@property (nonatomic, strong)   NSString *overlayDebugStatus;
@property (nonatomic, strong)   UILabel *pausedLabel;       // if camera capture is paused. Use .hidden as flag
@property (nonatomic, strong)   UIImageView *transformView; // transformed image
@property (nonatomic, strong)   NSMutableArray *thumbViewsArray;         // views that go into thumbsView
@property (nonatomic, strong)   UIView *thumbsView;         // transform thumbs view of thumbArray
@property (nonatomic, strong)   UITextView *executeView;        // active transform list
@property (nonatomic, strong)   NSMutableArray *layouts;    // approved list of current layouts
@property (assign)              long currentLayoutIndex;       // index into layouts

@property (nonatomic, strong)   UINavigationController *helpNavVC;

// in sources view
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (nonatomic, strong)   InputSource *currentSource, *firstSource, *nextSource;
@property (nonatomic, strong)   UIImageView *cameraSourceThumb; // non-nil if selecting source
@property (nonatomic, strong)   UIImage *currentSourceImage;    // what we are transforming, or nil if get an image from the camera
@property (nonatomic, strong)   UIImage *previousSourceImage;   // last used
@property (nonatomic, strong)   InputSource *fileSource;
@property (nonatomic, strong)   NSMutableArray *inputSources;
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
@property (nonatomic, strong)   UIBarButtonItem *saveBarButton;

@property (nonatomic, strong)   UIButton *plusButton;
@property (assign)              BOOL plusButtonLocked;
@property (nonatomic, strong)   UIButton *plusLockButton;

@property (assign)              BOOL busy;      // transforming is busy, don't start a new one

//@property (assign)              UIImageOrientation imageOrientation;
@property (assign)              UIDeviceOrientation deviceOrientation;
@property (assign)              BOOL isPortrait;
@property (assign)              BOOL isiPhone;
@property (assign)              BOOL hasFrontCamera;    // assume no front camera means no cameras at all
@property (assign)              BOOL hasRearCamera;
@property (assign)              BOOL hasFrontDepthCamera, hasRearDepthCamera;
@property (nonatomic, strong)   Layout *layout;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthBuf *depthBuf;
@property (assign)              CGSize transformDisplaySize;

@property (nonatomic, strong)   UISegmentedControl *sourceSelectionView;

@property (nonatomic, strong)   UISegmentedControl *uiSelection;
@property (nonatomic, strong)   UIScrollView *thumbScrollView;

@end

@implementation MainVC

@synthesize taskCtrl;
@synthesize screenTasks, thumbTasks, depthThumbTasks, externalTasks;
@synthesize hiresTasks;
@synthesize screenTask, externalTask;

@synthesize containerView;
@synthesize depthSwitch, flipBarButton, sourceBarButton;
@synthesize transformView, overlayView, overlayState;
@synthesize overlayDebugStatus;
@synthesize pausedLabel;
@synthesize reticleView, reticleBarButton;
@synthesize paramView;
@synthesize thumbViewsArray, thumbsView;
@synthesize layouts, currentLayoutIndex;
@synthesize helpNavVC;

@synthesize executeView;
@synthesize plusButton, plusButtonLocked;
@synthesize plusLockButton;

@synthesize deviceOrientation;
@synthesize isPortrait;
@synthesize isiPhone;
@synthesize hasFrontCamera, hasRearCamera;
@synthesize hasFrontDepthCamera, hasRearDepthCamera;

@synthesize sourcesNavVC;
@synthesize options;

@synthesize currentSource, nextSource, inputSources;
@synthesize cameraSourceThumb;
@synthesize currentDepthTransformIndex;
@synthesize currentTransformIndex;
@synthesize currentSourceImage, previousSourceImage;

@synthesize availableCameraCount;

@synthesize cameraController;
@synthesize layout;

@synthesize undoBarButton, saveBarButton, trashBarButton;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize hiresButton;
@synthesize snapButton;

@synthesize rowIsCollapsed;
@synthesize depthBuf;

@synthesize transformDisplaySize;
@synthesize sourceSelectionView;
@synthesize uiSelection;
@synthesize thumbScrollView;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        nullTransform = [[Transform alloc] init];
        
        currentTransformIndex = NO_TRANSFORM;
        currentSourceImage = nil;
        layout = nil;
        helpNavVC = nil;
        layouts = [[NSMutableArray alloc] init];
        
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
        depthThumbTasks = [taskCtrl newTaskGroupNamed:@"DepthThumbs"];
        //externalTasks = [taskCtrl newTaskGroupNamed:@"External"];
        
        transformTotalElapsed = 0;
        transformCount = 0;
        depthBuf = nil;
        thumbScrollView = nil;
        busy = NO;
        plusButtonLocked = NO;
        options = [[Options alloc] init];
        
        overlayState = overlayClear;
        overlayDebugStatus = nil;
        
        isiPhone  = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
        
#if TARGET_OS_SIMULATOR
        cameraController = nil;
        NSLog(@"No camera on simulator");
#else
        cameraController = [[CameraController alloc] init];
        cameraController.delegate = self;
#endif

        inputSources = [[NSMutableArray alloc] init];
        cameraSourceThumb = nil;
        
        if (HAVE_CAMERA) {
            [self addCameraSource];
        }
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
        
        currentSource = nil;
        InputSource *firstSource = nil;
        NSData *lastSourceData = [InputSource lastSourceArchive];
        if (lastSourceData) {
            NSError *error;
            firstSource = [NSKeyedUnarchiver
                             unarchivedObjectOfClass:[InputSource class]
                             fromData:lastSourceData error:&error];
        }
        firstSource = nil;    // DEBUG
        if (!firstSource) {  // select default source
            for (InputSource *source in inputSources)
                if (HAVE_CAMERA) {
                    if (IS_CAMERA(source)) {
                        firstSource = source;
                        NSLog(@"first source is default camera");

                        break;
                    }
                } else {
                    if (!IS_CAMERA(source)) {
                        firstSource = source;
                        NSLog(@"first source is file '%@'", firstSource.label);
                        break;
                    }
                }
            if (!firstSource)
                assert(NO); // inconceivable, no sources available
        }
        nextSource = firstSource;
    }
    return self;
}

- (void) createThumbArray {
    NSString *brokenPath = [[NSBundle mainBundle]
                            pathForResource:@"images/brokenTransform.png" ofType:@""];
    UIImage *brokenImage = [UIImage imageNamed:brokenPath];

    thumbViewsArray = [[NSMutableArray alloc] init];

    UITapGestureRecognizer *touch;
    NSString *lastSection = nil;
    
    for (size_t ti=0; ti<transforms.transforms.count; ti++) {
        ThumbView *thumbView = [[ThumbView alloc] init];

        Transform *transform = [transforms.transforms objectAtIndex:ti];
        NSString *section = [transform.helpPath pathComponents][0];
        if (!lastSection || ![lastSection isEqualToString:section]) {
            // new section. The first one has the depthSwitch
            [thumbView configureSectionThumbNamed:section
                                       withSwitch:!lastSection ? depthSwitch : nil];
            [thumbViewsArray addObject:thumbView];  // Add section thumb, then...
            
            thumbView = [[ThumbView alloc] init];   // a new thumbview for the actual transform
            lastSection = section;
        }
        [thumbView configureForTransform:transform];
        thumbView.transformIndex = ti;     // encode the index of this transform
        thumbView.tag = ti + TRANSFORM_BASE_TAG;

        [self adjustThumbView:thumbView selected:NO];
        if (transform.type == DepthVis) {
            touch = [[UITapGestureRecognizer alloc]
                     initWithTarget:self
                     action:@selector(doTapDepthVis:)];
            UIImageView *imageView = [thumbView viewWithTag:THUMB_IMAGE_TAG];
            Task *task = [depthThumbTasks createTaskForTargetImageView:imageView
                                                                 named:transform.name];
            [task useDepthTransform:transform];
            [thumbView addSubview:imageView];
            // these thumbs display their own transform of the depth input only, and don't
            // change when they are used.
            task.depthLocked = YES;
        } else {
            touch = [[UITapGestureRecognizer alloc]
                     initWithTarget:self
                     action:@selector(doTapThumb:)];
            UIImageView *imageView = [thumbView viewWithTag:THUMB_IMAGE_TAG];
            if (transform.broken) {
                imageView.image = brokenImage;
            } else {
                Task *task = [thumbTasks createTaskForTargetImageView:imageView
                                                                named:transform.name];
                [task appendTransformToTask:transform];
                task.depthLocked = YES;
            }
            [thumbView addSubview:imageView];
        }
        [thumbView addGestureRecognizer:touch];
        UILongPressGestureRecognizer *thumbHelp = [[UILongPressGestureRecognizer alloc]
                                                         initWithTarget:self action:@selector(doHelp:)];
        thumbHelp.minimumPressDuration = 1.0;
        [thumbView addGestureRecognizer:thumbHelp];

        [thumbViewsArray addObject:thumbView];
    }

    // contains transform thumbs and sections.  Positions and sizes decided
    // as needed.
    
    for (ThumbView *thumbView in thumbViewsArray) {
        [thumbsView addSubview:thumbView];
    }
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
    [thumbTasks configureGroupForSize:layout.thumbImageRect.size];
    if (DISPLAYING_THUMBS && cameraController.usingDepthCamera)
        [depthThumbTasks configureGroupForSize:layout.thumbImageRect.size];

    CGRect transformNameRect;
    transformNameRect.origin = CGPointMake(0, BELOW(layout.thumbImageRect));
    transformNameRect.size = CGSizeMake(nextButtonFrame.size.width, THUMB_LABEL_H);
    
    CGRect switchRect = CGRectMake((nextButtonFrame.size.width - SECTION_SWITCH_W)/2, nextButtonFrame.size.height-SECTION_SWITCH_H - SEP,
                                   SECTION_SWITCH_W, SECTION_SWITCH_H);
    depthSwitch.frame = switchRect;
    CGRect sectionNameRect = CGRectMake(0, 20,
                                        nextButtonFrame.size.width,
                                        nextButtonFrame.size.height - switchRect.origin.y);
    
    // Run through all the transform and section thumbs, computing the corresponding thumb sizes and
    // positions for the current situation. These thumbs come in section, each of which has
    // their own section header thumb display. This header starts on a new line (if vertical
    // thumb placement) or after a space on horizontal placements.
    
    atStartOfRow = YES;
    CGFloat thumbsH = 0;
    NSString *lastSection = nil;
    
    // run through the thumbview array
    for (ThumbView *thumbView in thumbViewsArray) {
        if (IS_SECTION_HEADER(thumbView)) {   // new section
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
            depthSwitch.enabled = HAVE_CAMERA && [cameraController isDepthAvailable];
            if (depthSwitch.enabled)
                depthSwitch.on = [cameraController usingDepthCamera];
            
            thumbView.frame = nextButtonFrame;  // this is a little incomplete
            lastSection = thumbView.sectionName;
        } else {
            Transform *transform = [transforms.transforms objectAtIndex:thumbView.transformIndex];
            thumbView.userInteractionEnabled = !transform.broken;
#ifdef DEBUG_THUMB_LAYOUT
            NSLog(@"%3.0f,%3.0f  %3.0fx%3.0f   Transform %@",
                  nextButtonFrame.origin.x, nextButtonFrame.origin.y,
                  nextButtonFrame.size.width, nextButtonFrame.size.height,
                  transform.name);
#endif
            if (transform.type == DepthVis) {
                [thumbView enable: cameraController.usingDepthCamera];
                if (cameraController.usingDepthCamera) {
                    BOOL selected = thumbView.transformIndex == currentDepthTransformIndex;
                    [self adjustThumbView:thumbView selected:selected];
                    if (selected) {
                        [screenTasks configureGroupWithNewDepthTransform:transform];
                    }
                }
            }
            
            UIImageView *thumbImage = [thumbView viewWithTag:THUMB_IMAGE_TAG];
            thumbImage.frame = layout.thumbImageRect;
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

- (void) saveDepthTransformName {
    assert(currentDepthTransformIndex != NO_TRANSFORM);
    Transform *transform = [transforms.transforms objectAtIndex:currentDepthTransformIndex];
    [[NSUserDefaults standardUserDefaults] setObject:transform.name
                                              forKey:LAST_DEPTH_TRANSFORM];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) addCameraSource {
    InputSource *newSource = [[InputSource alloc] init];
    [newSource makeCameraSourceOnSide:Front threeD:NO];
    [inputSources addObject:newSource];
}

- (void) addFileSource:(NSString *)fn label:(NSString *)l {
    InputSource *source = [[InputSource alloc] init];
    NSString *file = [@"images/" stringByAppendingPathComponent:fn];
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@""];
    if (!imagePath) {
        NSLog(@"**** Image not found: %@", fn);
        return;
    }
    [source setUpImageAt:imagePath];
    [inputSources addObject:source];
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

- (void) viewDidLoad {
    [super viewDidLoad];
    
#ifdef DEBUG_LAYOUT
    NSLog(@"viewDidLoad");
#endif
    
    self.navigationController.navigationBar.opaque = NO;
    self.navigationController.toolbar.opaque = NO;
    [self updateOverlayView:overlayClear];

    sourceBarButton = [[UIBarButtonItem alloc]
                                             initWithImage:[UIImage systemImageNamed:@"filemenu.and.selection"]
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(selectSource:)];
    
    flipBarButton = [[UIBarButtonItem alloc]
                                      initWithImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath.camera"]
                                      style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(flipCamera:)];
    
    depthSwitch = [[UISwitch alloc] init];  // this is placed later in the Depth thumb section header'
    [depthSwitch addTarget:self action:@selector(processDepthSwitch:)
          forControlEvents:UIControlEventValueChanged];
    depthSwitch.on = NO;
    depthSwitch.enabled = NO;
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                   target:nil action:nil];
    fixedSpace.width = isiPhone ? 10 : 20;
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];

#ifdef DISABLED
    UIBarButtonItem *otherMenuButton = [[UIBarButtonItem alloc]
                                        initWithImage:[UIImage systemImageNamed:@"ellipsis"]
                                        style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(goSelectOptions:)];
#endif
    
    trashBarButton = [[UIBarButtonItem alloc]
                      initWithImage:[UIImage systemImageNamed:@"trash"]
                      style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(doRemoveAllTransforms)];
    
    hiresButton = [[UIBarButtonItem alloc]
                   initWithTitle:@"Hi res" style:UIBarButtonItemStylePlain
                   target:self action:@selector(doToggleHires:)];
    
    saveBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                     style:UIBarButtonItemStylePlain
                     target:self
                     action:@selector(doSave)];
    
    undoBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"arrow.uturn.backward"]
                     style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(doRemoveLastTransform)];
    
    self.navigationItem.leftBarButtonItems = [[NSArray alloc] initWithObjects:
                                              sourceBarButton,
                                              flexibleSpace,
                                              flipBarButton,
                                              nil];
    
    UIBarButtonItem *docBarButton = [[UIBarButtonItem alloc]
//                                     initWithImage:[UIImage systemImageNamed:@"doc.text"]
                                     initWithTitle:@"?"
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(doHelp:)];

    reticleBarButton = [[UIBarButtonItem alloc]
                                        initWithImage:[UIImage systemImageNamed:@"squareshape.split.2x2.dotted"]
                                        style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(toggleReticle:)];
    
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:
                                               docBarButton,
                                               fixedSpace,
                                               reticleBarButton,
                                               nil];
    
#define TOOLBAR_H   self.navigationController.toolbar.frame.size.height
    plusButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    plusButton.frame = CGRectMake(0, 0, TOOLBAR_H+SEP, TOOLBAR_H);
    [plusButton setAttributedTitle:[[NSAttributedString alloc]
                                    initWithString:BIGPLUS attributes:@{
                                        NSFontAttributeName: [UIFont systemFontOfSize:TOOLBAR_H
                                                                               weight:UIFontWeightUltraLight],
                                        //NSBaselineOffsetAttributeName: @-3
                                    }] forState:UIControlStateNormal];
    [plusButton setAttributedTitle:[[NSAttributedString alloc]
                                    initWithString:BIGPLUS attributes:@{
                                        NSFontAttributeName: [UIFont systemFontOfSize:TOOLBAR_H
                                                                               weight:UIFontWeightHeavy],
                                        //NSBaselineOffsetAttributeName: @-3
                                    }] forState:UIControlStateSelected];
    [plusButton addTarget:self action:@selector(togglePlusMode)
         forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *plusBarButton = [[UIBarButtonItem alloc]
                                      initWithCustomView:plusButton];

#ifdef NOTDEF
    doublePlusButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    doublePlusButton.frame = CGRectMake(0, 0, 1.5*toolBarH+SEP, toolBarH);
    [doublePlusButton setAttributedTitle:[[NSAttributedString alloc]
                                    initWithString:DOUBLE_PLUS attributes:@{
                                        NSFontAttributeName: [UIFont systemFontOfSize:toolBarH
                                                                               weight:UIFontWeightUltraLight],
                                        NSBaselineOffsetAttributeName: @3
                                    }] forState:UIControlStateNormal];
    [doublePlusButton setAttributedTitle:[[NSAttributedString alloc]
                                    initWithString:DOUBLE_PLUS attributes:@{
                                        NSFontAttributeName: [UIFont systemFontOfSize:toolBarH
                                                                               weight:UIFontWeightHeavy],
                                        NSBaselineOffsetAttributeName: @3
                                    }] forState:UIControlStateSelected];
    [doublePlusButton addTarget:self action:@selector(togglePlusLock)
         forControlEvents:UIControlEventTouchUpInside];
#endif
    
    plusLockButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    plusLockButton.selected = NO;
    
    plusLockButton.frame = CGRectMake(0, 0, 1.5*TOOLBAR_H+SEP, TOOLBAR_H);
//    NSString *pLock = [BIGPLUS stringByAppendingString: LOCK];

#define PLUS_LOCK_FONT_SIZE (TOOLBAR_H*0.6)
#define PLUS_LOCK_KERN           (-TOOLBAR_H*0.3)
#define PLUS_LOCK_SUPERSCRIPT   (TOOLBAR_H*0.1)
#define OFFSET              0   // (TOOLBAR_H*0.1)
 
    NSMutableAttributedString *littleRaisedPlus = [[NSMutableAttributedString alloc]
                                           initWithString:BIGPLUS];
    [littleRaisedPlus addAttribute: NSKernAttributeName value: @PLUS_LOCK_KERN range:NSMakeRange(0,1)];
    [littleRaisedPlus addAttribute: (NSString*)NSBaselineOffsetAttributeName value: @PLUS_LOCK_SUPERSCRIPT range:NSMakeRange(0,1)];

    NSMutableAttributedString *littleLock = [[NSMutableAttributedString alloc]
                                           initWithString:LOCK];
    //    [plusLock addAttribute: NSBaselineOffsetAttributeName value: @OFFSET range:NSMakeRange(0, 1)];

    NSMutableAttributedString *plusLock = littleRaisedPlus;
    [plusLock appendAttributedString:littleLock];
    
    [plusLockButton setAttributedTitle:plusLock forState:UIControlStateNormal];
    plusLockButton.titleLabel.font = [UIFont systemFontOfSize:PLUS_LOCK_FONT_SIZE weight:UIFontWeightLight];

    [plusLockButton addTarget:self action:@selector(togglePlusLock)
             forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *plusLockBarButton = [[UIBarButtonItem alloc]
                                      initWithCustomView:plusLockButton];

    self.toolbarItems = [[NSArray alloc] initWithObjects:
                         plusBarButton,
                         fixedSpace,
                         plusLockBarButton,
                         flexibleSpace,
                         trashBarButton,
                         fixedSpace,
                         undoBarButton,
                         fixedSpace,
                         saveBarButton,
//                         fixedSpace,
// disabled                         otherMenuButton,
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

    overlayView = [[UIView alloc] init];
    overlayView.opaque = NO;
    overlayView.userInteractionEnabled = YES;
    overlayView.backgroundColor = [UIColor clearColor];

    pausedLabel = [[UILabel alloc]
                   initWithFrame:CGRectMake(0, SEP,
                                            LATER, PAUSE_FONT_SIZE+2*SEP)];
    pausedLabel.text = @"** PAUSED **";
    pausedLabel.textColor = [UIColor blackColor];
    pausedLabel.font = [UIFont boldSystemFontOfSize:PAUSE_FONT_SIZE];
    pausedLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    pausedLabel.textAlignment = NSTextAlignmentCenter;
    pausedLabel.hidden = YES;   // assume not paused video
    [transformView addSubview:pausedLabel];
    [transformView bringSubviewToFront:pausedLabel];
    
    reticleView = nil;      // defaults to off
    paramView = nil;
    
    executeView = [[UITextView alloc]
                   initWithFrame: CGRectMake(0, LATER, LATER, LATER)];
    executeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    executeView.userInteractionEnabled = NO;
    executeView.font = [UIFont boldSystemFontOfSize: EXECUTE_FONT_SIZE];
    executeView.textColor = [UIColor blackColor];
    executeView.text = @"";
    executeView.opaque = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTapSceen:)];
    [tap setNumberOfTouchesRequired:1];
    [overlayView addGestureRecognizer:tap];

    UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTwoTapSceen:)];
    [twoTap setNumberOfTouchesRequired:2];
    [overlayView addGestureRecognizer:twoTap];

    UITapGestureRecognizer *threeTap = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didThreeTapSceen:)];
    [threeTap setNumberOfTouchesRequired:3];
    [overlayView addGestureRecognizer:threeTap];

    UILongPressGestureRecognizer *longPressScreen = [[UILongPressGestureRecognizer alloc]
                                                     initWithTarget:self action:@selector(doLeft:)];
    longPressScreen.minimumPressDuration = 1.0;
    [overlayView addGestureRecognizer:longPressScreen];

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
    [containerView addSubview:executeView];
    [containerView bringSubviewToFront:overlayView];
    
    screenTask = [screenTasks createTaskForTargetImageView:transformView
                                                         named:@"main"];
    
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
    
    thumbsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [thumbScrollView addSubview:thumbsView];
    [containerView addSubview:thumbScrollView];

    [self.view addSubview:containerView];
    
    //externalTask = [externalTasks createTaskForTargetImage:transformImageView.image];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self createThumbArray];
}

- (void) viewWillTransitionToSize:(CGSize)newSize
        withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
#ifdef DEBUG_LAYOUT
    NSLog(@"********* viewWillTransitionToSize: %.0f x %.0f", newSize.width, newSize.height);
#endif
    [taskCtrl idleForReconfiguration];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#ifdef DEBUG_LAYOUT
    NSLog(@"viewWillAppear");
#endif
    // not needed: we haven't started anything yet
    //[taskCtrl idleForReconfiguration];
    [self newLayout];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

#ifdef DEBUG_LAYOUT
    NSLog(@"--------- viewDidAppear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#endif

#ifdef OLD
    if (IS_CAMERA(currentSource)) {
        [self startCamera];
        [self set3D:DOING_3D];
    }
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
#ifdef DEBUG_LAYOUT
    NSLog(@"--------- viewWillDisappear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#endif

    [super viewWillDisappear:animated];
    [self stopCamera];
}

- (void) newDeviceOrientation {
    UIDeviceOrientation nextOrientation = [[UIDevice currentDevice] orientation];
    if (nextOrientation == UIDeviceOrientationUnknown)
        return; // weird, ignore it
    if (nextOrientation == deviceOrientation)
        return; // nothing new to see here, folks
    deviceOrientation = nextOrientation;
#ifdef DEBUG_ORIENTATION
    NSLog(@"adjusting for orientation: %@", [CameraController
                                             dumpDeviceOrientationName:deviceOrientation]);
    //    NSLog(@" image orientation %@", imageOrientationName[imageOrientation]);
#endif
    if (layout) // already layed out, adjust it
        [taskCtrl idleForReconfiguration];
}

- (void) tasksAreIdle {
    [self newLayout];
}

// On entry:
//  currentSource or nextSource
//  transform tasks must be idle

- (void) newLayout {
    assert(currentSource || nextSource);
#ifdef DEBUG_LAYOUT
    NSLog(@"********* newLayout");
#endif
    isPortrait = UIDeviceOrientationIsPortrait(deviceOrientation) ||
        UIDeviceOrientationIsFlat(deviceOrientation);
    
    if (!isiPhone || !isPortrait)
        self.title = @"Digital Darkroom";
    
    // close down any currentSource stuff
    if (nextSource) {   // change sources
        if (LIVE) {
            [cameraController stopCamera];
        }
        currentSource = nextSource;
        nextSource = nil;
        if (currentSource.isCamera) {
            previousSourceImage = nil;
            currentSourceImage = nil;
        } else {    // source is a file, it is our source image
            currentSourceImage = [UIImage imageNamed: currentSource.imagePath];
        }
    }
    assert(currentSource);
    
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [containerView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor].active = YES;
    [containerView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor].active = YES;
    [containerView.topAnchor constraintEqualToAnchor:guide.topAnchor].active = YES;
    [containerView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor].active = YES;
    
    UIWindow *window = self.view.window; // UIApplication.sharedApplication.keyWindow;
//    CGFloat bottomPadding = window.safeAreaInsets.bottom;
    CGFloat leftPadding = window.safeAreaInsets.left;
    CGFloat rightPadding = window.safeAreaInsets.right;
    
#ifdef DEBUG_LAYOUT
    CGFloat topPadding = window.safeAreaInsets.top;
    NSLog(@"padding, L, R, T, B: %0.f %0.f %0.f",
          leftPadding, rightPadding, topPadding);
#endif
    
    CGRect f = self.view.frame;
#ifdef DEBUG_LAYOUT
    NSLog(@"                in: %.0f,%.0f  %.0fx%.0f (%4.2f)",
          f.origin.x, f.origin.y, f.size.width, f.size.height,
          f.size.width/f.size.height);
#endif
    f.origin.x = leftPadding; // + SEP;
    f.origin.y = BELOW(self.navigationController.navigationBar.frame) + SEP;
    f.size.height = self.navigationController.toolbar.frame.origin.y - f.origin.y;
    f.size.width = self.view.frame.size.width - rightPadding - f.origin.x;
    containerView.frame = f;
#ifdef DEBUG_LAYOUT
    NSLog(@"     containerview: %.0f,%.0f  %.0fx%.0f (%4.2f)",
          f.origin.x, f.origin.y, f.size.width, f.size.height,
          f.size.width/f.size.height);
#endif
    
    if (currentSourceImage) { // file or captured image input
#ifdef DEBUG_LAYOUT
        NSLog(@"choose layout for image source size %.0f x %.0f (%5.2f",
              currentSourceImage.size.width, currentSourceImage.size.height,
              currentSourceImage.size.width/currentSourceImage.size.height);
#endif
        [self initForLayingOut];
        
        layout = [[Layout alloc]
                  initForOrientation:isPortrait
                  iPhone:isiPhone
                  containerRect:containerView.frame];
        layout.thumbCount = thumbViewsArray.count;
        layout.format = nil;
        layout.captureSize = currentSourceImage.size;
        [layout configureLayoutWithDisplayOption:isiPhone ? TightDisplay : BestDisplay];
#ifdef NOTDEF
        float scale = scales[scaleIndex++];
        targetSize = CGSizeMake(round(targetSize.width * scale),
                                round(targetSize.height * scale));
#endif
        assert(layout.quality >= 0);
        [layouts addObject:layout];
        currentLayoutIndex = 0;
        [self applyScreenLayout];
        [taskCtrl enableTasks];
        [self doTransformsOn:currentSourceImage];
    } else {
        assert(LIVE);   // select camera setting for available area
        assert(cameraController);
        [cameraController updateOrientationTo:deviceOrientation];
        [cameraController selectCameraOnSide:currentSource.currentSide
                                      threeD:currentSource.usingDepthCamera];
        NSArray *availableFormats = [cameraController
                                     formatsForSelectedCameraNeeding3D:currentSource.usingDepthCamera];
        currentLayoutIndex = [self chooseLayoutsFromFormatList:availableFormats];
        assert(currentLayoutIndex != NO_LAYOUT_SELECTED);
        layout = layouts[currentLayoutIndex];
        [cameraController setupCameraSessionWithFormat:layout.format];
        [self applyScreenLayout];
        [self startCamera];
        [taskCtrl enableTasks];
    }
}

#define DEBUG_FONT_SIZE 16

-(void) updateOverlayView: (OverlayState) newState {
    // start fresh
    [overlayView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    UILabel *overlayDebug = nil;
    
    overlayState = newState;
    switch (overlayState) {
        case overlayClear:
            [self.navigationController setNavigationBarHidden:YES animated:YES];
            [self.navigationController setToolbarHidden:YES animated:YES];
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
            [self.navigationController setNavigationBarHidden:NO animated:YES];
            [self.navigationController setToolbarHidden:NO animated:YES];
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

- (void) adjustBarButtons {
    flipBarButton.enabled = IS_CAMERA(currentSource) && [cameraController isFlipAvailable];
    
    trashBarButton.enabled = screenTask.transformList.count > DEPTH_TRANSFORM + 1;
    undoBarButton.enabled = screenTask.transformList.count > DEPTH_TRANSFORM + 1;
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

// select a new depth visualization.
- (IBAction) doTapDepthVis:(UITapGestureRecognizer *)recognizer {
    ThumbView *newThumbView = (ThumbView *)recognizer.view;
    long newTransformIndex = newThumbView.transformIndex;
    assert(newTransformIndex >= 0 && newTransformIndex < transforms.transforms.count);
    if (newTransformIndex == currentDepthTransformIndex)
        return;

    ThumbView *oldSelectedDepthThumb = [thumbsView viewWithTag:currentDepthTransformIndex + TRANSFORM_BASE_TAG];
    [self adjustThumbView:oldSelectedDepthThumb selected:NO];
    [self adjustThumbView:newThumbView selected:YES];

    currentDepthTransformIndex = newTransformIndex;
    Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    assert(depthTransform.type == DepthVis);
    [self saveDepthTransformName];

    [screenTasks configureGroupWithNewDepthTransform:depthTransform];
    if (DISPLAYING_THUMBS && cameraController.usingDepthCamera)
        [depthThumbTasks configureGroupWithNewDepthTransform:depthTransform];
}

- (IBAction) doTapThumb:(UITapGestureRecognizer *)recognizer {
#ifdef OLD
    @synchronized (transforms.sequence) {
        [transforms.sequence removeAllObjects];
        transforms.sequenceChanged = YES;
    }
#endif
    ThumbView *tappedThumb = (ThumbView *)[recognizer view];
    [self transformThumbTapped: tappedThumb];
}


- (void) transformThumbTapped: (ThumbView *) tappedThumb {
    Transform *tappedTransform = transforms.transforms[tappedThumb.transformIndex];

    size_t lastTransformIndex = screenTask.transformList.count - 1; // depth transform (#0) doesn't count
    Transform *lastTransform = nil;
    if (lastTransformIndex > DEPTH_TRANSFORM) {
        lastTransform = screenTask.transformList[lastTransformIndex];
    }
    
    if (plusButton.selected) {  // add new transform
        [screenTask appendTransformToTask:tappedTransform];
        [screenTask configureTaskForSize];
        [self adjustThumbView:tappedThumb selected:YES];
        if (!plusButtonLocked)
            plusButton.selected = NO;
    } else {    // not plus mode
        if (lastTransform) {
            BOOL reTap = [tappedTransform.name isEqual:lastTransform.name];
            [screenTask removeLastTransform];
            ThumbView *oldThumb = [self thumbForTransform:lastTransform];
            [self adjustThumbView:oldThumb selected:NO];
            if (reTap) {
                // retapping a transform in not plus mode means just remove it, and we are done
                [self updateExecuteView];
                [self adjustBarButtons];
                tappedTransform = nil;
            }
        }
        if (tappedTransform) {
            [screenTask appendTransformToTask:tappedTransform];
            [self adjustThumbView:tappedThumb selected:YES];
        }
        [screenTask configureTaskForSize];
    }
    [self doTransformsOn:currentSourceImage];
    [self updateOverlayView:overlayState];
    [self updateExecuteView];
    [self adjustBarButtons];
}

- (IBAction) togglePlusMode {
    plusButton.selected = !plusButton.selected;
    [plusButton setNeedsDisplay];
    [self updateExecuteView];
}

- (IBAction) togglePlusLock {
    plusLockButton.selected = !plusLockButton.selected;
    plusButtonLocked = plusLockButton.selected;
    if (plusButtonLocked)
        plusLockButton.titleLabel.font = [UIFont systemFontOfSize:PLUS_LOCK_FONT_SIZE weight:UIFontWeightLight];
    else
        plusLockButton.titleLabel.font = [UIFont systemFontOfSize:PLUS_LOCK_FONT_SIZE weight:UIFontWeightHeavy];
    
    [plusLockButton setNeedsDisplay];
    if (plusLockButton.selected && !plusButton.selected)
        [self togglePlusMode];
    [self updateExecuteView];
}

- (void) adjustThumbView:(ThumbView *) thumb selected:(BOOL)selected {
    UILabel *label = [thumb viewWithTag:THUMB_LABEL_TAG];
    if (selected) {
        label.font = [UIFont boldSystemFontOfSize:THUMB_FONT_SIZE];
        thumb.layer.borderWidth = 5.0;
        currentTransformIndex = thumb.transformIndex;
        label.highlighted = YES;    // this doesn't seem to do anything
    } else {
        label.font = [UIFont systemFontOfSize:THUMB_FONT_SIZE];
        if (thumb.sectionName)
            thumb.layer.borderWidth = 0;
        else
            thumb.layer.borderWidth = 1.0;
        label.highlighted = NO;
    }
    [label setNeedsDisplay];
    [thumb setNeedsDisplay];
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
- (IBAction) didTapSceen:(UITapGestureRecognizer *)recognizer {
    if (overlayState == overlayClear)
        overlayState = overlayShowing;
    else
        overlayState = overlayClear;
    [self updateOverlayView:overlayState];
}

#ifdef NEW
    if (!IS_CAMERA(currentSource))
        return;
    if (PAUSED)
        [self goLive];
    else {
        pausedLabel.hidden = NO;
        currentSourceImage = previousSourceImage;
        [pausedLabel setNeedsDisplay];
    }
}
#endif

- (void) goLive {
    currentSourceImage = nil;
    previousSourceImage = nil;
    pausedLabel.hidden = YES;
    [pausedLabel setNeedsDisplay];
    [taskCtrl idleForReconfiguration];
}

- (IBAction) didTwoTapSceen:(UITapGestureRecognizer *)recognizer {
    NSLog(@"two-tap screen: save image");
    [self doSave];
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
        
        long transformIndex = thumbView.transformIndex;
        assert(transformIndex >= 0 && transformIndex < transforms.transforms.count);
        Transform *transform = [transforms transformAtIndex:transformIndex];
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
    
#ifdef OLD
    popController.sourceRect = CGRectMake(100, 100, 100, 100);
    popController.sourceView = helpNavVC.view;
    if ([caller isKindOfClass:[UIBarButtonItem class]]) {
        popController.barButtonItem = (UIBarButtonItem *)caller;
    } else if ([caller isKindOfClass:[UIView class]]) {
        popController.sourceView = caller;
    } else {
        NSLog(@"*** unexpected button class: %@ ***", [caller class]);
    }
    
    [self presentViewController:helpNavVC animated:YES completion:^{
        //        [helpNavVC.view removeFromSuperview];
        helpNavVC = nil;
        return;  //???
    }];
#endif
}

- (IBAction) toggleReticle:(UIBarButtonItem *)reticleBarButton {
    if (reticleView) {  // turn it off by removing it
        [reticleView removeFromSuperview];
        reticleView = nil;
        [paramView removeFromSuperview];
        paramView = nil;
        [overlayView setNeedsDisplay];
        return;
    }
    
    CGRect f = overlayView.frame;
    f.origin = CGPointZero;
    reticleView = [[ReticleView alloc] initWithFrame:f];
    reticleView.contentMode = UIViewContentModeRedraw;
    reticleView.opaque = NO;
    reticleView.backgroundColor = [UIColor clearColor];
    [overlayView addSubview:reticleView];
    
    CGFloat paramH = round(f.size.height/10.0);
    f.origin.y = f.size.height - paramH;
    f.size.height = paramH;
    paramView = [[UILabel alloc] initWithFrame:f];
    paramView.font = [UIFont systemFontOfSize:paramH - 4
                                       weight:UIFontWeightUltraLight];
    paramView.textAlignment = NSTextAlignmentCenter;
    paramView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    paramView.textColor = [UIColor blackColor];
    paramView.text = @"Poot";
    paramView.hidden = YES;
    [overlayView addSubview:paramView];

    [reticleView setNeedsDisplay];
    [self updateExecuteView];
}

#ifdef NOTDEEF
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

int startParam;

- (IBAction) doPan:(UIPanGestureRecognizer *)recognizer { // adjust value of selected transform
    Transform *lastTransform = [screenTask lastTransform:cameraController.usingDepthCamera];
    if (!lastTransform)
        return;
    int currentParam = [screenTask valueForStep:screenTask.transformList.count - 1];
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            startParam = currentParam;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            int range = lastTransform.high - lastTransform.low + 1;
            int pixelsPerRange = overlayView.frame.size.width / range;
            CGPoint dist = [recognizer translationInView:recognizer.view];
            int paramDelta = dist.x/pixelsPerRange;
            int newParam = startParam + paramDelta;
//            NSLog(@"changed  %.0f ppr %d   delta %d  new %d  current %d",
//                  dist.x, pixelsPerRange, paramDelta, newParam, currentParam);
            if ([screenTask updateParamOfLastTransformTo:newParam]) {
                [self doTransformsOn:previousSourceImage];
                [self updateExecuteView];
            }
            break;
        }
        default:
            ;;
    }
}

static CGSize startingDisplaySize;

- (IBAction) doPinch:(UIPinchGestureRecognizer *)pinch {
    switch (pinch.state) {
        case UIGestureRecognizerStateBegan:
            startingDisplaySize = overlayView.frame.size;
            break;
        case UIGestureRecognizerStateEnded:
            //[self finalizeDisplayAdjustment];
            break;
        case UIGestureRecognizerStateChanged: {
//            [UIView animateWithDuration:0.7 animations:^(void) {
//                [self adjustDisplayFromSize:startingDisplaySize toScale: pinch.scale];
//            }];
            break;
        }
        default:
            return;
    }
#ifdef NOTNEW
    if (recognizer.state != UIGestureRecognizerStateEnded)
        return;
    if (recognizer.scale > 1.0) {
        // go to bigger display image
        if (currentLayoutIndex + 1 < layouts.count) {
            currentLayoutIndex++;
            layout = layouts[currentLayoutIndex];
        }
        [self configureScreenForOrientation];
    } else if (recognizer.scale < 1.0) {
        // smaller display image
        if (currentLayoutIndex > 0) {
            currentLayoutIndex--;
            layout = layouts[currentLayoutIndex];
        }
    }
    [self reconfigure];
#endif
}

-(void) flash {
    overlayView.opaque = NO;
    overlayView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    [UIView animateWithDuration:0.40 animations:^(void) {
        self->overlayView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
    }];
    overlayView.backgroundColor = [UIColor clearColor];
    overlayView.opaque = NO;
}

// this should be copy to paste buffer, or the send-it-out option
- (IBAction) doSave {
    NSLog(@"saving");   // XXX need full image for a save
    [self flash];
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

#ifdef NOTYET
- (void) adjustDisplayFromSize:(CGSize) startingSize toScale:(float)newScale {
    // constrain the size between smallest display (thumb size) to size of the containerView.
    if (layout.aspectRatio > 1.0) {
        if (startingSize.height*newScale < MIN_DISPLAY_H)
            newScale = MIN_DISPLAY_H/startingSize.height;
        else if (startingSize.height*newScale > containerView.frame.size.height)
            newScale = containerView.frame.size.height/startingSize.height;
    } else {
        if (startingSize.width*newScale < MIN_DISPLAY_W)
            newScale = MIN_DISPLAY_W/startingSize.width;
        else if (startingSize.width*newScale > containerView.frame.size.width)
            newScale = containerView.frame.size.width/startingSize.width;
    }
    
    CGSize newSize = CGSizeMake(round(startingSize.width*newScale),
                                round(startingSize.height*newScale));
    if (newSize.width == layout.displayRect.size.width &&
        newSize.height == layout.displayRect.size.height)
        return;     // same size, nothing to do

    [self adjustDisplayToLayout:newSize];
}

- (void) adjustDisplayToLayout:(CGSize) newSize {
    [layout configureLayoutForDisplaySize:newSize];
    overlayView.frame = layout.displayRect;
    transformView.frame = layout.displayRect;
    executeView.frame = layout.executeRect;
    if (reticleView) {
        reticleView.frame = CGRectMake(0, 0,
                                       layout.displayRect.size.width,
                                       layout.displayRect.size.height);
        [reticleView setNeedsDisplay];
    }

    thumbScrollView.frame = layout.thumbArrayRect;
    thumbsView.frame = CGRectMake(0, 0,
                                      thumbScrollView.frame.size.width,
                                      thumbScrollView.frame.size.height);
    [self layoutThumbs: layout];
    [self updateExecuteView];
}
#endif

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

- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output
        didOutputDepthData:(AVDepthData *)rawDepthData
        timestamp:(CMTime)timestamp connection:(AVCaptureConnection *)connection {
    if (!pausedLabel.hidden)    // PAUSED displayed means no new images
        return;
    if (!cameraController.usingDepthCamera)
        return;
    if (taskCtrl.reconfigurationNeeded)
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
    
    if (depthBuf.maxDepth == 0.0) {     // if no previous depth range
        depthBuf.minDepth = MAXFLOAT;
        depthBuf.maxDepth = 0.0;
        for (int i=0; i<depthBuf.w * depthBuf.h; i++) {
            float z = depthBuf.db[i];
            if (z > depthBuf.maxDepth)
                depthBuf.maxDepth = z;
            if (z < depthBuf.minDepth)
                depthBuf.minDepth = z;
        }
//        return; // skip this frame, we spent enough time on it
    }

    assert(cameraController.usingDepthCamera);
    dispatch_async(dispatch_get_main_queue(), ^{
        self->previousSourceImage = [self->screenTasks executeTasksWithDepthBuf:self->depthBuf];
        if (self->cameraController.usingDepthCamera)
            [self->depthThumbTasks executeTasksWithDepthBuf:self->depthBuf];
        self->busy = NO;
    });
}

- (void) doTransformsOn:(UIImage *)sourceImage {
    if (!sourceImage)
        return;
    previousSourceImage = sourceImage;
    [screenTasks executeTasksWithImage:sourceImage];

    if (DISPLAYING_THUMBS)
        [thumbTasks executeTasksWithImage:sourceImage];
    if (cameraSourceThumb) {
        [cameraSourceThumb setImage:sourceImage];
        [cameraSourceThumb setNeedsDisplay];
    }
}
    
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    if (!pausedLabel.hidden)    // PAUSED displayed means no new images
        return;
    if (taskCtrl.reconfigurationNeeded)
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
    [screenTasks removeAllTransforms];
    for (ThumbView *thumbView in thumbViewsArray) {
        // deselect all selected thumbs
        UILabel *thumbLabel = [thumbView viewWithTag:THUMB_LABEL_TAG];
        if (thumbLabel.highlighted) {
            [self adjustThumbView:thumbView selected:NO];
        }
    }
    [self updateExecuteView];
    [self adjustBarButtons];
}

- (IBAction) doToggleHires:(UIBarButtonItem *)button {
    options.needHires = !options.needHires;
    NSLog(@" === high res now %d", options.needHires);
    [options save];
    button.style = options.needHires ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
}

- (void) doTick:(NSTimer *)sender {
    if (taskCtrl.reconfigurationNeeded && [taskCtrl tasksIdledForLayout]) {
        [self layout];
    }
    if (taskCtrl.reconfigurationNeeded)
        [taskCtrl checkReadyForReconfiguration];
    
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
    if (screenTask.transformList.count > 1) {
        Transform *lastTransform = screenTask.transformList[screenTask.transformList.count - 1];
        ThumbView *thumbView = [self thumbForTransform:lastTransform];
        [self adjustThumbView:thumbView selected:NO];
        [screenTask removeLastTransform];
        [self updateExecuteView];
        [self adjustBarButtons];
    }
}

- (ThumbView *) thumbForTransform:(Transform *) transform {
    return [thumbsView viewWithTag:TRANSFORM_BASE_TAG + transform.transformsArrayIndex];
}

// The executeView is a list of transforms.  There is a regular list mode, and a compressed
// mode for small, tight screens or long lists of transforms (which should be rare.)

- (void) updateExecuteView {
    NSString *t = nil;
    size_t start = cameraController.usingDepthCamera ? DEPTH_TRANSFORM : DEPTH_TRANSFORM + 1;
    long displaySteps = screenTask.transformList.count - start;
    CGFloat bestH = EXECUTE_H_FOR(displaySteps);
    BOOL onePerLine = !layout.executeIsTight && bestH <= executeView.frame.size.height;
    NSString *sep = onePerLine ? @"\n" : @" ";
    
    for (long step=start; step<screenTask.transformList.count; step++) {
        Transform *transform = screenTask.transformList[step];
        NSString *name = [transform.name stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        if (!t)
            t = name;
        else {
            t = [NSString stringWithFormat:@"%@  +%@%@", t, sep, name];
        }
        
        // append string showing the parameter value, if one is specified
        if (transform.hasParameters) {
            int value = [screenTask valueForStep:step];
            t = [NSString stringWithFormat:@"%@ %@%d%@",
                 t,
                 value == transform.low ? @"[" : @"<",
                 value,
                 value == transform.high ? @"]" : @">"];
            
            if (paramView) {
                paramView.text = [NSString stringWithFormat:@"%@  %d  %@",
                                  value == transform.low ? @"[" : @"<",
                                  value,
                                  value == transform.high ? @"]" : @">"];
                [paramView setNeedsDisplay];
            }
        }
        if (onePerLine && ![transform.description isEqual:@""])
            t = [NSString stringWithFormat:@"%@   (%@)", t, transform.description];
    }
    
    if (plusButton.selected || screenTask.transformList.count == DEPTH_TRANSFORM + 1)
        t = [t stringByAppendingString:@"  +"];
    executeView.text = t;
    
#ifdef EXECUTERECT
    if (layout.executeOverlayOK || executeView.contentSize.height > executeView.frame.size.height) {
        SET_VIEW_Y(executeView, BELOW(layout.executeRect) - executeView.contentSize.height);
    }
#endif
    
    // add big arrows if parameter can be changed on last transform
    Transform *lastTransform = [screenTask lastTransform:cameraController.usingDepthCamera];
    if (lastTransform && lastTransform.hasParameters) {
        int value = [screenTask valueForStep:[screenTask lastStep]];
        paramView.text = [NSString stringWithFormat:@"%@  %d  %@",
                          value == lastTransform.low ? @"[" : @"<",
                          value,
                          value == lastTransform.high ? @"]" : @">"];
        [paramView setNeedsDisplay];
        paramView.hidden = NO;
    } else
        paramView.hidden = YES;
    
#ifdef notdef
//    SET_VIEW_WIDTH(executeView, executeView.contentSize.width);
//    SET_VIEW_Y(executeView, transformView.frame.size.height - executeView.frame.size.height);
    NSLog(@"  *** updateExecuteView: %.0f,%.0f  %.0f x %.0f (%0.f x %.0f) text:%@",
          executeView.frame.origin.x, executeView.frame.origin.y,
          executeView.frame.size.width, executeView.frame.size.height,
          executeView.contentSize.width, executeView.contentSize.height, t);
    UIFont *font = [UIFont systemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
    CGSize size = [t sizeWithFont:font
                          constrainedToSize:plusButton.frame.size
                          lineBreakMode:NSLineBreakByWordWrapping];
//    float numberOfLines = size.height / font.lineHeight;
#endif
#ifdef DEBUG_LAYOUT
    executeView.layer.borderWidth = 2.0;
    executeView.layer.borderColor = layout.executeIsTight ?
        [UIColor redColor].CGColor : [UIColor greenColor].CGColor;
#endif
    [executeView setNeedsDisplay];
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
    InputSource *newSource = [currentSource copy];
    newSource.currentSide = FLIP_SIDE(currentSource.currentSide);
    [self changeSourceTo:newSource];
}

- (IBAction) processDepthSwitch:(UISwitch *)depthsw {
    InputSource *newSource = [currentSource copy];
    newSource.usingDepthCamera = !currentSource.usingDepthCamera;
    if (PAUSED)
        [self goLive];
    [self changeSourceTo:newSource];
}

- (IBAction) selectOptions:(UIButton *)button {
    OptionsVC *oVC = [[OptionsVC alloc] initWithOptions:options];
    UINavigationController *optionsNavVC = [[UINavigationController alloc]
                                            initWithRootViewController:oVC];
    [self presentViewController:optionsNavVC
                       animated:YES
                     completion:^{
        [self adjustBarButtons];
        [self->taskCtrl idleForReconfiguration];
    }];
}

CGSize sourceCellImageSize;
CGFloat sourceFontSize;
CGFloat sourceLabelH;
CGSize sourceCellSize;

#define SELECTION_CELL_ID  @"fileSelectCell"
#define SELECTION_HEADER_CELL_ID  @"fileSelectHeaderCell"

- (IBAction) selectSource:(UIBarButtonItem *)button {
    float scale = isiPhone ? SOURCE_IPHONE_SCALE : 1.0;
    sourceCellImageSize = CGSizeMake(SOURCE_THUMB_W*scale,
                                     SOURCE_THUMB_W*scale/layout.aspectRatio);
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
    [CameraSource] = @"    Camera",
    [SampleSource] = @"    Samples",
    [LibrarySource] = @"    From library",
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
        case CameraSource:
            return 1;
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
        case CameraSource:
            cameraSourceThumb = thumbImageView;
            thumbLabel.text = @"Cameras";
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
    [self changeSourceTo:[inputSources objectAtIndex:indexPath.row]];
    [sourcesNavVC dismissViewControllerAnimated:YES completion:nil];
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
        [self->taskCtrl idleForReconfiguration];
    }];
}

- (void) startCamera {
    if (!IS_CAMERA(currentSource))
        return;
    [cameraController startCamera];
//    pausedLabel.hidden = YES;
//    [pausedLabel setNeedsDisplay];
}

- (void) stopCamera {
    if (!IS_CAMERA(currentSource))
        return;
    [cameraController stopCamera];
//    pausedLabel.hidden = NO;
//    [pausedLabel setNeedsDisplay];
}

- (void) set3D:(BOOL) enable {
    if (enable) {
        
    } else {
        
    }
}

- (void) setCameraRunning:(BOOL) running {
    assert(IS_CAMERA(currentSource));
    if (running) {
        [cameraController startCamera];
    } else {
        [cameraController stopCamera];
    }
}

CGSize lastAcceptedSize;

- (void) initForLayingOut {
    [layouts removeAllObjects];
    lastAcceptedSize = CGSizeZero;
    currentLayoutIndex = NO_LAYOUT_SELECTED;
}

// save if this is the best candidate for this display size

- (void) tryCandidate:(Layout * __nullable) layout {
    if (!layout || LAYOUT_IS_BAD(layout.quality))
        return;
    
    if (layouts.count == 0) {   // accept the first one
        [layouts addObject:layout];
        return;
    }
    
    int i;
    for (i=0; i<layouts.count; i++) {   // find a match or do an insertion sort of this one
        Layout *previousLayout = layouts[i];
        switch ([layout compare:previousLayout]) {
            case NSOrderedDescending:   // smaller than current one. insert it and done
                [layouts insertObject:layout atIndex:i];
                return;
            case NSOrderedAscending:
                continue;
            case NSOrderedSame: {
                if (layout.quality > previousLayout.quality)
                    layouts[i]  = layout;
                return;
            }
        }
    }
    [layouts addObject:layout];
}

- (void) applyScreenLayout {
#ifdef DEBUG_LAYOUT
    NSLog(@"applyScreenLayout");
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
    
    overlayView.frame = layout.displayRect;
    if (reticleView) {
        reticleView.frame = CGRectMake(0, 0,
                                       overlayView.frame.size.width, overlayView.frame.size.height);
        [reticleView setNeedsDisplay];
    }
    overlayDebugStatus = layout.status;
    transformView.frame = overlayView.frame;
    SET_VIEW_WIDTH(pausedLabel, transformView.frame.size.width);
    thumbScrollView.frame = layout.thumbArrayRect;
    thumbScrollView.layer.borderColor = [UIColor cyanColor].CGColor;
    thumbScrollView.layer.borderWidth = 3.0;
    
    CGFloat below = BELOW(thumbScrollView.frame);
    assert(below <= BELOW(containerView.frame));
    assert(below <= self.navigationController.toolbar.frame.origin.y);

    thumbsView.frame = CGRectMake(0, 0,
                                      thumbScrollView.frame.size.width,
                                      thumbScrollView.frame.size.height);

#ifdef DEBUG_LAYOUT
    NSLog(@"layout selected:");

    NSLog(@"        capture:               %4.0f x %4.0f (%4.2f)  @%.1f",
          layout.captureSize.width, layout.captureSize.height,
          layout.captureSize.width/layout.captureSize.height, layout.scale);
    NSLog(@" transform size:               %4.0f x %4.0f (%4.2f)  @%.1f",
          layout.transformSize.width,
          layout.transformSize.height,
          layout.transformSize.width/layout.transformSize.height,
          layout.scale);
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
    NSLog(@"    display frac: %.3f", layout.displayFrac);
    NSLog(@"      thumb frac: %.3f", layout.thumbFrac);
    NSLog(@"           scale: %.3f", layout.scale);
#endif
    
    // layout.transformSize is what the tasks get to run.  They
    // then display (possibly scaled) onto transformView.
    
    [screenTasks configureGroupForSize: layout.transformSize];
    //    [externalTask configureForSize: processingSize];

// no longer?    [layout positionExecuteRect];
    executeView.frame = layout.executeRect;
    if (DISPLAYING_THUMBS) { // if we are displaying thumbs...
        [UIView animateWithDuration:0.5 animations:^(void) {
            // move views to where they need to be now.
            [self layoutThumbs: self->layout];
        }];
    }
    
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformImageView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;
    
    flipBarButton.enabled = HAVE_CAMERA && [cameraController isFlipAvailable];
    
    [self updateOverlayView:overlayState];
    [self updateExecuteView];
    [self adjustBarButtons];
}

static float scales[] = {0.8, 0.6, 0.5, 0.4, 0.2};

- (long) chooseLayoutsFromFormatList:(NSArray *)availableFormats {
#ifdef DEBUG_LAYOUT
    NSLog(@"chooseLayoutsFromFormatList");
#endif
    [self initForLayingOut];
    //    NSLog(@"screen size   %4.0f x %4.0f",
    //          containerView.frame.size.width, containerView.frame.size.height );
    
    CGSize lastSize = CGSizeZero;
    for (int i=0; i<availableFormats.count; i++) {
        AVCaptureDeviceFormat *format = availableFormats[i];
        //        NSLog(@"FFF %@", format);
        CGSize sourceSize = [cameraController sizeForFormat:format];
        if (sourceSize.width == lastSize.width && sourceSize.height == lastSize.height)
            continue;   // for now, only use the first of duplicate sizes
        assert(sourceSize.width >= lastSize.width || sourceSize.height >= lastSize.height);
        
        Layout *candidateLayout = [[Layout alloc]
                                   initForOrientation:isPortrait
                                   iPhone:isiPhone
                                   containerRect:containerView.frame];
        candidateLayout.thumbCount = thumbViewsArray.count;
        candidateLayout.format = format;
        candidateLayout.captureSize = sourceSize;
        
        [candidateLayout configureLayoutWithDisplayOption: BestDisplay];
        if (candidateLayout.quality < 0)
            continue;
        [layouts addObject:candidateLayout];
    }
    int bestQuality = -1;
    int newLayoutIndex = 0;
    for (int i=0; i<layouts.count; i++) {
        Layout *layout = layouts[i];
        if (layout.quality < bestQuality)
            continue;
        newLayoutIndex = i;
        bestQuality = layout.quality;
    }
    return newLayoutIndex;
}
        
#ifdef OLD
#ifdef NOTDEF
        [self tryCandidate:[candidateLayout layoutForSourceSize:sourceSize
                                                     targetSize:CGSizeZero
                                                  displayOption:NoDisplay]];
#endif
        int scaleIndex = 0;
        CGSize targetSize = sourceSize;
        do {
            [self tryCandidate:[candidateLayout layoutForSourceSize:sourceSize
                                                        displaySize:targetSize
                                                      displayOption:isiPhone ? TightDisplay : BestDisplay]];
            if (candidateLayout.quality != LAYOUT_BAD_TOO_LARGE)
                break;
            float scale = scales[scaleIndex++];
            targetSize = CGSizeMake(round(targetSize.width * scale),
                                    round(targetSize.height * scale));
        } while (scaleIndex < sizeof(scales)/sizeof(scales[0]));

        
        int newLayoutIndex = LAYOUT_NO_GOOD;
    int bestQuality = -1;
    for (int i=0; i<layouts.count; i++) {
        Layout *layout = layouts[i];
        if (layout.quality < bestQuality)
            continue;
        newLayoutIndex = i;
        bestQuality = layout.quality;
    }
#endif

- (void) changeSourceTo:(InputSource *)next {
    if (!next)
        return;
#ifdef DEBUG_LAYOUT
    NSLog(@"SSSS changeSourceTo %@", next);
#endif
    nextSource = next;
    [self->taskCtrl idleForReconfiguration];
}

#ifdef NOTUSED
    NSLog(@"--- switch layout, list:");
    for (int i=0; i<layouts.count; i++) {
        Layout *layout = layouts[i];
        NSLog(@"%@ %2d: %4.0fx%4.0f (%4.2f)  %4.0fx%4.0f (%4.2f)  %4.0fx%4.0f (%4.2f)  %3.1f  %3d   %@",
              i == currentLayoutIndex ? @">>>" : @"   ", i,
              layout.captureSize.width, layout.captureSize.height,
              layout.captureSize.width/layout.captureSize.height,
              layout.transformSize.width, layout.transformSize.height,
              layout.transformSize.width/layout.transformSize.height,
              layout.displayRect.size.width, layout.displayRect.size.height,
              layout.displayRect.size.width/layout.displayRect.size.height,
              layout.scale, layout.quality, layout.status);
    }
#endif
    
#ifdef NOTYET
    [self updateLayoutForDeviceChange];
    
    [self next]
    if (![cameraController isDepthAvailable]) {
        depthsw.enabled = NO;
        return;
    }
    NSLog(@"Depth %@", depthsw.on ? @"ON" : @"OFF");
    assert(IS_CAMERA(currentSource));
    [cameraController stopCamera];
    currentSource.usingDepthCamera = depthsw.on;
    [self adjustDepthThumbsToStatus:depthsw.on];
    [cameraController selectCameraOnSide:currentSource.currentSide threeD:depthsw.on];
    [cameraController setupSession];
    [cameraController startCamera];
    [taskCtrl reconfigureWhenReady];
    [cameraController selectCameraOnSide:newSource.currentSide
                                  threeD:NO];
    [cameraController setupSession];
    [cameraController startCamera];
    [taskCtrl reconfigureWhenReady];
    
#endif

@end
