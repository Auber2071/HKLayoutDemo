//
//  HKReadWhiteSafeDic.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/4/16.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKReadWhiteSafeDic.h"

@interface HKReadWhiteSafeDic()
@property (nonatomic, strong) dispatch_queue_t concurrent_queue;   // 定义一个并发队列
@property (nonatomic, strong) NSMutableDictionary *userCenterDic;   // 用户数据中心, 可能多个线程需要数据访问

@end

// 多读单写模型
@implementation HKReadWhiteSafeDic

- (id)init {
    self = [super init];
    if (self) {
        // 通过宏定义 DISPATCH_QUEUE_CONCURRENT 创建一个并发队列
        self.concurrent_queue = dispatch_queue_create("read_write_queue", DISPATCH_QUEUE_CONCURRENT);
        // 创建数据容器
        self.userCenterDic = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)objectForKey:(NSString *)key {
    __block id obj;
//    读操作为啥同步dispatch_sync
//    读的话通常都是直接想要结果，需要同步返回结果，如果是异步获取的话就根网络请求一样了。
    
    // 同步读取指定数据
    dispatch_sync(self.concurrent_queue, ^{
        obj = [self.userCenterDic objectForKey:key];
    });
    return obj;
}

- (void)setObject:(id)obj forKey:(NSString *)key {

//    写操作为啥异步dispatch_barrier_async
//    写操作是因为不需要等待写操作完成，所以用异步。

    // 异步栅栏调用设置数据
    dispatch_barrier_async(self.concurrent_queue, ^{
        [self.userCenterDic setObject:obj forKey:key];
    });
}

@end



#pragma mark - TKReadWhiteSafeDic

#import <pthread.h>
@interface TKReadWhiteSafeDic() {
    // 声明一个读写锁
   pthread_rwlock_t  lock;
  // 定义一个并发队列
    dispatch_queue_t concurrent_queue;
    // 用户数据中心, 可能多个线程需要数据访问
    NSMutableDictionary *userCenterDic;
}

@end

// 多读单写模型
@implementation TKReadWhiteSafeDic

- (id)init {
    self = [super init];
    if (self) {
      //初始化读写锁
      pthread_rwlock_init(&lock,NULL);
      // 创建数据容器
       userCenterDic = [NSMutableDictionary dictionary];
      // 通过宏定义 DISPATCH_QUEUE_CONCURRENT 创建一个并发队列
      concurrent_queue = dispatch_queue_create("read_write_queue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (id)objectForKey:(NSString *)key {
    //加读锁
    pthread_rwlock_rdlock(&lock);
    id obj = [userCenterDic objectForKey:key];
    pthread_rwlock_unlock(&lock);
    return obj;
}

- (void)setObject:(id)obj forKey:(NSString *)key {
     //加写锁
    pthread_rwlock_wrlock(&lock);
    [userCenterDic setObject:obj forKey:key];
    pthread_rwlock_unlock(&lock);
}
@end
