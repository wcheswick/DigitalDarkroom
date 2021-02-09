//
//  Options.h
//  SciEx
//
//  Created by ches on 2/23/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// This is deprecated:
typedef enum {
    small,  // mosly for iPhones
    medium,
    fullScreen,
    alternateScreen,
} DisplayMode_t;

@interface Options : NSObject {
    BOOL plusMode;
    BOOL executeDebug;
    BOOL needHires;
    BOOL reticle;
}
#define OPTION_COUNT    4

@property (assign)  DisplayMode_t displayMode;
@property (assign)  BOOL plusMode, executeDebug, needHires, reticle;

- (void) save;

@end

NS_ASSUME_NONNULL_END
