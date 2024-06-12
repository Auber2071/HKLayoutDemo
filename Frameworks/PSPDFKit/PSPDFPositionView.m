//
//  PSPDFPositionView.m
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFViewController.h"
#import "PSPDFPositionView.h"
#import "PSPDFDocument.h"
#import <QuartzCore/QuartzCore.h>

@implementation PSPDFPositionView

@synthesize label = label_;
@synthesize labelMargin = labelMargin_;
@synthesize pdfController = _pdfController;

static void *kPSPDFKVOToken;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)updateAnimated:(BOOL)animated {
    CGFloat targetAlpha = self.pdfController.viewMode == PSPDFViewModeDocument ? 1.f : 0.f;
    if (!_pdfController.document || _pdfController.document.pageCount == 0) {
        targetAlpha = 0.f;
    }

    if (self.alpha != targetAlpha || [label_.text length] == 0) {
        [UIView animateWithDuration:animated ? 0.25f : 0.f delay:0.f options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.alpha = targetAlpha;
        } completion:nil];
    }

    NSString *text = @"";
    if (_pdfController.document.isValid) {
        //TODO 把竖屏页数改为第0页开始
        //pdfController_.realPage 为第0页开始   pdfController_.realPage＋1 为第一页
        //取消pdf自带页码 例如罗马数字，改为统一阿拉伯数字
        //NSString *pageLabel = [pdfController_.document pageLabelForPage:pdfController_.realPage substituteWithPlainLabel:NO];
        // if (!pageLabel) {
        text = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)_pdfController.realPage +1, (unsigned long)_pdfController.document.pageCount];
        //        }else {
        //            text = [NSString stringWithFormat:@"%d of %d)", pageLabel, pdfController_.realPage, pdfController_.document.pageCount];
        //        }
    }
    
//    if (_pdfController.document.isValid) {
//        NSString *pageLabel = [_pdfController.document pageLabelForPage:_pdfController.realPage substituteWithPlainLabel:NO];
//        if (!pageLabel) {
//            text = [NSString stringWithFormat:PSPDFLocalize(@"%d of %d"), _pdfController.realPage+1, _pdfController.document.pageCount];
//        }else {
//            text = [NSString stringWithFormat:PSPDFLocalize(@"%@ (%d of %d)"), pageLabel, _pdfController.realPage+1, _pdfController.document.pageCount];
//        }
//    }
    label_.text = text;

    [self setNeedsLayout]; // recalculate outer frame
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        self.userInteractionEnabled = NO;
        labelMargin_ = 2;
        self.layer.cornerRadius = 3.f;
        self.backgroundColor = [UIColor colorWithWhite:0.4f alpha:0.7f];
        self.opaque = NO;
        label_ = [[UILabel alloc] init];
        label_.backgroundColor = [UIColor clearColor];
        label_.font = [UIFont boldSystemFontOfSize:14.f];
        label_.textColor = [UIColor whiteColor];
        label_.shadowColor = [UIColor blackColor];
        label_.shadowOffset = CGSizeMake(0, 1);
        [self addSubview:label_];
    }
    return self;
}

- (void)dealloc {
    self.pdfController = nil; // removes KVO
}

- (NSArray *)kvoValues {
    return [NSArray arrayWithObjects:NSStringFromSelector(@selector(document)), NSStringFromSelector(@selector(realPage)), NSStringFromSelector(@selector(viewMode)), @"viewModeAnimated", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &kPSPDFKVOToken) {
        BOOL animated = [keyPath isEqualToString:@"viewModeAnimated"];
        [self updateAnimated:animated];
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setPdfController:(PSPDFViewController *)pdfController {
    if(pdfController != _pdfController) {
        PSPDFViewController *oldController = _pdfController;
        _pdfController = pdfController;
        [[self kvoValues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [oldController removeObserver:self forKeyPath:obj];
            [pdfController addObserver:self forKeyPath:obj options:idx == 0 ? NSKeyValueObservingOptionInitial : 0 context:&kPSPDFKVOToken];
        }];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    [label_ sizeToFit];
    label_.frame = CGRectMake(labelMargin_*4, labelMargin_, label_.frame.size.width, label_.frame.size.height);
    CGRect bounds = CGRectMake(0, 0, label_.frame.size.width+labelMargin_*8, label_.frame.size.height+labelMargin_*2);
    self.bounds = bounds;
    self.frame = CGRectIntegral(self.frame); // don't subpixel align centered item!
}

@end
