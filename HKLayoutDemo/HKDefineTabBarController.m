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
#import "HKTabBar.h"

#define __TabBarItemFontSize 12.f
#define __TabBarItemsCount 4
@interface HKDefineTabBarController ()
@property (nonatomic, strong, nullable) HKTabBar *defineTabBar;

@end

@implementation HKDefineTabBarController

+ (void)initialize {
    NSMutableDictionary *defaultAttriDict = [NSMutableDictionary dictionary];
    defaultAttriDict[NSForegroundColorAttributeName] = [UIColor grayColor];
    defaultAttriDict[NSFontAttributeName] = [UIFont systemFontOfSize:__TabBarItemFontSize];

    NSMutableDictionary *selectAttriDict = [NSMutableDictionary dictionary];
    selectAttriDict[NSForegroundColorAttributeName] = [UIColor redColor];
    selectAttriDict[NSFontAttributeName] = [UIFont systemFontOfSize:__TabBarItemFontSize];

    UITabBarItem *tabBarItem = [UITabBarItem appearance];
    [tabBarItem setTitleTextAttributes:defaultAttriDict forState:UIControlStateNormal];
    [tabBarItem setTitleTextAttributes:selectAttriDict forState:UIControlStateSelected];
}

/*
- (void)loadView {
    [super loadView];
    self.defineTabBar = [[HKTabBar alloc] init];
    self.defineTabBar.itemWidth = [[UIScreen mainScreen] bounds].size.width/ __TabBarItemsCount;
    [self setValue:self.defineTabBar forKey:@"tabBar"];
}
*/


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.redColor;
    [self setupSubTabItemsWithController:[[HKNormalViewController alloc] init] title:@"Normal"
                          defaultImgName:@"tabBar_home_icon"
                         selectedImgName:@"tabBar_home_click_icon" index:0];
    
    [self setupSubTabItemsWithController:[[HKScrollViewController alloc] init] title:@"scroll"
                          defaultImgName:@"tabBar_Middle_icon"
                         selectedImgName:@"tabBar_Middle_click_icon" index:1];
    
    [self setupSubTabItemsWithController:[[HKTableViewController alloc] init] title:@"table"
                          defaultImgName:@"tabBar_home_icon"
                         selectedImgName:@"tabBar_home_click_icon" index:2];
    
    [self setupSubTabItemsWithController:[[HKCollectionViewController alloc] init] title:@"collection"
                          defaultImgName:@"tabBar_setting_icon"
                         selectedImgName:@"tabBar_setting_click_icon" index:3];
}



- (void)setupSubTabItemsWithController:(UIViewController *)controller
                                 title:(NSString *)title
                        defaultImgName:(NSString *)defaultImgName
                       selectedImgName:(NSString *)selectedImgName
                                 index:(NSInteger)index
{
    controller.title = title;
    controller.tabBarItem.image = [[UIImage imageNamed:defaultImgName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    controller.tabBarItem.selectedImage = [[UIImage imageNamed:selectedImgName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    controller.tabBarItem.tag = index;


    HKNavigationController *navigationController = [[HKNavigationController alloc] initWithRootViewController:controller];
    controller.navigationItem.title = title;
    [self addChildViewController:navigationController];
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    [self.defineTabBar setNeedsLayout];
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
