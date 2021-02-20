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

// step = EMPTY_STEP means not filled in yet

- (id)initWithName:(NSString *__nullable)tn
             param:(TransformInstance * __nullable)instance
              step:(long)step {
    self = [super init];
    if (self) {
        CGRect f = CGRectMake(EXECUTE_BORDER_W, 0, EXECUTE_CHAR_W, EXECUTE_ROW_H);
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
        if (step == EMPTY_STEP)
            stepNumber.text = @"";
        else
            stepNumber.text = [NSString stringWithFormat:@"%2ld ", step];
        stepNumber.textAlignment = NSTextAlignmentRight;
//        stepNumber.backgroundColor = [UIColor orangeColor];
        [self addSubview:stepNumber];
        
        f.origin.x = RIGHT(f) + SEP;
        f.size.width = EXECUTE_NAME_W;
        name = [[UILabel alloc] initWithFrame:f];
        if (step == EMPTY_STEP)
            name.text = @"";
        else
            name.text = tn;
        name.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        name.textAlignment = NSTextAlignmentLeft;
        [self addSubview:name];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        param = [[UILabel alloc] initWithFrame:f];
        param.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        if (step == EMPTY_STEP)
            param.text = @"";
        else
            param.text = [instance valueInfo];
        param.textAlignment = NSTextAlignmentRight;
        param.adjustsFontSizeToFitWidth = YES;
        [self addSubview:param];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        timing = [[UILabel alloc] initWithFrame:f];
        timing.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        if (step == EMPTY_STEP)
            timing.text = @"";
        else
            timing.text = [instance timeInfo];
        timing.textAlignment = NSTextAlignmentRight;
        timing.adjustsFontSizeToFitWidth = YES;
        [self addSubview:timing];
        
        self.backgroundColor = [UIColor whiteColor];
        self.opaque = YES;
 
        f.size.width = RIGHT(f) + EXECUTE_BORDER_W;
        assert(f.size.width == EXECUTE_LIST_W);
        f.origin.x = 0;
        self.frame = f;
    }
    return self;
}

@end
