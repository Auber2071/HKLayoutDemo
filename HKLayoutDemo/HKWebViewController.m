//
//  HKWebViewController.m
//  HKLayoutDemo
//
//  Created by ALPS on 2024/4/16.
//  Copyright © 2024 Edward. All rights reserved.
//

#import "HKWebViewController.h"
#import <WebKit/WebKit.h>

@interface HKWebViewController ()<UIWebViewDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) WKWebView *wkWebView;
@end

@implementation HKWebViewController

+ (void)load {
    NSLog(@"load------%s", __func__);
}

+ (void)initialize {
    NSLog(@"initialize--------%s", __func__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

//MARK: - 问开发者是否下载并载入当前 URL、而且 WKWebView 在 URL 下载完毕之后还会发一次询问，让开发者根据服务器返回的 Web 内容再次做一次确定
#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return YES;
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)navigationResponse.response;
    id cookies = [httpResponse.allHeaderFields objectForKey:@"Set-Cookie"];
    if(cookies) {
        // Cookie 写入 NSHttpCookieStorage
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}


//MARK: - 下载之前会调用一次 开始下载 回调，通知开发者 Web 已经开始下载。
#pragma mark - UIWebViewDelegate
- (void)webViewDidStartLoad:(UIWebView *)webView {}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
}


//MARK: - 页面下载完毕之后，UIWebView 会直接载入视图并调用载入成功回调，而WKWebView 会发询问，确定下载的内容被允许之后再载入视图。
#pragma mark - UIWebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView {
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
}


//MARK: - 成功则调用成功回调，整个流程有错误发生都会发出错误回调。

#pragma mark - UIWebViewDelegate
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
}


//MARK: - 重定向通知，在收到服务器重定向消息并且跳转询问允许之后，会回调重定向方法，这点是 UIWebView 没有的
#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
}


//MARK: - WKWebView 是跨进程的方案，当 WKWebView 进程退出时，会对主进程做一次方法回调。
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView API_AVAILABLE(macosx(10.11), ios(9.0)) {
    
}

//MARK: - HTTPS 证书自定义处理
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
}

#pragma mark - WKUIDelegate


//MARK: - Native 通知 JS
/**
 * WKWebView 的这个接口是异步的，而 UIWebView 是同步接口
 */
- (void)nativeToJS {
#pragma mark - UIWebView
    NSString *title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    
#pragma mark - WKWebView
    [self.wkWebView evaluateJavaScript:@"document.title"
                     completionHandler:^(id _Nullable ret, NSError * _Nullable error) {
        NSString *title = ret;
    }];
}

//MARK: - JS 通知 Native
/**
 * UIWebView:
 * 在 iOS 6 之前，UIWebView 是不支持共享对象的，Web 端需要通知 Native，需要通过修改 location.url，利用跳转询问协议来间接实现，通过定义 URL 元素组成来规范协议
 * 在 iOS 7 之后新增了 JavaScriptCore 库，内部有一个 JSContext 对象，可实现共享
 *
 * WKWebView:
 * WKWebView 上，Web 的 window 对象提供 WebKit 对象实现共享
 * 而 WKWebView 绑定共享对象，是通过特定的构造方法实现，参考代码，通过指定 UserContentController 对象的 ScriptMessageHandler 经过 Configuration 参数构造时传入
 *
 **/
- (void)jsToNative {
    WKUserContentController *userContent = [[WKUserContentController alloc] init];
    //重复添加相同name会crush的风险
    [userContent addScriptMessageHandler:self name:@"MyNative"];
//    [userContent addScriptMessageHandler:id<WKScriptMessageHandler> name:@"MyNative"];
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContent;
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
}


// 而 handler 对象需要实现指定协议，实现指定的协议方法，当 JS 端通过  window.webkit.messageHandlers 发送 Native 消息时，handler 对象的协议方法被调用，通过协议方法的相关参数传值
// Javascriptfunction callNative() {  window.webkit.messageHandlers.MyNative.postMessage('body');}

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
}


@end
