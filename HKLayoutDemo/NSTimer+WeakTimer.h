//
//  NSTimer+WeakTimer.h
//  HKLayoutDemo
//
//  Created by ALPS on 2023/11/28.
//  Copyright © 2023 Edward. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Proxy 方式
//PFProxy.h

@interface PFProxy : NSProxy

//通过创建对象
- (instancetype)initWithObjc:(id)object;

//通过类方法创建创建
+ (instancetype)proxyWithObjc:(id)object;

@end


#pragma mark - block 方式

@interface NSTimer (WeakTimer)
@property (nonatomic, assign) NSInteger code1;

@property (nonatomic, assign) NSInteger code2;

+ (NSTimer *)zx_scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                       repeats:(BOOL)repeats
                                  handlerBlock:(void(^)(void))handler;



+ (NSTimer *)zx_scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                        target:(id)aTarget
                                      selector:(SEL)aSelector
                                      userInfo:(nullable id)userInfo
                                       repeats:(BOOL)yesOrNo;
    

- (void)removeAssociation;
@end

@interface NSTimer (WeakTimer2)
@property (nonatomic, assign) NSInteger code3;
@end





NS_ASSUME_NONNULL_END



