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

#define DEPTH_STEP  DEPTH_TRANSFORM

#define TASK_STEP_TAG_OFFSET    10

@interface ExecuteRowView : UIView {
    long step;
    UILabel *statusChar;
    UILabel *stepNumber;
    UILabel *name;
    UILabel *param;
    UILabel *timing;
}

@property (assign)              long step;
@property (nonatomic, strong)   UILabel *statusChar;
@property (nonatomic, strong)   UILabel *stepNumber;
@property (nonatomic, strong)   UILabel *name;
@property (nonatomic, strong)   UILabel *param;
@property (nonatomic, strong)   UILabel *timing;

- (id)initForStep:(long)s;
- (void) updateWithName:(NSString *__nullable)tn
             param:(TransformInstance *__nullable)instance
             color:(UIColor *) textColor;
- (void) makeRowEmpty;

@end

NS_ASSUME_NONNULL_END
