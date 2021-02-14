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

@synthesize selectedChar;
@synthesize statusChar;
@synthesize name, param, timing;

- (id)initWithName:(NSString *)tn param:(TransformInstance *)instance {
    self = [super init];
    if (self) {
        CGRect f = CGRectMake(0, 0, EXECUTE_CHAR_W, EXECUTE_ROW_H);
        selectedChar = [[UILabel alloc] initWithFrame:f];
        selectedChar.text = @"";
        selectedChar.textAlignment = NSTextAlignmentRight;
        [self addSubview:selectedChar];

        f.origin.x = RIGHT(f);
        f.size.width = 2*EXECUTE_CHAR_W;
        statusChar = [[UILabel alloc] initWithFrame:f];
        statusChar.text = @"";
        statusChar.textAlignment = NSTextAlignmentRight;
        [self addSubview:statusChar];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NAME_W;
        name = [[UILabel alloc] initWithFrame:f];
        name.text = tn;
        name.font = [UIFont systemFontOfSize:EXECUTE_STATUS_FONT_SIZE];
        name.textAlignment = NSTextAlignmentLeft;
        name.adjustsFontSizeToFitWidth = YES;
        [self addSubview:name];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        param = [[UILabel alloc] initWithFrame:f];
        param.text = [instance valueInfo];
        param.textAlignment = NSTextAlignmentRight;
        param.adjustsFontSizeToFitWidth = YES;
        [self addSubview:param];
        
        f.origin.x = RIGHT(f);
        f.size.width = EXECUTE_NUMBERS_W;
        timing = [[UILabel alloc] initWithFrame:f];
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
