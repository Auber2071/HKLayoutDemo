//
//  HKNetViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/5/30.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKNetViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIKit+AFNetworking.h>
#import <SDWebImage/SDWebImage.h>


@interface HKNetViewController ()
@property (nonatomic, strong) UIImageView *imgView;
@property (nonatomic, strong) UIBarButtonItem *downloadBarBtnItem;
@property (nonatomic, strong) UIBarButtonItem *resetBarBtnItem;
@end

@implementation HKNetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.navigationItem.rightBarButtonItems = @[self.downloadBarBtnItem, self.resetBarBtnItem];
    [self.view addSubview:self.imgView];
    
    [self.imgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.mas_equalTo(self.view);
    }];
}


#pragma mark - private method
- (void)downloadAction {
    
    NSString *imgUrl = @"https://img2.baidu.com/it/u=3178257605,3200738192&fm=253&fmt=auto&app=138&f=JPEG?w=800&h=1730";
    //[self.imgView setImageWithURL: [NSURL URLWithString:imgUrl]];
    
    [self.imgView sd_setImageWithURL:[NSURL URLWithString:imgUrl] placeholderImage:[UIImage imageNamed:@"tabBar_setting_click_icon"] options:SDWebImageDelayPlaceholder];
    
    return;
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    BOOL isImageSerializer = false;
    if (isImageSerializer) {
        //方式一：
        manager.responseSerializer = [AFImageResponseSerializer serializer];
    } else {
        //方式二：
        //manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"image/jpeg", nil];
    }
    
    [manager GET:imgUrl parameters:nil headers:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        NSLog(@"进度 -%@", downloadProgress);
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (isImageSerializer) {
            //方式一：
            self.imgView.image = responseObject;
        } else {
            //方式二：
            self.imgView.image = [UIImage imageWithData:responseObject];
        }
        NSLog(@"线程 -%@", [NSThread currentThread]);//printLog：<_NSMainThread: 0x60000170c000>{number = 1, name = main}
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"errpr= %@", error);
    }];
    
}

- (void)resetAction {
    self.imgView.image = nil;
}

#pragma mark - get

- (UIImageView *)imgView {
    if (!_imgView) {
        _imgView = [[UIImageView alloc] init];
    }
    return _imgView;
}

- (UIBarButtonItem *)downloadBarBtnItem {
    if (!_downloadBarBtnItem) {
        _downloadBarBtnItem = [[UIBarButtonItem alloc] initWithTitle:@"下载" style:UIBarButtonItemStyleDone target:self action:@selector(downloadAction)];
    }
    return _downloadBarBtnItem;
}

- (UIBarButtonItem *)resetBarBtnItem {
    if (!_resetBarBtnItem) {
        _resetBarBtnItem = [[UIBarButtonItem alloc] initWithTitle:@"重置" style:UIBarButtonItemStyleDone target:self action:@selector(resetAction)];
    }
    return _resetBarBtnItem;
}


@end
