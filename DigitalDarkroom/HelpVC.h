//
//  HelpVC.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/23/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WKNavigationDelegate.h>


NS_ASSUME_NONNULL_BEGIN

@interface HelpVC : UIViewController <WKNavigationDelegate>

- (id)initWithURL:(NSURL *) startURL;

@end

NS_ASSUME_NONNULL_END
