//
//  CollectionHeaderView.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 10/31/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define SECTION_TITLE_TAG           666

@interface CollectionHeaderView : UICollectionReusableView {
    UILabel *sectionTitle;
}

@property (nonatomic, strong)    UILabel *sectionTitle;

@end

NS_ASSUME_NONNULL_END
