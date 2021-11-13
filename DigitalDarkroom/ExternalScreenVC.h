//
//  ExternalScreenVC.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 11/13/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExternalScreenVC : UIViewController

- (id)initWithScreen:(UIScreen *)screen;
- (UIImageView *) activateExternalScreen;
- (void) deactivateExternalScreen;

@end

NS_ASSUME_NONNULL_END
