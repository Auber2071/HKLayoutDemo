//
//  PSPDFPageViewController.m
//  PSPDFKit
//
//  Created by Peter Steinberger on 10/17/11.
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFPageViewController.h"
#import "PSPDFViewController.h"
#import "PSPDFDocument.h"
#import "PSPDFSinglePageViewController.h"
#import "PSPDFPageView.h"
#import "PSPDFTilingView.h"
#import "PSPDFAnnotationView.h"
#import "PSPDFPagedScrollView.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFVideoAnnotationView.h"
#import <objc/runtime.h>
#import "PSPDFPatches.h"

@interface PSPDFPageViewController () <PSPDFSinglePageViewControllerDelegate> {
    CGRect pageRect_;
    NSMutableSet *singlePages_; // non-retaining set to keep track of single pages.
}

@property(nonatomic, assign) BOOL isAnimatingProgrammaticPageChange;
@end

@implementation PSPDFPageViewController

@synthesize isAnimatingProgrammaticPageChange = isAnimatingProgrammaticPageChange_;
@synthesize clipToPageBoundaries = clipToPageBoundaries_;
@synthesize useSolidBackground = useSolidBackground_;
@synthesize pdfController = _pdfController;
@synthesize scrollView = scrollView_;
@synthesize page = page_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - private

// returns the singlePageController, looks if it may already be created
- (PSPDFSinglePageViewController *)singlePageControllerForPage:(NSUInteger)page {
    PSPDFSinglePageViewController *singlePage = nil;
    
    for (PSPDFSinglePageViewController *currentSinglePage in self.viewControllers) {
        if (currentSinglePage.page == page) {
            singlePage = currentSinglePage; break;
        }
    }
    
    if (!singlePage) {
        singlePage = [[PSPDFSinglePageViewController alloc] initWithPDFController:self.pdfController page:page];
        singlePage.delegate = self;
        [singlePages_ addObject:singlePage];
    }
    
    singlePage.useSolidBackground = useSolidBackground_;
    return singlePage;
}

// helper to correctly pre-setup view controllers
- (void)setupViewControllersDoubleSided:(BOOL)doubleSided animated:(BOOL)animated direction:(UIPageViewControllerNavigationDirection)direction splineLocation:(UIPageViewControllerSpineLocation)splineLocation {
    PSPDFLogVerbose(@"setupViewControllersDoubleSided:%d animated:%d direction:%ld", doubleSided, animated, (long)direction);
    NSMutableArray *viewControllers = [NSMutableArray arrayWithObject:[self singlePageControllerForPage:self.page]];
    if (doubleSided) {
        [viewControllers addObject:[self singlePageControllerForPage:self.page+1]];
    }
    
    // perform sanity check if something changed at all
    BOOL changed = ![viewControllers isEqualToArray:self.viewControllers];
    if (changed) {
        isAnimatingProgrammaticPageChange_ = YES;
        __ps_weak PSPDFPageViewController *weakSelf = self;
        
        // Doesn't always call completion handler (track with ivar) [bug still in iOS6B1]
        [self setViewControllers:viewControllers direction:direction animated:animated completion:^(BOOL finished) {
            PSPDFPageViewController *strongSelf = weakSelf;
            
            // updateViewSizeIfNeeded interferes with the pageCurl animation;
            // don't update size if we're not finished animating.
            strongSelf.isAnimatingProgrammaticPageChange = NO;
            
            if (finished) {
                // call the delegate if finished (only if call was animated)
                if (animated) {
                    [strongSelf.pdfController delegateDidEndPageScrollingAnimation:strongSelf.scrollView];
                }
                
                // don't forget to update the view size
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf updateViewSizeIfNeeded];
                });
            }
        }];
    }
    // ensure that this is YES if spline location is set to mid.
    if (splineLocation == UIPageViewControllerSpineLocationMid) {
        doubleSided = YES;
    }
    self.doubleSided = doubleSided;
}

- (NSUInteger)fixPageNumberForDoublePageMode:(NSUInteger)page forceDualPageMode:(BOOL)forceDualPageMode {
    // ensure that we've not set the wrong page for double page mode
    NSUInteger correctedPage = page;
    if (([self.pdfController isDualPageMode] || forceDualPageMode) && [self.pdfController isRightPageInDoublePageMode:correctedPage]) {
        correctedPage--;
    }
    return correctedPage;
}

// adapt the frame so that the page doesn't "bleed out".
- (void)updateViewSize {
    // cancel if we're zoomed in
    if (self.scrollView.zoomScale != 1.f) {
        return;
    }
    
    // size starts with zero, but we loop through multiple controllers
    CGSize size = CGSizeZero;
    
    if (clipToPageBoundaries_) {
        BOOL hasTwoPages = [self.viewControllers count] > 1;
        
        for (PSPDFSinglePageViewController *pageController in self.viewControllers) {
            PSPDFSinglePageViewController *currentPageController = pageController;
            
            // if we're at first/last page and in two page mode, just copy the size of the other page
            if (currentPageController.page == NSUIntegerMax || currentPageController.page >= [[_pdfController document] pageCount]) {
                if ([self.viewControllers indexOfObject:pageController] == 0) {
                    currentPageController = (PSPDFSinglePageViewController *)[self.viewControllers lastObject];
                }else {
                    currentPageController = (PSPDFSinglePageViewController *)[self.viewControllers objectAtIndex:0];
                }
            }
            
            // pageView's frame isn't reliable at this stage. calculate manually.
            CGRect availableRect = self.pdfController.view.bounds;
            if (hasTwoPages) {
                availableRect.size.width = floorf(availableRect.size.width/2);
            }
            
            CGRect pageRect = [currentPageController.pageView.document rectBoxForPage:currentPageController.pageView.page];
            CGFloat pageScale = PSPDFScaleForSizeWithinSizeWithOptions(pageRect.size, availableRect.size, _pdfController.isZoomingSmallDocumentsEnabled, _pdfController.isFittingWidth && !_pdfController.pageCurlEnabled);
            CGSize pageViewSize = PSPDFSizeForScale(pageRect.size, pageScale);
            
            // we may need to wait for viewWillLayoutSubviews to re-set the pageView frame after a rotation 
            // this can happen because pageView_ auto-resizes and may set height to zero,
            // and due to a timing issue on updateViewSize we mess up our view size if we don't break here.
            if ((pageViewSize.width == 0 || pageViewSize.height == 0) && pageViewSize.width + pageViewSize.height > 0) {
                return;
            }
            
            size = CGSizeMake(size.width + pageViewSize.width, MAX(size.height, pageViewSize.height)); 
        }
    }else {
        size = self.view.bounds.size;
    }
    
    // the system automatically centers the view for us - no need to do extra work!
    CGRect newFrame = CGRectMake(0, 0, size.width, size.height);
    PSPDFLogVerbose(@"old frame: %@ ---- new frame: %@", NSStringFromCGRect(self.view.frame), NSStringFromCGRect(newFrame));
    self.view.frame = newFrame;
    [self.view.superview setNeedsLayout];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

// allows RTL page curling support
- (UIPageViewControllerSpineLocation)splineLocationForPdfController:(PSPDFViewController *)pdfController {
    return pdfController.isPageCurlDirectionLeftToRight ? UIPageViewControllerSpineLocationMax : UIPageViewControllerSpineLocationMin;
}

- (id)initWithPDFController:(PSPDFViewController *)pdfController {
    BOOL isDoublePaged = [pdfController isDualPageMode];
    UIPageViewControllerSpineLocation splineLocation = isDoublePaged ? UIPageViewControllerSpineLocationMid : [self splineLocationForPdfController:pdfController];
    
    NSDictionary *optionDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:splineLocation] forKey:@"UIPageViewControllerOptionSpineLocationKey"];
    // don't use UIPageViewControllerOptionSpineLocationKey to be compatible with iOS4 w/o weak-linking UIKit
    
    if (self = [super initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:optionDict]) {
        PSPDFRegisterObject(self);
        clipToPageBoundaries_ = pdfController.clipToPageBoundaries;
        _pdfController = pdfController;
        page_ = pdfController.page;
        singlePages_ = (__bridge_transfer NSMutableSet *)CFSetCreateMutable(nil, 0, nil);
        pageRect_ = CGRectZero;
        self.delegate = self;
        self.dataSource = self;
        [self setupPageViewControllersDualPaged:isDoublePaged splineLocation:splineLocation];
    }
    
    // register for pageCurl events, to send events to annotations
    for (UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers) {
        [gestureRecognizer addTarget:self action:@selector(handleGesture:)];
    }
    
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
    self.pdfController = nil;
    self.delegate = nil;
    self.dataSource = nil;
    [singlePages_ makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

// later becomes - (BOOL)pspdf_customPointInside:(CGPoint)point withEvent:(UIEvent *)event on _UIPageViewControllerContentView.
BOOL pspdf_customPointInside(id this, SEL this_cmd, CGPoint point, UIEvent *event);
BOOL pspdf_customPointInside(id this, SEL this_cmd, CGPoint point, UIEvent *event) {
    CGPoint tranlatedPoint = [this convertPoint:point toView:[this superview]];
    BOOL isPointInSuperView = [[this superview] pointInside:tranlatedPoint withEvent:event];
    return isPointInSuperView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // hack into _UIPageViewControllerContentView to allow gestures to fire even if not in the view. All w/o private API!
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class pageCurlViewClass = [self.view class]; // _UIPageViewControllerContentView
        if (pageCurlViewClass) {
            SEL customPointInside = NSSelectorFromString(@"pspdf_customPointInside:withEvent:");
            const char *typeEncoding = method_getTypeEncoding(class_getInstanceMethod([UIView class], @selector(pointInside:withEvent:)));
            class_addMethod(pageCurlViewClass, customPointInside, (IMP)pspdf_customPointInside, typeEncoding);
            pspdf_swizzle(pageCurlViewClass, @selector(pointInside:withEvent:), customPointInside);
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // initially force layouting to set correct size of the view.
    [self updateViewSizeIfNeeded];
}

// iPhone orientation is limited by PSPDFViewController.
-(BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
    // restore original frame before we animate.
    self.view.frame = self.view.superview.frame;
    
    // remove any MPMoviePlayerControllers, they mess with the rotation animation and get recreated anyway
    for(PSPDFSinglePageViewController *singlePage in self.viewControllers) {
        for (UIView<PSPDFAnnotationView> *annotationView in singlePage.pageView.visibleAnnotationViews) {
            // send the hide page call
            if ([annotationView respondsToSelector:@selector(willHidePage:)]) {
                [annotationView willHidePage:self.page];
            }
        }
    }
    
    // kill all CATiledLayers so they don't redraw while we animate.
    // we will regenerate the whole page anyway so we can optimize rotation here.
    for(PSPDFSinglePageViewController *singlePage in self.viewControllers) {
        [singlePage.pageView.pdfView stopTiledRenderingAndRemoveFromSuperlayer];
    }
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setClipToPageBoundaries:(BOOL)clipToPageBoundaries {
    clipToPageBoundaries_ = clipToPageBoundaries;
    [self updateViewSize];
}

- (void)setPdfController:(PSPDFViewController *)pdfController {
    _pdfController = pdfController;
    [singlePages_ makeObjectsPerformSelector:@selector(setPdfController:) withObject:pdfController];
}

- (void)setPage:(NSUInteger)page {
    [self setPage:page animated:NO];
}

- (void)setPage:(NSUInteger)page animated:(BOOL)animated {
    // ensure that we've not set the wrong page for double page mode
    NSUInteger correctedPage = [self fixPageNumberForDoublePageMode:page forceDualPageMode:NO];
    if (page_ != correctedPage) {
        BOOL forwardAnimation = (NSInteger)correctedPage > (NSInteger)page_ && correctedPage != NSUIntegerMax;
        page_ = correctedPage;
        [self setupViewControllersDoubleSided:[self.pdfController isDualPageMode] animated:animated direction:forwardAnimation ? UIPageViewControllerNavigationDirectionForward : UIPageViewControllerNavigationDirectionReverse splineLocation:self.spineLocation];
    }
}

- (void)updateViewSizeIfNeeded {
    // don't update if the zoomScale is not 1, or if rotation is active.
    // use 2 pixels tolerance to fight against pixel rounding errors.
    if (!isAnimatingProgrammaticPageChange_ && scrollView_.zoomScale == 1.f && !_pdfController.isRotationActive && (fabs(pageRect_.size.width - self.view.bounds.size.width) > 2 || fabs(pageRect_.size.height - self.view.bounds.size.height) > 2)) {
        pageRect_ = self.view.bounds;
        [self updateViewSize];
    }
}

// if we detect a frame change, compensate and re-call updateViewSize
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateViewSizeIfNeeded];
    });
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFSinglePageViewControllerDelegate

- (void)pspdfSinglePageViewControllerWillDealloc:(PSPDFSinglePageViewController *)singlePageViewController {
    [singlePages_ removeObject:singlePageViewController];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    PSPDFSinglePageViewController *previousPageController = (PSPDFSinglePageViewController *)viewController;
    PSPDFLogVerbose(@"viewControllerBeforeViewController:%lu", (unsigned long)previousPageController.page);

    // allow special case for a document open (where the leftPage is empty)
    BOOL allowEmptyFirstPage = _pdfController.isDualPageMode && previousPageController.page == 0 && !_pdfController.doublePageModeOnFirstPage;
    if ((previousPageController.page == 0 || previousPageController.page >= self.pdfController.document.pageCount) && !allowEmptyFirstPage) {
        return nil;
    }
    NSUInteger newPage = previousPageController.page-1;

    // block if scrolling is not enabled
    if (!_pdfController.scrollingEnabled || ![_pdfController delegateShouldScrollToPage:newPage]) {
        return nil;
    }

    // hide UI
    [_pdfController hideControls];
    
    PSPDFSinglePageViewController *singlePageController = [self singlePageControllerForPage:newPage];
    singlePageController.useSolidBackground = useSolidBackground_;
    return singlePageController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    PSPDFSinglePageViewController *nextPageController = (PSPDFSinglePageViewController *)viewController;
    PSPDFLogVerbose(@"viewControllerAfterViewController:%lu", (unsigned long)nextPageController.page);

    BOOL allowEmptyLastPage = _pdfController.isDualPageMode && nextPageController.page == self.pdfController.document.pageCount-1 && ![self.pdfController isRightPageInDoublePageMode:nextPageController.page];
    BOOL allowNegativeIncrement = nextPageController.page == NSUIntegerMax;
    if (nextPageController.page >= self.pdfController.document.pageCount-1 && !allowEmptyLastPage && !allowNegativeIncrement) {
        return nil;
    }
    NSUInteger newPage = nextPageController.page+1;

    // block if scrolling is not enabled
    if (!_pdfController.scrollingEnabled || ![_pdfController delegateShouldScrollToPage:newPage]) {
        return nil;
    }
    
    // hide UI
    [_pdfController hideControls];
    
    PSPDFSinglePageViewController *singlePageController = [self singlePageControllerForPage:newPage];
    singlePageController.useSolidBackground = useSolidBackground_;
    return singlePageController;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIPageViewControllerDelegate

// Sent when a gesture-initiated transition ends. The 'finished' parameter indicates whether the animation finished, while the 'completed' parameter indicates whether the transition completed or bailed out (if the user let go early).
- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed {
    PSPDFLogVerbose(@"finished animating:%d transitionCompleted:%d", finished, completed);
    
    // save new page and apply fixes for Apple's broken UIPageViewController.
    // Note: this is improved in iOS6, but still broken for iOS5/5.1
    if (completed) {
        if ([pageViewController.viewControllers count]) {
            
            // apply new page
            PSPDFSinglePageViewController *singlePageViewController = [pageViewController.viewControllers objectAtIndex:0];
            NSUInteger newPage = singlePageViewController.page;
            page_ = newPage == NSUIntegerMax ? 0 : newPage;
            self.pdfController.realPage = page_;
            
            // check all views and remove any leftover pages / animation stuff (WTF, Apple!?)
            for (UIView *subview in self.view.subviews) {
                BOOL containsPSPDFPageView = [subview.subviews count] == 1 && [[subview.subviews objectAtIndex:0] isKindOfClass:[PSPDFPageView class]];
                
                BOOL removeView = YES;
                if (containsPSPDFPageView) {
                    PSPDFPageView *pageView = [subview.subviews objectAtIndex:0];
                    
                    if (![_pdfController isDualPageMode]) {
                        removeView = pageView.page != page_;
                    }else {
                        // search if one of the controllers matches the page, remove if not.
                        for (PSPDFSinglePageViewController *single in pageViewController.viewControllers) {
                            if(single.page == pageView.page) {
                                removeView = NO; break;
                            }
                        }
                    }                    
                }
                
                if (removeView) {
                    PSPDFLogVerbose(@"Fixed bug in UIPageViewController: remove leftover view %@", subview);
                    [subview removeFromSuperview];
                }
            }
            
            // next, check if there is a leftover controller
            for (UIViewController *childController in self.childViewControllers) {
                BOOL found = NO;
                for (PSPDFSinglePageViewController *singlePage in pageViewController.viewControllers) {
                    if(childController == singlePage) {
                        found = YES; break;
                    }
                }
                
                if (!found) {
                    PSPDFLogVerbose(@"Fixed bug in UIPageViewController: remove leftover controller %@", childController);
                    [childController removeFromParentViewController];
                    
                    // at this point, Apple internally called beginDisablingInterfaceAutorotation
                    // but never calls the corresponding endDisablingInterfaceAutorotation. (BUG!)
                    // (Both of them are, unfortunately, private API.)
                    
                    // So either we bite the Apple and fix it ourselves, or probably wait until iOS6 for
                    // UIPageViewController to be finally stable (And it's rarely used, so it's low priority).
                    
                    // If you're afraid about private API,
                    // set _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_ in your preprocessor defines.
                    
                    // Note however that Apple's checks are extremely limited,
                    // and a simple obfuscation like this usually is no problem at all.
                    // I do have and know several apps in the store that use the same technique.
#ifndef _PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API_
                    pspdf_endDisableIfcAutorotation(nil, nil);
#endif
                }                
            }
        }
    }
    
    // hide UI
    [_pdfController hideControls];
    
    // adapt view size in next runloop (or we get in UIKit-trouble)
    if (finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateViewSize];
        });
    }
}

- (void)setupPageViewControllersDualPaged:(BOOL)isDualPageMode splineLocation:(UIPageViewControllerSpineLocation)splineLocation {
    // Delegate may set new view controllers or update double-sided state within this method's implementation as well.
    if (isDualPageMode) {
        page_ = [self fixPageNumberForDoublePageMode:self.pdfController.realPage forceDualPageMode:YES];
        [self setupViewControllersDoubleSided:YES animated:YES direction:UIPageViewControllerNavigationDirectionForward splineLocation:splineLocation];
    }else {
        page_ = self.pdfController.realPage;
        [self setupViewControllersDoubleSided:NO animated:YES direction:UIPageViewControllerNavigationDirectionForward splineLocation:splineLocation];
    }
}

- (UIPageViewControllerSpineLocation)pageViewController:(UIPageViewController *)pageViewController spineLocationForInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // ensure we have the correct page for dual page mode
    BOOL isDualPageMode = [self.pdfController isDualPageModeForOrientation:orientation];
    UIPageViewControllerSpineLocation spineLocation = [self splineLocationForPdfController:self.pdfController];
    
    if (isDualPageMode) {
        spineLocation = UIPageViewControllerSpineLocationMid;
    }
    [self setupPageViewControllersDualPaged:isDualPageMode splineLocation:spineLocation];
    
    return spineLocation;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIGestureRecognizerDelegate

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateChanged:
            for(PSPDFSinglePageViewController *singlePage in self.viewControllers) {
                for (UIView<PSPDFAnnotationView> *annotationView in singlePage.pageView.visibleAnnotationViews) {
                    if ([annotationView respondsToSelector:@selector(willHidePage:)]) {
                        [annotationView willHidePage:self.page];
                    }
                }
            }
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateEnded:
            for(PSPDFSinglePageViewController *singlePage in self.viewControllers) {
                for (UIView<PSPDFAnnotationView> *annotationView in singlePage.pageView.visibleAnnotationViews) {
                    if ([annotationView respondsToSelector:@selector(willShowPage:)]) {
                        [annotationView willShowPage:self.page];
                    }
                }
            }
        default:
            break;
    }
}

// Undocumented: this class is the gesture recognizer delegate (but pretty obvious).
// Confirmation: https://github.com/steipete/iOS-Runtime-Headers/blob/master/Frameworks/UIKit.framework/UIPageViewController.h
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // disable any paging while we're in zoom mode
    BOOL isNotZoomed = self.scrollView.zoomScale == 1;
    return isNotZoomed;
}

@end
