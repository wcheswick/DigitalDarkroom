//
//  ColorTable.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 10/21/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * We precompute a lookup table for all the color changes.
 * But we don't the time and space to compute all 2^24 color
 * translations, and don't need to.
 */
#define COLOR_FUDGE    (1<<2)

@interface ColorTable : NSObject

@end

NS_ASSUME_NONNULL_END
