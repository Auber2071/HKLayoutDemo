//
//  PSPDFWebAnnotationView.m
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "PSPDFWebAnnotationView.h"

@implementation PSPDFWebAnnotationView {
    BOOL shadowsHidden_;
    NSUInteger requestCount_;
}

@synthesize annotation = annotation_;
@synthesize webView = webView_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)loadingStatusChanged_ {
    PSPDFLog(@"Finished loading %@", webView_.URL);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        PSPDFRegisterObject(self);

        // 页面自适应屏幕 UIWebview 的 scaletofit
        NSString *scaleToFitJS = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width, user-scalable=no'); document.getElementsByTagName('head')[0].appendChild(meta);";
        WKUserScript *scaleToFitUS = [[WKUserScript alloc] initWithSource:scaleToFitJS injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        // 禁止网页长按弹出系统放大镜,编辑等信息
        NSString *selectDisableJS = @"document.documentElement.style.webkitUserSelect='none';";
        WKUserScript *selectDisableUS = [[WKUserScript alloc] initWithSource:selectDisableJS injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        NSString *editDisableJS = @"document.documentElement.style.webkitTouchCallout='none';";
        WKUserScript *editDisableUS = [[WKUserScript alloc] initWithSource:editDisableJS injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        
        // 添加到用户控制器
        WKUserContentController *wkUController = [[WKUserContentController alloc] init];
        [wkUController addUserScript:scaleToFitUS];
        [wkUController addUserScript:selectDisableUS];
        [wkUController addUserScript:editDisableUS];
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.allowsInlineMediaPlayback = YES;
        config.userContentController = wkUController;
        
        webView_ = [[WKWebView alloc] initWithFrame:[UIScreen mainScreen].bounds configuration:config];
        webView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:webView_];
        webView_.navigationDelegate = self;
    }
    return self;
}

- (void)dealloc {
    // "the deallocation problem" - it's not safe to dealloc a controler from a thread different than the main thread
    // http://developer.apple.com/library/ios/#technotes/tn2109/_index.html#//apple_ref/doc/uid/DTS40010274-CH1-SUBSECTION11
    NSAssert([NSThread isMainThread], @"Must run on main thread, see http://developer.apple.com/library/ios/#technotes/tn2109/_index.html#//apple_ref/doc/uid/DTS40010274-CH1-SUBSECTION11");
    PSPDFDeregisterObject(self);
    webView_.navigationDelegate = nil; // delegate is self here, so first set to nil before call stopLoading.
    [webView_ stopLoading];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    webView_.frame = self.bounds;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setAnnotation:(PSPDFAnnotation *)annotation {
    if (annotation != annotation_) {
        annotation_  = annotation;
        
        [self.webView loadRequest:[NSURLRequest requestWithURL:annotation.URL]];
    }
}

- (BOOL)shadowsHidden {
	for (UIView *view in [webView_ subviews]) {
		if ([view isKindOfClass:[UIScrollView class]]) {
			for (UIView *innerView in [view subviews]) {
				if ([innerView isKindOfClass:[UIImageView class]]) {
					return [innerView isHidden];
				}
			}
		}
	}
	return NO;
}

- (void)setShadowsHidden:(BOOL)hide {
	if (shadowsHidden_ == hide) {
		return;
	}    
	shadowsHidden_ = hide;
    
	for (UIView *view in [webView_ subviews]) {
		if ([view isKindOfClass:[UIScrollView class]]) {
			for (UIView *innerView in [view subviews]) {
				if ([innerView isKindOfClass:[UIImageView class]]) {
					innerView.hidden = shadowsHidden_;
				}
			}
		}
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    requestCount_++;
}

/// 5 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    requestCount_--;
    if (requestCount_ == 0) {
        [self loadingStatusChanged_];
    }
}

/// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
   requestCount_--;
   if (requestCount_ == 0) {
       [self loadingStatusChanged_];
   }
}

@end
