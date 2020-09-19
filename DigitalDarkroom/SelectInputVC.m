//
//  SelectInputVC.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/5/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#ifdef REFERENCE
#import "SelectInputVC.h"

#define THUMB_H 100
#define W   150

@interface SelectInputVC ()

@property (nonatomic, strong) NSArray *fileNames;
@property (nonatomic, strong) NSMutableArray *images;

@end

@implementation SelectInputVC

@synthesize caller;
@synthesize fileNames;
@synthesize images;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    fileNames = [[NSArray alloc] initWithObjects:
                 @"hsvrainbow.jpeg",
                 @"ishihara6.jpeg",
                 @"cube.jpeg",
                 @"ishihara8.jpeg",
                 @"ishihara25.jpeg", @"ishihara29.jpeg",
                 @"ishihara45.jpeg", @"ishihara56.jpeg",
                 @"rainbow.gif", nil];
    images = [[NSMutableArray alloc] initWithCapacity:fileNames.count];
    for (NSString *name in fileNames) {
        NSString *file = [@"images/" stringByAppendingString:name];
        NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@""];
        if (!imagePath) {
            NSLog(@"**** Image not found: %@", name);
            [images addObject:@""];
        } else {
            UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
//            NSLog(@"%@", imagePath);
//            NSLog(@"  size: %.0f x %.0f", image.size.width, image.size.height);
            if (!image)
                NSLog(@"*** image failed to load: %@", imagePath);
            else
                [images addObject:image];
        }
    }
    NSLog(@"%lu images found", (unsigned long)images.count);
    self.view.frame = CGRectMake(0, 0, W, 49*2 + images.count*THUMB_H);
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return NCAMERA + images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"InputCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    switch(indexPath.row) {
        case FrontCamera:
            cell.textLabel.text = @"Front camera";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
            break;
        case BackCamera:
            cell.textLabel.text = @"Rear camera";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
            break;
        default: {
            UIImageView *thumbView = [[UIImageView alloc] initWithFrame:cell.contentView.frame];
            thumbView.contentMode =  UIViewContentModeScaleAspectFit;
            thumbView.clipsToBounds = YES;
            UIImage *image = [images objectAtIndex:indexPath.row - NCAMERA];
            CGSize thumbSize = CGSizeMake(cell.contentView.frame.size.width, THUMB_H);
            thumbView.image = [SelectInputVC imageWithImage:image
                                               scaledToSize:thumbSize];
            [cell.contentView addSubview:thumbView];
        }
    }
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case FrontCamera:
            NSLog(@"selected front camera");
            [caller selectCamera:FrontCamera];
            break;
        case BackCamera:
            NSLog(@"selected back camera");
            [caller selectCamera:BackCamera];
            break;
        default:
            NSLog(@"selected image %ld, %@", (long)indexPath.row - NCAMERA,
                  [fileNames objectAtIndex:indexPath.row - NCAMERA]);
            UIImage *image = [images objectAtIndex:indexPath.row - NCAMERA];
            [caller useImage:image];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case FrontCamera:
        case BackCamera:
            return 60;
        default:
            return THUMB_H;
    }
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    UIGraphicsBeginImageContextWithOptions(newSize, YES, 0.0);
    float AR = image.size.width/image.size.height;
    float newAR = newSize.width/newSize.height;
    NSLog(@" ar  %.3f %.0f x %.0f", AR, image.size.width, image.size.height);
    NSLog(@" nar %.3f %.0f x %.0f", newAR, newSize.width, newSize.height);
    float scale;
    if (newAR > AR) { // we have extra width, use Y
        scale = newSize.height/image.size.height;
    } else {
        scale = newSize.width/image.size.width;
    }
    CGSize targetSize = CGSizeMake(image.size.width*scale, image.size.height*scale);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end

#ifdef REFERENCE
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
#endif

- (void) configureCamera {
    NSString *err;
    
    if (
    
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
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"incoming image: %zu x %zu, AR %.2f", width, height, (float)width/(float)height);

    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(context);

//    float xScale = transformedView.frame.size.width / width;
//    float yScale = transformedView.frame.size.height / height;
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:(CGFloat)1.0
                                   orientation:[cameraController imageOrientation]];
    CGImageRelease(quartzImage);
    return image;
}

#endif

