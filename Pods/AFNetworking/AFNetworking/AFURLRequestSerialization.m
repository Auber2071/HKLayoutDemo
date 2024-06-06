// AFURLRequestSerialization.m
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

#import "AFURLRequestSerialization.h"

#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

/**
 AFURLRequestSerializer类的错误，错误码对应NSURLErrorDomain的错误码
 */
NSString * const AFURLRequestSerializationErrorDomain = @"com.alamofire.error.serialization.request";
/**
 这个key只存在AFURLRequestSerializationErrorDomain中，其对应的值是NSURLRequest错误请求的操作
 */
NSString * const AFNetworkingOperationFailingURLRequestErrorKey = @"com.alamofire.serialization.request.error.response";

typedef NSString * (^AFQueryStringSerializationBlock)(NSURLRequest *request, id parameters, NSError *__autoreleasing *error);

/**
 Returns a percent-escaped string following RFC 3986 for a query string key or value.
 RFC 3986 states that the following characters are "reserved" characters.
    - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="

 In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
 query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
 should be percent-escaped in the query string.
    - parameter string: The string to be percent-escaped.
    - returns: The percent-escaped string.
 */
NSString * AFPercentEscapedStringFromString(NSString *string) {
    // 在RFC3986的第3.4节中指出，在对查询字段百分号编码时，保留字符中的“?”和“/”可以不用编码，其他的都要进行编码。
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";

    // 获取URL查询字段允许字符，并从中删除除“?”和“/”之外的保留字符
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];

    // FIXME: https://github.com/AFNetworking/AFNetworking/pull/3028
    // return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];

    // 每50个字符一组进行百分号编码
    static NSUInteger const batchSize = 50;

    NSUInteger index = 0;
    NSMutableString *escaped = @"".mutableCopy;

    while (index < string.length) {
        NSUInteger length = MIN(string.length - index, batchSize);
        NSRange range = NSMakeRange(index, length);

        // To avoid breaking up character sequences such as 👴🏻👮🏽
        // 每一个中文或者英文在NSString中的length均为1，但是一个Emoji的length的长度为2或者4，这是为了避免截断Emoji表情产生乱码

        range = [string rangeOfComposedCharacterSequencesForRange:range];

        NSString *substring = [string substringWithRange:range];
        NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [escaped appendString:encoded];

        index += range.length;
    }

    return escaped;
}

#pragma mark -
/**
 在对请求的查询参数编码时，传入的参数会被拆分成最小的集合类对象，然后将集合对象转成AFQueryStringPair对象，再对field和value百分号编码后生成field=value类型的字符串
 */
@interface AFQueryStringPair : NSObject
@property (readwrite, nonatomic, strong) id field;  // 字段
@property (readwrite, nonatomic, strong) id value;  // 值

/**
 AFQueryStringPair对象初始化方法

 @param field 字段
 @param value 值
 @return 初始化的AFQueryStringPair对象
 */
- (instancetype)initWithField:(id)field value:(id)value;

/**
 将属性field和value进行百分号编码后，之间用”=“拼接成一个字符串

 @return 处理好的字符串
 */
- (NSString *)URLEncodedStringValue;
@end

@implementation AFQueryStringPair

- (instancetype)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    // 属性保存初始化传入的参数
    self.field = field;
    self.value = value;

    return self;
}

- (NSString *)URLEncodedStringValue {
    // 如果value值为nil或null
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        // 只把属性field的字符串描述属性进行百分号编码后返回
        return AFPercentEscapedStringFromString([self.field description]);
        
    // 如果value值不为nil或null
    } else {
        // 把属性field和value进行百分号编码后，之间用”=“拼接成一个字符串返回
        return [NSString stringWithFormat:@"%@=%@", AFPercentEscapedStringFromString([self.field description]), AFPercentEscapedStringFromString([self.value description])];
    }
}

@end

#pragma mark -

FOUNDATION_EXPORT NSArray * AFQueryStringPairsFromDictionary(NSDictionary *dictionary);
FOUNDATION_EXPORT NSArray * AFQueryStringPairsFromKeyAndValue(NSString *key, id value);

NSString * AFQueryStringFromParameters(NSDictionary *parameters) {
    // 把传入的字典转成元素为AFQueryStringPair对象的数组，然后遍历数组将AFQueryStringPair对象转成经过百分号编码的“key=value”类型NSString对象，最后用“&”拼接成一个字符串
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (AFQueryStringPair *pair in AFQueryStringPairsFromDictionary(parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValue]];
    }

    return [mutablePairs componentsJoinedByString:@"&"];
}

NSArray * AFQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    // 第一个参数key传了nil，第二个参数value传了以上方法传过来的字典
    return AFQueryStringPairsFromKeyAndValue(nil, dictionary);
}

NSArray * AFQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    // 设置排序描述为按照对象的description属性的字母升序排列
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(compare:)];

    // 如果参数value传入的是NSDictionary
    if ([value isKindOfClass:[NSDictionary class]]) {
        // 声明变量保存传入的字典
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        // 将字典的key按照首字母升序排列后进行遍历
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                // 如果遍历出的key所对应的value不为空，就递归调用本方法，如果有key值则传(key[nestedKey], nestedValue)，否则传(nestedKey, nestedValue)
                [mutableQueryStringComponents addObjectsFromArray:AFQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    // 如果参数value传入的是NSArray
    } else if ([value isKindOfClass:[NSArray class]]) {
        // 声明变量保存传入的数组
        NSArray *array = value;
        // 遍历数组
        for (id nestedValue in array) {
            // 递归调用本方法，如果有key值则传递(key[], nestedValue)，否则传((null)[], nestedValue)
            [mutableQueryStringComponents addObjectsFromArray:AFQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    // 如果参数value传入的是NSSet
    } else if ([value isKindOfClass:[NSSet class]]) {
        // 声明变量保存传入的集合
        NSSet *set = value;
        // 将集合的元素按照首字母升序排列后进行遍历
        for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            // 递归调用本方法，如果有key值则传(key, obj)，否则传((null), obj)
            [mutableQueryStringComponents addObjectsFromArray:AFQueryStringPairsFromKeyAndValue(key, obj)];
        }
    // 如果参数value传入的不是集合对象
    } else {
        // 利用传入的参数key和value实例化AFQueryStringPair对象并添加到mutableQueryStringComponents数组中
        [mutableQueryStringComponents addObject:[[AFQueryStringPair alloc] initWithField:key value:value]];
    }
    // 返回由字典对象转化元素为AFQueryStringPair对象组成的数组
    return mutableQueryStringComponents;
}

#pragma mark -
/**
 这个类的作用是提供接口以便用户添加上传的数据。
 
 当用户添加数据时，该类会将用户想要上传的数据分别转成AFHTTPBodyPart对象，然后依次保存到自身AFMultipartBodyStream *类型的属性bodyStream中，当数据添加完成，就会将属性bodyStream赋值给NSMutableURLRequest的HTTPBodyStream属性。
 */
@interface AFStreamingMultipartFormData : NSObject <AFMultipartFormData>
/**
 通过传递请求和编码方式进行初始化
 */
- (instancetype)initWithURLRequest:(NSMutableURLRequest *)urlRequest
                    stringEncoding:(NSStringEncoding)encoding;

/**
 返回最终处理好的NSMutableURLRequest
 */
- (NSMutableURLRequest *)requestByFinalizingMultipartFormData;
@end

#pragma mark -

// 该方法通过一个单例模式获取需要观察的AFHTTPRequestSerializer对象的属性，并保存在一个数组中返回
static NSArray * AFHTTPRequestSerializerObservedKeyPaths() {
    static NSArray *_AFHTTPRequestSerializerObservedKeyPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _AFHTTPRequestSerializerObservedKeyPaths = @[NSStringFromSelector(@selector(allowsCellularAccess)),
                                                     NSStringFromSelector(@selector(cachePolicy)),
                                                     NSStringFromSelector(@selector(HTTPShouldHandleCookies)),
                                                     NSStringFromSelector(@selector(HTTPShouldUsePipelining)),
                                                     NSStringFromSelector(@selector(networkServiceType)),
                                                     NSStringFromSelector(@selector(timeoutInterval))];
    });

    return _AFHTTPRequestSerializerObservedKeyPaths;
}

// 该变量用于识别观察者的身份
static void *AFHTTPRequestSerializerObserverContext = &AFHTTPRequestSerializerObserverContext;

@interface AFHTTPRequestSerializer ()
// 用来保存需要观察的用户自定义的AFHTTPRequestSerializer对象的属性
@property (readwrite, nonatomic, strong) NSMutableSet *mutableObservedChangedKeyPaths;
// 用来保存请求头信息
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableHTTPRequestHeaders;
@property (readwrite, nonatomic, strong) dispatch_queue_t requestHeaderModificationQueue;
// 用来保存查询字段编码类型
@property (readwrite, nonatomic, assign) AFHTTPRequestQueryStringSerializationStyle queryStringSerializationStyle;
// 用来保存用户自定义的查询字段编码方式代码块
@property (readwrite, nonatomic, copy) AFQueryStringSerializationBlock queryStringSerialization;
@end

@implementation AFHTTPRequestSerializer

+ (instancetype)serializer {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    // 初始化字符串编码方式为NSUTF8StringEncoding
    self.stringEncoding = NSUTF8StringEncoding;

    // 初始化请求头
    self.mutableHTTPRequestHeaders = [NSMutableDictionary dictionary];
    self.requestHeaderModificationQueue = dispatch_queue_create("requestHeaderModificationQueue", DISPATCH_QUEUE_CONCURRENT);

    // 获取前五个用户偏好的语言并赋值给请求头Accept-Language字段
    // Accept-Language HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
    NSMutableArray *acceptLanguagesComponents = [NSMutableArray array];
    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        float q = 1.0f - (idx * 0.1f);
        [acceptLanguagesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
        *stop = q <= 0.5f;
    }];
    [self setValue:[acceptLanguagesComponents componentsJoinedByString:@", "] forHTTPHeaderField:@"Accept-Language"];

    // 获取项目名称（如果没有则获取BundleID）、应用Version版本号（如果没有则获取应用Build版本号）、设备类型、系统版本号和屏幕缩放比并赋值给请求头User-Agent字段
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    NSString *userAgent = nil;
#if TARGET_OS_IOS
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)",
                 [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey],
                 [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey],
                 [[UIDevice currentDevice] model],
                 [[UIDevice currentDevice] systemVersion],
                 [[UIScreen mainScreen] scale]];
#elif TARGET_OS_TV
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; tvOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
#elif TARGET_OS_WATCH
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; watchOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[WKInterfaceDevice currentDevice] model], [[WKInterfaceDevice currentDevice] systemVersion], [[WKInterfaceDevice currentDevice] screenScale]];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    userAgent = [NSString stringWithFormat:@"%@/%@ (Mac OS X %@)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
    if (userAgent) {
        // 如果不能进行无损ASCII编码，即不是只有普通的字符或ASCII码
        if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSMutableString *mutableUserAgent = [userAgent mutableCopy];
            // 如果移除所有非ASCII值范围的所有字符，移除后再次赋值
            if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false)) {
                userAgent = mutableUserAgent;
            }
        }
        [self setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    }

    // HTTP Method Definitions; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html
    // 初始化需要把查询字符串编码拼接到URL后面的HTTP请求方法集合为GET、HEAD和DELETE方法
    self.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", @"DELETE", nil];

    // 初始化要观察的自定义的AFHTTPRequestSerializer属性集合
    self.mutableObservedChangedKeyPaths = [NSMutableSet set];
    // 遍历AFHTTPRequestSerializer需要添加观察的属性，添加观察者，并设置上下文为AFHTTPRequestSerializerObserverContext用于标识
    for (NSString *keyPath in AFHTTPRequestSerializerObservedKeyPaths()) {
        if ([self respondsToSelector:NSSelectorFromString(keyPath)]) {
            [self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:AFHTTPRequestSerializerObserverContext];
        }
    }

    return self;
}

- (void)dealloc {
    // 遍历AFHTTPRequestSerializer需要添加观察的属性，移除观察者
    for (NSString *keyPath in AFHTTPRequestSerializerObservedKeyPaths()) {
        if ([self respondsToSelector:NSSelectorFromString(keyPath)]) {
            [self removeObserver:self forKeyPath:keyPath context:AFHTTPRequestSerializerObserverContext];
        }
    }
}

#pragma mark - 手动实现KVO

// Workarounds for crashing behavior using Key-Value Observing with XCTest
// See https://github.com/AFNetworking/AFNetworking/issues/2523
- (void)setAllowsCellularAccess:(BOOL)allowsCellularAccess {
    [self willChangeValueForKey:NSStringFromSelector(@selector(allowsCellularAccess))];
    _allowsCellularAccess = allowsCellularAccess;
    [self didChangeValueForKey:NSStringFromSelector(@selector(allowsCellularAccess))];
}

- (void)setCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
    [self willChangeValueForKey:NSStringFromSelector(@selector(cachePolicy))];
    _cachePolicy = cachePolicy;
    [self didChangeValueForKey:NSStringFromSelector(@selector(cachePolicy))];
}

- (void)setHTTPShouldHandleCookies:(BOOL)HTTPShouldHandleCookies {
    [self willChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldHandleCookies))];
    _HTTPShouldHandleCookies = HTTPShouldHandleCookies;
    [self didChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldHandleCookies))];
}

- (void)setHTTPShouldUsePipelining:(BOOL)HTTPShouldUsePipelining {
    [self willChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldUsePipelining))];
    _HTTPShouldUsePipelining = HTTPShouldUsePipelining;
    [self didChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldUsePipelining))];
}

- (void)setNetworkServiceType:(NSURLRequestNetworkServiceType)networkServiceType {
    [self willChangeValueForKey:NSStringFromSelector(@selector(networkServiceType))];
    _networkServiceType = networkServiceType;
    [self didChangeValueForKey:NSStringFromSelector(@selector(networkServiceType))];
}

- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval {
    [self willChangeValueForKey:NSStringFromSelector(@selector(timeoutInterval))];
    _timeoutInterval = timeoutInterval;
    [self didChangeValueForKey:NSStringFromSelector(@selector(timeoutInterval))];
}

#pragma mark - 自定义公共属性的setter和getter

- (NSDictionary *)HTTPRequestHeaders {
    // 返回私有属性mutableHTTPRequestHeaders
    NSDictionary __block *value;
    dispatch_sync(self.requestHeaderModificationQueue, ^{
        value = [NSDictionary dictionaryWithDictionary:self.mutableHTTPRequestHeaders];
    });
    return value;
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // 为私有属性mutableHTTPRequestHeaders赋值
    dispatch_barrier_sync(self.requestHeaderModificationQueue, ^{
        [self.mutableHTTPRequestHeaders setValue:value forKey:field];
    });
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field {
    // 获取私有属性mutableHTTPRequestHeaders指定key的值
    NSString __block *value;
    dispatch_sync(self.requestHeaderModificationQueue, ^{
        value = [self.mutableHTTPRequestHeaders valueForKey:field];
    });
    return value;
}

- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username password:(NSString *)password {
    // 先把账户和密码拼接成一个字符串后转为UTF8格式的NSData对象，再通过base64编码成字符串赋值给请求头的Authorization字段
    NSData *basicAuthCredentials = [[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64AuthCredentials = [basicAuthCredentials base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)0];
    [self setValue:[NSString stringWithFormat:@"Basic %@", base64AuthCredentials] forHTTPHeaderField:@"Authorization"];
}

- (void)clearAuthorizationHeader {
    // 从请求头中移除Authorization字段
    dispatch_barrier_sync(self.requestHeaderModificationQueue, ^{
        [self.mutableHTTPRequestHeaders removeObjectForKey:@"Authorization"];
    });
}

- (void)setQueryStringSerializationWithStyle:(AFHTTPRequestQueryStringSerializationStyle)style {
    // 如果设置了编码格式就把自定义编码代码块置nil
    self.queryStringSerializationStyle = style;
    self.queryStringSerialization = nil;
}

- (void)setQueryStringSerializationWithBlock:(NSString *(^)(NSURLRequest *, id, NSError *__autoreleasing *))block {
    // 这是为了用户在设置代码块时有智能提示，可以直接回车敲出
    self.queryStringSerialization = block;
}

#pragma mark - 公共方法的实现

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                 URLString:(NSString *)URLString
                                parameters:(id)parameters
                                     error:(NSError *__autoreleasing *)error
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(method);
    NSParameterAssert(URLString);
    
    // 利用传入的路径生成NSURL对象
    NSURL *url = [NSURL URLWithString:URLString];

    // 判断url是否生成
    NSParameterAssert(url);

    // 利用生成的NSURL对象生成NSMutableURLRequest对象，并设置请求方式
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    mutableRequest.HTTPMethod = method;

    // 遍历AFHTTPRequestSerializer需要添加观察的属性
    for (NSString *keyPath in AFHTTPRequestSerializerObservedKeyPaths()) {
        // 如果遍历出的属性是用户自定义的属性
        if ([self.mutableObservedChangedKeyPaths containsObject:keyPath]) {
            // 将属性对应的值赋值给NSMutableURLRequest对象相对应的属性
            [mutableRequest setValue:[self valueForKeyPath:keyPath] forKey:keyPath];
        }
    }

    // 将传入的参数parameters处理后添加到mutableRequest中
    mutableRequest = [[self requestBySerializingRequest:mutableRequest withParameters:parameters error:error] mutableCopy];

    return mutableRequest;
}

- (NSMutableURLRequest *)multipartFormRequestWithMethod:(NSString *)method
                                              URLString:(NSString *)URLString
                                             parameters:(NSDictionary *)parameters
                              constructingBodyWithBlock:(void (^)(id <AFMultipartFormData> formData))block
                                                  error:(NSError *__autoreleasing *)error
{
    // 没有传请求方法就crash
    NSParameterAssert(method);
    // 请求方法是GET或HEAD就crash
    NSParameterAssert(![method isEqualToString:@"GET"] && ![method isEqualToString:@"HEAD"]);

    // 调用上个公共方法生成NSMutableURLRequest对象
    NSMutableURLRequest *mutableRequest = [self requestWithMethod:method URLString:URLString parameters:nil error:error];

    // 利用NSMutableURLRequest对象生成AFStreamingMultipartFormData对象formData
    __block AFStreamingMultipartFormData *formData = [[AFStreamingMultipartFormData alloc] initWithURLRequest:mutableRequest stringEncoding:NSUTF8StringEncoding];

    if (parameters) {
        // 将传入的字典参数转为元素是AFQueryStringPair对象的数组，并进行遍历
        for (AFQueryStringPair *pair in AFQueryStringPairsFromDictionary(parameters)) {
            // 将对象pair的value属性转为NSData对象，并拼到formData对象中
            NSData *data = nil;
            if ([pair.value isKindOfClass:[NSData class]]) {
                data = pair.value;
            } else if ([pair.value isEqual:[NSNull null]]) {
                data = [NSData data];
            } else {
                data = [[pair.value description] dataUsingEncoding:self.stringEncoding];
            }

            if (data) {
                [formData appendPartWithFormData:data name:[pair.field description]];
            }
        }
    }

    // 调用代码块拼接想要上传的数据
    if (block) {
        block(formData);
    }
    
    // 构建multipart/form-data请求独有的请求头
    return [formData requestByFinalizingMultipartFormData];
}

- (NSMutableURLRequest *)requestWithMultipartFormRequest:(NSURLRequest *)request
                             writingStreamContentsToFile:(NSURL *)fileURL
                                       completionHandler:(void (^)(NSError *error))handler
{
    // request对象的HTTPBodyStream属性为nil则crash
    NSParameterAssert(request.HTTPBodyStream);
    // fileURL不是合法的文件路径则crash
    NSParameterAssert([fileURL isFileURL]);

    // 生成输入流和输出流
    NSInputStream *inputStream = request.HTTPBodyStream;
    NSOutputStream *outputStream = [[NSOutputStream alloc] initWithURL:fileURL append:NO];
    __block NSError *error = nil;

    // 全局并发队列异步执行写入操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 把输入输出流添加到默认模式的当前运行循环中
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

        // 打开输入输出流
        [inputStream open];
        [outputStream open];

        // 如果输入输出流还有可操作字节
        while ([inputStream hasBytesAvailable] && [outputStream hasSpaceAvailable]) {
            uint8_t buffer[1024];
            
            // 每次从输入流中读取最大1024bytes大小的数据存入buffer中，如果出错则跳出循环
            NSInteger bytesRead = [inputStream read:buffer maxLength:1024];
            if (inputStream.streamError || bytesRead < 0) {
                error = inputStream.streamError;
                break;
            }

            // 将从输入流中读取出的数据写入到输出流中，如果出错则跳出循环
            NSInteger bytesWritten = [outputStream write:buffer maxLength:(NSUInteger)bytesRead];
            if (outputStream.streamError || bytesWritten < 0) {
                error = outputStream.streamError;
                break;
            }
            
            // 如果读写完则跳出循环
            if (bytesRead == 0 && bytesWritten == 0) {
                break;
            }
        }

        // 关闭输入输出流
        [outputStream close];
        [inputStream close];

        // 如果传入了回调代码块则在主队列异步回调
        if (handler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(error);
            });
        }
    });

    // 把原mutableRequest对象的HTTPBodyStream属性置nil后返回
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    mutableRequest.HTTPBodyStream = nil;

    return mutableRequest;
}

#pragma mark - AFURLRequestSerialization

- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(id)parameters
                                        error:(NSError *__autoreleasing *)error
{
    // 缺少request则会crash
    NSParameterAssert(request);

    NSMutableURLRequest *mutableRequest = [request mutableCopy];

    // 遍历request的请求头，对没有值的字段进行赋值
    [self.HTTPRequestHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
        if (![request valueForHTTPHeaderField:field]) {
            [mutableRequest setValue:value forHTTPHeaderField:field];
        }
    }];

    // 对参数parameters进行编码
    NSString *query = nil;
    if (parameters) {
        // 如果用户自定义了编码代码块则用用户自定义的方法编码
        if (self.queryStringSerialization) {
            NSError *serializationError;
            query = self.queryStringSerialization(request, parameters, &serializationError);

            if (serializationError) {
                if (error) {
                    *error = serializationError;
                }

                return nil;
            }
        // 如果用户没有自定义编码代码块则用AFNetworking默认的编码方式，即百分号编码
        } else {
            switch (self.queryStringSerializationStyle) {
                case AFHTTPRequestQueryStringDefaultStyle:
                    query = AFQueryStringFromParameters(parameters);
                    break;
            }
        }
    }

    // 如果HTTP请求方法为GET、HEAD或DELETE其中之一
    if ([self.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
        // 就把查询字符串拼接到url后面
        if (query && query.length > 0) {
            mutableRequest.URL = [NSURL URLWithString:[[mutableRequest.URL absoluteString] stringByAppendingFormat:mutableRequest.URL.query ? @"&%@" : @"?%@", query]];
        }
    // 如果HTTP请求方法为POST、PUT其中之一
    } else {
        // 就把查询字符串拼接到请求体中
        // #2864: an empty string is a valid x-www-form-urlencoded payload
        if (!query) {
            query = @"";
        }
        if (![mutableRequest valueForHTTPHeaderField:@"Content-Type"]) {
            [mutableRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        }
        [mutableRequest setHTTPBody:[query dataUsingEncoding:self.stringEncoding]];
    }

    return mutableRequest;
}

#pragma mark - NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    // 如果是需要观察的AFHTTPRequestSerializer对象的属性，则不自动实现KVO
    if ([AFHTTPRequestSerializerObservedKeyPaths() containsObject:key]) {
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:key];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(__unused id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    // 如果观察到的是AFHTTPRequestSerializer类添加观察的属性
    if (context == AFHTTPRequestSerializerObserverContext) {
        // 如果给当前属性赋的值不为null就添加到self.mutableObservedChangedKeyPaths中，否则从其中移除
        if ([change[NSKeyValueChangeNewKey] isEqual:[NSNull null]]) {
            [self.mutableObservedChangedKeyPaths removeObject:keyPath];
        } else {
            [self.mutableObservedChangedKeyPaths addObject:keyPath];
        }
    }
}

#pragma mark - NSSecureCoding
/**
 在iOS6中，苹果引入了一个新的协议，是基于NSCoding的，叫做NSSecureCoding。
 NSSecureCoding和NSCoding是一样的，除了在解码时要同时指定key和要解码的对象的类，如果要求的类和从文件中解码出的对象的类不匹配，NSCoder会抛出异常，告诉你数据已经被篡改了。
 */
+ (BOOL)supportsSecureCoding {
    // 如果一个类符合 NSSecureCoding 协议并在 + supportsSecureCoding 返回 YES，就声明了它可以处理本身实例的编码解码方式，以防止替换攻击。
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    if (!self) {
        return nil;
    }

    self.mutableHTTPRequestHeaders = [[decoder decodeObjectOfClass:[NSDictionary class] forKey:NSStringFromSelector(@selector(mutableHTTPRequestHeaders))] mutableCopy];
    self.queryStringSerializationStyle = (AFHTTPRequestQueryStringSerializationStyle)[[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(queryStringSerializationStyle))] unsignedIntegerValue];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    dispatch_sync(self.requestHeaderModificationQueue, ^{
        [coder encodeObject:self.mutableHTTPRequestHeaders forKey:NSStringFromSelector(@selector(mutableHTTPRequestHeaders))];
    });
    [coder encodeObject:@(self.queryStringSerializationStyle) forKey:NSStringFromSelector(@selector(queryStringSerializationStyle))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    AFHTTPRequestSerializer *serializer = [[[self class] allocWithZone:zone] init];
    dispatch_sync(self.requestHeaderModificationQueue, ^{
        serializer.mutableHTTPRequestHeaders = [self.mutableHTTPRequestHeaders mutableCopyWithZone:zone];
    });
    serializer.queryStringSerializationStyle = self.queryStringSerializationStyle;
    serializer.queryStringSerialization = self.queryStringSerialization;

    return serializer;
}

@end

#pragma mark - 私有全局属性

/**
 由随机生成的八位16进制字符串组成的边界字符串
 */
static NSString * AFCreateMultipartFormBoundary() {
    return [NSString stringWithFormat:@"Boundary+%08X%08X", arc4random(), arc4random()];
}

/**
 回车换行
 */
static NSString * const kAFMultipartFormCRLF = @"\r\n";

/**
 生成开始边界字符串
 */
static inline NSString * AFMultipartFormInitialBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"--%@%@", boundary, kAFMultipartFormCRLF];
}

/**
 生成中间边界字符串
 */
static inline NSString * AFMultipartFormEncapsulationBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"%@--%@%@", kAFMultipartFormCRLF, boundary, kAFMultipartFormCRLF];
}

/**
 生成结束边界字符串
 */
static inline NSString * AFMultipartFormFinalBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"%@--%@--%@", kAFMultipartFormCRLF, boundary, kAFMultipartFormCRLF];
}

/**
 根据文件后缀名获取文件的MIME类型，即Content-Type字段的值
 */
static inline NSString * AFContentTypeForPathExtension(NSString *extension) {
    // 通过传入的文件后缀字符串生成一个UTI字符串（统一类型标识符是唯一标识抽象类型的字符串。它们可以用来描述文件格式或内存中的数据类型，但也可以用来描述其他类型的实体类型，如目录，卷或包。）
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    // 将UTI转成MIME类型
    NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
    if (!contentType) {
        return @"application/octet-stream";
    } else {
        return contentType;
    }
}

/**
 3G环境上传建议带宽
 */
NSUInteger const kAFUploadStream3GSuggestedPacketSize = 1024 * 16;
/**
 3G环境上传建议延时
 */
NSTimeInterval const kAFUploadStream3GSuggestedDelay = 0.2;


/**
 每一个AFHTTPBodyPart就是代表一项表单数据，即一个要上传的文件的数据，并由它自己读取它内部的数据
 */
@interface AFHTTPBodyPart : NSObject
// 编码方式
@property (nonatomic, assign) NSStringEncoding stringEncoding;
// 段落头
@property (nonatomic, strong) NSDictionary *headers;
// 边界
@property (nonatomic, copy) NSString *boundary;
// 内容
@property (nonatomic, strong) id body;
// 内容长度
@property (nonatomic, assign) unsigned long long bodyContentLength;
// 输入流
@property (nonatomic, strong) NSInputStream *inputStream;
// 是否有开始边界
@property (nonatomic, assign) BOOL hasInitialBoundary;
// 是否有结束边界
@property (nonatomic, assign) BOOL hasFinalBoundary;
// 是否有可读数据
@property (readonly, nonatomic, assign, getter = hasBytesAvailable) BOOL bytesAvailable;
// 内容长度
@property (readonly, nonatomic, assign) unsigned long long contentLength;

// 将AFHTTPBodyPart对象中的数据读出，并写入到buffer中，也就是AFHTTPBodyPart对象自己把自己保存的数据读取出来，然后写入到传递进来的参数buffer中
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length;
@end

/**
 AFMultipartBodyStream类继承自NSInputStream类，并遵守了NSStreamDelegate协议。这个类保存着用户要上传的数据，并在数据上传时控制数据的读取。
 */
@interface AFMultipartBodyStream : NSInputStream <NSStreamDelegate>
// 单个包的大小
@property (nonatomic, assign) NSUInteger numberOfBytesInPacket;
// 延时
@property (nonatomic, assign) NSTimeInterval delay;
// 输入流
@property (nonatomic, strong) NSInputStream *inputStream;
// 内容大小
@property (readonly, nonatomic, assign) unsigned long long contentLength;
// 是否为空
@property (readonly, nonatomic, assign, getter = isEmpty) BOOL empty;

/**
 通过编码方式初始化
 */
- (instancetype)initWithStringEncoding:(NSStringEncoding)encoding;
/**
 设置开始和结束边界
 */
- (void)setInitialAndFinalBoundaries;
/**
 添加AFHTTPBodyPart对象
 */
- (void)appendHTTPBodyPart:(AFHTTPBodyPart *)bodyPart;
@end

#pragma mark -

@interface AFStreamingMultipartFormData ()
// 保存传入的NSMutableURLRequest对象
@property (readwrite, nonatomic, copy) NSMutableURLRequest *request;
// 保存传入的编码方式
@property (readwrite, nonatomic, assign) NSStringEncoding stringEncoding;
// 保存边界字符串
@property (readwrite, nonatomic, copy) NSString *boundary;
// 保存输入数据流
@property (readwrite, nonatomic, strong) AFMultipartBodyStream *bodyStream;
@end

@implementation AFStreamingMultipartFormData

- (instancetype)initWithURLRequest:(NSMutableURLRequest *)urlRequest
                    stringEncoding:(NSStringEncoding)encoding
{
    self = [super init];
    if (!self) {
        return nil;
    }

    // 保存传入的参数，初始化私有属性
    self.request = urlRequest;
    self.stringEncoding = encoding;
    self.boundary = AFCreateMultipartFormBoundary();
    self.bodyStream = [[AFMultipartBodyStream alloc] initWithStringEncoding:encoding];

    return self;
}

- (void)setRequest:(NSMutableURLRequest *)request
{
    _request = [request mutableCopy];
}
#pragma mark - AFMultipartFormData协议方法的实现
- (BOOL)appendPartWithFileURL:(NSURL *)fileURL
                         name:(NSString *)name
                        error:(NSError * __autoreleasing *)error
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(fileURL);
    NSParameterAssert(name);

    // 通过文件的路径中获取带有后缀的文件名
    NSString *fileName = [fileURL lastPathComponent];
    // 通过文件的路径获取不带“.”的后缀名后获取文件的mime类型
    NSString *mimeType = AFContentTypeForPathExtension([fileURL pathExtension]);

    // 调用下面那个方法
    return [self appendPartWithFileURL:fileURL name:name fileName:fileName mimeType:mimeType error:error];
}

- (BOOL)appendPartWithFileURL:(NSURL *)fileURL
                         name:(NSString *)name
                     fileName:(NSString *)fileName
                     mimeType:(NSString *)mimeType
                        error:(NSError * __autoreleasing *)error
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(fileURL);
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);

    // 如果不是一个合法的文件路径
    if (![fileURL isFileURL]) {
        // 就生成一个错误信息赋值给传入的错误对象指针后返回
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedStringFromTable(@"Expected URL to be a file URL", @"AFNetworking", nil)};
        if (error) {
            *error = [[NSError alloc] initWithDomain:AFURLRequestSerializationErrorDomain code:NSURLErrorBadURL userInfo:userInfo];
        }

        return NO;
        
    // 如果文件路径无法访问
    } else if ([fileURL checkResourceIsReachableAndReturnError:error] == NO) {
        // 就生成一个错误信息赋值给传入的错误对象指针后返回
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedStringFromTable(@"File URL not reachable.", @"AFNetworking", nil)};
        if (error) {
            *error = [[NSError alloc] initWithDomain:AFURLRequestSerializationErrorDomain code:NSURLErrorBadURL userInfo:userInfo];
        }

        return NO;
    }

    // 通过文件路径获取文件的属性，如果获取不到则返回，因为无法获取到文件的大小
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileURL path] error:error];
    if (!fileAttributes) {
        return NO;
    }

    // 生成一个可变字典保存请求头的相关信息，并为Content-Disposition和Content-Type字段赋值
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];

    // 生成一个AFHTTPBodyPart对象保存要传输的内容，并添加到私有属性bodyStream中
    AFHTTPBodyPart *bodyPart = [[AFHTTPBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = mutableHeaders;
    bodyPart.boundary = self.boundary;
    bodyPart.body = fileURL;
    bodyPart.bodyContentLength = [fileAttributes[NSFileSize] unsignedLongLongValue];
    [self.bodyStream appendHTTPBodyPart:bodyPart];

    return YES;
}

- (void)appendPartWithInputStream:(NSInputStream *)inputStream
                             name:(NSString *)name
                         fileName:(NSString *)fileName
                           length:(int64_t)length
                         mimeType:(NSString *)mimeType
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);

    // 生成一个可变字典保存请求头的相关信息，并为Content-Disposition和Content-Type字段赋值
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];

    // 生成一个AFHTTPBodyPart对象保存要传输的内容，并添加到私有属性bodyStream中
    AFHTTPBodyPart *bodyPart = [[AFHTTPBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = mutableHeaders;
    bodyPart.boundary = self.boundary;
    bodyPart.body = inputStream;

    bodyPart.bodyContentLength = (unsigned long long)length;

    [self.bodyStream appendHTTPBodyPart:bodyPart];
}

- (void)appendPartWithFileData:(NSData *)data
                          name:(NSString *)name
                      fileName:(NSString *)fileName
                      mimeType:(NSString *)mimeType
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);

    // 生成一个可变字典保存请求头的相关信息，并为Content-Disposition和Content-Type字段赋值
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];

    // 调用下下面的那个方法
    [self appendPartWithHeaders:mutableHeaders body:data];
}

- (void)appendPartWithFormData:(NSData *)data
                          name:(NSString *)name
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(name);

    // 生成一个可变字典保存请求头的相关信息，并为Content-Disposition和Content-Type字段赋值
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"", name] forKey:@"Content-Disposition"];

    // 调用下面的那个方法
    [self appendPartWithHeaders:mutableHeaders body:data];
}

- (void)appendPartWithHeaders:(NSDictionary *)headers
                         body:(NSData *)body
{
    // 在debug模式下缺少对应参数会crash
    NSParameterAssert(body);

    // 生成一个AFHTTPBodyPart对象保存要传输的内容，并添加到私有属性bodyStream中
    AFHTTPBodyPart *bodyPart = [[AFHTTPBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = headers;
    bodyPart.boundary = self.boundary;
    bodyPart.bodyContentLength = [body length];
    bodyPart.body = body;

    [self.bodyStream appendHTTPBodyPart:bodyPart];
}

- (void)throttleBandwidthWithPacketSize:(NSUInteger)numberOfBytes
                                  delay:(NSTimeInterval)delay
{
    // 设置发送单个包的大小和请求延迟
    self.bodyStream.numberOfBytesInPacket = numberOfBytes;
    self.bodyStream.delay = delay;
}

- (NSMutableURLRequest *)requestByFinalizingMultipartFormData {
    // 如果没有数据流就直接返回NSMutableURLRequest对象
    if ([self.bodyStream isEmpty]) {
        return self.request;
    }
    
    // 设置数据流的开始和结束边界
    // Reset the initial and final boundaries to ensure correct Content-Length
    [self.bodyStream setInitialAndFinalBoundaries];
    // 将数据流赋值给NSMutableURLRequest对象
    [self.request setHTTPBodyStream:self.bodyStream];

    // 为NSMutableURLRequest对象的请求头的Content-Type和Content-Length字段赋值
    [self.request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", self.boundary] forHTTPHeaderField:@"Content-Type"];
    [self.request setValue:[NSString stringWithFormat:@"%llu", [self.bodyStream contentLength]] forHTTPHeaderField:@"Content-Length"];

    return self.request;
}

@end

#pragma mark -
/**
 因为AFMultipartBodyStream类继承自NSInputStream类，而NSInputStream继承自NSStream类，
 但NSStream类的streamStatus属性和streamError属性是readonly，想要在AFMultipartBodyStream类内部使用读写这两个属性，于是添加了类扩展，改为私有可读写的。
 
 但这样会出现一个问题：原本只要通过@property声明属性，编译器就会自动帮我们生成getter、setter和成员变量，
 但是子类通过@property覆盖了父类的属性，这时编译器就不会自动生成成员变量，
 因此在AFMultipartBodyStream类的@implementation中可以看到@synthesize streamStatus;和@synthesize streamError;两句代码来生成成员变量；
 */
@interface NSStream ()
@property (readwrite) NSStreamStatus streamStatus;
@property (readwrite, copy) NSError *streamError;
@end

@interface AFMultipartBodyStream () <NSCopying>
// 编码方式
@property (readwrite, nonatomic, assign) NSStringEncoding stringEncoding;
// 保存AFHTTPBodyPart的数组
@property (readwrite, nonatomic, strong) NSMutableArray *HTTPBodyParts;
// 保存对属性HTTPBodyParts内容的遍历
@property (readwrite, nonatomic, strong) NSEnumerator *HTTPBodyPartEnumerator;
// 当前读写的HTTPBodyPart
@property (readwrite, nonatomic, strong) AFHTTPBodyPart *currentHTTPBodyPart;
// 输出流
@property (readwrite, nonatomic, strong) NSOutputStream *outputStream;
// 缓冲
@property (readwrite, nonatomic, strong) NSMutableData *buffer;
@end

@implementation AFMultipartBodyStream
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1100)
@synthesize delegate;
#endif

@synthesize streamStatus;
@synthesize streamError;

- (instancetype)initWithStringEncoding:(NSStringEncoding)encoding {
    self = [super init];
    if (!self) {
        return nil;
    }

    // 保存传入的参数和初始化属性
    self.stringEncoding = encoding;
    self.HTTPBodyParts = [NSMutableArray array];
    self.numberOfBytesInPacket = NSIntegerMax;

    return self;
}

- (void)setInitialAndFinalBoundaries {
    // 如果属性HTTPBodyParts内有元素，就将第一个元素设置为有开始边界，最后一个元素设置为有结束边界，其他元素都设置为无
    if ([self.HTTPBodyParts count] > 0) {
        for (AFHTTPBodyPart *bodyPart in self.HTTPBodyParts) {
            bodyPart.hasInitialBoundary = NO;
            bodyPart.hasFinalBoundary = NO;
        }

        [[self.HTTPBodyParts firstObject] setHasInitialBoundary:YES];
        [[self.HTTPBodyParts lastObject] setHasFinalBoundary:YES];
    }
}

- (void)appendHTTPBodyPart:(AFHTTPBodyPart *)bodyPart {
    // 向HTTPBodyParts属性内添加元素
    [self.HTTPBodyParts addObject:bodyPart];
}

- (BOOL)isEmpty {
    // 判断HTTPBodyParts属性内是否有元素
    return [self.HTTPBodyParts count] == 0;
}

#pragma mark - 对父类NSInputStream方法的重写

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length {
    // 如果输入流的状态是关闭就结束
    if ([self streamStatus] == NSStreamStatusClosed) {
        return 0;
    }

    // 定义变量记录已读取总数
    NSInteger totalNumberOfBytesRead = 0;

    // 只要已读取的数量小于限定的数量和包的总数量二者中的最小值
    while ((NSUInteger)totalNumberOfBytesRead < MIN(length, self.numberOfBytesInPacket)) {
        // 如果当前HTTPBodyPart为空或者没有可读数据
        if (!self.currentHTTPBodyPart || ![self.currentHTTPBodyPart hasBytesAvailable]) {
            // 为currentHTTPBodyPart赋值，但如果下一个元素为空则跳出循环
            if (!(self.currentHTTPBodyPart = [self.HTTPBodyPartEnumerator nextObject])) {
                break;
            }
            
        // 如果当前HTTPBodyPart有值
        } else {
            // 计算还能读取的最大数量
            NSUInteger maxLength = MIN(length, self.numberOfBytesInPacket) - (NSUInteger)totalNumberOfBytesRead;
            
            // 将currentHTTPBodyPart中的数据写入到buffer中
            NSInteger numberOfBytesRead = [self.currentHTTPBodyPart read:&buffer[totalNumberOfBytesRead] maxLength:maxLength];
            // 如果写入失败
            if (numberOfBytesRead == -1) {
                // 记录错误并跳出循环
                self.streamError = self.currentHTTPBodyPart.inputStream.streamError;
                break;
            } else {
                // 记录当前已读总数
                totalNumberOfBytesRead += numberOfBytesRead;
                
                // 如果设置了延时，就在当前线程延时一段时间
                if (self.delay > 0.0f) {
                    [NSThread sleepForTimeInterval:self.delay];
                }
            }
        }
    }

    return totalNumberOfBytesRead;
}

- (BOOL)getBuffer:(__unused uint8_t **)buffer
           length:(__unused NSUInteger *)len
{
    // 关闭读取缓存的方法
    return NO;
}

- (BOOL)hasBytesAvailable {
    // 只要状态为开就是有数据
    return [self streamStatus] == NSStreamStatusOpen;
}

#pragma mark - 对父类NSInputStream的父类NSStream方法的重写

- (void)open {
    // 如果流的状态是打开就不继续执行
    if (self.streamStatus == NSStreamStatusOpen) {
        return;
    }
    
    // 将流的状态设置为打开
    self.streamStatus = NSStreamStatusOpen;

    // 设置开始和结束边界
    [self setInitialAndFinalBoundaries];
    
    // 初始化HTTPBodyPartEnumerator属性
    self.HTTPBodyPartEnumerator = [self.HTTPBodyParts objectEnumerator];
}

- (void)close {
    // 将流的状态设置为关闭
    self.streamStatus = NSStreamStatusClosed;
}

- (id)propertyForKey:(__unused NSString *)key {
    // 关闭对key属性的查询
    return nil;
}

- (BOOL)setProperty:(__unused id)property
             forKey:(__unused NSString *)key
{
    // 关闭对key属性的赋值
    return NO;
}

// 将设置和移除运行环境的方法设置为什么都不做
- (void)scheduleInRunLoop:(__unused NSRunLoop *)aRunLoop
                  forMode:(__unused NSString *)mode
{}

- (void)removeFromRunLoop:(__unused NSRunLoop *)aRunLoop
                  forMode:(__unused NSString *)mode
{}

- (unsigned long long)contentLength {
    // 遍历HTTPBodyParts中的元素计算总长度
    unsigned long long length = 0;
    for (AFHTTPBodyPart *bodyPart in self.HTTPBodyParts) {
        length += [bodyPart contentLength];
    }

    return length;
}

#pragma mark - Undocumented CFReadStream Bridged Methods
/**
 对父类NSInputStream的父类NSStream私有方法的重写
 
 为什么要重写私有方法？因为NSMutableURLRequest的setHTTPBodyStream方法接受的是一个NSInputStream *参数，那我们要自定义NSInputStream的话，创建一个NSInputStream的子类传给它是不是就可以了？实际上不行，这样做后用NSMutableURLRequest发出请求会导致crash，提示[xx _scheduleInCFRunLoop:forMode:]: unrecognized selector。
 这是因为NSMutableURLRequest实际上接受的不是NSInputStream对象，而是CoreFoundation的CFReadStreamRef对象，因为CFReadStreamRef和NSInputStream是toll-free bridged，可以自由转换，但CFReadStreamRef会用到CFStreamScheduleWithRunLoop这个方法，当它调用到这个方法时，object-c的toll-free bridging机制会调用object-c对象NSInputStream的相应函数，这里就调用到了_scheduleInCFRunLoop:forMode:，若不实现这个方法就会crash。

 以上解释来自：http://blog.cnbang.net/tech/2371/
 */
- (void)_scheduleInCFRunLoop:(__unused CFRunLoopRef)aRunLoop
                     forMode:(__unused CFStringRef)aMode
{}

- (void)_unscheduleFromCFRunLoop:(__unused CFRunLoopRef)aRunLoop
                         forMode:(__unused CFStringRef)aMode
{}

- (BOOL)_setCFClientFlags:(__unused CFOptionFlags)inFlags
                 callback:(__unused CFReadStreamClientCallBack)inCallback
                  context:(__unused CFStreamClientContext *)inContext {
    return NO;
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    // 拷贝了HTTPBodyParts并设置了启示和结束边界
    AFMultipartBodyStream *bodyStreamCopy = [[[self class] allocWithZone:zone] initWithStringEncoding:self.stringEncoding];

    for (AFHTTPBodyPart *bodyPart in self.HTTPBodyParts) {
        [bodyStreamCopy appendHTTPBodyPart:[bodyPart copy]];
    }

    [bodyStreamCopy setInitialAndFinalBoundaries];

    return bodyStreamCopy;
}

@end

#pragma mark -

typedef enum {
    AFEncapsulationBoundaryPhase = 1,   // 中间边界段落
    AFHeaderPhase                = 2,   // 头段落
    AFBodyPhase                  = 3,   // 内容段落
    AFFinalBoundaryPhase         = 4,   // 结束边界段落
} AFHTTPBodyPartReadPhase;

@interface AFHTTPBodyPart () <NSCopying> {
    AFHTTPBodyPartReadPhase _phase;     // 保存要读取的段落，其实就是利用状态机模式控制对AFHTTPBodyPart对象不同内容的读取
    NSInputStream *_inputStream;        // 保存由AFHTTPBodyPart对象的body属性生成的输入流对象
    unsigned long long _phaseReadOffset;// 保存当前已读取字节数，用来计算读取进度
}
/**
 切换到下一段落进行读取，即控制状态机的状态
 */
- (BOOL)transitionToNextPhase;
/**
 将AFHTTPBodyPart对象的属性中保存的数据转成的NSDdata对象写入到buffer中
 */
- (NSInteger)readData:(NSData *)data
           intoBuffer:(uint8_t *)buffer
            maxLength:(NSUInteger)length;
@end

@implementation AFHTTPBodyPart

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    // 切换到主线程，初始化成员变量_phase为AFEncapsulationBoundaryPhase，_phaseReadOffset为0
    [self transitionToNextPhase];

    return self;
}

- (void)dealloc {
    // 关闭输入流并置空
    if (_inputStream) {
        [_inputStream close];
        _inputStream = nil;
    }
}

/**
 inputStream的懒加载方法
 */
- (NSInputStream *)inputStream {
    if (!_inputStream) {
        // 根据body属性的类生成对应的NSInputStream对象并保存
        if ([self.body isKindOfClass:[NSData class]]) {
            _inputStream = [NSInputStream inputStreamWithData:self.body];
            
        } else if ([self.body isKindOfClass:[NSURL class]]) {
            _inputStream = [NSInputStream inputStreamWithURL:self.body];
            
        } else if ([self.body isKindOfClass:[NSInputStream class]]) {
            _inputStream = self.body;
            
        } else {
            _inputStream = [NSInputStream inputStreamWithData:[NSData data]];
        }
    }

    return _inputStream;
}

/**
 将headers属性所保存的字典类型的数据拼接成指定格式的字符串
 */
- (NSString *)stringForHeaders {
    NSMutableString *headerString = [NSMutableString string];
    for (NSString *field in [self.headers allKeys]) {
        [headerString appendString:[NSString stringWithFormat:@"%@: %@%@", field, [self.headers valueForKey:field], kAFMultipartFormCRLF]];
    }
    [headerString appendString:kAFMultipartFormCRLF];

    return [NSString stringWithString:headerString];
}

/**
 获取内容的总长度
 */
- (unsigned long long)contentLength {
    unsigned long long length = 0;

    // 如果有开始边界就生成开始边界字符串，否则就生成中间边界字符串，然后生成对应的NSData对象，并获取长度
    NSData *encapsulationBoundaryData = [([self hasInitialBoundary] ? AFMultipartFormInitialBoundary(self.boundary) : AFMultipartFormEncapsulationBoundary(self.boundary)) dataUsingEncoding:self.stringEncoding];
    length += [encapsulationBoundaryData length];

    // 添加header对应的NSData对象的长度
    NSData *headersData = [[self stringForHeaders] dataUsingEncoding:self.stringEncoding];
    length += [headersData length];

    // 添加body对应的NSData对象的长度
    length += _bodyContentLength;

    // 如果有结束边界就生成结束边界字符串，否则就生成中间边界字符串，然后生成对应的NSData对象，并获取长度后添加
    NSData *closingBoundaryData = ([self hasFinalBoundary] ? [AFMultipartFormFinalBoundary(self.boundary) dataUsingEncoding:self.stringEncoding] : [NSData data]);
    length += [closingBoundaryData length];

    return length;
}

/**
 判断是否有可读数据
 */
- (BOOL)hasBytesAvailable {
    // Allows `read:maxLength:` to be called again if `AFMultipartFormFinalBoundary` doesn't fit into the available buffer
    if (_phase == AFFinalBoundaryPhase) {
        return YES;
    }

    // 根据inputStream的属性streamStatus来判断是否有可读数据
    switch (self.inputStream.streamStatus) {
        case NSStreamStatusNotOpen:
        case NSStreamStatusOpening:
        case NSStreamStatusOpen:
        case NSStreamStatusReading:
        case NSStreamStatusWriting:
            return YES;
        case NSStreamStatusAtEnd:
        case NSStreamStatusClosed:
        case NSStreamStatusError:
        default:
            return NO;
    }
}

/**
 将自身的数据写入到buffer中
 */
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length {
    NSInteger totalNumberOfBytesRead = 0;
    
    // 如果要读取的段落是中间边界段落
    if (_phase == AFEncapsulationBoundaryPhase) {
        // 根据是否有开始边界生成对应的边界字符串，然后生成相应的NSData对象，写入到butter中
        NSData *encapsulationBoundaryData = [([self hasInitialBoundary] ? AFMultipartFormInitialBoundary(self.boundary) : AFMultipartFormEncapsulationBoundary(self.boundary)) dataUsingEncoding:self.stringEncoding];
        totalNumberOfBytesRead += [self readData:encapsulationBoundaryData intoBuffer:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
    }

    // 如果要读取的段落是头部段落
    if (_phase == AFHeaderPhase) {
        // 将header编码写入到buffer中
        NSData *headersData = [[self stringForHeaders] dataUsingEncoding:self.stringEncoding];
        totalNumberOfBytesRead += [self readData:headersData intoBuffer:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
    }

    // 如果要读取的段落是内容段落
    if (_phase == AFBodyPhase) {
        // 将属性body中保存的数据转为NSInputStream对象再写入到buffer中
        NSInteger numberOfBytesRead = 0;

        numberOfBytesRead = [self.inputStream read:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
        if (numberOfBytesRead == -1) {
            return -1;
        } else {
            totalNumberOfBytesRead += numberOfBytesRead;

            // 如果inputStream的状态是结束、关闭或者出错，就切换状态机的状态
            if ([self.inputStream streamStatus] >= NSStreamStatusAtEnd) {
                [self transitionToNextPhase];
            }
        }
    }

    // 如果要读取的段落是结束边界段落
    if (_phase == AFFinalBoundaryPhase) {
        // 根据是否有结束边界生成对应的边界字符串，然后生成相应的NSData对象，写入到butter中
        NSData *closingBoundaryData = ([self hasFinalBoundary] ? [AFMultipartFormFinalBoundary(self.boundary) dataUsingEncoding:self.stringEncoding] : [NSData data]);
        totalNumberOfBytesRead += [self readData:closingBoundaryData intoBuffer:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
    }

    return totalNumberOfBytesRead;
}

/**
 将data中的数据写入到buffer中
 */
- (NSInteger)readData:(NSData *)data
           intoBuffer:(uint8_t *)buffer
            maxLength:(NSUInteger)length
{
    // 计算要读取的范围
    NSRange range = NSMakeRange((NSUInteger)_phaseReadOffset, MIN([data length] - ((NSUInteger)_phaseReadOffset), length));
    // 根据计算好的范围读写
    [data getBytes:buffer range:range];

    // 记录读写的进度
    _phaseReadOffset += range.length;

    // 如果data中的数据读写完成，就切换状态机的状态
    if (((NSUInteger)_phaseReadOffset) >= [data length]) {
        [self transitionToNextPhase];
    }

    return (NSInteger)range.length;
}

/**
 切换到下一段落进行读取，即控制状态机的状态
 */
- (BOOL)transitionToNextPhase {
    // 如果该方法不是在主线程调用，就切换到主线程
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self transitionToNextPhase];
        });
        return YES;
    }

    // 根据目前正在读取的段落，修改接下来要读取的段落
    switch (_phase) {
        // 如果现在读取的是中间边界段落，接下来就要读取头部段落
        case AFEncapsulationBoundaryPhase:
            _phase = AFHeaderPhase;
            break;
            
        // 如果现在读取的是头部段落，接下来就要读取内容段落，初始化inputStream添加到当前运行循环中，并开启
        case AFHeaderPhase:
            [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [self.inputStream open];
            _phase = AFBodyPhase;
            break;
        
        // 如果现在读取的是内容段落，接下来就要读取结束边界段落，关闭inputStream
        case AFBodyPhase:
            [self.inputStream close];
            _phase = AFFinalBoundaryPhase;
            break;
            
        // 如果现在读取的是结束边界段落，就赋值为中间边界段落
        case AFFinalBoundaryPhase:
        default:
            _phase = AFEncapsulationBoundaryPhase;
            break;
    }
 
    // 段落读取偏移量置零
    _phaseReadOffset = 0;

    return YES;
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    AFHTTPBodyPart *bodyPart = [[[self class] allocWithZone:zone] init];

    // 复制了主要属性
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = self.headers;
    bodyPart.bodyContentLength = self.bodyContentLength;
    bodyPart.body = self.body;
    bodyPart.boundary = self.boundary;

    return bodyPart;
}

@end

#pragma mark -
/**
 当服务器要求我们上传的数据格式类型为json时，就可以使用此类
 */
@implementation AFJSONRequestSerializer

+ (instancetype)serializer {
    // 调用下面的方法并传默认的JSON输出格式
    return [self serializerWithWritingOptions:(NSJSONWritingOptions)0];
}

+ (instancetype)serializerWithWritingOptions:(NSJSONWritingOptions)writingOptions
{
    // 调用父类的初始化方法并保存了传入的参数
    AFJSONRequestSerializer *serializer = [[self alloc] init];
    serializer.writingOptions = writingOptions;

    return serializer;
}

#pragma mark - AFURLRequestSerialization协议方法的实现

- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(id)parameters
                                        error:(NSError *__autoreleasing *)error
{
    // 缺少request则会crash
    NSParameterAssert(request);

    // 如果HTTP请求方法为GET、HEAD或DELETE其中之一
    if ([self.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
        // 就直接调用父类的实现并返回
        return [super requestBySerializingRequest:request withParameters:parameters error:error];
    }

    NSMutableURLRequest *mutableRequest = [request mutableCopy];

    // 遍历request的请求头，对没有值的字段进行赋值
    [self.HTTPRequestHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
        if (![request valueForHTTPHeaderField:field]) {
            [mutableRequest setValue:value forHTTPHeaderField:field];
        }
    }];

    // 如果传入了参数
    if (parameters) {
        // 如果mutableRequest的请求头的Content-Type字段没有值
        if (![mutableRequest valueForHTTPHeaderField:@"Content-Type"]) {
            // 为mutableRequest的请求头的Content-Type字段赋值为application/json
            [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        }

        if (![NSJSONSerialization isValidJSONObject:parameters]) {
            if (error) {
                NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedStringFromTable(@"The `parameters` argument is not valid JSON.", @"AFNetworking", nil)};
                *error = [[NSError alloc] initWithDomain:AFURLRequestSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:userInfo];
            }
            return nil;
        }
        
        // 将传入的parameters转成JSON格式的NSData对象并添加到mutableRequest的请求体中
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:self.writingOptions error:error];
        
        if (!jsonData) {
            return nil;
        }
        
        [mutableRequest setHTTPBody:jsonData];
    }

    return mutableRequest;
}

#pragma mark - NSSecureCoding
// 就是在父类的基础上添加了writingOptions属性
- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }

    self.writingOptions = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(writingOptions))] unsignedIntegerValue];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:@(self.writingOptions) forKey:NSStringFromSelector(@selector(writingOptions))];
}

#pragma mark - NSCopying
// 同样也是在父类的基础上添加了writingOptions属性
- (instancetype)copyWithZone:(NSZone *)zone {
    AFJSONRequestSerializer *serializer = [super copyWithZone:zone];
    serializer.writingOptions = self.writingOptions;

    return serializer;
}

@end

#pragma mark -

@implementation AFPropertyListRequestSerializer

+ (instancetype)serializer {
    // 调用下面的实例化方法，设置plist的输出格式为XML类型
    return [self serializerWithFormat:NSPropertyListXMLFormat_v1_0 writeOptions:0];
}

+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format
                        writeOptions:(NSPropertyListWriteOptions)writeOptions
{
    // 调用父类的初始化方法并保存了传入的参数
    AFPropertyListRequestSerializer *serializer = [[self alloc] init];
    serializer.format = format;
    serializer.writeOptions = writeOptions;

    return serializer;
}

#pragma mark - AFURLRequestSerializer协议方法的实现

- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(id)parameters
                                        error:(NSError *__autoreleasing *)error
{
    // 缺少request则会crash
    NSParameterAssert(request);

    // 如果HTTP请求方法为GET、HEAD或DELETE其中之一
    if ([self.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
        // 就直接调用父类的实现并返回
        return [super requestBySerializingRequest:request withParameters:parameters error:error];
    }

    NSMutableURLRequest *mutableRequest = [request mutableCopy];

    // 遍历request的请求头，对没有值的字段进行赋值
    [self.HTTPRequestHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
        if (![request valueForHTTPHeaderField:field]) {
            [mutableRequest setValue:value forHTTPHeaderField:field];
        }
    }];

    // 如果传入了参数
    if (parameters) {
        // 如果mutableRequest的请求头的Content-Type字段没有值
        if (![mutableRequest valueForHTTPHeaderField:@"Content-Type"]) {
            // 为mutableRequest的请求头的Content-Type字段赋值application/x-plist
            [mutableRequest setValue:@"application/x-plist" forHTTPHeaderField:@"Content-Type"];
        }

        // 将传入的parameters转成plist格式的NSData对象并添加到mutableRequest的请求体中
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:parameters format:self.format options:self.writeOptions error:error];
        
        if (!plistData) {
            return nil;
        }
        
        [mutableRequest setHTTPBody:plistData];
    }

    return mutableRequest;
}

#pragma mark - NSSecureCoding
// 同样也是在父类的基础上添加了format、writingOptions属性
- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }

    self.format = (NSPropertyListFormat)[[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(format))] unsignedIntegerValue];
    self.writeOptions = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(writeOptions))] unsignedIntegerValue];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:@(self.format) forKey:NSStringFromSelector(@selector(format))];
    [coder encodeObject:@(self.writeOptions) forKey:NSStringFromSelector(@selector(writeOptions))];
}

#pragma mark - NSCopying
// 同样也是在父类的基础上添加了format、writingOptions属性

- (instancetype)copyWithZone:(NSZone *)zone {
    AFPropertyListRequestSerializer *serializer = [super copyWithZone:zone];
    serializer.format = self.format;
    serializer.writeOptions = self.writeOptions;

    return serializer;
}

@end
