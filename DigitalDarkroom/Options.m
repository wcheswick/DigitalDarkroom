//
//  Options.m
//  SciEx
//
//  Created by ches on 2/23/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "Options.h"

#define kReticleOption     @"Heretical"
#define kHiresOption        @"Hires"
#define kmultipleModeOption     @"multipleMode"
#define kExecuteDebugOption @"ExecuteDebug"

@implementation Options

@synthesize displayMode;

@synthesize executeDebug;
@synthesize needHires;
@synthesize multipleMode;
@synthesize reticle;

- (id)init {
    self = [super init];
    if (self) {
        reticle = [[NSUserDefaults standardUserDefaults] valueForKey:kReticleOption];
        needHires = [[NSUserDefaults standardUserDefaults] valueForKey:kHiresOption];;
        multipleMode = [[NSUserDefaults standardUserDefaults] valueForKey:kmultipleModeOption];;
        executeDebug = [[NSUserDefaults standardUserDefaults] valueForKey:kExecuteDebugOption];
        displayMode = medium;   // not in use
        multipleMode = NO;
        needHires = NO;
        [self save];
    }
    return self;
}

- (void) save {
    [[NSUserDefaults standardUserDefaults] setBool:reticle forKey:kReticleOption];
    [[NSUserDefaults standardUserDefaults] setBool:needHires forKey:kHiresOption];
    [[NSUserDefaults standardUserDefaults] setBool:multipleMode forKey:kmultipleModeOption];
    [[NSUserDefaults standardUserDefaults] setBool:executeDebug forKey:kExecuteDebugOption];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
