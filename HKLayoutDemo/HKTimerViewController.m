//
//  HKTimerViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/4/17.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKTimerViewController.h"
#import "NSTimer+WeakTimer.h"

@interface HKTimerViewController ()

//使用NSProxy
@property (nonatomic, strong) NSTimer *proxyTimer;
@property (nonatomic, strong) NSTimer *blockTimer;


@end

@implementation HKTimerViewController

- (void)viewDidLoad {

    [super viewDidLoad];
    self.title = @"VC1";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.proxyTimer = [NSTimer zx_scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerHandle) userInfo:nil repeats:YES];
    
    // 或
    
    @weakify(self)
    self.blockTimer = [NSTimer zx_scheduledTimerWithTimeInterval:1.0 repeats:YES handlerBlock:^{
        @strongify(self)
        [self timerHandle];
    }];
}

//定时触发的事件
- (void)timerHandle {
    
     NSLog(@"正在计时中。。。。。。");
}

- (void)dealloc {
   
    [self.proxyTimer invalidate];
    self.proxyTimer = nil;
    
    [self.blockTimer invalidate];
    self.blockTimer = nil;
    NSLog(@"%s",__func__);
}

@end

