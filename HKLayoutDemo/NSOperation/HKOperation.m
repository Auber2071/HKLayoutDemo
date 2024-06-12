//
//  HKOperation.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/3/11.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKOperation.h"

@implementation HKOperation

- (void)main {
    if (!self.isCancelled) {
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"1--%d--%@", i, [NSThread currentThread]);
        }
    }
}

@end
