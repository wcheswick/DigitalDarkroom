//
//  Options.m
//  SciEx
//
//  Created by ches on 2/23/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "Options.h"

#define kHiresOption        @"Hires"
#define kExecuteDebugOption @"ExecuteDebug"

@implementation Options

@synthesize displayMode;

@synthesize executeDebug;
@synthesize needHires;

- (id)init {
    self = [super init];
    if (self) {
        needHires = [[NSUserDefaults standardUserDefaults] boolForKey:kHiresOption];;
        executeDebug = [[NSUserDefaults standardUserDefaults] boolForKey:kExecuteDebugOption];
        displayMode = medium;   // not in use
        needHires = NO;
        [self save];
    }
    return self;
}

- (void) save {
    [[NSUserDefaults standardUserDefaults] setBool:needHires forKey:kHiresOption];
    [[NSUserDefaults standardUserDefaults] setBool:executeDebug forKey:kExecuteDebugOption];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
