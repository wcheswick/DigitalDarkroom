//
//  ThumbView.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 5/18/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Task.h"
#import "Transform.h"

@class Task;    // why the heck is this needed?

NS_ASSUME_NONNULL_BEGIN

#define THUMB_LABEL_TAG         198
#define THUMB_IMAGE_TAG         197

#define SECTION_SWITCH_H    31
#define SECTION_SWITCH_W    51  // apparently fixed?

typedef enum {
    ThumbAvailable,
    ThumbUnAvailable,
    ThumbActive,
    ThumbTransformBroken,
    SectionHeader,
} thumbStatus_t;

@interface ThumbView : UIView {
    int useCount;
    thumbStatus_t status;
    NSString *sectionName;  // nil if thumb, else section header
    Transform *transform;
    Task *task;             // for updating thumbnail
}

@property (assign)              int useCount;
@property (assign)              thumbStatus_t status;;
@property (nonatomic, strong)   NSString *sectionName;
@property (nonatomic, strong)   Transform *transform;
@property (nonatomic, strong)   Task *task;

- (id)initWith3dAvailable:(BOOL) have3D;

- (void) configureForTransform:(Transform *) transform;
- (void) configureSectionThumbNamed:(NSString *)sectionName;
- (void) adjustStatus:(thumbStatus_t) newStatus;

@end

NS_ASSUME_NONNULL_END
