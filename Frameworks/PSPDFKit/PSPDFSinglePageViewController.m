//
//  PSPDFSinglePageViewController.m
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFSinglePageViewController.h"
#import "PSPDFPageViewController.h"
#import "PSPDFViewController.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFScrollView.h"
#import "PSPDFPageView.h"
#import "PSPDFTilingView.h"
#import "PSPDFDocument.h"
#import <QuartzCore/QuartzCore.h>

// provides write-access to properites, needed in PSPDFPage
@interface PSPDFPageView (PSPDFSinglePageInternal)
@property(nonatomic, assign) NSUInteger page;
@property(nonatomic, strong) PSPDFDocument *document;
@end

@implementation PSPDFSinglePageViewController

@synthesize pdfController = _pdfController;
@synthesize pageView = pageView_;
@synthesize page = page_;
@synthesize useSolidBackground = useSolidBackground_;
@synthesize delegate = delegate_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithPDFController:(PSPDFViewController *)pdfController page:(NSUInteger)page {
    if ((self = [super init])) {
        PSPDFRegisterObject(self);
        _pdfController = pdfController;
        page_ = page;
    }
    return self;
}

- (void)dealloc {
    [delegate_ pspdfSinglePageViewControllerWillDealloc:self];
    PSPDFDeregisterObject(self);
    self.pdfController = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // transparency doesn't work very well here
    if (useSolidBackground_) {
        self.view.backgroundColor = self.pdfController.backgroundColor;
    }
    
    if(kPSPDFKitDebugScrollViews) {
        self.view.backgroundColor = [UIColor purpleColor];
        self.view.alpha = 0.7;
    }
    
    // don't load content if we're on an invalid page
    if (page_ < [_pdfController.document pageCount]) {
        pageView_ = [[[self.pdfController classForClass:[PSPDFPageView class]] alloc] init];
        pageView_.frame = self.view.bounds;
        pageView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        pageView_.shadowEnabled = self.pdfController.isShadowEnabled;
        // pageView needs to be prepared for the delegates
        pageView_.page = page_;
        pageView_.document = _pdfController.document;
        pageView_.pdfController = self.pdfController;
        
        BOOL doublePageModeOnFirstPage = self.pdfController.doublePageModeOnFirstPage;
        BOOL isRightAligned = NO;
        if ([self.pdfController isDualPageMode]) {
            isRightAligned = ![self.pdfController isRightPageInDoublePageMode:page_];
        }
        
        // update shadow depending on position
        __ps_weak PSPDFPageView *weakPageView = pageView_;
        [pageView_ setUpdateShadowBlock:^(PSPDFPageView *pageView) {
            PSPDFPageView *strongPageView = weakPageView;
            CALayer *backgroundLayer = pageView.layer;
            BOOL shouldHideShadow = strongPageView.pdfController.isRotationActive;
            backgroundLayer.shadowOpacity = shouldHideShadow ? 0.f : strongPageView.shadowOpacity;
            CGSize size = pageView.bounds.size; 
            CGFloat moveShadow = -12;
            CGRect bezierRect = CGRectMake(moveShadow, moveShadow, size.width+fabs(moveShadow/2), size.height+fabs(moveShadow/2));
            
            if ([strongPageView.pdfController isDualPageMode]) {
                // don't trunicate shadow if we open the document.
                if (!isRightAligned && (doublePageModeOnFirstPage || pageView.page > 0)) {
                    bezierRect = CGRectMake(0, moveShadow, size.width+fabs(moveShadow/2)+moveShadow, size.height+fabs(moveShadow/2));
                }else {
                    bezierRect = CGRectMake(moveShadow, moveShadow, size.width+fabs(moveShadow/2)+moveShadow, size.height+fabs(moveShadow/2));
                }
            }
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectIntegral(bezierRect)];
            backgroundLayer.shadowPath = path.CGPath;
        }];        
    }else {
        if (page_ != -1 && [_pdfController.document isValid]) {
            PSPDFLogWarning(@"Invalid page %lu for document %@ with pageCount: %lu", (unsigned long)page_, _pdfController.document.title, (unsigned long)[_pdfController.document pageCount]);
        }
    }
    [self layoutPage];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Hack to make CATiledLayer aware of our current zoomLevel.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pageView.scrollView.zoomScale > 1.f) {
            CGFloat origZoomScale = self.pageView.scrollView.zoomScale;
            [self.pageView.scrollView setZoomScale:origZoomScale+0.000001];
            [self.pageView.scrollView setZoomScale:origZoomScale];
        }
    });
}

- (void)layoutPage {
    // stop on invalid pages
    // Note: we can't check for self.parentViewController here, as the UIPageViewController sets this at a later point.
    if (page_ == NSUIntegerMax || page_ >= [_pdfController.document pageCount]) {
        return;
    }

    PSPDFDocument *document = _pdfController.document;
    CGRect pageRect = [document rectBoxForPage:page_];
    
    
    // use superview, as the view is changed to fit the pages
    CGSize boundsSize = _pdfController.view.bounds.size;
    
    // as we "steal" the coordintes from above PSPDFPageViewController, re-calculate our real space
    if ([_pdfController isDualPageMode]) {
        boundsSize = CGSizeMake(boundsSize.width/2, boundsSize.height);
    }
    
    CGFloat scale = PSPDFScaleForSizeWithinSizeWithOptions(pageRect.size, boundsSize, self.pdfController.isZoomingSmallDocumentsEnabled, NO);
    
    pageView_.frame = self.view.bounds;
    // delay initially. faster scrolling, also fixes a bug where video didn't appear on landscape mode.
    BOOL delayAnnotations = self.page != page_ || !pageView_.pdfView.document;
    [pageView_ displayDocument:document page:page_ pageRect:pageRect scale:scale delayPageAnnotations:delayAnnotations pdfController:_pdfController];
    
    // center view and position to the center
    CGSize viewSize = self.view.bounds.size;
    CGFloat leftPos = (viewSize.width - pageView_.frame.size.width)/2;
    
    // for dual page mode, align the pages like a magazine
    if ([self.pdfController isDualPageMode]) {
        BOOL shouldAlignRight = ![self.pdfController isRightPageInDoublePageMode:page_];
        leftPos = shouldAlignRight ? viewSize.width-pageView_.frame.size.width : 0.f;
    }
    pageView_.frame = CGRectIntegral((CGRect){.origin={leftPos, (viewSize.height - pageView_.frame.size.height)/2}, .size=pageView_.frame.size});

    [self.view addSubview:self.pageView];
    PSPDFLogVerbose(@"site %lu frame: %@ pageView:%@", (unsigned long)self.page, NSStringFromCGRect(self.view.frame), NSStringFromCGRect(pageView_.frame));
    
    // send delegate events
    [self.pdfController delegateDidLoadPageView:pageView_];
}

// called when e.g. the view frame changes. Recalculate the pageView frame.
// also called when views get removed, etc.. it's a mess.
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutPage];
}

-(BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setPdfController:(PSPDFViewController *)pdfController {
    if (pdfController != _pdfController) {
        // if the pdfController gets nilled out, we can destroy the page already.
        if (!pdfController) {
            [pageView_ destroyPageAndRemoveFromView:YES callDelegate:YES];
        }
        
        _pdfController = pdfController;
        pageView_.pdfController = pdfController;
    }
}

@end
