//
//  PSPDFYouTubeAnnotationView.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFYouTubeAnnotationView.h"
#import "PSPDFVideoAnnotationView.h"
#import "PSPDFKitGlobal.h"
#import "PSPDFAnnotation.h"
#import <objc/runtime.h>

@interface PSPDFYouTubeAnnotationView() {
    BOOL isShowing_;
    BOOL wasPlaying_;
}
@property(nonatomic, strong) void (^setupWebView)(void);
@end

@implementation PSPDFYouTubeAnnotationView

@synthesize youTubeURL = youTubeURL_;
@synthesize setupWebView = setupWebView_;
@synthesize webView = webView_;
@synthesize error = error_;
@synthesize autostartEnabled = autostartEnabled_;
@synthesize annotation = annotation_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        PSPDFRegisterObject(self);
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
    webView_ .navigationDelegate = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)setupYouTubeAnnotation {
    // cleanup
    [webView_ removeFromSuperview];
    webView_.navigationDelegate = nil;
    webView_ = nil;
    
    // setup new view
    youTubeURL_ = annotation_.URL;
    
    if ([annotation_.options objectForKey:@"autostart"]) {
        self.autostartEnabled = [[annotation_.options objectForKey:@"autostart"] boolValue];
    }
    
    // fixin' invalid YouTube formats
    if([[youTubeURL_ absoluteString] rangeOfString:@"/v/"].length > 0) {
        youTubeURL_ = [NSURL URLWithString:[[youTubeURL_ absoluteString] stringByReplacingOccurrencesOfString:@"/v/" withString:@"/watch?v="]];
    }        
    if([[youTubeURL_ absoluteString] rangeOfString:@"/embed/"].length > 0) {
        youTubeURL_ = [NSURL URLWithString:[[youTubeURL_ absoluteString] stringByReplacingOccurrencesOfString:@"/embed/" withString:@"/watch?v="]];
    }
    
    __ps_weak PSPDFYouTubeAnnotationView *weakSelf = self;
    setupWebView_ = ^{
        PSPDFYouTubeAnnotationView *strongSelf = weakSelf;
        if (!strongSelf.webView) {
            
#if defined(__i386__) || defined(__x86_64__)
            NSLog(@"------------------------------------------------------------------------------");
            NSLog(@"Note: There is no YouTube plugin in the iPhone Simulator. View will be blank. Please test this on the device.");
            NSLog(@"------------------------------------------------------------------------------");
#endif
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            // allow inline playback, even on iPhone
            config.allowsInlineMediaPlayback = YES;
            WKWebView *webView = [[WKWebView alloc] initWithFrame:strongSelf.bounds configuration:config];
            webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [strongSelf insertSubview:webView atIndex:0];
            strongSelf.webView = webView;
            
            // load plugin
            NSString *embedHTML = @"<html><head><style type=\"text/css\"> \
            body {background-color:transparent;color:white;}</style> \
            </head><body style=\"margin:0\"> \
            <embed id=\"yt\" src=\"%@\" type=\"application/x-shockwave-flash\" \
            width=\"%0.0f\" height=\"%0.0f\"></embed></body></html>";  
            NSString *html = [NSString stringWithFormat:embedHTML, [strongSelf.youTubeURL absoluteString], strongSelf.frame.size.width, strongSelf.frame.size.height]; 
            [webView loadHTMLString:html baseURL:nil];  
        }
    };
    
    setupWebView_();
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFAnnotationView

- (void)setAnnotation:(PSPDFAnnotation *)annotation {
    if (annotation != annotation_) {
        annotation_ = annotation;
        [self setupYouTubeAnnotation];
    }
}

// get the class called MPAVController to play/pause the YouTube video.
// https://github.com/steipete/iOS-Runtime-Headers/blob/master/Frameworks/MediaPlayer.framework/MPAVController.h
- (UIViewController *)movieController {
    UIViewController *movieController = nil;
#ifndef _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_
    @try {
        UIView *movieView = PSPDFGetViewInsideView(self.webView, [NSString stringWithFormat:@"MP%@oView", @"Vide"]);
        SEL mpavControllerSel = NSSelectorFromString([NSString stringWithFormat:@"mp%@roller", @"avCont"]);
        if ([movieView respondsToSelector:mpavControllerSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            movieController = (UIViewController *)[movieView performSelector:mpavControllerSel];
#pragma clang diagnostic pop
        }
    }
    @catch (NSException *exception) {
        PSPDFLogWarning(@"Failed to get movieController: %@", exception);
    }
#endif
    return movieController;
}

- (void)willShowPage:(NSUInteger)page {
    [self didShowPage:page];
}

- (BOOL)startPlayingYouTube {
    if (isShowing_) {
        @try {
            UIView *youTubePluginView = PSPDFGetViewInsideView(self.webView, [NSString stringWithFormat:@"YouTub%@View", @"ePlugIn"]);
            UIButton *button = (UIButton *)PSPDFGetViewInsideView(youTubePluginView, NSStringFromClass([UIButton class]));
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            return button != nil;
        }
        @catch (NSException *exception) {
            PSPDFLogWarning(@"Failed to invoke autostart on YouTube view: %@", exception);
            return NO;
        }
    }
}

/// page is displayed
- (void)didShowPage:(NSUInteger)page {
    if (!isShowing_) {
        isShowing_ = YES;
        
        // invoke the view generation as soon as the view will be added to the screen
        if (!self.webView && setupWebView_) {
            setupWebView_();
        }
        
#ifndef _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_
        if (self.isAutostartEnabled) {
            
            // autostart needs to be delayed as we wait for WKWebView to load. (very hacky, but only way as mp4 links are not exposed via YouTube)
            double delayInSeconds = PSPDFIsCrappyDevice() ? 0.9f : 0.5f;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^{
                if(![self startPlayingYouTube]) {
                    // if this fails, try once more
                    dispatch_after(popTime, dispatch_get_main_queue(), ^{
                        [self startPlayingYouTube];
                    });
                }
            });
        }
        
        if (wasPlaying_) {
            @try {
                UIViewController *movieController = [self movieController];
                if([movieController respondsToSelector:@selector(play)]) {
                    [movieController performSelector:@selector(play)];
                }
            }
            @catch (NSException *exception) {
                PSPDFLogWarning(@"Failed to play YouTube view: %@", exception);
            }
        }
#endif
    }
}

- (void)willHidePage:(NSUInteger)page {
    [self didHidePage:page];
}

/// page is hidden
- (void)didHidePage:(NSUInteger)page {
    if (isShowing_) {
        isShowing_ = NO;
                
#ifndef _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_
        @try {
            UIViewController *movieController = [self movieController];
            if([movieController respondsToSelector:NSSelectorFromString(@"isPlaying")]) {
                wasPlaying_ = [[movieController valueForKey:@"isPlaying"] boolValue];
            }
            if (wasPlaying_) {
                if([movieController respondsToSelector:@selector(pause)]) {
                    [movieController performSelector:@selector(pause)];
                }
            }
        }
        @catch (NSException *exception) {
            PSPDFLogWarning(@"Failed to pause YouTube view: %@", exception);
        }
#endif
    }
}

- (void)didChangePageFrame:(CGRect)frame {
    
    // all this custom hacking, again. but we need to make the YouTube view to resize.
#ifndef _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_
    CGRect targetRect = (CGRect){CGPointZero, self.frame.size};
    
    // we need to delay that... oh well
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIView *webBrowserView = PSPDFGetViewInsideView(self.webView, @"UIWebB");
            webBrowserView.frame = targetRect;
            UIView *youTubeView = PSPDFGetViewInsideView(self.webView, @"YouTubeP");
            youTubeView.frame = targetRect;
        }
        @catch (NSException *exception) {
            PSPDFLogWarning(@"Whoops, subview hacking failed. Won't resize view then. %@", exception);
        }
    });
#endif
}

@end
