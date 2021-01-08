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
#import "Defines.h"

#define BUTTON_FONT_SIZE    20
#define STATS_W             75
#define STATS_FONT_SIZE     18

#define VALUE_W         45
#define VALUE_LIMITS_W  35
#define VALUE_FONT_SIZE 22
#define VALUE_LIMIT_FONT_SIZE   14

#define CURRENT_VALUE_LABEL_TAG     1
#define TRANSFORM_BASE_TAG          100
#define TRANSFORM_LABEL_TAG         98

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

#define OLIVE_W     80
#define OLIVE_FONT_SIZE 18
// #define OLIVE_LABEL_H   (2.0*(OLIVE_FONT_SIZE+4))

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
#define THUMB_TASK_INDEX_BASE_TAG   200

#define DEPTH_TABLE_SECTION     0

// last settings

#define LAST_SOURCE_KEY @"LastSource"
#define UI_MODE_KEY @"UIMode"

typedef enum {
    TransformTable,
    ActiveTable,
} TableTags;

typedef enum {
    sourceCollection,
    transformCollection
} CollectionTags;

@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   UIView *containerView;

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   TaskGroup *screenTasks;
@property (nonatomic, strong)   TaskGroup *thumbTasks;
@property (nonatomic, strong)   TaskGroup *externalTasks;   // not yet
@property (nonatomic, strong)   TaskGroup *hiresTasks;       // not yet


@property (nonatomic, strong)   Task *screenTask;
@property (nonatomic, strong)   Task *externalTask;

// in containerview:
@property (nonatomic, strong)   UIView *transformView;              // area reserved for transform display and related
@property (nonatomic, strong)   UIView *oliveArrayView;

// in transformview
@property (nonatomic, strong)   UIImageView *transformImageView;    // transformed image
@property (nonatomic, strong)   UIView *executeControlView;             // list of applied transforms, and controls

// in sources view
@property (nonatomic, strong)   UIButton *currentCameraButton;  // or nil if no camera is selected
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;
@property (nonatomic, strong)   InputSource *nextSource;
@property (assign)              int availableCameraCount;

@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   UILabel *allStatsLabel;

@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;

@property (nonatomic, strong)   UIBarButtonItem *trashButton;
@property (nonatomic, strong)   UIBarButtonItem *hiresButton;
@property (nonatomic, strong)   UIBarButtonItem *undoButton;
@property (nonatomic, strong)   UIBarButtonItem *snapButton;

@property (nonatomic, strong)   UIBarButtonItem *stopCamera;
@property (nonatomic, strong)   UIBarButtonItem *startCamera;

@property (assign, atomic)      BOOL capturing;         // camera is on and getting processed
@property (assign)              BOOL busy;              // transforming is busy, don't start a new one
@property (assign)              BOOL needHires;

@property (assign)              UIImageOrientation imageOrientation;
@property (assign)              DisplayMode_t displayMode;
@property (assign)              UIMode_t uiMode;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthImage *depthImage;
@property (assign)              CGSize transformDisplaySize;

@property (assign)              int depthTransformIndex;    // or NO_DEPTH_TRANSFORM, -1 selected index if disabled

@property (nonatomic, strong)   UISegmentedControl *sourceSelection;
@property (nonatomic, strong)   UISegmentedControl *uiSelection;
@property (nonatomic, strong)   UIScrollView *oliveScrollView;

@property (nonatomic, strong)   UIView *oliveSelectedView;
@property (assign)              BOOL oliveUpdateNeeded;

@end

@implementation MainVC

@synthesize taskCtrl;
@synthesize screenTasks, thumbTasks, externalTasks;
@synthesize hiresTasks;
@synthesize screenTask, externalTask;

@synthesize containerView;
@synthesize transformView;
@synthesize transformImageView;
@synthesize executeControlView;
@synthesize oliveArrayView;

@synthesize sourcesNavVC;

@synthesize currentCameraButton;

@synthesize inputSources, currentSource;
@synthesize nextSource;
@synthesize availableCameraCount;

@synthesize cameraController;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize capturing, busy, needHires;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize trashButton, hiresButton;
@synthesize undoButton, snapButton;
@synthesize stopCamera, startCamera;
@synthesize imageOrientation;
@synthesize displayMode;
@synthesize uiMode;

@synthesize rowIsCollapsed;
@synthesize depthImage;
@synthesize depthTransformIndex;

@synthesize transformDisplaySize;
@synthesize sourceSelection;
@synthesize uiSelection;
@synthesize oliveScrollView;
@synthesize oliveSelectedView;
@synthesize oliveUpdateNeeded;
@synthesize currentDeviceOrientation;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        [self loadTransformSectionVisInfo];
        
        taskCtrl = [[TaskCtrl alloc] init];
        taskCtrl.mainVC = self;
        currentDeviceOrientation = UIDeviceOrientationUnknown;
        
        screenTasks = [taskCtrl newTaskGroupNamed:@"Screen"];
        thumbTasks = [taskCtrl newTaskGroupNamed:@"Thumbs"];
        //externalTasks = [taskCtrl newTaskGroupNamed:@"External"];

        transformTotalElapsed = 0;
        transformCount = 0;
        depthImage = nil;
        oliveScrollView = nil;
        depthTransformIndex = NO_DEPTH_TRANSFORM;
        busy = NO;
        needHires = NO;
        oliveSelectedView = nil;
        oliveUpdateNeeded = NO;
        
        cameraController = [[CameraController alloc] init];
        cameraController.delegate = self;
        currentCameraButton = nil;

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
        
        [self newDisplayMode:medium];

        nextSource = nil;

        NSString *lastSourceUsedLabel = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:LAST_SOURCE_KEY];
        if (lastSourceUsedLabel) {
            for (int sourceIndex=0; sourceIndex<inputSources.count; sourceIndex++) {
                nextSource = [inputSources  objectAtIndex:sourceIndex];
                if ([lastSourceUsedLabel isEqual:nextSource.label]) {
                    NSLog(@"  - initializing source index %d", sourceIndex);
                    break;
                }
            }
        }
        
        if (!nextSource)  {   // no known default, pick the first camera
            for (int sourceIndex=0; sourceIndex<NCAMERA; sourceIndex++) {
                if ([cameraController isCameraAvailable:sourceIndex]) {
                    nextSource = [inputSources objectAtIndex:sourceIndex];
                    NSLog(@"  - no previous source, using %d, %@", sourceIndex, nextSource.label);
                    break;
                }
            }
        }

        currentSource = nextSource;
    }
    return self;
}

- (void) saveUIMode {
    NSString *uiStr = [NSString stringWithFormat:@"%d", uiMode];
    [[NSUserDefaults standardUserDefaults] setObject:uiStr
                                              forKey:UI_MODE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) saveCurrentSource {
    NSLog(@"Saving source %d", currentSource.sourceType);
    [[NSUserDefaults standardUserDefaults] setObject:currentSource.label
                                              forKey:LAST_SOURCE_KEY];
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

// The section headings might change.  Only propagate or initialize the ones we have now.

- (void) loadTransformSectionVisInfo {
    NSError *error;
    NSData *savedSettingsData = [NSData dataWithContentsOfFile:TRANS_SEC_VIS_ARCHIVE];
    NSMutableDictionary *savedSettings = nil;
    if (savedSettingsData)
        savedSettings = [NSKeyedUnarchiver
                         unarchivedObjectOfClass: NSMutableDictionary.class
                         fromData: savedSettingsData
                         error:&error];
    rowIsCollapsed = [[NSMutableDictionary alloc]
                    initWithCapacity:transforms.categoryList.count];
    for (NSString *key in transforms.categoryNames) {
        BOOL collapsed = NO;;
        if (savedSettings) {
            NSNumber *value = [savedSettings objectForKey:key];
            if ([value boolValue])
                collapsed = [value boolValue];
        }
        [rowIsCollapsed setValue:[NSNumber numberWithBool:collapsed] forKey:key];
    }
}

- (void) saveTransformSectionVisInfo {
    NSError *error;
    NSData *settingsData = [NSKeyedArchiver archivedDataWithRootObject:rowIsCollapsed
                                                 requiringSecureCoding:NO
                                                                 error:&error];
    if (error)
        NSLog(@"inconceivable, archive error %@", [error localizedDescription]);
    else
        [settingsData writeToFile:TRANS_SEC_VIS_ARCHIVE atomically:NO];
}

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
    currentDeviceOrientation = [[UIDevice currentDevice] orientation];
#ifdef DEBUG_LAYOUT
    NSLog(@"device rotated to %@", [CameraController
                                     dumpDeviceOrientationName:currentDeviceOrientation]);
#endif
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@" ========= viewDidLoad =========");
    
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
    
    sourceSelection = [[UISegmentedControl alloc] initWithItems:sourceNames];
    sourceSelection.frame = CGRectMake(0, 0, 100, 44);
    [sourceSelection addTarget:self action:@selector(selectSource:)
              forControlEvents: UIControlEventValueChanged];
    sourceSelection.selectedSegmentIndex = nextSource.sourceType;
    sourceSelection.momentary = NO;
    
    UIBarButtonItem *leftBarItem = [[UIBarButtonItem alloc]
                                    initWithCustomView:sourceSelection];
    self.navigationItem.leftBarButtonItem = leftBarItem;
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                   target:nil action:nil];
    fixedSpace.width = 20;
    
#define SLIDER_OFF  (-1)
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                   target:self
                                   action:@selector(doSave:)];
    trashButton = [[UIBarButtonItem alloc]
                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                   target:self
                   action:@selector(doRemoveAllTransforms:)];
    undoButton = [[UIBarButtonItem alloc]
                  initWithBarButtonSystemItem:UIBarButtonSystemItemUndo
                  target:self
                  action:@selector(doRemoveLastTransform)];
    hiresButton = [[UIBarButtonItem alloc]
                   initWithTitle:@"Hi res" style:UIBarButtonItemStylePlain
                   target:self action:@selector(doToggleHires:)];
    
    stopCamera = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                               target:self
                                                               action:@selector(doPauseCamera:)];
    startCamera = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                target:self
                                                                action:@selector(doResumeCamera:)];
    
    //    UIBarButtonItem *sliderBarButton = [[UIBarButtonItem alloc] initWithCustomView:valueSlider];
    //    [self displayValueSlider:SLIDER_OFF];     // XXX not displayed, for the moment
    
    NSArray *toolBarItems = [[NSArray alloc] initWithObjects:
                             stopCamera,
                             startCamera,
                             flexibleSpace,
                             hiresButton,
                             fixedSpace,
                             trashButton,
                             fixedSpace,
                             undoButton,
                             fixedSpace,
                             saveButton, nil];
    self.toolbarItems = toolBarItems;
    
    containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor whiteColor];
    containerView.layer.borderWidth = 1.0;
#ifdef DEBUG_LAYOUT
    containerView.layer.borderColor = [UIColor greenColor].CGColor;
#endif
    
    transformView = [[UIView alloc] init];
    UITapGestureRecognizer *touch = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTapSceen:)];
    [touch setNumberOfTouchesRequired:1];
    [transformImageView addGestureRecognizer:touch];

    [containerView addSubview:transformView];
    
    transformImageView = [[UIImageView alloc] init];
    transformImageView.userInteractionEnabled = YES;
    transformImageView.backgroundColor = NAVY_BLUE;
    [transformView addSubview:transformImageView];
    
    executeControlView = [[UIView alloc] init];
    executeControlView.opaque = NO;
    [transformView addSubview:executeControlView];
     
    oliveScrollView = [[UIScrollView alloc] init];
    [containerView addSubview:oliveScrollView];
    
    [self.view layoutIfNeeded];
    [self.view addSubview:containerView];
    
    //externalTask = [externalTasks createTaskForTargetImage:transformImageView.image];
    
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
 
    NSLog(@"--------- viewwillappear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);

    [self needLayout: self.view.frame.size];
}

- (void) viewWillTransitionToSize:(CGSize)newSize
        withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    NSLog(@"********* viewWillTransitionToSize: %.0f x %.0f", newSize.width, newSize.height);
    [self needLayout: newSize];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSLog(@"--------- viewDidAppear: %.0f x %.0f --------",
          self.view.frame.size.width, self.view.frame.size.height);
    
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

// tell the transforms we need to layout.   It will call doLayout
// when ready.

- (void) needLayout:(CGSize) newSize {
    NSLog(@" --- needLayout to %0.f x %.0f", newSize.width, newSize.height);
    [taskCtrl needLayoutTo:newSize];
}

// this is called when we know the transforms are all Stopped.

#define SEP 5  // between views
#define INSET 3 // from screen edges
#define MIN_TRANS_TABLE_W 275

- (void) doLayout:(CGSize) newSize {
    NSLog(@"****** doLayout to %0.f x %.0f", newSize.width, newSize.height);

    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = (uiMode == oliveUI);
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.opaque = (uiMode == oliveUI);
    
    // set up new source, if needed
    if (nextSource) {
        if (currentSource && ISCAMERA(currentSource.sourceType)) {
            [self cameraOn:NO];
        }
        currentSource = nextSource;
        if (IS_3D_CAMERA(currentSource.sourceType)) {
            if (depthTransformIndex < 0)    // use previous value
                depthTransformIndex = - depthTransformIndex;
            else if (depthTransformIndex == NO_DEPTH_TRANSFORM)
                depthTransformIndex = 0;
        } else
            depthTransformIndex = NO_DEPTH_TRANSFORM;
        [self saveCurrentSource];
        nextSource = nil;
    }
    
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
    NSLog(@"device idiom: %ld", (long)[UIDevice currentDevice].userInterfaceIdiom);
    NSLog(@"device is %@", [CameraController
                                     dumpDeviceOrientationName:currentDeviceOrientation]);
    NSLog(@" is portrait: %d", UIDeviceOrientationIsPortrait(currentDeviceOrientation));
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPhone ||
        !UIDeviceOrientationIsPortrait(currentDeviceOrientation))
        self.title = @"Digital Darkroom";
    else
        self.title = @"";
        
    CGRect f = self.view.frame;
    NSLog(@" **** device view frame:  %.0f x %.0f", f.size.width, f.size.height);

    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide * guide = self.view.safeAreaLayoutGuide;
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
    
    UIStatusBarManager *manager = [UIApplication sharedApplication].windows.firstObject.windowScene.statusBarManager;
    CGFloat height = manager.statusBarFrame.size.height;
    // not needed, apparently height += topPadding;
    f.origin.y = height + self.navigationController.navigationBar.frame.size.height;
    f.size.height = self.navigationController.toolbar.frame.origin.y - f.origin.y; //  - bottomPadding;
    f.origin.x = leftPadding;
    f.size.width -= rightPadding + f.origin.x;
    containerView.frame = f;
    NSLog(@"    containerview frame:  %.0f x %.0f", f.size.width, f.size.height);

    // Compute the size available for the image on the screen.  We include various constraints
    // for layout reasons.
    // the image display starts on the upper left of the screen.  Its width
    // must leave room for at least one thumb on the right, the aspect ratio
    // must match the image source, and it may not use more than a certain percentage
    // of the height of the screen.
    
    CGSize displaySizeLimit = containerView.frame.size;
    // displaySizeLimit.width -= (OLIVE_W + SEP);
    displaySizeLimit.height = round(displaySizeLimit.height * 1.0);    // no more than two thirds of the screen in height
    
    // determine capture size based on various target sizes
    CGSize captureSize;
    
    if (!ISCAMERA(currentSource.sourceType)) {
        captureSize = currentSource.imageSize;
        NSLog(@"file size is %.0f x %.0f", captureSize.width, captureSize.height);
    } else {    // figure out camera configuration
        if (needHires) {
            captureSize = CGSizeZero;   // largest available
        } else if (externalTasks) {
            captureSize = externalTasks.transformSize;  // assume they are the largest
        } else {
            captureSize = displaySizeLimit;
        }
#ifdef DEBUG_CAMERA_CAPTURE_SIZE
        NSLog(@"  cam target size is %.0f x %.0f", captureSize.width, captureSize.height);
#endif
        captureSize = [cameraController setupCameraForSize:captureSize];
#ifdef DEBUG_CAMERA_CAPTURE_SIZE
        NSLog(@"        best size is %.0f x %.0f", captureSize.width, captureSize.height);
#endif
    }
    
    // we now have the capture size.  Adjust the display size and thumb area size.
    assert(captureSize.height > 0);     // should never happen, of course
//    CGFloat aspectRatio = captureSize.width/captureSize.height;
    
    CGSize displaySize;     // compute our display size
    
    if (captureSize.width > displaySizeLimit.width) {
        // Taskgroup will scale down. Adjust the display size based on aspect ratio,
        // so there may be more room for thumbs
        CGFloat xScale = displaySizeLimit.width / captureSize.width;
        if (captureSize.height * xScale > displaySizeLimit.height) {
            // even squeezed horizontally, the image is too tall.  Squeeze so
            // that both fit.
            CGFloat yScale = displaySizeLimit.height / captureSize.height;
            assert(yScale < xScale);        // make sure the code is right
            displaySize = CGSizeMake(captureSize.width * yScale, captureSize.height * yScale);
        } else {
            displaySize = CGSizeMake(captureSize.width * xScale, captureSize.height * xScale);
        }
        assert(displaySize.height <= displaySizeLimit.height);
        assert(displaySize.width <= displaySizeLimit.width);
    } else if (captureSize.height > displaySizeLimit.height) {
        CGFloat yScale = displaySizeLimit.height / captureSize.height;
        displaySize = CGSizeMake(captureSize.width * yScale, captureSize.height * yScale);
    } else
        displaySize = captureSize;
    NSLog(@"     display size is %.0f x %.0f", displaySize.width, displaySize.height);

    f.origin = CGPointZero;
    f.size = displaySize;
    transformView.frame = f;
    f.origin = CGPointZero;
    transformImageView.frame = f;
    
    [screenTasks configureGroupForSize: captureSize];
    if (!screenTask)
        screenTask = [screenTasks createTaskForTargetImageView:transformImageView named:@"main"];

    //    [screenTasks selectDepthTransform:depthTransformIndex];
    //    [thumbsTasks selectDepthTransform:depthTransformIndex];
    //    [externalTask configureForSize: processingSize];
    
// XXXXXX    [self updateOlivesTo:nil];
    oliveUpdateNeeded = YES;
    
    [oliveScrollView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    
    f = containerView.frame;
    f.origin = CGPointZero;
    oliveScrollView.frame = f;
    [containerView addSubview:oliveScrollView];
    
    oliveArrayView = [[UIView alloc] initWithFrame:oliveScrollView.frame];
    [self fillOliveView: oliveArrayView];   // This will adjust its frame size
    
    oliveScrollView.contentSize = oliveArrayView.frame.size;
    oliveScrollView.contentOffset = oliveArrayView.frame.origin;
    oliveScrollView.pagingEnabled = NO;
    oliveScrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    oliveScrollView.showsVerticalScrollIndicator = YES;
    oliveScrollView.userInteractionEnabled = YES;
    oliveScrollView.exclusiveTouch = NO;
    oliveScrollView.bounces = NO;
    oliveScrollView.delaysContentTouches = YES;
    oliveScrollView.canCancelContentTouches = YES;
    [oliveScrollView addSubview:oliveArrayView];
    
    [containerView bringSubviewToFront:transformView];
    
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformImageView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;
    if (ISCAMERA(currentSource.sourceType)) {
        [self cameraOn:YES];
    } else {
        [self transformCurrentImage];
    }
    [self adjustButtons];
    
    [taskCtrl layoutCompleted];
}

- (void) fillOliveView:(UIView *)oliveSelectionPanel {
    CGFloat frameH = 0;
    
    CGRect imageRect = CGRectZero;
    imageRect.size.width = OLIVE_W;
    float aspectRatio = transformImageView.frame.size.width/transformImageView.frame.size.height;
    imageRect.size.height = round(imageRect.size.width / aspectRatio);
    
    [thumbTasks removeAllTransforms];
    [thumbTasks configureGroupForSize: imageRect.size];
    
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowOffset = CGSizeMake(3,3);
    shadow.shadowBlurRadius = 5.0;
    shadow.shadowColor = [UIColor blackColor];
    
    NSDictionary *labelAttributes = @{
        NSForegroundColorAttributeName:[UIColor blackColor],
        NSBackgroundColorAttributeName: [UIColor colorWithWhite:0.7 alpha:0.7],
        NSFontAttributeName : [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE],
        //        NSShadowAttributeName: shadow
    };
    
    BOOL roomRightOftransformView = RIGHT(transformView.frame) +
        SEP + imageRect.size.width <= containerView.frame.size.width;
    
    BOOL roomUndertransformView = BELOW(transformView.frame) +
        SEP + imageRect.size.height <= containerView.frame.size.height;
    
    assert(roomUndertransformView || roomRightOftransformView);
    
    CGRect f;
    f.size.width = imageRect.size.width;
    f.size.height = imageRect.size.height; // + OLIVE_LABEL_H;
    if (roomRightOftransformView) {
        f.origin.x = RIGHT(transformView.frame) + SEP;
        f.origin.y = transformView.frame.origin.y;
    } else {
        f.origin.x = transformView.frame.origin.x;
        f.origin.y = BELOW(transformView.frame) + SEP;
    }

    for (size_t i=0; i<transforms.flatTransformList.count; i++) {
        UIView *v = [[UIView alloc] initWithFrame:f];
        frameH = BELOW(v.frame) + SEP;
        v.layer.cornerRadius = 5.0;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
        imageView.frame = imageRect;
        imageView.backgroundColor = [UIColor whiteColor];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.opaque = YES;
        [v addSubview:imageView];   // empty placeholder at the moment
//        if (thumbTasksEmpty) {
//            Task *newTask = [thumbTasks createTaskForTargetImageView:imageView];
//        }

        // XXXXX        imageView.tag = THUMB_TASK_INDEX_BASE_TAG + taskIndex;  // XXX not sure this will be needed
        
        Transform *transform = [transforms.flatTransformList objectAtIndex:i];
        Task *task = [thumbTasks createTaskForTargetImageView:imageView
                                                        named:transform.name];
        [task appendTransform:transform];

        UILabel *transformLabel = [[UILabel alloc] init];
        transformLabel.textAlignment = NSTextAlignmentCenter;
        transformLabel.adjustsFontSizeToFitWidth = NO;
        transformLabel.numberOfLines = 0;
        transformLabel.lineBreakMode = NSLineBreakByWordWrapping;
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
        transformLabel.frame = CGRectMake(0, f.size.height-labelSize.height, f.size.width, labelSize.height);
        transformLabel.tag = TRANSFORM_LABEL_TAG;
        transformLabel.opaque = NO;
        transformLabel.backgroundColor = [UIColor clearColor];
        //        transformLabel.backgroundColor = [UIColor greenColor];
        transformLabel.contentMode = NSLayoutAttributeBottom;
        [v addSubview:transformLabel];
//        [v bringSubviewToFront:transformLabel];
        
        UITapGestureRecognizer *touch = [[UITapGestureRecognizer alloc]
                                         initWithTarget:self
                                         action:@selector(didTapOlive:)];
        [touch setNumberOfTouchesRequired:1];
        [v addGestureRecognizer:touch];
        
        v.tag = TRANSFORM_BASE_TAG + i;     // encode the index of this transform
        [oliveSelectionPanel addSubview:v];
        [self adjustOliveSelected:v selected:NO];
        
        // where does the next thumb go?
        f.origin.x = RIGHT(v.frame) + SEP;
        if (RIGHT(f) > containerView.frame.size.width) {   // go to next row
            f.origin.y = BELOW(f) + SEP;
            if (roomUndertransformView && f.origin.y >= BELOW(transformView.frame) + SEP) {   // underneath the display
                f.origin.x = transformView.frame.origin.x;
            } else {
                f.origin.x = RIGHT(transformView.frame) + SEP;
            }
        }
    }

    f = oliveSelectionPanel.frame;
    f.size.height = frameH;
    oliveSelectionPanel.frame = f;
}

- (void) updateOlivesTo:(UIImage *) newImage {
    for (size_t i=0; i<transforms.flatTransformList.count; i++) {
        [self updateOliveImage:i to:newImage];
    }
}

- (void) updateOliveImage:(size_t) index to:(UIImage *)newImage {
    if (!oliveArrayView)
        return;
    UIImageView *v = [oliveArrayView viewWithTag:index + TRANSFORM_BASE_TAG];
    if (!v) {
        NSLog(@"olive view not found: %zu", index);
        return;
    }
#ifdef OLD
    UIImageView *iv = [v viewWithTag:TRANSFORM_ICON_IMAGE_TAG];
    assert(iv);
    [iv setImage:newImage];
#endif
}

- (void) adjustOliveSelected:(UIView *)v selected:(BOOL)selected {
    UILabel *l = [v viewWithTag:TRANSFORM_LABEL_TAG];
    assert(l);
    if (selected) {
        l.font = [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE];
        v.layer.borderWidth = 5.0;
        oliveSelectedView = v;
    } else {
        l.font = [UIFont systemFontOfSize:OLIVE_FONT_SIZE];
        oliveSelectedView = nil;
        v.layer.borderWidth = 1.0;
    }
    [l setNeedsDisplay];
    [v setNeedsDisplay];
}

- (IBAction) didTapOlive:(UITapGestureRecognizer *)recognizer {
#ifdef OLD
    @synchronized (transforms.sequence) {
        [transforms.sequence removeAllObjects];
        transforms.sequenceChanged = YES;
    }
#endif
    [screenTasks removeAllTransforms];  // currently, no stacked transforms
    
    // at present, only one view selectable
    UIView *v = [recognizer view];
    if (v == oliveSelectedView) {   // deselect, and we are done
        [self adjustOliveSelected:oliveSelectedView selected:NO];
        oliveSelectedView = nil;
        return;
    }
    
    if (oliveSelectedView) {   // just turn off current one
        [self adjustOliveSelected:oliveSelectedView selected:NO];
    }
    
    oliveSelectedView = v;
    [self adjustOliveSelected:oliveSelectedView selected:YES];
    
    size_t flatTransformIndex = v.tag - TRANSFORM_BASE_TAG;
    Transform *transform = [transforms.flatTransformList objectAtIndex:flatTransformIndex];
    [screenTask appendTransform:transform];
}

#ifdef OLD
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

- (void) adjustButtons {
//    NSLog(@"****** adjustButtons ******");
    
    trashButton.enabled = screenTask.transformList.count > 0;
    undoButton.enabled = screenTask.transformList.count > 0;
    sourceSelection.selectedSegmentIndex = currentSource.sourceType;
    NSLog(@" current selection is %ld", (long)sourceSelection.selectedSegmentIndex);
    
    [sourceSelection setNeedsLayout];
    
    stopCamera.enabled = capturing;
    startCamera.enabled = !stopCamera.enabled;
}

- (void) adjustDepthInfo {
    NSLog(@"-------- adjustDepthInfo ----------");
}

- (void) cameraOn:(BOOL) on {
    capturing = on;
    if (capturing)
        [cameraController startCamera];
    else
        [cameraController stopCamera];
    [self adjustButtons];
}

#ifdef notdef
// sourcesScrollView contains the display size.  Layout the input source buttons
// with the size and shape of this view in mind, and set the contentsize.
// The buttonsview scrolls vertically only, so it doesn't confuse some
// horizontal scrolling we do.  It must have one column, but may have more.

#define THUMB_SEP   2

- (void) layoutSourceButtonsViewInScrollView {
    // remove previous buttons
    [sourceButtonsView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    
    CGRect f = sourcesScrollView.frame;
    int thumbsPerRow = f.size.width / (SELECTION_THUMB_SIZE + THUMB_SEP);
    if (thumbsPerRow < 1)
        thumbsPerRow = 1;
    
    float thumbWidth = (f.size.width - (thumbsPerRow - 1)*THUMB_SEP)/thumbsPerRow;
    f.size.width = thumbWidth;
    f.size.height = thumbWidth;
    f.origin = CGPointZero;
    
    CGFloat lastH = 0;
    for (int i=0; i<inputSources.count; i++) {
        InputSource *source = [inputSources objectAtIndex:i];
        UIButton *but = source.button;
        
        BOOL newRow = (i % thumbsPerRow) == 0;
        if (newRow) {
            f.origin.x = 0;
            if (i)
                f.origin.y += f.size.height + THUMB_SEP;
            lastH = f.origin.y + f.size.height;
        } else
            f.origin.x += f.size.width + THUMB_SEP;
        but.frame = f;
        [sourceButtonsView addSubview:but];
    }
    f.origin = CGPointZero;
    f.size.width = thumbsPerRow * SELECTION_THUMB_SIZE + (thumbsPerRow - 1)*THUMB_SEP;
    f.size.height = lastH;
    sourcesScrollView.contentSize = f.size;
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

- (IBAction) didTapSceen:(UITapGestureRecognizer *)recognizer {
    BOOL isHidden = self.navigationController.navigationBarHidden;
    [self.navigationController setNavigationBarHidden:!isHidden animated:YES];
    [self.navigationController setToolbarHidden:!isHidden animated:YES];
}

- (IBAction) doPauseCamera:(UIBarButtonItem *)recognizer {
    if ([cameraController isCameraOn]) {
        [cameraController stopCamera];
    }
    capturing = NO;
    [self adjustButtons];
}

- (IBAction) doResumeCamera:(UIBarButtonItem *)recognizer {
    if (![cameraController isCameraOn]) {
        [cameraController startCamera];
    }
    capturing = YES;
    [self adjustButtons];
}

- (IBAction) doSave:(UIBarButtonItem *)barButton {
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

- (IBAction) didSwipeVideoLeft:(UISwipeGestureRecognizer *)recognizer {
    NSLog(@"did swipe video left, save output to photos");
}

- (IBAction) didTwoSwipeVideoLeft:(UISwipeGestureRecognizer *)recognizer {
    NSLog(@"did two swipe video right, save screen to photos");
}


- (IBAction) didSwipeVideoRight:(UISwipeGestureRecognizer *)recognizer {
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

- (void) useImage:(UIImage *)image {
    [cameraController stopCamera];
    [self adjustButtons];
    
    [screenTasks executeTasksWithImage:image];
    [thumbTasks executeTasksWithImage:image];
#ifdef EXECUTEDAUTOMATICALLY
    assert(transformed);    // should never be too busy at this point
    dispatch_async(dispatch_get_main_queue(), ^{
        self->transformImageView.image = transformed;
        [self->transformImageView setNeedsDisplay];
    });
#endif
    
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
didOutputDepthData:(AVDepthData *)depthData
timestamp:(CMTime)timestamp connection:(AVCaptureConnection *)connection {
    if (!capturing)
        return;
    if (taskCtrl.layoutNeeded)
        return;
    depthCount++;
    if (busy) {
        busyCount++;
        return;
    }
    busy = YES;
    
#ifdef TODO
    
    UIImage *processedDepthImage = [self imageFromDepthDataBuffer:depthData
                                                      orientation:imageOrientation];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->oliveUpdateNeeded) { // we have one now
            [self updateOlivesTo:processedDepthImage];
        }
        [self doTransformsOn:processedDepthImage];
        self->busy = NO;
    });
#endif
}

- (void) doTransformsOn:(UIImage *)sourceImage {
    [screenTasks executeTasksWithImage:sourceImage];
    [thumbTasks executeTasksWithImage:sourceImage];
}

- (void) transformCurrentImage {
    if (ISCAMERA(currentSource.sourceType)) // cameras don't have a current image, do they?
        return;
    UIImage *currentImage = [UIImage imageWithContentsOfFile:currentSource.imagePath];
    assert(currentImage);
    [self doTransformsOn:currentImage];
}

#ifdef TODO
static Pixel *depthPixelVisImage = 0;    // alloc on the heap, maybe too big for the stack
size_t bufferEntries = 0;

- (UIImage *) imageFromDepthDataBuffer:(AVDepthData *) rawDepthData
                           orientation:(UIImageOrientation) orientation {
    //NSLog(@"         type: %@", [cameraController dumpFormatType:rawDepthData.depthDataType]);
    // this is hdis, displarity16, on iphone X
    //assert(rawDepthData.depthDataType == kCVPixelFormatType_DepthFloat32); // what we are expecting, for now
    AVDepthData *depthData;
    if (rawDepthData.depthDataType != kCVPixelFormatType_DepthFloat32)
        depthData = [rawDepthData depthDataByConvertingToDepthDataType:kCVPixelFormatType_DepthFloat32];
    else
        depthData = rawDepthData;
    
    CVPixelBufferRef pixelBufferRef = depthData.depthDataMap;
    size_t width = CVPixelBufferGetWidth(pixelBufferRef);
    size_t height = CVPixelBufferGetHeight(pixelBufferRef);
    //NSLog(@"depth data orientation %@", width > height ? @"panoramic" : @"portrait");
    if (bufferEntries != width * height) {    // put it on the heap.  This doesn't seem to help
        if (bufferEntries) {
            free(depthPixelVisImage);
        }
        bufferEntries = width * height;
        depthPixelVisImage = (Pixel *)malloc(bufferEntries * sizeof(Pixel));
    }
    if (depthImage) {
        // if size or shape has changed, reallocate
        if (depthImage.size.width != width ||
            depthImage.size.height != height) {
            @synchronized(depthImage) {
                // reallocate.  ARC should release the old buffer
                depthImage = [[DepthImage alloc]
                              initWithSize: CGSizeMake(width, height)];
            }
        }
    } else
        depthImage = [[DepthImage alloc]
                      initWithSize: CGSizeMake(width, height)];
    
    CVPixelBufferLockBaseAddress(pixelBufferRef,  kCVPixelBufferLock_ReadOnly);
    float *capturedDepthBuffer = (float *)CVPixelBufferGetBaseAddress(pixelBufferRef);
    memcpy(depthImage.buf, capturedDepthBuffer, bufferEntries*sizeof(float));
    CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
    
#ifdef TODO
    float min = MAX_DEPTH;
    float max = MIN_DEPTH;
    for (int i=0; i<bufferSize; i++) {
        float f = depthImage.buf[i];
        if (f < min)
            min = f;
        if (f > max)
            max = f;
    }
    for (int i=0; i<100; i++)
    NSLog(@"%2d   %.02f", i, depthImage.buf[i]);
    NSLog(@" src min, max = %.2f %.2f", min, max);
    
    [transforms depthToPixels: depthImage pixels:(Pixel *)depthPixelVisImage];
    size_t bytesPerRow = depthImage.size.width*sizeof(Pixel);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(depthPixelVisImage,
                                                 width, height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 BITMAP_OPTS;
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation:orientation];
    CGImageRelease(quartzImage);
    CGColorSpaceRelease(colorSpace);
#endif
    return image;
}
#endif

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    if (!capturing)
        return;
    if (taskCtrl.layoutNeeded)
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

#ifdef V0
- (IBAction) doEditActiveList:(UIBarButtonItem *)button {
    NSLog(@"edit transform list");
    [executeTableVC.tableView setEditing:!executeTableVC.tableView.editing animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    switch (tableView.tag) {
        case TransformTable:
            return transforms.categoryNames.count;
        case ActiveTable:
            return 1;
    }
    return 1;
}

- (BOOL) isCollapsed: (NSString *) key {
    NSNumber *v = [rowIsCollapsed objectForKey:key];
    return v.boolValue;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    switch (tableView.tag) {
        case TransformTable: {
            NSString *name = [transforms.categoryNames objectAtIndex:section];
            if ([self isCollapsed:name]) {
                return 0;
            } else {
                NSArray *transformList = [transforms.categoryList objectAtIndex:section];
                return transformList.count;
            }
        }
        case ActiveTable:
            return screenTask.transformList.count;
    }
    return 1;
}

- (UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
    CGRect f;
    TableTags tableType = (TableTags) tableView.tag;
    switch (tableType) {
        case TransformTable: {
            f = CGRectMake(SEP, 0, tableView.frame.size.width - SEP, TABLE_ENTRY_H);
            UIView *sectionHeaderView = [[UIView alloc] initWithFrame:f];
            f.origin = CGPointMake(0, 0);
            f.size.width -= SECTION_HEADER_ARROW_W;
            UILabel *sectionTitle = [[UILabel alloc] initWithFrame:f];
            //sectionTitle.adjustsFontSizeToFitWidth = YES;
            sectionTitle.textAlignment = NSTextAlignmentLeft;
            sectionTitle.font = [UIFont systemFontOfSize:SECTION_HEADER_FONT_SIZE];
            NSString *name = [transforms.categoryNames objectAtIndex:section];
            sectionTitle.text = [@" " stringByAppendingString:name];
            [sectionHeaderView addSubview:sectionTitle];
            
            f.origin.x = RIGHT(f);
            f.size.width = sectionHeaderView.frame.size.width - f.origin.x;
            UILabel *rowStatus = [[UILabel alloc] initWithFrame:f];
            rowStatus.textAlignment = NSTextAlignmentRight;
            rowStatus.adjustsFontSizeToFitWidth = YES;
            if ([self isCollapsed:name]) {
                NSArray *transformList = [transforms.categoryList objectAtIndex:section];
                rowStatus.text = [NSString stringWithFormat:@"(%lu) ˃", (unsigned long)transformList.count];
            } else
                rowStatus.text = [NSString stringWithFormat:@"⌄"];
            sectionHeaderView.tag = section;    // for the tap processing
            [sectionHeaderView addSubview:rowStatus];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(tapSectionHeader:)];
            [sectionHeaderView addGestureRecognizer:tap];
            return sectionHeaderView;
        }
        case ActiveTable:
            return nil;
    }
}

- (IBAction) tapSectionHeader:(UITapGestureRecognizer *)tapGesture {
    size_t section = tapGesture.view.tag;
    NSString *name = [transforms.categoryNames objectAtIndex:section];
    BOOL newSectionHidden = ![self isCollapsed:name];
    [rowIsCollapsed setObject:[NSNumber numberWithBool:newSectionHidden] forKey:name];
    [self saveTransformSectionVisInfo];
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:section];
    [availableTableVC.tableView beginUpdates];
    [availableTableVC.tableView reloadSections:indexSet
                              withRowAnimation:UITableViewRowAnimationTop];
    [availableTableVC.tableView endUpdates];
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    switch (tableView.tag) {
        case ActiveTable:
            return 0;
        default:
            return UITableViewAutomaticDimension;
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    switch (tableView.tag) {
        case ActiveTable:
            return TABLE_ENTRY_H;
        default:
            return 0;
    }
}

- (BOOL)tableView:(UITableView *)tableView
canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = @"TableCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    assert(cell);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    Transform *transform;
    
    switch (tableView.tag) {
        case TransformTable: {   // Selection table display table list
            NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
            transform = [transformList objectAtIndex:indexPath.row];
            break;
        }
        case ActiveTable: {
            transform = [screenTask.transformList objectAtIndex:indexPath.row];
            break;
        }
    }
    [cell.contentView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    CGRect f = cell.contentView.frame;
    f.size.width = tableView.frame.size.width;
    f.size.height = cell.frame.size.height;
    cell.contentView.frame = f;
    CGFloat labelEnd = cell.contentView.frame.size.width;
    
    // The transform table has a label and possible value display.  For the depth transforms,
    // that value display is tappable.
    // The executing transforms have a label, a possible value entry, and an executing time display.
    // So carve out what we need from the end of the contentView, and leave the rest for the label.
    
    if (tableView.tag == ActiveTable) {
        f.size.width = STATS_W;
        f.origin.x = cell.contentView.frame.size.width - f.size.width - SEP;
        UILabel *stepStatsLabel = [[UILabel alloc] initWithFrame:f];
        stepStatsLabel.tag = EXECUTE_STATS_TAG;
        stepStatsLabel.font = [UIFont systemFontOfSize:STATS_FONT_SIZE];
        stepStatsLabel.adjustsFontSizeToFitWidth = YES;
        stepStatsLabel.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:stepStatsLabel];
        
        labelEnd = f.origin.x;
    }
    
    if (transform.hasParameters) {
        // A big tappable current value, and tiny lower and upper limits stacked to the left of that
#define LIMIT_SEP   (0)
        
        f = UIEdgeInsetsInsetRect(cell.contentView.frame,
                                  UIEdgeInsetsMake(5, 0, 7, 5));
        CGFloat w = VALUE_LIMITS_W + LIMIT_SEP + VALUE_W + SEP/2;
        f.origin.x = labelEnd - w;
        f.size.width = w;
        UIView *paramView = [[UIView alloc] initWithFrame:f];
        paramView.tag = indexPath.row;      // index of the entry in one or the other of the tableviews
        paramView.layer.borderWidth = 1.0;
        paramView.layer.cornerRadius = 3.0;
        [cell.contentView addSubview:paramView];
        
        f.size.width = VALUE_W;
        f.origin.x = paramView.frame.size.width - SEP/2 - f.size.width;
        f.origin.y = 0;
        
        UILabel *value = [[UILabel alloc] initWithFrame:f];
        value.tag = CURRENT_VALUE_LABEL_TAG;
        value.text = [NSString stringWithFormat:@"%d", transform.value];
        value.textAlignment = NSTextAlignmentRight;
        //value.adjustsFontSizeToFitWidth = YES;
        value.font = [UIFont systemFontOfSize:VALUE_FONT_SIZE];
        [paramView addSubview:value];
        
        f.origin.x = 0;
        f.size.width = VALUE_LIMITS_W;
        f.size.height /= 2;     // lower half, lower value, upper is upper
        UILabel *minValue = [[UILabel alloc] initWithFrame:f];
        minValue.text = [NSString stringWithFormat:@"%d –", transform.low];
        minValue.textAlignment = NSTextAlignmentCenter;
        minValue.adjustsFontSizeToFitWidth = YES;
        minValue.font = [UIFont systemFontOfSize:VALUE_LIMIT_FONT_SIZE];
        [paramView addSubview:minValue];
        
        f.origin.y += f.size.height;
        UILabel *maxValue = [[UILabel alloc] initWithFrame:f];
        maxValue.text = [NSString stringWithFormat:@"%d", transform.high];
        maxValue.textAlignment = NSTextAlignmentCenter;
        maxValue.adjustsFontSizeToFitWidth = YES;
        maxValue.font = [UIFont systemFontOfSize:VALUE_LIMIT_FONT_SIZE];
        [paramView addSubview:maxValue];
        
        // XXXX add tap gesture and visual feedback of being selected
        
        labelEnd = paramView.frame.origin.x;
    }
    
    f = cell.contentView.frame;
    f.origin.x += 10;
    f.size.width = labelEnd - f.origin.x;
    UILabel *label = [[UILabel alloc] initWithFrame:f];
    label.numberOfLines = 0;
    label.font = [UIFont
                  systemFontOfSize:TABLE_ENTRY_FONT_SIZE
                  weight:UIFontWeightLight];
    label.text = transform.name;
    label.font = [UIFont systemFontOfSize:TABLE_ENTRY_FONT_SIZE];
    [cell.contentView addSubview:label];
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (tableView.tag) {
        case TransformTable: {
            if (depthTransformIndex != NO_DEPTH_TRANSFORM) {
                NSIndexPath *oldDepth = [NSIndexPath indexPathForRow:depthTransformIndex
                                                           inSection:DEPTH_TABLE_SECTION];
                UITableViewCell *oldSelected = [availableTableVC.tableView cellForRowAtIndexPath:oldDepth];
                oldSelected.highlighted = NO;
            }
            // for depth selections, just set the depthindex
            if (indexPath.section == DEPTH_TRANSFORM_SECTION) {
                assert(transforms.depthTransform);
                depthTransformIndex = (int)indexPath.row;
                UITableViewCell *newSelected = [tableView cellForRowAtIndexPath:indexPath];
                newSelected.highlighted = YES;
                [transforms selectDepthTransform:depthTransformIndex];
                return;
            }
            // Append a transform to the active list
            NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
            Transform *transform = [transformList objectAtIndex:indexPath.row];
            [self addTransform:transform];
            [self.executeTableVC.tableView reloadData];
            [self adjustButtons];
            [self transformCurrentImage];
            break;
        }
        case ActiveTable: {
            [self displayValueSlider:(int)indexPath.row];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            cell.selected = YES;
            break;
        }
    }
}

- (void) addTransform:(Transform *) transform {
    Transform *thisTransform = [transform copy];
    assert(thisTransform.remapTable == NULL);
    @synchronized (transforms.sequence) {
        [transforms.sequence addObject:thisTransform];
        transforms.sequenceChanged = YES;
    }
}
#endif

#ifdef notdef
-(void)tableView:(UITableView *)tableView
didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView)
        [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryNone;
}
#endif

- (IBAction) doRemoveLastTransform {
    [screenTasks removeLastTransform];
    [thumbTasks removeLastTransform];
}

- (IBAction) doRemoveAllTransforms:(UIBarButtonItem *)button {
    [screenTasks removeAllTransforms];
    [thumbTasks removeAllTransforms];
}

- (IBAction) doToggleHires:(UIBarButtonItem *)button {
    needHires = !needHires;
    NSLog(@"high res now %d", needHires);
    button.style = needHires ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
}


#ifdef V0
// These operations is only for the execute table:

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete: {
            @synchronized (transforms.sequence) {
                [transforms.sequence removeObjectAtIndex:indexPath.row];
                transforms.sequenceChanged = YES;
            }
            [self adjustButtons];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationBottom];
            [self transformCurrentImage];
            break;
        }
        case UITableViewCellEditingStyleInsert:
            NSLog(@"insert?");
            [self transformCurrentImage];
            break;
        default:
            NSLog(@"commitEditingStyle: never mind: %ld", (long)editingStyle);
    }
}

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
      toIndexPath:(NSIndexPath *)toIndexPath {
    @synchronized (transforms.sequence) {
        Transform *t = [transforms.sequence objectAtIndex:fromIndexPath.row];
        [transforms.sequence removeObjectAtIndex:fromIndexPath.row];
        [transforms.sequence insertObject:t atIndex:toIndexPath.row];
        transforms.sequenceChanged = YES;
        [self transformCurrentImage];
    }
    [tableView reloadData];
}
#endif

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

- (IBAction) selectSource:(UISegmentedControl *)sender {
    int segment = (Cameras)sender.selectedSegmentIndex;
    
    nextSource = [inputSources objectAtIndex:segment];
    if (nextSource.sourceType == NotACamera) {
        [self doSelecFileSource];
    } else {
        [self.view setNeedsLayout];
        return;
    }
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
    if (collectionView.tag == sourceCollection)
        return 3;
    else
        return 1;
}

static NSString * const sourceSectionTitles[] = {
    [0] = @"    Cameras",
    [1] = @"    Samples",
    [2] = @"    From library",
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
    if (collectionView.tag == sourceCollection) {
        switch (section) {
            case 0:
                return NCAMERA;
            case 1:
                return inputSources.count - NCAMERA;
            case 2:
                return 0;
        }
        return inputSources.count;
    } else {
        return transforms.flatTransformList.count;
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView.tag == sourceCollection) {
        return CGSizeMake(SOURCE_CELL_W, SOURCE_CELL_H);
    } else {
        if (indexPath.row == 0) // entry zero is overlaid by the transform view
            return transformView.frame.size;
        else
            return CGSizeMake(TRANS_CELL_W, TRANS_CELL_H);  // XXXXX this needs to vary?
    }
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
    
    InputSource *source = [self sourceForIndexPath:indexPath];
    switch (source.sourceType) {
        case FrontCamera:
        case Front3DCamera:
        case RearCamera:
        case Rear3DCamera:
            thumbLabel.text = [InputSource cameraNameFor:source.sourceType];
            if (![cameraController isCameraAvailable:source.sourceType]) {
                thumbLabel.textColor = [UIColor grayColor];
                cell.userInteractionEnabled = NO;
            }
            break;
        default: {
            thumbLabel.text = source.label;
            UIImage *sourceImage = [UIImage imageWithContentsOfFile:source.imagePath];
            thumbImageView.image = [self fitImage:sourceImage
                                           toSize:thumbImageView.frame.size
                                         centered:YES];
            break;
        }
    }
#ifdef NOMORE
    else {
        UICollectionViewCell *cell = [collectionView
                                      dequeueReusableCellWithReuseIdentifier:TRANSFORM_CELL_ID
                                      forIndexPath:indexPath];
        assert(cell);
        
        if (indexPath.row == 0) {   // cell overlaid by transform view, nothing to show
            return cell;
        }
        size_t flatTransformIndex = indexPath.row - 1;
        Transform *transform = [transforms.flatTransformList objectAtIndex:flatTransformIndex];
        UILabel *transformLabel = [[UILabel alloc] initWithFrame:CGRectInset(cell.contentView.frame, 3, 2)];
        transformLabel.textAlignment = NSTextAlignmentCenter;
        transformLabel.text = transform.name;
        transformLabel.font = [UIFont systemFontOfSize:STATS_FONT_SIZE];
        transformLabel.adjustsFontSizeToFitWidth = YES;
        transformLabel.numberOfLines = 0;
        transformLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [cell.contentView addSubview:transformLabel];
        
        if (cell.selected)
            cell.layer.borderWidth = 5.0;
        else
            cell.layer.borderWidth = 1.0;
        cell.layer.cornerRadius = 5.0;
        return cell;
    }
#endif
    return cell;
}

- (InputSource *) sourceForIndexPath:(NSIndexPath *)indexPath {
    size_t i;
    switch (indexPath.section) {
        case 0: // cameras
            i = indexPath.row;
            break;
        case 1: // examples
            i = indexPath.row + NCAMERA;
            break;
        default: //from library
            i = 0;
    }
    InputSource *source = [inputSources objectAtIndex:i];
    return source;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView.tag == sourceCollection) {
        nextSource = [self sourceForIndexPath:indexPath];
        [sourcesNavVC dismissViewControllerAnimated:YES completion:nil];
        NSLog(@"    ***** collectionView setneedslayout");
        [self.view setNeedsLayout];
    }
#ifdef V0
    else {    // transform selection
        @synchronized (transforms.sequence) {
            [transforms.sequence removeAllObjects];
            transforms.sequenceChanged = YES;
        }
        assert(indexPath.row > 0);  // entry zero should always be obscured
        size_t flatTransformIndex = indexPath.row - 1;
        Transform *transform = [transforms.flatTransformList objectAtIndex:flatTransformIndex];
        [self addTransform:transform];
        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
        cell.selected = YES;
        [cell setNeedsDisplay];
    }
#endif
}

- (IBAction) dismissSourceVC:(UIBarButtonItem *)sender {
    [sourcesNavVC dismissViewControllerAnimated:YES
                                     completion:NULL];
}

@end
