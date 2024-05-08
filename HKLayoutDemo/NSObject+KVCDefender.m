//
//  NSObject+KVCDefender.m
//  HKLayoutDemo
//
//  Created by ALPS on 2023/12/1.
//  Copyright © 2023 Edward. All rights reserved.
//

#import "NSObject+KVCDefender.h"

@implementation NSObject (KVCDefender)

// 不建议拦截 `setValue:forKey:` 方法，会影响系统逻辑判断
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        // 拦截 `setValue:forKey:` 方法，替换自定义实现
        [NSObject yscDefenderSwizzlingInstanceMethod:@selector(setValue:forKey:)
                                       withMethod:@selector(ysc_setValue:forKey:)
                                        withClass:[NSObject class]];

    });
}

- (void)ysc_setValue:(id)value forKey:(NSString *)key {
    if (key == nil) {
        NSString *crashMessages = [NSString stringWithFormat:@"*** Crash Message: [<%@ %p> setNilValueForKey]: could not set nil as the value for the key %@. ***",NSStringFromClass([self class]),self,key];
        NSLog(@"%@", crashMessages);
        return;
    }

    [self ysc_setValue:value forKey:key];
}

- (void)setNilValueForKey:(NSString *)key {
    NSString *crashMessages = [NSString stringWithFormat:@"*** Crash Message: [<%@ %p> setNilValueForKey]: could not set nil as the value for the key %@. ***",NSStringFromClass([self class]),self,key];
    NSLog(@"%@", crashMessages);
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSString *crashMessages = [NSString stringWithFormat:@"*** Crash Message: [<%@ %p> setValue:forUndefinedKey:]: this class is not key value coding-compliant for the key: %@,value:%@'. ***",NSStringFromClass([self class]),self,key,value];
    NSLog(@"%@", crashMessages);
}

- (nullable id)valueForUndefinedKey:(NSString *)key {
    NSString *crashMessages = [NSString stringWithFormat:@"*** Crash Message: [<%@ %p> valueForUndefinedKey:]: this class is not key value coding-compliant for the key: %@. ***",NSStringFromClass([self class]),self,key];
    NSLog(@"%@", crashMessages);
    
    return self;
}

@end
