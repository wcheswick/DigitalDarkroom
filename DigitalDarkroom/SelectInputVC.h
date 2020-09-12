//
//  SelectInputVC.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/5/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifdef REFERENCE
NS_ASSUME_NONNULL_BEGIN

typedef enum cameras {
    FrontCamera,
    BackCamera,
    NotACamera,
} cameras;
#define NCAMERA (BackCamera+1)

@protocol SelectInputProto <NSObject>

- (void) selectCamera:(enum cameras) camera;
- (void) useImage:(UIImage *)image;

@end

@interface SelectInputVC : UITableViewController
    <UITableViewDelegate, UITableViewDataSource,
    UIPopoverPresentationControllerDelegate> {
    __unsafe_unretained id<SelectInputProto> caller;
}

@property (assign)  __unsafe_unretained id<SelectInputProto> caller;

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;

@end

NS_ASSUME_NONNULL_END
#endif

