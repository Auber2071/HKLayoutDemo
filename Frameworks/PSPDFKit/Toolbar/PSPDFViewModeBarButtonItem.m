//
//  PSPDFViewModeBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFViewModeBarButtonItem.h"
#import "PSPDFSegmentedControl.h"
#import "PSPDFIconGenerator.h"
#import "PSPDFViewController+Internal.h"
#import "UIImage+PSPDFKitAdditions.h"

@implementation PSPDFViewModeBarButtonItem

@synthesize viewModeSegment = viewModeSegment_;

- (void)setupModeSegmentView {
    viewModeSegment_ = [[PSPDFSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"", @"", nil]];
    viewModeSegment_.segmentedControlStyle = UISegmentedControlStyleBar;
    [viewModeSegment_ addTarget:self action:@selector(viewModeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.customView = viewModeSegment_;
}

- (void)updateBarButtonItem {
    [super updateBarButtonItem];

    // WWDC: if we don't recreate the segmented contol, it only shows a graphics artefact instead.
    // only shows up with appcelerator; both iPhone and iPad. Gets fixed on iPhone on rotation.
    [self setupModeSegmentView];

    UIImage *pageImage = [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypePage];
    UIImage *thumbImage = [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypeThumbnails];
    if (![self.pdfViewController isDarkHUD] && PSIsIpad()) {
        UIColor *tintColor = [UIColor colorWithRed:106.f/255.f green:113.f/255.f blue:120.f/255.f alpha:1.f];
        pageImage = [pageImage pdpdf_imageTintedWithColor:tintColor fraction:0.f];
        thumbImage = [thumbImage pdpdf_imageTintedWithColor:tintColor fraction:0.f];
    }
    [viewModeSegment_ setImage:pageImage forSegmentAtIndex:0];
    [viewModeSegment_ setImage:thumbImage forSegmentAtIndex:1];
    
    if (![self.pdfViewController isDarkHUD] && PSIsIpad()) {
        UIColor *tintColor = [UIColor colorWithWhite:0.9 alpha:1.f];
        pageImage = [pageImage pdpdf_imageTintedWithColor:tintColor fraction:0.f];
        thumbImage = [thumbImage pdpdf_imageTintedWithColor:tintColor fraction:0.f];
    }
    [(PSPDFSegmentedControl*)viewModeSegment_ setSelectedImage:pageImage forSegmentAtIndex:0];
    [(PSPDFSegmentedControl*)viewModeSegment_ setSelectedImage:thumbImage forSegmentAtIndex:1];
    
    if (self.pdfViewController.tintColor) {
        viewModeSegment_.tintColor = self.pdfViewController.tintColor;
    }else {
        viewModeSegment_.tintColor = [self.pdfViewController isTransparentHUD] ? [UIColor colorWithWhite:0.2f alpha:1.0f] : nil;
    }
    
    viewModeSegment_.selectedSegmentIndex = (NSInteger)self.pdfViewController.viewMode;
}

- (UIView *)customView {
    if (!viewModeSegment_) {
        //`[self setupModeSegmentView];
        [self updateBarButtonItem];
    }
    return viewModeSegment_;
}

- (void)viewModeSegmentChanged:(PSPDFSegmentedControl *)sender {
    [PSPDFBarButtonItem dismissPopoverAnimated:NO];
    
    NSUInteger selectedSegment = sender.selectedSegmentIndex;
    PSPDFLog(@"selected segment index: %lu", (unsigned long)selectedSegment);
    [self.pdfViewController setViewMode:selectedSegment == 0 ? PSPDFViewModeDocument : PSPDFViewModeThumbnails animated:YES];
}

@end
