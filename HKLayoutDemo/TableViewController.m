//
//  TableViewController.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "TableViewController.h"
#import "TableView.h"
#import "TableViewCell.h"

@interface TableViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) TableView *tableView;

@end

@implementation TableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self.view addSubview:self.tableView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.tableView setFrame:self.view.bounds];
}


#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 40;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Identifier"];
    if (!cell) {
        cell = [[TableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Identifier"];
        cell.backgroundColor = [UIColor whiteColor];
    }
    [cell setCellTitle:@"夏天只是西瓜做的一个梦，超甜超甜超甜的夏夏天只是西瓜做的一个梦，超甜超甜超甜的夏"
               content:@"现在生活的节奏如此之快，我们又有多少时间现在生活的节奏如此之快，我们又有多少时间现在生活的节奏如此之快，我们又有多少时间现在生活的节奏如此之快，我们又有多少时间"
                  time:@"2021年6月15日"];
    return cell;
}

#pragma mark - UITableViewDelegate
//
/*
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return CGRectGetHeight(self.view.frame)/3.f*2.f;
}
*/

#pragma mark - Get Method

-(TableView *)tableView{
    if (!_tableView) {
        _tableView = [[TableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor whiteColor];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        //_tableView.estimatedRowHeight = 44;
        _tableView.rowHeight = UITableViewAutomaticDimension;
    }
    return _tableView;
}

@end
