//
//  HKScrollViewController.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "HKScrollViewController.h"
#import "HKScorllView.h"

@interface HKScrollViewController ()
@property (nonatomic, strong) HKScorllView *scrollView;

@end

@implementation HKScrollViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.scrollView];
}

-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self.scrollView setFrame:self.view.bounds];
    [self.scrollView setContentSize:CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame)*2.f)];
}

#pragma mark - Get Method

-(HKScorllView *)scrollView{
    if (!_scrollView) {
        _scrollView = [[HKScorllView alloc] init];
    }
    return _scrollView;
}

@end
