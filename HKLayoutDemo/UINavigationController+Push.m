//
//  UINavigationController+Push.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/14.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "UINavigationController+Push.h"

@implementation UINavigationController (Push)
- (void)hk_pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (animated) {
        viewController.hidesBottomBarWhenPushed = YES;
    }
    [self hk_pushViewController:viewController animated:animated];
}

+ (void)load {
    [self yscDefenderSwizzlingInstanceMethod:@selector(hk_pushViewController:animated:)
                                  withMethod:@selector(pushViewController:animated:)
                                   withClass:[UINavigationController class]];
}

@end
