//
//  Frame.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/6/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PixBuf.h"
#import "DepthBuf.h"

NS_ASSUME_NONNULL_BEGIN

@interface Frame : NSObject {
    PixBuf *__nullable pixBuf;
    DepthBuf *__nullable depthBuf;
    NSDate *creationTime;
}

@property (nonatomic, strong)   PixBuf *__nullable pixBuf;
@property (nonatomic, strong)   DepthBuf *__nullable depthBuf;
@property (nonatomic, strong)   NSDate *creationTime;

- (void) save;

@end

NS_ASSUME_NONNULL_END
