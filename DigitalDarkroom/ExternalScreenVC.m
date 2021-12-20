//
//  ExternalScreenVC.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 11/13/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "ExternalScreenVC.h"

@interface ExternalScreenVC ()

@property(nonatomic, strong)    UIWindow *externalWindow;
@property(nonatomic, strong)    UIImageView *extImageView;

@property(nonatomic, strong)    UIScreen *screen;

@end

@implementation ExternalScreenVC

@synthesize externalWindow, extImageView, screen;

- (id)initWithScreen:(UIScreen *)screen {
    self = [super init];
    if (self) {
        externalWindow = [[UIWindow alloc]initWithFrame:screen.bounds];
        externalWindow.rootViewController = self;
// not yet        externalWindow.screen = screen;
        externalWindow.hidden = YES;
    }
    return self;
}

- (UIImageView *) activateExternalScreen {
    externalWindow.hidden = NO;
    extImageView = [[UIImageView alloc] initWithFrame:externalWindow.frame];
    return extImageView;
}

- (void) deactivateExternalScreen {
    externalWindow.hidden = YES;
    extImageView = nil;
}

- (void) screen:(BOOL) on {
    externalWindow.hidden = !on;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

-(void)teardownExternalScreen {
    if (externalWindow != nil) {
        externalWindow.hidden = true;
        externalWindow = nil;
    }
}

@end
