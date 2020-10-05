//
//  MainVC.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "MainVC.h"
#import "CameraController.h"
#import "Transforms.h"
#import "Defines.h"

#define BUTTON_FONT_SIZE    20
#define STATS_FONT_SIZE     20
#define STATS_W             450

#define SOURCE_THUMB_SIZE   50
#define CONTROL_H   40
#define TRANSFORM_LIST_W    (1194 - 1024)

#define SOURCES_W   SOURCE_THUMB_SIZE

char * _NonnullcategoryLabels[] = {
    "Pixel colors",
    "Area",
    "Geometric",
    "Other",
};

enum {
    SourceSelectTag,
    TransformTag,
    ActiveTag,
} tableTags;


@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   UIView *containerView;

// screen views in containerView
@property (nonatomic, strong)   UIImageView *transformedView;   // final image
@property (nonatomic, strong)   UIView *controlsView;            // controls for current execute transform
@property (nonatomic, strong)   UIScrollView *selectionsView;
@property (nonatomic, strong)   UINavigationController *executeNavVC;       // table of current transforms
@property (nonatomic, strong)   UITableViewController *availableTransformsVC;

// in controlsView
@property (nonatomic, strong)   UISlider *controlSlider;
@property (nonatomic, strong)   UILabel *statsLabel;    // stats are in the execute view

// in execute view
@property (nonatomic, strong)   UITableViewController *executeTableVC;

// in sources view
@property (nonatomic, strong)   UIButton *currentCameraButton;  // or nil if no camera is selected

@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;

@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;

@property (nonatomic, strong)   UIBarButtonItem *undoButton, *trashButton;

@property (assign, atomic)      BOOL capturing;         // camera is on and getting processed
@property (assign)              BOOL busy;              // transforming is busy, don't start a new one
@property (nonatomic, strong)   UIImage *selectedImage;     // or nil if coming from the camera

@end

@implementation MainVC

@synthesize containerView;
@synthesize transformedView;
@synthesize controlsView;
@synthesize selectionsView;
@synthesize executeNavVC;
@synthesize availableTransformsVC;

@synthesize executeTableVC;

@synthesize currentCameraButton;

@synthesize statsLabel;
@synthesize controlSlider;
@synthesize inputSources, currentSource;

@synthesize cameraController;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy;
@synthesize statsTimer, lastTime;
@synthesize transforms;
@synthesize undoButton, trashButton;
@synthesize selectedImage;
@synthesize capturing;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        transformTotalElapsed = 0;
        transformCount = 0;
        busy = NO;
        
        inputSources = [[NSMutableArray alloc] init];

        [self addCameraSource:FrontCamera label:@"Front camera"];
        [self addCameraSource:RearCamera label:@"Rear camera"];
        [self addCameraSource:Front3DCamera label:@"Front 3D camera"];
        [self addCameraSource:Rear3DCamera label:@"Rear 3D camera"];
        [self addFileSource:@"ches-1024.jpeg" label:@"Ches"];
        [self addFileSource:@"PM5644-1920x1080.gif" label:@"Color test pattern"];
        [self addFileSource:@"800px-RCA_Indian_Head_test_pattern.jpg"
                      label:@"RCA test pattern"];
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
        currentSource = [inputSources objectAtIndex:sourceIndex];
    }
    return self;
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

#ifdef OLD
// We create the input selection buttons only once.  We put them in place each time the
// screen has a new layout.

- (void) setupSourceButtons {
    for (int i=0; i<inputSources.count; i++) {
        InputSource *source = [inputSources objectAtIndex:i];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.titleLabel.numberOfLines = 0;
        button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
        
        button.frame = CGRectMake(LATER, LATER, SELECTION_THUMB_SIZE, SELECTION_THUMB_SIZE);
        button.layer.borderWidth = 2.0;
        button.layer.borderColor = [UIColor blackColor].CGColor;
        button.layer.cornerRadius = 6.0;
        
        button.titleLabel.font = [UIFont boldSystemFontOfSize:BUTTON_FONT_SIZE];
        button.showsTouchWhenHighlighted = YES;
        button.tag = i;
        [button addTarget:self action:@selector(doInputSelect:)
            forControlEvents:UIControlEventTouchUpInside];

        switch (i) {
            case FrontCamera:
                [button setTitle:@"Front camera" forState:UIControlStateNormal];
                [button setTitle:@"Front camera (unavailable)" forState:UIControlStateDisabled];
                button.enabled = [cameraController isCameraAvailable:i];
                button.backgroundColor = [UIColor whiteColor];
                break;
            case Front3DCamera:
                [button setTitle:@"Front 3D camera" forState:UIControlStateNormal];
                [button setTitle:@"Front 3D camera (unavailable)" forState:UIControlStateDisabled];
                button.enabled = [cameraController isCameraAvailable:i];
                button.backgroundColor = [UIColor whiteColor];
                break;
            case RearCamera:
                [button setTitle:@"Rear camera" forState:UIControlStateNormal];
                [button setTitle:@"Rear camera (unavailable)" forState:UIControlStateDisabled];
                button.enabled = [cameraController isCameraAvailable:i];
                button.backgroundColor = [UIColor whiteColor];
                break;
            case Rear3DCamera:
                [button setTitle:@"Rear 3D camera" forState:UIControlStateNormal];
                [button setTitle:@"Rear 3D camera (unavailable)" forState:UIControlStateDisabled];
                button.enabled = [cameraController isCameraAvailable:i];
                button.backgroundColor = [UIColor whiteColor];
                break;
            default: {
                UIImage *image = [UIImage imageWithContentsOfFile:source.imagePath];
                UIImage *thumb = [self centerImage:image inSize:button.frame.size];
                if (!thumb)
                    continue;
                [button setTitle:source.label forState:UIControlStateNormal];
                button.backgroundColor = [UIColor whiteColor];
                [button setBackgroundImage:thumb forState:UIControlStateNormal];
                button.enabled = YES;
                currentCameraButton = nil;
            }
        }
        source.button = button;
    }
}
#endif

- (void)viewDidLoad {
    [super viewDidLoad];
    
    containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor greenColor];
    [self.view addSubview:containerView];
    
    transformedView = [[UIImageView alloc] init];
    transformedView.userInteractionEnabled = YES;
    [containerView addSubview:transformedView];

    controlsView = [[UIView alloc] init];
    [containerView addSubview:controlsView];
    
    controlSlider = [[UISlider alloc] init];
    controlSlider.hidden = NO;
    controlSlider.enabled = NO;
    [controlSlider addTarget:self action:@selector(moveControlSlider:)
            forControlEvents:UIControlEventValueChanged];
    [controlsView addSubview:controlSlider];
    
    statsLabel = [[UILabel alloc] init];
    statsLabel.font = [UIFont
                        monospacedSystemFontOfSize:STATS_FONT_SIZE
                        weight:UIFontWeightLight];
    statsLabel.backgroundColor = [UIColor whiteColor];
    statsLabel.adjustsFontSizeToFitWidth = YES;
    [controlsView addSubview:statsLabel];
    
    executeTableVC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    executeNavVC = [[UINavigationController alloc] initWithRootViewController:executeTableVC];
    availableTransformsVC = [[UITableViewController alloc]
                               initWithStyle:UITableViewStylePlain];
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        selectionsView = nil;
        [containerView addSubview:executeNavVC.view];
        [containerView addSubview:availableTransformsVC.view];
    } else {    // we have to put these in a horizontal scroll region on small devices
        selectionsView = [[UIScrollView alloc] init];
        [selectionsView addSubview:executeNavVC.view];
        [selectionsView addSubview:availableTransformsVC.view];
        
        [containerView addSubview:selectionsView];
    }
    
    // execute has a nav bar (with stats) and is a table
    executeTableVC.tableView.tag = ActiveTag;
    executeTableVC.tableView.delegate = self;
    executeTableVC.tableView.dataSource = self;
    executeTableVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    executeTableVC.tableView.showsVerticalScrollIndicator = YES;
    executeTableVC.title = @"Active";
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                   target:self
                                   action:@selector(doEditActiveList:)];
    executeTableVC.navigationItem.rightBarButtonItem = editButton;
    undoButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemUndo
                                   target:self
                                   action:@selector(doRemoveLastTransform)];
    executeTableVC.navigationItem.leftBarButtonItem = undoButton;
    trashButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                   target:self
                                   action:@selector(doRemoveAllTransforms:)];
    UIBarButtonItem *flexSpacer = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                   target:nil
                                   action:nil];
    executeTableVC.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:
                                                      undoButton,
                                                      flexSpacer,
                                                      trashButton,
                                                      nil];

    selectionsView.showsHorizontalScrollIndicator = YES;
    selectionsView.userInteractionEnabled = YES;
    selectionsView.exclusiveTouch = NO;
    selectionsView.bounces = NO;
    selectionsView.delaysContentTouches = YES;
    selectionsView.canCancelContentTouches = YES;
    //selectionsView.delegate = self;
    
    availableTransformsVC.tableView.tag = TransformTag;
    availableTransformsVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    availableTransformsVC.tableView.delegate = self;
    availableTransformsVC.tableView.dataSource = self;
    availableTransformsVC.tableView.showsVerticalScrollIndicator = YES;
    availableTransformsVC.title = @"Transforms";
 
    // touching the transformView
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(didTapVideo:)];
    [transformedView addGestureRecognizer:tap];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(didPressVideo:)];
    press.minimumPressDuration = 1.0;
    [transformedView addGestureRecognizer:press];

    // save image to photos
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didSwipeVideoLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [transformedView addGestureRecognizer:swipeLeft];
    
    // save screen to photos
    UISwipeGestureRecognizer *twoSwipeLeft = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didTwoSwipeVideoLeft:)];
    twoSwipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    twoSwipeLeft.numberOfTouchesRequired = 2;
    [transformedView addGestureRecognizer:twoSwipeLeft];

    // undo
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didSwipeVideoRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [transformedView addGestureRecognizer:swipeRight];

    [self adjustButtons];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) adjustButtons {
    undoButton.enabled = trashButton.enabled = transforms.sequence.count > 0;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"Digital Darkroom";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = NO;
    
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc]
                                      initWithTitle:@"Sources"
                                      style:UIBarButtonItemStylePlain
                                      target:self action:@selector(doSelectSource:)];
    leftBarButton.enabled = YES;
    self.navigationItem.leftBarButtonItem = leftBarButton;

//    self.navigationController.toolbarHidden = YES;
    //self.navigationController.toolbar.opaque = NO;
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
#define MIN_TABLE_W 300

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    BOOL isPortrait = UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]);
    NSLog(@" **** view frame: %.0f x %.0f", self.view.frame.size.width, self.view.frame.size.height);
    NSLog(@"    orientation: (%d)  %@",
          UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]),
          isPortrait ? @"Portrait" : @"Landscape");

    containerView.frame = self.view.frame;

    // if it is narrow, the transform image takes the entire width of the top screen.
    // if not, we have room to put the transform list on the right.
    CGRect f = containerView.frame;
    BOOL narrow = (f.size.width - TRANSFORM_LIST_W) < 1024;
    
    if (!narrow) {
        f.size.width = 1024 - TRANSFORM_LIST_W;
    }
    transformedView.frame = f;
    
    // given the maximum output width, get the best source width for it
    
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController selectCamera:currentSource.sourceType];
        f.size = [cameraController setupCameraForSize:f.size];
    } else {
        f.size = currentSource.imageSize;
    }
    
    NSLog(@" source image size: %.0f x %.0f", f.size.width, f.size.height);
    // the after the last step of the transform, we scale the results to our
    // transform size.  Using f.size, figure out the height of the transformed image.
    CGFloat wScale = transformedView.frame.size.width / f.size.width;
    CGFloat h = f.size.height * wScale;
    SET_VIEW_HEIGHT(transformedView, h);
    NSLog(@" transform target size: %.0f x %.0f", transformedView.frame.size.width, transformedView.frame.size.height);

    cameraController.displaySize = transformedView.frame.size;
    transformedView.backgroundColor = [UIColor orangeColor];
    
    f = transformedView.frame;  // control goes right under the transformed view
    f.origin.y = BELOW(f);
    f.size.height = CONTROL_H;  // kludge
    controlsView.frame = f;
    controlsView.backgroundColor = [UIColor whiteColor];
    
    if (selectionsView) {   // both inputs go into a scroll area
        if (isPortrait) {   // goes under the transform display
            f.origin = CGPointMake(0, BELOW(controlsView.frame));
            f.size.height = containerView.frame.size.height - f.origin.y;
            assert(f.size.height >= 100);
            f.size.width = 222;
        } else {        // goes to the right of the transform display
            f.origin = CGPointMake(RIGHT(controlsView.frame), 0);
            f.size.height = containerView.frame.size.height;
            f.size.width = LATER;
        }
    } else {    // ipad, a place for everyone
        if (isPortrait) {   // all three go below transform view
            // split the area in two, vertically.
            f.origin.x = 0;
            f.origin.y = BELOW(controlsView.frame);
            f.size.height = containerView.frame.size.height - f.origin.y;
            f.size.width = containerView.frame.size.width/2;
            executeNavVC.view.frame = f;
            
            f.origin.x += f.size.width;
            availableTransformsVC.view.frame = f;
        } else {    // put available to the right, and execute
            f.origin.x = RIGHT(transformedView.frame);
            f.size.width = containerView.frame.size.width - f.origin.x;
            f.origin.y = 0;
            f.size.height = containerView.frame.size.height;
            availableTransformsVC.view.frame = f;
            
            f.size.width = f.origin.x;
            f.origin.x = 0;
            f.origin.y = BELOW(controlsView.frame);
            f.size.height = containerView.frame.size.height - f.origin.y;
            executeNavVC.view.frame = f;
        }
        f = executeNavVC.navigationBar.frame;
        f.origin.x = 0;
        f.origin.y = f.size.height;
        f.size.height = executeNavVC.view.frame.size.height - f.origin.y;
        executeTableVC.view.frame = f;
    }
    
    f = controlsView.frame;
    f.origin.x = 0;
    f.origin.y = 0;
    f.size.width /= 2;
    statsLabel.frame = f;
    
    f.origin.x = RIGHT(f) + SEP;
    f.size.width = controlsView.frame.size.width - f.origin.x;
    f.origin.y = 0;
    controlSlider.frame = f;
    
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformedView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;

    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController startSession];
        [cameraController startCamera];
    } else {
        [self useImage:[UIImage imageWithContentsOfFile:currentSource.imagePath]];
    }
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

- (void) updateStatsLabel: (float) fps
               depthPerSec:(float) depthps
            droppedPerSec:(float)dps
               busyPerSec:(float)bps
             transformAve:(double) tams {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->statsLabel.text = [NSString stringWithFormat:@"FPS: %.1f|%.1f  d: %.1f  b: %.1f  ave: %.1fms",
                                 fps, depthps, dps, bps, tams];
        [self->statsLabel setNeedsDisplay];
    });
}

- (IBAction) didTapVideo:(UITapGestureRecognizer *)recognizer {
    NSLog(@"video tapped");
    if (selectedImage) // tapping non-moving image does nothing
        return;
    if ([cameraController isCameraOn]) {
        [cameraController stopCamera];
    } else {
        [cameraController startCamera];
    }
    capturing = !capturing;
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

- (UIImage *)centerImage:(UIImage *)image inSize:(CGSize)size {
    //CGFloat screenScale = [[UIScreen mainScreen] scale];
    
    float xScale = size.width/image.size.width;
    float yScale = size.height/image.size.height;
    float scale = MIN(xScale,yScale);
    
    CGRect scaledRect;
    scaledRect.size.width = scale*image.size.width;
    scaledRect.size.height = scale*image.size.height;
    //NSLog(@"scale is %.2f", scale);
    if (xScale < yScale) {  // slop above and below
        scaledRect.origin.x = 0;
        scaledRect.origin.y = (size.height - scaledRect.size.height)/2.0;
    } else {
        scaledRect.origin.x = (size.width - scaledRect.size.width)/2.0;
        scaledRect.origin.y = 0;
    }
    
    //NSLog(@"scaled image size: %.0fx%.0f", scaledRect.size.width, scaledRect.size.height);

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
    NSLog(@"use image");
    capturing = NO;
    [cameraController stopCamera];
    selectedImage = image;
    
    [self updateThumb:self->selectedImage];
    [self adjustButtons];
    
    UIImage *transformed = [transforms executeTransformsWithImage:image];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->transformedView.image = transformed;
        [self->transformedView setNeedsDisplay];
    });
}

- (void) updateThumb: (UIImage *)image {
    if (currentSource && ISCAMERA(currentSource.sourceType)) {
        UIButton *currentButton = currentSource.button;
        
        UIImage *buttonImage = [self centerImage:image inSize:currentButton.frame.size];
        if (!buttonImage)
            return;
        [currentButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
        [currentButton setNeedsDisplay];
    }
}

+ (UIImageOrientation) imageOrientationForDeviceOrientation {
    UIDeviceOrientation devo = [[UIDevice currentDevice] orientation];
    //NSLog(@"do %ld", (long)devo);
    UIImageOrientation orient;
    switch (devo) {
        case UIDeviceOrientationPortrait:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orient = UIImageOrientationDown;
            break;
        case UIDeviceOrientationLandscapeRight:
            orient = UIImageOrientationUpMirrored;  // fine
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
            orient = UIImageOrientationUp;
    }
#ifdef notdef
    NSLog(@"orient: %ld, %ld, %ld, %ld",
          [[UIDevice currentDevice] orientation],
          [CameraController videoOrientationForDeviceOrientation],
          (long)connection.videoOrientation,
          (long)orient);
#endif
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
    
    UIImageOrientation orient = [MainVC imageOrientationForDeviceOrientation];
    UIImage *capturedImage = [self imageFromDepthDataBuffer:depthData
                                                orientation:orient];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateThumb:capturedImage];
        NSDate *transformStart = [NSDate now];
        UIImage *transformed = [self->transforms executeTransformsWithImage:capturedImage];
        NSTimeInterval elapsed = -[transformStart timeIntervalSinceNow];
        self->transformTotalElapsed += elapsed;
        self->transformCount++;
        self->busy = NO;
        
        self->transformedView.image = transformed;
        [self->transformedView setNeedsDisplay];
    });
}

- (UIImage *) imageFromDepthDataBuffer:(AVDepthData *) depthData
                           orientation:(UIImageOrientation) orientation {
    CVPixelBufferRef pixelBufferRef = depthData.depthDataMap;
    size_t width = CVPixelBufferGetWidth(pixelBufferRef);
    size_t height = CVPixelBufferGetHeight(pixelBufferRef);
    CGRect r = CGRectMake(0, 0, width, height);

    CIContext *ctx = [CIContext contextWithOptions:nil];
    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBufferRef];
    CGImageRef quartzImage = [ctx createCGImage:ciimage fromRect:r];

    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation:orientation];
    CGImageRelease(quartzImage);
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
    UIImageOrientation orient = [MainVC imageOrientationForDeviceOrientation];
    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer
                                             orientation:orient];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateThumb:capturedImage];
        
        NSDate *transformStart = [NSDate now];
        UIImage *transformed = [self->transforms executeTransformsWithImage:capturedImage];
        NSTimeInterval elapsed = -[transformStart timeIntervalSinceNow];
        self->transformTotalElapsed += elapsed;
        self->transformCount++;
        self->busy = NO;
        
        self->transformedView.image = transformed;
        [self->transformedView setNeedsDisplay];
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
        case SourceSelectTag:
            return 1;
        case TransformTag:
            return transforms.categoryNames.count;
        case ActiveTag:
            return 1;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (tableView.tag) {
        case SourceSelectTag:
            return inputSources.count;
        case TransformTag: {
            NSArray *transformList = [transforms.categoryList objectAtIndex:section];
            return transformList.count;
        }
        case ActiveTag:
            return transforms.sequence.count;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (tableView.tag) {
        case TransformTag:
            return [transforms.categoryNames objectAtIndex:section];
        case ActiveTag:
        case SourceSelectTag:
            return @"";
    }
    return @"bogus";
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30;
}

- (BOOL)tableView:(UITableView *)tableView
canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return tableView.tag == ActiveTag;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return tableView.tag == ActiveTag;
}

#define SLIDER_TAG_OFFSET   100

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    
    switch (tableView.tag) {
        case SourceSelectTag: {
            NSString *CellIdentifier = @"SourceCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            
            InputSource *source = [inputSources objectAtIndex:indexPath.row];
            switch (source.sourceType) {
                case FrontCamera:
                    cell.textLabel.text = @"Front camera";
                    cell.userInteractionEnabled = [cameraController isCameraAvailable:source.sourceType];
                    break;
                case Front3DCamera:
                    cell.textLabel.text = @"Front 3D camera";
                    cell.userInteractionEnabled = [cameraController isCameraAvailable:source.sourceType];
                    break;
                case RearCamera:
                    cell.textLabel.text = @"FRear camera";
                    cell.userInteractionEnabled = [cameraController isCameraAvailable:source.sourceType];
                    break;
                case Rear3DCamera:
                    cell.textLabel.text = @"Front 3D camera";
                    cell.userInteractionEnabled = [cameraController isCameraAvailable:source.sourceType];
                    break;
                default: {
                    cell.textLabel.text = source.label;
                    UIImage *image = [UIImage imageWithContentsOfFile:source.imagePath];
                    UIImage *thumb = [self centerImage:image inSize:cell.frame.size];
                    if (thumb)
                        cell.backgroundView = [[UIImageView alloc] initWithImage:thumb];
                }
            }
        }
        case ActiveTag: {
            NSString *CellIdentifier = @"ListingCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            Transform *transform = [transforms.sequence objectAtIndex:indexPath.row];
            cell.textLabel.text = [NSString stringWithFormat:
                                   @"%2ld: %@", indexPath.row+1, transform.name];
            cell.layer.borderWidth = 0;
            cell.tag = 0;
#ifdef brokenloop
            if (indexPath.row == transforms.list.count - 1)
                [tableView scrollToRowAtIndexPath:indexPath
                                 atScrollPosition:UITableViewScrollPositionBottom
                                         animated:YES];
#endif
        }
        case TransformTag: {   // Selection table display table list
            NSString *CellIdentifier = @"SelectionCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
            Transform *transform = [transformList objectAtIndex:indexPath.row];
            cell.textLabel.text = transform.name;
            cell.detailTextLabel.text = transform.description;
            cell.indentationLevel = 1;
            cell.indentationWidth = 10;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.selected = NO;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    switch (tableView.tag) {
        case SourceSelectTag: { // select input
            NSLog(@"input button tapped: %ld", (long)cell.tag);
            InputSource *source = [inputSources objectAtIndex:cell.tag];
            currentSource = source;
            [self.view setNeedsLayout];
            break;
        }
        case ActiveTag: {   // select active step, and turn on slide if appropriate
            NSIndexPath *selectedPath = tableView.indexPathForSelectedRow;
            if (selectedPath) { // deselect previous cell, and disconnect possible slider connection
                UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:selectedPath];
                oldCell.selected = NO;
                [oldCell setNeedsDisplay];
            }
            cell.selected = YES;
            // XXX setup slider if appropriate
            // InputSource *source = [inputSources objectAtIndex:cell.tag];
            [cell setNeedsDisplay];
            break;
        }
        case TransformTag: {   // Append a transform to the active list
            NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
            Transform *transform = [transformList objectAtIndex:indexPath.row];
            Transform *thisTransform = [transform copy];
            assert(thisTransform.remapTable == NULL);
            thisTransform.p = thisTransform.initial;
            @synchronized (transforms.sequence) {
                [transforms.sequence addObject:thisTransform];
                transforms.sequenceChanged = YES;
            }
            [self.executeTableVC.tableView reloadData];
            [self adjustButtons];
        }
    }
}

- (IBAction) doRemoveLastTransform {
    @synchronized (transforms.sequence) {
        [transforms.sequence removeLastObject];
        transforms.sequenceChanged = YES;
    }
    [self adjustButtons];
    [executeTableVC.tableView reloadData];
}

- (IBAction) doRemoveAllTransforms:(UIBarButtonItem *)button {
    @synchronized (transforms.sequence) {
        [transforms.sequence removeAllObjects];
        transforms.sequenceChanged = YES;
    }
    [self adjustButtons];
    [executeTableVC.tableView reloadData];
}

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
            break;
        }
        case UITableViewCellEditingStyleInsert:
            NSLog(@"insert?");
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
    
    [self updateStatsLabel: frameCount/elapsed
                depthPerSec:depthCount/elapsed
             droppedPerSec:droppedCount/elapsed
                busyPerSec:busyCount/elapsed
              transformAve:transformAveTime];
    frameCount = depthCount = droppedCount = busyCount = 0;
    transformCount = transformTotalElapsed = 0;
}

- (IBAction) doSelectSource:(UIBarButtonItem *)sender {
    UITableViewController *sourcesTableVC = [[UITableViewController alloc]
                                   initWithStyle:UITableViewStylePlain];
    CGRect f = containerView.frame;
    f.size.height *= 0.75;
    f.size.width = SOURCES_W;
    sourcesTableVC.tableView.frame = f;
    sourcesTableVC.tableView.tag = SourceSelectTag;
    
    sourcesTableVC.modalPresentationStyle = UIModalPresentationPopover;
    sourcesTableVC.preferredContentSize = f.size;
    
    UIPopoverPresentationController *popvc = sourcesTableVC.popoverPresentationController;
    popvc.sourceRect = CGRectMake(100, 100, 100, 100);
    popvc.delegate = self;
    popvc.sourceView = sourcesTableVC.tableView;
    popvc.barButtonItem = sender;
    [self presentViewController:sourcesTableVC animated:YES completion:nil];
}

- (IBAction) moveControlSlider:(UISlider *)slider {
    if (slider.tag < SLIDER_TAG_OFFSET)
        return;
    int row = (int)slider.tag - SLIDER_TAG_OFFSET;
    Transform *t = [transforms.sequence objectAtIndex:row];
    @synchronized (transforms.sequence) {
        t.p = slider.value;
        NSLog(@"value is %f", slider.value);
        t.pUpdated = YES;
    }
}

@end
