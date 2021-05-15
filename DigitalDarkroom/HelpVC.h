//
//  HelpVC.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/23/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKUIdelegate.h>
#import <WebKit/WKFrameInfo.h>
#import <WebKit/WKNavigationAction.h>

NS_ASSUME_NONNULL_BEGIN

@interface HelpVC : UIViewController
    <WKNavigationDelegate,
    WKUIDelegate>

- (id)initWithSection:(NSString * __nullable)section;

@end

NS_ASSUME_NONNULL_END
