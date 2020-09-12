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
    BackCamera,
    NotACamera,
} cameras;

#define NCAMERA (BackCamera+1)

@interface InputSource : NSObject {
    cameras sourceType;
    NSString *label;
    UIImage *image;
}

@property (assign)  cameras sourceType;
@property (nonatomic, strong)   NSString *label;
@property (nonatomic, strong)   UIImage *image;

@end

NS_ASSUME_NONNULL_END
