//
//  PSPDFSearchHighlightView.m
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "PSPDFPageInfo.h"
#import "PSPDFSearchHighlightView.h"
#import "PSPDFSearchResult.h"
#import "PSPDFDocument.h"
#import "PSPDFTilingView.h"
#import "Selection.h"

// Slightly increase the calculated height to make finding the highlight easier
#define kPSPDFSearchHighlightIncreaseHeight 1

@implementation PSPDFSearchHighlightView

@synthesize searchResult = searchResult_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithSearchResult:(PSPDFSearchResult *)searchResult {
    if ((self = [super initWithFrame:CGRectZero])) {
        searchResult_ = searchResult;
        self.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.5f];
        self.layer.cornerRadius = 4.f;
        self.layer.borderWidth = 2.f;
        self.layer.borderColor = [[UIColor yellowColor] colorWithAlphaComponent:0.8f].CGColor;
        [self setNeedsLayout];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.superview) {
        Selection *selection = searchResult_.selection;
        CGRect highlightRect = CGRectApplyAffineTransform(selection.frame, selection.transform);
        PSPDFPageInfo *pageInfo = [searchResult_.document pageInfoForPage:searchResult_.pageIndex];
        CGRect frame = PSPDFConvertPDFRectToViewRect(highlightRect, pageInfo.pageRect, pageInfo.pageRotation, self.superview.bounds);
                
        // increase size
        frame.origin.y -= kPSPDFSearchHighlightIncreaseHeight;
        frame.size.height += kPSPDFSearchHighlightIncreaseHeight * 2;
        
        self.frame = frame;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)popupAnimation {
    self.transform = CGAffineTransformMakeScale(2, 2);
    [UIView animateWithDuration:0.6f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFAnnotationView

- (void)didChangePageFrame:(CGRect)frame {
    [self setNeedsLayout];
}

@end
