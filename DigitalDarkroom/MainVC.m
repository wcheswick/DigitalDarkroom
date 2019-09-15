//
//  MainVC.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "MainVC.h"
#import "CameraController.h"
#import "Defines.h"

@interface MainVC ()

@property (nonatomic, strong)   CameraController *cameraController;
@property (nonatomic, strong)   UIView *videoView;
@property (nonatomic, strong)   UITableView *programView;
@property (nonatomic, strong)   UIView *selectionView;

@end

@implementation MainVC

@synthesize cameraController;
@synthesize videoView;
@synthesize programView;
@synthesize selectionView;


- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    cameraController = [[CameraController alloc] init];
    if (!cameraController) {
        NSLog(@"************ no cameras available, help");
    }

    videoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, LATER, LATER)];
    [self.view addSubview:videoView];
    
    programView = [[UITableView alloc] initWithFrame:(CGRectMake(0, LATER, LATER, LATER))];
    [self.view addSubview:programView];
    
    selectionView = [[UIView alloc] initWithFrame:CGRectMake(LATER, LATER, LATER, LATER)];
    [self.view addSubview:selectionView];
}

- (void) viewWillAppear:(BOOL)animated {
    self.title = @"Digital Darkroom";
    
    SET_VIEW_Y(videoView, BELOW(self.navigationController.navigationBar.frame));
    SET_VIEW_WIDTH(videoView, self.view.frame.size.width);
    SET_VIEW_HEIGHT(videoView, videoView.frame.size.width * (768.0/1024.0));    // stupid hack
    
    SET_VIEW_Y(programView, BELOW(videoView.frame) + 5);
    SET_VIEW_HEIGHT(programView, self.view.frame.size.height - programView.frame.origin.y);
    SET_VIEW_Y(selectionView, programView.frame.origin.y);
    SET_VIEW_HEIGHT(selectionView, programView.frame.size.height);
    
    SET_VIEW_WIDTH(programView, self.view.frame.size.width*0.40);
    SET_VIEW_X(selectionView, RIGHT(programView.frame) + 5);
    SET_VIEW_WIDTH(selectionView, self.view.frame.size.width - selectionView.frame.origin.x);
    
    videoView.backgroundColor = [UIColor redColor];
    programView.backgroundColor = [UIColor orangeColor];
    selectionView.backgroundColor = [UIColor yellowColor];
    
}

- (void) viewDidAppear:(BOOL)animated {
    NSString *errorStr, *detailErrorStr;
    [cameraController startCamera:&errorStr
                           detail:&detailErrorStr
                           caller:self];
    if (errorStr)
        NSLog(@"camera start error: %@, %@", errorStr, detailErrorStr);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)captureConnection {
    NSLog(@"***************** %s", __PRETTY_FUNCTION__);
    //    UIImage *image = imageFromSampleBuffer(sampleBuffer);
    // Add your code here that uses the image.
}

@end
