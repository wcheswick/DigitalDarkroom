//
//  OptionsVC.h
//  SciEx
//
//  Created by ches on 3/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Options.h"

NS_ASSUME_NONNULL_BEGIN


@interface OptionsVC : UITableViewController
    <UITableViewDelegate, UITableViewDataSource>  {
    Options *options;
}

@property(nonatomic, strong)    Options *options;

- (id)initWithOptions:(Options *) o;

@end

NS_ASSUME_NONNULL_END
