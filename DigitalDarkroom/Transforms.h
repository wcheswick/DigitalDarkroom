//
//  Transforms.h
//  DigitalDarkroom
//
//  Created by ches on 9/16/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Transform.h"

NS_ASSUME_NONNULL_BEGIN


@interface Transforms : NSObject {
    NSMutableArray *categoryNames;
    NSMutableArray *categoryList;
    CGSize frameSize;
    NSMutableArray *list;
}

@property (nonatomic, strong)   NSArray *categoryNames;
@property (nonatomic, strong)   NSArray *categoryList;
@property (assign)              NSMutableArray *transforms;
@property (assign)              CGSize frameSize;
@property (nonatomic, strong)   NSMutableArray *list;

- (void) updateFrameSize: (CGSize) newSize;

@end

NS_ASSUME_NONNULL_END
