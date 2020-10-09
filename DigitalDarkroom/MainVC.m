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

#define CONTROL_H   45
#define TRANSFORM_LIST_W    280
#define MAX_TRANSFORM_W 1024
#define TABLE_ENTRY_H   40

#define SOURCE_THUMB_W  80
#define SOURCE_THUMB_H  80
#define SOURCE_CELL_W   200
#define SOURCE_BUTTON_FONT_SIZE 24

#define SLIDER_LIMIT_W  20
#define SLIDER_LABEL_W  130

#define SLIDER_AREA_W   200

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
@property (nonatomic, strong)   UIView *transformView;           // area reserved for transform display
@property (nonatomic, strong)   UIImageView *scaledTransformImageView;   // final image, places in transformView
@property (nonatomic, strong)   UIView *controlsView;            // controls for current execute transform
@property (nonatomic, strong)   UINavigationController *executeNavVC;       // table of current transforms
@property (nonatomic, strong)   UINavigationController *availableNavVC;        // available transforms

// in controlsView
@property (nonatomic, strong)   UIView *sliderView;
@property (nonatomic, strong)   UILabel *sliderLabel;
@property (nonatomic, strong)   UILabel *minimumLabel, *maximumLabel;
@property (nonatomic, strong)   UISlider *valueSlider;
@property (assign)              int sliderExecuteIndex;     // -1 if inactive

@property (nonatomic, strong)   UILabel *statsLabel;    // stats are in the execute view

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
@property (nonatomic, strong)   NSDate *lastTime;
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;
@property (assign)              volatile int frameCount, depthCount, droppedCount, busyCount;

@property (nonatomic, strong)   UIBarButtonItem *trashButton;

@property (assign, atomic)      BOOL capturing;         // camera is on and getting processed
@property (assign)              BOOL busy;              // transforming is busy, don't start a new one

@end

@implementation MainVC

@synthesize containerView;
@synthesize scaledTransformImageView;
@synthesize transformView;
@synthesize controlsView;
@synthesize executeNavVC;
@synthesize availableNavVC;

@synthesize executeTableVC;
@synthesize availableTableVC;

@synthesize currentCameraButton;

@synthesize statsLabel;
@synthesize sliderView;
@synthesize sliderLabel;
@synthesize minimumLabel, maximumLabel;
@synthesize valueSlider;
@synthesize sliderExecuteIndex;

@synthesize inputSources, currentSource;
@synthesize nextSource;

@synthesize cameraController;

@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, depthCount, droppedCount, busyCount;
@synthesize busy;
@synthesize statsTimer, lastTime;
@synthesize transforms;
@synthesize trashButton;
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Digital Darkroom";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;
    
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc]
                                      initWithTitle:@"Sources"
                                      style:UIBarButtonItemStylePlain
                                      target:self action:@selector(doSelectSource:)];
    leftBarButton.enabled = YES;
    self.navigationItem.leftBarButtonItem = leftBarButton;

    containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor colorWithRed:0 green:.4 blue:0 alpha:1];
    [self.view addSubview:containerView];
    
    transformView = [[UIImageView alloc] init];
    transformView.userInteractionEnabled = YES;
    [containerView addSubview:transformView];
    scaledTransformImageView = [[UIImageView alloc] init];
    [transformView addSubview:scaledTransformImageView];

    controlsView = [[UIView alloc] init];
    [containerView addSubview:controlsView];
    
    sliderView = [[UIView alloc] init];
    [controlsView addSubview:sliderView];
    
    sliderLabel = [[UILabel alloc] init];
    minimumLabel = [[UILabel alloc] init];
    minimumLabel.textAlignment = NSTextAlignmentRight;
    
    maximumLabel = [[UILabel alloc] init];
    minimumLabel.textAlignment = NSTextAlignmentLeft;
    
    valueSlider = [[UISlider alloc] init];
    valueSlider.hidden = NO;
    valueSlider.enabled = NO;
    [valueSlider addTarget:self action:@selector(moveValueSlider:)
            forControlEvents:UIControlEventValueChanged];
    sliderExecuteIndex = -1;

    [sliderView addSubview:sliderLabel];
    [sliderView addSubview:minimumLabel];
    [sliderView addSubview:maximumLabel];
    [sliderView addSubview:valueSlider];
    
    statsLabel = [[UILabel alloc] init];
    statsLabel.font = [UIFont
                        monospacedSystemFontOfSize:STATS_FONT_SIZE
                        weight:UIFontWeightLight];
    statsLabel.backgroundColor = [UIColor whiteColor];
    statsLabel.adjustsFontSizeToFitWidth = YES;
    [controlsView addSubview:statsLabel];
    
    executeTableVC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    executeNavVC = [[UINavigationController alloc] initWithRootViewController:executeTableVC];
    availableTableVC = [[UITableViewController alloc]
                               initWithStyle:UITableViewStylePlain];
    availableNavVC = [[UINavigationController alloc] initWithRootViewController:availableTableVC];

    [containerView addSubview:executeNavVC.view];
    [containerView addSubview:availableNavVC.view];
    
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
    trashButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                   target:self
                                   action:@selector(doRemoveAllTransforms:)];
    executeTableVC.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:
                                                      trashButton,
                                                      nil];
    

    availableTableVC.tableView.tag = TransformTag;
    availableTableVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    availableTableVC.tableView.delegate = self;
    availableTableVC.tableView.dataSource = self;
    availableTableVC.tableView.showsVerticalScrollIndicator = YES;
    availableTableVC.title = @"Transforms";
 
    // touching the transformView
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(didTapVideo:)];
    [transformView addGestureRecognizer:tap];
    
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
#define MIN_TABLE_W 300

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    BOOL isPortrait = UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]);
    NSLog(@" **** view frame: %.0f x %.0f", self.view.frame.size.width, self.view.frame.size.height);
    NSLog(@"    orientation: (%d)  %@",
          UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]),
          isPortrait ? @"Portrait" : @"Landscape");

    CGRect f = self.view.frame;
    f.origin.y = BELOW(self.navigationController.navigationBar.frame);
    f.size.height = f.size.height - f.origin.y;
    containerView.frame = f;

    // if it is narrow, the transform image takes the entire width of the top screen.
    // if not, we have room to put the transform list on the right.
    if (isPortrait) {   // both tables are below
        ;
    } else {    // one table is on top of the other on the right
        f.size.width -= TRANSFORM_LIST_W;
        if (f.size.width > MAX_TRANSFORM_W)
            f.size.width = MAX_TRANSFORM_W;
    }
    f.origin.y = 0; // in the containerView
    f.size.height -= CONTROL_H;
    transformView.frame = f;
    
    if (nextSource)
        [self newCurrentSource];
    
    CGSize sourceSize;   // the image size we are processing gives the transformed size.  we need to scale that.
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController selectCamera:currentSource.sourceType];
        sourceSize = [cameraController setupCameraForSize:transformView.frame.size];
    } else {
        sourceSize = currentSource.imageSize;
    }
    
    transformView.backgroundColor = [UIColor systemPinkColor];
    
    transforms.finalScale = [self scaleToFitSize:sourceSize toSize:transformView.frame.size];
    CGRect scaledRect;
    scaledRect.size = [self fitSize:sourceSize toSize:transformView.frame.size];
    // put the scaled image at the top of the transform view area, centered.
    CGFloat x = (transformView.frame.size.width - scaledRect.size.width)/2;
    scaledRect.origin = CGPointMake(x, 0);
    scaledTransformImageView.frame = scaledRect;
    
    NSLog(@" source image size: %.0f x %.0f", sourceSize.width, sourceSize.height);
    NSLog(@" transform target size: %.0f x %.0f", scaledRect.size.width, scaledRect.size.height);

    transformView.backgroundColor = [UIColor orangeColor];
    
    f = scaledTransformImageView.frame;  // control goes right under the transformed view
    f.origin.y = BELOW(f);
    f.size.height = CONTROL_H;  // kludge
    controlsView.frame = f;
    controlsView.backgroundColor = [UIColor whiteColor];
    
    if (isPortrait) {   // both go under the transform view
        f.origin = CGPointMake(0, BELOW(controlsView.frame));
        f.size.height = containerView.frame.size.height - f.origin.y;
        assert(f.size.height >= 100);
        f.size.width = containerView.frame.size.width/2;
        executeNavVC.view.frame = f;
        
        f.origin.x = RIGHT(f);
        availableNavVC.view.frame = f;
    } else {        // available and execute goes right of display
        f.origin = CGPointMake(RIGHT(controlsView.frame), 0);
        f.size.height = containerView.frame.size.height*0.3;
        f.size.width = containerView.frame.size.width - f.origin.x;
        executeNavVC.view.frame = f;

        f.origin.y = BELOW(f);
        f.size.height = containerView.frame.size.height - f.origin.y;
        availableNavVC.view.frame = f;
    }
    f = executeNavVC.navigationBar.frame;
    f.origin.x = 0;
    f.origin.y = f.size.height;
    f.size.height = executeNavVC.view.frame.size.height - f.origin.y;
    executeTableVC.view.frame = f;

    f = controlsView.frame;
    f.origin.x = 0;
    f.origin.y = 0;
    f.size.width /= 2;
    statsLabel.frame = f;
    
    f.origin.x = RIGHT(f) + SEP;
    f.size.width = controlsView.frame.size.width - f.origin.x;
    f.origin.y = 0;
    sliderView.frame = f;
    
    f.origin.x = 0;
    f.size.width = SLIDER_LABEL_W;
    sliderLabel.frame = f;
    
    f.origin.x = RIGHT(f);
    f.size.width = SLIDER_LIMIT_W;
    minimumLabel.frame = f;
    f.origin.x = sliderView.frame.size.width - f.size.width;
    maximumLabel.frame = f;
    
    f.origin.x = RIGHT(minimumLabel.frame);
    f.size.width = maximumLabel.frame.origin.x - f.origin.x;
    valueSlider.frame = f;
    
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;

    if (nextSource) {
        [self initiateSource];
        nextSource = nil;
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
#ifdef OLD
        self->statsLabel.text = [NSString stringWithFormat:@"FPS: %.1f|%.1f  d: %.1f  b: %.1f  ave: %.1fms",
                                 fps, depthps, dps, bps, tams];
#endif
        if (fps) {
            self->statsLabel.text = [NSString stringWithFormat:@"FPS: %.1f|%.1f  ave: %.1fms",
                                     fps, depthps, tams];
            [self->statsLabel setNeedsDisplay];
        }
    });
}

- (IBAction) didTapVideo:(UITapGestureRecognizer *)recognizer {
    NSLog(@"video tapped");
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
    if (!centered) {
        scaledRect.origin.x = (size.width - scaledRect.size.width)/2.0;
        scaledRect.origin.y = (size.height - scaledRect.size.height)/2.0;
    }
    
    //NSLog(@"scaled image size: %.0fx%.0f", scaledRect.size.width, scaledRect.size.height);

    UIGraphicsBeginImageContextWithOptions(scaledRect.size, NO, 0.0);
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
        self->scaledTransformImageView.image = transformed;
        [self->scaledTransformImageView setNeedsDisplay];
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
        [self doTransformsOn:capturedImage];
        self->busy = NO;
     });
}

- (void) doTransformsOn:(UIImage *)sourceImage {
    NSDate *transformStart = [NSDate now];
    UIImage *transformed = [self->transforms executeTransformsWithImage:sourceImage];
    NSTimeInterval elapsed = -[transformStart timeIntervalSinceNow];
    self->transformTotalElapsed += elapsed;
    self->transformCount++;
    self->scaledTransformImageView.image = transformed;
    [self->scaledTransformImageView setNeedsDisplay];
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
        case TransformTag:
            return transforms.categoryNames.count;
        case SourceSelectTag:
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
            return @"";
        case SourceSelectTag:
            return @"Sources";
    }
    return @"bogus";
}

#ifdef notdef
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    switch (tableView.tag) {
        case ActiveTag:
        case TransformTag:
            return TABLE_ENTRY_H;
        case SourceSelectTag:
            return SOURCE_THUMB_H;
    }
    return 30;
}
#endif

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 50;
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
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            size_t sourceIndex = indexPath.row;
            cell.tag = sourceIndex;
            
            UILabel *thumbLabel = [[UILabel alloc] init];
            UIImageView *thumbImageView = [[UIImageView alloc] init];
            thumbImageView.layer.borderWidth = 1.0;
            thumbImageView.layer.borderColor = [UIColor blackColor].CGColor;
            thumbImageView.layer.cornerRadius = 4.0;
            
            CGRect f = cell.contentView.frame;  // thumb goes on the right
            f.origin.x = 0; // XXXX for demo purposes
            f.origin.y = 0;
            f.size.height = SOURCE_THUMB_H;
            f.size.width = SOURCE_THUMB_W; //f.size.width - SOURCE_THUMB_W - INSET;
            //f.size = CGSizeMake(SOURCE_THUMB_W, SOURCE_THUMB_H);
            NSLog(@"h=%.0d  %.0f", SOURCE_THUMB_H, cell.frame.size.height);
            thumbImageView.frame = f;
            thumbImageView.backgroundColor = [UIColor yellowColor];
            [cell.contentView addSubview:thumbImageView];
            
            //f.size.width = f.origin.x - SEP;
            f.origin.x += f.size.width;
            thumbLabel.frame = f;
            thumbLabel.lineBreakMode = NSLineBreakByWordWrapping;
            thumbLabel.numberOfLines = 0;
            thumbLabel.adjustsFontSizeToFitWidth = YES;
            thumbLabel.textAlignment = NSTextAlignmentLeft;
            thumbLabel.font = [UIFont
                               systemFontOfSize:SOURCE_BUTTON_FONT_SIZE
                               weight:UIFontWeightMedium];
            thumbLabel.textColor = [UIColor blackColor];
            thumbLabel.backgroundColor = [UIColor orangeColor];
            [cell.contentView addSubview:thumbLabel];
            cell.contentView.backgroundColor = [UIColor purpleColor];
            
            InputSource *source = [inputSources objectAtIndex:sourceIndex];
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
            break;
        }
        case ActiveTag: {
            NSString *CellIdentifier = @"ListingCell";
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            Transform *transform = [transforms.sequence objectAtIndex:indexPath.row];
            NSString *name;
            if (transform.initial != UNINITIALIZED_P)
               name = [transform.name stringByAppendingString:@" ~"];
            else
                name = transform.name;
            cell.textLabel.text = [NSString stringWithFormat:
                                   @"%2ld: %@", indexPath.row+1, name];
            cell.layer.borderWidth = 0;
#ifdef brokenloop
            if (indexPath.row == transforms.list.count - 1)
                [tableView scrollToRowAtIndexPath:indexPath
                                 atScrollPosition:UITableViewScrollPositionBottom
                                         animated:YES];
#endif
            break;
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
            if (transform.initial != UNINITIALIZED_P)
                cell.textLabel.text = [transform.name stringByAppendingString:@" ~"];
            else
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

- (void) newCurrentSource {
    if (currentSource && ISCAMERA(currentSource.sourceType)) {
        [cameraController stopCamera];
        capturing = NO;
    }
    currentSource = nextSource;
}

- (void) initiateSource {
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController selectCamera:currentSource.sourceType];
        [cameraController startSession];
        [cameraController startCamera];
        capturing = YES;
    } else {
        [self transformCurrentImage];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    switch (tableView.tag) {
        case SourceSelectTag: { // select input
            NSLog(@"input button tapped: %ld", (long)cell.tag);
            InputSource *source = [inputSources objectAtIndex:cell.tag];
            nextSource = source;
            [self.view setNeedsLayout];
            break;
        }
        case ActiveTag: {   // select active step and turn on slide if appropriate
            NSIndexPath *selectedPath = tableView.indexPathForSelectedRow;
            if (selectedPath) { // deselect previous cell, and disconnect possible slider connection
                UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:selectedPath];
                oldCell.selected = NO;
                [oldCell setNeedsDisplay];
                [self disableSlider];
            }
            
            Transform *transform = [transforms.sequence objectAtIndex:indexPath.row];
            if (transform.p != UNINITIALIZED_P) {
                cell.selected = YES;
                [self setSliderTo:(int)indexPath.row];
                [cell setNeedsDisplay];
                //[self transformCurrentImage];
            }
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
            [self transformCurrentImage];
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
    f.size.width = SOURCE_CELL_W;
    sourcesTableVC.tableView.frame = f;
    sourcesTableVC.preferredContentSize = CGSizeMake(400, 400); // f.size;
    sourcesTableVC.tableView.tag = SourceSelectTag;
    sourcesTableVC.tableView.delegate = self;
    sourcesTableVC.tableView.dataSource = self;
    sourcesTableVC.tableView.rowHeight = SOURCE_THUMB_H + 4;
    sourcesTableVC.tableView.estimatedRowHeight = SOURCE_THUMB_H + 4;
    sourcesTableVC.modalPresentationStyle = UIModalPresentationPopover;
    sourcesTableVC.preferredContentSize = f.size;
    
    UIPopoverPresentationController *popvc = sourcesTableVC.popoverPresentationController;
    popvc.sourceRect = CGRectMake(0, 0, 300, 300);
    popvc.delegate = self;
    //popvc.sourceView = sourcesTableVC.tableView;
    popvc.barButtonItem = sender;
    [self presentViewController:sourcesTableVC animated:YES completion:nil];
}

- (void) disableSlider {
    valueSlider.enabled = NO;
    valueSlider.hidden = YES;
    sliderLabel.hidden = YES;
    minimumLabel.hidden = YES;
    maximumLabel.hidden = YES;
    sliderExecuteIndex = -1;
    [valueSlider setNeedsDisplay];
}

- (void) setSliderTo:(int)executeTableIndex {
    valueSlider.enabled = YES;
    sliderExecuteIndex = executeTableIndex;
    Transform *transform;
    @synchronized (transforms.sequence) {
        transform = [transforms.sequence objectAtIndex:executeTableIndex];
    }
    valueSlider.minimumValue = transform.low;
    valueSlider.maximumValue = transform.high;
    valueSlider.value = transform.p;
    valueSlider.hidden = NO;
    [valueSlider setNeedsDisplay];
    
    sliderLabel.text = transform.name;
    sliderLabel.hidden = NO;
    [sliderLabel setNeedsDisplay];
    
    minimumLabel.text = [NSString stringWithFormat:@"%d", (int)valueSlider.minimumValue];
    minimumLabel.hidden = NO;
    [minimumLabel setNeedsDisplay];
    
    maximumLabel.text = [NSString stringWithFormat:@"%d", (int)valueSlider.maximumValue];
    maximumLabel.hidden = NO;
    [maximumLabel setNeedsDisplay];
}

- (IBAction) moveValueSlider:(UISlider *)slider {
    @synchronized (transforms.sequence) {
        Transform *transform = [transforms.sequence objectAtIndex:sliderExecuteIndex];
        transform.p = slider.value;
        transform.pUpdated = YES;
    }
    [self transformCurrentImage];   // XXX if video capturing is off, we still need to update.  check
}

@end

// delete, move, or remove active?  check slider
// need indicator for things that can vary

