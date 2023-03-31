//
//  ResultViewController.m
//  HKLayoutDemo
//
//  Created by hankai on 2020/7/22.
//  Copyright © 2020 Edward. All rights reserved.
//

#import "ResultViewController.h"

@interface ResultViewController ()

@end

@implementation ResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark - UISearchResultsUpdating
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    searchController.searchResultsController.view.hidden = NO;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


@end
