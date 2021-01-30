//
//  TransformInstance.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/14/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

@class Transform;

#import <Foundation/Foundation.h>
#import "Transform.h"
#import "RemapBuf.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformInstance : NSObject {
    int value;   // parameter setting and range for transform
    RemapBuf * __nullable __unsafe_unretained remapBuf;
    NSTimeInterval elapsedProcessingTime;
    size_t timesCalled;
}

@property (assign)              int value;
@property (assign)              RemapBuf * __nullable __unsafe_unretained remapBuf;
@property (assign)              NSTimeInterval elapsedProcessingTime;
@property (assign)              size_t timesCalled;

- (id) initFromTransform:(Transform *)transform;
- (NSString *) valueInfo;
- (NSString *) timeInfo;


@end

NS_ASSUME_NONNULL_END
