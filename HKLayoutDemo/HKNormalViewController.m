//
//  HKNormalViewController.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "HKNormalViewController.h"
#import "HKOperation.h"

@interface HKNormalViewController ()
@property (nonatomic, strong, nullable) UIButton *button;
@property (nonatomic, strong) UILabel *label1;
@property (nonatomic, strong) UIView *view1;

/* 剩余火车票数 */
@property (nonatomic, assign) int ticketSurplusCount;
@property (readwrite, nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, strong) NSRecursiveLock *recursiveLock;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) NSInteger semaphoreSareCount;
@end

@implementation HKNormalViewController

+ (void)load {
    NSLog(@"load------%s", __func__);
}

+ (void)initialize {
    NSLog(@"initialize--------%s", __func__);
}


- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.label1];
    [self.view addSubview:self.view1];
    [self.view addSubview:self.button];
    
    
    
    
    //    [self barrier];
    //    [self methodLockA];
    //    [self methodSemaphoreSync];
    //    [self methodSemaphoreSafe];
    //    [self methoddBlock2];
    
    [self threadTest];
    //    [self operationTestDemo];
    //    [self mutBlock3];
    //    [self mutBlock4:^{
    //        NSLog(@"mutBlock4:%@", self);
    //    }];

}

- (void)mutBlock4:(dispatch_block_t)block {
    block();
    NSLog(@"Stack Block: %@", [block class]);//Stack Block: __NSStackBlock__
}

- (void)mutBlock3 {
    NSMutableArray *arr = [NSMutableArray arrayWithObjects:@"1", @"2", nil];
    NSLog(@"old:%p----%@",&arr, arr);
    
    void (^myBlock)(void) = ^{
        [arr addObject:@"4"];
        NSLog(@"new:%p----%@",&arr, arr);
    };
    [arr addObject:@"3"];
    
    arr = nil;
    
    myBlock();
}

- (void)methodLockA {
    //self.lock = [[NSLock alloc] init];
    self.recursiveLock = [[NSRecursiveLock alloc] init];
    NSLog(@"lockA begain");
    [self.recursiveLock lock];
    [self methodLockB];
    NSLog(@"%s",__func__);
    [self.recursiveLock unlock];
    NSLog(@"lockA end");
}

- (void)methodLockB {
    NSLog(@"lockB begain");
    [self.recursiveLock lock];
    // 操作逻辑
    NSLog(@"%s",__func__);
    [self.recursiveLock unlock];
    NSLog(@"lockB end");
}

- (void)methodSemaphoreSafe {
    // 初始化信号量是1
    _semaphore = dispatch_semaphore_create(1);
    
    for (NSInteger i = 0; i < 100; i++) {
        // 异步并发调用asyncTask
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self asyncTask];
        });
    }
}
- (void)asyncTask {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    self.semaphoreSareCount ++;
    sleep(1);
    NSLog(@"执行任务：%zd", self.semaphoreSareCount);
    dispatch_semaphore_signal(_semaphore);
}

- (void)methoddBlock {
    // 在函数栈上创建的blk，如果没有截获自动变量，Block的结构实例还是会被设置在程序的全局数据区，而非栈上
    
    void (^blk)(void) = ^{ // 没有截获自动变量的Block
        NSLog(@"Stack Block");
    };
    blk();
    NSLog(@"%@",[blk class]); // 打印：__NSGlobalBlock__
    
    int i = 1;
    void (^captureBlk)(void) = ^{ // 截获自动变量i的Block
        NSLog(@"Capture:%d", i);
    };
    captureBlk();
    NSLog(@"%@",[captureBlk class]); // 打印：__NSMallocBlock__
    
    //
    // 没有截获自动变量的Block 打印的类是NSGlobalBlock，表示存储在全局数据区。
    // 捕获自动变量的Block 打印的类却是设置在堆上的NSMallocBlock，而非栈上的NSStackBlock。
}

- (void)methoddBlock2 {
    int count = 0;
    void (^blk)(void) = ^(){
        NSLog(@"In Stack: %d", count);
    };
    
    NSLog(@"blk's Class: %@", [blk class]); // blk's Class: __NSMallocBlock__
    NSLog(@"Global Block: %@", [^{ NSLog(@"Global Block"); } class]); // Global Block: __NSGlobalBlock__
    NSLog(@"Copy Block: %@", [[^{ NSLog(@"Copy Block:%d",count); } copy] class]); // Copy Block: __NSMallocBlock__
    NSLog(@"Stack Block: %@", [^{ NSLog(@"Stack Block:%d",count); } class]); // Stack Block: __NSStackBlock__
}



- (void)methodSemaphoreSync {
    // 信号量初始化必须大于等于0，因为dispatch_semaphore_wait执行的是-1操作。
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // 创建异步队列
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    NSLog(@"semaphore begain");
    // 异步并发
    dispatch_async(queue, ^{
        sleep(1);
        NSLog(@"执行任务: A");
        // 让信号量+1
        dispatch_semaphore_signal(semaphore);
    });
    
    // 当前的信号量值=0时，会阻塞线程；如果大于0的话，信号量-1，不阻塞线程。(相当于加锁)
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    // 异步并发
    dispatch_async(queue, ^{
        //sleep(1);
        NSLog(@"执行任务: B");
        // 让信号量+1（相当于解锁）
        dispatch_semaphore_signal(semaphore);
    });
    //    NSLog(@"semaphore mid");
    
    // 当前的信号量值=0时，会阻塞线程；如果大于0的话，信号量-1，不阻塞线程。
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    // 异步并发
    dispatch_async(queue, ^{
        sleep(1);
        NSLog(@"执行任务: C");
        dispatch_semaphore_signal(semaphore);
    });
    
    NSLog(@"semaphore end");
}

- (void)threadTest {
    _queue = dispatch_queue_create("com.htmi.Zc", DISPATCH_QUEUE_CONCURRENT);
    //    [self barrier];
    NSLog(@"currentThread：%@", [NSThread currentThread]);
    //主线程
    [self performSelector:@selector(printLog) withObject:nil afterDelay:1];
    
    //会开辟子线程
    //   [self performSelectorInBackground:@selector(printLog) withObject:nil];
    //    [NSThread detachNewThreadSelector:@selector(printLog) toTarget:self withObject:@"构造器方式"];
    
    /**
     对于自己创建的队列，如果两个参数一样，那么创建的是两个不同的队列，如下所示queue1和queue2是不同的队列。
     
     // 打印两个队列的地址发现是不同的队列
     */
    // dispatch_queue_t queue1 = dispatch_queue_create("abc", DISPATCH_QUEUE_SERIAL);
    // dispatch_queue_t queue2 = dispatch_queue_create("abc", DISPATCH_QUEUE_SERIAL);
    // NSLog(@"dispatch_queue_create:%p ---- %p", queue1, queue2);
    
    
    
    /**
     对于全局队列，如果两个参数一样，那么获取的是同一个队列，如下所示queue1和queue2是同一个队列。
     
     // 打印两个队列的地址发现是同一个队列
     */
    // dispatch_queue_t globalQueue1 = dispatch_get_global_queue(0, 0);
    // dispatch_queue_t globalQueue2 = dispatch_get_global_queue(0, 0);
    // NSLog(@"dispatch_get_global_queue:%p ---- %p", globalQueue1, globalQueue2);
    
    
    /*
     NSLog(@"begain");
     dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
     NSLog(@"low 1");
     NSLog(@"low 3");
     NSLog(@"%@", [NSThread currentThread]);
     });
     
     
     dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
     NSLog(@"high 1");
     NSLog(@"high 3");
     NSLog(@"%@", [NSThread currentThread]);
     
     });
     
     NSLog(@"end");
     */
}

- (void)printLog {
    NSLog(@"printLog：%@", [NSThread currentThread]);
    NSLog(@"2");
}

#pragma mark - NSOperation

- (void)operationTestDemo {
    //    同步
    
    //    在当前线程使用子类 NSInvocationOperation
    //    [self useInvocationOperation];
    
    //    在其他线程使用子类 NSInvocationOperation
    //    [NSThread detachNewThreadSelector:@selector(useInvocationOperation) toTarget:self withObject:nil];
    
    //    在当前线程使用 NSBlockOperation
    //    [self useBlockOperation];
    
    //    使用 NSBlockOperation 的 AddExecutionBlock: 方法
    //    [self useBlockOperationAddExecutionBlock];
    
    //    使用自定义继承自 NSOperation 的子类
    //    [self useCustomOperation];
    
    
    //    异步
    //    使用addOperation: 添加操作到队列中
    //    [self addOperationToQueue];
    
    //    使用 addOperationWithBlock: 添加操作到队列中
    //    [self addOperationWithBlockToQueue];
    
    //    设置最大并发操作数（MaxConcurrentOperationCount）
    //    [self setMaxConcurrentOperationCount];
    
    //    设置优先级
    //    [self setQueuePriority];
    
    //    添加依赖
    //    [self addDependency];
    
    //    线程间的通信
    //    [self communication];
    
    //    完成操作
    //    [self completionBlock];
    
    //    不考虑线程安全
    //    [self initTicketStatusNotSave];
    
    //    考虑线程安全
    //    [self initTicketStatusSave];
}

- (void)task1 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"task1--%d--%@", i, [NSThread currentThread]);     // 打印当前线程
    }
}

- (void)task2 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"task2--%d--%@", i, [NSThread currentThread]);     // 打印当前线程
    }
}

/**
 * 使用子类 NSInvocationOperation
 */
- (void)useInvocationOperation {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"useInvocationOperation---start");
    
    // 1.创建 NSInvocationOperation 对象
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task1) object:nil];
    
    // 2.调用 start 方法开始执行操作
    [op start];
    
    NSLog(@"useInvocationOperation---end");
}

/**
 * 使用子类 NSBlockOperation
 */
- (void)useBlockOperation {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"useBlockOperation---begin");
    
    // 1.创建 NSBlockOperation 对象
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 2.调用 start 方法开始执行操作
    [op start];
    NSLog(@"useBlockOperation---end");
}

/**
 * 使用子类： NSBlockOperation
 * 调用方法 AddExecutionBlock:
 */
- (void)useBlockOperationAddExecutionBlock {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"useBlockOperationAddExecutionBlock---start");
    // 1.创建 NSBlockOperation 对象
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"0-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 2.添加额外的操作
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"3-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"4-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"5-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"6-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"7-%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 3.调用 start 方法开始执行操作
    [op start];
    NSLog(@"useBlockOperationAddExecutionBlock---end");
    
}

/**
 * 使用自定义继承自 NSOperation 的子类
 */
- (void)useCustomOperation {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"useCustomOperation---start");
    // 1.创建 HKOperation 对象
    HKOperation *op = [[HKOperation alloc] init];
    // 2.调用 start 方法开始执行操作
    [op start];
    NSLog(@"useCustomOperation---end");
}

/**
 * 使用 addOperation: 将操作加入到操作队列中
 */
- (void)addOperationToQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"addOperationToQueue---start");
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.创建操作
    // 使用 NSInvocationOperation 创建操作1
    NSInvocationOperation *op1 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task1) object:nil];
    
    // 使用 NSInvocationOperation 创建操作2
    NSInvocationOperation *op2 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task2) object:nil];
    
    // 使用 NSBlockOperation 创建操作3
    NSBlockOperation *op3 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"task3--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [op3 addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"task4--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 3.使用 addOperation: 添加所有操作到队列中
    [queue addOperation:op1]; // [op1 start]
    [queue addOperation:op2]; // [op2 start]
    [queue addOperation:op3]; // [op3 start]
    NSLog(@"addOperationToQueue---end");
}

/**
 * 使用 addOperationWithBlock: 将操作加入到操作队列中
 */
- (void)addOperationWithBlockToQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"addOperationWithBlockToQueue---start");
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.使用 addOperationWithBlock: 添加操作到队列中
    [queue addOperationWithBlock:^{
        NSLog(@"0--%d--%@", 0, [NSThread currentThread]); // 打印当前线程
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"3--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    NSLog(@"addOperationWithBlockToQueue---end");
}

/**
 * 设置 MaxConcurrentOperationCount（最大并发操作数）
 */
- (void)setMaxConcurrentOperationCount {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"setMaxConcurrentOperationCount---start");
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.设置最大并发操作数
    queue.maxConcurrentOperationCount = 1; // 默认值是-1；如果值设为0，那么不会执行任何任务； 串行队列 开批新线程
    
    // 3.添加操作
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"3--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            //            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"4--%d--%@", i, [NSThread currentThread]); // 打印当前线程
        }
    }];
    NSLog(@"setMaxConcurrentOperationCount---end");
    
}

/**
 * 设置优先级
 * 就绪状态下，优先级高的会优先执行，但是执行时间长短并不是一定的，所以优先级高的并不是一定会先执行完毕
 */
- (void)setQueuePriority
{
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"setQueuePriority---start");
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        //        [NSThread sleepForTimeInterval:2];
        NSLog(@"1-----%@", [NSThread currentThread]);
    }];
    
    
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        //        [NSThread sleepForTimeInterval:2];
        NSLog(@"2-----%@", [NSThread currentThread]);
    }];
    
    [op2 addDependency:op1];
    
    [op1 setQueuePriority:(NSOperationQueuePriorityLow)];
    [op2 setQueuePriority:(NSOperationQueuePriorityHigh)];
    
    
    
    [queue addOperations:@[op1, op2] waitUntilFinished:NO];
    
    NSLog(@"setQueuePriority---end");
    
    /**
     优先执行的意思是 系统会优先执行优先级高的任务。但是优先执行并不代表着 这个任务一定会最先执行完毕。
     比如说 op1 比 op2 优先级高，系统优先执行 op1，0.01秒之后执行 op2。但是 op1执行了2秒，op2执行了1秒。
     所以最终显示的结果是 op2 先执行完毕，op1 后执行完毕。
     我们就会以为系统先执行的 op2，后执行的 op1。其实不然。
     */
}

/**
 * 操作依赖
 * 使用方法：addDependency:
 */
- (void)addDependency {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"addDependency---start");
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.创建操作
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 3.添加依赖
    [op2 addDependency:op1];    // 让op2 依赖于 op1，则先执行op1，在执行op2
    
    // 4.添加操作到队列中
    [queue addOperations:@[op1, op2] waitUntilFinished:YES];
    
    NSLog(@"addDependency---end");
}

/**
 * 线程间通信
 */
- (void)communication {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"communication---start");
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc]init];
    
    // 2.添加操作
    [queue addOperationWithBlock:^{
        // 异步进行耗时操作
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
        
        // 回到主线程
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // 进行一些 UI 刷新等操作
            for (int i = 0; i < 2; i++) {
                [NSThread sleepForTimeInterval:2];      // 模拟耗时操作
                NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
            }
        }];
    }];
    NSLog(@"communication---end");
}

/**
 * 完成操作 completionBlock
 */
- (void)completionBlock {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"completionBlock---start");
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.创建操作
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 3.添加完成操作
    op1.completionBlock = ^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    };
    
    // 4.添加操作到队列中
    [queue addOperation:op1];
    NSLog(@"completionBlock---end");
}

#pragma mark - 线程安全
/**
 * 非线程安全：不使用 NSLock
 * 初始化火车票数量、卖票窗口(非线程安全)、并开始卖票
 */
- (void)initTicketStatusNotSave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"initTicketStatusNotSave---start");
    
    self.ticketSurplusCount = 50;
    
    // 1.创建 queue1,queue1 代表北京火车票售卖窗口
    NSOperationQueue *queue1 = [[NSOperationQueue alloc] init];
    queue1.maxConcurrentOperationCount = 1;
    
    // 2.创建 queue2,queue2 代表上海火车票售卖窗口
    NSOperationQueue *queue2 = [[NSOperationQueue alloc] init];
    queue2.maxConcurrentOperationCount = 1;
    
    
    // 3.创建卖票操作 op1
    __weak typeof(self) weakSelf = self;
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        [weakSelf saleTicketNotSafe];
    }];
    
    // 4.创建卖票操作 op2
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        [weakSelf saleTicketNotSafe];
    }];
    
    // 5.添加操作，开始卖票
    [queue1 addOperation:op1];
    [queue2 addOperation:op2];
    
    NSLog(@"initTicketStatusNotSave---end");
}

/**
 * 售卖火车票(非线程安全)
 */
- (void)saleTicketNotSafe {
    while (1) {
        if (self.ticketSurplusCount > 0) {
            [NSThread sleepForTimeInterval:0.2];
            
            //如果还有票，继续售卖
            self.ticketSurplusCount--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数:%d 窗口:%@", self.ticketSurplusCount, [NSThread currentThread]]);
            
        } else {
            NSLog(@"所有火车票均已售完");
            break;
        }
    }
}

/**
 * 线程安全：使用 NSLock 加锁
 * 初始化火车票数量、卖票窗口(线程安全)、并开始卖票
 */
- (void)initTicketStatusSave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"initTicketStatusSave---start");
    
    self.ticketSurplusCount = 50;
    
    self.lock = [[NSLock alloc] init];
    // 1.创建 queue1,queue1 代表北京火车票售卖窗口
    NSOperationQueue *queue1 = [[NSOperationQueue alloc] init];
    queue1.maxConcurrentOperationCount = 1;
    
    // 2.创建 queue2,queue2 代表上海火车票售卖窗口
    NSOperationQueue *queue2 = [[NSOperationQueue alloc] init];
    queue2.maxConcurrentOperationCount = 1;
    
    // 3.创建卖票操作 op1
    __weak typeof(self) weakSelf = self;
    NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
        [weakSelf saleTicketSafe];
    }];
    
    // 4.创建卖票操作 op2
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        [weakSelf saleTicketSafe];
    }];
    
    // 5.添加操作，开始卖票
    [queue1 addOperation:op1];
    [queue2 addOperation:op2];
    
    NSLog(@"initTicketStatusSave---end");
}

/**
 * 售卖火车票(线程安全)
 */
- (void)saleTicketSafe {
    while (1) {
        // 加锁
        [self.lock lock];
        
        if (self.ticketSurplusCount > 0) {
            [NSThread sleepForTimeInterval:0.2];
            
            //如果还有票，继续售卖
            self.ticketSurplusCount--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数:%d 窗口:%@", self.ticketSurplusCount, [NSThread currentThread]]);
        }
        // 解锁
        [self.lock unlock];
        
        if (self.ticketSurplusCount <= 0) {
            NSLog(@"所有火车票均已售完");
            break;
        }
    }
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - System Method

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGSize circleSize = CGSizeMake(100, 100);
    CGFloat padding = (CGRectGetWidth(self.view.frame) - circleSize.width * 2) / 3;
    self.label1.frame = CGRectMake(padding, 100,
                                   circleSize.width, circleSize.height);
    self.view1.frame = CGRectMake(CGRectGetMaxX(self.label1.frame) + padding, 100,
                                  circleSize.width, circleSize.height);
    
    self.button.frame = CGRectMake(0, CGRectGetMaxY(self.view1.frame) + 40,
                                   CGRectGetWidth(self.view.frame) - 60 * 2, 60);
    self.button.centerX = CGRectGetWidth(self.view.frame) / 2.f;
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

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSLog(@"%s", __func__);
}

- (void)buttonClick {

}

- (UIButton *)button {
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        [_button setTitle:@"button" forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
        [_button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        _button.titleLabel.font = [UIFont systemFontOfSize:30];
        _button.layer.borderColor = UIColor.grayColor.CGColor;
        _button.layer.borderWidth = 1.f;
    }
    return _button;
}

- (UILabel *)label1 {
    if (!_label1) {
        _label1 = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
        _label1.backgroundColor = [UIColor purpleColor];
        _label1.layer.cornerRadius = 50.f;
        _label1.layer.masksToBounds = YES;
    }
    return _label1;
}

- (UIView *)view1 {
    if (!_view1) {
        _view1 = [[UIView alloc] initWithFrame:CGRectMake(250, 100, 100, 100)];
        _view1.backgroundColor = UIColor.blueColor;
        _view1.layer.cornerRadius = 50.f;
    }
    return _view1;
}

@end

