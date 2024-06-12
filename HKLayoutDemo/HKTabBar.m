//
//  HKTabBar.m
//  TabBarPop
//
//  Created by Edward on 2019/3/27.
//  Copyright © 2019 Edward. All rights reserved.
//

#import "HKTabBar.h"
#import "HKButton.h"
#import <Masonry/Masonry.h>

@interface HKTabBar()<CAAnimationDelegate>
@property (nonatomic, strong, nullable) UIImageView *popImgView;
//@property (nonatomic, strong, nullable) UIView *popView;
//@property (nonatomic, strong, nullable) UIButton *button;

@end

@implementation HKTabBar

- (instancetype)init
{
    self = [super init];
    if (self) {
        //self.barTintColor = [UIColor redColor];//tabBar背景色
        self.tintColor = [UIColor orangeColor];
        self.unselectedItemTintColor = [UIColor blackColor];
        self.itemPositioning = UITabBarItemPositioningCentered;
//        [self addSubview:self.popView];
//        [self shakeToShow:self.popImgView];
        [self addSubview:self.popImgView];
//        [self addSubview:self.button];
    }
    return self;
}


- (void)layoutSubviews {
    [super layoutSubviews];
//    self.button.frame = CGRectMake(0, -60, 100, 80);
    CGRect tempFrame = self.popImgView.frame;
    tempFrame.origin.x = (self.itemSpacing + self.itemWidth)/2 - self.popImgView.frame.size.width/2 + (self.itemSpacing + self.itemWidth) * self.selectedItem.tag;
    tempFrame.origin.y = -self.popImgView.frame.size.height;
    self.popImgView.frame = tempFrame;

}

- (void)setNeedsLayout {
    self.popImgView.hidden = false;
    [super setNeedsLayout];
    [self shakeToShow:self.popImgView];
}

/*
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    CGPoint tempPoint = [self.button convertPoint:point fromView:self];
    if ([self.button pointInside:tempPoint withEvent:event]) {
        return self.button;
    }
    return view;
}
*/

- (UIImageView *)popImgView {
    if (!_popImgView) {
        _popImgView = [[UIImageView alloc] initWithImage: [UIImage imageNamed:@"tabBar_Middle_click_icon"]];
        _popImgView.frame = CGRectMake(0, 0, 60, 60);
        _popImgView.layer.borderColor = UIColor.blueColor.CGColor;
        _popImgView.layer.borderWidth = 1.f;

    }
    return _popImgView;
}

/*
- (UIView *)popView {
    if (!_popView) {
        _popView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
        _popView.layer.cornerRadius = CGRectGetHeight(_popView.frame)/2.f;
        _popView.layer.masksToBounds = YES;
        _popView.backgroundColor = UIColor.redColor;
    }
    return _popView;
}
*/

- (void) shakeToShow:(UIView*)aView{
    CAKeyframeAnimation* animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    animation.duration = 1.5;
    NSMutableArray *values = [NSMutableArray array];
    
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.1, 0.1, 1.0)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(1.0, 1.0, 1.0)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.1, 0.1, 1.0)]];
    animation.values = values;
    animation.repeatCount = 1;
    animation.delegate = self;
    aView.layer.anchorPoint = CGPointMake(0.5,0.5);
    
    [aView.layer addAnimation:animation forKey:nil];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    if (view == nil) {
        for (UIView *subView in self.subviews) {
            if ([subView isKindOfClass:[HKButton class]]) {
                CGPoint tp = [subView convertPoint:point fromView:self];
                if (CGRectContainsPoint(subView.bounds, tp)) {
                    view = subView;
                }
            }

        }
    }
    return view;
}

/*
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event{

    for (UIView * sub in self.subviews) {

        CGPoint po = [self convertPoint:point toView:sub];

        if (CGRectContainsPoint(sub.bounds, po)) {
            return YES;
        }
    }

    return [super pointInside:point withEvent:event];
}
 */
#pragma mark - CAAnimationDelegate

- (void)animationDidStart:(CAAnimation *)anim {
    
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (flag) {
        self.popImgView.hidden = true;
    }
}

@end
