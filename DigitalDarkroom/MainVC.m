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
@property (nonatomic, strong)   UIImageView *videoView;

@property (nonatomic, strong)   UINavigationController *transformsNavVC;
@property (nonatomic, strong)   UITableViewController *transformsVC;
@property (nonatomic, strong)   Transforms *transforms;

@property (nonatomic, strong)   UINavigationController *activeNavVC;
@property (nonatomic, strong)   UITableViewController *activeListVC;

@property (nonatomic, strong)   UILabel *frameDisplay;
@property (assign)              int frameCount, droppedCount;

@property (nonatomic, strong)   UIView *videoPreview;   // not shown
@property (nonatomic, strong)   UIBarButtonItem *addButton;

@end

@implementation MainVC

@synthesize cameraController;
@synthesize videoView;
@synthesize transformsNavVC, activeNavVC;
@synthesize transformsVC, activeListVC;
@synthesize frameDisplay;
@synthesize frameCount, droppedCount;
@synthesize transforms;
@synthesize videoPreview;
@synthesize addButton;


- (id)init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    videoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    frameDisplay = [[UILabel alloc] init];
    frameDisplay.hidden = YES;  // performance debugging....too soon
    [videoView addSubview:frameDisplay];
    videoView.backgroundColor = [UIColor yellowColor];
//    videoView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:videoView];

    videoPreview = [[UIView alloc] init];    // where the original video is stored

    
    UITapGestureRecognizer *videoTapped = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(doVideoTap:)];
    [frameDisplay addGestureRecognizer:videoTapped];
    
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
    UIBarButtonItem *undoButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                   target:self
                                   action:@selector(doRemoveLastTransform:)];
    activeListVC.navigationItem.leftBarButtonItem = undoButton;
    [self adjustUndoButton];

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

- (void) adjustUndoButton {
    activeListVC.navigationItem.leftBarButtonItem.enabled = transforms.list.count > 0;
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
    }
    
    [cameraController selectCaptureDevice];
    NSString *err = [cameraController configureForCaptureWithCaller:self];
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
        return;
    }
    [videoPreview.layer addSublayer:cameraController.captureVideoPreviewLayer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [cameraController stopCamera];
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
    } else {    // video on the left
        f.size.width -= MIN_TABLE_W + SEP;
        f.size = [cameraController cameraVideoSizeFor:f.size];
        assert(workingFrame.size.height - INSET);
        f.origin.x = INSET;
        f.origin.y = BELOW(self.navigationController.navigationBar.frame) + (workingFrame.size.height - f.size.height)/2;
        videoView.frame = f;
        
        f.origin.x = RIGHT(f) + SEP;
        f.origin.y = workingFrame.origin.y;
        f.size.width = workingFrame.size.width - f.origin.x - INSET;
        f.size.height = 0.30*videoView.frame.size.height;
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
    
    [transforms updateFrameSize: videoView.frame.size];
    
    [activeNavVC.view setNeedsDisplay];     // not sure if any of these are ...
    [transformsNavVC.view setNeedsDisplay];
    [transformsVC.tableView reloadData];    // ... needed

    f = videoView.frame;
    f.origin = CGPointZero;
    videoPreview.frame = f;
}

- (void) updateFrameCounter {
    frameDisplay.text = [NSString stringWithFormat:@"frame: %5d   dropped: %5d",
                         frameCount, droppedCount];
    [frameDisplay setNeedsDisplay];
}

- (void) viewDidAppear:(BOOL)animated {
    frameCount = droppedCount = 0;
    [self updateFrameCounter];
    [cameraController startCamera];
    [cameraController startCapture];
    [self.view setNeedsDisplay];
}


- (IBAction) doVideoTap:(UITapGestureRecognizer *)recognizer {
    NSLog(@"video tapped");
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
            return transforms.list.count;
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
        if (indexPath.row < transforms.list.count) { // show transform entry
            Transform *transform = [transforms.list objectAtIndex:indexPath.row];
            cell.textLabel.text = [NSString stringWithFormat:
                                   @"%2ld: %@", indexPath.row+1, transform.name];
            cell.layer.borderWidth = 0;
        } else {    // show an empty highlighted cell where the next one goes
            cell.textLabel.text = @"";
            cell.layer.cornerRadius = 3.0;
            cell.layer.borderColor = [UIColor blueColor].CGColor;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == ActiveTag) {
        // Nothing happens
        //        Transform *transform = [transforms.list objectAtIndex:indexPath.row];
    } else {    // Selection table display table list
        NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
        Transform *transform = [transformList objectAtIndex:indexPath.row];
        [self changeTransformList:^{
            [self->transforms.list addObject:transform];
            [self->transforms setupForTransforming];
            [self adjustUndoButton];
        }];
    }
}

- (IBAction) doRemoveLastTransform:(UIBarButtonItem *)button {
    [self changeTransformList:^{
        [self->transforms.list removeLastObject];
        [self adjustUndoButton];
    }];
    [activeListVC.tableView
     deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                    [NSIndexPath indexPathForRow:transforms.list.count inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationFade];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete: {
            [self changeTransformList:^{
                [self->transforms.list removeObjectAtIndex:indexPath.row];
                [self adjustUndoButton];
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
    Transform *t = [transforms.list objectAtIndex:fromIndexPath.row];
    [self changeTransformList:^{
        [self->transforms.list removeObjectAtIndex:fromIndexPath.row];
        [self->transforms.list insertObject:t atIndex:toIndexPath.row];
    }];
    [tableView reloadData];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->activeListVC.tableView reloadData];
    });
    
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
                                                  bytesPerRow, colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    
    UIImage *transformed = [transforms doTransformsOnContext:(CGContextRef)context];
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self updateFrameCounter];
        self->videoView.image = transformed;
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
