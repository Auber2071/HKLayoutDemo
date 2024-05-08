//
//  UIView+Rect.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/14.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "UIView+Rect.h"

@implementation UIView (Rect)
- (void)setX:(CGFloat)x
{
    self.frame = CGRectMake(x, self.y, self.width, self.height);
}

- (CGFloat)x
{
    return CGRectGetMinX(self.frame);
}

- (void)setY:(CGFloat)y
{
    CGRect frame = CGRectMake(self.x, y, self.width, self.height);
    self.frame = frame;
}

- (CGFloat)y
{
    return CGRectGetMinY(self.frame);
}

- (void)setWidth:(CGFloat)width
{
    CGRect frame = CGRectMake(self.x, self.y, width, self.height);
    self.frame = frame;
}

- (CGFloat)width
{
    return CGRectGetWidth(self.frame);
}

- (void)setHeight:(CGFloat)height
{
    CGRect frame = CGRectMake(self.x, self.y, self.width, height);
    self.frame = frame;
}

- (CGFloat)height
{
    return CGRectGetHeight(self.frame);
}

- (void)setSize:(CGSize)size
{
    CGRect frame = CGRectMake(self.x, self.y, size.width, size.height);
    self.frame = frame;
}

- (CGSize)size
{
    return self.frame.size;
}

- (void)setOrigin:(CGPoint)origin
{
    CGRect frame = CGRectMake(origin.x, origin.y, self.width, self.height);
    self.frame = frame;
}

- (CGPoint)origin
{
    return self.frame.origin;
}

- (CGFloat)centerX
{
    return self.center.x;
}

- (void)setCenterX:(CGFloat)newCenterX
{
    self.center = CGPointMake(newCenterX, self.center.y);
}

- (CGFloat)centerY
{
    return self.center.y;
}

- (void)setCenterY:(CGFloat)newCenterY
{
    self.center = CGPointMake(self.center.x, newCenterY);
}

@end
