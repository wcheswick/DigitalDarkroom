//
//  TransformInstance.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/14/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RemapBuf.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformInstance : NSObject {
    int value;   // parameter setting and range for transform
    RemapBuf * __nullable __unsafe_unretained remapTable;
    NSTimeInterval elapsedProcessingTime;
}

@property (assign)              int value;
@property (assign)              RemapBuf * __nullable __unsafe_unretained remapTable;
@property (assign)              NSTimeInterval elapsedProcessingTime;

@end

NS_ASSUME_NONNULL_END
