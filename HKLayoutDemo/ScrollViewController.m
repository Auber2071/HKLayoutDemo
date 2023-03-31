//
//  ScrollViewController.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "ScrollViewController.h"
#import "ScorllView.h"

@interface ScrollViewController ()
@property (nonatomic, strong) ScorllView *scrollView;

@end

@implementation ScrollViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self.view addSubview:self.scrollView];
}

-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self.scrollView setFrame:self.view.bounds];
    [self.scrollView setContentSize:CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame)*2.f)];
}

#pragma mark - Get Method

-(ScorllView *)scrollView{
    if (!_scrollView) {
        _scrollView = [[ScorllView alloc] init];
    }
    return _scrollView;
}

@end
