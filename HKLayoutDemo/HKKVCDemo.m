//
//  HKKVCDemo.m
//  YSC-GCD-demo
//
//  Created by ALPS on 2023/2/22.
//  Copyright © 2023 Walking Boy. All rights reserved.
//

#import "HKKVCDemo.h"

@implementation HKKVCDemo



+ (BOOL)accessInstanceVariablesDirectly {
    return YES;//默认YES
}

- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"valueForUndefinedKey: 出现异常，该key不存在%@", key);
    return nil;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"setValue:forUndefinedKey: 出现异常，该key不存在%@", key);
}

- (void)setNilValueForKey:(NSString *)key {
    NSLog(@"不能将%@设置为nil", key);
}

- (void)setTestName:(NSString *)testName {
    _testName = testName;
}

@end
