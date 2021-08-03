//
//  PopoverMenuVC.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 7/28/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^PopoverSelectRow)(long rowSelected);
typedef void (^PopoverFormatCellForRow)(UITableViewCell *cell, long menuRow);

#define POPMENU_ABORTED (-1)

@interface PopoverMenuVC : UIViewController
    <UITableViewDelegate,
    UITableViewDataSource,
    UIPopoverPresentationControllerDelegate,
    UIAdaptivePresentationControllerDelegate> {
}

- (id)initWithFrame:(CGRect) frame
        entries:(int)entryCount
        title:(NSString *)title
        target:(id)target
        formatCell:(PopoverFormatCellForRow) formatCell
        selectRow:(PopoverSelectRow) selectRow;

- (UINavigationController *) prepareMenuUnder:(UIBarButtonItem *) barButton;
//               completion:(CompletionBlock)block;

@end

NS_ASSUME_NONNULL_END
