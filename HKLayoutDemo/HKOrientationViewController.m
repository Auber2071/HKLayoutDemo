//
//  HKOrientationViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/14.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKOrientationViewController.h"

@interface HKOrientationViewController ()
@property (nonatomic, assign) BOOL isLandscapeRight;
@property (nonatomic, strong, nullable) UIButton *button;
@property (nonatomic, strong) UILabel *label1;
@property (nonatomic, strong) UIView *view1;

@property (nonatomic, assign) UIInterfaceOrientation lastOrientation;
@end

@implementation HKOrientationViewController
- (void)dealloc
{
    [self endOrientationNotification];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.label1];
    [self.view addSubview:self.view1];
    [self.view addSubview:self.button];
    self.lastOrientation = [UIApplication sharedApplication].windows.firstObject.windowScene.interfaceOrientation;
    
    
    [self startOrientationNotification];
}


#pragma mark - 测试旋转相关api

- (void)startOrientationNotification {
    // 在开始监听设备方向变化时
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interfaceOrientationDidChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)endOrientationNotification {
    // 在停止监听设备方向变化时
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    //销毁 设备旋转 通知
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidChangeStatusBarOrientationNotification
                                                  object:nil];
}
// 监听设备方向变化的方法
- (void)deviceOrientationDidChange:(NSNotification *)notification {
    UIDevice *device = [notification object];
    UIDeviceOrientation currentOrientation = device.orientation;
    
    switch (currentOrientation) {
        case UIDeviceOrientationPortrait:
            NSLog(@"device 手机正立");
            break;
        case UIDeviceOrientationLandscapeLeft:
            NSLog(@"device 手机左转");
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            NSLog(@"device 手机倒立");
            break;
        case UIDeviceOrientationLandscapeRight:
            NSLog(@"device 手机右转");
            break;
        case UIDeviceOrientationUnknown:
            NSLog(@"device 未知");
            break;
        case UIDeviceOrientationFaceUp:
            NSLog(@"device 手机屏幕朝上");
            break;
        case UIDeviceOrientationFaceDown:
            NSLog(@"device 手机屏幕朝下");
            break;
        default:
            break;
    }
}


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    NSLog(@"interface view size width:%ld, height:%ld", (long)size.width, (long)size.height);
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // 这里是转换过程中的动画
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // 转换完成后的操作
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].windows.firstObject.windowScene.interfaceOrientation;
        
        if (orientation != self.lastOrientation) {
            // 发生了旋转
            self.lastOrientation = orientation;
            [self interfaceOrientationChange:orientation isNotificaton:NO];
        }
    }];
}

/**屏幕旋转的通知回调*/
- (void)interfaceOrientationChange:(UIInterfaceOrientation)sender isNotificaton:(BOOL)isNoti {
    switch (sender) {
        case UIInterfaceOrientationUnknown:
            NSLog(@"interface 未知 isNotification:%@", isNoti ? @"YES" : @"NO");
            break;
        case UIInterfaceOrientationPortrait:
            NSLog(@"interface 屏幕竖直 isNotification:%@", isNoti ? @"YES" : @"NO");
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            NSLog(@"interface 屏幕倒立 isNotification:%@", isNoti ? @"YES" : @"NO");
            break;
        case UIInterfaceOrientationLandscapeLeft:
            NSLog(@"interface 手机水平，home键在左边 isNotification:%@", isNoti ? @"YES" : @"NO");
            break;
        case UIInterfaceOrientationLandscapeRight:
            NSLog(@"interface 手机水平，home键在右边 isNotification:%@", isNoti ? @"YES" : @"NO");
            break;
        default:
            break;
    }
        
}

- (void)interfaceOrientationDidChange:(NSNotification *)notification {
    UIApplication *application = [notification object];
    UIInterfaceOrientation orientation = application.windows.firstObject.windowScene.interfaceOrientation;
    [self interfaceOrientationChange:orientation isNotificaton:YES];
}

/**
 * 通常情况下，一个视图控制器的`supportedInterfaceOrientations`属性在视图控制器的生命周期中只被询问一次，
 * 即在视图控制器被添加到视图层次结构时。
 *
 * 但是，如果你需要在视图控制器已经显示后动态地改变它支持的界面方向，
 * 你就需要调用`setNeedsUpdateOfSupportedInterfaceOrientations`来触发系统的重新询问。
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    
    return UIInterfaceOrientationMaskPortrait;

//    if (@available(iOS 16.0, *)) {
//        if (self.isLandscapeRight) {
//            return UIInterfaceOrientationMaskLandscapeRight;
//        } else {
//            return UIInterfaceOrientationMaskPortrait;
//        }
//    } else {
//    }
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    self.isLandscapeRight = !self.isLandscapeRight;
//    
//    if (@available(iOS 16.0, *)) {
//           [self setNeedsUpdateOfSupportedInterfaceOrientations];
//       } else {
//           //TODO：
        [self setInterfaceOrientation:self.isLandscapeRight ? UIInterfaceOrientationLandscapeLeft : UIInterfaceOrientationPortrait];
//    }
}



#pragma mark - System Method

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGSize circleSize = CGSizeMake(100, 100);
    CGFloat padding = (CGRectGetWidth(self.view.frame) - circleSize.width * 2) / 3;
    self.label1.frame = CGRectMake(padding, 100,
                                   circleSize.width, circleSize.height);
    self.view1.frame = CGRectMake(CGRectGetMaxX(self.label1.frame) + padding, 100,
                                  circleSize.width, circleSize.height);
    
    self.button.frame = CGRectMake(0, CGRectGetMaxY(self.view1.frame) + 40,
                                   CGRectGetWidth(self.view.frame) - 60 * 2, 60);
    self.button.centerX = CGRectGetWidth(self.view.frame) / 2.f;
}

- (void)buttonClick {

}

- (UIButton *)button {
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        [_button setTitle:@"button" forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
        [_button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        _button.titleLabel.font = [UIFont systemFontOfSize:30];
        _button.layer.borderColor = UIColor.grayColor.CGColor;
        _button.layer.borderWidth = 1.f;
    }
    return _button;
}

- (UILabel *)label1 {
    if (!_label1) {
        _label1 = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
        _label1.backgroundColor = [UIColor purpleColor];
        _label1.layer.cornerRadius = 50.f;
        _label1.layer.masksToBounds = YES;
    }
    return _label1;
}

- (UIView *)view1 {
    if (!_view1) {
        _view1 = [[UIView alloc] initWithFrame:CGRectMake(250, 100, 100, 100)];
        _view1.backgroundColor = UIColor.blueColor;
        _view1.layer.cornerRadius = 50.f;
    }
    return _view1;
}

@end
