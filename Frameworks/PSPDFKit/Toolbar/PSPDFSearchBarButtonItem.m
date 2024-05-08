//
//  PSPDFSearchBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFSearchBarButtonItem.h"
#import "PSPDFSearchViewController.h"
#import "PSPDFViewController+Internal.h"

@implementation PSPDFSearchBarButtonItem

- (UIBarButtonSystemItem)systemItem {
    return UIBarButtonSystemItemSearch;
}

- (NSString *)actionName {
    return PSPDFLocalize(@"Search");
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
    Class viewControllerClass = [self.pdfViewController classForClass:[PSPDFSearchViewController class]];
    PSPDFSearchViewController *searchController = [[viewControllerClass alloc] initWithDocument:self.pdfViewController.document pdfController:self.pdfViewController];
    return [self presentModalOrInPopover:searchController sender:sender];
}

- (void)dismissAnimated:(BOOL)animated {
    [self dismissModalOrPopoverAnimated:animated];
}

@end
