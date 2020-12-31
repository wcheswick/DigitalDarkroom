//
//  ChannelBuf.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 12/10/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "ChannelBuf.h"

@implementation ChannelBuf

@synthesize buf, W, H;

- (id)initWithSize: (CGSize) s {
    self = [super init];
    if (self) {
        W = s.width;
        H = s.height;
        channel *b = (channel *)calloc(W*H, sizeof(channel));
        [self dataWithBytes]
        channel **b = (channel **)malloc(W*sizeof(channel *));
        for (int x=0; x<W; x++) {
            b[x] = (channel *)malloc(H*sizeof(channel));
    }
    return self;
}

- (void) dealloc {
}
   
@end
