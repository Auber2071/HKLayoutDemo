//
//  NSTimer+WeakTimer.m
//  HKLayoutDemo
//
//  Created by ALPS on 2023/11/28.
//  Copyright © 2023 Edward. All rights reserved.
//

#import "NSTimer+WeakTimer.h"
#import <objc/runtime.h>


#pragma mark - 中间件（接受者重定向）
@interface PFProxy()
@property (nonatomic, weak) id object;
@end

@implementation PFProxy

- (instancetype)initWithObjc:(id)object {
    
    self.object = object;
    return self;
}

+ (instancetype)proxyWithObjc:(id)object {
    
    return [[self alloc] initWithObjc:object];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    
    if ([self.object respondsToSelector:invocation.selector]) {
        
        [invocation invokeWithTarget:self.object];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    
    return [self.object methodSignatureForSelector:sel];
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}
@end

#pragma mark - 中间件（传递target、selector）
@interface TimerWeakObject : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector; // 定时器到时的回调方法
@property (nonatomic, weak) NSTimer *timer;
- (void)fire:(NSTimer *)timer;
@end

@implementation TimerWeakObject

- (void)fire:(NSTimer *)timer {
    if (self.target) {
        if ([self.target respondsToSelector:self.selector]) {
            [self.target performSelector:self.selector withObject:timer.userInfo];
        }
    } else {
        [self.target  invalidate];
    }
}

@end


#pragma mark - block 方式

@implementation NSTimer (WeakTimer)
#pragma  mark - 方式一
/**
 * 该方案主要要点：
 *
 * 将计时器所应执行的任务封装成"Block"，在调用计时器函数时，把block作为userInfo参数传进去。
 *
 * userInfo参数用来存放"不透明值"，只要计时器有效，就会一直保留它。在传入参数时要通过copy方法，将block拷贝到"堆区"，否则等到稍后要执行它的时候，该blcok可能已经无效了。
 *
 * 计时器现在的target是NSTimer类对象，这是个单例，因此计时器是否会保留它，其实都无所谓。
 *
 * 此处依然有保留环，然而因为类对象（class object）无需回收，所以不用担心。
 */

+ (NSTimer *)zx_scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                       repeats:(BOOL)repeats
                                  handlerBlock:(void(^)(void))handler
{
    return [self scheduledTimerWithTimeInterval:timeInterval
                                         target:self
                                       selector:@selector(handlerBlockInvoke:)
                                       userInfo:[handler copy]
                                        repeats:repeats];
}

+ (void)handlerBlockInvoke:(NSTimer *)timer
{
    void (^block)(void) = timer.userInfo;
    if (block) {
        block();
    }
}


#pragma  mark - 方式二
+ (NSTimer *)zx_scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                        target:(id)aTarget
                                      selector:(SEL)aSelector
                                      userInfo:(nullable id)userInfo
                                       repeats:(BOOL)yesOrNo {
    
    PFProxy *proxy = [[PFProxy alloc] initWithObjc:aTarget];
    return [NSTimer scheduledTimerWithTimeInterval:ti
                                            target:proxy
                                          selector:aSelector
                                          userInfo:userInfo
                                           repeats:yesOrNo];

}

#pragma  mark - 方式三
+ (NSTimer *)zx_scheduledWeakTimerWithTimeInterval:(NSTimeInterval)ti
                                        target:(id)aTarget
                                      selector:(SEL)aSelector
                                      userInfo:(nullable id)userInfo
                                       repeats:(BOOL)yesOrNo {
    
    TimerWeakObject *object = [[TimerWeakObject alloc] init];
    object.target = aTarget;
    object.selector = aSelector;
    object.timer = [NSTimer scheduledTimerWithTimeInterval:ti
                                                    target:object
                                                  selector:@selector(fire:)
                                                  userInfo:userInfo
                                                   repeats:yesOrNo];
    
    return object.timer;

}



@end

