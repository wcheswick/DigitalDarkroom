//
//  CollectionHeaderView.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 10/31/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import "CollectionHeaderView.h"
#import "Defines.h"

@implementation CollectionHeaderView

@synthesize sectionTitle;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        sectionTitle = [[UILabel alloc] initWithFrame:frame];
        sectionTitle.adjustsFontSizeToFitWidth = YES;
        sectionTitle.textAlignment = NSTextAlignmentLeft;
        sectionTitle.font = [UIFont
                             systemFontOfSize:SECTION_HEADER_FONT_SIZE
                             weight:UIFontWeightMedium];
        sectionTitle.tag = SECTION_TITLE_TAG;
        sectionTitle.backgroundColor = [UIColor yellowColor];
        [self addSubview: sectionTitle];
    }
    return self;
}
@end
