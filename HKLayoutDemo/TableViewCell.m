//
//  TableViewCell.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "TableViewCell.h"
#import <Masonry/Masonry.h>

@interface TableViewCell ()
@property (nonatomic, strong, nullable) UIImageView *imgView;
@property (nonatomic, strong, nullable) UILabel *titleLab;
@property (nonatomic, strong, nullable) UILabel *contentLab;
@property (nonatomic, strong, nullable) UILabel *timeLab;
@end

@implementation TableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self addSubViews];
    }
    return self;
}

- (void)addSubViews {
    self.imgView = [[UIImageView alloc] init];
    self.imageView.layer.borderColor = UIColor.redColor.CGColor;
    self.imageView.layer.borderWidth = 1.f;
    [self.contentView addSubview:self.imgView];
    __weak __typeof(self) weakSelf = self;
    [self.imgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(weakSelf.contentView.mas_top).offset(5);
        make.left.mas_equalTo(weakSelf.contentView.mas_left).offset(5);
        make.size.mas_equalTo(CGSizeMake(20, 20));
    }];
    
    self.titleLab = [[UILabel alloc] init];
    self.titleLab.font = [UIFont systemFontOfSize:44];
    self.titleLab.numberOfLines = 2;
    [self.contentView addSubview:self.titleLab];
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(weakSelf.imgView.mas_top).offset(5);
        make.left.mas_equalTo(weakSelf.imgView.mas_left);
        make.right.mas_equalTo(weakSelf.contentView.mas_right).offset(-5);
    }];
    
    self.contentLab = [[UILabel alloc] init];
    self.contentLab.font = [UIFont systemFontOfSize:36];
    self.contentLab.numberOfLines = 3;
    [self.contentView addSubview:self.contentLab];
    [self.contentLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(weakSelf.titleLab.mas_top).offset(5);
        make.left.mas_equalTo(weakSelf.titleLab.mas_left);
        make.right.mas_equalTo(weakSelf.contentView.mas_right).offset(-5);
    }];
    
    self.timeLab = [[UILabel alloc] init];
    self.timeLab.font = [UIFont systemFontOfSize:20];
    self.timeLab.numberOfLines = 1;
    [self.contentView addSubview:self.timeLab];
    [self.timeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(weakSelf.contentLab.mas_top).offset(5);
        make.left.mas_equalTo(weakSelf.contentLab.mas_left);
        make.width.mas_equalTo(weakSelf.contentView.mas_width);
    }];
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    NSLog(@"%s",__func__);
}

- (void)setCellTitle:(NSString *)title content:(NSString *)content time:(NSString *)time {
    self.titleLab.text = title;
    self.contentLab.text = content;
    self.timeLab.text = time;
    [self setNeedsLayout];
}

@end
