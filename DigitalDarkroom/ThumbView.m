//
//  ThumbView.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 5/18/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "ThumbView.h"
#import "Defines.h"

@interface ThumbView ()


@end

@implementation ThumbView

@synthesize status;
@synthesize sectionName;
@synthesize transform, task;
@synthesize useCount;

- (id)initWith3dAvailable:(BOOL) have3D {
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0, LATER, LATER, LATER);
        sectionName = nil;
        transform = nil;
        task = nil;
        useCount = 0;
        if (have3D)
            [self adjustStatus:ThumbAvailable];
        else
            [self adjustStatus:ThumbUnAvailable];
    }
    return self;
}

#ifdef OLD
- (void) enable:(BOOL) enable {
    status = enable ? ThumbActive : ThumbAvailable;
    self.userInteractionEnabled = enable;
    if (enable) {
        self.alpha = 1.0f;
        self.backgroundColor = [UIColor whiteColor];
    } else {
        self.alpha = 0.3f;
        self.backgroundColor = [UIColor grayColor];
    }
}
#endif

- (void) configureForTransform:(Transform *) transform {
    self.transform = transform;
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
    self.layer.borderWidth = 0.5;
}

- (void) configureSectionThumbNamed:(NSString *)sn {
    sectionName = sn;
    [self adjustStatus:SectionHeader];
    
    UILabel *sectionLabel = [[UILabel alloc] initWithFrame:CGRectMake(THUMB_LABEL_SEP, LATER, LATER, LATER)];
    sectionLabel.tag = THUMB_LABEL_TAG;
    sectionLabel.textAlignment = NSTextAlignmentCenter;
    sectionLabel.adjustsFontSizeToFitWidth = YES;
    sectionLabel.numberOfLines = 0;
    sectionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.hyphenationFactor = 1.0f;

    // hyphenated entry
    sectionLabel.attributedText  = [[NSMutableAttributedString alloc]
                                    initWithString:[sectionName stringByAppendingString:@""]
                                    attributes:@{ NSParagraphStyleAttributeName : paragraphStyle }];;
    sectionLabel.textColor = [UIColor blackColor];
    sectionLabel.font = [UIFont boldSystemFontOfSize:SECTION_HEADER_FONT_SIZE];
    sectionLabel.textAlignment = NSTextAlignmentCenter;
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
}

- (void) adjustStatus:(thumbStatus_t) newStatus {
    UILabel *label = [self viewWithTag:THUMB_LABEL_TAG];
    UIImageView *imageView= [self viewWithTag:THUMB_IMAGE_TAG];;

    switch (newStatus) {
        case ThumbAvailable:
            label.font = [UIFont systemFontOfSize:THUMB_FONT_SIZE];
            if (sectionName)
                self.layer.borderWidth = 0;
            else
                self.layer.borderWidth = 1.0;
            label.highlighted = NO;
            imageView.image = nil;
            break;
        case ThumbActive:
            label.font = [UIFont boldSystemFontOfSize:THUMB_FONT_SIZE];
//            self.layer.borderWidth = useCount > 1 ? 10.0 : 5.0;
            label.highlighted = YES;    // this doesn't seem to do anything
            self.layer.borderWidth = 3.0;
            break;
        case ThumbTransformBroken:
            imageView.image = [UIImage imageNamed:[[NSBundle mainBundle]
                                                   pathForResource:@"images/brokenTransform.png"
                                                   ofType:@""]];;
            [imageView setNeedsDisplay];
            break;
        case ThumbUnAvailable:
            imageView.image = [UIImage imageNamed:[[NSBundle mainBundle]
                                                   pathForResource:@"images/no3Dcamera.png"
                                                   ofType:@""]];
            [imageView setNeedsDisplay];
            break;
        case SectionHeader:
            self.layer.borderWidth = 0;
            break;
    }
    status = newStatus;
    [self setNeedsDisplay];
}

@end
