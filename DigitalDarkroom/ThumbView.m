//
//  ThumbView.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 5/18/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "ThumbView.h"
#import "Defines.h"

@implementation ThumbView

@synthesize sectionName;
@synthesize transformIndex;


- (id)init {
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0, LATER, LATER, LATER);
        sectionName = nil;
    }
    return self;
}

- (void) enable:(BOOL) enable {
    self.userInteractionEnabled = enable;
    if (enable) {
        self.alpha = 1.0f;
        self.backgroundColor = [UIColor whiteColor];
    } else {
        self.alpha = 0.3f;
        self.backgroundColor = [UIColor grayColor];
    }
}


- (void) configureForTransform:(Transform *) transform {
    UILabel *transformLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    transformLabel.tag = THUMB_LABEL_TAG;
    transformLabel.textAlignment = NSTextAlignmentCenter;
    transformLabel.adjustsFontSizeToFitWidth = YES;
    transformLabel.numberOfLines = 0;
    //transformLabel.backgroundColor = [UIColor whiteColor];
    transformLabel.lineBreakMode = NSLineBreakByWordWrapping;
    transformLabel.text = [transform.name
                           stringByAppendingString:transform.hasParameters ? BIGSTAR : @""];
    transformLabel.textColor = [UIColor blackColor];
    transformLabel.font = [UIFont boldSystemFontOfSize:THUMB_FONT_SIZE];
    transformLabel.highlighted = NO;    // yes if selected
#ifdef NOTDEF
    transformLabel.attributedText = [[NSMutableAttributedString alloc]
                                     initWithString:transform.name
                                     attributes:labelAttributes];
    CGSize labelSize =  [transformLabel.text
                         boundingRectWithSize:f.size
                         options:NSStringDrawingUsesLineFragmentOrigin
                         attributes:@{
                             NSFontAttributeName : transformLabel.font,
                             NSShadowAttributeName: shadow
                         }
                         context:nil].size;
    transformLabel.contentMode = NSLayoutAttributeTop;
#endif
    transformLabel.opaque = NO;
    transformLabel.layer.borderWidth = 0.5;
    [self addSubview:transformLabel];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(LATER, LATER, LATER, LATER)];
    imageView.tag = THUMB_IMAGE_TAG;
    imageView.backgroundColor = [UIColor whiteColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.opaque = YES;
    [self addSubview:imageView];   // empty placeholder at the moment
    self.layer.borderColor = [UIColor blueColor].CGColor;
    self.layer.borderWidth = 1.0;
}

- (void) configureSectionThumbNamed:(NSString *)sn
                         withSwitch:(UISwitch *__nullable) sw {
    sectionName = sn;
    
    UILabel *sectionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    sectionLabel.tag = THUMB_LABEL_TAG;
    sectionLabel.textAlignment = NSTextAlignmentCenter;
    sectionLabel.adjustsFontSizeToFitWidth = YES;
    sectionLabel.numberOfLines = 3;
    sectionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    sectionLabel.text = [sectionName stringByAppendingString:@"\ntransforms"];
    sectionLabel.textColor = [UIColor blackColor];
    sectionLabel.font = [UIFont boldSystemFontOfSize:SECTION_NAME_FONT_SIZE];
    sectionLabel.highlighted = NO;    // yes if selected
#ifdef NOTDEF
    sectionLabel.attributedText = [[NSMutableAttributedString alloc]
                                     initWithString:transform.name
                                     attributes:labelAttributes];
    CGSize labelSize =  [sectionLabel.text
                         boundingRectWithSize:f.size
                         options:NSStringDrawingUsesLineFragmentOrigin
                         attributes:@{
                             NSFontAttributeName : transformLabel.font,
                             NSShadowAttributeName: shadow
                         }
                         context:nil].size;
    sectionLabel.contentMode = NSLayoutAttributeTop;
#endif
    sectionLabel.opaque = NO;
    [self addSubview:sectionLabel];
    
    if (sw) {
        [self addSubview:sw];
        sw.frame = CGRectMake(0, LATER, LATER, SECTION_SWITCH_H);
        [self addSubview:sw];
    }
}

@end
