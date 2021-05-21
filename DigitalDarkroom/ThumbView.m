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
    transformLabel.font = [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE];
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
}

- (void) configureSectionThumbNamed:(NSString *)sn
                         withSwitch:(UISwitch *__nullable) sw {
    sectionName = sn;
    
    UILabel *transformLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, LATER, LATER, LATER)];
    transformLabel.tag = THUMB_LABEL_TAG;
    transformLabel.textAlignment = NSTextAlignmentCenter;
    transformLabel.adjustsFontSizeToFitWidth = YES;
    transformLabel.numberOfLines = 0;
    transformLabel.lineBreakMode = NSLineBreakByWordWrapping;
    transformLabel.text = sectionName;
    transformLabel.textColor = [UIColor blackColor];
    transformLabel.font = [UIFont boldSystemFontOfSize:OLIVE_FONT_SIZE];
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
    
    if (sw) {
        sw.tag = THUMB_SWITCH_TAG;    // Not used
        [self addSubview:sw];
    }
}

@end
