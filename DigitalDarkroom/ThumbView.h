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

#define SECTION_SWITCH_H    31
#define SECTION_SWITCH_W    51  // apparently fixed?

#define IS_SECTION_HEADER(t)    ((t).sectionName != nil)

@interface ThumbView : UIView {
    NSString *sectionName;  // nil if thumb, else section header
    long transformIndex;
}

@property (nonatomic, strong)   NSString *sectionName;
@property (assign)              long transformIndex;

- (void) configureForTransform:(Transform *) transform;
- (void) configureSectionThumbNamed:(NSString *)sectionName;
- (void) enable:(BOOL) enable;

@end

NS_ASSUME_NONNULL_END
