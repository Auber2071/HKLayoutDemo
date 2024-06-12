//
//  PSPDFCloseBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFCloseBarButtonItem.h"
#import "PSPDFViewController.h"

@implementation PSPDFCloseBarButtonItem

// always enable close button
- (void)updateBarButtonItem {
    self.enabled = YES;
}

- (NSString *)actionName {
    return PSPDFLocalize(@"Close");
}

- (UIBarButtonItemStyle)itemStyle {
    return UIBarButtonItemStylePlain;
}

- (void)action:(PSPDFBarButtonItem *)sender {
    // try to be smart and pop if we are not displayed modally.
    BOOL shouldDismiss = YES;
    if (self.pdfViewController.navigationController) {
        UIViewController *topViewController = self.pdfViewController.navigationController.topViewController;
        UIViewController *parentViewController = nil;
        PSPDF_IF_IOS5_OR_GREATER(parentViewController = self.pdfViewController.parentViewController; )
        if ((topViewController == self.pdfViewController || topViewController == parentViewController) && [self.pdfViewController.navigationController.viewControllers count] > 1) {
            [self.pdfViewController.navigationController popViewControllerAnimated:YES];
            shouldDismiss = NO;
        }
    }

    if (shouldDismiss) {
        [self.pdfViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
