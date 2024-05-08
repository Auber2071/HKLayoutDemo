//
//  HKScorllView.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "HKScorllView.h"

@interface HKScorllView()
@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation HKScorllView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        [self addSubview:self.titleLabel];
    }
    return self;
}

-(void)layoutSubviews{
    [super layoutSubviews];
    NSLog(@"%s",__func__);
    [self.titleLabel setFrame:CGRectMake(0, 200, CGRectGetWidth(self.frame), 60)];
}

#pragma mark - Get Method

-(UILabel *)titleLabel{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"ScrollView";
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLabel;
}

@end
