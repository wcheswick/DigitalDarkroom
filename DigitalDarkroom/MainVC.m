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
#import "Defines.h"

#define BUTTON_FONT_SIZE    20
#define STATS_W             75
#define STATS_FONT_SIZE     18

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

#define SECTION_HEADER_ARROW_W  100

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

typedef enum {
    TransformTable,
    ActiveTable,
} TableTags;


@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   UIView *containerView;

// screen views in containerView
@property (nonatomic, strong)   UIImageView *transformView;           // area reserved for transform display
@property (nonatomic, strong)   UINavigationController *sourcesNavVC;
@property (nonatomic, strong)   UINavigationController *executeNavVC;       // table of current transforms
@property (nonatomic, strong)   UINavigationController *availableNavVC;        // available transforms

// in execute view
@property (nonatomic, strong)   UITableViewController *executeTableVC;

// in available VC
@property (nonatomic, strong)   UITableViewController *availableTableVC;

// in sources view
@property (nonatomic, strong)   UIButton *currentCameraButton;  // or nil if no camera is selected

@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;
@property (nonatomic, strong)   InputSource *nextSource;

@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   UILabel *allStatsLabel;

@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;

@property (nonatomic, strong)   UIBarButtonItem *trashButton;
@property (nonatomic, strong)   UIBarButtonItem *saveButton;

@property (assign, atomic)      BOOL capturing;         // camera is on and getting processed
@property (assign)              BOOL busy;              // transforming is busy, don't start a new one
@property (assign)              UIImageOrientation imageOrientation;
@property (assign)              DisplayMode_t displayMode;

@property (nonatomic, strong)   NSMutableDictionary *rowIsCollapsed;
@property (nonatomic, strong)   DepthImage *depthImage;
@property (assign)              CGSize transformDisplaySize;

@property (assign)              int depthTransformIndex;
@property (assign)              BOOL fullImage;     // transform a full capture (slower)

@property (nonatomic, strong)   UISegmentedControl *sourceSelection;

@end

@implementation MainVC

@synthesize containerView;
@synthesize transformView;
@synthesize sourcesNavVC;
@synthesize executeNavVC;
@synthesize availableNavVC;

@synthesize executeTableVC;
@synthesize availableTableVC;

@synthesize currentCameraButton;

@synthesize inputSources, currentSource;
@synthesize nextSource;

@synthesize cameraController;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy;
@synthesize statsTimer, allStatsLabel, lastTime;
@synthesize transforms;
@synthesize trashButton, saveButton;
@synthesize capturing;
@synthesize imageOrientation;
@synthesize displayMode;

@synthesize rowIsCollapsed;
@synthesize depthImage;
@synthesize depthTransformIndex;

@synthesize transformDisplaySize;
@synthesize fullImage;
@synthesize sourceSelection;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        [self loadTransformSectionVisInfo];

        transformTotalElapsed = 0;
        transformCount = 0;
        depthImage = nil;
        depthTransformIndex = 0;
        busy = NO;
        
        inputSources = [[NSMutableArray alloc] init];

        [self addCameraSource:FrontCamera label:@"Front camera"];
        [self addCameraSource:RearCamera label:@"Rear camera"];
        [self addCameraSource:Front3DCamera label:@"Front 3D camera"];
        [self addCameraSource:Rear3DCamera label:@"Rear 3D camera"];
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
        
        cameraController = [[CameraController alloc] init];
        cameraController.delegate = self;
        currentCameraButton = nil;
        
        Cameras sourceIndex;
        for (sourceIndex=0; sourceIndex<NCAMERA; sourceIndex++) {
            if ([cameraController isCameraAvailable:sourceIndex])
                break;
        }
        currentSource = nil;
        nextSource = [inputSources objectAtIndex:sourceIndex];
        fullImage = NO;
        [self newDisplayMode:medium];
    }
    return self;
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
            if (value)
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
            newMode = newMode;
            return;
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
    NSLog(@"new display mode is %d", displayMode);
}

- (void) addCameraSource:(Cameras)c label:(NSString *)l {
    InputSource *is = [[InputSource alloc] init];
    is.sourceType = c;
    is.label = l;
    [inputSources addObject:is];
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Digital Darkroom";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = NO;
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.opaque = NO;
    
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UISegmentedControl class]]] setNumberOfLines:0];
    sourceSelection = [[UISegmentedControl alloc]
                       initWithItems: [NSArray arrayWithObjects:
                                       @"Front\ncamera",
                                       @"Rear\ncamera",
                                       @"Front\n3D",
                                       @"Rear\n3D",
                                       @"File", nil]];
    sourceSelection.frame = CGRectMake(0, 0, 100, 44);
    [sourceSelection addTarget:self action:@selector(selectSource:)
               forControlEvents: UIControlEventValueChanged];
    sourceSelection.selectedSegmentIndex = 0;
    sourceSelection.momentary = NO;
    UIBarButtonItem *leftBarItem = [[UIBarButtonItem alloc]
                                    initWithCustomView:sourceSelection];
    self.navigationItem.leftBarButtonItem = leftBarItem;

    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                       target:self
                                       action:@selector(doSave:)];
    self.navigationItem.rightBarButtonItem = rightBarButton;

    UIColor *navyBlue = NAVY_BLUE;
    
    containerView = [[UIView alloc] init];
    containerView.backgroundColor = navyBlue;
    [self.view addSubview:containerView];
    
    transformView = [[UIImageView alloc] init];
    transformView.userInteractionEnabled = YES;
    transformView.backgroundColor = navyBlue;
    [containerView addSubview:transformView];
    
    // touching the transformView toggles nav and tool bars
    UITapGestureRecognizer *touch = [[UITapGestureRecognizer alloc]
                                     initWithTarget:self action:@selector(didTapSceen:)];
    [touch setNumberOfTouchesRequired:1];
    [transformView addGestureRecognizer:touch];

    executeTableVC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    executeNavVC = [[UINavigationController alloc] initWithRootViewController:executeTableVC];
    availableTableVC = [[UITableViewController alloc]
                               initWithStyle:UITableViewStylePlain];
    availableNavVC = [[UINavigationController alloc] initWithRootViewController:availableTableVC];

    [containerView addSubview:executeNavVC.view];
    [containerView addSubview:availableNavVC.view];
    
    // execute has a nav bar and a table.  There is an extra entry in the table at
    // the end, with performance stats.
    executeTableVC.tableView.tag = ActiveTable;
    executeTableVC.tableView.delegate = self;
    executeTableVC.tableView.dataSource = self;
    //executeTableVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    executeTableVC.tableView.showsVerticalScrollIndicator = YES;
    executeTableVC.title = @"Active";
    executeTableVC.tableView.rowHeight = ACTIVE_TABLE_ENTRY_H;
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                   target:self
                                   action:@selector(doEditActiveList:)];
    executeTableVC.navigationItem.rightBarButtonItem = editButton;
    trashButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                   target:self
                                   action:@selector(doRemoveAllTransforms:)];
    executeTableVC.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:
                                                      trashButton,
                                                      nil];
    
    allStatsLabel = [[UILabel alloc] initWithFrame:CGRectMake(LATER, 0, STATS_W, TABLE_ENTRY_H)];
    allStatsLabel.textAlignment = NSTextAlignmentRight;
    allStatsLabel.text = nil;
    allStatsLabel.font = [UIFont systemFontOfSize:STATS_FONT_SIZE];
    allStatsLabel.adjustsFontSizeToFitWidth = YES;

    executeTableVC.tableView.tableFooterView = allStatsLabel;

    availableTableVC.tableView.tag = TransformTable;
    availableTableVC.tableView.rowHeight = TABLE_ENTRY_H;
    availableTableVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    availableTableVC.tableView.delegate = self;
    availableTableVC.tableView.dataSource = self;
    availableTableVC.tableView.showsVerticalScrollIndicator = YES;
    availableTableVC.title = @"Transforms";

    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(didPressVideo:)];
    press.minimumPressDuration = 1.0;
    [transformView addGestureRecognizer:press];

    // save image to photos
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didSwipeVideoLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [transformView addGestureRecognizer:swipeLeft];
    
    // save screen to photos
    UISwipeGestureRecognizer *twoSwipeLeft = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didTwoSwipeVideoLeft:)];
    twoSwipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    twoSwipeLeft.numberOfTouchesRequired = 2;
    [transformView addGestureRecognizer:twoSwipeLeft];

    // undo
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didSwipeVideoRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [transformView addGestureRecognizer:swipeRight];


    [self adjustButtons];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) adjustButtons {
    trashButton.enabled = transforms.sequence.count > 0;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
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
    [super viewWillDisappear:animated];
    if (currentSource && ISCAMERA(currentSource.sourceType)) {
        [cameraController stopCamera];
        capturing = NO;
    }
}

#define SEP 10  // between views
#define INSET 3 // from screen edges
#define MIN_TRANS_TABLE_W 275

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // set up new source, if needed
    if (nextSource) {
        if (currentSource && ISCAMERA(currentSource.sourceType)) {
            [cameraController stopCamera];
            capturing = NO;
        }
        currentSource = nextSource;
        nextSource = nil;
    }
    
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController selectCamera:currentSource.sourceType];
        [cameraController setupSessionForCurrentDeviceOrientation];
        if (IS_3D_CAMERA(currentSource.sourceType)) {
            [transforms selectDepthTransform:depthTransformIndex];
        } else {
            [transforms selectDepthTransform:NO_DEPTH_TRANSFORM];
        }
    } else
        [transforms selectDepthTransform:NO_DEPTH_TRANSFORM];

    CGRect f = self.view.frame;
    containerView.frame = f;

    imageOrientation = [self imageOrientationForDeviceOrientation];
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    BOOL isPortrait = UIDeviceOrientationIsPortrait(deviceOrientation);
    NSLog(@" **** view frame: %.0f x %.0f", self.view.frame.size.width, self.view.frame.size.height);
    NSLog(@"    orientation: (%d)  %@",
          UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]),
          isPortrait ? @"Portrait" : @"Landscape");

    // the image display starts on the upper left of the screen.  Its width
    // depends on device and orientation, and its height depends on the aspect
    // ratio of the source.
    // how we set these sizes depends on the "fullImage" flag, which insists that
    // we gather and process the largest image we can.
    
    CGSize sourceSize;
    CGSize processingSize;
    CGSize displaySize;
    
    displaySize.width = containerView.frame.size.width;
    if (isPortrait) {
        displaySize.width = containerView.frame.size.width;
        displaySize.height = containerView.frame.size.height -
            MIN_ACTIVE_TABLE_H - MIN_TRANSFORM_TABLE_H - 2*SEP;
    } else {
        displaySize.width -= TRANSFORM_LIST_W;
        displaySize.height = containerView.frame.size.height;   // maximum display window height
    }
  
    f.origin = CGPointZero;
    f.size = displaySize;
    transformView.frame = f;
    
    // the image size we are processing gives the display size.
    if (ISCAMERA(currentSource.sourceType)) {
        if (fullImage)
            sourceSize = CGSizeZero;    // obtain maximum available camera size
        else
            sourceSize = displaySize;   // we will learn what fits in the given width
        NSLog(@"sourceSize is %.0f x %.0f", sourceSize.width, sourceSize.height);
        processingSize = [cameraController setupCameraForSize:sourceSize
                                              displayMode:displayMode];
    } else {
        processingSize = currentSource.imageSize;
        NSLog(@"sourceSize is %.0f x %.0f", processingSize.width, processingSize.height);
    }
    
    // The transforms operate on processingSize images.  What size the height of the display,
    // and how does the processed image fit in?  Scaling is ok.
    
    NSLog(@"processingSize is %.0f x %.0f", processingSize.width, processingSize.height);
    [transforms setTransformSize:processingSize];
    
    // We now know the size at the end of transforming.  This needs to fit into displaySize,
    // with appropriate positioning.  The display area may have its height reduced.
    // XXX this code can be simpler.
    
    float xScale = displaySize.width / processingSize.width;;
    float yScale = displaySize.height / processingSize.height;
    transforms.finalScale = MIN(xScale, yScale);
    f.size = CGSizeMake(processingSize.width * transforms.finalScale, processingSize.height * transforms.finalScale);
    if (xScale > yScale) // center the image
        f.origin = CGPointMake((displaySize.width - f.size.width)/2.0, 0);
    else
        f.origin = CGPointZero;
    transformView.frame = f;

    // now position the two tables.
    
#define EXEC_FRAC   (0.3)
    switch (UIDevice.currentDevice.userInterfaceIdiom) {
        case UIUserInterfaceIdiomPhone:
            if (isPortrait) {       // image on top, execute and available stacked below
                f.origin = CGPointMake(0, BELOW(f) + SEP);
                f.size.width = containerView.frame.size.width;
                f.size.height = EXEC_FRAC*(containerView.frame.size.height - f.origin.y);
                executeNavVC.view.frame = f;

                f.origin.y = BELOW(f) + SEP;
                f.size.height = containerView.frame.size.height - f.origin.y;
                availableNavVC.view.frame = f;
            } else {    // image on the left, execute and available stacked on the right
                f.origin = CGPointMake(RIGHT(transformView.frame) + SEP, 0);
                f.size.width = containerView.frame.size.width - f.origin.x - SEP;
                f.size.height = EXEC_FRAC*containerView.frame.size.height;
                executeNavVC.view.frame = f;
                
                f.origin.y += f.size.height + SEP;
                f.size.height = containerView.frame.size.height - f.origin.y;
                availableNavVC.view.frame = f;
            }
            break;
        case UIUserInterfaceIdiomPad:
            if (isPortrait) {       // image on the top, execute and avail side-by-side on the bottom
                f.origin = CGPointMake(0, BELOW(f) + SEP);
                f.size.width = containerView.frame.size.width/2 - SEP/2;
                f.size.height = containerView.frame.size.height - f.origin.y;
                executeNavVC.view.frame = f;

                f.origin.x += f.size.width + SEP;
                availableNavVC.view.frame = f;
            } else {    // image in upper left, avail on the whole right side, execute underneath
                f.origin = CGPointMake(RIGHT(transformView.frame) + SEP, 0);
                f.size.width = containerView.frame.size.width - f.origin.x - SEP;
                f.size.height = containerView.frame.size.height;
                availableNavVC.view.frame = f;

                f.origin = CGPointMake(0, BELOW(transformView.frame));
                f.size.width = availableNavVC.view.frame.origin.x - SEP;
                f.size.height = containerView.frame.size.height - f.origin.y;
                executeNavVC.view.frame = f;
            }
            break;
       default:    // one of the other Apple devices
            NSLog(@"***** Unplanned device: %ld", (long)UIDevice.currentDevice.userInterfaceIdiom);
            return;
    }

    f = executeNavVC.view.frame;
    f.origin.x = 0;
    f.origin.y = executeNavVC.navigationBar.frame.size.height;
    f.size.height = executeNavVC.navigationBar.frame.size.height - f.origin.y;
    executeTableVC.view.frame = f;
    
    executeTableVC.tableView.tableFooterView = allStatsLabel;
    SET_VIEW_X(allStatsLabel, f.size.width - allStatsLabel.frame.size.width - SEP);

    f = availableNavVC.view.frame;
    f.origin.x = 0;
    f.origin.y = availableNavVC.navigationBar.frame.size.height;
    f.size.height = availableNavVC.navigationBar.frame.size.height - f.origin.y;
    availableTableVC.view.frame = f;
    
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController startCamera];
    } else {
        [self transformCurrentImage];
    }
    
    [availableTableVC.tableView reloadData];

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
    // not yet  [self.navigationController setToolbarHidden:!isHidden animated:YES];
}

// XXXXX stub

- (IBAction) didFreezeVideo:(UIBarButtonItem *)recognizer {
    NSLog(@"video touched");
    if ([cameraController isCameraOn]) {
        [cameraController stopCamera];
    } else {
        [cameraController startCamera];
    }
    capturing = !capturing;
}

- (IBAction) doSave:(UIBarButtonItem *)barButton {
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

- (void) transformCurrentImage {
    if (ISCAMERA(currentSource.sourceType)) // cameras don't have a current image, do they?
           return;
    UIImage *currentImage = [UIImage imageWithContentsOfFile:currentSource.imagePath];
    assert(currentImage);
    [self doTransformsOn:currentImage];
}

- (void) useImage:(UIImage *)image {
    NSLog(@"use image");
    [cameraController stopCamera];
    
    [self adjustButtons];
    
    UIImage *transformed = [transforms executeTransformsWithImage:image];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->transformView.image = transformed;
        [self->transformView setNeedsDisplay];
    });
}

- (void) updateThumb: (UIImage *)image {
    return; // no live source buttons
#ifdef NOTNOW
    if (currentSource && ISCAMERA(currentSource.sourceType)) {
        //UIButton *currentButton = currentSource.button;
        
        UIImage *buttonImage = [self fitImage:image toSize:currentButton.frame.size centered:NO];
        if (!buttonImage)
            return;
        [currentButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
        [currentButton setNeedsDisplay];
    }
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

- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output
     didOutputDepthData:(AVDepthData *)depthData
              timestamp:(CMTime)timestamp
             connection:(AVCaptureConnection *)connection {
    depthCount++;
    if (busy) {
        busyCount++;
        return;
    }
    busy = YES;
    
    UIImage *processedDepthImage = [self imageFromDepthDataBuffer:depthData
                                                orientation:imageOrientation];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateThumb:processedDepthImage];
        [self doTransformsOn:processedDepthImage];
        self->busy = NO;
     });
}

- (void) doTransformsOn:(UIImage *)sourceImage {
    NSDate *transformStart = [NSDate now];
    UIImage *transformed = [self->transforms executeTransformsWithImage:sourceImage];
    NSTimeInterval elapsed = -[transformStart timeIntervalSinceNow];
    self->transformTotalElapsed += elapsed;
    self->transformCount++;
    self->transformView.image = transformed;
    [self->transformView setNeedsDisplay];
}

static Pixel *depthPixelVisImage = 0;    // alloc on the heap, maybe too big for the stack
size_t bufferSize = 0;

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
    if (bufferSize != width * height) {    // put it on the heap.  This doesn't seem to help
        if (bufferSize) {
            free(depthPixelVisImage);
        }
        bufferSize = width * height;
        depthPixelVisImage = (Pixel *)malloc(bufferSize * sizeof(Pixel));
    }
    if (depthImage) {
        if (width * height != bufferSize) {
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
    memcpy(depthImage.buf, capturedDepthBuffer, bufferSize*sizeof(float));
    CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
  
#ifdef NOTDEF
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
#endif
    
    [transforms depthToPixels: depthImage pixels:(Pixel *)depthPixelVisImage];
    size_t bytesPerRow = depthImage.size.width*sizeof(Pixel);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(depthPixelVisImage,
                                                 width, height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little |
                                                    kCGImageAlphaPremultipliedFirst);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation:orientation];
    CGImageRelease(quartzImage);
    CGColorSpaceRelease(colorSpace);
    return image;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;

    if (busy) {
        busyCount++;
        return;
    }
    busy = YES;
    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer
                                             orientation:imageOrientation];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateThumb:capturedImage];
        [self doTransformsOn:capturedImage];
        self->busy = NO;
     });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
       fromConnection:(nonnull AVCaptureConnection *)connection {
    NSLog(@"dropped");
    droppedCount++;
}

- (void)depthDataOutput:(AVCaptureDepthDataOutput *)output
       didDropDepthData:(AVDepthData *)depthData
              timestamp:(CMTime)timestamp
             connection:(AVCaptureConnection *)connection
                 reason:(AVCaptureOutputDataDroppedReason)reason {
    NSLog(@"depth data dropped: %ld", (long)reason);
    droppedCount++;
}

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
                        orientation:(UIImageOrientation) orientation {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"image  orientation %@", width > height ? @"panoramic" : @"portrait");

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
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
            return transforms.sequence.count;
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
            sectionTitle.adjustsFontSizeToFitWidth = YES;
            sectionTitle.textAlignment = NSTextAlignmentLeft;
            sectionTitle.font = [UIFont
                                 systemFontOfSize:SECTION_HEADER_FONT_SIZE
                                 weight:UIFontWeightMedium];
            NSString *name = [transforms.categoryNames objectAtIndex:section];
            sectionTitle.text = [@" " stringByAppendingString:name];
            [sectionHeaderView addSubview:sectionTitle];
            
            f.origin.x = RIGHT(f);
            f.size.width = sectionHeaderView.frame.size.width - f.origin.x;
            UILabel *rowStatus = [[UILabel alloc] initWithFrame:f];
            rowStatus.textAlignment = NSTextAlignmentRight;
            if ([self isCollapsed:name]) {
                NSArray *transformList = [transforms.categoryList objectAtIndex:section];
                rowStatus.text = [NSString stringWithFormat:@"(%lu)  ▼", (unsigned long)transformList.count];
            } else
                rowStatus.text = [NSString stringWithFormat:@"▲"];
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
    UITableViewCell *cell;
    switch (tableView.tag) {
        case TransformTable: {   // Selection table display table list
            NSString *CellIdentifier = @"SelectionCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
            Transform *transform = [transformList objectAtIndex:indexPath.row];
            if (transform.hasParameters)
                cell.textLabel.text = [transform.name stringByAppendingString:@" ~"];
            else
                cell.textLabel.text = transform.name;
            cell.detailTextLabel.text = transform.description;
            cell.indentationLevel = 1;
            cell.indentationWidth = 10;
            if (indexPath.section == DEPTH_TRANSFORM_SECTION) {   // depth transforms
                cell.userInteractionEnabled = transforms.depthTransform != nil;
                cell.selected = transforms.depthTransform && depthTransformIndex == indexPath.row;
                if (cell.selected)
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            break;
        }
        case ActiveTable: {
            NSString *CellIdentifier = @"ListingCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell.contentView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
            
            CGRect f = cell.contentView.frame;
            f.size.width = tableView.frame.size.width;
            f.size.height = cell.frame.size.height;
            cell.contentView.frame = f;
            
            Transform *transform = [transforms.sequence objectAtIndex:indexPath.row];
            f.size.width = MIN_ACTIVE_NAME_W;
            UILabel *label = [[UILabel alloc] initWithFrame:f];
            label.numberOfLines = 0;
            label.font = [UIFont systemFontOfSize:TABLE_ENTRY_FONT_SIZE];
            
            f.size.width = STATS_W;
            f.origin.x = cell.contentView.frame.size.width - f.size.width - SEP;
            UILabel *stepStatsLabel = [[UILabel alloc] initWithFrame:f];
            stepStatsLabel.font = [UIFont systemFontOfSize:STATS_FONT_SIZE];
            stepStatsLabel.adjustsFontSizeToFitWidth = YES;
            stepStatsLabel.tag = EXECUTE_STATS_TAG;
            stepStatsLabel.textAlignment = NSTextAlignmentRight;
            [cell.contentView addSubview:stepStatsLabel];

            if (transform.hasParameters) {
                label.text = [transform.name
                              stringByAppendingString:[NSString
                                                       stringWithFormat:@"  %d  ", transform.value]];
                f.origin.x = RIGHT(label.frame);
                f.size.width = SLIDER_VALUE_W;
                UILabel *minValue = [[UILabel alloc] initWithFrame:f];
                minValue.text = [NSString stringWithFormat:@"%d", transform.low];
                minValue.textAlignment = NSTextAlignmentRight;
                minValue.adjustsFontSizeToFitWidth = YES;
                minValue.font = [UIFont systemFontOfSize:24];
                [cell.contentView addSubview:minValue];
                
                f.origin.x -= SLIDER_VALUE_W + SEP;
                f.size.width = SLIDER_VALUE_W;
                UILabel *maxValue = [[UILabel alloc] initWithFrame:f];
                maxValue.text = [NSString stringWithFormat:@"%d", transform.high];
                maxValue.textAlignment = NSTextAlignmentLeft;
                maxValue.adjustsFontSizeToFitWidth = YES;
                maxValue.font = [UIFont systemFontOfSize:24];
                [cell.contentView addSubview:maxValue];

                f.origin.x = RIGHT(minValue.frame) + SEP;
                f.size.width = maxValue.frame.origin.x - f.origin.x - SEP;
                UISlider *slider = [[UISlider alloc] initWithFrame:f];
                slider.minimumValue = transform.low;
                slider.maximumValue = transform.high;
                slider.value = transform.value;
                slider.continuous = YES;
                slider.tag = indexPath.row;
                [slider addTarget:self
                           action:@selector(moveSlider:)
                 forControlEvents:UIControlEventValueChanged];
                [cell.contentView addSubview:slider];
            } else {
                label.text = transform.name;
            }
            [cell.contentView addSubview:label];
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (tableView.tag) {
        case TransformTable: {
            // for depth selections, just set the depthindex
            if (indexPath.section == DEPTH_TRANSFORM_SECTION) {
                if (!transforms.depthTransform)
                    return; // no depth, no selection
                depthTransformIndex = (int)indexPath.row;
                [transforms selectDepthTransform:depthTransformIndex];
                return;
            }
            // Append a transform to the active list
            NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
            Transform *transform = [transformList objectAtIndex:indexPath.row];
            Transform *thisTransform = [transform copy];
            assert(thisTransform.remapTable == NULL);
            @synchronized (transforms.sequence) {
                [transforms.sequence addObject:thisTransform];
                transforms.sequenceChanged = YES;
            }
            [self.executeTableVC.tableView reloadData];
            [self adjustButtons];
            [self transformCurrentImage];
            break;
        }
        case ActiveTable: {
            break;
        }
    }
}

#ifdef notdef
-(void)tableView:(UITableView *)tableView
didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView)
    [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryNone;
}
#endif

- (IBAction) doRemoveLastTransform {
    @synchronized (transforms.sequence) {
        [transforms.sequence removeLastObject];
        transforms.sequenceChanged = YES;
    }
    [self adjustButtons];
    [executeTableVC.tableView reloadData];
    [self transformCurrentImage];
}

- (IBAction) doRemoveAllTransforms:(UIBarButtonItem *)button {
    @synchronized (transforms.sequence) {
        [transforms.sequence removeAllObjects];
        transforms.sequenceChanged = YES;
    }
    [self adjustButtons];
    [executeTableVC.tableView reloadData];
    [self transformCurrentImage];
}

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

- (void) doTick:(NSTimer *)sender {
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
}

- (IBAction) selectSource:(UISegmentedControl *)sender {
    Cameras newCam = (Cameras)sender.selectedSegmentIndex;
    if (ISCAMERA(newCam)) {
        nextSource = [InputSource sourceForCamera:newCam];
        [self.view setNeedsLayout];
        return;
    }
    [self doSelecFileSource];
}

#define CELLECTION_CELL_ID  @"collectionCell"
#define CELLECTION_HEADER_CELL_ID  @"collectionHeaderCell"

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
    [collectionView registerClass:[UICollectionViewCell class]
       forCellWithReuseIdentifier:CELLECTION_CELL_ID];
    collectionView.backgroundColor = [UIColor whiteColor];
    collectionVC.view = collectionView;
    [collectionView registerClass:[CollectionHeaderView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:CELLECTION_HEADER_CELL_ID];
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
    return 3;
}

static NSString * const sectionTitles[] = {
    [0] = @"    Cameras",
    [1] = @"    Samples",
    [2] = @"    From library",
};

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqual:UICollectionElementKindSectionHeader]) {
        UICollectionReusableView *headerView = [collectionView
                                            dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                            withReuseIdentifier:CELLECTION_HEADER_CELL_ID
                                            forIndexPath:indexPath];
        UILabel *sectionTitle = [headerView viewWithTag:SECTION_TITLE_TAG];
        sectionTitle.text = sectionTitles[indexPath.section];
        return headerView;
    } else {
        NSLog(@"** inconceivable: unexpected collection section type: %@, indexPath %ld,%ld", kind,
              (long)indexPath.section,
              (long)indexPath.row);
        return nil;
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return NCAMERA;
        case 1:
            return inputSources.count - NCAMERA;
        case 2:
            return 0;
    }
    return inputSources.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(SOURCE_CELL_W, SOURCE_CELL_H);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell=[collectionView
                                dequeueReusableCellWithReuseIdentifier:CELLECTION_CELL_ID
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
                       systemFontOfSize:SOURCE_BUTTON_FONT_SIZE
                       weight:UIFontWeightMedium];
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
    nextSource = [self sourceForIndexPath:indexPath];
    [sourcesNavVC dismissViewControllerAnimated:YES completion:nil];
    [self.view setNeedsLayout];
}

- (IBAction) dismissSourceVC:(UIBarButtonItem *)sender {
    [sourcesNavVC dismissViewControllerAnimated:YES
                                     completion:NULL];
}

- (IBAction) moveSlider:(UISlider *)slider {
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

@end
