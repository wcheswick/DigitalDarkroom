//
//  ExecuteRowView.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 2/11/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TransformInstance.h"

NS_ASSUME_NONNULL_BEGIN

@interface ExecuteRowView : UIView {
    UILabel *statusChar;
    UILabel *stepNumber;
    UILabel *name;
    UILabel *param;
    UILabel *timing;
}

@property (nonatomic, strong)   UILabel *statusChar;
@property (nonatomic, strong)   UILabel *stepNumber;
@property (nonatomic, strong)   UILabel *name;
@property (nonatomic, strong)   UILabel *param;
@property (nonatomic, strong)   UILabel *timing;

- (id)initWithName:(NSString *)n param:(TransformInstance *)instance step:(long)step;

@end

NS_ASSUME_NONNULL_END
