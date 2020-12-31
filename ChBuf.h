//
//  ChBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/13/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

typedef channel *_Nullable *_Nonnull ChannelArray_t;

@interface ChBuf : NSMutableData {
    size_t w, h;
    ChannelArray_t ca;  // channel array, cb[x][y] in our code
    channel *cb;      // channel buffer, w*h contiguous pixels
}

@property (assign)  size_t w, h;
@property (assign)  ChannelArray_t ca;
@property (assign)  channel *cb;

- (id) initForWidth:(size_t) w height:(size_t)h;

@end

NS_ASSUME_NONNULL_END
