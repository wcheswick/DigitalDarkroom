//
//  ExecuteNote.h
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/22/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Defines.h"

NS_ASSUME_NONNULL_BEGIN

#define UNINITIALIZED_P  (-1)

@interface ExecuteNote : NSObject {
    int p, updatedP;          // variable layout parameter, and new value if != to p
    PixelIndex_t * _Nullable remapTable;
}

@property (assign)  int p, updatedP;
@property (assign)  PixelIndex_t * _Nullable remapTable;

- (void) clearRemap;

@end

NS_ASSUME_NONNULL_END
