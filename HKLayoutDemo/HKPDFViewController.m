//
//  HKPDFViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/11.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKPDFViewController.h"

#if TARGET_OS_SIMULATOR
@implementation HKPDFViewController
/*
- (instancetype)init {
    NSURL *documentURL = [NSBundle.mainBundle URLForResource:@"C Primer Plus 第6版" withExtension:@"pdf"];
    PSPDFDocument *document = [[PSPDFDocument alloc] initWithURL:documentURL];
    self = [super initWithDocument:document];
    if (self) {

    }
    return self;
}
*/

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    //[self setPositionViewEnabled:NO];

}
@end
#else
    // 真机上的代码
#endif
