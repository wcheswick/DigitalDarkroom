//
//  ChannelBuf.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/10/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChannelBuf : NSMutableData {
    size_t W, H;
}

@property (nonatomic, strong)   NSData *buf;
@property (assign)              size_t W, H;

@end

NS_ASSUME_NONNULL_END
