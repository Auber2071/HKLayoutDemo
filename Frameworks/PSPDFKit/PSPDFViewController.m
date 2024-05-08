//
//  PSPDFViewController.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "PSPDFTransparentToolbar.h"
#import "PSPDFThumbnailGridViewCell.h"
#import "PSPDFPageViewController.h"
#import "PSPDFPagedScrollView.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFViewControllerDelegate.h"
#import "PSPDFGridView.h"
#import "PSPDFWebViewController.h"
#import "PSPDFIconGenerator.h"
#import "PSPDFAnnotationCache.h"
#import "PSPDFBarButtonItem.h"
#import "PSPDFOutlineBarButtonItem.h"
#import "PSPDFSearchBarButtonItem.h"
#import "PSPDFViewModeBarButtonItem.h"
#import "PSPDFPrintBarButtonItem.h"
#import "PSPDFOpenInBarButtonItem.h"
#import "PSPDFEmailBarButtonItem.h"
#import "PSPDFMoreBarButtonItem.h"
#import "PSPDFCloseBarButtonItem.h"
#import "UIImage+PSPDFKitAdditions.h"
#import "NSURL+PSPDFUnicodeURL.h"
#import <QuartzCore/QuartzCore.h>

#if !__has_feature(objc_arc)
#error "PSPDFKit needs to be compiled with ARC enabled."
#endif

#define kPSPDFViewControllerFrameChanged @"kPSPDFViewControllerFrameChanged"
NSString *kPSPDFFixNavigationBarFrame = @"kPSPDFFixNavigationBarFrame";

@interface PSPDFViewController() <UIActionSheetDelegate, PSPDFGridViewActionDelegate, PSPDFGridViewDataSource>
{
    __ps_weak UINavigationController *navigationController_;
    UIBarStyle previousBarStyle_;
    CGFloat previousBarAlpha_;
    UIColor *previousBarTint_;
    
    CGFloat lastContentOffset_;
    NSInteger targetPageAfterRotate_;
    
    unsigned int previousBarHidden_:1;
    unsigned int previousBarStyleTranslucent_:1;
    unsigned int isShowingOpenInMenu_:1;
    unsigned int isReloading_:1;
    unsigned int documentRectCacheLoaded_:1;
    unsigned int rotationAnimationActive_:1;
    struct {
        unsigned int delegateShouldScrollToPage:1;
        unsigned int delegateWillDisplayDocument:1;
        unsigned int delegateDidDisplayDocument:1;
        unsigned int delegateDidShowPageView:1;
        unsigned int delegateDidRenderPageView:1;
        unsigned int delegateDidChangeViewMode:1;
        unsigned int delegateDidTapOnPageView:1;
        unsigned int delegateDidTapOnAnnotation:1;
        unsigned int delegateShouldDisplayAnnotation:1;
        unsigned int delegateViewForAnnotation:1;        
        unsigned int delegateAnnotationViewForAnnotation:1;
        unsigned int delegateWillShowAnnotationView:1;
        unsigned int delegateDidShowAnnotationView:1;
        unsigned int delegateDidLoadPageView:1;
        unsigned int delegateWillUnloadPageView:1;
        unsigned int delegateDidEndPageScrollingAnimation:1;
        unsigned int delegateDidEndZoomingAtScale:1;
        unsigned int delegateWillShowControllerAnimated:1;
        unsigned int delegateDidShowControllerAnimated:1;
    } delegateFlags_;
}
@property(nonatomic, assign) CGSize lastOrientationSize;
@property(nonatomic, strong) PSPDFViewState *restoreViewStatePending;
@property(nonatomic, assign) NSUInteger lastPage;
@property(nonatomic, assign) unsigned int didReloadFirstPageWorkaround;

@property(nonatomic, strong) PSPDFGridView *gridView;
@property(nonatomic, strong) PSPDFHUDView *hudView;
@property(nonatomic, assign, readonly, getter=isLandscape) BOOL landscape;
@property(nonatomic, assign, getter=isViewVisible) BOOL viewVisible;
@property(nonatomic, assign, getter=isNavigationBarHidden) BOOL navigationBarHidden;
@property(nonatomic, assign, getter=isRotationActive) BOOL rotationActive;
@property(nonatomic, assign) NSUInteger page;
@property(nonatomic, strong) UIToolbar *leftToolbar;
@property(nonatomic, strong) UIToolbar *rightToolbar;
@property(nonatomic, strong) PSPDFScrobbleBar *scrobbleBar;
@property(nonatomic, strong) UIScrollView *pagingScrollView;
@property(nonatomic, strong) NSMutableSet *recycledPages;
@property(nonatomic, strong) NSMutableSet *visiblePages;
@property(nonatomic, assign) UIStatusBarStyle savedStatusBarStyle;
@property(nonatomic, assign) BOOL savedStatusBarVisibility;
@property(nonatomic, strong) PSPDFPageViewController *pageViewController;
@property(nonatomic, strong) PSPDFAnnotationCache *annotationCache;

/// snap pages into screen size. If disabled, you get one big scrollview (but zoom is resetted). Defaults to YES.
/// TODO: this doesn't work as supposed. Still work in progress.
@property(nonatomic, assign, getter=isPagingEnabled) BOOL pagingEnabled;

@end

// Simple subclass to relay frame change events.
@interface PSPDFViewControllerView : UIView
@end

@implementation PSPDFViewController

@synthesize delegate = delegate_;
@synthesize document = document_;
@synthesize realPage = realPage_;
@synthesize gridView = gridView_;
@synthesize navigationBarHidden = navigationBarHidden_;
@synthesize viewMode = viewMode_;
@synthesize pageMode = pageMode_;
@synthesize doublePageModeOnFirstPage = doublePageModeOnFirstPage_;
@synthesize landscape = landscape_;
@synthesize rotationActive = rotationActive_;
@synthesize leftToolbar = leftToolbar_;
@synthesize rightToolbar = rightToolbar_;
@synthesize popoverController = popoverController_;
@synthesize backgroundColor = backgroundColor_;
@synthesize tintColor = tintColor_;
@synthesize scrobbleBar = scrobbleBar_;
@synthesize scrobbleBarEnabled = scrobbleBarEnabled_;
@synthesize positionViewEnabled = positionViewEnabled_;
@synthesize toolbarEnabled = toolbarEnabled_;
@synthesize scrollOnTapPageEndEnabled = scrollOnTapPageEndEnabled_;
@synthesize iPhoneThumbnailSizeReductionFactor = iPhoneThumbnailSizeReductionFactor_;
@synthesize pagingScrollView = pagingScrollView_;
@synthesize recycledPages = recycledPages_;
@synthesize visiblePages = visiblePages_;
@synthesize hudView = hudView_;
@synthesize positionView = positionView_;
@synthesize maximumZoomScale = maximumZoomScale_;
@synthesize pagePadding = pagePadding_;
@synthesize zoomingSmallDocumentsEnabled = zoomingSmallDocumentsEnabled_;
@synthesize shadowEnabled = shadowEnabled_;
@synthesize pageScrolling = pageScrolling_;
@synthesize fitWidth = fitWidth_;
@synthesize fixedVerticalPositionForFitWidthMode = _fixedVerticalPositionForFitWidthMode;
@synthesize linkAction = linkAction_;
@synthesize closeButtonItem = closeButtonItem_;
@synthesize outlineButtonItem = outlineButtonItem_;
@synthesize searchButtonItem = searchButtonItem_;
@synthesize viewModeButtonItem = viewModeButtonItem_;
@synthesize printButtonItem = printButtonItem_;
@synthesize openInButtonItem = openInButtonItem_;
@synthesize emailButtonItem = emailButtonItem_;
@synthesize leftBarButtonItems = leftBarButtonItems_;
@synthesize rightBarButtonItems = rightBarButtonItems_;
@synthesize additionalRightBarButtonItems = additionalRightBarButtonItems_;
@synthesize thumbnailSize = thumbnailSize_;
@synthesize viewVisible = viewVisible_;
@synthesize pagingEnabled = pagingEnabled_;
@synthesize statusBarStyleSetting = statusBarStyleSetting_;
@synthesize savedStatusBarStyle = savedStatusBarStyle_;
@synthesize savedStatusBarVisibility = savedStatusBarVisibility_;
@synthesize scrollingEnabled = scrollingEnabled_;
@synthesize overrideClassNames = overrideClassNames_;
@synthesize pageCurlEnabled = pageCurlEnabled_;
@synthesize pageViewController = pageViewController_;
@synthesize annotationAnimationDuration = annotationAnimationDuration_;
@synthesize clipToPageBoundaries = clipToPageBoundaries_;
@synthesize annotationCache = annotationCache_;
@synthesize useParentNavigationBar = useParentNavigationBar_;
@synthesize pageCurlDirectionLeftToRight = pageCurlDirectionLeftToRight_;
@synthesize minLeftToolbarWidth = _minLeftToolbarWidth;
@synthesize minRightToolbarWidth = _minRightToolbarWidth;
@synthesize loadThumbnailsOnMainThread = _loadThumbnailsOnMainThread;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Custom Class Helper

// Looks up an entry in overrideClassNames for custom Class subclasses
- (Class)classForClass:(Class)originalClass {
    // TODO: assert when baseclass is not the correct class.
    Class overrideClassObject = [overrideClassNames_ objectForKey:originalClass];
    if (!overrideClassObject) {
        // add legacy support to work with strings of class names
        NSString *overriddenClassName = [overrideClassNames_ objectForKey:NSStringFromClass(originalClass)];
        if (overriddenClassName) {
            if (!(overrideClassObject = NSClassFromString(overriddenClassName))) {
                PSPDFLogError(@"Error! Couldn't find class %@ in runtime. Using default %@ instead.", overriddenClassName, NSStringFromClass(originalClass));
            }
        }
    }
    return overrideClassObject ?: originalClass;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Controls

// helper to detect if we're embedded or not.
- (BOOL)isEmbedded {
    BOOL hasParentViewController = NO;
    PSPDF_IF_IOS5_OR_GREATER(hasParentViewController = self.parentViewController != nil;)
    if (!self.view.window && !hasParentViewController) {
        return NO;
    }
    CGRect viewRect = self.view.bounds;
    viewRect = [self.view convertRect:viewRect toView:nil]; // Convert to the window's coordinate space.
    CGRect appRect = [[UIScreen mainScreen] applicationFrame];
    // use a heuristic to compensate status bar effects (transparency, call notification, etc)
    BOOL isEmbedded = fabs(viewRect.size.width - appRect.size.width) > 44.f || fabs(viewRect.size.height - appRect.size.height) > 44.f;
    PSPDFLogVerbose(@"embedded: %d (%@:%@)", isEmbedded, NSStringFromCGRect(viewRect), NSStringFromCGRect(appRect));
    return isEmbedded;
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated {
    if (![self isEmbedded] && !(self.statusBarStyleSetting & PSPDFStatusBarIgnore)) {
//        [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle animated:animated];
    }
}

- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    if (![self isEmbedded] && !(self.statusBarStyleSetting & PSPDFStatusBarIgnore)) {
        [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animation];
    }
}

- (void)closeModalView {
    [[self masterViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)presentModalViewController:(UIViewController *)controller withCloseButton:(BOOL)closeButton animated:(BOOL)animated {
    UINavigationController *navController = (UINavigationController *)controller;
    if (![controller isKindOfClass:[UINavigationController class]]) {
        navController = [[UINavigationController alloc] initWithRootViewController:controller];
    }else {
        controller = navController.topViewController;
    }
    
    // informal protocol
    if (closeButton) {
        if ([controller respondsToSelector:@selector(setShowsCancelButton:)]) {
            [(PSPDFSearchViewController *)controller setShowsCancelButton:YES];
            navController.navigationBarHidden = YES;
        }else {
            controller.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:PSPDFLocalize(@"Close") style:UIBarButtonItemStylePlain target:self action:@selector(closeModalView)];
        }
    }
    
    controller.navigationItem.title = self.document.title;
    [self delegateWillShowController:controller embeddedInController:navController animated:animated];
    
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_5_0) {
        [[self masterViewController] presentViewController:navController animated:animated completion:^{
            [self delegateDidShowController:controller embeddedInController:navController animated:animated];
        }];
    }else {
        [[self masterViewController] presentViewController:controller animated:YES completion:nil];
    }
    
    // on the iPhone, we wanna move to the default statusbar
    if (!PSIsIpad()) {
        UIStatusBarStyle statusBarStyle = UIStatusBarStyleDefault;
        
        // if the barSyle is set dark, don't set a white status bar.
        if (navController.navigationBar && navController.navigationBar.barStyle != UIBarStyleDefault) {
            statusBarStyle = UIStatusBarStyleLightContent;
        }
        
        // next, look if we implement PSPDFStatusBarStyleHint - overrides navigationBar.barStyle.
        if ([controller conformsToProtocol:@protocol(PSPDFStatusBarStyleHint)]) {
            statusBarStyle = [(id<PSPDFStatusBarStyleHint>)controller preferredStatusBarStyle];
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        statusBarStyle = UIStatusBarStyleLightContent;
#endif
//        if ([[UIDevice currentDevice].systemVersion floatValue]>= 7.0) {
//            statusBarStyle = UIStatusBarStyleLightContent;
//        }
        [self setStatusBarStyle:statusBarStyle animated:animated];
    }
}

- (void)showControls {
    //TODO:
//    if (self.isNavigationBarHidden) {
        [self setHUDVisible:YES animated:YES];
//}
}

- (void)hideControls {
    if (!self.isNavigationBarHidden && ![PSPDFBarButtonItem isPopoverVisible]) {
        [self setHUDVisible:NO animated:YES];
    }
}

- (void)tappedPageLeftSide:(PSPDFScrollView *)scrollView
{
    
}

- (void)tappedPageRightSide:(PSPDFScrollView *)scrollView
{
    
}

- (void)toggleControls {
    BOOL newHUDVisibilityStatus = ![self isHUDVisible];
    // 0xced: Is the (self.viewMode == PSPDFViewModeThumbnails) condition still necessary?
    if (self.viewMode == PSPDFViewModeThumbnails || [PSPDFBarButtonItem isPopoverVisible]) {
        newHUDVisibilityStatus = YES;
    }
    [self setHUDVisible:newHUDVisibilityStatus animated:YES];
}

- (UIStatusBarStyle)statusBarStyle {
    UIStatusBarStyle statusBarStyle;
    switch (self.statusBarStyleSetting & ~PSPDFStatusBarIgnore) {
        case PSPDFStatusBarSmartBlack:
            statusBarStyle = PSIsIpad() ? UIStatusBarStyleLightContent : UIStatusBarStyleLightContent;
            break;
        case PSPDFStatusBarBlackOpaque:
            statusBarStyle = UIStatusBarStyleLightContent;
            break;
        case PSPDFStatusBarDefaultWhite:
            statusBarStyle = UIStatusBarStyleDefault;
            break;
        case PSPDFStatusBarDisable:
        case PSPDFStatusBarInherit:
        default:
            statusBarStyle = [UIApplication sharedApplication].statusBarStyle;
            break;
    }
    
    return statusBarStyle;
}

- (BOOL)isHUDVisible {
    BOOL isHUDVisible = self.hudView.alpha > 0.f;
    return isHUDVisible;
}

// send all HUD subviews hidden/visible state
- (void)setHUDSubviewsHidden:(BOOL)hidden {
    for (UIView *hudSubView in self.hudView.subviews) {
        hudSubView.hidden = hidden;
    }
}

- (void)setHUDVisible:(BOOL)HUDVisible {
    [self setHUDVisible:HUDVisible animated:NO];
}

- (BOOL)prefersStatusBarHidden
{
    if (![self isHUDVisible]) {
        [UIApplication sharedApplication].statusBarHidden = YES;
        return YES;
    }
    else {
        [UIApplication sharedApplication].statusBarHidden = NO;
        return NO;
    }
}

- (void)setHUDVisible:(BOOL)show animated:(BOOL)animated {
    [self willChangeValueForKey:@"HUDVisible"];
    BOOL isShown = [self isHUDVisible];
    //TODO:显示状态栏  HUDVIEW 调整 动画改为滑动出现/消失
//    if ([[UIDevice currentDevice].systemVersion floatValue] >= 7.0) {
//        [UIView beginAnimations:nil context:nil];
//        [UIView setAnimationDuration:0.2];
//        [self prefersStatusBarHidden];
//        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
//        [UIView commitAnimations];
//    }
//    else
//    {
        //[[UIApplication sharedApplication] setStatusBarHidden:!show withAnimation:UIStatusBarAnimationSlide];
//    }
    UIStatusBarStyle statusBarStyle = [self statusBarStyle];
    if (show == isShown) {        
        if (self.isToolbarEnabled && statusBarStyle != UIStatusBarStyleDefault) {
            [self.internalNavController setNavigationBarHidden:!isShown animated:YES];
        }
        [self didChangeValueForKey:@"HUDVisible"];
        return;
    }
    
    BOOL allowChange = YES;
    if (show) {
        if ([delegate_ respondsToSelector:@selector(pdfViewController:shouldShowHUD:)]) {
            allowChange = [delegate_ pdfViewController:self shouldShowHUD:animated];
        }
    }else {
        if ([delegate_ respondsToSelector:@selector(pdfViewController:shouldHideHUD:)]) {
            allowChange = [delegate_ pdfViewController:self shouldHideHUD:animated];
        }
    }
    if (!allowChange) {
        [self didChangeValueForKey:@"HUDVisible"];
        return;
    }
    
//    if (!PSIsIpad()) {
//        if (self.wantsFullScreenLayout && !(self.statusBarStyleSetting & PSPDFStatusBarDisable)) {
//            [self setStatusBarHidden:!show withAnimation:UIStatusBarAnimationFade];
//        }
//    }
    self.hudView.alpha = 1.0;
    [self setHUDSubviewsHidden:NO];
    // we need to perform this AFTER changing the statusbar, or else it gets overlayed (iOS BUG)
    dispatch_async(dispatch_get_main_queue(), ^{
        // only switch if we start showing
        if (!isShown && self.isToolbarEnabled) {
            self.internalNavController.navigationBarHidden = YES;
            self.internalNavController.navigationBarHidden = NO;
        }
        
        if (show) {
            if([self.delegate respondsToSelector:@selector(pdfViewController:willShowHUD:)]) {
                [self.delegate pdfViewController:self willShowHUD:animated];
            }
        }else {
            if([self.delegate respondsToSelector:@selector(pdfViewController:willHideHUD:)]) {
                [self.delegate pdfViewController:self willHideHUD:animated];
            }
        }
        
//        PSPDFBasicBlock animationBlock = ^{
//            self.hudView.alpha = show ? 1.f : 0.f;
//            if (self.isToolbarEnabled && self.document.isValid) {
//                BOOL navBarAlwaysVisible = statusBarStyle == UIStatusBarStyleDefault;
//                self.internalNavController.navigationBar.alpha = (show || navBarAlwaysVisible) ? 1.0f : 0.0f;
//                self.internalNavController.navigationBar.translucent = statusBarStyle != UIStatusBarStyleDefault;
//                self.navigationBarHidden = !show && !navBarAlwaysVisible;
//            }
//        };
//        
//        if (animated) {
//            CGFloat animationDuration = PSIsIpad() ? UINavigationControllerHideShowBarDuration : 0.4f;
//            [UIView animateWithDuration:animationDuration delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
//                [self setHUDSubviewsHidden:NO];
//                animationBlock();
//            } completion:^(BOOL finished) {
//                if (finished) {
//                    [self setHUDSubviewsHidden:!show];
//                    
//                    if (show) {
//                        if([delegate_ respondsToSelector:@selector(pdfViewController:didShowHUD:)]) {
//                            [delegate_ pdfViewController:self didShowHUD:animated];
//                        }
//                    }else {
//                        if([delegate_ respondsToSelector:@selector(pdfViewController:didHideHUD:)]) {
//                            [delegate_ pdfViewController:self didHideHUD:animated];
//                        }
//                    }
//                }
//            }];
//        }else {
//            animationBlock();
//            [self setHUDSubviewsHidden:!show];
//        }
    });
    [self didChangeValueForKey:@"HUDVisible"];
}

- (void)setViewMode:(PSPDFViewMode)viewMode animated:(BOOL)animated {
    if (viewMode != viewMode_) {
        if (animated) {
            [self willChangeValueForKey:@"viewModeAnimated"];
        }
        [self willChangeValueForKey:@"viewMode"];
        viewMode_ = viewMode;
        
        // sync thumbnail control
        if (self.viewModeItem.viewModeSegment.selectedSegmentIndex != viewMode) {
            self.viewModeItem.viewModeSegment.selectedSegmentIndex = viewMode;
        }
        
        // hide any open popovers
        self.popoverController = nil;
        
        // preparations (insert grid in view stack
        if(viewMode == PSPDFViewModeThumbnails) {
            // if cell is hidden, scroll to top
            //TODO: 修正了预览图 眼睛位置的问题
            BOOL isCellVisible = [self.gridView isCellVisibleAtIndex:self.realPage partly:NO];
            if (!isCellVisible) {
                [self.gridView scrollToObjectAtIndex:self.realPage atScrollPosition:PSPDFGridViewScrollPositionTop animated:NO];
                [self.gridView layoutSubviews]; // ensure cells are laid out
            };
            self.gridView.hidden = NO;
            self.gridView.alpha = 0.0f;
            self.pagingScrollView.alpha = 1.0f;
        }else {
            [self.gridView setContentOffset:self.gridView.contentOffset animated:NO]; // stop scrolling, fixes a disappearing grid bug.
            self.gridView.alpha = 1.f;
            self.pagingScrollView.hidden = NO;
            self.pagingScrollView.alpha = 0.f;
        }
        
        [self.view insertSubview:self.pagingScrollView belowSubview:self.hudView];
        
        // prepare views
        NSMutableArray *pageViews = [NSMutableArray array];
        NSMutableArray *pageImageViews = [NSMutableArray new];
        NSMutableArray *targetCells = [NSMutableArray array];
        NSMutableArray *shadowPageSetting = [NSMutableArray array];
        NSMutableArray *shadowScrollSetting = [NSMutableArray array];
        NSMutableArray *fullRects = [NSMutableArray array];
        NSMutableArray *smallRects = [NSMutableArray array];
        for (NSNumber *pageNumber in [self visiblePageNumbers]) {
            // can return nil when we are in dual page mode and show first/last page
            PSPDFPageView *pageView = [self pageViewForPage:[pageNumber integerValue]];
            if (pageView) {
                [pageViews addObject:pageView];
            }
            
            // stop if more pages are loaded than displayed
            if ([pageViews count] && ![self isDualPageMode]) {
                break;
            }
        }
        
        // load stuff/visible views
        if (animated) {
            for (PSPDFPageView *pageView in pageViews) {
                // targetCell might not be visible.
                CGRect targetCellRect;
                PSPDFGridViewCell *targetCell = [self.gridView cellForItemAtIndex:pageView.page];
                if (targetCell) {
                    targetCell.hidden = YES;
                    [targetCells addObject:targetCell];
                    targetCellRect = targetCell.frame;
                }else {
                    // TODO: use center!
                    targetCellRect = CGRectZero;
                }
                
                // try to load already visible image, else load from the cache
                CGImageRef imageRef = pageView.backgroundImageView.image.CGImage;
                UIImage *pageImage;
                if (imageRef) {
                    pageImage = [UIImage imageWithCGImage:imageRef scale:pageView.backgroundImageView.image.scale orientation:pageView.backgroundImageView.image.imageOrientation];
                }else {
                    pageImage = [[PSPDFCache sharedPSPDFCache] cachedImageForDocument:self.document page:pageView.page size:PSPDFSizeNative preload:NO];
                }
                UIImageView *pageImageView = [[UIImageView alloc] initWithImage:pageImage];
                pageImageView.backgroundColor = pageImage ? [UIColor clearColor] : [UIColor whiteColor];
                [self.view insertSubview:pageImageView aboveSubview:self.pagingScrollView];
                
                CGRect fullRect = [pageView convertRect:pageView.bounds toView:self.view];
                [fullRects addObject:[NSValue valueWithCGRect:fullRect]];
                CGRect relativeCellRect = [self.gridView convertRect:targetCellRect toView:self.view];
                [smallRects addObject:[NSValue valueWithCGRect:relativeCellRect]];
                
                pageImageView.frame = viewMode == PSPDFViewModeThumbnails ? fullRect : relativeCellRect;
                pageImageView.contentMode = UIViewContentModeScaleAspectFit;
                [pageImageViews addObject:pageImageView];
                
                // disable shadows until we're done with the animation
                [shadowPageSetting addObject:[NSNumber numberWithBool:pageView.isShadowEnabled]];
                [shadowScrollSetting addObject:[NSNumber numberWithBool:pageView.scrollView.isShadowEnabled]];
            }
            
            // disable shadow in an extra loop (to not change connected shadow while saving state)
            for (PSPDFPageView *pageView in pageViews) {
                pageView.shadowEnabled = NO;
                pageView.scrollView.shadowEnabled = NO;
            }
        }
        
        [UIView animateWithDuration:animated ? 0.25f : 0.f delay:0.f options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            for (NSUInteger index = 0; index < [pageViews count]; index++) {
                PSPDFPageView *pageView = [pageViews objectAtIndex:index];
                pageView.hidden = viewMode != PSPDFViewModeThumbnails;
                if (animated) {
                    //[self updatePositionViewPosition];
                    UIImageView *pageImage = [pageImageViews objectAtIndex:index];
                    CGRect relativeCellRect = [[(viewMode == PSPDFViewModeThumbnails ? smallRects : fullRects) objectAtIndex:index] CGRectValue];
                    pageImage.frame = relativeCellRect;
                }
            }
            
            if(viewMode == PSPDFViewModeThumbnails) { // grid                
                self.pagingScrollView.hidden = YES;
                self.gridView.alpha = 1.f;
            }else {
                self.pagingScrollView.alpha = 1.f;
                self.gridView.alpha = 0.f;
            }      
        } completion:^(BOOL finished) {
            BOOL isShowingThumbnails = viewMode == PSPDFViewModeThumbnails;
            if (finished) {
                self.pagingScrollView.hidden = isShowingThumbnails;
                self.gridView.hidden = !isShowingThumbnails;
            }
            
            // ensure that cells are visible again
            for (NSUInteger index = 0; index < [pageViews count]; index++) {
                PSPDFPageView *pageView = [pageViews objectAtIndex:index];
                pageView.hidden = isShowingThumbnails;
                if (animated) {
                    pageView.shadowEnabled = [[shadowPageSetting objectAtIndex:index] boolValue];
                    pageView.scrollView.shadowEnabled = [[shadowScrollSetting objectAtIndex:index] boolValue];
                    PSPDFGridViewCell *targetCell = index < [targetCells count] ? [targetCells objectAtIndex:index] : nil;
                    targetCell.hidden = NO;
                    // no matter of the animation finished or not, remove the images
                    [pageImageViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
                }
            }
        }];
        if (animated) {
            [self didChangeValueForKey:@"viewModeAnimated"];
        }
        [self didChangeValueForKey:@"viewMode"];
        [self delegateDidChangeViewMode:viewMode];
    }
}

- (void)setViewMode:(PSPDFViewMode)viewMode {
    [self setViewMode:viewMode animated:NO];
}

- (void)updateGridForOrientation {
    gridView_.itemSpacing = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) ? 28 : 15;
    
    // on iPhone, the navigation toolbar is either 44 (portrait) or 30 (landscape) pixels
    CGFloat transparentToolbarOffset = [self hudTransparencyOffset];
    NSUInteger spacing = 15;
    gridView_.minEdgeInsets = UIEdgeInsetsMake(spacing + transparentToolbarOffset, spacing, spacing, spacing);
}

- (PSPDFGridView *)gridView {
    if (!gridView_) {
        self.gridView = [[[self classForClass:[PSPDFGridView class]] alloc] initWithFrame:self.view.bounds];
        self.gridView.backgroundColor = [UIColor clearColor];
        self.gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.gridView.actionDelegate = self;
        self.gridView.style = PSPDFGridViewStyleSwap;
        self.gridView.centerGrid = YES;
        self.gridView.mainSuperView = self.view;
        [self updateGridForOrientation];
        self.gridView.dataSource = self;
        [self.view insertSubview:self.gridView belowSubview:self.hudView];
    }
    
    return gridView_;
}

- (BOOL)isDualPageModeForOrientation:(UIInterfaceOrientation)interfaceOrientation {
    BOOL isDualPageMode = self.pageMode == PSPDFPageModeDouble || (self.pageMode == PSPDFPageModeAutomatic && UIInterfaceOrientationIsLandscape(interfaceOrientation));
    if (isDualPageMode && self.pageMode == PSPDFPageModeAutomatic) {
        if (self.document.isValid) {
            PSPDFPageInfo *pageInfo = [self.document pageInfoForPage:0];
            if (pageInfo) {
                CGSize pageSize = pageInfo.pageRect.size;
                isDualPageMode = pageSize.height > pageSize.width && document_.pageCount > 1;
            }else {
                PSPDFLogWarning(@"Could not get pageInfo for %lu", (unsigned long)self.realPage);
            }
        }
    }
    return isDualPageMode;
}

// dynamically determine if we're landscape or not. (also checks if dual page mode makes any sense at all)
- (BOOL)isDualPageMode {
    return [self isDualPageModeForOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
}

/// YES if we are at the last page
- (BOOL)isLastPage {
    BOOL isLastPage = self.page >= self.document.pageCount-1;
    return isLastPage;
}

/// YES if we are at the first page
- (BOOL)isFirstPage {
    BOOL isFirstPage = self.page == 0;
    return isFirstPage;
}

- (NSUInteger)actualPage:(NSUInteger)aPage convert:(BOOL)convert {
    NSUInteger actualPage = aPage;
    if (convert) {
        if (self.doublePageModeOnFirstPage) {
            actualPage = floor(aPage/2.0);
        }else if(aPage) {
            actualPage = ceil(aPage/2.0);
        }
    }
    
    return actualPage;
}

// 0,1,2,3,4,5
- (NSUInteger)actualPage:(NSUInteger)aPage {
    return [self actualPage:aPage convert:[self isDualPageMode]];
}

- (NSUInteger)landscapePage:(NSUInteger)aPage convert:(BOOL)convert {
    NSUInteger landscapePage = aPage;
    if (convert) {
        if (self.doublePageModeOnFirstPage) {
            landscapePage = aPage*2;
        }else if(aPage) { // don't produce a -1
            landscapePage = aPage*2-1;
        }
    }
    return landscapePage;
}

// doublePageModeOnFirstPage: 0,0,1,1,2,2,3
// !doublePageModeOnFirstPage 0,1,1,2,2,3,3
- (NSUInteger)landscapePage:(NSUInteger)aPage {
    return [self landscapePage:aPage convert:[self isDualPageMode]];
}

// for showing the *human readable* page displayed
- (NSUInteger)humanReadablePageForPage:(NSUInteger)aPage {
    NSUInteger humanPage = aPage + 1; // increase on 1 (pages start at 1 for us)
    
    if (humanPage > [self.document pageCount]) {
        humanPage = [self.document pageCount];
    }
    
    return humanPage;
}

// returns if the page would be or is a right page in dual page mode
- (BOOL)isRightPageInDoublePageMode:(NSUInteger)page {
    BOOL isRightPage = ((page%2 == 1 && self.isDoublePageModeOnFirstPage) || (page%2 == 0 && !self.isDoublePageModeOnFirstPage));
    return isRightPage;
}

- (void)frameChangedNotification:(NSNotification *)notification {
    UIView *changedView = (UIView *)notification.object;
    
    // as we could receive notifications from any controller, compare view.
    // might be called in viewWillDisappear as we restore the original navBar; thus we check for isViewVisible.
    if ([self isViewLoaded] && self.isViewVisible && self.view == changedView && self.view.window && !rotationActive_) {
        
        // disable animation while reloading (else we get ugly animations)
        [UIView animateWithDuration:0 delay:0 options:UIViewAnimationOptionOverrideInheritedDuration animations:^{
            [self reloadData];
        } completion:nil];
    }
}

- (void)updateSettingsForRotation:(CGSize)toInterfaceOrientationSize {
    // improves readability on iPhone
    if(!PSIsIpad()) {
        self.fitWidth = toInterfaceOrientationSize.width > toInterfaceOrientationSize.height;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Delegate

- (void)setDelegate:(id<PSPDFViewControllerDelegate>)delegate {
    if (delegate != delegate_) {
        delegate_ = delegate;
        delegateFlags_.delegateShouldScrollToPage = [delegate respondsToSelector:@selector(pdfViewController:shouldScrollToPage:)];
        delegateFlags_.delegateWillDisplayDocument = [delegate respondsToSelector:@selector(pdfViewController:willDisplayDocument:)];
        delegateFlags_.delegateDidDisplayDocument = [delegate respondsToSelector:@selector(pdfViewController:didDisplayDocument:)];
        delegateFlags_.delegateDidShowPageView = [delegate respondsToSelector:@selector(pdfViewController:didShowPageView:)];
        delegateFlags_.delegateDidRenderPageView = [delegate respondsToSelector:@selector(pdfViewController:didRenderPageView:)];
        delegateFlags_.delegateDidChangeViewMode = [delegate respondsToSelector:@selector(pdfViewController:didChangeViewMode:)];
        delegateFlags_.delegateDidTapOnPageView = [delegate respondsToSelector:@selector(pdfViewController:didTapOnPageView:info:coordinates:)];
        delegateFlags_.delegateDidTapOnAnnotation = [delegate respondsToSelector:@selector(pdfViewController:didTapOnAnnotation:page:info:coordinates:)];
        delegateFlags_.delegateShouldDisplayAnnotation = [delegate respondsToSelector:@selector(pdfViewController:shouldDisplayAnnotation:onPageView:)];
        delegateFlags_.delegateViewForAnnotation = [delegate respondsToSelector:@selector(pdfViewController:viewForAnnotation:onPageView:)];
        delegateFlags_.delegateAnnotationViewForAnnotation = [delegate respondsToSelector:@selector(pdfViewController:annotationView:forAnnotation:onPageView:)];
        delegateFlags_.delegateWillShowAnnotationView = [delegate respondsToSelector:@selector(pdfViewController:willShowAnnotationView:onPageView:)];
        delegateFlags_.delegateDidShowAnnotationView = [delegate respondsToSelector:@selector(pdfViewController:didShowAnnotationView:onPageView:)];
        delegateFlags_.delegateDidLoadPageView = [delegate respondsToSelector:@selector(pdfViewController:didLoadPageView:)];
        delegateFlags_.delegateWillUnloadPageView = [delegate respondsToSelector:@selector(pdfViewController:willUnloadPageView:)];
        delegateFlags_.delegateDidEndPageScrollingAnimation = [delegate respondsToSelector:@selector(pdfViewController:didEndPageScrollingAnimation:)];
        delegateFlags_.delegateDidEndZoomingAtScale = [delegate respondsToSelector:@selector(pdfViewController:didEndPageZooming:atScale:)];
        delegateFlags_.delegateWillShowControllerAnimated = [delegate respondsToSelector:@selector(pdfViewController:willShowController:embeddedInController:animated:)];
        delegateFlags_.delegateDidShowControllerAnimated = [delegate respondsToSelector:@selector(pdfViewController:didShowController:embeddedInController:animated:)];
    }
}

- (BOOL)delegateShouldScrollToPage:(NSUInteger)page {
    BOOL shouldScroll = YES;
    if(delegateFlags_.delegateShouldScrollToPage) {
        shouldScroll = [self.delegate pdfViewController:self shouldScrollToPage:page];
    }
    return shouldScroll;
}

- (void)delegateWillDisplayDocument {
    if (delegateFlags_.delegateWillDisplayDocument) {
        [self.delegate pdfViewController:self willDisplayDocument:self.document];
    }
}

- (void)delegateDidDisplayDocument {
    if(delegateFlags_.delegateDidDisplayDocument) {
        [self.delegate pdfViewController:self didDisplayDocument:self.document];
    }
}

// helper, only look for PSPDFPageView if we really need it!
- (void)delegateDidShowPage:(NSUInteger)realPage {
    if (delegateFlags_.delegateDidShowPageView) {
        PSPDFPageView *pageView = [self pageViewForPage:realPage];
        [self delegateDidShowPageView:pageView];
    }
}

- (void)delegateDidShowPageView:(PSPDFPageView *)pageView {
    if (_didReloadFirstPageWorkaround) return;

    if (delegateFlags_.delegateDidShowPageView) {
        [self.delegate pdfViewController:self didShowPageView:pageView];
    }
}

- (void)delegateDidRenderPageView:(PSPDFPageView *)pageView {
    if (delegateFlags_.delegateDidRenderPageView) {
        [self.delegate pdfViewController:self didRenderPageView:pageView];
    }
}

- (void)delegateDidChangeViewMode:(PSPDFViewMode)viewMode {
    if (delegateFlags_.delegateDidChangeViewMode) {
        [self.delegate pdfViewController:self didChangeViewMode:viewMode];
    }
}

- (BOOL)delegateDidTapOnPageView:(PSPDFPageView *)pageView info:(PSPDFPageInfo *)pageInfo coordinates:(PSPDFPageCoordinates *)pageCoordinates {
    BOOL touchProcessed = NO;
    if (delegateFlags_.delegateDidTapOnPageView) {
        touchProcessed = [self.delegate pdfViewController:self didTapOnPageView:pageView info:pageInfo coordinates:pageCoordinates];
    }
    
    return touchProcessed;
}

- (BOOL)delegateDidTapOnAnnotation:(PSPDFAnnotation *)annotation page:(NSUInteger)page info:(PSPDFPageInfo *)pageInfo coordinates:(PSPDFPageCoordinates *)pageCoordinates {
    BOOL processed = NO;
    if (delegateFlags_.delegateDidTapOnAnnotation) {
        processed = [self.delegate pdfViewController:self didTapOnAnnotation:annotation page:page info:pageInfo coordinates:pageCoordinates];
    }
    return processed;
}

- (BOOL)delegateShouldDisplayAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {
    BOOL shouldDisplayAnnotation = YES; // default
    if(delegateFlags_.delegateShouldDisplayAnnotation) {
        shouldDisplayAnnotation = [self.delegate pdfViewController:self shouldDisplayAnnotation:annotation onPageView:pageView];
    }
    return shouldDisplayAnnotation;
}

- (UIView <PSPDFAnnotationView> *)delegateViewForAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {
    UIView <PSPDFAnnotationView> *annotationView = nil;
    if(delegateFlags_.delegateViewForAnnotation) {
        annotationView = [self.delegate pdfViewController:self viewForAnnotation:annotation onPageView:pageView];
    }
    return annotationView;
}

- (UIView <PSPDFAnnotationView> *)delegateAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView forAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {
    if(delegateFlags_.delegateAnnotationViewForAnnotation) {
        annotationView = [self.delegate pdfViewController:self annotationView:annotationView forAnnotation:annotation onPageView:pageView];
    }
    return annotationView;
}

- (void)delegateWillShowAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView onPageView:(PSPDFPageView *)pageView {
    if(delegateFlags_.delegateWillShowAnnotationView) {
        [self.delegate pdfViewController:self willShowAnnotationView:annotationView onPageView:pageView];
    }
}

- (void)delegateDidShowAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView onPageView:(PSPDFPageView *)pageView {
    if(delegateFlags_.delegateDidShowAnnotationView) {
        [self.delegate pdfViewController:self didShowAnnotationView:annotationView onPageView:pageView];
    }
}

- (void)delegateDidLoadPageView:(PSPDFPageView *)pageView {
    if (_didReloadFirstPageWorkaround) return;

    if (delegateFlags_.delegateDidLoadPageView) {
        [self.delegate pdfViewController:self didLoadPageView:pageView];
    }
}

- (void)delegateWillUnloadPageView:(PSPDFPageView *)pageView {
    if (_didReloadFirstPageWorkaround) return;

    if (delegateFlags_.delegateWillUnloadPageView) {
        [self.delegate pdfViewController:self willUnloadPageView:pageView];
    }
}

- (void)delegateDidEndPageScrollingAnimation:(UIScrollView *)scrollView {
    // hook for view restoring
    if (self.restoreViewStatePending) {
        [self restoreDocumentViewState:self.restoreViewStatePending animated:YES];
    }
    
    if (delegateFlags_.delegateDidEndPageScrollingAnimation) {
        [self.delegate pdfViewController:self didEndPageScrollingAnimation:scrollView];
    }    
}

- (void)delegateDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
    if (delegateFlags_.delegateDidEndZoomingAtScale) {
        [self.delegate pdfViewController:self didEndPageZooming:scrollView atScale:scale];
    }        
}

- (void)delegateWillShowController:(id)viewController embeddedInController:(id)controller animated:(BOOL)animated {
    if (delegateFlags_.delegateWillShowControllerAnimated) {
        [self.delegate pdfViewController:self willShowController:viewController embeddedInController:controller animated:animated];
    }
}

- (void)delegateDidShowController:(id)viewController embeddedInController:(id)controller animated:(BOOL)animated {
    if (delegateFlags_.delegateDidShowControllerAnimated) {
        [self.delegate pdfViewController:self didShowController:viewController embeddedInController:controller animated:animated];
    }
}

- (void)handleTouchUpForAnnotationIgnoredByDelegate:(PSPDFLinkAnnotationView *)annotationView {
    PSPDFAnnotation *annotation = annotationView.annotation;
    if (annotation.pageLinkTarget > 0) {
        //TODO: 书内链接跳转不要操作HUD
        [self scrollToPage:annotation.pageLinkTarget-1 animated:NO];
        
    }else if([annotation.siteLinkTarget length]) {
        if ([[annotation.siteLinkTarget lowercaseString] hasPrefix:@"mailto:"] && [MFMailComposeViewController canSendMail]) {
            // mail
            MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
            mailVC.mailComposeDelegate = self;
            NSString *email = [annotation.siteLinkTarget stringByReplacingOccurrencesOfString:@"mailto:" withString:@""];
            
            // fix encoding
            email = [email stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
            // search for subject
            NSRange subjectRange = [email rangeOfString:@"?subject="];
            if (subjectRange.length > 0) {
                NSRange subjectContentRange = NSMakeRange(subjectRange.location + subjectRange.length, [email length] - subjectRange.location - subjectRange.length);
                NSString *subject = [email substringWithRange:subjectContentRange];
                if ([subject length]) {
                    [mailVC setSubject:subject];
                }
                
                // remove subject from email
                email = [email substringWithRange:NSMakeRange(0, subjectRange.location)];
            }
            
            [mailVC setToRecipients:[NSArray arrayWithObject:email]];
            mailVC.modalPresentationStyle = UIModalPresentationFormSheet;
            [[self masterViewController] presentViewController:mailVC animated:YES completion:nil];
        }else {
            NSURL *URL = annotation.URL ?: [[NSURL alloc] initWithUnicodeString_pspdf:annotation.siteLinkTarget];
            if ([[UIApplication sharedApplication] canOpenURL:URL]) {
                // special case if we want to use an inline browser
                if (annotation.isModal || linkAction_ == PSPDFLinkActionInlineBrowser) {
                    UINavigationController *webControllerNav = [PSPDFWebViewController modalWebViewWithURL:URL];
                    webControllerNav.navigationBar.tintColor = self.tintColor;
                    if (PSIsIpad()) {
                        CGSize targetSize = CGSizeMake(MAX(annotation.size.width, 200), MAX(annotation.size.height, 200));
                        if ([[annotation.options objectForKey:@"popover"] boolValue]) {
                            webControllerNav.topViewController.navigationItem.leftBarButtonItem = nil; // hide Done
                            UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:webControllerNav];
                            popover.popoverContentSize = targetSize;
                            CGRect popoverRect = [self.view convertRect:annotationView.frame fromView:annotationView.superview];
                            self.popoverController = popover;
                            [popover presentPopoverFromRect:popoverRect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
                        }else {
                            if (!CGSizeEqualToSize(annotation.size, CGSizeZero)) {
                                
                                // Note: there's currently (iOS 5.1) a known bug when you put a video into a FormSheet and try to fullscreen it. Best workaround: don't set a size, use full modal size. WWDC
                                // http://openradar.appspot.com/radar?id=1721401
                                webControllerNav.modalPresentationStyle = UIModalPresentationFormSheet;
                                [[self masterViewController] presentViewController:webControllerNav animated:YES completion:nil];
                                // if we go to small, we hide the Done button
                                webControllerNav.view.superview.bounds = (CGRect){0, 0, targetSize};
                            }else {
                                [self presentModalViewController:webControllerNav withCloseButton:NO animated:YES];
                            }
                        }
                    }else {
                        [self presentModalViewController:webControllerNav withCloseButton:NO animated:YES];
                    }
                }else {
                    // web browser
                    if (linkAction_ == PSPDFLinkActionAlertView) {
                        PSPDFAlertView *alert = [PSPDFAlertView alertWithTitle:annotation.siteLinkTarget];
                        [alert setCancelButtonWithTitle:PSPDFLocalize(@"Cancel") block:nil];
                        [alert addButtonWithTitle:PSPDFLocalize(@"Open") block:^{
                            [[UIApplication sharedApplication] openURL:URL];
                        }];
                        [alert show];
                    }else if(linkAction_ == PSPDFLinkActionOpenSafari) {
                        [[UIApplication sharedApplication] openURL:URL];
                    }
                }
            }else {
                PSPDFLogWarning(@"Ignoring tap to %@ - UIApplication canOpenURL reports this is no registered handler.", annotation.siteLinkTarget);
            }
        }
    }
}

// sadly, this is needed. The UINavigationBar frame sometimes gets out of sync after MPMoviePlayerController fullscreen rortations.
// We know about this and apply a fix after the animation is done.
- (void)fixNavigationBarFrame:(NSNotification *)notification {
    if ([self isViewLoaded] && ![self isEmbedded] && self.internalNavController.navigationBar) {
        CGRect navigationBarFrame = self.internalNavController.navigationBar.frame;
        CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
        if (navigationBarFrame.origin.y <= statusBarFrame.origin.y) {
            [UIView animateWithDuration:0.25f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
                CGRect fixedFrame = navigationBarFrame;
                // compensate rotation
                fixedFrame.origin.y = fminf(statusBarFrame.size.height, statusBarFrame.size.width);
                self.internalNavController.navigationBar.frame = fixedFrame;
            } completion:nil];
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init { 
    return self = [self initWithDocument:nil]; // ensure to always call initWithDocument
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    return self = [self initWithDocument:nil]; // ensure to always call initWithDocument (support for Storyboarding)
}

- (id)initWithDocument:(PSPDFDocument *)document {
    if ((self = [super init])) {
        PSPDFLogVerbose(@"Initalize %@ with document %@", NSStringFromClass([self class]), document);
        PSPDFRegisterObject(self);
        PSPDFKitInitializeGlobals();
        NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
        [dnc addObserver:self selector:@selector(frameChangedNotification:) name:kPSPDFViewControllerFrameChanged object:nil];
        [dnc addObserver:self selector:@selector(fixNavigationBarFrame:) name:kPSPDFFixNavigationBarFrame object:nil];
        viewMode_ = PSPDFViewModeDocument;
        landscape_ = PSIsLandscape();
        [self setDocumentInternal:document];
        PSPDFLog(@"Open PDF with folder: %@", document.basePath);
        annotationCache_ = [PSPDFAnnotationCache new];
        targetPageAfterRotate_ = 1; // on 0, first page would be omitted
        iPhoneThumbnailSizeReductionFactor_ = 0.5f;
        pageCurlEnabled_ = NO;
        scrobbleBarEnabled_ = NO;
        positionViewEnabled_ = YES;
        toolbarEnabled_ = YES;
        scrollOnTapPageEndEnabled_ = YES;
        zoomingSmallDocumentsEnabled_ = YES;
        pageScrolling_ = PSPDFScrollingHorizontal;
        pageMode_ = PSIsIpad() ? PSPDFPageModeAutomatic : PSPDFPageModeSingle;
        statusBarStyleSetting_ = PSPDFStatusBarSmartBlack;
        linkAction_ = PSPDFLinkActionInlineBrowser;
        doublePageModeOnFirstPage_ = NO;
        self.lastPage = NSNotFound; // for delegates
        realPage_ = 0;  
        maximumZoomScale_ = 5.f;
        shadowEnabled_ = YES;
        pagePadding_ = 20.f;
        pagingEnabled_ = YES;
        scrollingEnabled_ = YES;
        clipToPageBoundaries_ = YES;
        thumbnailSize_ = CGSizeMake(170.f, 220.f);
        annotationAnimationDuration_ = 0.25f;
        _loadThumbnailsOnMainThread = YES;
        previousBarStyle_ = -1; // marker to save state one-time
        //TODO delete searchButtonItem in array for current version 
        rightBarButtonItems_ = [NSArray arrayWithObjects: self.outlineButtonItem, self.viewModeButtonItem, nil];
    }
    return self;
}

- (void)dealloc {
    PSPDFLogVerbose(@"Deallocating %@", self);
    
    // "the deallocation problem" - it's not safe to dealloc a controller from a thread different than the main thread
    // http://developer.apple.com/library/ios/#technotes/tn2109/_index.html#//apple_ref/doc/uid/DTS40010274-CH1-SUBSECTION11
    NSAssert([NSThread isMainThread], @"Must run on main thread, see http://developer.apple.com/library/ios/#technotes/tn2109/_index.html#//apple_ref/doc/uid/DTS40010274-CH1-SUBSECTION11");
    PSPDFDeregisterObject(self);
    
    // cancel operations, nil out delegates
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(preloadNextThumbnails) object:nil];
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc removeObserver:self name:kPSPDFViewControllerFrameChanged object:nil];
    [dnc removeObserver:self name:kPSPDFFixNavigationBarFrame object:nil];
    
    if (document_) {
        // is called in viewWillDisappear, but call again if some forgot to relay that.
        [[PSPDFCache sharedPSPDFCache] stopCachingDocument:document_];
        document_.displayingPdfController = nil;
    }
    
    delegate_ = nil;    
    [[PSPDFGlobalLock sharedPSPDFGlobalLock] requestClearCacheAndWait:NO]; // request a clear cache
    
    // ensure delegate is nilled out on visible pages
    for(PSPDFScrollView *scrollView in [visiblePages_ setByAddingObjectsFromSet:recycledPages_]) {
        [scrollView releaseDocumentAndCallDelegate:NO];
    }
    
    // if pageCurl is enabled, nil out the delegates here.
    if ([pagingScrollView_ respondsToSelector:@selector(setPdfController:)]) {
        [(PSPDFPagedScrollView *)pagingScrollView_ setPdfController:nil];
    }
    pageViewController_.pdfController = nil;
    gridView_.actionDelegate = nil;
    gridView_.dataSource = nil;
    pagingScrollView_.delegate = nil;
    scrobbleBar_.pdfController = nil;  // deregisters KVO
    positionView_.pdfController = nil; // deregisters KVO
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ page:%lu pageCurl:%d viewMode:%d visiblePageNumbers:%@ fitWidth:%d>", NSStringFromClass([self class]), (unsigned long)self.page, self.pageCurlEnabled, self.viewMode, [self visiblePageNumbers], self.isFittingWidth];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView related

// Return rect of the content view area excluding translucent toolbar/statusbar.
- (CGRect)contentRect {
    CGRect contentRect = self.view.bounds;
    
    if (self.internalNavController.navigationBar.barStyle == UIBarStyleBlackTranslucent || self.internalNavController.navigationBar.translucent) {
        CGFloat navBarHeight = fminf(self.internalNavController.navigationBar.frame.size.width, self.internalNavController.navigationBar.frame.size.height);
        CGFloat translucentStatusBarHeight = [[UIApplication sharedApplication] statusBarStyle] == UIStatusBarStyleLightContent ? fminf([[UIApplication sharedApplication] statusBarFrame].size.height, [[UIApplication sharedApplication] statusBarFrame].size.width) : 0;
        contentRect.origin.y += navBarHeight + translucentStatusBarHeight;
        contentRect.size.height -= navBarHeight + translucentStatusBarHeight;
    }
    return contentRect;
}

// searches the active root/modal viewController. We can't use our parent, we maybe are embedded.
- (UIViewController *)masterViewController {
    UIViewController *masterViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    // use topmost modal view
    while (masterViewController.presentedViewController) {
        masterViewController = masterViewController.presentedViewController;
    }
    
    // get visible controller in a navigation controller
    if ([masterViewController isKindOfClass:[UINavigationController class]]) {
        masterViewController = [(UINavigationController *)masterViewController topViewController];
    }
    
    // if that didn't work out, try if there's a parent
    if (!masterViewController) {
        masterViewController = self.parentViewController;
    }
    
    // last restort
    if (!masterViewController) {
        masterViewController = self;
    }
    
    return masterViewController;
}

// helper
- (BOOL)isHorizontalScrolling {
    return pageScrolling_ == PSPDFScrollingHorizontal;
}

- (void)updatePagingContentSize {
    if (!self.isPageCurlEnabled) {
        CGRect pagingScrollViewFrame = [self frameForPageInScrollView];
        NSUInteger pageCount = [self actualPage:[self.document pageCount]];
        if ([self isDualPageMode] && (([self.document pageCount]%2==1 && self.doublePageModeOnFirstPage) || ([self.document pageCount]%2==0 && !self.doublePageModeOnFirstPage))) {
            pageCount++; // first page...
        }
        PSPDFLog(@"pageCount:%lu, used page Count:%lu", (unsigned long)[self.document pageCount], (unsigned long)pageCount);
        CGSize contentSize;
        if ([self isHorizontalScrolling]) {
            contentSize = CGSizeMake(pagingScrollViewFrame.size.width * pageCount, pagingScrollViewFrame.size.height);
        }else {
            contentSize = CGSizeMake(pagingScrollViewFrame.size.width, pagingScrollViewFrame.size.height * pageCount);
        }
        
        self.pagingScrollView.contentSize = contentSize;
    }
}

// page turn is a iOS5 exclusive feature
- (BOOL)isPageCurlEnabled {
    BOOL allowPageCurl = NO;
    PSPDF_IF_IOS5_OR_GREATER(allowPageCurl = pageCurlEnabled_;)
    
#ifdef _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_
    if (allowPageCurl) {
        PSPDFLogWarning(@"Unable to enable pageCurl as you disabled the needed fixes.");
        PSPDFLogWarning(@"Remove _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_ to enable the pageCurl feature.");
        allowPageCurl = NO;
    }
#endif
    
    return allowPageCurl;
}

- (void)setPageCurlEnabled:(BOOL)pageCurlEnabled {
    if (pageCurlEnabled != pageCurlEnabled_) {
        pageCurlEnabled_ = pageCurlEnabled;
        [self reloadData];
    }
}

- (void)setPageCurlDirectionLeftToRight:(BOOL)pageCurlDirectionLeftToRight {
    if (pageCurlDirectionLeftToRight != pageCurlDirectionLeftToRight_) {
        pageCurlDirectionLeftToRight_ = pageCurlDirectionLeftToRight;
        [self reloadData];
    }
}

// coordinates for the global scrollview
- (CGRect)boundsForPagingScrollView {
    CGRect bounds = self.view.bounds;
    
    // extend the bounds if we don't use pageCurl
    if(!self.isPageCurlEnabled) {
        if ([self isHorizontalScrolling]) {
            bounds.origin.x -= self.pagePadding;
            bounds.size.width += 2 * self.pagePadding;
        }else {
            bounds.origin.y -= self.pagePadding;
            bounds.size.height += 2 * self.pagePadding;
        }
    }
    return bounds;
}

- (void)createPagingScrollView {
    // remove current pdf display classes
    self.pagingScrollView.delegate = nil;
    [self.pagingScrollView removeFromSuperview];
    
    // remove paging view
    [self.pageViewController removeFromParentViewController];
    self.pageViewController.pdfController = nil;
    self.pageViewController = nil;
    
    CGRect bounds = [self boundsForPagingScrollView];
    if(self.isPageCurlEnabled) {
        // first clear pageViewController, release some resources
        PSPDFPageViewController *pageViewController = [[[self classForClass:[PSPDFPageViewController class]] alloc] initWithPDFController:self];
        pageViewController.view.frame = bounds;
        pageViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addChildViewController:pageViewController];
        self.pageViewController = pageViewController;
        PSPDFPagedScrollView *pagedScrollView = [[[self classForClass:[PSPDFPagedScrollView class]] alloc] initWithPageViewController:pageViewController];
        [self.view insertSubview:pagedScrollView belowSubview:self.hudView];
        self.pagingScrollView = pagedScrollView;
    }else {        
        self.pagingScrollView = [[UIScrollView alloc] initWithFrame:bounds];
        if (@available(iOS 11.0, *)) {
            self.pagingScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            self.automaticallyAdjustsScrollViewInsets = NO;
        }
        self.pagingScrollView.pagingEnabled = self.isPagingEnabled;
        self.pagingScrollView.scrollEnabled = self.isScrollingEnabled;
        self.pagingScrollView.backgroundColor = [UIColor clearColor];
        self.pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        if (kPSPDFKitDebugScrollViews) {
            self.pagingScrollView.backgroundColor = [UIColor colorWithRed:0.5f green:0.2f blue:0.f alpha:0.5f];
        }
        self.pagingScrollView.showsVerticalScrollIndicator = NO;
        self.pagingScrollView.showsHorizontalScrollIndicator = NO;
        self.pagingScrollView.delegate = self;
        [self.view insertSubview:self.pagingScrollView belowSubview:self.hudView];
        [self updatePagingContentSize];
        
        // Step 2: prepare to tile content
        self.recycledPages = [NSMutableSet setWithCapacity:4];
        self.visiblePages  = [NSMutableSet setWithCapacity:4];
        [self tilePages:NO];
    }
}

- (BOOL)isTransparentHUD {
    BOOL isTransparentHUD = [self statusBarStyle] != UIStatusBarStyleDefault;
    return isTransparentHUD;
}

- (BOOL)isDarkHUD {
    BOOL isDarkHUD = [self isTransparentHUD];
    if (![self isTransparentHUD] && self.tintColor) {
        const CGFloat *components = CGColorGetComponents(self.tintColor.CGColor);
        CGFloat brightness = 0;
        if (components) {
            brightness = (components[0] * 299 + components[1] * 587 + components[2] * 114)/1000.f;
        }
        isDarkHUD = brightness < 0.6f;
    }
    return isDarkHUD;
}

// Helper that returns the transparent height for the HUD. Used in toolbar scroll offset.
- (CGFloat)hudTransparencyOffset {
    // can't use self.internalNavController.navigationBar.height, updates too late
    CGFloat hudTransparencyOffset = self.isTransparentHUD ? ((PSIsPortrait() || PSIsIpad()) ? 44.f : 30.f) : 0.f;
    if (!PSIsIpad() && [self isTransparentHUD]) {
        CGRect statusBarRect = [UIApplication sharedApplication].statusBarFrame;
        hudTransparencyOffset +=  (statusBarRect.size.height < statusBarRect.size.width ? statusBarRect.size.height : statusBarRect.size.width);
    }
    return hudTransparencyOffset;
}

- (void)updatePositionViewPosition {
    if (self.positionView) {
        CGFloat positionViewHeight = self.view.frame.origin.y + self.view.frame.size.height;
        //if (self.isScrobbleBarEnabled && self.viewMode != PSPDFViewModeThumbnails) {
            //TODO: change positionview position
            positionViewHeight -= 200;
            //positionViewHeight -= self.scrobbleBar.frame.size.height;
        //}
        CGRect frame = CGRectIntegral(CGRectMake(self.view.frame.size.width/2, positionViewHeight - 30.f, 1, 1));
        self.positionView.frame = frame;
    }
}

// Helper that adds the position view if controller is configured to show it
- (void)addPositionViewToHUD {
    if (self.isPositionViewEnabled && !self.positionView && self.hudView) {
        positionView_ = [[[self classForClass:[PSPDFPositionView class]] alloc] initWithFrame:CGRectZero];
        positionView_.pdfController = self;
        positionView_.alpha = 0.0;
        [self.hudView addSubview:positionView_];
        self.positionView = positionView_;
        [self updatePositionViewPosition];
    }
}

// Helper that initializes the scrobble bar
- (void)addScrobbleBarToHUD {
    if (self.isScrobbleBarEnabled && !self.scrobbleBar && self.hudView) {
        if (!self.scrobbleBar) {
            self.scrobbleBar = [[[self classForClass:[PSPDFScrobbleBar class]] alloc] init];
            self.scrobbleBar.pdfController = self;
        }
        [self.hudView addSubview:self.scrobbleBar];
    }
}

// lazily creates a property if nil
- (id)lazyInitProperty:(id __strong *)propertyAddress withClass:(Class)itemClass {
    if (!(*propertyAddress)) {
        *propertyAddress = [[[self classForClass:itemClass] alloc] initWithPDFViewController:self];
    }
    return *propertyAddress;
}

- (PSPDFBarButtonItem *)closeButtonItem {
    return [self lazyInitProperty:&closeButtonItem_ withClass:[PSPDFCloseBarButtonItem class]];
}

- (PSPDFBarButtonItem *)outlineButtonItem {
    return [self lazyInitProperty:&outlineButtonItem_ withClass:[PSPDFOutlineBarButtonItem class]];
}

- (PSPDFBarButtonItem *)searchButtonItem {
    return [self lazyInitProperty:&searchButtonItem_ withClass:[PSPDFSearchBarButtonItem class]];
}

- (PSPDFBarButtonItem *)viewModeButtonItem {
    return [self lazyInitProperty:&viewModeButtonItem_ withClass:[PSPDFViewModeBarButtonItem class]];
}

- (PSPDFViewModeBarButtonItem *)viewModeItem {
    return (PSPDFViewModeBarButtonItem *)self.viewModeButtonItem;
}

- (PSPDFBarButtonItem *)printButtonItem {
    return [self lazyInitProperty:&printButtonItem_ withClass:[PSPDFPrintBarButtonItem class]];
}

- (PSPDFBarButtonItem *)openInButtonItem {
    return [self lazyInitProperty:&openInButtonItem_ withClass:[PSPDFOpenInBarButtonItem class]];
}

- (PSPDFBarButtonItem *)emailButtonItem {
    return [self lazyInitProperty:&emailButtonItem_ withClass:[PSPDFEmailBarButtonItem class]];
}

- (void)setToolbarProperty:(id __strong *)propertyAddress array:(NSArray *)newArray {
    // as leftBarButtonItems is automatically created if set to nil, don't allow nil values here.
    *propertyAddress = newArray ?: [NSArray array];
    [self createToolbar];
}

- (NSArray *)leftBarButtonItems {
    if (!leftBarButtonItems_) {
        UIViewController *topViewController = [[[self navigationController] viewControllers] objectAtIndex:0];
        if (self == topViewController || self.parentViewController == topViewController) {
            leftBarButtonItems_ = [NSArray arrayWithObject:self.closeButtonItem];
        }else {
            leftBarButtonItems_ = [NSArray new];
        }
    }
    return leftBarButtonItems_;
}

- (void)setLeftBarButtonItems:(NSArray *)leftBarButtonItems {
    [self setToolbarProperty:&leftBarButtonItems_ array:leftBarButtonItems];
}

- (void)setRightBarButtonItems:(NSArray *)rightBarButtonItems {
    [self setToolbarProperty:&rightBarButtonItems_ array:rightBarButtonItems];
}

- (void)setAdditionalRightBarButtonItems:(NSArray *)additionalRightBarButtonItems {
    [self setToolbarProperty:&additionalRightBarButtonItems_ array:additionalRightBarButtonItems];
}

- (NSArray *)arrayWithFilteringUnavailableBarButtons:(NSArray *)items {
    NSMutableArray *filteredItems = [NSMutableArray array];
    for (PSPDFBarButtonItem *barButtonItem in items) {
        if (![barButtonItem respondsToSelector:@selector(isAvailable)] || barButtonItem.isAvailable) {
            [filteredItems addObject:barButtonItem];
        }
    }
    return filteredItems;
}

// If barButtonItem is nil, the default size is chosen.
- (CGFloat)approximatWidthForBarButtonItem:(UIBarButtonItem *)barButtonItem {
    CGFloat width = 50;
    if ([barButtonItem.title length]) {
        width = [barButtonItem.title sizeWithFont:[UIFont systemFontOfSize:15]].width + 25;
    }else if(barButtonItem.customView) {
        width = barButtonItem.customView.frame.size.width + 15;
    }
    return  width;
}

- (void)calculateToolbarWidths {
    if ([self isViewLoaded]) {
        _minLeftToolbarWidth = 0;
        
        // left
        NSMutableArray *leftItems = [[self arrayWithFilteringUnavailableBarButtons:self.leftBarButtonItems] mutableCopy];
        for(UIBarButtonItem *barButtonItem in [leftItems copy]) {
            _minLeftToolbarWidth += [self approximatWidthForBarButtonItem:barButtonItem];
        }

        // right
        _minRightToolbarWidth = 0;
        NSMutableArray *rightItems = [[self arrayWithFilteringUnavailableBarButtons:self.rightBarButtonItems] mutableCopy];
        for(UIBarButtonItem *barButtonItem in [rightItems copy]) {
            _minRightToolbarWidth += [self approximatWidthForBarButtonItem:barButtonItem];
        }
        if ([self.additionalRightBarButtonItems count]) {
            _minRightToolbarWidth += [self approximatWidthForBarButtonItem:nil];
        }
    }
}

#define kPSPDFToolbarExtraMargin (PSIsIpad() ? 7.f : 6.f)
- (UIToolbar *)createTransparentToolbar {
    PSPDFTransparentToolbar *toolbar = [[[self classForClass:[PSPDFTransparentToolbar class]] alloc] initWithFrame:CGRectMake(0.f, 0.f, 0.f, CGRectGetHeight(self.internalNavController.navigationBar.bounds) ?: 44.f)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    toolbar.barStyle = [self isDarkHUD] ? UIBarStyleBlack : UIBarStyleDefault;
    toolbar.tintColor = self.tintColor;
    // clipToBounds is a bad idea here, since the button highlighting would be clipped.
    return toolbar;
}

- (void)createToolbar {
    if (self.isToolbarEnabled && [self isViewLoaded]) {
        [self calculateToolbarWidths];
        UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        space.width = 8.f;
        
        NSMutableArray *leftToolbarItems = [NSMutableArray array];
        for (PSPDFBarButtonItem *barButtonItem in self.leftBarButtonItems) {
            if (![barButtonItem respondsToSelector:@selector(isAvailable)] || barButtonItem.isAvailable) {
                [leftToolbarItems addObject:barButtonItem];
                [leftToolbarItems addObject:space];
            }
        }
        self.leftToolbar = [self createTransparentToolbar];
        self.leftToolbar.items = leftToolbarItems;
        if ([self.leftToolbar.items count]) {
            // add a hostingView to compensate UIToolbar margin.
            CGRect lRect = leftToolbar_.frame; lRect.origin.x = -kPSPDFToolbarExtraMargin; leftToolbar_.frame = lRect;
            UIView *hostingView = [[PSPDFHUDView alloc] initWithFrame:self.leftToolbar.bounds];
            hostingView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
            [hostingView addSubview:self.leftToolbar];
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:hostingView];
        }else if([self.navigationItem.leftBarButtonItem.customView isKindOfClass:[PSPDFHUDView class]]) {
            self.navigationItem.leftBarButtonItem = nil;
        }
        
        NSMutableArray *rightToolbarItems = [NSMutableArray array];
        NSArray *availableAdditionalRightBarButtonItems = [self arrayWithFilteringUnavailableBarButtons:self.additionalRightBarButtonItems];
        
        if ([availableAdditionalRightBarButtonItems count] == 1) {
            PSPDFBarButtonItem *barButtonItem = [self.additionalRightBarButtonItems objectAtIndex:0];
            if (barButtonItem.image) {
                [rightToolbarItems addObject:barButtonItem];
                [rightToolbarItems addObject:space];
            }
        }else if ([availableAdditionalRightBarButtonItems count] > 1) {
            PSPDFMoreBarButtonItem *moreButtonItem = [[PSPDFMoreBarButtonItem alloc] initWithPDFViewController:self];
            [rightToolbarItems addObject:moreButtonItem];
            [rightToolbarItems addObject:space];
        }
        
        for (PSPDFBarButtonItem *barButtonItem in self.rightBarButtonItems) {
            if (![barButtonItem respondsToSelector:@selector(isAvailable)] || barButtonItem.isAvailable) {
                [rightToolbarItems addObject:barButtonItem];
                [rightToolbarItems addObject:space];
            }
        }
        
        [rightToolbarItems insertObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL] atIndex:0];
        [rightToolbarItems removeLastObject];
        
        self.rightToolbar = [self createTransparentToolbar];
        self.rightToolbar.items = rightToolbarItems;
        
        if ([self.rightToolbar.items count]) {
            CGRect rRect = rightToolbar_.frame; rRect.origin.x = kPSPDFToolbarExtraMargin; rightToolbar_.frame = rRect;
            UIView *hostingView = [[PSPDFHUDView alloc] initWithFrame:self.rightToolbar.bounds];
            hostingView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
            [hostingView addSubview:self.rightToolbar];
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:hostingView];
            // Note: if IOS5's rightBarButtomItems would be used here, we would get a button style for search, which we don't want.
        }else if([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[PSPDFHUDView class]]) {
            self.navigationItem.rightBarButtonItem = nil;
        }
        
        [self addScrobbleBarToHUD];
        [self addPositionViewToHUD];
        [self updateToolbars];
    }
}

- (void)updateToolbars {
    // only perform if toolbar has been created
    if (self.isToolbarEnabled && self.leftToolbar) {
        CGRect leftFrame = self.leftToolbar.superview.frame;
        CGRect rightFrame = self.rightToolbar.superview.frame;

        CGFloat navBarWidth = CGRectGetWidth(self.internalNavController.navigationBar.bounds);
        CGFloat maxToolbarWidth = roundf(navBarWidth / 2.f);
        leftFrame.size.width = [self.leftToolbar.items count] ? fminf(maxToolbarWidth, _minLeftToolbarWidth) : 0.f;
        rightFrame.size.width = [self.rightToolbar.items count] ? fminf(maxToolbarWidth, _minRightToolbarWidth) : 0.f;
        
        // on the iPhone, space is rare.
        if (!PSIsIpad() && [leftToolbar_.items count] < 5 && [rightToolbar_.items count] > 0) {
            rightFrame.size.width = fmaxf(roundf(maxToolbarWidth * 6/5), _minRightToolbarWidth);
        }
        
        self.leftToolbar.superview.frame = leftFrame;
        self.rightToolbar.superview.frame = rightFrame;
        
        // enable/disable buttons depending on document state
        NSMutableSet *barButtonItems = [NSMutableSet new];
        if (self.leftToolbar) {
            [barButtonItems addObjectsFromArray:self.leftToolbar.items];
        }
        if (self.rightToolbar) {
            [barButtonItems addObjectsFromArray:self.rightToolbar.items];
        }
        BOOL isValidDocument = self.document.isValid;
        for (UIBarButtonItem *barButtonItem in barButtonItems) {
            if ([barButtonItem isKindOfClass:[PSPDFBarButtonItem class]]) {
                [(PSPDFBarButtonItem *)barButtonItem updateBarButtonItem];
            }else if ([barButtonItem isKindOfClass:[UIBarButtonItem class]]) {
                barButtonItem.enabled = isValidDocument;
            }
        }
        
        // set again to make UINavigationBar honor the toolbar frame.
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.leftToolbar.superview];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.rightToolbar.superview];
        
        // As of iOS5, the navigationBar supports setting an array of UIBarButtonItems.
        // We can't use that as we're still supporting iOS4 and the plain button style isn't supported.
        BOOL useModernNavigationBarFeatures = NO;
        if (useModernNavigationBarFeatures) {
            self.navigationItem.leftBarButtonItems = [[self.leftToolbar.items reverseObjectEnumerator] allObjects];
            self.navigationItem.rightBarButtonItems = [[self.rightToolbar.items reverseObjectEnumerator] allObjects];
        }
        
        // uncomment to see toolbar width
        /*
         self.leftToolbar.backgroundColor = [UIColor redColor];
         self.rightToolbar.backgroundColor = [UIColor redColor];
         */
    }
}

- (void)setMinLeftToolbarWidth:(CGFloat)minLeftToolbarWidth {
    _minLeftToolbarWidth = minLeftToolbarWidth;
}

- (void)setMinRightToolbarWidth:(CGFloat)minRightToolbarWidth {
    _minRightToolbarWidth = minRightToolbarWidth;
}

- (void)loadView {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    PSPDFViewControllerView *view = [[[self classForClass:[PSPDFViewControllerView class]] alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.clipsToBounds = YES; // don't draw outside borders
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    PSPDFLogVerbose(@"Loading view for %@", self);
    
    //TODO: 修改HUDVIEW为初始显示
    // setup HUD
    PSPDFHUDView *hudView = [[[self classForClass:[PSPDFHUDView class]] alloc] initWithFrame:self.view.bounds];
    hudView.backgroundColor  = [UIColor clearColor];
    hudView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    hudView.alpha = 1.0;
    [self.view addSubview:hudView];
    self.hudView = hudView;
    
    // set custom background color if needed
    self.view.backgroundColor = self.backgroundColor ? self.backgroundColor : [UIColor whiteColor];
    
    // view debugging
    if(kPSPDFKitDebugScrollViews) {
        self.view.backgroundColor = [UIColor orangeColor];
    }
    
    // initally save last orientation
    self.lastOrientationSize = self.view.bounds.size;
}

- (UINavigationController *)internalNavController {
    return navigationController_;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    PSPDFLogVerbose(@"%@", self);
    
    self.viewVisible = YES;
    
    // configure toolbar if enabled
    if (self.isToolbarEnabled) {
        navigationController_ = self.navigationController;
PSPDF_IF_IOS5_OR_GREATER(
                         // don't use the navBar if we're set to NO.
                         if(self.navigationController == self.parentViewController.navigationController && !self.useParentNavigationBar) {
                             navigationController_ = nil;
                         });
        if (navigationController_ && (NSInteger)previousBarStyle_ == -1) {
            previousBarAlpha_  = self.navigationController.navigationBar.alpha;
            previousBarHidden_ = self.navigationController.navigationBarHidden;
            previousBarTint_   = self.navigationController.navigationBar.tintColor;
            previousBarStyle_  = self.navigationController.navigationBar.barStyle;
            previousBarStyleTranslucent_ = self.navigationController.navigationBar.translucent;
        }
        
// 以下代码被注释，修改系统导航类变成半透明问题，并不确保PDF界面不受影响，如有问题，请找柯洁
// viewWillDisappear也有代码被注释
/********************************************************************************
        BOOL animatedAndNotOnTop = animated && [self.internalNavController.viewControllers count] > 1;
        if (self.internalNavController && animatedAndNotOnTop && (previousBarStyle_ != UIBarStyleBlackTranslucent || navigationController_.navigationBar.translucent != YES)) {
            CATransition *transition = [CATransition animation];
            transition.duration = 0.25f;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            [navigationController_.navigationBar.layer addAnimation:transition forKey:nil];
        }
        
        navigationController_.navigationBar.barStyle = [self isDarkHUD] ? UIBarStyleBlackTranslucent : UIBarStyleDefault;
        navigationController_.navigationBar.tintColor = tintColor_;
        navigationController_.navigationBar.translucent = [self isTransparentHUD];
 ********************************************************************************/
    }
    
    // optimizes caching
    self.document.displayingPdfController = self;
    
    // save current status bar style and change to configured style
    self.savedStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    self.savedStatusBarVisibility = [UIApplication sharedApplication].statusBarHidden;
    //TODO: 统一样式
    UIStatusBarStyle statusBarStyle;
    if ([[UIDevice currentDevice].systemVersion floatValue]>= 7.0) {
            statusBarStyle = UIStatusBarStyleDefault;
    }
    else
    {
            statusBarStyle = UIStatusBarStyleLightContent;
    }
    [self setStatusBarStyle:statusBarStyle animated:animated];
    
    // on iPhone, we may want fullscreen layout
    //if (statusBarStyle == UIStatusBarStyleBlackTranslucent || self.statusBarStyleSetting & PSPDFStatusBarDisable) {
//        self.wantsFullScreenLayout = YES;
    //}
    
    // if statusbar hiding is requested, hide!
//    if (self.statusBarStyleSetting & PSPDFStatusBarDisable) {
//        [self setStatusBarHidden:YES withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
//        
//        // correct bounds for the navigation bar is calculated one runloop later.
//        // if we just hide the statusbar here, we need to show/hide the HUD to fix the statusbar gap.
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self setHUDVisible:NO animated:NO];
//            [self setHUDVisible:YES animated:animated];
//        });
//    }
    
    // update rotation specific settings
    [self updateSettingsForRotation:self.view.bounds.size];
    
    // notify delegates that we're about to display a document
    [self delegateWillDisplayDocument];
    
    // finally load scrollview!
    // TODO: WWDC. Is there a workaround to instantly get the correct view coordinates?
    // if we don't delay reload the initial view is too small.
    // Test with EmbeddedExample + PSPDFKit.pdf in Landscape -> push on stack.
    BOOL needsAdditionalReload = (self.internalNavController.navigationBar.translucent) && !self.pageCurlEnabled;
    // set flag to prevent delegate calls until the view is reloaded.
    _didReloadFirstPageWorkaround = needsAdditionalReload;
    [self reloadDataAndScrollToPage:self.realPage];
    if (needsAdditionalReload) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didReloadFirstPageWorkaround = NO;
            self.lastPage = NSNotFound;
            [self reloadDataAndScrollToPage:self.realPage];
        });
    }

    //TODO: HUD is visible initially
    //[self setHUDVisible:NO animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    PSPDFLogVerbose(@"%@ (animated:%d)", self, animated);
    
    // relay any rotation that may happened after we were offscreen
    CGSize currentOrientationSize = self.view.bounds.size;
    if (!CGSizeEqualToSize(currentOrientationSize, self.lastOrientationSize)) {
        [self willChangeSize:currentOrientationSize];
        [self chaningToSize:currentOrientationSize];
        [self didChangeToSize:currentOrientationSize];
        self.lastOrientationSize = currentOrientationSize;
    }
    
    [self delegateDidDisplayDocument];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    PSPDFLogVerbose(@"%@ (animated:%d)", self, animated);
    self.popoverController = nil;
    self.viewVisible = NO;
    
    //TODO: 屏蔽switch back
    // switch back to document mode (but don't care if we're no longer on the viewController
//    BOOL shouldSwitchBack = !self.internalNavController || [self.internalNavController.viewControllers containsObject:self];
//    if (shouldSwitchBack) {
//        [self setViewMode:PSPDFViewModeDocument animated:YES];
//    }
    
    // stop potential preload request
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(preloadNextThumbnails) object:nil];
    
    if (self.document) {
        // optimizes caching
        self.document.displayingPdfController = nil;
    }
    
    // restore statusbar
    //TODO:关闭控制statusbar
//    [self setStatusBarStyle:self.savedStatusBarStyle animated:animated];
//    [self setStatusBarHidden:self.savedStatusBarVisibility withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    
// 以下代码被注释，修改系统导航类变成半透明问题，并不确保PDF界面不受影响，如有问题，请找柯洁
// viewWillAppear也有代码被注释
/********************************************************************************
    // self.internalNavController is already nil here, so use the saved reference
    if (navigationController_.topViewController != self) {
        BOOL shouldRestore = [navigationController_.viewControllers lastObject] && [navigationController_.viewControllers lastObject] != self && [navigationController_.viewControllers lastObject] != self.parentViewController;
        BOOL animatedAndNotOnTop = animated && shouldRestore;
        [navigationController_ setNavigationBarHidden:previousBarHidden_ animated:animatedAndNotOnTop];
        if (animatedAndNotOnTop && (navigationController_.navigationBar.barStyle != previousBarStyle_ || navigationController_.navigationBar.translucent != previousBarStyleTranslucent_)) {
            CATransition *transition = [CATransition animation];
            transition.duration = 0.25f;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            [navigationController_.navigationBar.layer addAnimation:transition forKey:nil];
        }
        
        if (shouldRestore) {
            navigationController_.navigationBar.alpha = previousBarAlpha_;
            navigationController_.navigationBar.tintColor = previousBarTint_;
            // this might produce a frame change notification (but viewVisible is already nil)
            navigationController_.navigationBar.barStyle = previousBarStyle_;
            navigationController_.navigationBar.translucent = previousBarStyleTranslucent_;
        }
    }
 ********************************************************************************/
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    PSPDFLogVerbose(@"%@ (animated:%d)", self, animated);
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self willChangeSize:size];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self chaningToSize:size];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self didChangeToSize:size];
    }];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)willChangeSize:(CGSize)size {
    // we'll have to capture our target scroll page here, as pre-rotate maybe calls tilePages and changes current page...
    NSInteger lastRotationValue = targetPageAfterRotate_;
    targetPageAfterRotate_ = self.realPage;
    
    // now it get's tricky. make sure that after rotating back from two-page-mode to single page, we're showing the right page
    if ([self isDualPageMode] && lastRotationValue >= 0) {
        BOOL wasRightPage = [self isRightPageInDoublePageMode:lastRotationValue];
        BOOL singleFirstPage = !self.doublePageModeOnFirstPage && self.page == 0;
        BOOL isLastPage = targetPageAfterRotate_ == [document_ pageCount]-1;
        if (wasRightPage && !singleFirstPage && !isLastPage) {
            targetPageAfterRotate_++;
        }
    }
    
    // save orientation in case we rotate while off-screen
    self.lastOrientationSize = size;
    
    [self updateSettingsForRotation:size];
    
    // if there's a popover visible, hide it on rotation!
    self.popoverController = nil;
    
    rotationActive_ = YES;
    
    // disable tiled layer for rotation (fixes rotation problems with layer+background and tiledlayer artifacts on size change)
    for (PSPDFScrollView *page in self.visiblePages) {
        page.rotationActive = YES;
    }
    
    // PSPDFPageViewController's rotate is called before we come to willAnimateRotation, so set early.
    if (self.isPageCurlEnabled) {
        realPage_ = targetPageAfterRotate_;
    }
}

- (void)chaningToSize:(CGSize)size {
    // rotation is handled implicit via the setFrame-notification
    if ([self isViewLoaded] && self.view.window) {
       //PSPDF_IF_PRE_IOS5([self updateGridForOrientation];) // viewWillLayoutSubviews is iOS5 only
        [self updatePagingContentSize];
        [self updateToolbars];
        [self scrollToPage:targetPageAfterRotate_ animated:NO hideHUD:NO];        
        rotationAnimationActive_ = YES; // important to only enable the flag here (or rotate animation and delegates freak out)
        [self tilePages:YES];
    }
    rotationAnimationActive_ = NO;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self updateGridForOrientation];
}

- (void)didChangeToSize:(CGSize)size {
    rotationActive_ = NO;
    
    // If we don't reload after rotation, we get all kind of weird bugs breaking rotation altogether.
    // ([UIWindow beginDisablingInterfaceAutorotation] overflow on <UIWindow ...)
    // TODO: remains a todo, this may be fixed in future versions of iOS.
    if (self.isPageCurlEnabled) {
        [self reloadData];
    }
    
    // re-disable tiled layer for rotation
    for (PSPDFScrollView *page in self.visiblePages) {
        page.rotationActive = NO;
    }
}

- (void)setPopoverController:(UIPopoverController *)popoverController {
    // be sure to dismiss the popover of our toolbar.
    // Some BarButtonItems can't expose their popover, so hide even if popoverController_ is nil
    [PSPDFBarButtonItem dismissPopoverAnimated:NO];
    
    if (popoverController != popoverController_) {
        // hide last popup
        [popoverController_ dismissPopoverAnimated:NO];
        popoverController_.delegate = nil;
        popoverController_ = popoverController;
        popoverController_.delegate = self; // set delegate to be notified when popopver controller closes!
        
        // relay popover if there's a setter
        if ([popoverController.contentViewController respondsToSelector:@selector(setPopoverController:)]) {
            [(PSPDFWebViewController *)popoverController.contentViewController setPopoverController:popoverController];
        }
    }
}

// relay the navigationItem of a contained viewController (iOS5)
- (UINavigationItem *)navigationItem {
    PSPDF_IF_PRE_IOS5(return [super navigationItem];)
    
    if (useParentNavigationBar_ && self.parentViewController) {
        return self.parentViewController.navigationItem;
    }else {
        return [super navigationItem];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

// corects landscape-values if entered in landscape
- (BOOL)scrollToPage:(NSUInteger)page animated:(BOOL)animated hideHUD:(BOOL)hideHUD {
    if (![self.document isValid]) {
        return NO; // silent abort of we don't have a document set
    }

    if (page >= [self.document pageCount]) {
        PSPDFLogWarning(@"Cannot scroll outside boundaries (%lu), ignoring.", (unsigned long)page);
        return NO;
    }
    
    // stop if delegate doesn't allow scrolling
    if(![self delegateShouldScrollToPage:page]) {
        return NO;
    }

    NSUInteger actualPage = [self actualPage:page];
    
    if (self.isViewVisible) {
        CGRect pageFrame = [self frameForPageAtIndex:actualPage];
        if ([self isHorizontalScrolling]) {
            pageFrame.origin.x -= self.pagePadding;
        }else {
            pageFrame.origin.y -= self.pagePadding;
        }
        if (hideHUD) {
            [self hideControlsIfPageMode];
        }
        
        if (!self.isPageCurlEnabled) {
            PSPDFLogVerbose(@"Scrolling to offset: %@", NSStringFromCGRect(pageFrame));
            [self.pagingScrollView setContentOffset:pageFrame.origin animated:animated];
            
            // if not animated, we have to manually tile pages.
            // also don't manually call when we're in the middle of rotation
            if (!animated && !(rotationActive_ && !rotationAnimationActive_)) {
                [self tilePages:NO];
            }
        }else {
            [pageViewController_ setPage:page animated:animated];
            self.page = actualPage;
        }
    }else {
        // not visible atm, just set page
        self.page = actualPage;
    }
    return YES;
}

- (BOOL)scrollToPage:(NSUInteger)page animated:(BOOL)animated {
    return [self scrollToPage:page animated:animated hideHUD:NO];
}

- (BOOL)scrollToNextPageAnimated:(BOOL)animated {
    if (![self isLastPage]) {
        NSUInteger nextPage = [self landscapePage:self.page+1];
        [self scrollToPage:nextPage animated:animated]; 
        return YES;
    }else {
        PSPDFLog(@"max page count of %lu exceeded! tried:%lu", (unsigned long)[self.document pageCount], (unsigned long)self.page+1);
        return NO;
    }
}

- (BOOL)scrollToPreviousPageAnimated:(BOOL)animated {
    if (![self isFirstPage]) {
        NSUInteger prevPage = [self landscapePage:self.page-1];
        [self scrollToPage:prevPage animated:animated];   
        return YES;
    }else {
        PSPDFLog(@"Cannot scroll < page 0");
        return NO;
    }
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated {
    PSPDFPageView *pageView = [self pageViewForPage:self.page];
    [pageView.scrollView scrollRectToVisible:rect animated:animated];
}

- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated {
    PSPDFPageView *pageView = [self pageViewForPage:self.page];
    [pageView.scrollView zoomToRect:rect animated:animated];
}

- (PSPDFViewState *)documentViewState {
    UIScrollView *scrollView = [self pageViewForPage:self.page].scrollView;
    PSPDFViewState *state = [PSPDFViewState new];
    state.page = self.page;
    state.contentOffset = scrollView.contentOffset;
    state.zoomScale = scrollView.zoomScale;
    return state;
}

- (void)restoreDocumentViewState:(PSPDFViewState *)viewState animated:(BOOL)animated {
    // we can't restore the view if we're not ready yet.
    if (![self isViewLoaded]) {
        self.restoreViewStatePending = viewState;
        return;
    }
    
    if (self.page != viewState.page) {
        [self scrollToPage:viewState.page animated:animated hideHUD:viewState.showHUD];
        
        // do we need to zoom to a certain rect? if so, this needs to be done AFTER scrolling.
        // (using delegateDidEndPageScrolling)
        if(animated && viewState.zoomScale > 1.f) {
            self.restoreViewStatePending = viewState;
            return;
        }
    }
    
    // Note: because we *center* the rect in PSPDFScrollView, this messes up our scrollView animation when setting a rect.
    PSPDFPageView *pageView = [self pageViewForPage:self.page];
    pageView.scrollView.zoomScale = viewState.zoomScale;
    pageView.scrollView.contentOffset = viewState.contentOffset;
    
    /*
     // WWDC
     CGRect visibleRect = (CGRect){.origin = viewState.contentOffset, .size = pageView.scrollView.bounds.size};
     if (viewState.zoomScale > 1.f) {
     float theScale = 1.0 / viewState.zoomScale;
     visibleRect.origin.x *= theScale;
     visibleRect.origin.y *= theScale;
     visibleRect.size.width *= theScale;
     visibleRect.size.height *= theScale;
     [pageView.scrollView setZoomScale:viewState.zoomScale animated:NO];
     [pageView.scrollView zoomToRect:visibleRect animated:YES];
     [self printVisibleRect];
     //pageView.scrollView.contentOffset = viewState.contentOffset;
     }
     
     - (void)printVisibleRect {
     PSPDFPageView *pageView = [self pageViewForPage:self.page];
     CGRect visibleRect = (CGRect){.origin = pageView.scrollView.contentOffset, .size = pageView.scrollView.bounds.size};
     float theScale = 1.0 / pageView.scrollView.zoomScale;
     visibleRect.origin.x *= theScale;
     visibleRect.origin.y *= theScale;
     visibleRect.size.width *= theScale;
     visibleRect.size.height *= theScale;
     NSLog(@"%@", NSStringFromCGRect(visibleRect));
     }
     */
    
    self.restoreViewStatePending = nil;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (backgroundColor_ != backgroundColor) {
        backgroundColor_ = backgroundColor;
        
        // only relay to view if loaded
        if ([self isViewLoaded]) {
            self.view.backgroundColor = backgroundColor;
        }
    }
}

// add special support that accepts plain NSString's as PSPDFDocument, most likely used by Storybarding. Does not fire KVO.
- (void)setDocumentInternal:(PSPDFDocument *)document {
    if ([document isKindOfClass:[NSString class]]) {
        NSString *documentPath = PSPDFResolvePathNames((NSString *)document, nil);
        document_ = [PSPDFDocument PDFDocumentWithUrl:[NSURL fileURLWithPath:documentPath]];
    }else {
        document_ = document;
    }
    
    [self updateNavBarTitleIfAllowed];
    
    // set document delegate to listen for search events
    document_.documentSearcher.delegate = self;
}

- (void)setDocument:(PSPDFDocument *)document {
    PSPDFLogVerbose(@"Setting new document %@", document);
    if (document_ != document) {
        if (document_) {
            [[PSPDFCache sharedPSPDFCache] stopCachingDocument:document_];
            document_.displayingPdfController = nil;
            document_.documentSearcher.delegate = nil;
        }
        [self setDocumentInternal:document];
        self.lastPage = NSNotFound; // reset last page
        [self reloadDataAndScrollToPage:0];
    }
}

- (void)setPageMode:(PSPDFPageMode)pageMode {
    if (pageMode != pageMode_) {
        pageMode_ = pageMode;
        // don't rotate if rotation is active
        if (!rotationActive_) {
            [self reloadData];
        }
    }
}

- (void)setScrobbleBarEnabled:(BOOL)scrobbleBarEnabled {
    if (scrobbleBarEnabled != scrobbleBarEnabled_) {
        scrobbleBarEnabled_ = scrobbleBarEnabled;
        
        // only adds the view if enabled, and hide initially
        [self addScrobbleBarToHUD];
        self.scrobbleBar.alpha = scrobbleBarEnabled ? 0.f : 1.f;
        
        // default animation, duration can be overridden when inside another animation block
        // still there's a chance thet we don't get the positionView (if HUD is not yet initialized)
        [UIView animateWithDuration:0.f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            if(scrobbleBarEnabled) {self.scrobbleBar.hidden = NO;}
            self.scrobbleBar.alpha = scrobbleBarEnabled ? 1.f : 0.f;
        } completion:^(BOOL finished) {
            self.scrobbleBar.hidden = !scrobbleBarEnabled;
        }];
    }    
}

- (void)setPositionViewEnabled:(BOOL)positionViewEnabled {
    if (positionViewEnabled != positionViewEnabled_) {
        positionViewEnabled_ = positionViewEnabled;
        
        // only adds the view if enabled, and hide initially
        [self addPositionViewToHUD];
        self.positionView.alpha = 0.0;
        
        // default animation, duration can be overridden when inside another animation block
        // still there's a chance thet we don't get the positionView (if HUD is not yet initialized)
//        [UIView animateWithDuration:0.f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
//            if(positionViewEnabled) {self.positionView.hidden = NO;}
//            self.positionView.alpha = 0.0;
//        } completion:^(BOOL finished) {
//            self.positionView.hidden = !positionViewEnabled;
//        }];
    }
}

// relay property
- (void)setClipToPageBoundaries:(BOOL)clipToPageBoundaries {
    clipToPageBoundaries_ = clipToPageBoundaries;
    pageViewController_.clipToPageBoundaries = clipToPageBoundaries;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Tiling and page configuration

- (NSArray *)visiblePageNumbers {
    NSMutableArray *visiblePageNumbers = nil;
    
    if (self.isPageCurlEnabled) {
        visiblePageNumbers = [NSMutableArray arrayWithCapacity:2];
        NSInteger currentPage = self.pageViewController.page;
        if(currentPage >= 0) { // might be an invalid page (e.g. first page right only)
            [visiblePageNumbers addObject:[NSNumber numberWithInteger:currentPage]];
        }
        BOOL isDualPageMode = [self isDualPageMode];
        BOOL isNotLastPage = currentPage+1 < (NSInteger)([self.document pageCount]);
        if (isDualPageMode && isNotLastPage) {
            [visiblePageNumbers addObject:[NSNumber numberWithInteger:currentPage+1]];
        }
    }else {
        visiblePageNumbers = [NSMutableArray arrayWithCapacity:[self.visiblePages count]];
        for (PSPDFScrollView *scrollView in self.visiblePages) {
            if (scrollView.leftPage.document) {
                [visiblePageNumbers addObject:[NSNumber numberWithInteger:scrollView.leftPage.page]];
            }
            if (scrollView.rightPage.document) {
                [visiblePageNumbers addObject:[NSNumber numberWithInteger:scrollView.rightPage.page]];
            }
        }
    }
    return visiblePageNumbers;
}

// search for the page within PSPDFScollView
- (PSPDFPageView *)pageViewForPage:(NSUInteger)page {
    PSPDFPageView *pageView = nil;
    
    if (self.isPageCurlEnabled) {
        for (PSPDFSinglePageViewController *singlePage in self.pageViewController.viewControllers) {
            if (singlePage.page == page) {
                pageView = singlePage.pageView;
            }
        }
    }else {
        for (PSPDFScrollView *scrollView in self.visiblePages) {
            if (scrollView.leftPage.page == page) {
                pageView = scrollView.leftPage;
                break;
            }else if(scrollView.rightPage.document && scrollView.rightPage.page == page) {
                pageView = scrollView.rightPage;
                break;
            }
        }
    }
    
    return pageView;
}

// be sure to destroy pages before d'allocating
- (void)setVisiblePages:(NSMutableSet *)visiblePages {
    if (visiblePages != visiblePages_) {
        [self destroyVisiblePages];
        visiblePages_ = visiblePages;
    }
}

// checks if a page is already displayed in the scrollview
- (BOOL)isDisplayingPageForIndex:(NSUInteger)pageIndex {
    BOOL foundPage = NO;
    for (PSPDFScrollView *page in self.visiblePages) {
        if (page.page == pageIndex) {
            foundPage = YES;
            break;
        }
    }
    return foundPage;
}

// stop all rendering
- (void)destroyVisiblePages {
    for (PSPDFScrollView *page in self.visiblePages) {        
        [page releaseDocumentAndCallDelegate:YES];
    }
    
    // no delegate calls needed, already recycled here
    for (PSPDFScrollView *page in self.recycledPages) {
        [page releaseDocumentAndCallDelegate:NO];
    }
}

- (PSPDFScrollView *)dequeueRecycledPage {
    PSPDFScrollView *page = [self.recycledPages anyObject];
    if (page) {
        [self.recycledPages removeObject:page];
    }
    return page;
}

// if there is a discrepancy between dual page mode, convert the pages first
- (void)convertPageOnDualModeChange:(PSPDFScrollView *)page currentPage:(NSUInteger)currentPage {
    if (page.dualPageMode != [self isDualPageMode]) {
        // we were dual paged, now converting back to single-pages (or vice versa)
        page.page = page.dualPageMode ? [self landscapePage:page.page convert:YES] : [self actualPage:page.page convert:YES];
        
        // make rotation awesome. (if the *right* page of a two-page set is visible, switch internal pages so that right page is not reused)
        if (page.dualPageMode && page.page == currentPage-1) {
            [page switchPages];
            page.page = currentPage;
        }
        
        page.dualPageMode = [self isDualPageMode];
    }    
}

// UIScrollView likes to scroll a few pixel "too far" - letting us create pages that we instantly destroy
// after ScrollerHeartBeat corrects the problem and finishes the scrolling. Compensate.
#define kScrollAnimationCompensator 3
//TODO: page recycled
- (void)tilePages:(BOOL)forceUpdate {
    // return early if paging scrollview is not yet created
    if (!self.pagingScrollView || self.isPageCurlEnabled) {
        return;
    }
    
    // if pagePadding is zero, we can't compensate scrollview movements
    
    CGFloat scrollAnimationCompensator = fminf(kScrollAnimationCompensator, pagePadding_);
    
    // Calculate which pages are visible
    CGRect visibleBounds = self.pagingScrollView.bounds;
    NSInteger firstNeededPageIndex, lastNeededPageIndex, primaryPageIndex;
    if ([self isHorizontalScrolling]) {
        firstNeededPageIndex = floorf((CGRectGetMinX(visibleBounds)+scrollAnimationCompensator) / CGRectGetWidth(visibleBounds));
        lastNeededPageIndex  = floorf((CGRectGetMaxX(visibleBounds)-scrollAnimationCompensator) / CGRectGetWidth(visibleBounds));
        primaryPageIndex = MAX(roundf(CGRectGetMinX(visibleBounds) / CGRectGetWidth(visibleBounds)), 0);
    }else {
        firstNeededPageIndex = floorf((CGRectGetMinY(visibleBounds)+scrollAnimationCompensator) / CGRectGetHeight(visibleBounds));
        lastNeededPageIndex  = floorf((CGRectGetMaxY(visibleBounds)-scrollAnimationCompensator) / CGRectGetHeight(visibleBounds));
        primaryPageIndex = MAX(roundf(CGRectGetMinY(visibleBounds) / CGRectGetHeight(visibleBounds)), 0);
    }
        
    // make sure firstNeededPageIndex is within range
    firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
    
    // make sure lastNeededPageIndex is limited to pageCount
    if ([self isDualPageMode]) { // two pages per slide
        lastNeededPageIndex = MIN(lastNeededPageIndex, floorf([self.document pageCount]/2));
    }else {
        lastNeededPageIndex = MIN(lastNeededPageIndex, [self.document pageCount] - 1);
    }
    
    // estimate page that is mostly visible
    PSPDFLogVerbose(@"first:%ld last:%ld page:%ld", (long)firstNeededPageIndex, (long)lastNeededPageIndex, (long)primaryPageIndex);

    // remember vertical position?
    CGPoint offsetPoint = [self pageViewForPage:self.realPage].scrollView.contentOffset;
    
    // Recycle no-longer-visible pages (or convert for re-use while rotation)
    NSMutableSet *removedPages = [NSMutableSet set];
    for (PSPDFScrollView *page in self.visiblePages) {
        [self convertPageOnDualModeChange:page currentPage:[self landscapePage:primaryPageIndex]]; // used so we can re-use page on a dual page mode change (rotate, usually)
        if (page.page < firstNeededPageIndex || page.page > lastNeededPageIndex) {
            [page releaseDocumentAndCallDelegate:YES]; // remove set pdf, release memory (also, calls delegate!)
            [self.recycledPages addObject:page];   
            [removedPages addObject:page];
        }
    }
    [self.visiblePages minusSet:self.recycledPages];
    
    // add missing pages
    NSMutableSet *updatedPages = [NSMutableSet set];
    for (NSInteger pageIndex = firstNeededPageIndex; pageIndex <= lastNeededPageIndex; pageIndex++) {
        if (![self isDisplayingPageForIndex:pageIndex]) {
            PSPDFScrollView *page = [self dequeueRecycledPage];
            if ([removedPages containsObject:page]) {
                [removedPages removeObject:page];
            }
            if (page == nil) {
                page = [[[self classForClass:[PSPDFScrollView class]] alloc] init];
            }
            
            // add view
            [self.pagingScrollView addSubview:page];
            [self.visiblePages addObject:page];
            
            // configure it (also sends delegate events)
            [self configurePage:page forIndex:pageIndex];
            
            // ensure content is scrolled to top. (fitWidth + PSPDFScrollingVertical is not yet supported)
            if (self.fitWidth && self.pageScrolling == PSPDFScrollingHorizontal) {
                if (self.fixedVerticalPositionForFitWidthMode) {
                    page.contentOffset = CGPointMake(fminf(offsetPoint.x, page.contentSize.width-self.view.bounds.size.width), fminf(offsetPoint.y, page.contentSize.height - self.view.bounds.size.height));
                }else {
                    page.contentOffset = CGPointMake(0, 0);
                }
            }
            [updatedPages addObject:page];
        }
    }
    
    // only call removeFromSuperview for those pages that are not instantly re-used.
    // needs do be done in next runloop, else we may recursively invoke scrollViewDidScroll
    dispatch_async(dispatch_get_main_queue(), ^{
        [removedPages makeObjectsPerformSelector:@selector(removeFromSuperview)];
    });
    
    // if forced, configure all pages (used for rotation events)
    if (forceUpdate) {
        for (PSPDFScrollView *page in self.visiblePages) {
            if (![updatedPages containsObject:page]) {
                [self configurePage:page forIndex:page.page];
            }
        }
    }
    
    // finally, set new page
    self.page = primaryPageIndex;
}

// set properties within scrollview, update view
- (void)configurePage:(PSPDFScrollView *)page forIndex:(NSUInteger)pageIndex {
    page.dualPageMode = [self isDualPageMode];
    page.doublePageModeOnFirstPage = self.doublePageModeOnFirstPage;
    page.frame = [self frameForPageAtIndex:pageIndex];  
    page.zoomingSmallDocumentsEnabled = self.zoomingSmallDocumentsEnabled;
    page.shadowEnabled = self.shadowEnabled;
    page.scrollOnTapPageEndEnabled = self.scrollOnTapPageEndEnabled;
    page.fitWidth = [self isHorizontalScrolling] && self.isFittingWidth; // KNOWN LIMITATION
    page.pdfController = self;
    page.hidden = !self.document; // hide view if no document is set
    [page displayDocument:self.document withPage:pageIndex];
    
    page.backgroundColor = [UIColor colorWithRed:246/255.0f green:246/255.0f blue:246/255.0f alpha:1];
}

// preloads next document thumbnail
- (void)preloadNextThumbnails {
    PSPDFDocument *document = self.document;
    NSUInteger page = self.page;
    
    if (document) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // cache next page's thumbnail
            if (page+1 < [document pageCount]) {
                PSPDFLogVerbose(@"Preloading thumbnails for page %lu", (unsigned long)page+1);
                [[PSPDFCache sharedPSPDFCache] cachedImageForDocument:document page:page+1 size:PSPDFSizeThumbnail];
            }
            
            // start/update caching document
            [[PSPDFCache sharedPSPDFCache] cacheDocument:document startAtPage:page size:PSPDFSizeNative];
        });
        
        // fill document data cache in background (once)
        if (!documentRectCacheLoaded_) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [document fillCache];
            });
            documentRectCacheLoaded_ = YES;
        }
    }
}

- (NSUInteger)page {
    NSUInteger page = [self actualPage:self.realPage];
    return page;
}

- (void)updateNavBarTitleIfAllowed {
    // only set title if we're allowed to make toolbar modifications, and only on iPad due to lack of space on iPhone
    if (PSIsIpad() && self.isToolbarEnabled) {
        self.navigationItem.title = self.document.title;
    }
}

- (void)setRealPage:(NSUInteger)realPage {
    if (realPage != realPage_ || self.lastPage == NSNotFound) {
        realPage_ = realPage;
        
        [self updateNavBarTitleIfAllowed];
        
        [self delegateDidShowPage:realPage]; // use helper to find PageView
        self.lastPage = realPage;
        
        // preload next thumbnails (so user doesn't see an empty image on scrolling)
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(preloadNextThumbnails) object:nil];
        [self performSelector:@selector(preloadNextThumbnails) withObject:nil afterDelay:PSPDFIsCrappyDevice() ? 2.f : 1.f];
    }
}

- (void)setPage:(NSUInteger)page {
    self.realPage = [self landscapePage:page];
}

- (void)reloadDataAndScrollToPage:(NSUInteger)page {
    // ignore multiple calls to reloadData
    if (isReloading_ || rotationActive_) {
        return;
    }
    isReloading_ = YES;
    // only update if window is attached
    if ([self isViewLoaded]) {
        realPage_ = 0; // ensure initially we're at page 0 while loading.
        [self createPagingScrollView];
        [self scrollToPage:page animated:NO hideHUD:NO];
        self.pagingScrollView.alpha = self.viewMode == PSPDFViewModeThumbnails ? 0.0 : 1.0;
        [self createToolbar];
        [self.scrobbleBar updateToolbarForced];
        [self updatePositionViewPosition]; // depends on the scrobbleBar
        // don't forget the thumbnails
        [gridView_ reloadData]; // don't use self.gridView, as it's lazy init
        
        // if there's a view state we need to load, execute here.
        if (self.restoreViewStatePending) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self restoreDocumentViewState:self.restoreViewStatePending animated:NO];
            });
        }
    }
    isReloading_ = NO;
}

- (void)reloadData {
    [self reloadDataAndScrollToPage:self.realPage];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Memory

- (void)didReceiveMemoryWarning {    
    [super didReceiveMemoryWarning];    
    PSPDFLog(@"Received memory warning. Relaying to scrollview. Removing recycled pages.");
    
    // release the pdf doc (clears internal cache)
    // this doesn't work if we have string references to the document somewhere else - so beware!
    [self.visiblePages makeObjectsPerformSelector:@selector(didReceiveMemoryWarning)];
    
    // remove all recycled pages
    [self.recycledPages removeAllObjects];

    // clear annotation cache
    [self.annotationCache clearAllObjects];
    
    // clear up the grid view
    if (gridView_ &&  self.viewMode == PSPDFViewModeDocument) {
        PSPDFLog(@"Clearing thumbnail grid.");
        [gridView_ removeFromSuperview];
        gridView_ = nil;
    }
    
    // if we're not visible, destroy all pages
    if (![self isViewLoaded] || !self.view.window) {
        [self destroyVisiblePages];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIScrollViewDelegate

- (void)setScrollingEnabled:(BOOL)scrollingEnabled {
    scrollingEnabled_ = scrollingEnabled;
    self.pagingScrollView.scrollEnabled = scrollingEnabled;
}

- (BOOL)shouldShowControls {
    BOOL atFirstPage = self.realPage == 0;
    BOOL atLastPage = self.realPage >= [self.document pageCount]-1;
    return atFirstPage || atLastPage;
}

//TODO: 第一页跳转别页隐藏控制
- (void)hideControlsIfPageMode {
    if (self.viewMode == PSPDFViewModeDocument){ //&& ![self shouldShowControls]) {
        [self hideControls];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // before willAnimateRotate* is invoked, the system adapts the frame of the scrollView and
    // thus maybe contentOffset is adapted (which would cause automatic tiling, and would destroy the animation)
    // This is happening at the very last page of a document on rotate, so ignore the event here.
    if (rotationActive_ && !rotationAnimationActive_) {
        return;
    }
    
    lastContentOffset_ = scrollView.contentOffset.y;
    
    [self tilePages:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
//    if (self.viewMode == PSPDFViewModeDocument ) {
//        [self hideControls];
//    }
    // invalidate target page (used to get correct page after rotation)
    targetPageAfterRotate_ = 1;
}

// called on finger up if user dragged. decelerate is true if it will continue moving afterwards
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
//    [self hideControlsIfPageMode];
//    
//    if (!decelerate) {
//        if ([self shouldShowControls]) {
//            [self showControls];
//        }
//    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
//    [self hideControlsIfPageMode];
//    if ([self shouldShowControls]) {
//        
//        
//        [self showControls];
//    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self delegateDidEndPageScrollingAnimation:scrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    [self delegateDidEndZooming:scrollView withView:view atScale:scale];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Frame calculations

- (CGRect)frameForPageInScrollView {
    CGRect bounds = self.view.bounds;
    
    if ([self isHorizontalScrolling]) {
        bounds.origin.x -= self.pagePadding;
        bounds.size.width += 2 * self.pagePadding;
    }else {
        bounds.origin.y -= self.pagePadding;
        bounds.size.height += 2 * self.pagePadding;
    }
    return bounds;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)pageIndex {
    CGRect pagingScrollViewFrame = [self frameForPageInScrollView];
    CGRect pageFrame = pagingScrollViewFrame;
    
    if ([self isHorizontalScrolling]) {
        pageFrame.size.width -= (2 * self.pagePadding);
        pageFrame.origin.x = roundf(pagingScrollViewFrame.size.width * pageIndex) + self.pagePadding;
    }else {
        pageFrame.size.height -= (2 * self.pagePadding);
        pageFrame.origin.y = roundf(pagingScrollViewFrame.size.height * pageIndex) + self.pagePadding;
    }
    
    PSPDFLogVerbose(@"frameForPage: %@", NSStringFromCGRect(pageFrame));
    return pageFrame;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFGridViewDataSource

- (NSInteger)numberOfItemsInPSPDFGridView:(PSPDFGridView *)gridView {    
    return [self.document pageCount];
}

- (CGSize)PSPDFGridView:(PSPDFGridView *)gridView sizeForItemsInInterfaceOrientation:(UIInterfaceOrientation)orientation {
    CGSize thumbnailSize = self.thumbnailSize;    
    if (!PSIsIpad()) {
        thumbnailSize = CGSizeMake(floorf(thumbnailSize_.width * iPhoneThumbnailSizeReductionFactor_), floorf(thumbnailSize.height * iPhoneThumbnailSizeReductionFactor_));
    }
    return thumbnailSize;
}

- (PSPDFGridViewCell *)PSPDFGridView:(PSPDFGridView *)gridView cellForItemAtIndex:(NSInteger)cellIndex {
    CGSize size = [self PSPDFGridView:gridView sizeForItemsInInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
    
    PSPDFThumbnailGridViewCell *cell = (PSPDFThumbnailGridViewCell *)[self.gridView dequeueReusableCell];
    if (!cell) {
        cell = [[[self classForClass:[PSPDFThumbnailGridViewCell class]] alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    }

    //TODO cell label
    // configure cell
    cell.document = self.document;
    cell.page = cellIndex;
    cell.siteLabel.text = [NSString stringWithFormat:@"%ld",(long)cellIndex+1];//[self.document pageLabelForPage:cellIndex substituteWithPlainLabel:YES];
    [cell setNeedsLayout]; // update siteLabel
    
    return cell;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFGrid

- (void)PSPDFGridView:(PSPDFGridView *)gridView didTapOnItemAtIndex:(NSInteger)position {
    [self scrollToPage:position animated:NO];
    
    // we need some extra time to lay out the views correctly (sigh... again) WWDC
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0001f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self setViewMode:PSPDFViewModeDocument animated:YES];
    });
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIPopoverController

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popoverController = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - MFMailComposeViewControllerDelegate

// for email sheet on mailto: links
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [[self masterViewController] dismissViewControllerAnimated:YES completion:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFSearchDelegate

- (PSPDFSearchHighlightView *)highlightViewForSearchResult:(PSPDFSearchResult *)searchResult inView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[PSPDFSearchHighlightView class]]) {
            PSPDFSearchHighlightView *highlightView = (PSPDFSearchHighlightView *)subview;
            if ([highlightView.searchResult isEqual:searchResult]) {
                return highlightView;
            }
        }
    }
    return nil;
}

// private helper to iterate over PSPDFSearchHighlightView
- (void)iterateHighlightViewsWithBlock:(void(^)(PSPDFSearchHighlightView *highlightView))block {
    if (self.document.documentSearcher.searchMode == PSPDFSearchAdvancedWithHighlighting) {
        NSArray *visiblePageNumbers = [self visiblePageNumbers];
        for (NSNumber *pageNumber in visiblePageNumbers) {
            PSPDFPageView *pageView = [self pageViewForPage:[pageNumber integerValue]];
            for (UIView *subview in pageView.subviews) {
                if ([subview isKindOfClass:[PSPDFSearchHighlightView class]]) {
                    PSPDFSearchHighlightView *highlightView = (PSPDFSearchHighlightView *)subview;
                    block(highlightView);
                }
            }
        }
    }    
}    

- (void)animateSearchHighlight:(PSPDFSearchResult *)searchResult {
    [self iterateHighlightViewsWithBlock:^(PSPDFSearchHighlightView *highlightView) {
        if (highlightView.searchResult == searchResult) {
            [highlightView popupAnimation];
        }
    }];
}

- (void)clearHighlightedSearchResults {
    [self iterateHighlightViewsWithBlock:^(PSPDFSearchHighlightView *highlightView) {
        [highlightView removeFromSuperview];
    }];
}

// add to the current page!
- (void)addHighlightSearchResults:(NSArray *)searchResults {
    if (self.document.documentSearcher.searchMode == PSPDFSearchAdvancedWithHighlighting) {
        PSPDFPageView *pageView = nil;
        NSArray *visiblePageNumbers = [self visiblePageNumbers];
        for (PSPDFSearchResult *searchResult in searchResults) {
            if (searchResult.selection) {
                NSUInteger page = searchResult.pageIndex;
                if ([visiblePageNumbers containsObject:[NSNumber numberWithInteger:page]]) {
                    if (!pageView || pageView.page != page) {
                        pageView = [self pageViewForPage:page];
                    }
                    
                    // mark text
                    if (pageView) {
                        PSPDFSearchHighlightView *highlight = [self highlightViewForSearchResult:searchResult inView:pageView];
                        if (!highlight) {
                            highlight = [[[self classForClass:[PSPDFSearchHighlightView class]] alloc] initWithSearchResult:searchResult];
                            [pageView insertSubview:highlight aboveSubview:pageView.pdfView]; // respect other views
                            [highlight popupAnimation];
                        }
                    }
                }
            }
        }
    }
}

- (void)willStartSearchForString:(NSString *)searchString isFullSearch:(BOOL)isFullSearch {
    if (isFullSearch) {
        [self clearHighlightedSearchResults];    
    }
}

- (void)didUpdateSearchForString:(NSString *)searchString newSearchResults:(NSArray *)searchResults forPage:(NSUInteger)page {
    [self addHighlightSearchResults:searchResults];
}

- (void)didFinishSearchForString:(NSString *)searchString searchResults:(NSArray *)searchResults isFullSearch:(BOOL)isFullSearch {
}

- (void)didCancelSearchForString:(NSString *)searchString isFullSearch:(BOOL)isFullSearch {
    [self clearHighlightedSearchResults];    
}

@end

// override frame to get a change event
@implementation PSPDFViewControllerView

- (void)setFrame:(CGRect)frame {
    BOOL changed = !CGRectEqualToRect(frame, self.frame);
    [super setFrame:frame];
    
    if (changed && !CGRectIsEmpty(frame)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kPSPDFViewControllerFrameChanged object:self];
    }
}

@end
