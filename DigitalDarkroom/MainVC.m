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
@property (nonatomic, strong)   UIView *inputView;
@property (nonatomic, strong)   UIImageView *inputThumb;
@property (nonatomic, strong)   UIImageView *cameraPreview;

@property (nonatomic, strong)   UIScrollView *selectInputScroll;
@property (nonatomic, strong)   UIView *selectInputButtonsView;
@property (nonatomic, strong)   NSMutableArray *inputSources;
@property (assign           )   int inputSource;

@property (nonatomic, strong)   UIView *outputView;
@property (nonatomic, strong)   UIImageView *transformedView;
@property (nonatomic, strong)   UILabel *outputLabel;

@property (nonatomic, strong)   UINavigationController *transformsNavVC;
@property (nonatomic, strong)   UITableViewController *transformsVC;
@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   UITableViewController *activeListVC;
@property (nonatomic, strong)   UIBarButtonItem *undoButton, *trashButton;

@property (assign)              int frameCount, droppedCount;

@property (nonatomic, strong)   UIBarButtonItem *addButton;

@property (assign, atomic)      BOOL capturing;
@property (nonatomic, strong)   UIImage *selectedImage;     // or nil if coming from the camera

@end

@implementation MainVC

@synthesize inputView, inputThumb, cameraPreview;
@synthesize outputView, transformedView, outputLabel;
@synthesize selectInputScroll, selectInputButtonsView;
@synthesize inputSources, inputSource;

@synthesize cameraController;
@synthesize transformsNavVC;
@synthesize transformsVC, activeListVC;
@synthesize frameCount, droppedCount;
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
        [self addCameraSource:BackCamera label:@"Back camera"];
        [self addFileSource:@"hsvrainbow.jpeg" label:@"HSV Rainbow"];
        [self addFileSource:@"ches.png" label:@"Ches"];
        [self addFileSource:@"ishihara6.jpeg" label:@"Ishibara 6"];
        [self addFileSource:@"cube.jpeg" label:@"Rubix cube"];
        [self addFileSource:@"ishihara8.jpeg" label:@"Ishibara 8"];
        [self addFileSource:@"ishihara25.jpeg" label:@"Ishibara 25"];
        [self addFileSource:@"ishihara45.jpeg" label:@"Ishibara 45"];
        [self addFileSource:@"ishihara56.jpeg" label:@"Ishibara 56"];
        [self addFileSource:@"rainbow.gif" label:@"Rainbow"];
    }
    NSLog(@"%lu input sources loaded", (unsigned long)inputSources.count);
    inputSource = NO_INPUT_SOURCE;
//    [self selectCamera:FrontCamera];
    
    return self;
}

- (void) addCameraSource:(cameras)c label:(NSString *)l {
    InputSource *is = [[InputSource alloc] init];
    is.sourceType = c;
    is.label = l;
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

- (void) selectSource:(int) sourceIndex {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    outputView = [[UIView alloc] init];
    transformedView = [[UIImageView alloc] initWithFrame:CGRectMake(0, LATER, LATER, TRANSTEXT_H)];
    //transformedView.contentMode = UIViewContentModeScaleAspectFit;
    //    transformedView.contentMode = UIViewContentModeScaleAspectFit;
    [outputView addSubview:transformedView];
    outputLabel = [[UILabel alloc] init];
    outputLabel.font = [UIFont
                        monospacedSystemFontOfSize:transformedView.frame.size.height-4
                        weight:UIFontWeightMedium];
    [outputView addSubview:outputLabel];
    [self updateOutputLabel];
    
    outputView.userInteractionEnabled = YES;
    outputView.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:outputView];
    
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
    [self.view addSubview:selectInputScroll];

    inputView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    inputView.backgroundColor = [UIColor whiteColor];
    
    inputThumb = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    inputThumb.contentMode = UIViewContentModeScaleAspectFit;
    [inputView addSubview: inputThumb];
    
    // where the original video is stored.  Not displayed.
    cameraPreview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [self.view addSubview:inputView];
    
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
    
    [self.view addSubview:transformsNavVC.view];
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
    
    cameraController = [[CameraController alloc] init];
    if ([cameraController cameraAvailable:FrontCamera])
        [self newInputSource:FrontCamera];
    else if  ([cameraController cameraAvailable:BackCamera])
        [self newInputSource:BackCamera];
    else
        [self newInputSource: NotACamera];
    [cameraController configureForCaptureWithCaller:self];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    frameCount = droppedCount = 0;
    [self updateOutputLabel];
    [self.view setNeedsDisplay];
    if (inputSource != NotACamera) {
        capturing = YES;
        transforms.outputSize = transformedView.frame.size;
        [cameraController startCamera];
    }
}

- (void) newInputSource: (cameras)newInput {
    switch (newInput) {
        case FrontCamera:
        case BackCamera:
            [cameraController selectCaptureDevice:newInput];
            // XXXX set thumb image address
            // XXXX adjust text
            // set to running
            // highlight thumb
            // turn on capture
            break;
        case NotACamera: {
            UIImage *image = [inputSources objectAtIndex:newInput];
            // turn off capture, etc.
            [self useImage:image];
            // XXXX dotransforms
            break;
        }
            
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [cameraController stopCamera];
    capturing = NO;
//    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

    CGRect workingFrame = self.view.frame;
    workingFrame.origin.x = INSET;
    workingFrame.size.width -= 2*INSET;
    workingFrame.origin.y = self.navigationController.navigationBar.frame.size.height;
    workingFrame.size.height -= workingFrame.origin.y;  // space at the bottom
    CGRect f = workingFrame;

    [cameraController setVideoOrientation];
    
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
        f.size.width = self.view.frame.size.width - SEP - MIN_TABLE_W;
        f.size.height = self.view.frame.size.height;
        
        // compute optimum display size, based on camera-supplied video if available
        if (inputSource != NotACamera) {
            CGSize cameraSize = [cameraController cameraVideoSizeFor:f.size];
            f.size = cameraSize;
            f.origin = CGPointZero;
            transformedView.frame = f;
        } else {
            f.size.height = 0.8*f.size.height;
            transformedView.frame = f;
            [cameraController cameraVideoSizeFor:CGSizeZero];
        }
        transformedView.backgroundColor = [UIColor redColor];

        f.origin.y += f.size.height;
        f.size.height = TRANSTEXT_H;
        outputLabel.backgroundColor = [UIColor orangeColor];
        outputLabel.font = [UIFont boldSystemFontOfSize:TRANSTEXT_H-4];
        outputLabel.frame = f;
        
        f.origin = workingFrame.origin;
        f.size.height = BELOW(outputLabel.frame);
        outputView.backgroundColor = [UIColor yellowColor];
        outputView.frame = f;
        
        cameraPreview.frame = f;
        f.origin = CGPointZero;
        
        f = workingFrame;
        f.origin.y = BELOW(outputView.frame) + SEP;
        f.size.width = outputView.frame.size.width;
        f.size.height = workingFrame.size.height - INSET - f.origin.y;
        selectInputScroll.frame = f;
        
        CGFloat thumbH = SELECTION_THUMB_H;
        if (thumbH > f.size.height)
            thumbH = f.size.height;
        int thumbsPerColumn = floor(f.size.height / thumbH);
        f.origin = CGPointZero;
        f.size.height = thumbsPerColumn * thumbH;
        f.size.width = thumbH * floor(inputSources.count + NCAMERA + thumbsPerColumn - 1)/thumbsPerColumn;
        selectInputButtonsView.frame = f;
        selectInputScroll.contentSize = f.size;

        for (int i=0; i<inputSources.count + NCAMERA; i++) {
            int row = i % thumbsPerColumn;
            int col = i / thumbsPerColumn;
            CGRect bf = CGRectMake(col*thumbH, row*thumbH,
                                   thumbH-1, thumbH);
            
            UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
            but.frame = bf;
            but.tag = i;
            but.titleLabel.textAlignment = NSTextAlignmentCenter;
            but.titleLabel.numberOfLines = 0;
            but.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
            but.titleLabel.adjustsFontSizeToFitWidth = YES;
            
            but.layer.borderWidth = 0.5;
            but.layer.borderColor = [UIColor blueColor].CGColor;
            but.layer.cornerRadius = 4.0;
            
            switch (i) {
                case FrontCamera:
                    [but setTitle:@"Front camera" forState:UIControlStateNormal];
                    but.enabled = [cameraController cameraAvailable:i];
                    but.backgroundColor = [UIColor blueColor];
                    break;
                case BackCamera:
                    [but setTitle:@"Back camera" forState:UIControlStateNormal];
                    but.enabled = [cameraController cameraAvailable:i];
                    but.backgroundColor = [UIColor blueColor];
                    break;
                default: {
                    InputSource *source = [inputSources objectAtIndex:i - NCAMERA];
                    UIImage *thumb = [self imageWithImage:source.image
                                             scaledToSize:but.frame.size];
                    [but setTitle:source.label forState:UIControlStateNormal];
                    [but setBackgroundImage:thumb forState:UIControlStateNormal];
                }
            }
            but.titleLabel.font = [UIFont boldSystemFontOfSize:20];
            but.showsTouchWhenHighlighted = YES;
            [but addTarget:self action:@selector(doInputSelect:)
                forControlEvents:UIControlEventTouchUpInside];
            [selectInputButtonsView addSubview:but];
        }
        
        f.origin.x = RIGHT(outputView.frame) + SEP;
        f.origin.y = workingFrame.origin.y;
        f.size.width = workingFrame.size.width - INSET - f.origin.x;
        f.size.height = 0.3 * workingFrame.size.height;
        activeListVC.view.frame = f;
        
        f.origin.y = BELOW(activeListVC.view.frame) + SEP;
        f.size.height = workingFrame.size.height - INSET - f.origin.y;
        transformsNavVC.view.frame = f;
        
        f.origin.x = 0;
        f.origin.y = transformsNavVC.navigationBar.frame.size.height;
        f.size.height = transformsNavVC.view.frame.size.height - f.origin.y;
        transformsVC.tableView.frame = f;
    }
    
    [transformsNavVC.view setNeedsDisplay];
    [transformsVC.tableView reloadData];    // ... needed
}

- (IBAction) doInputSelect:(UIButton *)button {
    NSLog(@"button tapped: %ld", (long)button.tag);
}

- (void) updateOutputLabel {
    outputLabel.text = [NSString stringWithFormat:@"frame: %5d   dropped: %5d",
                         frameCount, droppedCount];
    [outputLabel setNeedsDisplay];
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

#ifdef NOMORE
- (void) selectCamera:(cameras) c {
    NSLog(@"use camera %d", c);
    inputCamera = c;
    selectedImage = nil;
    [self configureCamera];
    capturing = YES;
    [cameraController startCamera];
}
#endif

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
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
        [self updateOutputImage:transformed];
    });
}

- (void) updateThumb: (UIImage *)image {
#ifdef NOTYET
    UIImage *scaledImage = [SelectInputVC imageWithImage:image
                                            scaledToSize:inputThumb.frame.size];
    inputThumb.image = scaledImage;
    NSLog(@"thumb output:");
    NSLog(@"transform: %.0f x %.0f", image.size.width, image.size.height);
    NSLog(@"   scaled: %.0f x %.0f", scaledImage.size.width, scaledImage.size.height);
    NSLog(@"       tv: %.0f x %.0f", inputThumb.frame.size.width, inputThumb.frame.size.height);
    [inputThumb setNeedsDisplay];
#endif
}

- (void) updateOutputImage:(UIImage *)newImage {
    transformedView.image = newImage;
    [transformedView setNeedsDisplay];
#ifdef notyet
    UIImage *scaledImage = [SelectInputVC imageWithImage:newImage
                                            scaledToSize:transformedView.frame.size];
    transformedView.image = scaledImage;
    NSLog(@"transformed output:");
    NSLog(@"transform: %.0f x %.0f", newImage.size.width, newImage.size.height);
    NSLog(@"   scaled: %.0f x %.0f", scaledImage.size.width, scaledImage.size.height);
    NSLog(@"       tv: %.0f x %.0f", transformedView.frame.size.width, transformedView.frame.size.height);
    NSLog(@"       ov: %.0f x %.0f", outputView.frame.size.width, outputView.frame.size.height);
    [transformedView setNeedsDisplay];
#endif
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateOutputLabel];
    });
    
    if (!capturing)
        return;
    
    if (transforms.busy) {  // drop the frame
        return;
    }
//    dispatch_async(dispatch_get_main_queue(), ^{    // XXXXX always?
//      [self->activeListVC.tableView reloadData];
//});
    
//    captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    // Lock the base address of the pixel buffer
    CVPixelBufferRef imageBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);

    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                  bytesPerRow, colorSpace,
                                                 BITMAP_OPTS);
    // get the captured image for thumbnail display
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    UIImage *capturedImage = [UIImage imageWithCGImage:quartzImage];
    CGImageRelease(quartzImage);
    

//    UIImage *transformed = [self->transforms executeTransformsWithContext:context];
//    UIImage *transformed = [self->transforms executeTransformsWithImage:capturedImage];

    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
//        transformedView.image = capturedImage;
        [self updateThumb:capturedImage];
//        [self updateOutputImage:transformed];
        [self updateOutputImage:capturedImage];
        [self updateOutputLabel];
    });
    
//    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
//    CMVideoDimensions d = CMVideoFormatDescriptionGetDimensions( formatDescription );
    
//    NSLog(@"***************** %s", __PRETTY_FUNCTION__);
    //    UIImage *image = imageFromSampleBuffer(sampleBuffer);
    // Add your code here that uses the image.
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
       fromConnection:(nonnull AVCaptureConnection *)connection {
    droppedCount++;
    //    NSLog(@"***************** %s", __PRETTY_FUNCTION__);
    //    UIImage *image = imageFromSampleBuffer(sampleBuffer);
    // Add your code here that uses the image.
}
// Don't change the list datastructure while running through the list.

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
