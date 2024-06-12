//
//  PSPDFOutlineBarButtonItem.m
//  PSPDFKit
//
//  Created by Cédric Luthi on 11.05.12.
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFOutlineBarButtonItem.h"
#import "PSPDFIconGenerator.h"
#import "PSPDFOutlineViewController.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFDocument.h"
#import "PSPDFOutlineParser.h"
#import "PSPDFOutlineElement.h"

@implementation PSPDFOutlineBarButtonItem

- (BOOL)isAvailable {
    return [self.pdfViewController.document.outlineParser.outline.children count] > 0;
}

- (UIImage *)image {
    return [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypeOutline];
}

- (NSString *)actionName {
    return PSPDFLocalize(@"Outline");
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
    Class viewControllerClass = [self.pdfViewController classForClass:[PSPDFOutlineViewController class]];
    PSPDFOutlineViewController *outlineViewController = [[viewControllerClass alloc] initWithDocument:self.pdfViewController.document pdfController:self.pdfViewController];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:outlineViewController];
    return [self presentModalOrInPopover:navigationController sender:sender];
}

- (void)dismissAnimated:(BOOL)animated {
    [self dismissModalOrPopoverAnimated:animated];
}

@end
