//
//  HKKVCDemo.h
//  YSC-GCD-demo
//
//  Created by ALPS on 2023/2/22.
//  Copyright © 2023 Walking Boy. All rights reserved.
//

//#import <Foundation/Foundation.h>
@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface HKKVCDemo : NSObject {
    NSString *_name;
    NSString *_isName;
    NSString *name;
    NSString *isName;
    NSInteger age;
}
@property (nonatomic, strong) NSString *testName;

@end

NS_ASSUME_NONNULL_END
