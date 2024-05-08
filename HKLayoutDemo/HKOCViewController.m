//
//  HKOCViewController.m
//  HKLayoutDemo
//
//  Created by hankai on 2021/12/27.
//  Copyright © 2021 Edward. All rights reserved.
//

#import "HKOCViewController.h"

@interface HKOCViewController ()

@end

@implementation HKOCViewController

+ (void)load {
    NSLog(@"load------%s", __func__);
}

+ (void)initialize {
    NSLog(@"initialize--------%s", __func__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = UIColor.whiteColor;
   
    
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
