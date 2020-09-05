//
//  SelectInputVC.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/5/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

enum cameras {
    FrontCamera,
    BackCamera,
};
#define NCAMERA (BackCamera+1)

@protocol SelectInputProto <NSObject>

- (void) selectCamera:(enum cameras) camera;
- (void) useImage:(UIImage *)image;

@end

@interface SelectInputVC : UITableViewController

<UIPopoverPresentationControllerDelegate> {
    __unsafe_unretained id<SelectInputProto> caller;
}

@property (assign)  __unsafe_unretained id<SelectInputProto> caller;

@end

NS_ASSUME_NONNULL_END
