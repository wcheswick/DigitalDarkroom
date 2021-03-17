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

@synthesize step;
@synthesize statusChar;
@synthesize stepNumber;
@synthesize name, param, timing;


- (id)initForStep:(long)s {
    self = [super init];
    if (self) {
        step = s;
        assert(step >= 0);
        self.tag = EXECUTE_STEP_TAG + step;
        
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
        stepNumber.textAlignment = NSTextAlignmentRight;
        [self addSubview:stepNumber];

        f.origin.x = RIGHT(f) + 2*SEP;
        f.size.width = EXECUTE_NAME_W;
        name = [[UILabel alloc] initWithFrame:f];
        name.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        name.textAlignment = NSTextAlignmentLeft;
        [self addSubview:name];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        param = [[UILabel alloc] initWithFrame:f];
        param.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        param.textAlignment = NSTextAlignmentRight;
        param.adjustsFontSizeToFitWidth = YES;
        [self addSubview:param];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        timing = [[UILabel alloc] initWithFrame:f];
        timing.font = [UIFont boldSystemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        timing.textAlignment = NSTextAlignmentRight;
        timing.adjustsFontSizeToFitWidth = YES;
        [self addSubview:timing];

        f.size.width = RIGHT(f) + EXECUTE_BORDER_W;
        assert(f.size.width == EXECUTE_LIST_W);
        f.origin.x = 0;
        self.frame = f;
        
        self.backgroundColor = [UIColor whiteColor];
        self.opaque = YES;
    }
    return self;
}

- (void) updateWithName:(NSString *__nullable)tn
                  param:(TransformInstance *__nullable)instance
                  color:(UIColor *) textColor {
#ifdef DEBUG_EXECUTE
    NSLog(@"      %2ld: updateWithName: %@", step, tn);
#endif
    stepNumber.textColor = textColor;
    stepNumber.text = [NSString stringWithFormat:@"%2ld", step];
    if (!tn) {
        name.text = nil;
        param.text = @"";
        timing.text = @"";
    } else {
        name.text = tn;
        param.text = [instance valueInfo];
        timing.text = [instance timeInfo];
    }

    stepNumber.textColor = textColor;
    name.textColor = textColor;
    param.textColor = textColor;
    timing.textColor = textColor;

    [self setNeedsDisplay];
}

- (void) makeRowEmpty {
    [self updateWithName:nil param:nil
                   color:[UIColor blackColor]];
}

@end
