//
//  PSPDFPrintBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFPrintBarButtonItem.h"
#import "PSPDFIconGenerator.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFDocument.h"

@interface PSPDFPrintBarButtonItem ()

@property(nonatomic, assign) BOOL isAnimatingPrint;
@property(nonatomic, assign) BOOL isShowingPrint;

@end

@implementation PSPDFPrintBarButtonItem

- (BOOL)isAvailable {
    return [UIPrintInteractionController isPrintingAvailable] && self.pdfViewController.document.allowsPrinting;
}

- (UIImage *)image {
    return [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypePrint];
}

- (NSString *)actionName {
    return PSPDFLocalize(@"Print");
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
    UIPrintInteractionController *printController = [UIPrintInteractionController sharedPrintController];
    
    if (self.isAnimatingPrint)
        return printController;
    
    UIPrintInfo *printInfo = [UIPrintInfo printInfo];
    printInfo.jobName = self.pdfViewController.document.title;
    
    printController.delegate = self;
    printController.printInfo = printInfo;
    
    if (self.pdfViewController.document.data) {
        printController.printingItem = self.pdfViewController.document.data;
    }else {
        if ([self.pdfViewController.document.files count] == 1) {
            // As documented, showsPageRange = YES does not work with printingItems (plural), only with printingItem (singular)
            printController.printingItem = self.pdfViewController.document.fileUrl;
        }else {
            printController.printingItems = [self.pdfViewController.document filesWithBasePath];
        }
    }
    printController.showsPageRange = YES;
    
    UIPrintInteractionCompletionHandler completionHandler = ^(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *error) {
        if (!PSIsIpad()) {
            [self.pdfViewController setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
        }
        self.isShowingPrint = NO;
        self.isAnimatingPrint = NO;
        PSPDFLogVerbose(@"Printing finished: %d", completed);
        if (error) {
            PSPDFLogError(@"Could not print document. %@", error);
        }
    };
    
    [self.pdfViewController delegateWillShowController:printController embeddedInController:[[self class] popoverControllerForObject:printController] animated:YES];
    if (PSIsIpad()) {
        [printController presentFromBarButtonItem:sender animated:YES completionHandler:completionHandler];
    }else {
        [printController presentAnimated:YES completionHandler:completionHandler];
        [self.pdfViewController setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    }
    self.isShowingPrint = YES;
    
    return printController;
}

- (void)dismissAnimated:(BOOL)animated {
    if (self.isShowingPrint || self.isAnimatingPrint) {
        // stupid UIPrintInteractionController. We need to block calls during animation
        // else it crashes on us with a "dealloc reached while still visible" exception.
        if (!self.isAnimatingPrint) {
            [[UIPrintInteractionController sharedPrintController] dismissAnimated:animated];
            self.isAnimatingPrint = animated;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIPrintInteractionControllerDelegate

- (void)printInteractionControllerDidDismissPrinterOptions:(UIPrintInteractionController *)printInteractionController {
    self.isShowingPrint = NO;
    self.isAnimatingPrint = NO;
    [self didDismiss];
}

@end
