//
//  ReticleView.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 4/8/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "ReticleView.h"

@implementation ReticleView

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 1.0f);
    CGPoint center = CGPointMake(rect.size.width/2.0, rect.size.height/2.0);
    CGFloat tickLen = rect.size.height/20.0;
    CGContextMoveToPoint(context, center.x-tickLen, center.y);
    CGContextAddLineToPoint(context, center.x+tickLen, center.y);
    CGContextStrokePath(context);
    CGContextMoveToPoint(context, center.x, center.y-tickLen);
    CGContextAddLineToPoint(context, center.x, center.y+tickLen);
    CGContextStrokePath(context);
}

@end
