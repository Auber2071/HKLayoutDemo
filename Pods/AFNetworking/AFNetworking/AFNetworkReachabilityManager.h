// AFNetworkReachabilityManager.h
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


/**
 该类主要是用来检测网络环境的变化。
 */
#import <Foundation/Foundation.h>

#if !TARGET_OS_WATCH
#import <SystemConfiguration/SystemConfiguration.h>

typedef NS_ENUM(NSInteger, AFNetworkReachabilityStatus) {
    AFNetworkReachabilityStatusUnknown          = -1,   // 网络状态未知
    AFNetworkReachabilityStatusNotReachable     = 0,    // 网络状态无连接
    AFNetworkReachabilityStatusReachableViaWWAN = 1,    // 网络状态为蜂窝移动网络连接
    AFNetworkReachabilityStatusReachableViaWiFi = 2,    // 网络状态为无线局域网连接
};

NS_ASSUME_NONNULL_BEGIN

/**
 `AFNetworkReachabilityManager` monitors the reachability of domains, and addresses for both WWAN and WiFi network interfaces.
 
 Reachability（能达到性）
 Reachability can be used to determine background information about why a network operation failed, or to trigger a network operation retrying when a connection is established. It should not be used to prevent a user from initiating a network request, as it's possible that an initial request may be required to establish reachability.

 See Apple's Reachability Sample Code ( https://developer.apple.com/library/ios/samplecode/reachability/ )

 @warning Instances of `AFNetworkReachabilityManager` must be started with `-startMonitoring` before reachability status can be determined.
 */
@interface AFNetworkReachabilityManager : NSObject

/**
 The current network reachability status.
 当前网络连接状态
 */
@property (readonly, nonatomic, assign) AFNetworkReachabilityStatus networkReachabilityStatus;

/**
 Whether or not the network is currently reachable.
 当前是否有网络连接
 */
@property (readonly, nonatomic, assign, getter = isReachable) BOOL reachable;

/**
 Whether or not the network is currently reachable via WWAN.
 当前网络连接状态是否为蜂窝移动网络连接
 */
@property (readonly, nonatomic, assign, getter = isReachableViaWWAN) BOOL reachableViaWWAN;

/**
 Whether or not the network is currently reachable via WiFi.
 当前网络连接状态是否为无线局域网连接
 */
@property (readonly, nonatomic, assign, getter = isReachableViaWiFi) BOOL reachableViaWiFi;

///---------------------
/// @name Initialization
///---------------------

/**
 Returns the shared network reachability manager.
 获取单例对象
 */
+ (instancetype)sharedManager;

/**
 Creates and returns a network reachability manager with the default socket address.
 实例化默认socket地址的对象，并主动监视默认socket地址的状态

 @return An initialized network reachability manager, actively monitoring the default socket address.
 */
+ (instancetype)manager;

/**
 Creates and returns a network reachability manager for the specified domain.
 实例化指定域的对象，并主动监视指定域的状态

 @param domain The domain used to evaluate network reachability.

 @return An initialized network reachability manager, actively monitoring the specified domain.
 */
+ (instancetype)managerForDomain:(NSString *)domain;

/**
 Creates and returns a network reachability manager for the socket address.
 实例化指定socket地址的对象，并主动监视指定socket地址的状态

 @param address The socket address (`sockaddr_in6`) used to evaluate network reachability.

 @return An initialized network reachability manager, actively monitoring the specified socket address.
 */
+ (instancetype)managerForAddress:(const void *)address;

/**
 Initializes an instance of a network reachability manager from the specified reachability object.
 以指定SCNetworkReachabilityRef对象进行初始化，并主动监视指定SCNetworkReachabilityRef对象的状态

 @param reachability The reachability object to monitor.

 @return An initialized network reachability manager, actively monitoring the specified reachability.
 */
- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability NS_DESIGNATED_INITIALIZER;

/**
 *  Unavailable initializer
 *  
 */
+ (instancetype)new NS_UNAVAILABLE;

/**
 *  Unavailable initializer
 *  初始化方法，这个方法被手动禁止了，如果强制调用这个方法就会报错
 */
- (instancetype)init NS_UNAVAILABLE;

///--------------------------------------------------
/// @name Starting & Stopping Reachability Monitoring
///--------------------------------------------------

/**
 Starts monitoring for changes in network reachability status.
 开始监控网络状态
 */
- (void)startMonitoring;

/**
 Stops monitoring for changes in network reachability status.
 停止监控网络状态
 */
- (void)stopMonitoring;

///-------------------------------------------------
/// @name Getting Localized Reachability Description
///-------------------------------------------------

/**
 Returns a localized string representation of the current network reachability status.
 获得网络状态的本地文字描述
 */
- (NSString *)localizedNetworkReachabilityStatusString;

///---------------------------------------------------
/// @name Setting Network Reachability Change Callback
///---------------------------------------------------

/**
 Sets a callback to be executed when the network availability of the `baseURL` host changes.
 当网络状态发生变化时，会回调block

 @param block A block object to be executed when the network availability of the `baseURL` host changes.. This block has no return value and takes a single argument which represents the various reachability states from the device to the `baseURL`.
 */
- (void)setReachabilityStatusChangeBlock:(nullable void (^)(AFNetworkReachabilityStatus status))block;

@end

///----------------
/// @name Constants（常量）
///----------------

/**
 ## Network Reachability

 The following constants are provided by `AFNetworkReachabilityManager` as possible network reachability statuses.

 enum {
 AFNetworkReachabilityStatusUnknown,
 AFNetworkReachabilityStatusNotReachable,
 AFNetworkReachabilityStatusReachableViaWWAN,
 AFNetworkReachabilityStatusReachableViaWiFi,
 }

 `AFNetworkReachabilityStatusUnknown`
 The `baseURL` host reachability is not known.

 `AFNetworkReachabilityStatusNotReachable`
 The `baseURL` host cannot be reached.

 `AFNetworkReachabilityStatusReachableViaWWAN`
 The `baseURL` host can be reached via a cellular connection, such as EDGE or GPRS.

 `AFNetworkReachabilityStatusReachableViaWiFi`
 The `baseURL` host can be reached via a Wi-Fi connection.

 ### Keys for Notification UserInfo Dictionary

 Strings that are used as keys in a `userInfo` dictionary in a network reachability status change notification.

 `AFNetworkingReachabilityNotificationStatusItem`
 A key in the userInfo dictionary in a `AFNetworkingReachabilityDidChangeNotification` notification.
 The corresponding value is an `NSNumber` object representing the `AFNetworkReachabilityStatus` value for the current reachability status.
 */

///--------------------
/// @name Notifications
///--------------------

/**
 Posted when network reachability changes.
 This notification assigns no notification object. The `userInfo` dictionary contains an `NSNumber` object under the `AFNetworkingReachabilityNotificationStatusItem` key, representing the `AFNetworkReachabilityStatus` value for the current network reachability.

 @warning In order for network reachability to be monitored, include the `SystemConfiguration` framework in the active target's "Link Binary With Library" build phase, and add `#import <SystemConfiguration/SystemConfiguration.h>` to the header prefix of the project (`Prefix.pch`).
 */
/**
 当需要用通知来监听网络状态变化时，先监听AFNetworkingReachabilityDidChangeNotification通知，
 然后在通知调用的方法中获取传递过来参数中的属性userInfo，这个属性是NSDictionary类型的，通过key值AFNetworkingReachabilityNotificationStatusItem就可以获得当前的网络状态。
 */
FOUNDATION_EXPORT NSString * const AFNetworkingReachabilityDidChangeNotification;
FOUNDATION_EXPORT NSString * const AFNetworkingReachabilityNotificationStatusItem;

///--------------------
/// @name Functions
///--------------------

/**
 Returns a localized string representation of an `AFNetworkReachabilityStatus` value.
 将传入的网络状态枚举值转成本地文字描述。
 */
FOUNDATION_EXPORT NSString * AFStringFromNetworkReachabilityStatus(AFNetworkReachabilityStatus status);

NS_ASSUME_NONNULL_END
#endif
