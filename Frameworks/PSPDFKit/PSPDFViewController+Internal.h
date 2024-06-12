//
//  PSPDFViewController+Internal.h
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFViewController.h"
#import "PSPDFPageView.h"
#import <Foundation/Foundation.h>

@class PSPDFPageCoordinates, PSPDFAnnotation, PSPDFPageInfo, PSPDFLinkAnnotationView, PSPDFAnnotationCache, PSPDFScrollView;
@protocol PSPDFAnnotationView;

// due to rotation while in full-screen mode, the navigationBar sometimes is messed up by the statusBar height. Send a notification that this is checked and fixed.
extern NSString *kPSPDFFixNavigationBarFrame;

@interface PSPDFViewController (PSPDFInternal)

- (BOOL)delegateShouldScrollToPage:(NSUInteger)page;
- (void)delegateWillDisplayDocument;
- (void)delegateDidDisplayDocument;
- (void)delegateDidShowPageView:(PSPDFPageView *)pageView;
- (void)delegateDidRenderPageView:(PSPDFPageView *)pageView;
- (void)delegateDidChangeViewMode:(PSPDFViewMode)viewMode;
- (BOOL)delegateDidTapOnPageView:(PSPDFPageView *)pageView info:(PSPDFPageInfo *)pageInfo coordinates:(PSPDFPageCoordinates *)pageCoordinates;
- (BOOL)delegateDidTapOnAnnotation:(PSPDFAnnotation *)annotation page:(NSUInteger)page info:(PSPDFPageInfo *)pageInfo coordinates:(PSPDFPageCoordinates *)pageCoordinates;
- (BOOL)delegateShouldDisplayAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView;
- (UIView <PSPDFAnnotationView> *)delegateViewForAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView; // deprecated
- (UIView <PSPDFAnnotationView> *)delegateAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView forAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView;
- (void)delegateWillShowAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView onPageView:(PSPDFPageView *)pageView;
- (void)delegateDidShowAnnotationView:(UIView <PSPDFAnnotationView> *)annotationView onPageView:(PSPDFPageView *)pageView;
- (void)delegateDidEndPageScrollingAnimation:(UIScrollView *)scrollView;
- (void)delegateDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale;

- (void)delegateDidLoadPageView:(PSPDFPageView *)pageView;
- (void)delegateWillUnloadPageView:(PSPDFPageView *)pageView;

- (void)delegateWillShowController:(id)viewController embeddedInController:(id)controller animated:(BOOL)animated;
- (void)delegateDidShowController:(id)viewController embeddedInController:(id)controller animated:(BOOL)animated;

- (Class)classForClass:(Class)originalClass;

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated;

/// causes the annotations to be handled as the receiver sees fit (for example, link annotations are followed).
- (void)handleTouchUpForAnnotationIgnoredByDelegate:(PSPDFLinkAnnotationView *)annotation;

// for PSPDFPageViewController
- (void)setPage:(NSUInteger)page;
- (void)setRealPage:(NSUInteger)page;

// for the scrobble bar
- (BOOL)isTransparentHUD;
- (BOOL)isDarkHUD;

// allow checking rotation, for PSPDFSinglePageViewController
@property(nonatomic, assign, getter=isRotationActive, readonly) BOOL rotationActive;

@property(nonatomic, retain, readonly) PSPDFPageViewController *pageViewController;

// Allows access to the annotation cache
@property(nonatomic, strong, readonly) PSPDFAnnotationCache *annotationCache;

@end

@interface PSPDFPageView (PSPDFPageInternal)
@property(nonatomic, ps_weak) PSPDFViewController *pdfController;
@end
