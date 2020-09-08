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

@property (nonatomic, strong)   UIView *outputView;
@property (nonatomic, strong)   UIImageView *transformedView;
@property (nonatomic, strong)   UILabel *transformedTextView;

@property (nonatomic, strong)   UINavigationController *transformsNavVC;
@property (nonatomic, strong)   UITableViewController *transformsVC;
@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   UINavigationController *activeNavVC;
@property (nonatomic, strong)   UITableViewController *activeListVC;
@property (nonatomic, strong)   UIBarButtonItem *undoButton, *trashButton;

@property (assign)              int frameCount, droppedCount;

@property (nonatomic, strong)   UIBarButtonItem *addButton;

@property (assign)              enum cameras inputCamera;   // camera if inputImage is nil
@property (assign, atomic)      BOOL capturing;
@property (nonatomic, strong)   UIImage *selectedImage;     // or nil if coming from the camera

@end

@implementation MainVC

@synthesize inputView, inputThumb, cameraPreview;
@synthesize outputView, transformedView, transformedTextView;

@synthesize cameraController;
@synthesize transformsNavVC, activeNavVC;
@synthesize transformsVC, activeListVC;
@synthesize frameCount, droppedCount;
@synthesize transforms;
@synthesize addButton;
@synthesize undoButton, trashButton;
@synthesize inputCamera;
@synthesize selectedImage;
@synthesize capturing;


- (id)init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
    }
    inputCamera = FrontCamera;
    selectedImage = nil;
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc]
                                      initWithTitle:@"Source"
                                      style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(doSelectInput:)];
    self.navigationItem.leftBarButtonItem = leftBarButton;
    
    inputView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    inputView.backgroundColor = [UIColor whiteColor];
    
    inputThumb = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    inputThumb.contentMode = UIViewContentModeScaleAspectFit;
    [inputView addSubview: inputThumb];
    
    // where the original video is stored.  Not displayed.
    cameraPreview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [self.view addSubview:inputView];
    
    outputView = [[UIView alloc] init];
    transformedView = [[UIImageView alloc] init];
    transformedView.backgroundColor = [UIColor yellowColor];
    //    transformedView.contentMode = UIViewContentModeScaleAspectFit;

    [outputView addSubview:transformedView];
    transformedTextView = [[UILabel alloc] init];
    transformedTextView.backgroundColor = [UIColor grayColor];
    
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

    activeNavVC = [[UINavigationController alloc] initWithRootViewController:activeListVC];

    [activeNavVC.view addSubview:activeListVC.tableView];
    
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
    
    [self.view addSubview:activeNavVC.view];
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
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.opaque = NO;

    cameraController = [[CameraController alloc] init];
    if (!cameraController) {
        NSLog(@"************ no cameras available, help");
        capturing = NO;
    } else
        [self configureCamera];
}

- (void) configureCamera {
    NSString *err;
    if (![cameraController selectCaptureDevice: inputCamera])
        err = @"camera not available";
    else
        err = [cameraController configureForCaptureWithCaller:self];
    if (err) {
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle:@"Camera connection failed"
                                    message:err
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                                        actionWithTitle:@"Dismiss"
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {}
                                        ];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        capturing = NO;
        return;
    }
    [cameraPreview.layer addSublayer:cameraController.captureVideoPreviewLayer];

    capturing = YES;
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
    workingFrame.origin.y = BELOW(self.navigationController.navigationBar.frame);
    workingFrame.size.height -= workingFrame.origin.y + INSET;  // space at the bottom
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
        f.size.width -= MIN_TABLE_W + SEP;
        f.size.height = workingFrame.size.height/5.0;
        inputView.frame = f;
        inputThumb.frame = CGRectMake(0, 0, f.size.width, f.size.height);

        f.origin.y = BELOW(f) + SEP;
        f.size.height = workingFrame.size.height - f.origin.y;
        outputView.frame = f;
        f.origin = CGPointMake(0, 0);
        f.size = [cameraController cameraVideoSizeFor:f.size];
        cameraPreview.frame = f;

        f.origin.x = RIGHT(inputView.frame) + SEP;
        f.origin.y = inputView.frame.origin.y;
        f.size.width = workingFrame.size.width - f.origin.x - INSET;
        f.size.height = 0.30*workingFrame.size.height;
        activeNavVC.view.frame = f;
        
        f.origin.x = 0;
        f.origin.y = activeNavVC.navigationBar.frame.size.height;
        f.size.height = activeNavVC.view.frame.size.height - f.origin.y;
        activeListVC.view.frame = f;
        
        f.origin.x = activeNavVC.view.frame.origin.x;
        f.origin.y = BELOW(activeNavVC.view.frame) + SEP;
        f.size.height = workingFrame.size.height - INSET - f.origin.y;
        transformsNavVC.view.frame = f;
        
        f.origin.x = 0;
        f.origin.y = transformsNavVC.navigationBar.frame.size.height;
        f.size.height = transformsNavVC.view.frame.size.height - f.origin.y;
        transformsVC.tableView.frame = f;
    }
    
    [activeNavVC.view setNeedsDisplay];     // not sure if any of these are ...
    [transformsNavVC.view setNeedsDisplay];
    [transformsVC.tableView reloadData];    // ... needed
}

- (void) updateFrameCounter {
    transformedTextView.text = [NSString stringWithFormat:@"frame: %5d   dropped: %5d",
                         frameCount, droppedCount];
    [transformedTextView setNeedsDisplay];
}

- (void) viewDidAppear:(BOOL)animated {
    frameCount = droppedCount = 0;
    [self updateFrameCounter];
    capturing = YES;
    [cameraController startCamera];
    [cameraController startCapture];
    [self.view setNeedsDisplay];
}

- (IBAction) didTapVideo:(UITapGestureRecognizer *)recognizer {
    NSLog(@"video tapped");
    if (selectedImage) // tapping non-moving image does nothing
        return;
    if (capturing) {
        [cameraController stopCapture];
    } else {
        [cameraController startCamera];
        [cameraController startCapture];
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

- (IBAction) doSelectInput:(UIBarButtonItem *)sender {
    SelectInputVC *siVC = [[SelectInputVC alloc] init];
    siVC.caller = self;
//    siVC.view.frame = CGRectMake(0, 0, 100, 44*4 + 40);
    siVC.preferredContentSize = siVC.view.frame.size; //CGSizeMake(100, 44*4 + 40);
    siVC.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController *popvc = siVC.popoverPresentationController;
    popvc.sourceView = self.navigationController.navigationBar;
    popvc.sourceRect = siVC.view.frame;
    popvc.delegate = self;
    popvc.sourceView = siVC.view;
    popvc.barButtonItem = sender;
    [self presentViewController:siVC animated:YES completion:nil];
}

- (void) selectCamera:(enum cameras) c {
    NSLog(@"use camera %d", c);
    inputCamera = c;
    selectedImage = nil;
    [self configureCamera];
    capturing = YES;
    [cameraController startCamera];
    [cameraController startCapture];
}

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
    
    UIGraphicsBeginImageContext(selectedImage.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIImage *transformed = [transforms executeTransformsWithContext:context];
    CGContextRelease(context);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"output %.0f x %.0f", transformed.size.width, transformed.size.height);
        [self updateOutputImage:transformed];
    });
}

- (void) updateThumb: (UIImage *)image {
    inputThumb.image = image;
    [inputThumb setNeedsDisplay];
}

- (void) updateOutputImage:(UIImage *)newImage {
    transformedView.image = newImage;
    [transformedView setNeedsDisplay];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
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

    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    UIImage *capturedImage = [UIImage imageWithCGImage:quartzImage];
    CGImageRelease(quartzImage);

    UIImage *transformed = [transforms executeTransformsWithContext:(CGContextRef)context];
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateThumb:capturedImage];
        [self updateOutputImage:transformed];
        [self updateFrameCounter];
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
