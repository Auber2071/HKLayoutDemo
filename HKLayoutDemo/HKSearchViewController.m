//
//  HKSearchViewController.m
//  HKLayoutDemo
//
//  Created by hankai on 2020/7/22.
//  Copyright © 2020 Edward. All rights reserved.
//

#import "HKSearchViewController.h"
#import "HKResultViewController.h"

@interface HKSearchViewController ()<UISearchControllerDelegate, UISearchBarDelegate>
@property (nonatomic, strong, nullable) UISearchController *searchController;
@property (nonatomic, strong, nullable) UIButton *button;
@property (nonatomic, strong, nullable) UIButton *button2;
@property (nonatomic, strong, nullable) UIButton *button3;

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, copy) void(^blk)(void);
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger count;

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSArray *array;
@property (nonatomic, copy) NSArray *arrayCopy;
@property (nonatomic, strong) UIView *backView;


@end

@implementation HKSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray *array1 = @[@1, @2, @3, @4];
    NSMutableArray *mutableArray = [NSMutableArray arrayWithArray:array1];
    self.array = mutableArray;
    self.arrayCopy = mutableArray;
    NSLog(@"self.array:%@", self.array);
    NSLog(@"self.arrayCopy:%@", self.arrayCopy);
    [mutableArray removeAllObjects];
    NSLog(@"self.array:%@", self.array);
    NSLog(@"self.arrayCopy:%@", self.arrayCopy);
    
    self.count = 0;
    
    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.button setTitle:@"back" forState:UIControlStateNormal];
    [self.button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    self.button.titleLabel.font = [UIFont systemFontOfSize:30];
    
    self.navigationItem.title = @"Test SearchController";
    self.navigationController.navigationBar.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.3];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.button];
    
        
    self.backView = [[UIView alloc] init];
    self.backView.opaque = YES;

    [self.view addSubview:self.backView];
    
    HKResultViewController *resultVC = [[HKResultViewController alloc] init];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:resultVC];
    self.searchController.searchResultsUpdater = resultVC;
    self.searchController.searchBar.delegate = self;
    self.searchController.hidesNavigationBarDuringPresentation = YES;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    [self.backView addSubview:self.searchController.searchBar];
    
    [self.backView addSubview:self.button2];
    
    //[self.button3 addSubview:self.label];
    [self.backView addSubview:self.button3];
    
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.backView.frame = self.view.bounds;
    CGFloat searchBarWidth = CGRectGetWidth(self.view.frame) - 60 * 2;
    CGFloat searchBarHeight = 60;
    [self.searchController.searchBar sizeThatFits:CGSizeMake(searchBarWidth, searchBarHeight)];
    self.searchController.searchBar.frame = CGRectMake(60, 100, searchBarWidth, searchBarHeight);
    
    self.button2.frame = CGRectMake(30, 300, 100, 40);
    self.button3.frame = CGRectMake(CGRectGetMaxX(self.button2.frame) + 10, 300, 100, 40);
    self.label.frame = CGRectMake(10, 10, 40, 20);
}


- (UIButton *)button2 {
    if (!_button2) {
        _button2 = [UIButton buttonWithType:UIButtonTypeCustom];
        [_button2 setTitle:@"组合透明度" forState:UIControlStateNormal];
        [_button2 setBackgroundColor:UIColor.whiteColor];
        [_button2 setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        //_button2.alpha = 0.5;
        _button2.layer.cornerRadius = 5.f;
        [_button2 addTarget:self action:@selector(button2Action) forControlEvents:UIControlEventTouchUpInside];
    }
    return _button2;
}

- (void)button2Action {
    CGAffineTransform transform = CGAffineTransformIdentity;
    //scale by 50%
    CGAffineTransform transform1 = CGAffineTransformScale(transform, 0.5, 0.5);
    //rotate by 30 degrees
    CGAffineTransform transform2 = CGAffineTransformRotate(transform, M_PI / 180.0 * 30.0);
    transform = CGAffineTransformConcat(transform1, transform2);
    //translate by 200 points
    //transform = CGAffineTransformTranslate(transform, 200, 0);
    //apply transform to layer
    [UIView animateWithDuration:3 animations:^{
        self.button2.layer.affineTransform = transform;
    }];
    
}

- (UIButton *)button3 {
    if (!_button3) {
        _button3 = [UIButton buttonWithType:UIButtonTypeCustom];
        [_button3 setBackgroundColor:UIColor.whiteColor];
        [_button3 setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        _button3.layer.shouldRasterize = YES;
        _button3.alpha = 0.5;
        _button3.layer.cornerRadius = 5.f;
        [_button3 addTarget:self
                     action:@selector(clickButton3Action)
           forControlEvents:UIControlEventTouchUpInside];
    }
    return _button3;
}

- (UILabel *)label {
    if (!_label) {
        _label = [[UILabel alloc] init];
        _label.text = @"label";
        _label.backgroundColor = UIColor.whiteColor;
        _label.textColor = UIColor.blackColor;
        _label.layer.cornerRadius = 5.f;
        //_label.layer.shouldRasterize = YES;
        _label.alpha = 0.5;
    }
    return _label;
}


- (void)clickButton3Action {
    NSLog(@"%s", __func__);
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"%s", __func__);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"%s", __func__);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    NSLog(@"%s", __func__);
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSLog(@"%s", __func__);
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    /*
      __weak typeof(self) weakSelf = self;
      self.blk = ^{
          __strong typeof(self) strongSelf = weakSelf;
          //5秒后执行
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              NSLog(@"sssssssss");
              NSLog(@"%@", strongSelf);
          });
      };
      self.blk();
      //[self dismissViewControllerAnimated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
    */
    /*
    self.image = [[UIImage alloc] init];
    __weak typeof(self) weakSelf = self;

    self.timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(timermethod) userInfo:nil repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
    self.image.code3 = 3;
    self.timer.code1 = 1;
    self.timer.code2 = 2;
    self.timer.code3 = 33;
    
//    self.timer = [NSTimer zx_scheduledTimerWithTimeInterval:1 repeats:YES handlerBlock:^{
//        
//    }];
    */
    

}


- (void)timermethod {
    
    
    self.count += 1;
}


- (void)dealloc
{
    
    NSLog(@"%s xxxxxxxxxxxxx", __func__);
    NSLog(@"%@", self.timer);
}

- (void)buttonClick {
    [self.navigationController popViewControllerAnimated:YES];
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
