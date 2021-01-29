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

#define EXECUTE_TEXT_FONT_SIZE  18
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
@property (nonatomic, strong)   UIView *containerView;

@property (nonatomic, strong)   TaskCtrl *taskCtrl;
@property (nonatomic, strong)   TaskGroup *screenTasks; // only one task in this group
@property (nonatomic, strong)   TaskGroup *thumbTasks;
@property (nonatomic, strong)   TaskGroup *externalTasks;   // not yet, only one task in this group
@property (nonatomic, strong)   TaskGroup *hiresTasks;       // not yet, only one task in this group

@property (nonatomic, strong)   Task *screenTask;
@property (nonatomic, strong)   Task *externalTask;

// in containerview:
@property (nonatomic, strong)   UIView *transformView;              // area reserved for transform display and related
@property (nonatomic, strong)   UIView *thumbArrayView;

// in transformview
@property (nonatomic, strong)   UIImageView *transformImageView;    // transformed image
@property (nonatomic, strong)   UITextView *executeControlView;         // list of applied transforms, and controls

// in sources view
@property (nonatomic, strong)   UIButton *currentCameraButton;      // or nil if no camera is selected
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;

@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;
@property (nonatomic, strong)   InputSource *nextSource;
@property (nonatomic, strong)   InputSource *fileSource;
@property (assign)              int availableCameraCount;

@property (nonatomic, strong)   Transforms *transforms;
//@property (nonatomic, strong)   Transform *currentDepthTransform;  // current one, must not be nil
@property (assign)              long currentTransformIndex;      // or NO_TRANSFORM
@property (assign)              long currentDepthTransformIndex; // or NO_TRANSFORM

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
@synthesize executeControlView;
@synthesize thumbArrayView;

@synthesize sourcesNavVC;

@synthesize currentCameraButton;

@synthesize inputSources, currentSource;
@synthesize currentTransformIndex;
@synthesize currentDepthTransformIndex;

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
        currentTransformIndex = NO_TRANSFORM;   // XXX this is going to be a list
        
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
        
        Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
        screenTasks.defaultDepthTransform = depthTransform;
        thumbTasks.defaultDepthTransform = depthTransform;

        transformTotalElapsed = 0;
        transformCount = 0;
        depthBuf = nil;
        thumbScrollView = nil;
        busy = NO;
        needHires = NO;
        
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

        lastFileSourceUsed = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:LAST_FILE_SOURCE_KEY];
        NSString *lastSourceUsedLabel = [[NSUserDefaults standardUserDefaults]
                                   stringForKey:LAST_SOURCE_KEY];
        if (lastSourceUsedLabel) {
            for (int sourceIndex=0; sourceIndex<inputSources.count; sourceIndex++) {
                nextSource = [inputSources objectAtIndex:sourceIndex];
                if ([lastSourceUsedLabel isEqual:nextSource.label]) {
 //                   NSLog(@"  - initializing source index %d", sourceIndex);
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

- (void) saveDepthTransformName {
    assert(currentDepthTransformIndex != NO_TRANSFORM);
    Transform *transform = [transforms.transforms objectAtIndex:currentDepthTransformIndex];
    [[NSUserDefaults standardUserDefaults] setObject:transform.name
                                              forKey:LAST_DEPTH_TRANSFORM];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) saveUIMode {
    NSString *uiStr = [NSString stringWithFormat:@"%d", uiMode];
    [[NSUserDefaults standardUserDefaults] setObject:uiStr
                                              forKey:UI_MODE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) saveCurrentSource {
//    NSLog(@"Saving source %d, %@", currentSource.sourceType, currentSource.label);
    [[NSUserDefaults standardUserDefaults] setObject:currentSource.label
                                              forKey:LAST_SOURCE_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:lastFileSourceUsed
                                              forKey:LAST_FILE_SOURCE_KEY];
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
    
    sourceSelection = [[UISegmentedControl alloc] initWithItems:sourceNames];
    sourceSelection.frame = CGRectMake(0, 0,
                                       100, self.navigationController.navigationBar.frame.size.height);
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
    
    executeControlView = [[UITextView alloc]
                          initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    executeControlView.editable = NO;
    executeControlView.allowsEditingTextAttributes = NO;
    executeControlView.selectable = NO;
    executeControlView.font = [UIFont boldSystemFontOfSize:EXECUTE_TEXT_FONT_SIZE];
    [transformView addSubview:executeControlView];
    
//    [transformView bringSubviewToFront:executeControlView];
     
    thumbScrollView = [[UIScrollView alloc] init];
    thumbScrollView.pagingEnabled = NO;
    thumbScrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    thumbScrollView.showsVerticalScrollIndicator = YES;
    thumbScrollView.userInteractionEnabled = YES;
    thumbScrollView.exclusiveTouch = NO;
    thumbScrollView.bounces = NO;
    thumbScrollView.delaysContentTouches = YES;
    thumbScrollView.canCancelContentTouches = YES;
    [containerView addSubview:thumbScrollView];
    
    thumbArrayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [thumbScrollView addSubview:thumbArrayView];
    [containerView addSubview:thumbArrayView];

    [self createThumbArray];    // animate to correct positions later
    
    [self.view layoutIfNeeded];
    [self.view addSubview:containerView];
    
    //externalTask = [externalTasks createTaskForTargetImage:transformImageView.image];
    
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) createThumbArray {
    UITapGestureRecognizer *touch;
    for (size_t i=0; i<transforms.depthTransformCount; i++) {
        Transform *transform = [transforms.transforms objectAtIndex:i];
        UIView *thumbView = [self makeThumbForTransform:transform];
        [self adjustThumb:thumbView selected:NO];
        touch = [[UITapGestureRecognizer alloc]
                 initWithTarget:self
                 action:@selector(doSelectDepthVis:)];
        [thumbView addGestureRecognizer:touch];
        
#ifdef OLD
        // no live updates for depth views for now
        UIImageView *imageView = [thumbView viewWithTag:THUMB_IMAGE_TAG];
        NSString *file = [@"images/" stringByAppendingPathComponent:transform.name];
        NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@"jpeg"];
        if (imagePath) {
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            imageView.image = [UIImage imageWithContentsOfFile:imagePath];
        } else {
            NSLog(@"thumb image '%@' not found", file);
        }
#endif
        UIImageView *imageView = [thumbView viewWithTag:THUMB_IMAGE_TAG];
        Task *task = [thumbTasks createTaskForTargetImageView:imageView named:transform.name];
        task.depthTransform = transform;    // we are our own depth transform

        thumbView.tag = TRANSFORM_BASE_TAG + i;     // encode the index of this transform
        [thumbArrayView addSubview:thumbView];
    }
    
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
        Task *task = [thumbTasks createTaskForTargetImageView:imageView named:transform.name];
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

#define SEP 5  // between views
#define INSET 3 // from screen edges
#define MIN_TRANS_TABLE_W 275

- (void) doLayout {
#ifdef DEBUG_LAYOUT
    NSLog(@"****** doLayout self.view %0.f x %.0f",
          self.view.frame.size.width, self.view.frame.size.height);
#endif
    BOOL adjustSourceInfo = (nextSource != nil);
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = (uiMode == oliveUI);
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.opaque = (uiMode == oliveUI);
    
    // set up new source, if needed
    if (nextSource) {
        if (currentSource && ISCAMERA(currentSource.sourceType)) {
            [self cameraOn:NO];
        }
        if (!ISCAMERA(nextSource.sourceType)) {
            lastFileSourceUsed = nextSource.label;
        }
        currentSource = nextSource;
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
    
    UIStatusBarManager *manager = [UIApplication sharedApplication].windows.firstObject.windowScene.statusBarManager;
    CGFloat height = manager.statusBarFrame.size.height;
    // not needed, apparently height += topPadding;
    f.origin.y = height + self.navigationController.navigationBar.frame.size.height + topPadding + SEP;
    f.size.height = self.navigationController.toolbar.frame.origin.y - f.origin.y; //  - bottomPadding;
    f.origin.x = leftPadding + SEP;
    f.size.width -= rightPadding + f.origin.x;
    containerView.frame = f;
#ifdef DEBUG_LAYOUT
    NSLog(@"    containerview frame:  %.0f x %.0f", f.size.width, f.size.height);
#endif
    
    // Compute the size available for the image on the screen.  We include various constraints
    // for layout reasons. We also need room for the execute display, a few lines of text below
    // the transformed image.
    //
    // the image display starts on the upper left of the screen.  The aspect ratio
    // must match the image source. We try to come out with layouts that work based on device
    // and orientation.  This is highly-constrained for iPhones and such.
    
    CGSize displaySizeLimit = containerView.frame.size;
    displaySizeLimit.height -= EXECUTE_H;
    displaySizeLimit.height = round(displaySizeLimit.height * 1.0);
    if (displaySizeLimit.width > 768)
        displaySizeLimit.width = 768;
    
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
#ifdef DEBUG_LAYOUT
    NSLog(@"     display size is %.0f x %.0f", displaySize.width, displaySize.height);
#endif
    
    f.origin = CGPointZero;
    f.size = displaySize;
    f.size.height += EXECUTE_H;
    transformView.frame = f;

    f.origin = CGPointZero;
    f.size = displaySize;
    transformImageView.frame = f;

    f.origin.y = BELOW(transformImageView.frame);
    f.size.height = EXECUTE_H;
    executeControlView.frame = f;

    Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    if (!screenTask) {
        screenTask = [screenTasks createTaskForTargetImageView:transformImageView named:@"main"];
        thumbTasks.defaultDepthTransform = depthTransform;
    }
    [screenTasks configureGroupForSize: captureSize];
    
    if (IS_3D_CAMERA(currentSource.sourceType))
        screenTask.depthTransform = depthTransform;
    else
        screenTask.depthTransform = nil;

    //    [externalTask configureForSize: processingSize];

    // for a start, these fit in the container, though we may
    // adjust them later.
    
    f = containerView.frame;
    f.origin = CGPointMake(0, transformView.frame.origin.y);
    f.size.height -= f.origin.y;
    thumbScrollView.frame = f;
    f.origin = CGPointZero;
    thumbArrayView.frame = f;   // the final may be higher

    [UIView animateWithDuration:0.5 animations:^(void) {
        CGRect f = self->containerView.frame;
        f.origin = CGPointZero;
        self->thumbScrollView.frame = f;
        // move views to where they need to be now.
        [self layoutThumbArray];
    }];
    
    [containerView bringSubviewToFront:transformView];
//    transformView.hidden = YES;
    
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
}

- (void) adjustCameraButtons {
//    NSLog(@"****** adjustButtons ******");
    
    trashButton.enabled = screenTask.transformList.count > 0;
    undoButton.enabled = screenTask.transformList.count > 0;
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
BOOL roomRightOftransformView;
BOOL roomUndertransformView;
BOOL atStartOfRow;
CGFloat topOfNonDepthArray = 0;

// layout the 3d transforms.  If the input isn't a 3D source, these will always be
// scrolled off the top of the view.

- (void) layoutThumbArray {
    imageRect = CGRectZero;
    imageRect.size.width = OLIVE_W;
    float aspectRatio = transformImageView.frame.size.width/transformImageView.frame.size.height;
    imageRect.size.height = round(imageRect.size.width / aspectRatio);

    [thumbTasks configureGroupForSize:imageRect.size];
    
    nextButtonFrame.size = CGSizeMake(imageRect.size.width,
                                   imageRect.size.height + OLIVE_LABEL_H);
    
    roomRightOftransformView = RIGHT(transformView.frame) +
        SEP + nextButtonFrame.size.width <= containerView.frame.size.width;
    roomUndertransformView = BELOW(transformView.frame) +
        SEP + nextButtonFrame.size.height <= containerView.frame.size.height;
    assert(roomUndertransformView || roomRightOftransformView); // we need space somewhere...

    if (roomRightOftransformView) {
        nextButtonFrame.origin.x = RIGHT(transformView.frame) + SEP;
        nextButtonFrame.origin.y = transformView.frame.origin.y;
    } else {
        nextButtonFrame.origin.x = transformView.frame.origin.x;
        nextButtonFrame.origin.y = BELOW(transformView.frame) + SEP;
    }
    
    if (!roomRightOftransformView || !roomUndertransformView) {
        CGRect f = transformView.frame;
        if (!roomRightOftransformView) {    // center the transform display
            f.origin.x = (containerView.frame.size.width - f.size.width)/2;
        } else {
            f.origin.y = (containerView.frame.size.height - f.size.height)/2;
        }
        transformView.frame = f;
    }
    atStartOfRow = YES;

    // Run through all the transforms, computing the corresponding thumb sizes and
    // positions for the current situation. Skip to a new row after depth transforms,
    // which are first.
    
    CGFloat thumbsH = 0;
    BOOL is3D = IS_3D_CAMERA(currentSource.sourceType);
    
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
                f.origin = CGPointZero;
                thumb.frame = f;
//              thumb.hidden = YES;
                continue;
            }
        } else {    // regular transform
            if (currentTransformIndex != NO_TRANSFORM && i == currentTransformIndex) {
                [self adjustThumb:thumb selected:YES];
            } else {
                [self adjustThumb:thumb selected:NO];
            }
        }

        
        thumb.frame = nextButtonFrame;
        thumb.hidden = NO;
        thumb.userInteractionEnabled = YES;

        UIImageView *imageView = [thumb viewWithTag:THUMB_IMAGE_TAG];
        imageView.frame = imageRect;
        UILabel *label = [thumb viewWithTag:THUMB_LABEL_TAG];
        label.frame = CGRectMake(0, BELOW(imageView.frame), thumb.frame.size.width, OLIVE_LABEL_H);

        Transform *depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
        if (is3D)
            screenTasks.defaultDepthTransform = depthTransform;
        else
            screenTasks.defaultDepthTransform = nil;
        thumbTasks.defaultDepthTransform = depthTransform;

        atStartOfRow = NO;
        thumbsH = BELOW(thumb.frame);
        
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
    if (IS_3D_CAMERA(currentSource.sourceType))
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
    if (roomRightOftransformView) {
        if (f.origin.y < BELOW(transformView.frame)) {   // we are still on the right
            f.origin.x = RIGHT(transformView.frame) + SEP;
        } else {    // below transformView. Space underneath?
            if (roomUndertransformView)
                f.origin.x = 0;
            else
                f.origin.x = RIGHT(transformView.frame) + SEP;
        }
    } else {    // room only under transform view
        assert(roomUndertransformView);
        f.origin.x = transformView.frame.origin.x;
    }
    nextButtonFrame = f;
    atStartOfRow = YES;
}

// select a new depth visualization.
- (IBAction) doSelectDepthVis:(UITapGestureRecognizer *)recognizer {
    UIView *newView = recognizer.view;
    [self newDepthVizAtThumb:newView];
}

- (void) newDepthVizAtThumb:(UIView *) newView {
    long newTransformIndex = newView.tag - TRANSFORM_BASE_TAG;
    assert(newTransformIndex >= 0 && newTransformIndex < transforms.transforms.count);
    if (newTransformIndex == currentDepthTransformIndex)
        return;
    
    assert(currentDepthTransformIndex != NO_TRANSFORM);
    UIView *oldSelectedDepthThumb = [thumbArrayView viewWithTag:currentDepthTransformIndex + TRANSFORM_BASE_TAG];

    [self adjustThumb:oldSelectedDepthThumb selected:NO];
    [self adjustThumb:newView selected:YES];
    
    currentDepthTransformIndex = newTransformIndex;
    screenTask.depthTransform = [transforms transformAtIndex:currentDepthTransformIndex];
    assert(screenTask.depthTransform.type == DepthVis);
    [self saveDepthTransformName];
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
    [screenTasks removeAllTransforms];  // currently, no stacked transforms
    // at present, only one view selectable
    long tappedTransformIndex = tappedThumb.tag - TRANSFORM_BASE_TAG;
    if (tappedTransformIndex == currentTransformIndex) {
        // tapped the current one.  Deselect, and we are done.
        [self adjustThumb:tappedThumb selected:NO];
        currentTransformIndex = NO_TRANSFORM;
        [self doTransformsOn:[UIImage imageWithContentsOfFile:currentSource.imagePath]];
        [self updateExecuteDisplay];
        return;
    }
    
    // If there is an old one, deselect it
    if (currentTransformIndex != NO_TRANSFORM) {
        UIView *oldSelectedThumb = [thumbArrayView viewWithTag:currentTransformIndex + TRANSFORM_BASE_TAG];
        assert(oldSelectedThumb);
        [self adjustThumb:oldSelectedThumb selected:NO];
    }
    
    [self adjustThumb:tappedThumb selected:YES];
    currentTransformIndex = tappedTransformIndex;

    Transform *tappedTransform = [transforms transformAtIndex:currentTransformIndex];
    [screenTask appendTransform:tappedTransform];
    
    [self updateExecuteDisplay];
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

- (void) updateExecuteDisplay {
    NSString *statusText = [screenTask executeStatus];
    executeControlView.text = statusText;
    [executeControlView setNeedsDisplay];
#ifdef OLD
    [executeControlView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
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
        //label.backgroundColor = [UIColor clearColor];
        [executeControlView addSubview:label];
        f.origin.y -= f.size.height;
    }
    [executeControlView setNeedsDisplay];
#endif
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

- (void) adjustDepthInfo {
    NSLog(@"-------- adjustDepthInfo ----------");
}

- (void) cameraOn:(BOOL) on {
    capturing = on;
    if (capturing)
        [cameraController startCamera];
    else
        [cameraController stopCamera];
    [self adjustCameraButtons];
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
    [self adjustCameraButtons];
}

- (IBAction) doResumeCamera:(UIBarButtonItem *)recognizer {
    if (![cameraController isCameraOn]) {
        [cameraController startCamera];
    }
    capturing = YES;
    [self adjustCameraButtons];
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

@end
