//
//  PSPDFPDFPageView.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFLinkAnnotationView.h"
#import "PSPDFHighlightAnnotationView.h"
#import "PSPDFAnnotationCache.h"
#import <QuartzCore/QuartzCore.h>

@interface PSPDFPageView() {
    NSMutableDictionary *annotationViews_;
    CGPDFDocumentRef pdfDocument_;
    CGPDFPageRef pdfPage_;
}

@property(nonatomic, assign)  NSUInteger page;
@property(nonatomic, strong)  PSPDFDocument *document;
@property(nonatomic, assign)  CGFloat pdfScale;
@property(nonatomic, strong)  PSPDFTilingView *pdfView;
@property(nonatomic, strong)  UIImageView *backgroundImageView;
@property(nonatomic, ps_weak) PSPDFViewController *pdfController;

/// if page is no longer used, mark it as destroyed. (even if blocks hold onto it)
@property(nonatomic, getter=isDestroyed) BOOL destroyed;
@end

@implementation PSPDFPageView

@synthesize page = page_;
@synthesize document = document_;
@synthesize backgroundImageView = backgroundImageView_;
@synthesize pdfView = pdfView_;
@synthesize pdfScale = pdfScale_;
@synthesize destroyed = destroyed_;
@synthesize shadowEnabled = shadowEnabled_;
@synthesize updateShadowBlock = updateShadowBlock_;
@synthesize shadowOpacity = shadowOpacity_;
@synthesize pdfController = _pdfController;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - private

dispatch_queue_t pspdf_get_image_background_queue(void);
dispatch_queue_t pspdf_get_image_background_queue(void) {
	static dispatch_once_t once;
	static dispatch_queue_t image_loader_queue;
	dispatch_once(&once, ^{
		image_loader_queue = dispatch_queue_create("com.petersteinberger.pspdfkit.imageloader", NULL);
	});
	return image_loader_queue;
}

- (void)startCachingDocument {
    // cache page, make it an async call
    PSPDFDocument *aDocument = self.document;
    if (aDocument) {
        [[PSPDFCache sharedPSPDFCache] cacheDocument:aDocument startAtPage:self.page size:PSPDFSizeNative];
    }
}

// load page annotations from the pdf.
- (void)loadPageAnnotationsAnimated:(BOOL)animated {
    if (!self.document || destroyed_) {
        return; // document removed? don't try to load annotations!
    }
    
    // ensure annotations are already loaded; else load then in a background thread
    // If we don't check for annotationParser, this could result in an endless loop!
    if (self.document.annotationParser && ![self.document.annotationParser hasLoadedAnnotationsForPage:self.page]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.document.annotationParser annotationsForPage:self.page filter:0];
            // always call back to main queue, so we don't get released on a background thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadPageAnnotationsAnimated:YES];
            });
        });
        return;
    }
    PSPDFLogVerbose(@"Adding annotations for page: %lu", (unsigned long)self.page);
    NSArray *annotations = [self.document.annotationParser annotationsForPage:self.page filter:PSPDFAnnotationFilterOverlay | PSPDFAnnotationFilterLink];
    PSPDFLogVerbose(@"dispaying annotations: %@", annotations);
    
    PSPDFViewController *pdfController = self.pdfController;
    for (PSPDFAnnotation *annotation in annotations) {
        
        // if we are rotation in pageCurl we must apply a special hack,
        // as the pageCurl control is buggy and needs to be re-initialized after rotation is finished
        // so save some work here, and don't mess up MPMoviePlayerController who doesn't like fast changes.
        BOOL isRotatingWithPageCurlMode = pdfController.isPageCurlEnabled && pdfController.isRotationActive;
        if (isRotatingWithPageCurlMode && annotation.type == PSPDFAnnotationTypeVideo) {
            continue;
        }

        BOOL shouldDisplay = [pdfController delegateShouldDisplayAnnotation:annotation onPageView:self];
        if(shouldDisplay) {
            CGRect annotationRect = [annotation rectForPageRect:self.bounds];
            
            // sanity check - rect can't be larger than the page.
            annotationRect = CGRectMake(fmaxf(annotationRect.origin.x, 0), fmaxf(annotationRect.origin.y, 0),
                                        fminf(annotationRect.size.width, self.bounds.size.width), fminf(annotationRect.size.height, self.bounds.size.height));
            
            PSPDFLogVerbose(@"anntation rect %@ (bounds: %@)", NSStringFromCGRect(annotationRect), NSStringFromCGRect(self.bounds));
            
            // check if the annotation is already created
            UIView <PSPDFAnnotationView> *annotationView = [annotationViews_ objectForKey:[NSNumber numberWithInteger:[annotation hash]]];
            if (annotationView) {
                annotationView.frame = annotationRect;
            }else {
                
                // loop up of we already have the annotation in cache
                annotationView = [self.pdfController.annotationCache dequeueViewFromCacheForAnnotation:annotation];
                
                if (!annotationView) {
                    // create annotation using document's annotationParser
                    annotationView = [self.document.annotationParser createAnnotationViewForAnnotation:annotation frame:annotationRect];
                }else {
                    annotationView.frame = annotationRect;
                    annotationView.annotation = annotation;
                }
                
                // add support for deprecated delegate
                if (annotation.type == PSPDFAnnotationTypeCustom) {
                    annotationView = [pdfController delegateViewForAnnotation:annotation onPageView:self];
                    annotationView.frame = annotationRect;
                }
                
                // call delegate with created annotation, let user modify/return a new one
                annotationView = [pdfController delegateAnnotationView:annotationView forAnnotation:annotation onPageView:self];
                
                if (annotationView) {
                    [annotationViews_ setObject:annotationView forKey:[NSNumber numberWithInteger:[annotation hash]]];
                    [pdfController delegateWillShowAnnotationView:annotationView onPageView:self];
                    
                    [self insertSubview:annotationView aboveSubview:pdfView_];
                    
                    // smooth annotation animation
                    CGFloat animationDuration = self.pdfController.annotationAnimationDuration;
                    if (animated && animationDuration > 0.01f) {
                        annotationView.alpha = 0.f;
                        [UIView animateWithDuration:animationDuration delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
                            annotationView.alpha = 1.f;
                        } completion:^(BOOL finished) {
                            [pdfController delegateDidShowAnnotationView:annotationView onPageView:self];
                        }];
                    }else {
                        // don't animate, call delegate directly
                        [pdfController delegateDidShowAnnotationView:annotationView onPageView:self];
                    }
                }
            }
            
            // call up delegate
            if ([annotationView respondsToSelector:@selector(didShowPage:)]) {
                [(id<PSPDFAnnotationView>)annotationView didShowPage:self.page];
            }
        }
    }
}

// shorthand for performSelector
- (void)loadPageAnnotationsWithAnimation {
    [self loadPageAnnotationsAnimated:YES];
}

// iterate over all subviews and return the annotation views.
// we're not using annotationViews_ here to allow custom subview manipulation.
- (NSArray *)visibleAnnotationViews {
    NSMutableArray *annotationViews = [NSMutableArray arrayWithCapacity:[self.subviews count]];
    // iterates over all subviews that conform to PSPDFAnnotationView
    for (UIView *subview in self.subviews) {
        if ([subview conformsToProtocol:@protocol(PSPDFAnnotationView)]) {
            [annotationViews addObject:subview];
        }
    }
    return annotationViews;
}

- (void)callAnnotationVisibleDelegateToShow:(BOOL)show {
    // update show/hide info on all loaded annotations
    NSArray *annotationViews = [self visibleAnnotationViews];
    [annotationViews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (!show) {
            // call up delegate
            if ([obj respondsToSelector:@selector(didHidePage:)]) {
                [(id<PSPDFAnnotationView>)obj didHidePage:self.page];
            }
        }else {
            // call up delegate
            if ([obj respondsToSelector:@selector(didShowPage:)]) {
                [(id<PSPDFAnnotationView>)obj didShowPage:self.page];
            }
        }
    }];
}

- (void)recycleAnnotationViews {
    // recycle annotation views (only those we created ourselves)
    [[annotationViews_ allValues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        // send the hide page call
        if ([obj respondsToSelector:@selector(didHidePage:)]) {
            [obj didHidePage:self.page];
        }
        
        // enqueue in cache
        [self.pdfController.annotationCache recycleAnnotationView:obj];
    }];
    [annotationViews_ removeAllObjects];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        NSAssert([NSThread isMainThread], @"Must run on main thread (init PSPDFPageView)");
        PSPDFRegisterObject(self);
        
        // cache for annotation objects
        annotationViews_ = [[NSMutableDictionary alloc] init];
        
        // make transparent
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        shadowOpacity_ = 0.7f;
        
        // setup background image view
        backgroundImageView_ = [[UIImageView alloc] initWithImage:nil];
        backgroundImageView_.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        backgroundImageView_.opaque = YES;
        [self addSubview:backgroundImageView_];
        
        // create pdf view (foreground)
        pdfView_ = [[PSPDFTilingView alloc] initWithFrame:CGRectZero];
        pdfView_.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        pdfView_.pageView = self;
        if (kPSPDFKitDebugScrollViews) {
            pdfView_.alpha = 0.5f;
        }
        [self addSubview:pdfView_];
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
    [self recycleAnnotationViews];
    pdfView_.pageView = nil;
    _pdfController = nil;
    if (!destroyed_) {
        // remove delegate, and wait for threads to finish drawing.
        // we *might* be not in main, so don't perform any UIKit modifications
        ((CATiledLayer *)[self.pdfView layer]).delegate = nil;
        ((CATiledLayer *)[self.pdfView layer]).contents = nil;    
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startCachingDocument) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadPageAnnotationsWithAnimation) object:nil];    
}

- (NSString *)description {
    NSString *defaultDescription = [super description]; // UIView's default description
    NSString *description = [NSString stringWithFormat:@"%@ (page: %lu, document: %@)", defaultDescription, (unsigned long)self.page, self.document];
    return description;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setShadowOpacity:(float)shadowOpacity {
    shadowOpacity_ = shadowOpacity;
    [self setNeedsLayout]; // rebuild shadow
}

// dynamically search for scrollView
- (PSPDFScrollView *)scrollView {
    // view hierarchy might not be loaded yet, so make a direct call.
    // if we're not in pageCurl mode, each PSPDFPageView has its own scrollView.
    if (self.pdfController.pageCurlEnabled) {
        return (PSPDFScrollView *)self.pdfController.pagingScrollView;
    }
    
    PSPDFScrollView *scrollView = (PSPDFScrollView *)self.superview;
    while (scrollView && ![scrollView isKindOfClass:[PSPDFScrollView class]]) {
        scrollView = (PSPDFScrollView *)scrollView.superview;
    }
    return scrollView;
}

- (void)displayDocument:(PSPDFDocument *)document page:(NSUInteger)page pageRect:(CGRect)pageRect scale:(CGFloat)scale delayPageAnnotations:(BOOL)delayPageAnnotations pdfController:(PSPDFViewController *)pdfController {
    self.document = document;
    self.page = page;
    self.pdfScale = scale;
    self.backgroundImageView.backgroundColor = [document backgroundColorForPage:page];
    self.pdfView.fitWidth = pdfController.fitWidth;
    self.pdfController = pdfController;
    
    // prevents NaN-crashes
    if (pageRect.size.width < 10 || pageRect.size.height < 10) {
        if ([document pageCount]) {
            PSPDFLogWarning(@"Invalid page rect given: %@ (stopping rendering here)", NSStringFromCGRect(pageRect));
        }
        return;
    }
    
    pageRect.size = PSPDFSizeForScale(pageRect.size, scale);
    
    // configure CATiledLayer
    self.frame = pageRect;
    self.pdfView.document = document;
    self.pdfView.page = page;
    
    // if full-size pageimage is in memory, use it -> insta-sharp!
    UIImage *backgroundImage = [[PSPDFCache sharedPSPDFCache] imageForDocument:document page:page size:PSPDFSizeNative];
    
    // call delegate if pdfController is not nil
    if (backgroundImage && self.backgroundImageView.image != backgroundImage) {
        [self.pdfController delegateDidRenderPageView:self];
    }
    
    // fallback to thumbnail image, if it's on memory or on disk
    if (!backgroundImage) {
        
        // Experimental support for non-mainthread loading of background thumbs,
        // to remove even more load from the main thread. (but may flashes images)
        if (self.pdfController.loadThumbnailsOnMainThread) {
            // this may block the main thread for a but, but we don't wanna flash-in the thumbnail as soon as its there.
            backgroundImage = [[PSPDFCache sharedPSPDFCache] cachedImageForDocument:document page:page size:PSPDFSizeThumbnail];
        }else {
            backgroundImage = [[PSPDFCache sharedPSPDFCache] imageForDocument:document page:page size:PSPDFSizeThumbnail];
            
            if (!backgroundImage) { 
                // decompresses image in background
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    UIImage *cachedImage = nil;
                    if(self.window && !self.destroyed) {
                        cachedImage = [[PSPDFCache sharedPSPDFCache] cachedImageForDocument:document page:page size:PSPDFSizeThumbnail preload:YES];
                    }
                    // *always* call back main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // only update image if the big image is not yet loaded
                        if (cachedImage && self.window && !self.destroyed && (!self.backgroundImageView.image || self.backgroundImageView.image.size.width < cachedImage.size.width)) {
                            [self setBackgroundImage:cachedImage animated:YES];
                        }
                    });
                });
            }
        }
    }else {
        PSPDFLogVerbose(@"Full page cache hit for %lu", (unsigned long)page);
    }
    
    [self setBackgroundImage:backgroundImage animated:NO];
    
    // start caching document after two seconds
    [self performSelector:@selector(startCachingDocument) withObject:nil afterDelay:2.0];
    
    // add delay for annotation loading; improve scrolling speed (but reload instantly if already there)
    if ([annotationViews_ count] > 0 || !delayPageAnnotations) {
        [self loadPageAnnotationsAnimated:NO];
    }else {
        [self performSelector:@selector(loadPageAnnotationsWithAnimation) withObject:nil afterDelay:kPSPDFInitialAnnotationLoadDelay];
    }
}

- (void)setBackgroundImage:(UIImage *)image animated:(BOOL)animated {
    if (self.backgroundImageView.image != image) {
        if (animated && kPSPDFKitPDFAnimationDuration > 0.f) {
            CATransition *transition = [CATransition animation];
            transition.duration = kPSPDFKitPDFAnimationDuration;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            transition.type = kCATransitionFade;
            [self.backgroundImageView.layer addAnimation:transition forKey:@"image"];
        }
        
        self.backgroundImageView.image = image;
    }
    self.backgroundImageView.backgroundColor = image ? [UIColor clearColor] : [self.document backgroundColorForPage:self.page];
    
    //CGRect rectInWindow = [self.backgroundImageView convertRect:self.backgroundImageView.frame toView:self.backgroundImageView.window];
    
    // if image is readonably close to target size, don't scale it (fixes blurry text)
    /*
     BOOL isFullSize = NO;    
     if (image) {
     int widthDiff = abs(self.backgroundImageView.frame.size.width - image.size.width);
     int heightDiff = abs(self.backgroundImageView.frame.size.height - image.size.height);        
     isFullSize = widthDiff < 2 && heightDiff < 2;
     }*/
    
    //if(isFullSize) {
    //    backgroundImageView_.contentMode = UIViewContentModeTopLeft; // doesn't stretch image
    //}else {
    backgroundImageView_.contentMode = UIViewContentModeScaleToFill;
    //}
}

- (void)destroyPageAndRemoveFromView:(BOOL)removeFromView callDelegate:(BOOL)callDelegate {
    if (self.isDestroyed) {
        return;
    }
    
    // always recycle views
    [self recycleAnnotationViews];
    
    // try calling delegate
    // TODO: move this somewhere else?
    // TODO: ARC-RELATED bug. If this is called within pdfController dealloc, we get an weird over-release
    if (callDelegate && self.document) {
        if (![NSThread isMainThread]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.pdfController delegateWillUnloadPageView:self];
            });
        }else {
            [self.pdfController delegateWillUnloadPageView:self];
        }
    }
    
    self.destroyed = YES;
    if (removeFromView) {
        NSAssert([NSThread isMainThread], @"Must run on main thread");
        [self.pdfView stopTiledRenderingAndRemoveFromSuperlayer];
        [self removeFromSuperview];        
    }
}

// needs to be called while view is still visible, and only in main
- (void)setDestroyed:(BOOL)destroyed {
    if (destroyed_ != destroyed) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startCachingDocument) object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadPageAnnotationsWithAnimation) object:nil];
        destroyed_ = destroyed;
    }
}

- (void)setHidden:(BOOL)hidden {
    if (hidden != self.hidden) {
        [super setHidden:hidden];
        [self callAnnotationVisibleDelegateToShow:!hidden];
    }    
}

// detects when the controller/view goes offscreen - pause videos etc
- (void)willMoveToWindow:(UIWindow *)newWindow {
    PSPDFLogVerbose(@"new window for page: %@", newWindow);
    // inform annotations
    if(self.document) {
        [self callAnnotationVisibleDelegateToShow:newWindow != nil];
    }
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    // inform annotations that the parent size has changed
    [[self visibleAnnotationViews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj respondsToSelector:@selector(didChangePageFrame:)]) {
            [obj didChangePageFrame:self.frame];
        }
    }];
}

- (void)updateShadow {
    if (self.isShadowEnabled) {
        // TODO: make one library for shadow services (see PSPDFScrollView)
        CALayer *backgroundLayer = self.layer;
        backgroundLayer.shadowColor = [UIColor blackColor].CGColor;
        backgroundLayer.shadowOffset = PSIsIpad() ? CGSizeMake(10.0f, 10.0f) : CGSizeMake(8.0f, 8.0f); 
        backgroundLayer.shadowRadius = 4.0f;
        backgroundLayer.masksToBounds = NO;
        CGSize size = self.bounds.size; 
        CGFloat moveShadow = -12;
        UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(moveShadow, moveShadow, size.width+fabs(moveShadow/2), size.height+fabs(moveShadow/2))];
        backgroundLayer.shadowOpacity = shadowOpacity_;
        backgroundLayer.shadowPath = path.CGPath;
        
        if (updateShadowBlock_) {
            updateShadowBlock_(self);
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateShadow];
}

- (CGPoint)convertViewPointToPDFPoint:(CGPoint)viewPoint {
    return PSPDFConvertViewPointToPDFPoint(viewPoint, [self.document rectBoxForPage:page_], [self.document rotationForPage:page_], self.bounds);
}

- (CGPoint)convertPDFPointToViewPoint:(CGPoint)pdfPoint {
    return PSPDFConvertPDFPointToViewPoint(pdfPoint, [self.document rectBoxForPage:page_], [self.document rotationForPage:page_], self.bounds);
}

@end
