//
//  HKTestSearchController.m
//  HKLayoutDemo
//
//  Created by hankai on 2020/7/22.
//  Copyright © 2020 Edward. All rights reserved.
//

#import "HKTestSearchController.h"
#import "ResultViewController.h"
#import "UIImage+category.h"

@interface HKTestSearchController ()<UISearchControllerDelegate, UISearchBarDelegate>
@property (nonatomic, strong, nullable) UISearchController *searchController;
@property (nonatomic, strong, nullable) UIButton *button;

@end

@implementation HKTestSearchController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.button setTitle:@"back" forState:UIControlStateNormal];
    [self.button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    self.button.titleLabel.font = [UIFont systemFontOfSize:30];
    
    self.navigationItem.title = @"Test SearchController";
    self.navigationController.navigationBar.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.3];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.button];
    
        
    ResultViewController *resultVC = [[ResultViewController alloc] init];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:resultVC];
    self.searchController.searchResultsUpdater = resultVC;
    self.searchController.searchBar.delegate = self;
    self.searchController.hidesNavigationBarDuringPresentation = YES;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    [self.view addSubview:self.searchController.searchBar];
}

- (void)buttonClick {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat searchBarWidth = CGRectGetWidth(self.view.frame) - 60 * 2;
    CGFloat searchBarHeight = 60;
    [self.searchController.searchBar sizeThatFits:CGSizeMake(searchBarWidth, searchBarHeight)];
    self.searchController.searchBar.frame = CGRectMake(60, 100, searchBarWidth, searchBarHeight);
}

#pragma mark - UISearchControllerDelegate
- (void)didPresentSearchController:(UISearchController *)searchController {
    searchController.searchResultsController.view.hidden = NO;
}

#pragma mark - UISearchBarDelegate
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
    for (id obj in [searchBar subviews]) {
        if ([obj isKindOfClass:[UIView class]]) {
            for (id obj2 in [obj subviews]) {
                if ([obj2 isKindOfClass:[UIButton class]]) {
                    UIButton *btn = (UIButton *)obj2;
                    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
                    [btn setTitle:@"取消" forState:UIControlStateNormal];
                    btn.titleLabel.font = [UIFont systemFontOfSize:42];
                }
            }
        }
    }
    return YES;
}
@end
