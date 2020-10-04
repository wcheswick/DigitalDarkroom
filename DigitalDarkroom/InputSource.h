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
    Front3DCamera,
    Rear3DCamera,
    NotACamera,
} Cameras;

#define NCAMERA (NotACamera)
#define ISCAMERA(i) ((i) < NCAMERA)
#define IS_2D_CAMERA(i)    ((i) < Front3DCamera)
#define IS_3D_CAMERA(i)    ((i) == Front3DCamera || (i) == Rear3DCamera)

@interface InputSource : NSObject {
    Cameras sourceType;
    NSString *label;
    NSString *imagePath;
    CGSize imageSize;
    UIButton *button;
}

@property (assign)  Cameras sourceType;
@property (nonatomic, strong)   NSString *label;
@property (nonatomic, strong)   NSString *imagePath;
@property (nonatomic, strong)   UIButton *button;
@property (assign)              CGSize imageSize;

@end

NS_ASSUME_NONNULL_END
