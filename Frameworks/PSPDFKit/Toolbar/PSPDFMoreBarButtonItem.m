//
//  PSPDFMoreBarButtonItem.m
//  PSPDFKit
//
//  Created by Cédric Luthi on 11.05.12.
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFMoreBarButtonItem.h"
#import "PSPDFActionSheet.h"
#import "PSPDFViewController.h"
#import "PSPDFViewController+Internal.h"

@interface PSPDFMoreBarButtonItem ()

@property(nonatomic, assign) BOOL isDismissingSheet;

@end

@implementation PSPDFMoreBarButtonItem

@synthesize actionSheet = actionSheet_;

- (UIBarButtonSystemItem)systemItem {
    return UIBarButtonSystemItemAction;
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
    PSPDFActionSheet *sheet = [[PSPDFActionSheet alloc] initWithTitle:@""];
    self.isDismissingSheet = NO;
    
    for (PSPDFBarButtonItem *buttonItem in self.pdfViewController.additionalRightBarButtonItems) {
        if (![buttonItem isKindOfClass:[UIBarButtonItem class]]) {
            continue;
        }

        if (!buttonItem.isAvailable) {
            continue;
        }
        
        if (!buttonItem.actionName) {
            PSPDFLogWarning(@"Bar button item %@ does not have an action name.", buttonItem);
            continue;
        }
        
        [sheet addButtonWithTitle:buttonItem.actionName block:^{
            [buttonItem.target performSelector:@selector(action:) withObject:sender];
        }];
    }
    
    if ([sheet buttonCount] > 0) {
        sheet.delegate = self;
        [sheet setCancelButtonWithTitle:PSPDFLocalize(@"Cancel") block:^{
            // we don't get any delegates for the slide down animation on iPhone.
            // if we'd call dismissWithClickedButtonIndex again, the animation would be nil.
            self.isDismissingSheet = YES;
            [self didDismiss];
        }];
        [self.pdfViewController delegateWillShowController:sheet embeddedInController:nil animated:YES];
        if (PSIsIpad()) {
            [sheet showFromBarButtonItem:sender animated:YES];
        }else {
            [sheet showInView:self.pdfViewController.view];
        }
        self.actionSheet = sheet.actionSheet;
        return self.actionSheet;
    }else {
        PSPDFLogError(@"Not showing empty action sheet.");
        return nil;
    }
}

- (void)dismissAnimated:(BOOL)animated {
    if (self.isDismissingSheet) {
        return;
    }
    
    [self.actionSheet dismissWithClickedButtonIndex:self.actionSheet.cancelButtonIndex animated:animated];
}

@end
