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
#define kPlusmodeOption     @"PlusMode"
#define kExecuteDebugOption @"ExecuteDebug"

@implementation Options

@synthesize displayMode;

@synthesize executeDebug;
@synthesize needHires;
@synthesize plusMode;
@synthesize reticle;

- (id)init {
    self = [super init];
    if (self) {
        reticle = [[NSUserDefaults standardUserDefaults] valueForKey:kReticleOption];
        needHires = [[NSUserDefaults standardUserDefaults] valueForKey:kHiresOption];;
        plusMode = [[NSUserDefaults standardUserDefaults] valueForKey:kPlusmodeOption];;
        executeDebug = [[NSUserDefaults standardUserDefaults] valueForKey:kExecuteDebugOption];
        displayMode = medium;   // not in use
        plusMode = NO;
        [self save];
    }
    return self;
}

- (void) save {
    [[NSUserDefaults standardUserDefaults] setBool:reticle forKey:kReticleOption];
    [[NSUserDefaults standardUserDefaults] setBool:needHires forKey:kHiresOption];
    [[NSUserDefaults standardUserDefaults] setBool:plusMode forKey:kPlusmodeOption];
    [[NSUserDefaults standardUserDefaults] setBool:executeDebug forKey:kExecuteDebugOption];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
