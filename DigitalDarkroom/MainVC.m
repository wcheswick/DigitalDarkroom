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

#define SELECTION_THUMB_H   100

#define TRANSTEXT_H 25

char * _NonnullcategoryLabels[] = {
    "Pixel colors",
    "Area",
    "Geometric",
    "Other",
};

enum {
    TransformTag,
    ActiveTag,
} tableTags;


@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   UIView *containerView;

@property (nonatomic, strong)   UIView *inputView;
@property (nonatomic, strong)   UIImageView *inputThumb;
@property (nonatomic, strong)   UIImageView *cameraThumbView;

@property (nonatomic, strong)   UIView *previewView;

@property (nonatomic, strong)   UIScrollView *selectInputScroll;
@property (nonatomic, strong)   UIView *selectInputButtonsView;
@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (nonatomic, strong)   InputSource *currentSource;
@property (nonatomic, strong)   UIButton *frontButton, *rearButton;

@property (nonatomic, strong)   UIView *outputView;
@property (nonatomic, strong)   UIImageView *transformedView;
@property (nonatomic, strong)   UILabel *statsLabel;
@property (nonatomic, strong)   NSTimer *statsTimer;
@property (nonatomic, strong)   NSDate *lastTime;

@property (nonatomic, strong)   UINavigationController *transformsNavVC;
@property (nonatomic, strong)   UITableViewController *transformsVC;
@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   UITableViewController *activeListVC;
@property (nonatomic, strong)   UIBarButtonItem *undoButton, *trashButton;

@property (assign)              volatile int frameCount, droppedCount, busyCount;
@property (assign)              float cps, dps, mps;

@property (nonatomic, strong)   UIBarButtonItem *addButton;

@property (assign, atomic)      BOOL capturing;
@property (nonatomic, strong)   UIImage *selectedImage;     // or nil if coming from the camera

@end

@implementation MainVC

@synthesize containerView;
@synthesize inputView, inputThumb, cameraThumbView;
@synthesize previewView;
@synthesize outputView, transformedView, statsLabel;
@synthesize selectInputScroll, selectInputButtonsView;
@synthesize inputSources, currentSource;
@synthesize frontButton, rearButton;

@synthesize cameraController;
@synthesize transformsNavVC;
@synthesize transformsVC, activeListVC;
@synthesize frameCount, droppedCount, busyCount, cps, dps, mps;
@synthesize statsTimer, lastTime;
@synthesize transforms;
@synthesize addButton;
@synthesize undoButton, trashButton;
@synthesize selectedImage;
@synthesize capturing;

- (id) init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        inputSources = [[NSMutableArray alloc] init];
        
        [self addCameraSource:FrontCamera label:@"Front camera"];
        [self addCameraSource:RearCamera label:@"Rear camera"];
        [self addFileSource:@"PM5644-1920x1080.gif" label:@"Color test pattern"];
        [self addFileSource:@"ches.jpg" label:@"Ches"];
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
    }
    currentSource = nil;
    frontButton = rearButton = nil;
    cameraThumbView = nil;
    
    cameraController = [[CameraController alloc] init];
    cameraController.delegate = self;
    
    return self;
}

- (void) addCameraSource:(cameras)c label:(NSString *)l {
    InputSource *is = [[InputSource alloc] init];
    is.sourceType = c;
    is.label = l;
    [inputSources addObject:is];
}

- (void) addFileSource:(NSString *)fn label:(NSString *)l {
    InputSource *is = [[InputSource alloc] init];
    is.sourceType = NotACamera;
    is.label = l;
    
    NSString *file = [@"images/" stringByAppendingPathComponent:fn];
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@""];
    if (!imagePath) {
        is.label = [fn stringByAppendingString:@" missing"];
        NSLog(@"**** Image not found: %@", fn);
    } else {
        is.image = [UIImage imageWithContentsOfFile:imagePath];
        if (!is.image)
            is.label = [fn stringByAppendingString:@" Missing"];
    }
    [inputSources addObject:is];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    containerView = [[UIView alloc] init];
    [self.view addSubview:containerView];
    
    outputView = [[UIView alloc] init];
    transformedView = [[UIImageView alloc] init];
    [outputView addSubview:transformedView];
    
    statsLabel= [[UILabel alloc] init];
    statsLabel.backgroundColor = [UIColor whiteColor];
    [outputView addSubview:statsLabel];
    
    outputView.userInteractionEnabled = YES;
    outputView.backgroundColor = [UIColor whiteColor];
    [containerView addSubview:outputView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(didTapVideo:)];
    [outputView addGestureRecognizer:tap];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(didPressVideo:)];
    press.minimumPressDuration = 1.0;
    [outputView addGestureRecognizer:press];

    // save image to photos
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didSwipeVideoLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [outputView addGestureRecognizer:swipeLeft];
    
    // save screen to photos
    UISwipeGestureRecognizer *twoSwipeLeft = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didTwoSwipeVideoLeft:)];
    twoSwipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    twoSwipeLeft.numberOfTouchesRequired = 2;
    [outputView addGestureRecognizer:twoSwipeLeft];

    // undo
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:self action:@selector(didSwipeVideoRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [outputView addGestureRecognizer:swipeRight];

#ifdef OLD
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc]
                                      initWithTitle:@"Source"
                                      style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(doSelectInput:)];
    self.navigationItem.leftBarButtonItem = leftBarButton;
#endif
    
    selectInputScroll = [[UIScrollView alloc]
                       initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    selectInputScroll.delegate = self;
//    selectInputScroll.contentSize =
    selectInputScroll.pagingEnabled = NO;
    selectInputScroll.showsHorizontalScrollIndicator = YES;
    selectInputScroll.userInteractionEnabled = YES;
    selectInputScroll.exclusiveTouch = NO;
    selectInputScroll.bounces = NO;
    selectInputScroll.delaysContentTouches = YES;
    selectInputScroll.canCancelContentTouches = YES;
    selectInputScroll.delegate = self;
    
    selectInputButtonsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [selectInputScroll addSubview:selectInputButtonsView];
    [containerView addSubview:selectInputScroll];

    inputView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    inputView.backgroundColor = [UIColor whiteColor];
    
    inputThumb = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [inputView addSubview: inputThumb];
    
    activeListVC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    activeListVC.tableView.frame = CGRectMake(0, 0,
                                        activeListVC.navigationController.navigationBar.frame.size.height, 10);
    activeListVC.tableView.tag = ActiveTag;
    activeListVC.tableView.delegate = self;
    activeListVC.tableView.dataSource = self;
    activeListVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    activeListVC.tableView.showsVerticalScrollIndicator = YES;
    activeListVC.title = @"Active";
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                   target:self
                                   action:@selector(doEditActiveList:)];
    activeListVC.navigationItem.rightBarButtonItem = editButton;
    undoButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemUndo
                                   target:self
                                   action:@selector(doRemoveLastTransform)];
    activeListVC.navigationItem.leftBarButtonItem = undoButton;
    trashButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                   target:self
                                   action:@selector(doRemoveAllTransforms:)];
    UIBarButtonItem *flexSpacer = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                   target:nil
                                   action:nil];
    activeListVC.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects:
                                                      undoButton,
                                                      flexSpacer,
                                                      trashButton,
                                                      nil];
    [containerView addSubview:activeListVC.view];
    [self adjustButtons];
    
    transformsVC = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    transformsVC.tableView.frame = CGRectMake(0, 0,
                                             transformsVC.navigationController.navigationBar.frame.size.height, 10);
    transformsVC.tableView.tag = TransformTag;
    transformsVC.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    transformsVC.tableView.delegate = self;
    transformsVC.tableView.dataSource = self;
    transformsVC.tableView.showsVerticalScrollIndicator = YES;

    transformsVC.title = @"Transforms";
    transformsNavVC = [[UINavigationController alloc] initWithRootViewController:transformsVC];
    [transformsNavVC.view addSubview:transformsVC.tableView];
    
    [containerView addSubview:transformsNavVC.view];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) adjustButtons {
    undoButton.enabled = trashButton.enabled = transforms.masterTransformList.count > 0;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"Digital Darkroom";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;
//    self.navigationController.toolbarHidden = YES;
    //self.navigationController.toolbar.opaque = NO;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    frameCount = droppedCount = busyCount = 0;
    [self.view setNeedsDisplay];
    transforms.outputSize = transformedView.frame.size;
    
#define TICK_INTERVAL   1.0
    statsTimer = [NSTimer scheduledTimerWithTimeInterval:TICK_INTERVAL
                                                target:self
                                              selector:@selector(doTick:)
                                              userInfo:NULL
                                               repeats:YES];
    lastTime = [NSDate now];
}

- (void) doTick:(NSTimer *)sender {
    NSDate *now = [NSDate now];
    NSTimeInterval elapsed = [now timeIntervalSinceDate:lastTime];
    lastTime = now;
    [self updateStatsLabel: frameCount/elapsed
                       droppedPerSec:droppedCount/elapsed
                       busyPerSec:busyCount/elapsed];
    frameCount = droppedCount = busyCount = 0;
}

- (void) setupSource:(InputSource *)newSource {
    if (ISCAMERA(newSource.sourceType) && ! [cameraController cameraAvailable:newSource.sourceType]) {
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle:@"Camera not available"
                                    message:nil
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                                        actionWithTitle:@"Dismiss"
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {}
                                        ];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    if (currentSource && [currentSource.label isEqualToString:newSource.label])
        return;
    
    if (currentSource && ISCAMERA(currentSource.sourceType)) {
        [cameraController stopCamera];
        currentSource.button.highlighted = NO;
        currentSource.button.selected = NO;
        [currentSource.button setBackgroundImage:NULL forState:UIControlStateNormal];
        [currentSource.button setNeedsDisplay];
        capturing = NO;
    }
    
    currentSource = newSource;
    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController selectCamera:currentSource.sourceType];
        transforms.imageOrientation = cameraController.imageOrientation;
        currentSource.button.highlighted = YES;
        capturing = YES;
        [cameraController startCamera];
    } else {
        [self useImage:currentSource.image];
    }
}

- (IBAction) doInputSelect:(UIButton *)button {
    NSLog(@"input button tapped: %ld", (long)button.tag);
    
    InputSource *newSource = [inputSources objectAtIndex:button.tag];
    [self setupSource:newSource];
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

    CGRect f = CGRectMake(INSET,
                          BELOW(self.navigationController.navigationBar.frame),
                          self.view.frame.size.width - 2*INSET,
                          LATER);
    f.size.height = self.view.frame.size.height - f.origin.y - INSET;
    containerView.frame = f;
    
    if (isPortrait) {   // video on the top
#ifdef notdef
        f.size.height /= 2;    // top half only, for now
        f.size = [cameraController cameraVideoSizeFor:f.size];
        f.origin.y = BELOW(self.navigationController.navigationBar.frame) + SEP;
        f.origin.x = (workingFrame.size.width - f.size.width)/2;
        videoView.frame = f;
        
        f.origin.x = 0;
        f.origin.y = BELOW(videoView.frame) + SEP;
        f.size.height = workingFrame.size.height - f.origin.y;
        f.size.width = (workingFrame.size.width - SEP)*0.50;
        activeNavVC.view.frame = f;
        
        f.origin.x += f.size.width + SEP;
        transformsNavVC.view.frame = f;
        
        f.origin.y = activeNavVC.navigationBar.frame.size.height;
        f.size.height -= f.origin.y;
        f.origin.x = 0;
        transformsVC.tableView.frame = f;
        activeListVC.tableView.frame = f;
#endif
    } else {    // video on the left
        CGRect f = containerView.frame;
        
        // top left side
        f.origin = CGPointZero;
        f.size.width = containerView.frame.size.width - SEP - MIN_TABLE_W;  // work on the left side
        outputView.frame = f;   // adjust height in a moment.
        
        // do the right side
        f.origin.x = RIGHT(outputView.frame) + SEP;
        f.size.width = containerView.frame.size.width - f.origin.x;
        f.size.height *= 0.25;
        activeListVC.view.frame = f;

        f.origin.y = BELOW(f);
        f.size.height = containerView.frame.size.height - f.origin.y;
        transformsNavVC.view.frame = f;
        
        f.origin.x = 0;
        f.origin.y = transformsNavVC.navigationController.navigationBar.frame.size.height;
        f.size.height -= f.origin.y;
        transformsVC.tableView.frame = f;

        // now the left side, taking into account the size of camera images, if available

        f.origin = CGPointZero;
        f.size = outputView.frame.size;
        if ([cameraController camerasAvailable] && ISCAMERA(currentSource.sourceType)) {
            [cameraController setupCamerasForCurrentOrientationAndSizeOf:f.size];
            CGSize frontSize = [cameraController captureSizeFor:FrontCamera];
            CGSize rearSize = [cameraController captureSizeFor:RearCamera];
            
            NSLog(@"for desired size %.0fx%.0f, front: %.0fx%.0f, rear: %.0fx%.0f",
                  f.size.width, f.size.height,
                  frontSize.width, frontSize.height,
                  rearSize.width, rearSize.height);

            f.size = (currentSource.sourceType == FrontCamera) ? frontSize : rearSize;
            transformedView.frame = f;

        } else {
            f.size.height = 0.8*f.size.height;
            transformedView.frame = f;
        }
        transforms.outputSize = transformedView.frame.size;
        
        previewView = transformedView;
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformedView.layer;
        cameraController.captureVideoPreviewLayer = previewLayer;

        f.origin.x = 0;
        f.origin.y = BELOW(transformedView.frame) + SEP;
        f.size.height = TRANSTEXT_H;
        f.size.width = transformedView.frame.size.width;
        statsLabel.frame = f;
        statsLabel.font = [UIFont
                            monospacedSystemFontOfSize:TRANSTEXT_H-4
                            weight:UIFontWeightMedium];
        statsLabel.backgroundColor = [UIColor yellowColor];

        transformedView.backgroundColor = [UIColor whiteColor];
        SET_VIEW_HEIGHT(outputView, BELOW(statsLabel.frame));
        
        selectInputScroll.frame = outputView.frame;
        SET_VIEW_Y(selectInputScroll, BELOW(outputView.frame)+SEP);
        
        CGFloat heightLeft = containerView.frame.size.height - selectInputScroll.frame.origin.y;
        CGFloat thumbH = SELECTION_THUMB_H;
        if (thumbH > heightLeft)
            thumbH = heightLeft;
        int thumbsPerColumn = floor(heightLeft / thumbH);
        thumbH = heightLeft / (CGFloat)thumbsPerColumn;
        NSLog(@"thumbs wanted %.0d, got %.0f actual %.0f, %d thumb row(s)",
              SELECTION_THUMB_H, heightLeft, thumbH, thumbsPerColumn);
        f.origin = CGPointZero;
        f.size.height = thumbsPerColumn * thumbH;
        f.size.width = thumbH * floor(inputSources.count + thumbsPerColumn - 1)/thumbsPerColumn;
        selectInputButtonsView.frame = f;
        selectInputScroll.contentSize = f.size;
        SET_VIEW_HEIGHT(selectInputScroll, f.size.height);
        
        for (int i=0; i<inputSources.count; i++) {
            int row = i % thumbsPerColumn;
            int col = i / thumbsPerColumn;
            
            UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
            but.frame = CGRectMake(col*thumbH + 2*col, row*thumbH + 2*row,
                                   thumbH-1, thumbH);
            but.tag = i;
            but.titleLabel.textAlignment = NSTextAlignmentCenter;
            but.titleLabel.numberOfLines = 0;
            but.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
            but.titleLabel.adjustsFontSizeToFitWidth = YES;
            
            but.layer.borderWidth = 2.0;
            but.layer.borderColor = [UIColor blackColor].CGColor;
            but.layer.cornerRadius = 6.0;
            
            InputSource *source = [inputSources objectAtIndex:i];

            switch (i) {
                case FrontCamera:
                    [but setTitle:@"Front camera" forState:UIControlStateNormal];
                    [but setTitle:@"Front camera (unavailable)" forState:UIControlStateDisabled];
                    but.enabled = [cameraController cameraAvailable:i];
                    but.backgroundColor = [UIColor whiteColor];
                    frontButton = but;
                    break;
                case RearCamera:
                    [but setTitle:@"Rear camera" forState:UIControlStateNormal];
                    [but setTitle:@"Rear camera (unavailable)" forState:UIControlStateDisabled];
                    but.enabled = [cameraController cameraAvailable:i];
                    but.backgroundColor = [UIColor whiteColor];
                    rearButton = but;
                    break;
                default: {
                    UIImage *thumb = [self centerImage:source.image inSize:but.frame.size];
                    if (!thumb)
                        continue;
                    [but setTitle:source.label forState:UIControlStateNormal];
                    but.backgroundColor = [UIColor whiteColor];
                    [but setBackgroundImage:thumb forState:UIControlStateNormal];
                }
            }
            but.titleLabel.font = [UIFont boldSystemFontOfSize:20];
            but.showsTouchWhenHighlighted = YES;
            [but addTarget:self action:@selector(doInputSelect:)
                forControlEvents:UIControlEventTouchUpInside];
            [selectInputButtonsView addSubview:but];
            source.button = but;
        }
    }
    
    [transformsNavVC.view setNeedsDisplay];
    [transformsVC.tableView reloadData];    // ... needed
    
    if (!currentSource) {   // simulate button press for starting input source
        InputSource *startSource;
        
        if ([cameraController cameraAvailable:FrontCamera]) {
            startSource = [inputSources objectAtIndex:FrontCamera];
        } else if ([cameraController cameraAvailable:RearCamera]) {
            startSource = [inputSources objectAtIndex:RearCamera];
        } else {    // use first image.
            startSource = [inputSources objectAtIndex:NCAMERA];
        }
        [self setupSource:startSource];
    }
}

- (void) updateStatsLabel: (float) fps droppedPerSec:(float)dps busyPerSec:(float)bps {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->statsLabel.text = [NSString stringWithFormat:@"FPS: %.1f  dropped/s: %.1f  busy/s: %.1f",
                                 fps, dps, bps];
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
    
    [self changeTransformList:^{
        [self updateThumb:self->selectedImage];
        self->transforms.listChanged = YES;
        [self adjustButtons];
    }];
    
    transforms.outputSize = transformedView.frame.size;
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


- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
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
                                   orientation:[cameraController imageOrientation]];
    CGImageRelease(quartzImage);
    return image;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    
    if (!capturing)
        return;
    
    if (transforms.busy) {  // drop the frame
        busyCount++;
        return;
    }

    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateThumb:capturedImage];
        UIImage *transformed = [self->transforms executeTransformsWithImage:capturedImage];
        self->transformedView.image = transformed;
        [self->transformedView setNeedsDisplay];
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
       fromConnection:(nonnull AVCaptureConnection *)connection {
    droppedCount++;
}

- (IBAction) didPressVideo:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        NSLog(@"video long press");
    }
}

- (IBAction) doEditActiveList:(UIBarButtonItem *)button {
    NSLog(@"edit transform list");
    [activeListVC.tableView setEditing:!activeListVC.tableView.editing animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    switch (tableView.tag) {
        case TransformTag:
            return transforms.categoryNames.count;
        case ActiveTag:
            return 1;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (tableView.tag) {
        case TransformTag: {
            NSArray *transformList = [transforms.categoryList objectAtIndex:section];
            return transformList.count;
        }
        case ActiveTag:
            return transforms.masterTransformList.count;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (tableView.tag) {
        case TransformTag:
            return [transforms.categoryNames objectAtIndex:section];
        case ActiveTag:
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
    if (tableView.tag == ActiveTag) {
        NSString *CellIdentifier = @"ListingCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:CellIdentifier];
        }
        Transform *transform = [transforms.masterTransformList objectAtIndex:indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:
                               @"%2ld: %@", indexPath.row+1, transform.name];
        cell.layer.borderWidth = 0;
        cell.tag = 0;
        if (transform.param) {  // we need a slider
            CGRect f = CGRectInset(cell.contentView.frame, 2, 2);
            f.origin.x += f.size.width - 80;
            f.size.width = 80;
            f.origin.x = cell.contentView.frame.size.width - f.size.width;
            UISlider *slider = [[UISlider alloc] initWithFrame:f];
            slider.value = transform.param;
            slider.minimumValue = transform.low;
            slider.maximumValue = transform.high;
            slider.tag = indexPath.row + SLIDER_TAG_OFFSET;
            [slider addTarget:self action:@selector(adjustParam:)
             forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:slider];
        }
#ifdef brokenloop
        if (indexPath.row == transforms.list.count - 1)
            [tableView scrollToRowAtIndexPath:indexPath
                             atScrollPosition:UITableViewScrollPositionBottom
                                     animated:YES];
#endif
    } else {    // Selection table display table list
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
    return cell;
}

- (IBAction) adjustParam:(UISlider *)slider {
    if (slider.tag < SLIDER_TAG_OFFSET)
        return;
    [self changeTransformList:^{    // XXXXXX these parameters need per-execute values
        Transform *transform = [self->transforms.masterTransformList objectAtIndex:slider.tag - SLIDER_TAG_OFFSET];
        transform.param = slider.value;
        transform.changed = YES;
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == ActiveTag) {
        // Nothing happens
        //        Transform *transform = [transforms.list objectAtIndex:indexPath.row];
    } else {    // Selection table display table list
        NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
        Transform *transform = [[transformList objectAtIndex:indexPath.row] copy];
        [self changeTransformList:^{
            transform.changed = YES;
            [self->transforms.masterTransformList addObject:transform];
            [self->activeListVC.tableView reloadData];
            [self adjustButtons];
        }];
    }
}

- (IBAction) doRemoveLastTransform {
    [self changeTransformList:^{
        self->transforms.listChanged = YES;
        [self->transforms.masterTransformList removeLastObject];
        [self adjustButtons];
    }];
    [activeListVC.tableView reloadData];
}

- (IBAction) doRemoveAllTransforms:(UIBarButtonItem *)button {
    [self changeTransformList:^{
        self->transforms.listChanged = YES;
        [self->transforms.masterTransformList removeAllObjects];
        [self adjustButtons];
    }];
    [activeListVC.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete: {
            [self changeTransformList:^{
                [self->transforms.masterTransformList removeObjectAtIndex:indexPath.row];
                [self adjustButtons];
            }];
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
    Transform *t = [transforms.masterTransformList objectAtIndex:fromIndexPath.row];
    [self changeTransformList:^{
        self->transforms.listChanged = YES;
        [self->transforms.masterTransformList removeObjectAtIndex:fromIndexPath.row];
        [self->transforms.masterTransformList insertObject:t atIndex:toIndexPath.row];
    }];
    [tableView reloadData];
}

#define SPIN_WAIT_MS    10

- (void) changeTransformList:(void (^)(void))changeTransforms {
    // It is possible that the transformer engine hasn't processed some
    // previous changes we made.  Wait until it has.  This should
    // almost never happen.
    
    if (transforms.listChanged) {
        NSLog(@"prevous change pending");
        int msWait = 0;
        while(transforms.listChanged) {
            usleep(SPIN_WAIT_MS);
            msWait += SPIN_WAIT_MS;
        }
        NSLog(@"Spin wait for transform change took %dms", msWait);
    }
    changeTransforms();
    transforms.listChanged = YES;
}

#ifdef OLDCOMPLICATED
- (void) changeTransformList:(void (^)(void))changeTransforms {
    assert(!listChangePending); //  XXX right now, this is a race we hope not to lose
    pendingTransformChanges = changeTransforms;
    listChangePending = YES;
}
#endif

@end
