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
@property (assign)              NSTimeInterval transformTotalElapsed;
@property (assign)              int transformCount;

@property (nonatomic, strong)   UINavigationController *transformsNavVC;
@property (nonatomic, strong)   UITableViewController *transformsVC;
@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   UITableViewController *activeListVC;
@property (nonatomic, strong)   UIBarButtonItem *undoButton, *trashButton;

@property (assign)              volatile int frameCount, droppedCount, busyCount;
@property (assign)              BOOL busy;
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
@synthesize transformTotalElapsed, transformCount;
@synthesize frameCount, droppedCount, busyCount, cps, dps, mps;
@synthesize busy;
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
        transformTotalElapsed = 0;
        transformCount = 0;
        busy = NO;
        
        
        inputSources = [[NSMutableArray alloc] init];
        
        [self addCameraSource:FrontCamera label:@"Front camera"];
        [self addCameraSource:RearCamera label:@"Rear camera"];
        [self addCameraSource:Front3DCamera label:@"Front 3D camera"];
        [self addCameraSource:Rear3DCamera label:@"Rear 3D camera"];
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
        
        cameraController = [[CameraController alloc] init];
        cameraController.delegate = self;
        
        Cameras sourceIndex;
        for (sourceIndex=0; sourceIndex<NCAMERA; sourceIndex++) {
            if ([cameraController isCameraAvailable:sourceIndex])
                break;
        }
        currentSource = [inputSources objectAtIndex:sourceIndex];
        // [self.view setNeedsLayout];  // we do this anyway
        frontButton = rearButton = nil;
        cameraThumbView = nil;
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
    undoButton.enabled = trashButton.enabled = transforms.sequence.count > 0;
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
    float transformAveTime;
    if (transformCount)
        transformAveTime = 1000.0 *(transformTotalElapsed/transformCount);
    else
        transformAveTime = NAN;
    
    [self updateStatsLabel: frameCount/elapsed
             droppedPerSec:droppedCount/elapsed
                busyPerSec:busyCount/elapsed
              transformAve:transformAveTime];
    frameCount = droppedCount = busyCount = 0;
    transformCount = transformTotalElapsed = 0;
}

- (IBAction) doInputSelect:(UIButton *)button {
    NSLog(@"input button tapped: %ld", (long)button.tag);
    
    currentSource = [inputSources objectAtIndex:button.tag];
    [self.view setNeedsLayout];
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
        outputView.frame = f;   // adjust height later
        
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

        // now the left side, taking into account the size of the input source

        f.origin = CGPointZero;
        f.size = outputView.frame.size;
        
        // we recompute the output display for each layout or input source change.
        // the size and aspect ratio of the source guides us.  For cameras, find
        // out what is available for the current camera and orientation.
        
        if (ISCAMERA(currentSource.sourceType)) {
            [cameraController selectCamera:currentSource.sourceType];
            f.size = [cameraController setupCameraForSize:f.size];
            transformedView.frame = f;
        } else {
            f.size.height = 0.8*f.size.height;
            transformedView.frame = f;
            transformedView.image = [self centerImage:currentSource.image
                                               inSize:f.size];
        }
        
        previewView = transformedView;  // used?

        f.origin.x = 0;
        f.origin.y = BELOW(transformedView.frame) + SEP;
        f.size.height = TRANSTEXT_H;
        f.size.width = transformedView.frame.size.width;
        statsLabel.frame = f;
        statsLabel.font = [UIFont
                            monospacedSystemFontOfSize:TRANSTEXT_H-4
                            weight:UIFontWeightMedium];
        statsLabel.backgroundColor = [UIColor whiteColor];

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
            [but setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
            but.titleLabel.textColor = [UIColor blueColor];
            
            but.layer.borderWidth = 2.0;
            but.layer.borderColor = [UIColor blackColor].CGColor;
            but.layer.cornerRadius = 6.0;
            
            InputSource *source = [inputSources objectAtIndex:i];
            switch (i) {
                case FrontCamera:
                    [but setTitle:@"Front camera" forState:UIControlStateNormal];
                    [but setTitle:@"Front camera (unavailable)" forState:UIControlStateDisabled];
                    but.enabled = [cameraController isCameraAvailable:i];
                    but.backgroundColor = [UIColor whiteColor];
                    frontButton = but;
                    break;
                case RearCamera:
                    [but setTitle:@"Rear camera" forState:UIControlStateNormal];
                    [but setTitle:@"Rear camera (unavailable)" forState:UIControlStateDisabled];
                    but.enabled = [cameraController isCameraAvailable:i];
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
    
    //AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)transformedView.layer;
    //cameraController.captureVideoPreviewLayer = previewLayer;

    if (ISCAMERA(currentSource.sourceType)) {
        [cameraController startSession];
        [cameraController startCamera];
    }
    
    [transformsNavVC.view setNeedsDisplay];
    [transformsVC.tableView reloadData];    // ... needed
}

- (void) updateStatsLabel: (float) fps
            droppedPerSec:(float)dps
               busyPerSec:(float)bps
             transformAve:(double) tams {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->statsLabel.text = [NSString stringWithFormat:@"FPS: %.1f  dropped/s: %.1f  busy/s: %.1f  exec ave: %.1fms",
                                 fps, dps, bps, tams];
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;

    if (busy) {
        busyCount++;
        return;
    }
    busy = YES;

    UIImage *capturedImage = [self imageFromSampleBuffer:sampleBuffer];
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
        Transform *transform = [transforms.sequence objectAtIndex:indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:
                               @"%2ld: %@", indexPath.row+1, transform.name];
        cell.layer.borderWidth = 0;
        cell.tag = 0;
        if (transform.p) {  // we need a slider
            CGRect f = CGRectInset(cell.contentView.frame, 2, 2);
            f.origin.x += f.size.width - 80;
            f.size.width = 80;
            f.origin.x = cell.contentView.frame.size.width - f.size.width;
            UISlider *slider = [[UISlider alloc] initWithFrame:f];
            slider.value = transform.p;
            slider.minimumValue = transform.low;
            slider.maximumValue = transform.high;
            slider.tag = indexPath.row + SLIDER_TAG_OFFSET;
            //UILabel *valueLabel = [[UILabel alloc] init];
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
    int row = (int)slider.tag - SLIDER_TAG_OFFSET;
    Transform *t = [transforms.sequence objectAtIndex:row];
    @synchronized (transforms.sequence) {
        t.p = slider.value;
        NSLog(@"value is %f", slider.value);
        t.pUpdated = YES;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == ActiveTag) {
        // Nothing happens
        //        Transform *transform = [transforms.list objectAtIndex:indexPath.row];
    } else {    // Selection table display table list
        NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
        Transform *transform = [transformList objectAtIndex:indexPath.row];
        Transform *thisTransform = [transform copy];
        assert(thisTransform.remapTable == NULL);
        thisTransform.p = thisTransform.initial;
        @synchronized (transforms.sequence) {
            [transforms.sequence addObject:thisTransform];
            transforms.sequenceChanged = YES;
        }
        [self.activeListVC.tableView reloadData];
        [self adjustButtons];
    }
}

- (IBAction) doRemoveLastTransform {
    @synchronized (transforms.sequence) {
        [transforms.sequence removeLastObject];
        transforms.sequenceChanged = YES;
    }
    [self adjustButtons];
    [activeListVC.tableView reloadData];
}

- (IBAction) doRemoveAllTransforms:(UIBarButtonItem *)button {
    @synchronized (transforms.sequence) {
        [transforms.sequence removeAllObjects];
        transforms.sequenceChanged = YES;
    }
    [self adjustButtons];
    [activeListVC.tableView reloadData];
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

@end
