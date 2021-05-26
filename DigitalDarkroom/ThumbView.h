//
//  ThumbView.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 5/18/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "Transform.h"

NS_ASSUME_NONNULL_BEGIN

#define THUMB_LABEL_TAG         198
#define THUMB_IMAGE_TAG         197
#define THUMB_SWITCH_TAG        196

#define THUMB_SECTION_TAG   (-1)

#define SECTION_NAME_FONT_SIZE  14
#define SECTION_SWITCH_H    31
#define SECTION_SWITCH_W    51  // apparently fixed?

@interface ThumbView : UIView {
    NSString *sectionName;
    long transformIndex;
}

@property (nonatomic, strong)   NSString *sectionName;
@property (assign)              long transformIndex;

- (void) configureSectionThumbNamed:(NSString *)sectionName
                         withSwitch:(UISwitch *__nullable) sw;
- (void) configureForTransform:(Transform *) transform;
- (void) enable:(BOOL) enable;

@end

NS_ASSUME_NONNULL_END