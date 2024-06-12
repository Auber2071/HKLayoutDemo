//
//  PSPDFWebViewController.m
//  PSPDFKitExample
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//  Parts of this code are based on https://github.com/samvermette/SVWebViewController. Thanks, Sam Vermette!
//

#import "PSPDFActionSheet.h"
#import "PSPDFWebViewController.h"
#import "PSPDFTransparentToolbar.h"
#import "PSPDFIconGenerator.h"
#import "NSURL+PSPDFUnicodeURL.h"
#import <MessageUI/MessageUI.h>

@interface PSPDFWebViewController () <MFMailComposeViewControllerDelegate, UIActionSheetDelegate> {
    BOOL toolbarWasHidden_;
    UIBarButtonItem *backBarButtonItem_;
    UIBarButtonItem *forwardBarButtonItem_;
    UIBarButtonItem *actionBarButtonItem_;
    UIBarButtonItem *stopBarButtonItem_;
    UIBarButtonItem *refreshBarButtonItem_;
}
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, retain) PSPDFActionSheet *pageActionSheet;
@end

@implementation PSPDFWebViewController

@synthesize webView = webView_;
@synthesize URL = URL_;
@synthesize availableActions = availableActions_;
@synthesize pageActionSheet = pageActionSheet_;
@synthesize popoverController = popoverController_; // _popoverController is already used!

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Static

+ (UINavigationController *)modalWebViewWithURL:(NSURL *)URL {
    PSPDFWebViewController *webViewController = [[PSPDFWebViewController alloc] initWithURL:URL];
    webViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:webViewController action:@selector(doneButtonClicked:)];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    return navController;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

// clear delegate, stop loading, deallocate
- (void)cleanupWebView {
    URL_ = nil;
    webView_.navigationDelegate = nil; // delegate is self here, so first set to nil before call stopLoading.
    [webView_ stopLoading];
    webView_ = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Target selectors

- (void)updateToolbarItems {
    backBarButtonItem_.enabled = webView_.canGoBack;
    forwardBarButtonItem_.enabled = webView_.canGoForward;
    actionBarButtonItem_.enabled = !webView_.isLoading;
    
    UIBarButtonItem *refreshStopBarButtonItem = webView_.isLoading ? stopBarButtonItem_ : refreshBarButtonItem_;
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixedSpace.width = 5.0f;
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    NSArray *items;
    if (PSIsIpad()) {
        CGFloat toolbarWidth = 250.0f;
        if(self.availableActions == 0) {
            toolbarWidth = 200.0f;
            items = [NSArray arrayWithObjects:
                     fixedSpace,
                     refreshStopBarButtonItem,
                     flexibleSpace,
                     backBarButtonItem_,
                     flexibleSpace,
                     forwardBarButtonItem_,
                     fixedSpace,
                     nil];
        } else {
            items = [NSArray arrayWithObjects:
                     fixedSpace,
                     refreshStopBarButtonItem,
                     flexibleSpace,
                     backBarButtonItem_,
                     flexibleSpace,
                     forwardBarButtonItem_,
                     flexibleSpace,
                     actionBarButtonItem_,
                     fixedSpace,
                     nil];
        }
        
        // make toolbar more compact on small sizes
        CGFloat viewWidth = self.view.frame.size.width;
        if (viewWidth < 400.f) {
            toolbarWidth -= 70.f;
        }
        
        UIToolbar *toolbar = [[PSPDFTransparentToolbar alloc] init];
        toolbar.items = items;
        toolbar.frame = CGRectMake(0, 0, toolbarWidth, 44);
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
    }
    
    else {
        if(self.availableActions == 0) {
            items = [NSArray arrayWithObjects:
                     flexibleSpace,
                     backBarButtonItem_,
                     flexibleSpace,
                     forwardBarButtonItem_,
                     flexibleSpace,
                     refreshStopBarButtonItem,
                     flexibleSpace,
                     nil];
        } else {
            items = [NSArray arrayWithObjects:
                     fixedSpace,
                     backBarButtonItem_,
                     flexibleSpace,
                     forwardBarButtonItem_,
                     flexibleSpace,
                     refreshStopBarButtonItem,
                     flexibleSpace,
                     actionBarButtonItem_,
                     fixedSpace,
                     nil];
        }
        
        self.toolbarItems = items;
    }
}

- (void)goBack:(UIBarButtonItem *)sender {
    [webView_ goBack];
}

- (void)goForward:(UIBarButtonItem *)sender {
    [webView_ goForward];
}

- (void)reload:(UIBarButtonItem *)sender {
    [webView_ reload];
}

- (void)stop:(UIBarButtonItem *)sender {
    [webView_ stopLoading];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	[self updateToolbarItems];
}

- (void)action:(id)sender {
    if(pageActionSheet_) {
        [pageActionSheet_ destroy];
        [pageActionSheet_.actionSheet dismissWithClickedButtonIndex:0 animated:YES];
        pageActionSheet_ = nil;
        return;
    }
    
    // create action sheet
    pageActionSheet_ = [[PSPDFActionSheet alloc] initWithTitle:webView_.URL.absoluteString];
    pageActionSheet_.delegate = self;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    if (self.availableActions & PSPDFWebViewControllerAvailableActionsCopyLink) {
        [pageActionSheet_ addButtonWithTitle:PSPDFLocalize(@"Copy Link") block:^{
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = self.webView.URL.absoluteString;
        }];
    }
    
    if (self.availableActions & PSPDFWebViewControllerAvailableActionsOpenInSafari) {
        [pageActionSheet_ addButtonWithTitle:PSPDFLocalize(@"Open in Safari") block:^{
            [[UIApplication sharedApplication] openURL:self.webView.URL];
        }];
    }
    
    if (self.availableActions & PSPDFWebViewControllerAvailableActionsMailLink) {
        [pageActionSheet_ addButtonWithTitle:PSPDFLocalize(@"Mail Link to this Page") block:^{
            MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
            mailViewController.mailComposeDelegate = self;
            [self.webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                if (![result isKindOfClass:NSString.class]) {
                    return ;
                }
                
                [mailViewController setSubject:(NSString *)result];
            }];
            [mailViewController setMessageBody:self.webView.URL.absoluteString isHTML:NO];
            mailViewController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:mailViewController animated:YES completion:nil];
        }];
    }
    
    // we need the cancel button only on the iPad if we're within a popover
    if (!PSIsIpad() || self.popoverController) {
        [pageActionSheet_ setCancelButtonWithTitle:PSPDFLocalize(@"Cancel") block:nil];
    }
    
#pragma clang diagnostic pop
    
    if(PSIsIpad()) {
        [pageActionSheet_ showFromBarButtonItem:actionBarButtonItem_ animated:YES];
    }else {
        [pageActionSheet_ showFromToolbar:self.navigationController.toolbar];
    }
}

- (void)doneButtonClicked:(id)sender {
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:YES];
    }else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithURL:(NSURL *)URL {
    if ((self = [self initWithNibName:nil bundle:nil])) {
        URL_ = URL;
        self.title = [URL pspdf_unicodeAbsoluteString];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        availableActions_ = PSPDFWebViewControllerAvailableActionsOpenInSafari | PSPDFWebViewControllerAvailableActionsMailLink | PSPDFWebViewControllerAvailableActionsCopyLink;
        PSPDFRegisterObject(self);
    }
    return self;
}

- (void)dealloc {
    // "the deallocation problem" - it's not safe to dealloc a controler from a thread different than the main thread
    // http://developer.apple.com/library/ios/#technotes/tn2109/_index.html#//apple_ref/doc/uid/DTS40010274-CH1-SUBSECTION11
    NSAssert([NSThread isMainThread], @"Must run on main thread, see http://developer.apple.com/library/ios/#technotes/tn2109/_index.html#//apple_ref/doc/uid/DTS40010274-CH1-SUBSECTION11");
    PSPDFDeregisterObject(self);
    [self cleanupWebView];
    [pageActionSheet_ destroy];
}

- (void)loadView {
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
    webView_.navigationDelegate = self;
    [webView_ loadRequest:[NSURLRequest requestWithURL:self.URL]];
    self.view = webView_;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // CREATE ... ALL THE BUTTONS!
    stopBarButtonItem_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop:)];
    refreshBarButtonItem_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload:)];
    actionBarButtonItem_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(action:)];
    forwardBarButtonItem_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(goForward:)];
    
    UIImage *backImage = [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypeBackArrow];    
    
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_5_0) {
        UIImage *smallBackImage = [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypeBackArrowSmall];        
        backBarButtonItem_ = [[UIBarButtonItem alloc] initWithImage:backImage landscapeImagePhone:smallBackImage style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    }else {
        backBarButtonItem_ = [[UIBarButtonItem alloc] initWithImage:backImage style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    }    
}

- (BOOL)isModal {
    BOOL isModal = [self.navigationController.viewControllers count] && [self.navigationController.viewControllers objectAtIndex:0] == self;
    return isModal;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateToolbarItems];

    if (!PSIsIpad()) {
        // animations
        toolbarWasHidden_ = self.navigationController.isToolbarHidden;
        [self.navigationController setToolbarHidden:NO animated:animated && ![self isModal]]; // should not be animated when used modally
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (!PSIsIpad()) {
        [self.navigationController setToolbarHidden:toolbarWasHidden_ animated:animated && ![self isModal]];
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self updateToolbarItems];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - WKNavigationDelegate
/// 页面开始发起请求
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self updateToolbarItems];
}

/// 5 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    [webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (![result isKindOfClass:NSString.class]) {
            return ;
        }
        
        self.navigationItem.title = (NSString *)result;
        [self updateToolbarItems];
    }];
}

/// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
   [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateToolbarItems];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    self.pageActionSheet = nil;
}

@end
