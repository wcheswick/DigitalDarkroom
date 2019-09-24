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
@property (nonatomic, strong)   NSIndexPath *selectedTransformEntry;
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
@synthesize selectedTransformEntry;
@synthesize addButton;


- (id)init {
    self = [super init];
    if (self) {
        transforms = [[Transforms alloc] init];
        selectedTransformEntry = nil;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    
    videoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    [self.view addSubview:videoView];
    frameDisplay = [[UILabel alloc] init];
    frameDisplay.hidden = YES;  // performance debugging....too soon
    [videoView addSubview:frameDisplay];
    videoView.backgroundColor = [UIColor yellowColor];
//    videoView.contentMode = UIViewContentModeScaleAspectFit;
    
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
                                   action:@selector(doeditActiveList:)];
    activeListVC.navigationItem.rightBarButtonItem = editButton;

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

    addButton = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                  target:self
                                  action:@selector(addTransformToList:)];
    transformsVC.navigationItem.rightBarButtonItem = addButton;
    addButton.enabled = (selectedTransformEntry != nil);

    transformsVC.title = @"Transforms";
    transformsNavVC = [[UINavigationController alloc] initWithRootViewController:transformsVC];
    [transformsNavVC.view addSubview:transformsVC.tableView];
    
    [self.view addSubview:activeNavVC.view];
    [self.view addSubview:transformsNavVC.view];
    self.view.backgroundColor = [UIColor whiteColor];
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


#define SEP 10

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    BOOL isPortrait = UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]);
    CGRect f = self.view.frame;
    
    NSLog(@" **** view frame: %.0f x %.0f", self.view.frame.size.width, self.view.frame.size.height);

    [cameraController setVideoOrientation];
    
    if (isPortrait) {   // video on the top
        f.size.height /= 2;    // top half only, for now
        f.size = [cameraController cameraVideoSizeFor:f.size];
        f.origin.y = BELOW(self.navigationController.navigationBar.frame) + SEP;
        f.origin.x = (self.view.frame.size.width - f.size.width)/2;
        videoView.frame = f;
        
        f.origin.x = 0;
        f.origin.y = BELOW(videoView.frame) + SEP;
        f.size.height = self.view.frame.size.height - f.origin.y;
        f.size.width = (self.view.frame.size.width - SEP)*0.50;
        activeNavVC.view.frame = f;
        
        f.origin.x += f.size.width + SEP;
        transformsNavVC.view.frame = f;
        
        f.origin.y = activeNavVC.navigationBar.frame.size.height;
        f.size.height -= f.origin.y;
        f.origin.x = 0;
        transformsVC.tableView.frame = f;
        activeListVC.tableView.frame = f;
    } else {    // video on the left
        f.origin.y = BELOW(self.navigationController.navigationBar.frame) + SEP;
        f.size.height -= f.origin.y;
        f.origin.x = 0;
        f.size = [cameraController cameraVideoSizeFor:f.size];
        videoView.frame = f;
        
        f.origin.x = RIGHT(f) + SEP;
        f.size.width = self.view.frame.size.width - f.origin.x;
        f.size.height = 0.30*videoView.frame.size.height;
        activeNavVC.view.frame = f;
        
        f.origin.y = BELOW(f) + SEP;
        f.size.height = self.view.frame.size.height - f.origin.y;
        transformsNavVC.view.frame = f;
        
        f.origin.y = activeNavVC.navigationBar.frame.size.height;
        f.size.height = activeNavVC.navigationBar.frame.size.height - f.origin.y;
        f.origin.x = 0;
        transformsVC.tableView.frame = f;
        
        f.origin.y = transformsNavVC.navigationBar.frame.size.height;
        f.size.height = transformsNavVC.navigationBar.frame.size.height - f.origin.y;
        f.origin.x = 0;
        transformsVC.tableView.frame = f;
    }
    
    [transforms updateFrameSize: videoView.frame.size];
    
    [activeNavVC.view setNeedsDisplay];     // not sure if any of these are ...
    [transformsNavVC.view setNeedsDisplay];
    [activeListVC.tableView reloadData];
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
    [self.view setNeedsDisplay];
}


- (IBAction) doVideoTap:(UITapGestureRecognizer *)recognizer {
    NSLog(@"video tapped");
}

- (IBAction) doeditActiveList:(UIBarButtonItem *)button {
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
            if (selectedTransformEntry) // if we have a selected entry, don't highlight next (empty) cell
                return transforms.list.count;
            else
                return transforms.list.count + 1;    // to highlight where the next one goes
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag != ActiveTag)
        return NO;      // cannot edit source transform list
    if (selectedTransformEntry && indexPath.row >= transforms.list.count)
        return NO;      // cannot edit highlighted empty cell
    return YES;
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
            cell.textLabel.text = transform.name;
            cell.layer.borderWidth = 0;
        } else {    // show an empty highlighted cell where the next one goes
            cell.textLabel.text = @"";
            cell.layer.cornerRadius = 3.0;
            cell.layer.borderColor = [UIColor blueColor].CGColor;
            if (selectedTransformEntry) // do not show this
                cell.layer.borderWidth = 0;
            else
                cell.layer.borderWidth = 2;
        }
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
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if (tableView.tag == ActiveTag) {
        // Nothing happens
//        Transform *transform = [transforms.list objectAtIndex:indexPath.row];
    } else {    // Selection table display table list
        NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
        Transform *transform = [transformList objectAtIndex:indexPath.row];
        if (!selectedTransformEntry) {   // create a transform selection. Remove outlined cell
            cell.selected = YES;
            [transformsVC.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionBottom];
            selectedTransformEntry = indexPath;
            [transforms.list addObject:transform];
        } else if (indexPath.row != selectedTransformEntry.row) {  // switch selection entry
            UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:selectedTransformEntry];
            oldCell.selected = NO;
            [transformsVC.tableView deselectRowAtIndexPath:selectedTransformEntry animated:NO];
            selectedTransformEntry = indexPath;
            cell.selected = YES;
            [transformsVC.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionBottom];
            [transforms.list replaceObjectAtIndex:transforms.list.count - 1 withObject:transform];
        } else {        // remove selection, restoring outlined cell in list
            cell.selected = NO;
            [transformsVC.tableView deselectRowAtIndexPath:indexPath animated:NO];
            selectedTransformEntry = nil;
            [transforms.list removeObjectAtIndex:transforms.list.count - 1];
        }
        [activeListVC.tableView reloadData];
        [transforms setupForTransforming];
        addButton.enabled = (selectedTransformEntry != nil);
    }
}

- (IBAction) addTransformToList:(UIBarButtonItem *)button {
    assert(selectedTransformEntry);
    NSLog(@"add transform");
    [transformsVC.tableView deselectRowAtIndexPath:selectedTransformEntry animated:NO];
    selectedTransformEntry = nil;
    addButton.enabled = (selectedTransformEntry != nil);
    [activeListVC.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete:
            [transforms.list removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationBottom];
            break;
        case UITableViewCellEditingStyleInsert:
            break;
        default:
            NSLog(@"commitEditingStyle: never mind: %ld", (long)editingStyle);
    }
}

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
      toIndexPath:(NSIndexPath *)toIndexPath {
    NSLog(@"move from %ld.%ld to %ld.%ld",
          (long)fromIndexPath.section, (long)fromIndexPath.row,
          (long)toIndexPath.section, (long)toIndexPath.row);
    Transform *t = [transforms.list objectAtIndex:fromIndexPath.row];
    [transforms.list removeObjectAtIndex:fromIndexPath.row];
    [transforms.list insertObject:t atIndex:toIndexPath.row];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    
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
    
    // Create a bitmap graphics context with the sample buffer data
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

@end
