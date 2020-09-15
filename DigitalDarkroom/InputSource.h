//
//  InputSource.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/11/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    FrontCamera,
    RearCamera,
    NotACamera,
} cameras;

#define NCAMERA (RearCamera+1)
#define ISCAMERA(i) ((i) < NCAMERA)

@interface InputSource : NSObject {
    cameras sourceType;
    NSString *label;
    UIImage *image;
    UIButton *button;
}

@property (assign)  cameras sourceType;
@property (nonatomic, strong)   NSString *label;
@property (nonatomic, strong)   UIImage *image;
@property (nonatomic, strong)   UIButton *button;

@end

NS_ASSUME_NONNULL_END
