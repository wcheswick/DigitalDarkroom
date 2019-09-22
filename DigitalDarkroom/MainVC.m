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
@property (nonatomic, strong)   NSMutableArray *activeList;

@property (nonatomic, strong)   UILabel *frameDisplay;
@property (assign)              int frameCount, droppedCount;

@end

@implementation MainVC

@synthesize cameraController;
@synthesize videoView;
@synthesize transformsNavVC, activeNavVC;
@synthesize transformsVC, activeListVC;
@synthesize frameDisplay;
@synthesize frameCount, droppedCount;
@synthesize transforms;
@synthesize activeList;


- (id)init {
    self = [super init];
    if (self) {
        activeList = [[NSMutableArray alloc] init];
        transforms = [[Transforms alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    cameraController = [[CameraController alloc] init];
    if (!cameraController) {
        NSLog(@"************ no cameras available, help");
    }

    videoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    [self.view addSubview:videoView];
    frameDisplay = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 300, 20)];
    frameDisplay.hidden = YES;  // performance debugging....too soon
    [videoView addSubview:frameDisplay];
    
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
    
    transformsNavVC = [[UINavigationController alloc] initWithRootViewController:transformsVC];
    [transformsNavVC.view addSubview:transformsVC.tableView];
    
    [self.view addSubview:activeNavVC.view];
    [self.view addSubview:transformsNavVC.view];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) viewWillAppear:(BOOL)animated {
    self.title = @"Digital Darkroom";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.opaque = NO;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                  target:self
                                  action:@selector(doAddTransform:)];
    activeNavVC.navigationItem.rightBarButtonItem = addButton;
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                   target:self
                                   action:@selector(doeditTransformList:)];
    activeNavVC.navigationItem.leftBarButtonItem = editButton;

    [self layoutViews];
}

#define SEP 10

- (void) layoutViews {
    CGRect f = self.view.frame;
    f.size.height /= 2;    // top half only, for now
    f.size = [cameraController cameraVideoSizeFor:f.size];
    f.origin.y = BELOW(self.navigationController.navigationBar.frame) + SEP;
    f.origin.x = (self.view.frame.size.width - f.size.width)/2;
    videoView.frame = f;
    
    f = activeNavVC.view.frame;
    f.origin.y = BELOW(videoView.frame) + SEP;
    f.size.height = self.view.frame.size.height - f.origin.y;
    f.size.width = (self.view.frame.size.width - SEP)*0.50;
    activeNavVC.view.frame = f;
    activeListVC.title = @"Active";
    
    f.origin.x += f.size.width + SEP;
    transformsNavVC.view.frame = f;
    transformsVC.title = @"Transforms";
    
    f.origin.y = activeNavVC.navigationBar.frame.size.height;
    f.size.height -= f.origin.y;
    f.origin.x = 0;
    transformsVC.tableView.frame = f;
    activeListVC.tableView.frame = f;
    
    [transforms updateFrameSize: videoView.frame.size];
    
    [activeListVC.tableView reloadData];
    [transformsVC.tableView reloadData];
    
    [activeNavVC.view setNeedsDisplay];
    [transformsNavVC.view setNeedsDisplay];
    
    NSLog(@"**** %@", activeNavVC.navigationItem.leftBarButtonItem);
}

- (void) updateFrameCounter {
    frameDisplay.text = [NSString stringWithFormat:@"frame: %5d   dropped: %5d",
                         frameCount, droppedCount];
    [frameDisplay setNeedsDisplay];
}

- (void) viewDidAppear:(BOOL)animated {
    NSString *errorStr, *detailErrorStr;
    frameCount = droppedCount = 0;
    [self updateFrameCounter];
    [cameraController startCamera:&errorStr
                           detail:&detailErrorStr
                           caller:self];
    if (errorStr)
        NSLog(@"camera start error: %@, %@", errorStr, detailErrorStr);
    [self.view setNeedsDisplay];
}


- (IBAction) doVideoTap:(UITapGestureRecognizer *)recognizer {
    NSLog(@"video tapped");
}

- (IBAction) doAddTransform:(UIBarButtonItem *)button {
    NSLog(@"add transform");
}

- (IBAction) doeditTransformList:(UIBarButtonItem *)button {
    NSLog(@"edit transform list");
    transformsVC.editing = !transformsVC.editing;
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
            return activeList.count;
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
    return (tableView.tag == ActiveTag);
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
        Transform *transform = [activeList objectAtIndex:indexPath.row];
        cell.textLabel.text = transform.name;
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
    cell.selected = NO;
    
    if (tableView.tag == ActiveTag) {
        Transform *transform = [activeList objectAtIndex:indexPath.row];
        NSLog(@"tapped listing entry number %ld, %@", (long)indexPath.row, transform.name);
    } else {    // Selection table display table list
        NSArray *transformList = [transforms.categoryList objectAtIndex:indexPath.section];
        Transform *transform = [transformList objectAtIndex:indexPath.row];
        NSLog(@"tapped transform entry number %ld, %@", (long)indexPath.row, transform.name);
    }
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete:
            break;
        case UITableViewCellEditingStyleInsert:
            break;
        default:
            NSLog(@"commitEditingStyle: never mind: %ld", (long)editingStyle);
    }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath
               toIndexPath:(NSIndexPath *)newIndexPath {
    
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    frameCount++;
    
    // Lock the base address of the pixel buffer

    captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
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
    CGContextRef context1 = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                  bytesPerRow, colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    
    Image image = {width, height, CGBitmapContextGetData(context1)};

#ifdef notdef
    for (int y=0; y<height/2; y++) {    // copy bottom
        for (int x=0; x<width; x++) {
            *A(image,x,y)] = *A(image,x,height - y - 1)];
        }
    }


    for (int y=0; y<height/2; y++) {    // copy top
        for (int x=0; x<width; x++) {
            pixels[P(x,height - y - 1)] = pixels[P(x,y)];
        }
    }

    for (int x=0; x<width/2; x++) { // copy right
        for (int y=0; y<height; y++) {
            pixels[P(width - x - 1,y)] = pixels[P(x,y)];
        }
    }

    for (int x=0; x<width/2; x++) { // copy left
        for (int y=0; y<height; y++) {
            pixels[P(x,y)] = pixels[P(width - x - 1,y)];
        }
    }
#endif
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context1);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context1);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    //I modified this line: [UIImage imageWithCGImage:quartzImage]; to the following to correct the orientation:
    UIImage *outImage =  [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    
//    CIImage * imageFromCoreImageLibrary = [CIImage imageWithCVPixelBuffer: pixelBuffer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self updateFrameCounter];
        self->videoView.image = outImage;
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
