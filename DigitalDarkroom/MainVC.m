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
#import "CameraController.h"

#import "Transforms.h"  // includes DepthImage.h
#import "OptionsVC.h"
#import "ReticleView.h"
#import "Layout.h"
#import "HelpVC.h"
#import "Defines.h"

#define HAVE_CAMERA (cameraController != nil)

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

#define SHOW_LAYOUT_FONT_SIZE   14
#define MAIN_STATS_FONT_SIZE 20

#define STATS_HEADER_INDEX  1   // second section is just stats
#define TRANSFORM_USES_SLIDER(t) ((t).p != UNINITIALIZED_P)

#define RETLO_GREEN [UIColor colorWithRed:0 green:.4 blue:0 alpha:1]
#define NAVY_BLUE   [UIColor colorWithRed:0 green:0 blue:0.5 alpha:1]

#define EXECUTE_STATS_TAG   1

#define PLUS_W    300

#define DEPTH_TABLE_SECTION     0

#define NO_STEP_SELECTED    -1
#define NO_LAYOUT_SELECTED   (-1)
#define NO_SOURCE       (-1)

#define DISPLAYING_THUMBS   (self->thumbScrollView && self->thumbScrollView.frame.size.width > 0)

#define SOURCE(si)   ((InputSource *)inputSources[si])
#define CURRENT_SOURCE  SOURCE(currentSourceIndex)

#define SOURCE_INDEX_IS_FRONT(si)   (possibleCameras[SOURCE(si).cameraIndex].front)
#define SOURCE_INDEX_IS_3D(si)   (possibleCameras[SOURCE(si).cameraIndex].threeD)

typedef enum {
    NoPlus,
    PlusOne,
    PlusMany,
} PlusMode;
#define PLUS_MODE_COUNT    3

NSString *plusNames[] = {
    @"No",
    @"One",
    @"Many"
};

NSString *plusImageNames[] = {
    @"plus.rectangle",
    @"plus.rectangle.fill",
    @"plus.rectangle.fill.on.rectangle.fill"
};

struct camera_t {
    BOOL front, threeD;
    NSString *name;
} possibleCameras[] = {
    {YES, NO, @"Front"},
    {YES, YES, @"Front 3D"},
    {NO, NO, @"Rear"},
    {NO, YES, @"Rear 3D"},
};
#define N_POSS_CAM   (sizeof(possibleCameras)/sizeof(struct camera_t))

#define IS_CAMERA(s)        ((s).cameraIndex != NOT_A_CAMERA)
#define IS_FRONT_CAMERA(s)  (IS_CAMERA(s) && possibleCameras[(s).cameraIndex].front)
#define IS_3D_CAMERA(s)     (IS_CAMERA(s) && possibleCameras[(s).cameraIndex].threeD)

#define IS_PLUS_ON      (plusMode == PlusOne)
#define IS_PLUS_LOCKED  (plusMode == PlusMany)

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

MainVC *mainVC = nil;

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

@property (nonatomic, strong)   UIBarButtonItem *flipBarButton;
@property (nonatomic, strong)   UIBarButtonItem *sourceBarButton;

@property (nonatomic, strong)   UIBarButtonItem *depthBarButton;
@property (nonatomic, strong)   Frame *lastDisplayedFrame;  // what's on the screen

// in containerview:
@property (nonatomic, strong)   UIView *paramView;
@property (nonatomic, strong)   UILabel *paramLabel;
@property (nonatomic, strong)   UISlider *paramSlider;

@property (nonatomic, strong)   UIView *flashView;
@property (nonatomic, strong)   UILabel *layoutValuesView;
@property (nonatomic, strong)   UILabel *mainStatsView;

@property (assign)              BOOL showControls, live;
@property (assign)              BOOL transformChainChanged;
@property (nonatomic, strong)   UILabel *paramLow, *paramName, *paramHigh, *paramValue;

@property (nonatomic, strong)   NSString *overlayDebugStatus;
@property (nonatomic, strong)   UIButton *runningButton, *snapButton;
@property (nonatomic, strong)   UIImageView *transformView; // transformed image
@property (nonatomic, strong)   UIView *thumbsView;         // transform thumbs view of thumbArray
@property (nonatomic, strong)   UITextView *executeView;    // active transform list
@property (nonatomic, strong)   NSMutableArray *layouts;    // approved list of current layouts
@property (assign)              long layoutIndex;           // index into layouts

@property (nonatomic, strong)   UINavigationController *helpNavVC;
// in sources view
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (assign)              NSInteger currentSourceIndex, nextSourceIndex;
@property (nonatomic, strong)   UIImageView *cameraSourceThumb; // non-nil if selecting source
@property (nonatomic, strong)   Frame *fileSourceFrame;    // what we are transforming, or nil if get an image from the camera
@property (nonatomic, strong)   InputSource *fileSource;
@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (assign)              int cameraCount;

@property (nonatomic, strong)   Transforms *transforms;
@property (assign)              long currentTransformIndex; // or NO_TRANSFORM

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   UILabel *allStatsLabel;

@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;

@property (nonatomic, strong)   UIBarButtonItem *trashBarButton;
@property (nonatomic, strong)   UIBarButtonItem *hiresButton;
@property (nonatomic, strong)   UIBarButtonItem *undoBarButton;
@property (nonatomic, strong)   UIBarButtonItem *shareBarButton;

@property (nonatomic, strong)   UIBarButtonItem *plusBarButtonItem;
@property (nonatomic, strong)   UIBarButtonItem *cameraBarButtonItem;

@property (assign)              PlusMode plusMode;

@property (assign)              BOOL busy;      // transforming is busy, don't start a new one

//@property (assign)              UIImageOrientation imageOrientation;
@property (assign)              UIDeviceOrientation deviceOrientation;

@property (nonatomic, strong)   Layout *layout;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthBuf *rawDepthBuf;
@property (assign)              CGSize transformDisplaySize;

@property (nonatomic, strong)   UISegmentedControl *sourceSelectionView;

@property (nonatomic, strong)   UISegmentedControl *uiSelection;
@property (nonatomic, strong)   UIScrollView *thumbScrollView;

@property (assign)              BOOL imageDumpRequested;

@end

@implementation MainVC

@synthesize taskCtrl;
@synthesize screenTasks, thumbTasks, externalTasks;
@synthesize hiresTasks;
@synthesize screenTask, externalTask;

@synthesize containerView;
@synthesize depthBarButton, flipBarButton, sourceBarButton;
@synthesize transformView;
@synthesize transformChainChanged;
@synthesize overlayDebugStatus;
@synthesize runningButton, snapButton;
@synthesize thumbViewsArray, thumbsView;
@synthesize layouts, layoutIndex;
@synthesize helpNavVC;
@synthesize mainStatsView;

@synthesize paramView, paramLabel, paramSlider;
@synthesize showControls, flashView;
@synthesize paramLow, paramName, paramHigh, paramValue;

@synthesize executeView;
@synthesize layoutValuesView;

@synthesize plusBarButtonItem;
@synthesize cameraBarButtonItem;

@synthesize deviceOrientation;
@synthesize isPortrait, isiPhone;

@synthesize sourcesNavVC;
@synthesize options;

@synthesize currentSourceIndex, nextSourceIndex;
@synthesize inputSources;
@synthesize cameraSourceThumb;
@synthesize currentTransformIndex;
@synthesize fileSourceFrame;
@synthesize live;
@synthesize cameraCount;

@synthesize cameraController;
@synthesize layout;

@synthesize undoBarButton, shareBarButton, trashBarButton;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy, plusMode;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize hiresButton;

@synthesize rowIsCollapsed;
@synthesize rawDepthBuf;
@synthesize transformDisplaySize;
@synthesize sourceSelectionView;
@synthesize uiSelection;
@synthesize thumbScrollView;
@synthesize imageDumpRequested;
@synthesize lastDisplayedFrame;
@synthesize stats;

- (id) init {
    self = [super init];
    if (self) {
        mainVC = self;  // a global is easier

        transforms = [[Transforms alloc] init];
        
        currentTransformIndex = NO_TRANSFORM;
        fileSourceFrame = nil;
        layout = nil;
        helpNavVC = nil;
        showControls = NO;
        transformChainChanged = NO;
        plusMode = NoPlus;
        imageDumpRequested = NO;
        lastDisplayedFrame = nil;
        layouts = [[NSMutableArray alloc] init];
        taskCtrl = [[TaskCtrl alloc] init];
        deviceOrientation = UIDeviceOrientationUnknown;
        stats = [[Stats alloc] init];
        
        screenTasks = [taskCtrl newTaskGroupNamed:@"Screen"];
        thumbTasks = [taskCtrl newTaskGroupNamed:@"Thumbs"];
        //externalTasks = [taskCtrl newTaskGroupNamed:@"External"];
        
        transformTotalElapsed = 0;
        transformCount = 0;
        rawDepthBuf = nil;
        thumbScrollView = nil;
        busy = NO;
        options = [[Options alloc] init];
        
        overlayDebugStatus = nil;
        
        isiPhone  = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
        
#if TARGET_OS_SIMULATOR
        cameraController = nil;
        NSLog(@"No camera on simulator");
#else
        cameraController = [[CameraController alloc] init];
        cameraController.videoProcessor = self;
        cameraController.stats = self.stats;
#endif

        inputSources = [[NSMutableArray alloc] init];
        cameraSourceThumb = nil;
        cameraCount = 0;
        
        if (HAVE_CAMERA) {
            for (int ci=0; ci<N_POSS_CAM; ci++) {
                if ([cameraController selectCameraOnSide:possibleCameras[ci].front]) {
                    cameraCount++;
                    InputSource *newSource = [[InputSource alloc] init];
                    [newSource makeCameraSource:possibleCameras[ci].name
                                    cameraIndex:ci];
                    [inputSources addObject:newSource];
                }
            }
        }
        // [self dumpInputCameraSources];

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
        
        currentSourceIndex = [[NSUserDefaults standardUserDefaults]
                              integerForKey: LAST_SOURCE_KEY];
//        NSLog(@"III loading source index %ld, %@", (long)currentSourceIndex, CURRENT_SOURCE.label);
        
        if (currentSourceIndex == NO_SOURCE) {  // select default source
            for (currentSourceIndex=0; currentSourceIndex<inputSources.count; currentSourceIndex++) {
                if (HAVE_CAMERA) {
                    if (IS_CAMERA(CURRENT_SOURCE)) {
                        NSLog(@"first source is default camera");
                        break;
                    }
                } else {
                    if (!IS_CAMERA(CURRENT_SOURCE)) {
                        NSLog(@"first source is file '%@'", CURRENT_SOURCE.label);
                        break;
                    }
                }
                assert(currentSourceIndex != NO_SOURCE);
            }
        }
        nextSourceIndex = currentSourceIndex;
        currentSourceIndex = NO_SOURCE;
        nextSourceIndex = 0;    // XXXXXX DEBUG
    }
    return self;
}

- (void) dumpInputCameraSources {
    for (int i=0; i < inputSources.count && IS_CAMERA(SOURCE(i)); i++) {
        NSLog(@"camera source %d  ci %ld   %@  %@", i, SOURCE(i).cameraIndex,
              IS_FRONT_CAMERA(SOURCE(i)) ? @"front" : @"rear ",
              IS_3D_CAMERA(SOURCE(i)) ? @"3D" : @"2D");
    }
}

- (void) createThumbArray {
    thumbViewsArray = [[NSMutableArray alloc] init];

    UITapGestureRecognizer *touch;
    NSString *lastSection = nil;

    for (size_t ti=0; ti<transforms.transforms.count; ti++) {
        Transform *transform = [transforms.transforms objectAtIndex:ti];
        ThumbView *thumbView = [[ThumbView alloc] init];

        NSString *section = [transform.helpPath pathComponents][0];
        if (!lastSection || ![lastSection isEqualToString:section]) {   // new section.
            [thumbView configureSectionThumbNamed:section];
            [thumbViewsArray addObject:thumbView];  // Add section thumb, then...
            
            thumbView = [[ThumbView alloc] init];   // a new thumbview for the actual transform
            thumbView.transform = transform;
            lastSection = section;
        }
        [thumbView configureForTransform:transform];
        thumbView.tag = ti + TRANSFORM_BASE_TAG;
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.tag = THUMB_IMAGE_TAG;
        [thumbView addSubview:imageView];
        
        if (transform.broken) {
            [thumbView adjustStatus:ThumbTransformBroken];
        } else {
            [thumbView adjustStatus:ThumbAvailable];
        }
        
        touch = [[UITapGestureRecognizer alloc]
                 initWithTarget:self
                 action:@selector(didTapThumb:)];
        thumbView.task = [thumbTasks createTaskForTargetImageView:imageView
                                                       named:transform.name];
        thumbView.task.enabled = YES;
        [thumbView.task appendTransformToTask:transform];
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

    CGRect transformNameRect;
    transformNameRect.origin = CGPointMake(0, BELOW(layout.thumbImageRect));
    transformNameRect.size = CGSizeMake(nextButtonFrame.size.width, THUMB_LABEL_H);
    CGRect sectionNameRect = CGRectMake(THUMB_LABEL_SEP, SEP,
                                        nextButtonFrame.size.width - 2*THUMB_LABEL_SEP,
                                        nextButtonFrame.size.height - 2*SEP);
    
    UIImage *noDepthImage = nil;
    if (![cameraController depthDataAvailable]) {
        NSString *noDepthPath = [[NSBundle mainBundle]
                                pathForResource:@"images/no3Dcamera.png" ofType:@""];
        noDepthImage = [UIImage imageNamed:noDepthPath];
    }

    // Run through all the transform and section thumbs, computing the corresponding thumb sizes and
    // positions for the current situation. These thumbs come in section, each of which has
    // their own section header thumb display. This header starts on a new line (if vertical
    // thumb placement) or after a space on horizontal placements.
    
    atStartOfRow = YES;
    CGFloat thumbsH = 0;
//    NSString *lastSection = nil;
    
    // run through the thumbview array
    for (ThumbView *thumbView in thumbViewsArray) {
        if (thumbView.status == SectionHeader) {   // new section
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
        } else {
            thumbView.userInteractionEnabled = !thumbView.transform.broken;
#ifdef DEBUG_THUMB_LAYOUT
            NSLog(@"%3.0f,%3.0f  %3.0fx%3.0f   Transform %@",
                  nextButtonFrame.origin.x, nextButtonFrame.origin.y,
                  nextButtonFrame.size.width, nextButtonFrame.size.height,
                  transform.name);
#endif
            UIImageView *thumbImage = [thumbView viewWithTag:THUMB_IMAGE_TAG];
            thumbImage.frame = layout.thumbImageRect;
            if (thumbView.transform.type == DepthVis) {
                [thumbView adjustStatus: (lastDisplayedFrame.depthBuf != nil) ? ThumbAvailable : ThumbUnAvailable];
            } else {
                thumbImage.image = noDepthImage;
            }
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

- (void) saveSourceIndex {
    assert(currentSourceIndex != NO_SOURCE);
//    NSLog(@"III saving source index %ld, %@", (long)currentSourceIndex, CURRENT_SOURCE.label);
    [[NSUserDefaults standardUserDefaults] setInteger:currentSourceIndex forKey:LAST_SOURCE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

#ifdef DEBUG_ORIENTATION
    NSLog(@"OOOO viewDidLoad orientation: %@",
          [CameraController dumpDeviceOrientationName:deviceOrientation]);
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
                                             action:@selector(selectSource:)];
    
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
    
    trashBarButton = [[UIBarButtonItem alloc]
                      initWithImage:[UIImage systemImageNamed:@"trash"]
                      style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(doRemoveAllTransforms)];
    
    hiresButton = [[UIBarButtonItem alloc]
                   initWithTitle:@"Hi res" style:UIBarButtonItemStylePlain
                   target:self action:@selector(doToggleHires:)];
    
    shareBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                     style:UIBarButtonItemStylePlain
                     target:self
                      action:@selector(doShare:)];
    
    undoBarButton = [[UIBarButtonItem alloc]
                     initWithImage:[UIImage systemImageNamed:@"arrow.uturn.backward"]
                     style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(doRemoveLastTransform)];
     
    UIBarButtonItem *docBarButton = [[UIBarButtonItem alloc]
//                                     initWithImage:[UIImage systemImageNamed:@"doc.text"]
                                     initWithTitle:@"?"
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(doHelp:)];

#define NAVBAR_H   self.navigationController.navigationBar.frame.size.height
    
#ifdef SWIFTONLY
    UIMenu *plusMenu = [[UIMenu alloc] init];
    plusMenu.
    UIBarButtonItem *plusButton = [[UIBarButtonItem alloc]
                                   initWithImage:
                                   menu:<#(nullable UIMenu *)#>]
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Menu", image: nil, primaryAction: nil, menu: demoMenu)
    
    cameraBarButtonItem = [[UIBarButtonItem alloc] initWithImage:nil
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(doCamera:)];
    UIImage *newImage = [UIImage systemImageNamed:@"star"];
    assert(newImage);
    cameraBarButtonItem.image = newImage;
    cameraBarButtonItem.enabled = (cameraCount > 0);

#endif
    
    plusBarButtonItem = [[UIBarButtonItem alloc] initWithImage:nil
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(doPlus:)];
    [self adjustPlusTo:NoPlus];
        
    depthBarButton = [[UIBarButtonItem alloc] initWithImage:nil
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(doVideoAndDepth:)];
    
    self.navigationItem.leftBarButtonItems = [[NSArray alloc] initWithObjects:
                                              sourceBarButton,
//                                              depthBarButton,
                                              flipBarButton,
                                              plusBarButtonItem,
                                              nil];
    
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:
                                               docBarButton,
//                                               fixedSpace,
                                               shareBarButton,
//                                               fixedSpace,
                                               undoBarButton,
//                                               fixedSpace,
                                               trashBarButton,
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
    paramView.backgroundColor = [UIColor colorWithRed:0.5 green:1.0 blue:0.0 alpha:0.5];
    paramView.hidden = YES;
    paramView.opaque = NO;
    paramView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    paramView.layer.cornerRadius = 6.0;
    paramView.clipsToBounds = YES;
    [transformView addSubview:paramView];

    paramLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, LATER, PARAM_LABEL_H)];
    paramLabel.textAlignment = NSTextAlignmentCenter;
    paramLabel.font = [UIFont boldSystemFontOfSize:PARAM_LABEL_FONT_SIZE];
    paramLabel.textColor = [UIColor blackColor];
    [paramView addSubview:paramLabel];

    paramSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, BELOW(paramLabel.frame) + SEP, LATER, PARAM_SLIDER_H)];
    paramSlider.continuous = YES;
    [paramSlider addTarget:self action:@selector(doParamSlider:)
          forControlEvents:UIControlEventValueChanged];
    [paramView addSubview:paramSlider];

    SET_VIEW_HEIGHT(paramView, BELOW(paramSlider.frame) + SEP);
    
    executeView = [[UITextView alloc]
                   initWithFrame: CGRectMake(0, LATER, LATER, LATER)];
    executeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    executeView.userInteractionEnabled = NO;
    executeView.font = [UIFont boldSystemFontOfSize: EXECUTE_FONT_SIZE];
    executeView.textColor = [UIColor blackColor];
    executeView.text = @"";
    executeView.opaque = YES;

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
    [containerView addSubview:executeView];
    
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
}

- (void) viewWillTransitionToSize:(CGSize)newSize
        withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:newSize withTransitionCoordinator:coordinator];
    
    // "Note that iPhoneX series (with notch) does not support portrait upside down."
    
#ifdef DEBUG_ORIENTATION
    NSLog(@"OOOO viewWillTransitionToSize orientation: %@",
          [CameraController dumpDeviceOrientationName:deviceOrientation]);

    NSLog(@"                                     Size: %.0f x %.0f", newSize.width, newSize.height);
#else
#ifdef DEBUG_LAYOUT
    NSLog(@"********* viewWillTransitionToSize: %.0f x %.0f", newSize.width, newSize.height);
#endif
#endif

    [taskCtrl idleFor:NeedsNewLayout];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
#ifdef DEBUG_LAYOUT
    NSLog(@"OOOO viewWillAppear orientation: %@",
          [CameraController dumpDeviceOrientationName:deviceOrientation]);
#else
#ifdef DEBUG_ORIENTATION
    NSLog(@"OOOO viewWillAppear orientation: %@",
          [CameraController dumpDeviceOrientationName:deviceOrientation]);
#endif
#endif
    // not needed: we haven't started anything yet
    [taskCtrl idleFor:NeedsNewLayout];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

#ifdef DEBUG_ORIENTATION
    NSLog(@"OOOO viewDidAppear orientation: %@",
          [CameraController dumpDeviceOrientationName:deviceOrientation]);
    NSLog(@"                          size: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#else
#ifdef DEBUG_LAYOUT
    NSLog(@"--------- viewDidAppear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
#endif
#endif
    
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

- (void) newDeviceOrientation {
    UIDeviceOrientation nextOrientation = [[UIDevice currentDevice] orientation];
#ifdef DEBUG_ORIENTATION
    NSLog(@"OOOO new orientation: %@",
          [CameraController dumpDeviceOrientationName:deviceOrientation]);
#endif
    if (nextOrientation == UIDeviceOrientationUnknown)
        nextOrientation = UIDeviceOrientationPortraitUpsideDown;    // klduge, don't know why
    if (nextOrientation == deviceOrientation)
        return; // nothing new to see here, folks
    deviceOrientation = nextOrientation;
    if (layout) // already layed out, adjust it
        [taskCtrl idleFor:NeedsNewLayout];
}

- (void) tasksReadyFor:(LayoutStatus_t) layoutStatus {
    switch (layoutStatus) {
        case LayoutOK:
            assert(NO); // should not be ok yet
            break;
        case NeedsNewLayout:
            // On entry:
            //  currentSource or nextSource
            //  transform tasks must be idle
            if (nextSourceIndex != NO_SOURCE) {   // change sources
                if (live) {
                    [self liveOn:NO];
                }
                
                currentSourceIndex = nextSourceIndex;
                transformChainChanged = YES;
                //        NSLog(@"III switching to source index %ld, %@",
                //  (long)currentSourceIndex, CURRENT_SOURCE.label);
                nextSourceIndex = NO_SOURCE;
                InputSource *source = inputSources[currentSourceIndex];
                
                if (!isiPhone)
                    self.title = source.label;
                
                if (IS_CAMERA(source)) {
                    [cameraController updateOrientationTo:deviceOrientation];
                    [cameraController selectCameraOnSide:IS_FRONT_CAMERA(source)];
                    [self liveOn:YES];
                } else {    // source is a file, it is our source image
                    fileSourceFrame = [[Frame alloc] init];
                    [fileSourceFrame readImageFromPath: source.imagePath];
                    transformChainChanged = YES;
                }
                [self saveSourceIndex];
            }
            
            [self doLayout];
            taskCtrl.state = ApplyLayout;
            // FALLTHROUGH
        case ApplyLayout:
            [self applyScreenLayout: layoutIndex];     // top one is best
    }
    taskCtrl.state = LayoutOK;
}

- (void) doLayout {
#ifdef DEBUG_LAYOUT
    NSLog(@" *** newlayout, new source is %ld", (long)nextSourceIndex);
#endif
    isPortrait = UIDeviceOrientationIsPortrait(deviceOrientation) ||
        UIDeviceOrientationIsFlat(deviceOrientation);
    [layouts removeAllObjects];
    
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
    f.size.height -= f.origin.y;
    f.size.width = self.view.frame.size.width - rightPadding - f.origin.x;
    containerView.frame = f;
#ifdef DEBUG_LAYOUT
    NSLog(@"     containerview: %.0f,%.0f  %.0fx%.0f (%4.2f)",
          f.origin.x, f.origin.y, f.size.width, f.size.height,
          f.size.width/f.size.height);
#endif

//  [self simpleLayouts];
    [self tryAllThumbLayouts];
    assert(layouts.count > 0);
    
    // sort the layouts by decreasing screen size.  Start with the
    // layout with the highest score.
    
    [layouts sortUsingComparator:^NSComparisonResult(Layout *l1, Layout *l2) {
        // sort in decending order, hence l1 and l2 are switched
        return [[NSNumber numberWithFloat:l2.displayFrac]
                compare:[NSNumber numberWithFloat:l1.displayFrac]];
    }];
    
    // run down through the layouts, from largest display to smallest, removing
    // ones that are essentially duplicates.
    
    NSMutableArray *editedLayouts = [[NSMutableArray alloc] init];
    
    float topScore = -1;;
    Layout *previousLayout = nil;

//    NSLog(@"LLLL scanning %lu layouts", (unsigned long)layouts.count);
    for (Layout *layout in layouts) {
#ifdef NOTDEF
        NSLog(@"CCCC format: %@", layout.format);
        NSLog(@"   dformats: %@", layout.format.supportedDepthDataFormats);
        NSLog(@"%3d   %.3f  %.3f %.3f    %lu", i++,
              layout.displayFrac, layout.score, layout.thumbFrac,
              (unsigned long)editedLayouts.count);
#endif
        if (layouts.count == 0) {   // first one
            topScore = layout.score;
            layoutIndex = layouts.count;
            [editedLayouts addObject:layout];
            previousLayout = layout;
            continue;
        }
        // find best depth format for this.  Must have same aspect ratio, and correct type.

        NSArray<AVCaptureDeviceFormat *> *depthFormats = layout.format.supportedDepthDataFormats;
        layout.depthFormat = nil;
        for (AVCaptureDeviceFormat *depthFormat in depthFormats) {
            if (![CameraController depthFormat:depthFormat isSuitableFor:layout.format])
                continue;
            layout.depthFormat = depthFormat;
        }

#ifdef NOTDEF
        if (i % 10 == 0)
            NSLog(@"pause %d", i);
        NSLog(@"   %.3f %.3f  %@    %2d %2d  %@    %.3f  %.3f  %@",
              layout.displayFrac, previousLayout.displayFrac,
              layout.displayFrac == previousLayout.displayFrac ? @"= " : @"!=",
              layout.thumbsPosition, previousLayout.thumbsPosition,
              layout.thumbsPosition == previousLayout.thumbsPosition ? @"= " : @"!=",
              layout.thumbFrac, previousLayout.thumbFrac,
              layout.thumbFrac == previousLayout.thumbFrac ? @"= " : @"!=");
#endif
        if (layout.displayFrac == previousLayout.displayFrac &&
            layout.thumbsPosition == previousLayout.thumbsPosition &&
            layout.thumbFrac == previousLayout.thumbFrac) {
            if (layout.score >= previousLayout.score) { // discard previous
                [editedLayouts replaceObjectAtIndex:editedLayouts.count-1 withObject:layout];
            }
        } else {
            [editedLayouts addObject:layout];
        }
        if (layout.score > topScore) {
            topScore = layout.score;
            layoutIndex = editedLayouts.count - 1;
        }
        previousLayout = layout;
    }
//    NSLog(@"LLLL remaining layouts: %lu, top score %.5f at %ld",
//          (unsigned long)editedLayouts.count, topScore, layoutIndex);
    layouts = editedLayouts;
    
#ifdef DEBUG_LAYOUT
    int i = 0;
    for (Layout *layout in layouts) {
        NSLog(@"%3d   %.3f  %.3f %.3f    %@", i,
              layout.displayFrac, layout.score, layout.thumbFrac,
              i == layoutIndex ? @"<---" : @"");
        i++;
    }
    
    for (int i=0; i<layouts.count; i++ ) {
        Layout *layout = layouts[i];
        NSLog(@"%2d %@", i, layout.status);
    }
#endif
    
    [self adjustControls];
    [self adjustBarButtons];
}

- (void) applyScreenLayout:(long) newLayoutIndex {
    assert(newLayoutIndex >= 0 && newLayoutIndex < layouts.count);
    
    layoutIndex = newLayoutIndex;
    layout = layouts[layoutIndex];
#ifdef DEBUG_LAYOUT
    NSLog(@"applyScreenLayout %ld", layoutIndex);
    NSLog(@"screen format %@", layout.format);
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
    
    transformView.frame = layout.displayRect;
    [self positionControls];
    thumbScrollView.frame = layout.thumbArrayRect;
    thumbScrollView.layer.borderColor = [UIColor cyanColor].CGColor;
    thumbScrollView.layer.borderWidth = 3.0;
    
    CGFloat below = BELOW(thumbScrollView.frame);
    assert(below <= BELOW(containerView.frame));

    thumbsView.frame = CGRectMake(0, 0,
                                  thumbScrollView.frame.size.width,
                                  thumbScrollView.frame.size.height);
#ifdef NOTDEF
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
    
    taskCtrl.sourceSize = layout.imageSourceSize;
    [screenTasks configureGroupForTargetSize:layout.transformSize];
    [thumbTasks configureGroupForTargetSize:layout.thumbImageRect.size];
//    [externalTask configureGroupForTargetSize:processingSize];

// no longer?    [layout positionExecuteRect];
    executeView.frame = layout.executeRect;
    if (DISPLAYING_THUMBS) { // if we are displaying thumbs...
        [UIView animateWithDuration:0.5 animations:^(void) {
            // move views to where they need to be now.
            [self layoutThumbs: self->layout];
        }];
    }
    
    layoutValuesView.frame = transformView.frame;
    [containerView bringSubviewToFront:layoutValuesView];
    NSString *formatList = @"";
    long start = newLayoutIndex - 6;
    long finish = newLayoutIndex + 6;
    if (start < 0)
        start = 0;
    if (finish > layouts.count)
        finish = layouts.count;
    for (long i=start; i<finish; i++) {
        if (i > start)
            formatList = [formatList stringByAppendingString:@"\n"];
        NSString *cursor = newLayoutIndex == i ? @">" : @" ";
        Layout *layout = layouts[i];
        NSString *line = [NSString stringWithFormat:@"%@%@", cursor, layout.status];
        formatList = [formatList stringByAppendingString:line];
#ifdef DEBUG_LAYOUT
        if (i == newLayoutIndex)
            NSLog(@"%1ld-%@", i, layout.status);
        else
            NSLog(@"%1ld %@", i, layout.status);
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
    [taskCtrl enableTasks];
    if (fileSourceFrame)
        [self doTransformsOnFrame:fileSourceFrame];
    else {
        [cameraController setupCameraSessionWithFormat:layout.format depthFormat:layout.depthFormat];
        //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformImageView.layer;
        //cameraController.captureVideoPreviewLayer = previewLayer;
        [cameraController startCamera];
    }
}

- (void) tryAllThumbLayouts {
    if (fileSourceFrame) {
        [self tryAllThumbsForSize:fileSourceFrame.pixBuf.size format:nil];
    } else {
        assert(cameraController);
        assert(live);   // select camera setting for available area
#ifdef XXXXXX
        [cameraController updateOrientationTo:deviceOrientation];
        [cameraController selectCameraOnSide:IS_FRONT_CAMERA(CURRENT_SOURCE)
                                      threeD:IS_3D_CAMERA(CURRENT_SOURCE)];
#endif
        for (AVCaptureDeviceFormat *format in cameraController.formatList) {
            if (cameraController.depthDataAvailable) {
                if (!format.supportedDepthDataFormats || format.supportedDepthDataFormats.count == 0)
                    continue;   // we want depth, if available
            }
            CGSize formatSize = [cameraController sizeForFormat:format];
            [self tryAllThumbsForSize:formatSize format:format];
       }
    }
}

- (void) tryAllThumbsForSize:(CGSize) size
                      format:(AVCaptureDeviceFormat *)format {
    // first, layout full-screen version
    Layout *trialLayout = [[Layout alloc] init];
    if (format)
        trialLayout.format = format;
    if ([trialLayout tryLayoutForSize:size
                            thumbRows:0
                         thumbColumns:0]) {
        if (trialLayout.score) {
            [layouts addObject:trialLayout];
        }
    }
    
    for (int thumbColumns=2; ; thumbColumns++) {
        Layout *trialLayout = [[Layout alloc] init];
        if (format)
            trialLayout.format = format;
        if (![trialLayout tryLayoutForSize:size
                           thumbRows:0
                        thumbColumns:thumbColumns]) {
            break;  // can't be done
        }
        if (!trialLayout.score)
            continue;
        [layouts addObject:trialLayout];
    }
    
    for (int thumbRows=2; ; thumbRows++) {
        Layout *trialLayout = [[Layout alloc] init];
        if (format)
            trialLayout.format = format;
        if (![trialLayout tryLayoutForSize:size
                           thumbRows:thumbRows
                        thumbColumns:0]) {
            break;  // can't be done
        }
        if (!trialLayout.score)
            continue;
        [layouts addObject:trialLayout];
    }
}

- (void) adjustBarButtons {
    trashBarButton.enabled = screenTask.transformList.count > 0;
    undoBarButton.enabled = screenTask.transformList.count > 0;

    NSString *imageName;
    if (!cameraCount) { // never a camera here
        flipBarButton.enabled = depthBarButton.enabled = NO;
        imageName = @"video";
    } else {
        if (!IS_CAMERA(CURRENT_SOURCE)) { // not using a camera at the moment
            depthBarButton.enabled = YES;   // to select the camera
            imageName = @"video";
        } else {
            struct camera_t cam = possibleCameras[CURRENT_SOURCE.cameraIndex];
            flipBarButton.image = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath.camera"];
            flipBarButton.enabled = [self flipOfCurrentSource] != NO_SOURCE;
 //           NSLog(@"AAAA flip enabled: %d for front: %d 3d:%d", flipBarButton.enabled, cam.front, cam.threeD);
            depthBarButton.enabled = [self otherDepthOfCurrentSource] != NO_SOURCE;
            imageName = !cam.threeD ? @"view.3d" : @"view.2d";
        }
    }
    depthBarButton.image = [UIImage systemImageNamed:imageName];
}

// do we have an input camera source that is the flip of the current source?
// search the camera inputs.
- (long) flipOfCurrentSource {
    for (int i=0; i < inputSources.count && IS_CAMERA(SOURCE(i)); i++) {
        if (SOURCE_INDEX_IS_3D(currentSourceIndex) != SOURCE_INDEX_IS_3D(i))
            continue;
        if (SOURCE_INDEX_IS_FRONT(currentSourceIndex) != SOURCE_INDEX_IS_FRONT(i))
            return i;
    }
    return NO_SOURCE;
}

// do we have an input camera source that is the depth alternative to the current source?
// search the camera inputs.
- (long) otherDepthOfCurrentSource {
    for (int i=0; i < inputSources.count && IS_CAMERA(SOURCE(i)); i++) {
        if (SOURCE_INDEX_IS_FRONT(currentSourceIndex) != SOURCE_INDEX_IS_FRONT(i))
            continue;
        if (SOURCE_INDEX_IS_3D(currentSourceIndex) != SOURCE_INDEX_IS_3D(i))
            return i;
    }
    return NO_SOURCE;
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

    Transform *lastTransform = nil;
    if (screenTask.transformList.count) {
        lastTransform = screenTask.transformList[screenTask.transformList.count - 1];
    }
    
    if (IS_PLUS_LOCKED || IS_PLUS_ON) {  // add new transform
        [screenTask appendTransformToTask:tappedTransform];
        [screenTask configureTaskForSize];
        [tappedThumb adjustStatus:ThumbActive];
//        if (!IS_PLUS_LOCKED)
//            [self adjustPlusTo:NoPlus];
    } else {    // not plus mode
#ifdef NEW
        if (screenTasks.tasks.count > 0) {  // clear everything
            [self deselectAllThumbs];
            [self transformChainAdjusted];
        }
#endif
        // XXX in minus mode, selecting a selected transform should simply remove it
        if (lastTransform) {
            BOOL reTap = [tappedTransform.name isEqual:lastTransform.name];
            [screenTask removeLastTransform];
            ThumbView *oldThumb = [self thumbForTransform:lastTransform];
            [oldThumb adjustStatus:ThumbAvailable];
            if (reTap) {
                // retapping a transform in not plus mode means just remove it, and we are done
                [self updateExecuteView];
                [self adjustBarButtons];
                tappedTransform = nil;
            }

        }
        if (tappedTransform) {
            [screenTask appendTransformToTask:tappedTransform];
            [tappedThumb adjustStatus:ThumbActive];
        }
        [screenTask configureTaskForSize];
    }
    transformChainChanged = YES;
    [self doTransformsOnFrame:lastDisplayedFrame];
//    [self updateOverlayView];
    [self adjustParametersFrom:lastTransform to:tappedTransform];
    [self updateExecuteView];
    [self adjustBarButtons];
}

- (void) adjustParametersFrom:(Transform *)oldTransform to:(Transform *)newTransform {
    BOOL oldParameters = oldTransform && oldTransform.hasParameters;
    BOOL newParameters = newTransform && newTransform.hasParameters;
    if (oldParameters) {
        [UIView animateWithDuration:0.5 animations:^(void) {
            SET_VIEW_Y(self->paramView, BELOW(self->transformView.frame));
        } completion:^(BOOL finished) {
            if (newParameters) {
                [UIView animateWithDuration:0.5 animations:^(void) {
                    SET_VIEW_Y(self->paramView, self->transformView.frame.size.height - self->paramView.frame.size.height);
                    [self adjustParamView];
                }];
            }
        }];
    } else if (newParameters) {
        [UIView animateWithDuration:0.5 animations:^(void) {
            SET_VIEW_Y(self->paramView, self->transformView.frame.size.height - self->paramView.frame.size.height);
            [self adjustParamView];
        }];
    }
}

- (IBAction) doPlus:(UIBarButtonItem *)caller {
    PopoverMenuVC *popMenuVC = [[PopoverMenuVC alloc]
                                initWithFrame: CGRectMake(0, 0, PLUS_W, LATER)
                                entries:PLUS_MODE_COUNT
                                title:@"Stacking"
                                target:self
                                formatCell:^(UITableViewCell * _Nonnull cell, long menuRow) {
                                    [self formatPlusPopoverCell:cell forRow:menuRow];
                                }
                                selectRow:^(long rowSelected) {
                                    [self adjustPlusTo:(int)rowSelected];
                                }];

    UINavigationController *popNavVC = [popMenuVC prepareMenuUnder:caller];
    [self presentViewController:popNavVC animated:YES completion:nil];
}

- (void) formatPlusPopoverCell:(UITableViewCell *)cell forRow:(long)row {
    cell.textLabel.text = plusNames[row];
    cell.highlighted = (row == self->plusMode);
    //    cell.textLabel.font = [UIFont systemFontOfSize:PLUS_ROW_H];
    UIImage *image = [UIImage systemImageNamed:plusImageNames[row]];
    if (!image) {
        NSLog(@"menu image missing: %@", plusImageNames[row]);
        assert(image);
    }
    cell.accessoryView = [[UIImageView alloc] initWithImage:image];
}

- (void) adjustPlusTo:(PlusMode) newPlusMode {
    if (newPlusMode == POPMENU_ABORTED)
        return;
    UIImage *newImage = [UIImage systemImageNamed:plusImageNames[newPlusMode]];
    assert(newImage);
    plusBarButtonItem.image = newImage;
    plusMode = newPlusMode;
}

// If the camera is off, turn it on, to the first possible setting,
// almost certainly the front camera, 2d.  Otherwise, change the depth.

- (IBAction) doVideoAndDepth:(UIBarButtonItem *)caller {
    if (!IS_CAMERA(CURRENT_SOURCE)) { // select default camera
        nextSourceIndex = 0;
    } else {
        long ci = CURRENT_SOURCE.cameraIndex;
        nextSourceIndex = 0;
        do {
            // [self dumpInputCameraSources];
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
}

#ifdef OLD
- (IBAction) doCamera:(UIBarButtonItem *)caller {
    PopoverMenuVC *popMenuVC = [[PopoverMenuVC alloc]
                                initWithFrame: CGRectMake(0, 0, PLUS_W, LATER)
                                entries:cameraCount
                                title:@"Cameras"
                                target:self
                                formatCell:^(UITableViewCell * _Nonnull cell, long menuRow) {
                                    [self formatCameraPopoverCell:cell forRow:menuRow];
                                }
                                selectRow:^(long rowSelected) {
                                    [self selectCamera:rowSelected];
                                }];

    UINavigationController *popNavVC = [popMenuVC prepareMenuUnder:caller];
    [self presentViewController:popNavVC animated:YES completion:nil];
}

- (void) formatCameraPopoverCell:(UITableViewCell *)cell forRow:(long)row {
    InputSource *cameraSource = [inputSources objectAtIndex:row];
    long cameraIndex = cameraSource.cameraIndex;
    cell.textLabel.text = possibleCameras[cameraIndex].name;
    if (currentSourceIndex == row) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.highlighted = YES;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.highlighted = NO;
    }
    //    cell.textLabel.font = [UIFont systemFontOfSize:PLUS_ROW_H];
    cell.imageView.image = [self cameraImageForCamera:row height:cell.frame.size.height];
#ifdef MAYBENOT
    UIImageView *accessImageView = [[UIImageView alloc] initWithImage:[self cameraImageForCamera:row]];
    accessImageView.contentMode = UIViewContentModeScaleAspectFit;
    accessImageView.frame = CGRectMake(0, 0, cell.frame.size.height, cell.frame.size.width);
    cell.accessoryView = accessImageView;
#endif
}

- (UIImage *) cameraImageForCamera:(long) cameraIndex height:(CGFloat) h {
    NSString *imageName = possibleCameras[cameraIndex].imageName;
    UIImage *image = [UIImage systemImageNamed:imageName];
    if (!image) { // not an SF image, try local bundle image
        NSString *imagePath = [[NSBundle mainBundle]
                               pathForResource:[@"images"
                                                stringByAppendingPathComponent:imageName]
                               ofType:@"png"];
        image = [UIImage imageNamed:imagePath];
    }
    if (!image) {
        NSLog(@"menu image missing: %@", imageName);
        assert(image);
    }
    return image;
}
#endif

#ifdef NOTDEF

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
#endif

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

#ifdef OLD
#define DEBUG_FONT_SIZE 16

-(void) updateOverlayView: (OverlayState) newState {
    // start fresh
    [overlayView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    UILabel *overlayDebug = nil;
    
    overlayState = newState;
    switch (overlayState) {
        case overlayClear:
            //[self.navigationController setNavigationBarHidden:YES animated:YES];
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
            //[self.navigationController setNavigationBarHidden:NO animated:YES];
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
#endif

// pause/unpause video
- (IBAction) togglePauseResume:(UITapGestureRecognizer *)recognizer {
    assert(IS_CAMERA(CURRENT_SOURCE));
    [self liveOn:!live];
}

- (void) liveOn:(BOOL) on {
    live = on;
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
}

// debug: create a pnm file from current live image, and email it

- (IBAction) didLongPressTransformView:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded)
        return;
    imageDumpRequested = YES;
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
    runningButton.enabled = IS_CAMERA(CURRENT_SOURCE);
    runningButton.hidden = !showControls;
    snapButton.hidden = !showControls;
    [runningButton setNeedsDisplay];
}

- (IBAction)doParamSlider:(UISlider *)slider {
    Transform *lastTransform = LAST_TRANSFORM_IN_TASK(screenTask);
    if (!lastTransform || !lastTransform.hasParameters) {
        return;
    }
//    NSLog(@"slider value %.1f", slider.value);
    [slider setNeedsDisplay];
    if ([screenTask updateParamOfLastTransformTo:paramSlider.value]) {
//        [self doTransformsOn:previousSourceImage depth:rawDepthBuf];    // XXXXXX depth of source image
        [self updateParamViewFor: lastTransform];
        [self updateExecuteView];
    }
}

// reveal or hide the parameter slider
- (void) adjustParamView {
    Transform *lastTransform = LAST_TRANSFORM_IN_TASK(screenTask);
    if (!lastTransform || !lastTransform.hasParameters) {
        paramView.hidden = YES;
        SET_VIEW_Y(paramView, transformView.frame.size.height);    // under the bottom
        return;
    }
    paramView.hidden = NO;
//    NSString *lowValue = [NSString stringWithFormat:lastTransform.lowValueFormat, lastTransform.low];
//    NSString *highValue = [NSString stringWithFormat:lastTransform.highValueFormat, lastTransform.high];
    paramSlider.minimumValue = lastTransform.low;
    paramSlider.maximumValue = lastTransform.high;
    paramSlider.value = lastTransform.value;
    [self updateParamViewFor: lastTransform];
    [transformView bringSubviewToFront:paramView];
}

- (void) updateParamViewFor:(Transform *)transform {
     paramLabel.text = [NSString stringWithFormat:@"%@:    %@: %.0f",
                       transform.name,
                       transform.paramName,
                       paramSlider.value];
    [paramLabel setNeedsDisplay];
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

#ifdef OLD
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
#endif

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

// new video frame data and perhaps depth data from the cameracontroller.
// This is a copy of the incoming frame, and further incoming frames will be
// ignored until this routine is done.  At this point, the depth data, if it
// is present, has min and max values computed, but one or more depths may
// be BAD_DEPTH.

- (void) processCapturedFrame:(const Frame * _Nonnull) capturedFrame {
    if (!live || taskCtrl.state != LayoutOK || busy) {
        if (busy)
            busyCount++;
        return;
    }
    busy = YES;
    assert(capturedFrame.pixBuf);       // we require an image
    capturedFrame.pixBuf.readOnly = YES;
    assert(capturedFrame.depthBuf);
    capturedFrame.depthBuf.readOnly = YES;
    [capturedFrame.depthBuf verifyDepthRange];
    [taskCtrl newFrameForTaskGroups:capturedFrame];
    capturedFrame = nil;
    [taskCtrl doPendingGroupTransforms];    // from the frame we just gave them
    busy = NO;
}

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
    [frame.depthBuf verifyDepthRange];
    Frame *displayedFrame = [screenTasks executeTasksWithFrame:frame dumpFile:nil];
    if (displayedFrame) {
        lastDisplayedFrame = displayedFrame;
    }
    if (transformChainChanged)
        [self updateThumbAvailability];

    if (DISPLAYING_THUMBS) {
        if (displayedFrame)
            [thumbTasks executeTasksWithFrame:displayedFrame dumpFile:nil];
    }
    if (cameraSourceThumb) {
        [cameraSourceThumb setImage:[frame toUIImage]];
        [cameraSourceThumb setNeedsDisplay];
    }
}

#ifdef DEBUG_TASK_CONFIGURATION
BOOL haveOrientation = NO;
UIImageOrientation lastOrientation;
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
//    transformDisplayNeedsUpdate = YES;
//    [self updateOverlayView];
    [self updateExecuteView];
    [self adjustBarButtons];
}

- (void) deselectAllThumbs {
    for (ThumbView *thumbView in thumbViewsArray) {
        // deselect all selected thumbs
        if (thumbView.status == ThumbActive)
            [thumbView adjustStatus:ThumbAvailable];
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
    mainStatsView.text = [stats report];
    [mainStatsView setNeedsDisplay];
    [taskCtrl checkForIdle];

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

// The executeView is a list of transforms.  There is a regular list mode, and a compressed
// mode for small, tight screens or long lists of transforms (which should be rare.)

- (void) updateExecuteView {
    NSString *t = nil;
    
    long step = 0;
    long displaySteps = screenTask.transformList.count;
    CGFloat bestH = EXECUTE_H_FOR(displaySteps);
    BOOL onePerLine = !layout.executeIsTight && bestH <= executeView.frame.size.height;
    NSString *sep = onePerLine ? @"\n" : @" ";
    
    for (int i=0; i<displaySteps; i++, step++) {
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
                [self updateParamViewFor:transform];
#ifdef OLD
                paramLabel.text = [NSString stringWithFormat:@"%@  %d  %@",
                                  value == transform.low ? @"[" : @"<",
                                  value,
                                  value == transform.high ? @"]" : @">"];
#endif
                [paramView setNeedsDisplay];
            }
        }
        if (onePerLine && ![transform.description isEqual:@""])
            t = [NSString stringWithFormat:@"%@   (%@)", t, transform.description];
    }
    
    if (IS_PLUS_ON || screenTask.transformList.count == 0)
        t = [t stringByAppendingString:@"  +"];
    executeView.text = t;
    
#ifdef EXECUTERECT
    if (layout.executeOverlayOK || executeView.contentSize.height > executeView.frame.size.height) {
        SET_VIEW_Y(executeView, BELOW(layout.executeRect) - executeView.contentSize.height);
    }
#endif
   
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

static CGSize startingPinchSize;

- (IBAction) doPinch:(UIPinchGestureRecognizer *)pinch {
    switch (pinch.state) {
        case UIGestureRecognizerStateBegan:
            startingPinchSize = layout.displayRect.size;
            break;
        case UIGestureRecognizerStateEnded: {
            float currentScale = ((Layout *)layouts[layoutIndex]).displayFrac;
            if (pinch.scale < 1.0) {    // go smaller
                float targetScale = currentScale*pinch.scale;
                for (layoutIndex++; layoutIndex < layouts.count; layoutIndex++)
                    if (((Layout *)layouts[layoutIndex]).displayFrac <= targetScale)
                        break;
                if (layoutIndex >= layouts.count)
                    layoutIndex = layouts.count - 1;
            } else {
                float targetScale = currentScale + 0.1 * trunc(pinch.scale);
                for (layoutIndex--; layoutIndex >= 0; layoutIndex--)
                    if (((Layout *)layouts[layoutIndex]).displayFrac >= targetScale)
                        break;
                if (layoutIndex < 0)
                    layoutIndex = 0;
            }
            [taskCtrl idleFor:ApplyLayout];
            [self applyScreenLayout:layoutIndex];
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
    nextSourceIndex = [self flipOfCurrentSource];
    assert(nextSourceIndex != NO_SOURCE);
    [self changeSourceTo:nextSourceIndex];
}

- (IBAction) processDepthSwitch:(UISwitch *)depthsw {
    NSLog(@"chagne camera deoth");
    nextSourceIndex = [self otherDepthOfCurrentSource];
    assert(nextSourceIndex != NO_SOURCE);
    [self changeSourceTo:nextSourceIndex];
//    if (!live)
//        [self liveOn:YES];
}

- (void) changeSourceTo:(NSInteger)nextIndex {
    transformChainChanged = YES;
    if (nextIndex == NO_SOURCE)
        return;
//    NSLog(@"III changeSource To  index %ld", (long)nextIndex);
    nextSourceIndex = nextIndex;
    [taskCtrl idleFor:NeedsNewLayout];
}

- (IBAction) selectOptions:(UIButton *)button {
    OptionsVC *oVC = [[OptionsVC alloc] initWithOptions:options];
    UINavigationController *optionsNavVC = [[UINavigationController alloc]
                                            initWithRootViewController:oVC];
    [self presentViewController:optionsNavVC
                       animated:YES
                     completion:^{
        [self adjustBarButtons];
        [self->taskCtrl idleFor:NeedsNewLayout];
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
            return cameraCount;
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
    [self changeSourceTo:indexPath.row];
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
        [self->taskCtrl idleFor:NeedsNewLayout];
    }];
}

// The bottom of the image has, from right to left
// - the snap button
// - the running/pause button
// - the parameter slider

- (void) positionControls {
    CGRect f = transformView.frame;
    f.origin.x = f.size.width - CONTROL_BUTTON_SIZE - SEP;
    f.origin.y = f.size.height - CONTROL_BUTTON_SIZE - SEP;
    f.size = snapButton.frame.size;
    snapButton.frame = f;
    
    f.origin.x -= f.size.width + SEP;
    runningButton.frame = f;
    
    f.origin.x = INSET;
    f.origin.y = transformView.frame.size.height;   // off screen below transform window
    f.size.width = runningButton.frame.origin.x - SEP - f.origin.x;
    f.size.height = paramView.frame.size.height;
    paramView.frame = f;
    SET_VIEW_WIDTH(paramLabel, paramView.frame.size.width);
    SET_VIEW_WIDTH(paramSlider, paramView.frame.size.width);
    [self adjustParamView];
}

// update the thumbs to show which are available for the end of the new transform chain
// displayedFrame has the source frame.  if nil?
- (void) updateThumbAvailability {
    BOOL depthAvailable = (lastDisplayedFrame.depthBuf != nil); // cameraController.depthDataAvailable;
    for (ThumbView *thumbView in thumbViewsArray) {
        Transform *transform = thumbView.transform;
        if (transform.type != DepthVis)
            continue;
        thumbView.task.enabled = depthAvailable;
        [thumbView adjustStatus:depthAvailable ? ThumbAvailable : ThumbUnAvailable];
    }
    transformChainChanged = NO;
}

@end
