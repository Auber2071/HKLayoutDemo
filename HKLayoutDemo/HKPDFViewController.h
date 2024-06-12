//
//  HKPDFViewController.h
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/11.
//  Copyright © 2024 Edward. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "PSPDFViewController.h"
#import "HKBaseViewController.h"

#if TARGET_OS_SIMULATOR

NS_ASSUME_NONNULL_BEGIN

@interface HKPDFViewController : HKBaseViewController//PSPDFViewController
//- (instancetype)initWithURL:(NSURL *)documentURL;
@end

NS_ASSUME_NONNULL_END

#else
    // 真机上的代码
#endif

