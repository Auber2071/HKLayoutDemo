//
//  PSPDFWebViewController.h
//  PSPDFKitExample
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PSPDFViewController.h"
#import "PSPDFBaseViewController.h"
#import <WebKit/WebKit.h>

enum {
    PSPDFWebViewControllerAvailableActionsNone             = 0,
    PSPDFWebViewControllerAvailableActionsOpenInSafari     = 1 << 0,
    PSPDFWebViewControllerAvailableActionsMailLink         = 1 << 1,
    PSPDFWebViewControllerAvailableActionsCopyLink         = 1 << 2
};
typedef NSUInteger PSPDFWebViewControllerAvailableActions;

@interface PSPDFWebViewController : PSPDFBaseViewController <WKNavigationDelegate>

/// Use this to get a UINavigationController with a Done-Button.
+ (UINavigationController *)modalWebViewWithURL:(NSURL *)URL;

/// Creates a new PSPDFWebViewController with the specified URL.
- (id)initWithURL:(NSURL *)URL;

@property (nonatomic, assign) PSPDFWebViewControllerAvailableActions availableActions;

/// Internal webview used.
@property(nonatomic, strong, readonly) WKWebView *webView;

/// Access popover controller, if attached.
@property(nonatomic, strong) UIPopoverController *popoverController;

@end