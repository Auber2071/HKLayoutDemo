//
//  HKTableViewController.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "HKTableViewController.h"

#define kDesc @"description"
#define kClassName @"className"

@interface HKTableViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) HKTableView *tableView;
@property (nonatomic, strong) NSArray *dataSource;
@end

@implementation HKTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.tableView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.tableView setFrame:self.view.bounds];
}




#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = NSStringFromClass([HKTableViewCell class]);
    HKTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[HKTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    NSDictionary *dict = self.dataSource[indexPath.row];
    [cell configureWithData:dict[kDesc] className:dict[kClassName]];
    return cell;
}



#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *className = self.dataSource[indexPath.row][kClassName];
    UIViewController *vc;
    if ([className isEqualToString:@"HKSwiftViewController"]) {
        vc = [[HKSwiftViewController alloc] init];
    } else {
        vc = [[NSClassFromString(className) alloc] init];
        vc.navigationItem.title = self.dataSource[indexPath.row][kDesc];
    }
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Get Method

- (HKTableView *)tableView{
    if (!_tableView) {
        _tableView = [[HKTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor whiteColor];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.estimatedRowHeight = 44;
        _tableView.rowHeight = UITableViewAutomaticDimension;
        //注意：如果你的 cell 中有异步加载的内容（如网络图片），你可能需要在内容加载完成后调用 tableView 的 beginUpdates 和 endUpdates 方法来刷新 cell 的高度。同时，确保在刷新高度时不要引起无限循环或不必要的重绘。
    }
    return _tableView;
}

- (NSArray *)dataSource {
    if (!_dataSource) {
        _dataSource = @[@{kDesc: @"PDF文件的加载",
                          kClassName: @"HKPDFViewController"},
                        
                        @{kDesc: @"搜索相关功能",
                          kClassName: @"HKSearchViewController"},
                        
                        @{kDesc: @"UIDeviceOrientation & UIInterfaceOrientation",
                          kClassName: @"HKOrientationViewController"},
                        
                        @{kDesc: @"Swift 相关",
                          kClassName: @"HKSwiftViewController"},
                        
                        @{kDesc: @"NSTimer",
                          kClassName: @"HKTimerViewController"},
                        
                        @{kDesc: @"Net",
                          kClassName: @"HKNetViewController"},
                        
                        @{kDesc: @"GCD",
                          kClassName: @"HKGCDViewController"},
                        
        ];
        
    }
    return _dataSource;
}

@end

#pragma mark - HKTableView
@implementation HKTableView

- (void)layoutSubviews {
    [super layoutSubviews];
//    NSLog(@"%s",__func__);
}

@end

#pragma mark - HKTableViewCell
#import <Masonry/Masonry.h>

@interface HKTableViewCell ()
@property (nonatomic, strong, nullable) UIImageView *imgView;
@property (nonatomic, strong, nullable) UILabel *titleLab;
@property (nonatomic, strong, nullable) UILabel *contentLab;
@property (nonatomic, strong, nullable) UILabel *timeLab;

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UILabel *classLabel;

@end

@implementation HKTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self addSubViews];
    }
    return self;
}

- (void)addSubViews {
    // 初始化你的子视图，比如一个 UILabel
    self.label = [[UILabel alloc] init];
    self.label.textColor = UIColor.blackColor;
    self.label.font = [UIFont systemFontOfSize:14];
    self.label.numberOfLines = 0; // 多行显示
    self.label.lineBreakMode = NSLineBreakByWordWrapping; // 文字换行方式
    [self.contentView addSubview:self.label];
    
    self.classLabel = [[UILabel alloc] init];
    self.classLabel.font = [UIFont systemFontOfSize:11];
    self.classLabel.textColor = UIColor.grayColor;
    self.classLabel.numberOfLines = 0; // 多行显示
    self.classLabel.lineBreakMode = NSLineBreakByWordWrapping; // 文字换行方式
    [self.contentView addSubview:self.classLabel];
    
    
    // 使用 Masonry 设置约束
    [self.label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView.mas_top).with.offset(10);
        make.left.equalTo(self.contentView.mas_left).with.offset(10);
        make.right.equalTo(self.contentView.mas_right).with.offset(-10);
        make.bottom.equalTo(self.classLabel.mas_top).with.offset(-10);
    }];

    
    [self.classLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.label.mas_bottom).with.offset(10);
        make.left.equalTo(self.contentView.mas_left).with.offset(10);
        make.right.equalTo(self.contentView.mas_right).with.offset(-10);
        make.bottom.equalTo(self.contentView.mas_bottom).with.offset(-10);
    }];
    
    /*
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
    */
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
//    NSLog(@"%s",__func__);
}

- (void)configureWithData:(NSString *)data className:(NSString *)className {
    // 设置 cell 的内容
    self.label.text = data;
    self.classLabel.text = className;
    
    // 强制立即布局，确保约束生效
    [self.label layoutIfNeeded];
    [self.classLabel layoutIfNeeded];
}

/*
- (void)setCellTitle:(NSString *)title content:(NSString *)content time:(NSString *)time {
    self.titleLab.text = title;
    self.contentLab.text = content;
    self.timeLab.text = time;
    [self setNeedsLayout];
    
    // 强制立即布局，确保约束生效
    [self.titleLab layoutIfNeeded];
    [self.contentLab layoutIfNeeded];
    [self.timeLab layoutIfNeeded];
}
*/

@end

