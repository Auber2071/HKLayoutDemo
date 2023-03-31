//
//  NormalViewController.m
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "NormalViewController.h"
#import "HKTestSearchController.h"
#import "YSCOperation.h"

@interface NormalViewController ()
@property (nonatomic, strong, nullable) UIButton *button;

/* 剩余火车票数 */
@property (nonatomic, assign) int ticketSurplusCount;
@property (readwrite, nonatomic, strong) NSLock *lock;

@end

@implementation NormalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.button setTitle:@"test searchController" forState:UIControlStateNormal];
    [self.button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    self.button.titleLabel.font = [UIFont systemFontOfSize:30];
    [self.view addSubview:self.button];
    
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat searchBarWidth = CGRectGetWidth(self.view.frame) - 60 * 2;
    CGFloat searchBarHeight = 60;

    self.button.frame = CGRectMake(60, 200, searchBarWidth, searchBarHeight);
}

- (void)buttonClick {
    HKTestSearchController *test = [[HKTestSearchController alloc] init];
    test.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:test animated:YES];
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
    
//    设置优先级                                         ????没起作用
    [self setQueuePriority];
    
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
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 2.调用 start 方法开始执行操作
    [op start];
    NSLog(@"useBlockOperation---end");

}

/**
 * 使用子类 NSBlockOperation
 * 调用方法 AddExecutionBlock:
 */
- (void)useBlockOperationAddExecutionBlock {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"useBlockOperationAddExecutionBlock---start");
    // 1.创建 NSBlockOperation 对象
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 2.添加额外的操作
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"3---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"4---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"5---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"6---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"7---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"8---%@", [NSThread currentThread]); // 打印当前线程
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
    // 1.创建 YSCOperation 对象
    YSCOperation *op = [[YSCOperation alloc] init];
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
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"task3---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [op3 addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"task4---%@", [NSThread currentThread]); // 打印当前线程
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
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"3---%@", [NSThread currentThread]); // 打印当前线程
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
    queue.maxConcurrentOperationCount = 1; // 串行队列 开批新线程
//    queue.maxConcurrentOperationCount = 2; // 并发队列
//    queue.maxConcurrentOperationCount = 8; // 并发队列
    
    // 3.添加操作
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"3---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];          // 模拟耗时操作
            NSLog(@"4---%@", [NSThread currentThread]); // 打印当前线程
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
        [NSThread sleepForTimeInterval:2];
        NSLog(@"1-----%@", [NSThread currentThread]);
    }];
    
    
    NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"2-----%@", [NSThread currentThread]);
    }];
    
    [op1 setQueuePriority:(NSOperationQueuePriorityLow)];
    [op2 setQueuePriority:(NSOperationQueuePriorityHigh)];
    
    
    [queue addOperation:op1];
    [queue addOperation:op2];
    
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
    [queue addOperation:op1];
    [queue addOperation:op2];
    
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

/**
 * 任务1
 */
- (void)task1 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"task1---%@", [NSThread currentThread]);     // 打印当前线程
    }
}

/**
 * 任务2
 */
- (void)task2 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"task2---%@", [NSThread currentThread]);     // 打印当前线程
    }
}




@end

