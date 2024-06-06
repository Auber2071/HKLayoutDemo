//
//  HKGCDViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/5/31.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKGCDViewController.h"
#import <objc/runtime.h>

@interface HKGCDViewController ()
@property (nonatomic, assign) int ticketSurplusCount;   //剩余火车票数
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSMutableArray *mutArray;
@end

@implementation HKGCDViewController {
    
    dispatch_semaphore_t semaphoreLock;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    /* 任务+队列 相关方法 */
    
    //    同步执行 + 并发队列               不开  有序
    //    [self syncConcurrent];
    
    //    异步执行 + 并发队列               开    无序
    //    [self asyncConcurrent];
    
    //    同步执行 + 串行队列               不开  有序
    //    [self syncSerial];
    
    //    异步执行 + 串行队列               开    有序
//        [self asyncSerial];
    
    //    同步执行 + 主队列（主线程调用）     阻塞                    同步 主队列  主线程
    //    [self syncMain];
    
    //    同步执行 + 主队列（其他线程调用）    不开  有序              同步 主队列  其他线程
    //    [NSThread detachNewThreadSelector:@selector(syncMain) toTarget:self withObject:nil];
    
    //    异步执行 + 主队列（特殊的串行队列）  ⚠️不开  有序
    //    [self asyncMain];
    
    
    /* GCD 嵌套 */
    
    //    异步执行 + 串行队列 嵌套  同步执行 + 串行队列     阻塞
    //    [self asyncSerialAndSync];
    
    //    异步执行 + 串行队列 嵌套  异步执行 + 串行队列     开  有序  + 不开  有序
//        [self asyncSerialAndAsync];
    
    //    同步执行 + 串行队列 嵌套  同步执行 + 串行队列     阻塞
//        [self syncSerialAndSync];
    
    //    同步执行 + 串行队列 嵌套  异步执行 + 串行队列     不开  有序  + 开   有序
//        [self syncSerialAndAsync];
    
    
    //    异步执行 + 并行队列 嵌套  同步执行 + 并行队列     开    无序  + 不开 有序
    //    [self asyncConcurrentAndSync];
    
    //    异步执行 + 并行队列 嵌套  异步执行 + 并行队列     开    无序  + 开   无序
    //    [self asyncConcurrentAndAsync];
    
    //    同步执行 + 并行队列 嵌套  同步执行 + 并行队列     不开  有序  + 不开  有序
    //    [self syncConcurrentAndSync];
    
    //    同步执行 + 并行队列 嵌套  异步执行 + 并行队列     不开  有序  + 开   无序
    //    [self syncConcurrentAndAsync];
    
    
    /* GCD 线程间通信 */
    
    //    [self communication];
    

    /* GCD 其他方法 */
    
    //    栅栏方法 dispatch_barrier_async
//        [self barrier];
    
    //    延时执行方法 dispatch_after
    //    [self after];
    
    //    一次性代码（只执行一次）dispatch_once
    //    [self once];
    
    //    快速迭代方法 dispatch_apply
    //    [self apply];
    
    
    /* 队列组 gropu */
    
    //    队列组 dispatch_group_notify
    //    [self groupNotify];
    
    //    队列组 dispatch_group_wait
//        [self groupWait];
    
    //    队列组 dispatch_group_enter、dispatch_group_leave
//        [self groupEnterAndLeave];
    
    
    
    /* 信号量 dispatch_semaphore */
    
    //    semaphore 线程同步
//        [self semaphoreSync];
    
    //    semaphore 线程安全
    //    非线程安全：不使用 semaphore
    //    [self initTicketStatusNotSave];
    
    //    线程安全：使用 semaphore 加锁
    //    [self initTicketStatusSave];
    
    
    /*-----------------------------*/
    
    //多线程，异步执行（async）一个performSelector 会执行么？如果加上 afterDelay呢？
//    [self test5];
    
    [self asyncAndSyncConcurrent];
}

/**
 *  GCD 主要是 函数与队列
 *  任务的快慢：CPU（时间片间切换 ）、调度（优先级）、任务复杂度  有关
 *  队列：一种数据结构。共两种：串行队列，并发队列
 *  线程  是执行任务的最小单位
 *
 *  设计一个主队列： 结构体   - 全局 - 静态变量
 */

#pragma mark - 任务+队列 相关方法
- (void)globalTest {
    __block int a = 0;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    while (a<5) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSLog(@"里面 = %d - %@", a, NSThread.currentThread);
            a++;
        });
        
    }
    NSLog(@"外面 = %d", a); // >= 5
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"外面 = %d", a); // >= 里面最大的数字 + 1
    });
    
    
    /*
     ^{
         NSLog(@"外面 = %d", a); // >= 里面最大的数字 + 1
     }
     */
    //block的执行依赖 当前的block的调度
    //GCD任务调度
}

- (void)asyncAndSyncConcurrent {
    /**
     *  1  2  3     无序
     *  0
     *  7  8  9     无序
     */
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        // 追加任务 1
        NSLog(@"1---%@",[NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        // 追加任务 2
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    dispatch_sync(queue, ^{
        // 追加任务 3
        NSLog(@"3---%@",[NSThread currentThread]);
    }); //⚠️⚠️⚠️在此处阻塞
    
    NSLog(@"0---%@",[NSThread currentThread]);

    dispatch_async(queue, ^{
        NSLog(@"7---%@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        NSLog(@"8---%@",[NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        NSLog(@"9---%@",[NSThread currentThread]);
    });
    
}


/**
 * 同步执行 + 并发队列
 * 特点：在当前线程中执行任务，不会开启新线程，执行完一个任务，再执行下一个任务。
 * 不开   有序：currentThread、syncConcurrent-begain   1   2   3   syncConcurrent-end
 */
- (void)syncConcurrent {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncConcurrent---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"syncConcurrent---end");
}

/**
 * 异步执行 + 并发队列
 * 特点：开启多个线程，任务交替（同时）执行。
 * 开    无序：currentThread    async-begain    async-end   (1 2 3 无序)
 */
- (void)asyncConcurrent {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncConcurrent---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"asyncConcurrent---end");
}

/**
 * 同步执行 + 串行队列
 * 特点：不会开启新线程，在当前线程执行任务。任务是串行的，执行完一个任务，再执行下一个任务。
 * 不开   有序：currentThread    sync-begain 1   2   3   sync-end
 */
- (void)syncSerial {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"syncSerial---end");
}

/**
 * 异步执行 + 串行队列
 * 特点：会开启新线程，但是因为任务是串行的，执行完一个任务，再执行下一个任务。
 * 开    有序：currentThread    async-begain    async-end   1   2   3
 */
- (void)asyncSerial {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(queue, ^{
        // 追加任务 1
        //[NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        // 追加任务 2
        //[NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        // 追加任务 3
        //[NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"asyncSerial---end");
}

/**
 * 同步执行 + 串行队列（主队列）
 * 特点(主线程调用)：互等卡主不执行。阻塞
 * 特点(其他线程调用)：不会开启新线程，执行完一个任务，再执行下一个任务。
 */
- (void)syncMain {
    
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncMain---begin");
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    //卡死↓
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });

    NSLog(@"syncMain---end");
}

/**
 * 异步执行 + 主队列
 * 特点：只在主线程中执行任务，执行完一个任务，再执行下一个任务
 * 不开   有序：currentThread    async-begain    async-end   1   2   3
 */
- (void)asyncMain {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncMain---begin");
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"asyncMain---end");
}

#pragma mark - 任务+队列 嵌套 相关方法

/**
 * 异步执行 + 串行队列（A） + 嵌套  A  + 同步执行
 * 特点：串行队列中追加的任务 和 串行队列中原有的任务 两者之间相互等待，阻塞穿行队列，最终串行队列所在的 线程 死锁
 * 开 阻塞： currentThread  async-begain    async-end   1 卡主
 *
 */
- (void)asyncSerialAndSync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        //⚠️⚠️⚠️死锁：
        dispatch_sync(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
    });
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"asyncSerial---end");
}

/**
 * 异步执行 + 串行队列（A） + 嵌套  A  + 异步执行
 * 特点：
 * 外层：开 有序 ：currentThread   async-begain    async-end   1   2   3   嵌套1 嵌套2 嵌套3 嵌套4（嵌套不开）
 *
 */
- (void)asyncSerialAndAsync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(queue, ^{
        // 追加任务 1
//        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        dispatch_async(queue, ^{
            // 嵌套任务 1
//            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 2
//            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 3
//            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 4
//            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 5
//            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务5---%@",[NSThread currentThread]); 
        });

        dispatch_async(queue, ^{
            // 嵌套任务 6
//            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务6---%@",[NSThread currentThread]); 
        });

    });
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"asyncSerial---end");
}


/**
 * 同步执行 + 串行队列（A） + 嵌套  A  + 同步执行
 * 特点：串行队列中追加的任务 和 串行队列中原有的任务 两者之间相互等待，阻塞穿行队列，最终串行队列所在的 线程 死锁
 * 外层：开 有序 ：currentThread   async-begain   1   卡死
 *
 */
- (void)syncSerialAndSync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        
        //卡死↓
        dispatch_sync(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
    });
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"syncSerial---end");
}

/**
 * 同步执行 + 串行队列（A） + 嵌套  A  + 异步执行
 * 外层：不开    有序：currentThread    sync-begain 1 嵌套1   嵌套2 嵌套3 嵌套4     2   3   sync-end        (嵌套 开)
 *
 */
- (void)syncSerialAndAsync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncSerial---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        dispatch_async(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
    });
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"syncSerial---end");
}


/**
 * 异步执行 + 并行队列（A） + 嵌套  A  + 异步执行
 *  开   无序 ：currentThread   async-begain    async-end   (1-start    1-end  2   3)   嵌套 开 无序(嵌套1     嵌套2     嵌套3     嵌套4)
 */
- (void)asyncConcurrentAndAsync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncConcurrent---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];                          // 模拟耗时操作
        NSLog(@"1---start:%@",[NSThread currentThread]);      
        dispatch_async(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
        NSLog(@"1---end:%@",[NSThread currentThread]);        
    });
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];                          // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);            
    });
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];                          // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);            
    });
    
    NSLog(@"asyncConcurrent---end");
}


/**
 * 异步执行 + 并行队列（A） + 嵌套  A  + 同步执行
 * 外层：开 无序  currentThread   async-begain    async-end   1   2   3   嵌套1     嵌套2     嵌套3     嵌套4     （嵌套 不开 有序）
 */
- (void)asyncConcurrentAndSync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncConcurrent---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        dispatch_sync(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
    });
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"asyncConcurrent---end");
}


/**
 * 同步执行 + 并行队列（A） + 嵌套  A  + 同步执行
 *  不开  有序：currentThread    sync-begain 1   嵌套1     嵌套2     嵌套3     嵌套4     2       3   sync-end     嵌套（不开   有序）
 */
- (void)syncConcurrentAndSync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncConcurrent---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        dispatch_sync(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_sync(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
    });
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"syncConcurrent---end");
}


/**
 * 同步执行 + 并行队列（A） + 嵌套  A  + 异步执行
 * 不开   有序：currentThread    sync-begain 1 2 3   (嵌套 开 无序) 插入在 1之后
*/
- (void)syncConcurrentAndAsync {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"syncConcurrent---begin");
    
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);

        dispatch_async(queue, ^{
            // 嵌套任务 1
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务1---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 2
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务2---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 3
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务3---%@",[NSThread currentThread]); 
        });
        dispatch_async(queue, ^{
            // 嵌套任务 4
            [NSThread sleepForTimeInterval:2];                      // 模拟耗时操作
            NSLog(@"嵌套任务4---%@",[NSThread currentThread]); 
        });
    });
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    NSLog(@"syncConcurrent---end");
}


#pragma mark - 线程间通信

/**
 * 线程间通信
 */
- (void)communication {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"communication---begin");
    
    // 获取全局并发队列
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 获取主队列
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    
    dispatch_async(queue, ^{
        // 异步追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        
        // 回到主线程
        dispatch_async(mainQueue, ^{
            // 追加在主线程中执行的任务
            [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
            NSLog(@"2---%@",[NSThread currentThread]);
        });
    });
    NSLog(@"communication---end");
}


#pragma mark - GCD 其他相关方法

/**
 * 栅栏方法 dispatch_barrier_async
 */
- (void)barrier {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"barrier---begin");
    dispatch_queue_t queue = dispatch_queue_create("net.bujige.testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        // 追加任务 2
//        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    
//    dispatch_sync(queue, ^{
//        // 追加任务 2
//        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
//        NSLog(@"2.sync---%@",[NSThread currentThread]);
//    });
    
    dispatch_barrier_sync(queue, ^{
        // 追加任务 barrier
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"barrier---%@",[NSThread currentThread]);// 打印当前线程
    });
    
    NSLog(@"2.9---%@",[NSThread currentThread]);
    
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        // 追加任务 4
//        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"4---%@",[NSThread currentThread]);
    });
    NSLog(@"barrier---end");
}

/**
 * 延时执行方法 dispatch_after
 */
- (void)after {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"after---begin");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 2.0 秒后异步追加任务代码到主队列，并开始执行
        NSLog(@"after---%@",[NSThread currentThread]);  // 打印当前线程
    });
    NSLog(@"after---end");
}

/**
 * 一次性代码（只执行一次）dispatch_once
 */
- (void)once {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"once---begin");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 只执行 1 次的代码（这里面默认是线程安全的）
        // dispatch_once_t是否为0，为0表示block 未执行
        // 执行后把token的值改为1，下次判断非0则不处理
        
    });
    NSLog(@"once---end");
}

/**
 * 快速迭代方法 dispatch_apply
 * 开 无序 ：currnetThread apply-begain     apply-end   循环无序
 */
- (void)apply {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"apply---begin");
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(6, queue, ^(size_t index) {
        NSLog(@"%zd---%@",index, [NSThread currentThread]);
    });
    NSLog(@"apply---end");
}

#pragma mark - dispatch_group 队列组

/**
 * 队列组 dispatch_group_notify
 * 开    无序：currentThread    group-begain   group-end    (1  2   3无序输出)  4   notify-end
 */
- (void)groupNotify {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"group---begin");
    
    dispatch_group_t group =  dispatch_group_create();
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 等前面的异步任务 1、任务 2 都执行完毕后，回到主线程执行下边任务
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"4---%@",[NSThread currentThread]);

        NSLog(@"notify---end");
    });
    NSLog(@"group---end");
}

/**
 * 队列组 dispatch_group_wait
 *  wait阻塞主线程： 开 有序 currentThread   group-begain    (1  2   3 无序)          group-end
 */
- (void)groupWait {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"group---begin");
    
    dispatch_group_t group =  dispatch_group_create();
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
    });
    
    // 等待上面的任务全部完成后，会往下继续执行（会阻塞当前线程）
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSLog(@"group---end");
    
}

/**
 * 队列组 dispatch_group_enter、dispatch_group_leave
 * 结果同 dispatch_group_async
 */
- (void)groupEnterAndLeave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"group---begin");
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);

        dispatch_group_leave(group);
    });
    
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
        
        dispatch_group_leave(group);
    });
    
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
        
        dispatch_group_leave(group);
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 等前面的异步操作都执行完毕后，回到主线程.
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"4---%@",[NSThread currentThread]);
    
        NSLog(@"notify---end");
    });
    NSLog(@"group---end");
}

#pragma mark - semaphore 线程同步

/**
 * semaphore 线程同步
 */
- (void)semaphoreSync {
    /*
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"semaphore---begin");
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block int number = 0;
    dispatch_sync(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);
        
        number = 100;
//        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);
        
        number = 200;
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_sync(queue, ^{
        // 追加任务 3
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);
        
        number = 300;
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"semaphore---end,number = %d",number);
    */
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
     __block int a = 0;
     while (a < 5) {
         NSLog(@"start");
         dispatch_async(dispatch_get_global_queue(0, 0), ^{
             NSLog(@"里面的a的值：%d-----%@", a, [NSThread currentThread]);
             dispatch_semaphore_signal(semaphore);
             a++;
         });
         NSLog(@"wait");
         dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
     }
     NSLog(@"外面的a的值：%d", a);
}



#pragma mark - semaphore 线程安全
/**
 * 非线程安全：不使用 semaphore
 * 初始化火车票数量、卖票窗口（非线程安全）、并开始卖票
 */
- (void)initTicketStatusNotSave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"semaphore---begin");
    
    self.ticketSurplusCount = 50;
    
    // queue1 代表北京火车票售卖窗口
    dispatch_queue_t queue1 = dispatch_queue_create("net.bujige.testQueue1", DISPATCH_QUEUE_SERIAL);
    // queue2 代表上海火车票售卖窗口
    dispatch_queue_t queue2 = dispatch_queue_create("net.bujige.testQueue2", DISPATCH_QUEUE_SERIAL);
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(queue1, ^{
        [weakSelf saleTicketNotSafe];
    });

    dispatch_async(queue2, ^{
        [weakSelf saleTicketNotSafe];
    });
}

/**
 * 售卖火车票（非线程安全）
 */
- (void)saleTicketNotSafe {
    while (1) {
        
        if (self.ticketSurplusCount > 0) {  //如果还有票，继续售卖
            self.ticketSurplusCount--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%d 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else { // 如果已卖完，关闭售票窗口
            NSLog(@"所有火车票均已售完");
            break;
        }
        
    }
}

/**
 * 线程安全：使用 semaphore 加锁
 * 初始化火车票数量、卖票窗口（线程安全）、并开始卖票
 */
- (void)initTicketStatusSave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"semaphore---begin");
    
    semaphoreLock = dispatch_semaphore_create(1);
    
    self.ticketSurplusCount = 50;
    
    // queue1 代表北京火车票售卖窗口
    dispatch_queue_t queue1 = dispatch_queue_create("net.bujige.testQueue1", DISPATCH_QUEUE_SERIAL);
    // queue2 代表上海火车票售卖窗口
    dispatch_queue_t queue2 = dispatch_queue_create("net.bujige.testQueue2", DISPATCH_QUEUE_SERIAL);
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(queue1, ^{
        [weakSelf saleTicketSafe];
    });

    dispatch_async(queue2, ^{
        [weakSelf saleTicketSafe];
    });
}

/**
 * 售卖火车票（线程安全）
 */
- (void)saleTicketSafe {
    while (1) {
        // 相当于加锁
        dispatch_semaphore_wait(semaphoreLock, DISPATCH_TIME_FOREVER);
        
        if (self.ticketSurplusCount > 0) {  // 如果还有票，继续售卖
            self.ticketSurplusCount--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%d 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else { // 如果已卖完，关闭售票窗口
            NSLog(@"所有火车票均已售完");
            
            // 相当于解锁
            dispatch_semaphore_signal(semaphoreLock);
            break;
        }
        
        // 相当于解锁
        dispatch_semaphore_signal(semaphoreLock);
    }
}

- (void)test {
    dispatch_queue_t queueConcurrent = dispatch_queue_create("net.bujige.testQueue1", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queueMain = dispatch_get_main_queue();
    NSLog(@"1---%@",[NSThread currentThread]);        
    dispatch_async(queueConcurrent, ^{
        NSLog(@"2---%@",[NSThread currentThread]);    
        dispatch_sync(queueMain, ^{
            NSLog(@"3---%@",[NSThread currentThread]);
        });
    });
    NSLog(@"4---%@",[NSThread currentThread]);        

}



- (void)printNSArrayMethods
{
    u_int count;
    Method *methods = class_copyMethodList([NSArray class], &count);
    for (int i = 0; i < count ; i++)
    {
        Method method = methods[i];
        SEL sel = method_getName(method);
        NSLog(@"%d---%@", i, NSStringFromSelector(sel));
    }
    free(methods);
}



#pragma mark - performSelector
- (void)testPerformSelector
{
    NSLog(@"3 - %@", [NSThread currentThread]);
}

// 1、2、3、4
/**
 原因： 因为 performSelector:withObject: 会在当前线程立即执行指定的 selector 方法。
 */
- (void)test1
{
    NSLog(@"1 - %@", [NSThread currentThread]);

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
    
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                   withObject:nil];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}


// 1、2、4
/**
 原因： 因为 performSelector:withObject:afterDelay: 实际是往 RunLoop 里面注册一个定时器，而在子线程中，RunLoop 是没有开启（默认）的，所有不会输出 3。
 */
- (void)test2
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                   withObject:nil
                   afterDelay:0];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}


// 1、2、3、4
/**
 原因： 由于 [[NSRunLoop currentRunLoop] run]; 会创建的当前子线程对应的 RunLoop 对象并启动了，因此可以执行 test 方法；并且 test 执行完后，RunLoop 中注册的定时器已经无效，所以还可以输出 4 （对比 例子⑥例子）
 */
- (void)test3
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                   withObject:nil
                   afterDelay:0];
        [[NSRunLoop currentRunLoop] run];
        NSLog(@"4 - %@", [NSThread currentThread]);
        
    });
}


// 1、2、3、4
/**
 输出结果：1，2，3，4
 原因： 因为 performSelector:onThread:withObject:waitUntilDone: 会在指定的线程执行，而执行的策略根据参数 wait 处理，这里传 YES 表明将会立即阻断 指定的线程 并执行指定的 selector。
 */
- (void)test4
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                     onThread:[NSThread currentThread]
                   withObject:nil
                waitUntilDone:YES];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}
    
// 1、2、4
/**
 原因： 因为 performSelector:onThread:withObject:waitUntilDone: 会在指定的线程执行，而执行的策略根据参数 wait 处理，这里传 NO 表明不会立即阻断 指定的线程 而是将 selector 添加到指定线程的 RunLoop 中等待时机执行。（该例子中，子线程 RunLoop 没有启动，所有没有输出 3）
 */
- (void)test5
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                     onThread:[NSThread currentThread]
                   withObject:nil
                waitUntilDone:NO];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}
    
// 1、2、3
/**
 原因： 由于 [[NSRunLoop currentRunLoop] run]; 已经创建的当前子线程对应的 RunLoop 对象并启动了，因此可以执行 test 方法；但是 test 方法执行完后，RunLoop 并没有结束（使用这种启动方式，RunLoop 会一直运行下去，在此期间会处理来自输入源的数据，并且会在 NSDefaultRunLoopMode 模式下重复调用 runMode:beforeDate: 方法）所以无法继续输出 4。
 */
- (void)test6
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                     onThread:[NSThread currentThread]
                   withObject:nil
                waitUntilDone:NO];
        [[NSRunLoop currentRunLoop] run];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}
    
// 1、2、3
/**
 原因： 由于 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]]; 已经创建的当前子线程对应的 RunLoop 对象并启动了，因此可以执行 test 方法；但是 test 方法执行完后，RunLoop 并没有结束（使用这种启动方式，可以设置超时时间，在超时时间到达之前，runloop会一直运行，在此期间runloop会处理来自输入源的数据，并且会在 NSDefaultRunLoopMode 模式下重复调用 runMode:beforeDate: 方法）所以无法继续输出 4。
 */
- (void)test7
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                     onThread:[NSThread currentThread]
                   withObject:nil
                waitUntilDone:NO];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}
    
// 1、2、3、4
/**
 原因： 由于 [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]; 已经创建的当前子线程对应的 RunLoop 对象并启动了，因此可以执行 test 方法；而且 test 方法执行完后，RunLoop 立刻结束（使用这种启动方式 ，RunLoop 会运行一次，超时时间到达或者第一个 input source 被处理，则 RunLoop 就会退出）所以可以继续输出 4。
 */
- (void)test8
{
    NSLog(@"1 - %@", [NSThread currentThread]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"2 - %@", [NSThread currentThread]);
        [self performSelector:@selector(testPerformSelector)
                     onThread:[NSThread currentThread]
                   withObject:nil
                waitUntilDone:NO];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate distantFuture]];
        NSLog(@"4 - %@", [NSThread currentThread]);
    });
}

/**
 常用 performSelector 方法

 常用的 perform，是 NSObject.h 头文件下的方法：

 - (id)performSelector:(SEL)aSelector;
 - (id)performSelector:(SEL)aSelector withObject:(id)object;
 - (id)performSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;

 
 可以 delay 的 perform，是 NSRunLoop.h 头文件下的方法：

 - (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay inModes:(NSArray<NSRunLoopMode> *)modes;
 - (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay;

 
 可以 指定线程 的 perform，是 NSThread 头文件下的方法：

 - (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait modes:(nullable NSArray<NSString *> *)array;
 - (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
 - (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(nullable id)arg waitUntilDone:(BOOL)wait modes:(nullable NSArray<NSString *> *)array;
 - (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
 - (void)performSelectorInBackground:(SEL)aSelector withObject:(nullable id)arg;

 
 RunLoop 退出方式：

 使用 - (void)run; 启动，RunLoop 会一直运行下去，在此期间会处理来自输入源的数据，并且会在 NSDefaultRunLoopMode 模式下重复调用 runMode:beforeDate: 方法；
 
 使用 - (void)runUntilDate:(NSDate *)limitDate； 启动，可以设置超时时间，在超时时间到达之前，RunLoop 会一直运行，在此期间 RunLoop 会处理来自输入源的数据，并且也会在 NSDefaultRunLoopMode 模式下重复调用 runMode:beforeDate: 方法；
 
 使用 - (void)runMode:(NSString *)mode beforeDate:(NSDate *)limitDate; 启动，RunLoop 会运行一次，超时时间到达或者第一个 input source 被处理，则 RunLoop 就会退出。

 */
//参考：https://juejin.cn/post/6844903775816122375

#pragma mark - imageNamed：底层会进行对图片的解码和绘制
- (void)subThreadSetImage {

    /*
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.image = [UIImage imageNamed:@"timg"];
    */
    
    
    // 换成如下方法
    UIImageView *imageView = [[UIImageView alloc] init];
    self.imageView = imageView;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 获取CGImage
        CGImageRef cgImage = [UIImage imageNamed:@"timg"].CGImage;
        // alphaInfo
        CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage) & kCGBitmapAlphaInfoMask;
        BOOL hasAlpha = NO;
        if (alphaInfo == kCGImageAlphaPremultipliedLast ||
            alphaInfo == kCGImageAlphaPremultipliedFirst ||
            alphaInfo == kCGImageAlphaLast ||
            alphaInfo == kCGImageAlphaFirst) {
            hasAlpha = YES;
        }
        // bitmapInfo
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host; bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
        // size
        size_t width = CGImageGetWidth(cgImage);
        size_t height = CGImageGetHeight(cgImage);
        // context
        CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, CGColorSpaceCreateDeviceRGB(), bitmapInfo);
        // draw
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
        // get
        cgImage = CGBitmapContextCreateImage(context);
        // into UIImage
        UIImage *newImage = [UIImage imageWithCGImage:cgImage];
        // release
        CGContextRelease(context);
        CGImageRelease(cgImage);
        // back to the main thread dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = newImage;
    });

}

@end
