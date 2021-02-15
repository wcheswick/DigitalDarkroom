//
//  ExecuteRowView.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 2/11/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "ExecuteRowView.h"
#import "Defines.h"

@implementation ExecuteRowView

@synthesize statusChar;
@synthesize stepNumber;
@synthesize name, param, timing;

- (id)initWithName:(NSString *)tn param:(TransformInstance *)instance step:(int)step {
    self = [super init];
    if (self) {
        CGRect f = CGRectMake(0, 0, EXECUTE_CHAR_W, EXECUTE_ROW_H);
        statusChar = [[UILabel alloc] initWithFrame:f];
        statusChar.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        statusChar.text = @"";
        statusChar.textAlignment = NSTextAlignmentRight;
//        statusChar.backgroundColor = [UIColor yellowColor];
        [self addSubview:statusChar];
        
        f.origin.x = RIGHT(f);
        f.size.width = STEP_W;
        stepNumber = [[UILabel alloc] initWithFrame:f];
        stepNumber.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        if (step == NO_DEPTH_TRANSFORM)
            stepNumber.text = @"d";
        else
            stepNumber.text = [NSString stringWithFormat:@"%2d ", step];
        stepNumber.textAlignment = NSTextAlignmentRight;
//        stepNumber.backgroundColor = [UIColor orangeColor];
        [self addSubview:stepNumber];
        
        f.origin.x = RIGHT(f) + SEP;
        f.size.width = EXECUTE_NAME_W;
        name = [[UILabel alloc] initWithFrame:f];
        name.text = tn;
        name.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        name.textAlignment = NSTextAlignmentLeft;
//        name.backgroundColor = [UIColor redColor];
        [self addSubview:name];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        param = [[UILabel alloc] initWithFrame:f];
        param.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        param.text = [instance valueInfo];
        param.textAlignment = NSTextAlignmentRight;
        param.adjustsFontSizeToFitWidth = YES;
        [self addSubview:param];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        timing = [[UILabel alloc] initWithFrame:f];
        timing.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        timing.text = [instance timeInfo];
        timing.textAlignment = NSTextAlignmentRight;
        param.adjustsFontSizeToFitWidth = YES;
        [self addSubview:timing];
        
        f.size.width = RIGHT(f);
        assert(f.size.width == EXECUTE_LIST_W);
        f.origin.x = 0;
        self.frame = f;
    }
    return self;
}

@end
