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
#define CURRENT_SOURCE  SOURCE(currentSourceIndex)

#define SOURCE_INDEX_IS_FRONT(si)   (possibleCameras[SOURCE(si).cameraIndex].front)
#define SOURCE_INDEX_IS_3D(si)   (possibleCameras[SOURCE(si).cameraIndex].threeD)

struct camera_t {
    BOOL front, threeD;
    NSString *name;
} possibleCameras[] = {
    {YES, NO, @"Front camera"},
    {YES, YES, @"Front 3D camera"},
    {NO, NO, @"Rear camera"},
    {NO, YES, @"Rear 3D camera"},
};
#define N_POSS_CAM   (sizeof(possibleCameras)/sizeof(struct camera_t))

#define IS_CAMERA(s)        ((s).cameraIndex != NOT_A_CAMERA)
#define IS_FRONT_CAMERA(s)  (IS_CAMERA(s) && possibleCameras[(s).cameraIndex].front)
#define IS_3D_CAMERA(s)     (IS_CAMERA(s) && possibleCameras[(s).cameraIndex].threeD)


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

@property (nonatomic, strong)   ExternalScreenVC *extScreenVC;
@property (nonatomic, strong)   UIImageView *extImageView;  // not yet implemented...use native screen mirror
@property (nonatomic, strong)   Options *options;
@property (assign)              DisplayOptions currentDisplayOption;

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

@property (nonatomic, strong)   UIImageView *transformView; // transformed image
@property (nonatomic, strong)   UIView *thumbsView;         // transform thumbs view of thumbArray
@property (nonatomic, strong)   UIScrollView *executeScrollView;    // active transform list area
@property (nonatomic, strong)   UIView *executeView;                // stack of UILabels in executeScrollView
@property (nonatomic, strong)   NSMutableArray<Layout *> *layouts;    // approved list of current layouts
@property (assign)              long layoutIndex;           // index into layouts, or NO_LAYOUT_SELECTED
@property (assign)              BOOL layoutIsBroken;    // for debugging

@property (nonatomic, strong)   UINavigationController *helpNavVC;
// in sources view
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (assign)              NSInteger currentSourceIndex, nextSourceIndex;
@property (nonatomic, strong)   UIImageView *cameraSourceThumb; // non-nil if selecting source
@property (nonatomic, strong)   Frame *fileSourceFrame;    // what we are transforming, or nil if get an image from the camera
@property (nonatomic, strong)   InputSource *fileSource;
@property (nonatomic, strong)   NSMutableArray<InputSource *> *inputSources;
@property (assign)              int cameraCount;

@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   UILabel *allStatsLabel;

@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;


@property (assign)              UIDeviceOrientation deviceOrientation;
@property (nonatomic, strong)   Layout *layout;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthBuf *rawDepthBuf;
@property (assign)              CGSize transformDisplaySize;

@property (nonatomic, strong)   UISegmentedControl *sourceSelectionView;

@property (nonatomic, strong)   UISegmentedControl *uiSelection;
@property (nonatomic, strong)   UIScrollView *thumbScrollView;

@end

@implementation MainVC

@synthesize extScreenVC, extImageView;

@synthesize plusButton;
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
@synthesize layouts, layoutIndex;
@synthesize helpNavVC;
@synthesize mainStatsView;
@synthesize currentDisplayOption;

@synthesize paramView, paramLabel, paramSlider;
@synthesize showControls, showStats, flashView;
@synthesize paramLow, paramName, paramHigh, paramValue;

@synthesize executeScrollView, executeView;
@synthesize layoutValuesView;

@synthesize deviceOrientation;
@synthesize isPortrait, isiPhone;

@synthesize sourcesNavVC;
@synthesize options;

@synthesize currentSourceIndex, nextSourceIndex;
@synthesize inputSources;
@synthesize cameraSourceThumb;
@synthesize fileSourceFrame;
@synthesize live;
@synthesize cameraCount;

@synthesize cameraController;
@synthesize layout;
@synthesize layoutIsBroken;

@synthesize undoBarButton, shareBarButton, trashBarButton;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize hiresButton;

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
@synthesize minExecWidth;
@synthesize minDisplayWidth, maxDisplayWidth;
@synthesize minDisplayHeight, maxDisplayHeight;
@synthesize execFontSize;

- (id) init {
    self = [super init];
    if (self) {
        mainVC = self;  // a global is easier

        transforms = [[Transforms alloc] init];
        
        fileSourceFrame = nil;
        layout = nil;
        layoutIsBroken = NO;
        helpNavVC = nil;
        showControls = NO;
        extScreenVC = nil;
        extImageView = nil;
        transformChainChanged = NO;
        lastDisplayedFrame = nil;
        layouts = [[NSMutableArray alloc] init];
        taskCtrl = [[TaskCtrl alloc] init];
        deviceOrientation = UIDeviceOrientationUnknown;
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
        
        isiPhone  = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
        currentDisplayOption = isiPhone ? iPhoneSize : iPadSize;
        
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
        currentSourceIndex = NO_SOURCE;
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
        
//        currentSourceIndex = [[NSUserDefaults standardUserDefaults]
//                              integerForKey: LAST_SOURCE_KEY];
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
                        break;
                    }
                }
                assert(currentSourceIndex != NO_SOURCE);
            }
        }
        nextSourceIndex = currentSourceIndex;
        currentSourceIndex = NO_SOURCE;
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
                                                             initWithTarget:self action:@selector(doHelp:)];
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
    [source loadImage:imagePath];
    [inputSources addObject:source];
}

- (void) viewDidLoad {
    [super viewDidLoad];
    

    [self adjustOrientation];

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
//                                     initWithImage:[UIImage systemImageNamed:@"doc.text"]
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
    executeScrollView.contentOffset = CGPointZero;
    [containerView addSubview:executeScrollView];
    
    executeView = [[UIView alloc] init];
    [executeScrollView addSubview:executeView];

#define PLUS_SELECTED    plusButton.selected
#define PLUS_LOCKED     plusButton.highlighted
    
    plusButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [plusButton addTarget:self
                   action:@selector(doPlusTapped:)
         forControlEvents:UIControlEventTouchUpInside];

    // NOT SELECTED
    [self plusTitleForState:UIControlStateNormal
                     weight:UIFontWeightThin
                      color:[UIColor blackColor]];
    // SELECTED
    [self plusTitleForState:UIControlStateSelected
                     weight:UIFontWeightRegular
                      color:[UIColor blackColor]];
    // LOCKED:
    [self plusTitleForState:UIControlStateHighlighted
                     weight:UIFontWeightBold
                      color:[UIColor blackColor]];

    [self adjustPlusSelected:NO locked:NO];
    plusButton.layer.borderWidth = isiPhone ? 1.0 : 5.0;
    plusButton.layer.cornerRadius = isiPhone ? 3.0 : 5.0;
    plusButton.layer.borderColor = [UIColor orangeColor].CGColor;
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalScreenDidConnect:) name:UIScreenDidConnectNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalScreenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
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
                               dumpDeviceOrientationName:[[UIDevice currentDevice]
                                                          orientation]]);
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
    
    [self dumpViewLimits:(@"OOOO viewWillAppear")];
    // not needed: we haven't started anything yet
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self dumpViewLimits:(@"OOOO viewDidAppear")];

    frameCount = depthCount = droppedCount = busyCount = 0;
    [self.view setNeedsDisplay];
    
    [taskCtrl idleFor:NeedsNewLayout];

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
    UIDeviceOrientation nextOrientation = [[UIDevice currentDevice] orientation];
    
    [self dumpViewLimits:@"viewWillTransitionToSize"];
    if (nextOrientation == UIDeviceOrientationUnknown)
//        nextOrientation = UIDeviceOrientationPortraitUpsideDown;    // klduge, don't know why
        nextOrientation = UIDeviceOrientationPortrait;    // klduge, don't know why
    if (nextOrientation == deviceOrientation)
        return; // nothing new to see here, folks
    deviceOrientation = nextOrientation;
    [self reloadSourceImage];
//    taskCtrl.lastFrame = nil;
}

- (void) viewWillTransitionToSize:(CGSize)size
        withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        ;
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self adjustOrientation];
        [self->taskCtrl idleFor:NeedsNewLayout];
        [self.view setNeedsDisplay];
    }];
}

- (void) tasksReadyFor:(LayoutStatus_t) layoutStatus {
    if (layoutIsBroken)
        return;
    switch (layoutStatus) {
        case LayoutUnavailable:
            break;
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
                if (!IS_CAMERA(CURRENT_SOURCE)) {
                    fileSourceFrame = [[Frame alloc] init];
                    [fileSourceFrame readImageFromPath: source.imagePath];
                    transformChainChanged = YES;
                }
                [self saveSourceIndex];
            }
            [self computeLayouts];
            if (!layouts.count) {
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
                
                layoutStatus = LayoutUnavailable;
                layoutIndex = NO_LAYOUT_SELECTED;
                layoutIsBroken = YES;
                return;
            }
            layoutIndex = 0;    // highest score, top of the array
            taskCtrl.state = ApplyLayout;
            // FALLTHROUGH
        case ApplyLayout:
            if (IS_CAMERA(CURRENT_SOURCE)) {
                [cameraController updateOrientationTo:deviceOrientation];
                [cameraController selectCameraOnSide:IS_FRONT_CAMERA(CURRENT_SOURCE)];
                [self liveOn:YES];
            }
            [self refreshScreen];
    }
    taskCtrl.state = LayoutOK;
}

- (void) dumpLayouts {
    for (int i=0; i<layouts.count; i++) {
        Layout *layout = layouts[i];
        NSLog(@"%2d %@ %@", i,
            layoutIndex == i ? @">>" : @"  ",
            [layout layoutSum]);
    }
}

- (void) computeLayouts {
    isPortrait = UIDeviceOrientationIsPortrait(deviceOrientation) ||
        UIDeviceOrientationIsFlat(deviceOrientation);
    
    // screen/view limits
    if (mainVC.isiPhone) { // iphone display is very cramped.  Make the best of it.
        execFontSize = EXECUTE_IPHONE_FONT_SIZE;
        minExecWidth = EXECUTE_MIN_TEXT_CHARS * (execFontSize*0.7) + 2*EXECUTE_BORDER_W;
        if (mainVC.isPortrait) {
            minDisplayWidth = currentDisplayOption == NoTransformDisplayed ? 0 : containerView.frame.size.width / 6.0;
            maxDisplayWidth = 0;    // no max
            minDisplayHeight = PARAM_VIEW_H*3;
            maxDisplayHeight = containerView.frame.size.height / 3.0;
            minPctThumbsShown = 7.0;
        } else {    // iphone landscape
            minDisplayWidth = currentDisplayOption == NoTransformDisplayed ? 0 : THUMB_W*2.0;
            maxDisplayWidth = containerView.frame.size.width / 3.0;    // no max
            minDisplayHeight = THUMB_W*2;
            maxDisplayHeight = 0;   // no limit
            minPctThumbsShown = 14.0;
        }
        bestMinDisplayFrac = 0.2; // 0.4;
        minDisplayFrac = currentDisplayOption == NoTransformDisplayed ? 0 : 0.3;
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
    
    if (currentDisplayOption == OnlyTransformDisplayed) {
        minThumbRows = 0;
        minThumbCols = 0;
    }
    assert(minExecWidth > 0);
    
    CGRect safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
    containerView.frame = safeFrame;
    NSLog(@" ******* containerview: %.0f,%.0f  %.0fx%.0f  %@",
          containerView.frame.origin.x, containerView.frame.origin.y,
          containerView.frame.size.width, containerView.frame.size.height,
          containerView.frame.size.width > containerView.frame.size.height ? @"landscape" : @"portrait");
    
#ifdef DEBUG_BORDERS
    containerView.layer.borderColor = [UIColor magentaColor].CGColor;
    containerView.layer.borderWidth = 3.0;
#endif

    [layouts removeAllObjects];
    [self findLayouts];

    if (!layouts.count) {
        return;
    }

    // sort the layouts by descending size, and score. Default is the highest
    // scoring one.  Discard the ones that are close.
    
    [layouts sortUsingComparator:^NSComparisonResult(Layout *l1, Layout *l2) {
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
    
    NSMutableArray<Layout *> *editedLayouts = [[NSMutableArray alloc] init];
    
    Layout *previousLayout = nil;
    float bestScore = -1;
    int bestScoreIndex = -1;

    for (int i=0; i<layouts.count; i++) {
        Layout *layout = layouts[i];
        if (i == 0) {   // first one
            bestScore = layout.score;
            bestScoreIndex = i;
            [editedLayouts addObject:layout];
            previousLayout = layout;
            continue;
        }
        
        if (layout.format) {
            // find best depth format for this.  Must have same aspect ratio, and correct type.
            NSArray<AVCaptureDeviceFormat *> *depthFormats = layout.format.supportedDepthDataFormats;
            layout.depthFormat = nil;
            for (AVCaptureDeviceFormat *depthFormat in depthFormats) {
                if (![CameraController depthFormat:depthFormat isSuitableFor:layout.format])
                    continue;
                layout.depthFormat = depthFormat;
            }
        }
        
        [editedLayouts addObject:layout];
        if (layout.score > bestScore) {
            bestScore = layout.score;
            bestScoreIndex = (int)editedLayouts.count - 1;
        }
        previousLayout = layout;
    }
    
#ifdef DEBUG_LAYOUT
    NSLog(@"LLLL %lu trimmed to %lu, top score %.5f at %d",
          layouts.count, editedLayouts.count, bestScore, bestScoreIndex);
#endif
    
    layouts = editedLayouts;
    [self applyScreenLayout:bestScoreIndex];

#ifdef NOTDEF
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
}

- (void) findLayouts {
    CGSize sourceSize;
    if (fileSourceFrame) {
        sourceSize = fileSourceFrame.size;
        [self searchThumbOptionsForSize:sourceSize format:nil];
    } else {
        assert(cameraController);
        [cameraController updateOrientationTo:deviceOrientation];
        [cameraController selectCameraOnSide:IS_FRONT_CAMERA(CURRENT_SOURCE)];
        // XXXXXXX        assert(live);
    
        for (AVCaptureDeviceFormat *format in cameraController.formatList) {
            if (cameraController.depthDataAvailable) {
                if (!format.supportedDepthDataFormats || format.supportedDepthDataFormats.count == 0)
                    continue;   // we want depth if needed and available
            }
            CGSize formatSize = [cameraController sizeForFormat:format];
            [self searchThumbOptionsForSize:formatSize format:format];
        }
    }
    
    NSLog(@" *** findLayouts: %lu", (unsigned long)layouts.count);
    [self dumpLayouts];
}

// try different thumb placement options for this source size
- (void) searchThumbOptionsForSize:(CGSize) sourceSize
                            format:(AVCaptureDeviceFormat *__nullable)format {
    [self dumpViewLimits:@"searchThumbOptionsForSize"];
    
    size_t thumbCols = minThumbCols;
    size_t thumbRows = minThumbRows;
    Layout *layout;
    
    switch (currentDisplayOption) {
        case iPadSize:
            // try right thumbs
            do {
                layout = [[Layout alloc]
                                  initForSize: sourceSize
                                  rightThumbs:thumbCols++
                                  bottomThumbs:0
                                  displayOption:currentDisplayOption
                                  format:format];
                if (layout) {
                    NSLog(@"RT  %@", [layout layoutSum]);
                }

                if (layout && layout.score != BAD_LAYOUT)
                    [layouts addObject:layout];
            } while (layout);
            
            // try bottom thumbs
            do {    // try bottom thumbs
                layout = [[Layout alloc]
                                  initForSize: sourceSize
                                  rightThumbs:0
                                  bottomThumbs:thumbRows++
                                  displayOption:currentDisplayOption
                                  format:format];
                if (/* DISABLES CODE */ (NO) && layout) {
                    NSLog(@"BT  %@", [layout layoutSum]);
                }

                if (layout && layout.score != BAD_LAYOUT)
                    [layouts addObject:layout];
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
        case iPhoneSize:    // NB: iPhone is suboptimal for this app
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
        case NoTransformDisplayed: {  // execute and thumbs only
            if (isPortrait) {       // portrait iphone
                
            } else {            // landscape iphone
                
            }
            break;
        }
    }
}

- (void) applyScreenLayout:(long) newLayoutIndex {
    if (newLayoutIndex == NO_LAYOUT_SELECTED)
        return;
    assert(newLayoutIndex < layouts.count);
    
    layoutIndex = newLayoutIndex;
    layout = layouts[layoutIndex];
#ifdef DEBUG_LAYOUT
    NSLog(@"applyScreenLayout");
    [layout dump];
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
    CGRect f = transformView.frame;
    f.origin.x = f.size.width - CONTROL_BUTTON_SIZE - SEP;
    f.origin.y = f.size.height - CONTROL_BUTTON_SIZE - SEP;
    f.size = snapButton.frame.size;
    snapButton.frame = f;
    
    f.origin.x -= f.size.width + SEP;
    runningButton.frame = f;
    
    paramView.frame = layout.paramRect;
    SET_VIEW_WIDTH(paramLabel, paramView.frame.size.width);
    SET_VIEW_WIDTH(paramSlider, paramView.frame.size.width);
    [self addParamsFor:[screenTask.transformList lastObject]];
    
    thumbScrollView.frame = layout.thumbScrollRect;
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
    
    CGSize imageSize, depthSize;
    if (!fileSourceFrame) { // camera input: set format and get raw sizes
        [cameraController setupCameraSessionWithFormat:layout.format depthFormat:layout.depthFormat];
        //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformImageView.layer;
        //cameraController.captureVideoPreviewLayer = previewLayer;
        [cameraController currentRawSizes:&imageSize
                             rawDepthSize:&depthSize];
    } else {
        imageSize = [fileSourceFrame imageSize];
        depthSize = CGSizeZero;
    }

//    [taskCtrl updateRawSourceSizes:imageSize depthSize:depthSize];
    screenTasks.targetSize = layout.transformSize;
    thumbTasks.targetSize = layout.thumbImageRect.size;
//    [externalTask newTargetSize:processingSize];
//  externalTask.targetSize = layout.processing.size;
    
    executeScrollView.frame = layout.executeScrollRect;
    executeView.frame = CGRectMake(0, 0,
                                   executeScrollView.frame.size.width,
                                   executeScrollView.frame.size.height);
    executeScrollView.contentSize = executeView.frame.size;
    
    thumbScrollView.contentOffset = thumbsView.frame.origin;
    [thumbScrollView setContentOffset:CGPointMake(0, 0) animated:YES];

    plusButton.frame = layout.plusRect;
    [UIView animateWithDuration:0.5 animations:^(void) {
        // move views to where they need to be now.
        [self layoutThumbs: self->layout];
    }];
    
    layoutValuesView.frame = transformView.frame;
    [containerView bringSubviewToFront:layoutValuesView];
    NSString *formatList = @"";
    long start = newLayoutIndex - 6;
    long finish = newLayoutIndex + 6;
    start = 0; finish = layouts.count;
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
            depthBarButton.enabled = [self otherDepthOfCurrentSource] != NO_SOURCE;
            imageName = !cam.threeD ? @"view.3d" : @"view.2d";
        }
    }
    depthBarButton.image = [UIImage systemImageNamed:imageName];
#endif
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

- (size_t) nextTransformTapIndex {
    if (PLUS_SELECTED)
        return screenTask.transformList.count;
    if (screenTask.transformList.count > 0)
        return screenTask.transformList.count - 1;
    return 0;
}

- (IBAction) didTapThumb:(UITapGestureRecognizer *)recognizer {
    ThumbView *tappedThumb = (ThumbView *)[recognizer view];
    Transform *tappedTransform = tappedThumb.transform;
    Transform *oldTransform = [screenTask.transformList lastObject];
    
    //    size_t indexToChange = [self nextTransformTapIndex];
    // if there is no current transform, or plus is selected, append the transform
    if (!screenTask.transformList.count || PLUS_SELECTED) {
        [self removeParamsFor: oldTransform];
        [screenTask appendTransformToTask:tappedTransform];
        [self addParamsFor: tappedTransform];
        [tappedThumb adjustStatus:ThumbActive];
        if (PLUS_SELECTED) {
            [self adjustPlusSelected:NO locked:NO]; // satisfied
        } else {
            [self adjustPlusSelected:YES locked:NO]; // satisfied
        }
    } else {    // we have a current transform. deselect if he tapped current transform
        if (tappedThumb.status == ThumbActive) {    // just deselect tapped thumb
            [self removeParamsFor: tappedTransform];
            [tappedThumb adjustStatus:ThumbAvailable];
            [screenTask removeLastTransform];
            if (!screenTask.transformList.count) {
                [self adjustPlusSelected:NO locked:NO]; // satisfied
            }
        } else {
            if (oldTransform) {
                [self removeParamsFor: oldTransform];
                ThumbView *oldThumb = oldTransform.thumbView;
                [oldThumb adjustStatus:ThumbAvailable];
                [tappedThumb adjustStatus:ThumbActive];
                [screenTask changeLastTransformTo:tappedTransform];
                [self addParamsFor:tappedTransform];
            } else {
                [screenTask appendTransformToTask:tappedTransform];
                [tappedThumb adjustStatus:ThumbActive];
                [self addParamsFor:tappedTransform];
            }
            [self adjustPlusSelected:NO locked:NO]; // satisfied
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
    if (IS_CAMERA(CURRENT_SOURCE) && live)
        return; // updates when the camera is ready
    Frame *frame = [[Frame alloc] init];
    [frame readImageFromPath:CURRENT_SOURCE.imagePath];
    [taskCtrl processFrame:frame];
}

- (void) removeParamsFor:(Transform *) oldTransform {
    BOOL oldParameters = oldTransform && oldTransform.hasParameters;
    if (!oldParameters)
        return;
#ifdef NOTDEF
    [UIView animateWithDuration:0.5 animations:^(void) {
        // slide old parameters off the bottom of the display
        SET_VIEW_Y(self->paramView, BELOW(self->layout.displayRect));
    } completion:nil];
#endif
}

- (void) addParamsFor:(Transform *) newTransform {
    BOOL newParameters = newTransform && newTransform.hasParameters;
    if (!newParameters) {
        [self adjustParamView];
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
    NSLog(@"doPlusTapped");
    [self adjustPlusSelected:!PLUS_SELECTED locked:PLUS_LOCKED];
}

- (IBAction) doPlusPressed:(UIButton *)caller {
    NSLog(@"doPlusPressed");
    [self adjustPlusSelected:PLUS_SELECTED
                    locked:!PLUS_LOCKED];
}

- (void) adjustPlusSelected:(BOOL)selected locked:(BOOL)locked {
    PLUS_SELECTED = selected;
    PLUS_LOCKED = locked;
    NSLog(@"new plus: %@ %@",
          PLUS_SELECTED ? @"S" : @"s",
          PLUS_LOCKED ? @"L" : @"l");
    [self updateExecuteView];
}

- (void) plusTitleForState:(UIControlState) state
                    weight:(UIFontWeight) weight
                     color:(UIColor *) color {
    UIFont *font = [UIFont
                    systemFontOfSize:PLUS_H
                    weight:weight];
    [plusButton setAttributedTitle:[[NSAttributedString alloc]
                                    initWithString:@"+"
                                    attributes:@{ NSFontAttributeName : font,
                                                  NSForegroundColorAttributeName: color,
                                               }] forState:state];
}


// If the camera is off, turn it on, to the first possible setting,
// almost certainly the front camera, 2d. //  Otherwise, change the depth.

- (IBAction) doCamera:(UIBarButtonItem *)caller {
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
    assert(IS_CAMERA(CURRENT_SOURCE));
    [self liveOn:!live];
}

- (void) liveOn:(BOOL) state {
    live = state;
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
    if (!lastTransform) {
        paramLabel.text = [NSString stringWithFormat:@"(Source image)"];
        paramLabel.textColor = [UIColor lightGrayColor];
        [paramLabel setNeedsDisplay];
        return;
    }
    paramLabel.textColor = [UIColor blackColor];
    [paramLabel setNeedsDisplay];
    if (!lastTransform.hasParameters) {
        paramLabel.text = [NSString stringWithFormat:@"%@",
                           lastTransform.name];
    } else if (transformChainChanged) {
        paramLabel.text = [NSString stringWithFormat:@"%@:    %@: %.0f",
                           lastTransform.name,
                           lastTransform.paramName,
                           paramSlider.value];
        [paramSlider setNeedsDisplay];
        [paramView setNeedsDisplay];
        [self updateExecuteView];
        [self refreshScreen];
    }
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
    if ((NO) && showStats)
        [self updateExecuteView];
    [taskCtrl checkForIdle];
    if (showStats)
        self.title = [NSString stringWithFormat:@"\"%@\",    layout %ld/%lu  %@",
                      CURRENT_SOURCE.label,
                      layoutIndex, (unsigned long)layouts.count,
                      layout.type];

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
//
// we update the plus button, too.

- (void) updateExecuteView {
    long step = 0;
    long displaySteps = screenTask.transformList.count;
    CGFloat bestH = [layout executeHForRowCount:displaySteps];
//    NSString *sep = onePerLine ? @"\n" : @" ";
//    NSString *text = @"";
    
    if ((YES) || (!layout.executeIsTight && bestH <= executeView.frame.size.height)) {
        // one-per-line layout
        // loop includes last line +1
        // next transform to be entered/changed is in a box, with a hand pointing to it
        
        NSArray *viewsToRemove = [executeView subviews];
        for (UIView *v in viewsToRemove) {
            [v removeFromSuperview];
        }

#define EXEC_LABEL_H    (execFontSize + 7)
        for (int i=0; i<=displaySteps; i++, step++) {
            UILabel *execLine = [[UILabel alloc]
                                 initWithFrame:CGRectMake(2*INSET, i*EXEC_LABEL_H,
                                                          executeView.frame.size.width - 2*2*INSET,
                                                          EXEC_LABEL_H)];
            execLine.font = [UIFont systemFontOfSize:execFontSize];
            NSString *transformInfo = [screenTask displayInfoForStep:i
                                                  shortForm:NO
                                                      stats:showStats];
            size_t plusIndex = [self nextTransformTapIndex];
            BOOL currentTransform = plusIndex == i;
            execLine.text = [NSString stringWithFormat:@" %@ %@",
                             currentTransform ? POINTING_HAND : @" ",
                             transformInfo];
            if (currentTransform) {
                execLine.layer.borderWidth = 0.50;
                execLine.layer.borderColor = [UIColor darkGrayColor].CGColor;
            }
            [executeView addSubview:execLine];
        }
    } else {    // compressed layout. XXX: STUB
//        executeView.text = text;
    }
    
#ifdef OLD
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
    [executeView setNeedsDisplay];
}

static CGSize startingPinchSize;

- (IBAction) doPinch:(UIPinchGestureRecognizer *)pinch {
    if (layoutIndex == NO_LAYOUT_SELECTED) {
        NSLog(@"pinch ignored, no layout available");
        return;
    }
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

- (void) reloadSourceImage {
    if (currentSourceIndex == NO_SOURCE)
        return;
   if (IS_CAMERA(CURRENT_SOURCE) && live)
       return;  // no need: the camera will refresh
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
                                                         action:@selector(nextLayout:)];
    return @[uKey, dKey, spaceKey];
}

- (void)upLayout:(UIKeyCommand *)keyCommand {
    if (![self keyTimeOK])
        return;
    if (layoutIndex == 0)
        return;
    [self applyScreenLayout:layoutIndex - 1];
}

- (void)downLayout:(UIKeyCommand *)keyCommand {
    if (![self keyTimeOK])
        return;
    if (layoutIndex+1 >= layouts.count)
        return;
    [self applyScreenLayout:layoutIndex + 1];
}

- (void)nextLayout:(UIKeyCommand *)keyCommand {
    if (![self keyTimeOK])
        return;
    [self applyScreenLayout:(layoutIndex + 1) % layouts.count];
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

@end
