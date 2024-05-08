//
//  AppDelegate.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/17.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "AppDelegate.h"
#import "HKDefineTabBarController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    HKDefineTabBarController *tabVC = [[HKDefineTabBarController alloc] init];
    self.window.rootViewController = tabVC;
    [self.window makeKeyAndVisible];
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
/*
 Build Setting: Other C Flags: -fsanitize-coverage=trace-pc-guard
#include <stdio.h>
#include <sanitizer/coverage_interface.h>
#import <dlfcn.h>

void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
      static uint64_t N;
      if (start == stop || *start) return;
      printf("启动优化----INIT: %p %p\n", start, stop);
      for (uint32_t *x = start; x < stop; x++)
        *x = ++N;
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    if (!*guard) return;// 把这个注释掉 +load方法也会hook到
    void *PC = __builtin_return_address(0);
    char PcDescr[1024];
//    printf("启动优化----guard: %p %x PC %s\n", guard, *guard, PcDescr);
    
    Dl_info info;
    dladdr(PC, &info);
    NSLog(@"启动优化----name:%s\n",info.dli_sname);
}

*/
