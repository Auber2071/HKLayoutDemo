//
//  HKDefineTabBarController.m
//  TestDemo
//
//  Created by Edward on 2018/4/10.
//  Copyright © 2018年 hankai. All rights reserved.
//

#import "HKDefineTabBarController.h"
#import "HKNavigationController.h"
#import "HKNormalViewController.h"
#import "HKScrollViewController.h"
#import "HKTableViewController.h"
#import "HKCollectionViewController.h"

#define __TabBarItemFontSize 12.f
@interface HKDefineTabBarController ()

@end

@implementation HKDefineTabBarController

+ (void)initialize {
    NSMutableDictionary *defaultAttriDict = [NSMutableDictionary dictionary];
    defaultAttriDict[NSForegroundColorAttributeName] = [UIColor redColor];
    defaultAttriDict[NSFontAttributeName] = [UIFont systemFontOfSize:__TabBarItemFontSize];

    NSMutableDictionary *selectAttriDict = [NSMutableDictionary dictionary];
    selectAttriDict[NSForegroundColorAttributeName] = [UIColor redColor];
    selectAttriDict[NSFontAttributeName] = [UIFont systemFontOfSize:__TabBarItemFontSize];

    UITabBarItem *tabBarItem = [UITabBarItem appearance];
    [tabBarItem setTitleTextAttributes:defaultAttriDict forState:UIControlStateNormal];
    [tabBarItem setTitleTextAttributes:selectAttriDict forState:UIControlStateSelected];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.redColor;
    [self setupSubTabItemsWithController:[[HKNormalViewController alloc] init] title:@"Normal"
                          defaultImgName:@"tabBar_home_icon"
                         selectedImgName:@"tabBar_home_click_icon"];
    
    [self setupSubTabItemsWithController:[[HKScrollViewController alloc] init] title:@"scroll"
                          defaultImgName:@"tabBar_setting_icon"
                         selectedImgName:@"tabBar_setting_click_icon"];
    
    [self setupSubTabItemsWithController:[[HKTableViewController alloc] init] title:@"table"
                          defaultImgName:@"tabBar_home_icon"
                         selectedImgName:@"tabBar_home_click_icon"];
    
    [self setupSubTabItemsWithController:[[HKCollectionViewController alloc] init] title:@"collection"
                          defaultImgName:@"tabBar_setting_icon"
                         selectedImgName:@"tabBar_setting_click_icon"];
}



- (void)setupSubTabItemsWithController:(UIViewController *)controller
                                 title:(NSString *)title
                        defaultImgName:(NSString *)defaultImgName
                       selectedImgName:(NSString *)selectedImgName
{
    controller.title = title;
    controller.tabBarItem.image = [[UIImage imageNamed:defaultImgName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    controller.tabBarItem.selectedImage = [[UIImage imageNamed:selectedImgName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    HKNavigationController *navigationController = [[HKNavigationController alloc] initWithRootViewController:controller];
    controller.navigationItem.title = title;
    [self addChildViewController:navigationController];
}

- (BOOL)shouldAutorotate {
    return [self.selectedViewController shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.selectedViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [self.selectedViewController preferredInterfaceOrientationForPresentation];
}





@end
