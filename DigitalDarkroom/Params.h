//
//  Params.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/17/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RemapBuf.h"

NS_ASSUME_NONNULL_BEGIN

@interface Params : NSObject {
    BOOL hasValue;
    int value;
    RemapBuf * __nullable remapBuf;
    size_t timesCalled;
    NSTimeInterval elapsedProcessingTime;
}

@property (assign)              BOOL hasValue;
@property (assign)              int value;
@property (nonatomic, strong)   RemapBuf * __nullable remapBuf;
@property (assign)              NSTimeInterval elapsedProcessingTime;

@end

NS_ASSUME_NONNULL_END
