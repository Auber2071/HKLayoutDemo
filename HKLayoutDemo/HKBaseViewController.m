//
//  HKBaseViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/14.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKBaseViewController.h"

@interface HKBaseViewController ()

@end

@implementation HKBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    //清空view所有subviews
    //[self removeAllSubviewsFromeView];
    
}
/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}


- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation {
//    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
//        SEL selector  = NSSelectorFromString(@"setOrientation:");
//        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
//        [invocation setSelector:selector];
//        [invocation setTarget:[UIDevice currentDevice]];
//        [invocation setArgument:&orientation atIndex:2];
//        [invocation invoke];
//    }
    
//    [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:YES];
//    [[UIApplication sharedApplication] setStatusBarHidden: orientation != UIInterfaceOrientationPortrait];
}


- (void)removeAllSubviewsFromeView {
    // 方式一：
    [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    // 方式二：
    [self.view.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    // 方式三：
    for (UIView *obj in self.view.subviews) {
        [obj removeFromSuperview];
    }
}

@end
