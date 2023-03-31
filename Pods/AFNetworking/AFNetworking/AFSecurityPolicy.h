// AFSecurityPolicy.h
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
 AFSecurityPolicy这个类是用于验证HTTPS请求的证书是否正确。
 */

#import <Foundation/Foundation.h>
#import <Security/Security.h>

typedef NS_ENUM(NSUInteger, AFSSLPinningMode) {
    AFSSLPinningModeNone,           // 不使用证书验证服务器
    AFSSLPinningModePublicKey,      // 使用证书中的公钥验证服务器
    AFSSLPinningModeCertificate,    // 使用证书验证服务器
};

/**
 `AFSecurityPolicy` evaluates server trust against pinned X.509 certificates and public keys over secure connections.

 Adding pinned SSL certificates to your app helps prevent man-in-the-middle attacks and other vulnerabilities. Applications dealing with sensitive customer data or financial information are strongly encouraged to route all communication over an HTTPS connection with SSL pinning configured and enabled.
 
 将固定的 SSL 证书添加到应用有助于防止中间人攻击和其他漏洞。强烈建议处理敏感客户数据或财务信息的应用程序通过配置并启用 SSL 固定的 HTTPS 连接路由所有通信。
 */

NS_ASSUME_NONNULL_BEGIN

@interface AFSecurityPolicy : NSObject <NSSecureCoding, NSCopying>

/**
 criteria（标准）
 evaluated（评价）
 against（针对）
 The criteria by which server trust should be evaluated against the pinned SSL certificates. Defaults to `AFSSLPinningModeNone`.
 服务器证书验证模式，默认是不验证
 */
@property (readonly, nonatomic, assign) AFSSLPinningMode SSLPinningMode;

/**
 The certificates used to evaluate server trust according to the SSL pinning mode. 
 
 Note that if pinning is enabled, `evaluateServerTrust:forDomain:` will return true if any pinned certificate matches.
 验证服务器的证书的集合，默认情况下，AFNetworking会搜索工程中所有.cer的证书文件，但不会将某个证书作为默认。
 如果想创建AFSecurityPolicy对象，就先调用certificatesInBundle方法加载证书，然后调用policyWithPinningMode:withPinnedCertificates方法创建对象

 @see policyWithPinningMode:withPinnedCertificates:
 */
@property (nonatomic, strong, nullable) NSSet <NSData *> *pinnedCertificates;

/**
 Whether or not to trust servers with an invalid or expired SSL certificates. Defaults to `NO`.
 是否信任无效或者过期的证书，默认为否
 */
@property (nonatomic, assign) BOOL allowInvalidCertificates;

/**
 Whether or not to validate the domain name in the certificate's CN field. Defaults to `YES`.
 是否验证证书中的域名，默认为是
 */
@property (nonatomic, assign) BOOL validatesDomainName;

///-----------------------------------------
/// @name Getting Certificates from the Bundle
///-----------------------------------------

/**
 Returns any certificates included in the bundle. If you are using AFNetworking as an embedded framework, you must use this method to find the certificates you have included in your app bundle, and use them when creating your security policy by calling `policyWithPinningMode:withPinnedCertificates`.
 用这个方法查找包含在指定包中的所有的证书
 
 @return The certificates included in the given bundle.
 */
+ (NSSet <NSData *> *)certificatesInBundle:(NSBundle *)bundle;

///-----------------------------------------
/// @name Getting Specific Security Policies
///-----------------------------------------

/**
 Returns the shared default security policy, which does not allow invalid certificates, validates domain name, and does not validate against pinned certificates or public keys.
 实例化工厂方法，默认的配置包括不允许无效或者过期证书、验证域名、不验证证书和证书中公钥

 @return The default security policy.
 */
+ (instancetype)defaultPolicy;

///---------------------
/// @name Initialization
///---------------------

/**
 Creates and returns a security policy with the specified pinning mode.
 
 Certificates with the `.cer` extension found in the main bundle will be pinned. If you want more control over which certificates are pinned, please use `policyWithPinningMode:withPinnedCertificates:` instead.
 指定证书验证模式的实例化工厂方法

 @param pinningMode The SSL pinning mode.

 @return A new security policy.

 @see -policyWithPinningMode:withPinnedCertificates:
 */
+ (instancetype)policyWithPinningMode:(AFSSLPinningMode)pinningMode;

/**
 Creates and returns a security policy with the specified pinning mode.

 @param pinningMode The SSL pinning mode.
 @param pinnedCertificates The certificates to pin against.
 指定证书验证模式和证书的实例化工厂方法

 @return A new security policy.

 @see +certificatesInBundle:
 @see -pinnedCertificates
*/
+ (instancetype)policyWithPinningMode:(AFSSLPinningMode)pinningMode withPinnedCertificates:(NSSet <NSData *> *)pinnedCertificates;

///------------------------------
/// @name Evaluating Server Trust
///------------------------------

/**
 Whether or not the specified server trust should be accepted, based on the security policy.

 This method should be used when responding to an authentication challenge from a server.
 验证是否信任服务器

 @param serverTrust The X.509 certificate trust of the server.
 @param domain The domain of serverTrust. If `nil`, the domain will not be validated.

 @return Whether or not to trust the server.
 */
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(nullable NSString *)domain;

@end

NS_ASSUME_NONNULL_END

///----------------
/// @name Constants
///----------------

/**
 ## SSL Pinning Modes

 The following constants are provided by `AFSSLPinningMode` as possible SSL pinning modes.

 enum {
 AFSSLPinningModeNone,
 AFSSLPinningModePublicKey,
 AFSSLPinningModeCertificate,
 }

 `AFSSLPinningModeNone`
 Do not used pinned certificates to validate servers.

 `AFSSLPinningModePublicKey`
 Validate host certificates against public keys of pinned certificates.

 `AFSSLPinningModeCertificate`
 Validate host certificates against pinned certificates.
*/
