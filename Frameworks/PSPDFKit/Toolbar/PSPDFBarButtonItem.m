//
//  PSPDFBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFBarButtonItem.h"
#import "PSPDFViewController.h"
#import "PSPDFMoreBarButtonItem.h"
#import "PSPDFDocument.h"
#import "PSPDFViewController+Internal.h"

// Allows to easily mix UIBarButtonItem and PSPDFBarButtonItem in rightBarButtonItems and leftBarButtonItems
@implementation UIBarButtonItem (PSPDFBarButtonItem)
- (BOOL)isAvailable {
    return YES;
}
@end

@interface PSPDFBarButtonItem ()
@property (nonatomic, ps_weak) PSPDFBarButtonItem *senderBarButtonItem;
@end

@implementation PSPDFBarButtonItem

@synthesize pdfViewController = pdfViewController_;
@synthesize senderBarButtonItem = senderBarButtonItem_;

static PSPDFBarButtonItem *currentBarButtonItem = nil;

+ (void)dismissPopoverAnimated:(BOOL)animated {
    // prevent entering multiple times
    static BOOL isDismissingPopover = NO;
    if (!isDismissingPopover) {
        isDismissingPopover = YES;
        [currentBarButtonItem dismissAnimated:animated];
        [currentBarButtonItem didDismiss];
        isDismissingPopover = NO;
    }
}

+ (BOOL)isPopoverVisible {
    return currentBarButtonItem != nil;
}

- (id)initWithPDFViewController:(PSPDFViewController *)pdfViewController {
    pdfViewController_ = pdfViewController;
    
    if (self.customView) {
        self = [super initWithCustomView:self.customView];
    }else if (self.image) {
        if (self.landscapeImagePhone && kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_5_0) {
            self = [super initWithImage:self.image landscapeImagePhone:self.landscapeImagePhone style:self.itemStyle target:self action:@selector(action:)];
        }else {
            self = [super initWithImage:self.image style:[self itemStyle] target:self action:@selector(action:)];
        }
    }else if (self.systemItem != (UIBarButtonSystemItem)-1) {
        self = [super initWithBarButtonSystemItem:self.systemItem target:self action:@selector(action:)];
    }else {
        self = [super initWithTitle:[self actionName] style:[self itemStyle] target:self action:@selector(action:)];
    }
    return self;
}

- (BOOL)isAvailable {
    return YES;
}

- (void)updateBarButtonItem {
   // self.enabled = [pdfViewController_.document isValid];
}

- (UIView *)customView {
    return nil;
}

- (UIImage *)image {
    return nil;
}

- (UIImage *)landscapeImagePhone {
    return nil;
}

- (UIBarButtonSystemItem)systemItem {
    return (UIBarButtonSystemItem)-1;
}

- (NSString *)actionName {
    return nil;
}

- (UIBarButtonItemStyle)itemStyle {
    return UIBarButtonItemStylePlain;
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)dismissAnimated:(BOOL)animated {
    [self doesNotRecognizeSelector:_cmd];
}

- (void)didDismiss {
    currentBarButtonItem.senderBarButtonItem = nil;
    currentBarButtonItem.pdfViewController.popoverController = nil;
    currentBarButtonItem = nil;
}

- (void)action:(PSPDFBarButtonItem *)sender {
    BOOL dismissOnly = sender == currentBarButtonItem.senderBarButtonItem && sender == self;
    [[self class] dismissPopoverAnimated:dismissOnly];
    if (!dismissOnly && !self.pdfViewController.isNavigationBarHidden) {
        self.pdfViewController.popoverController = nil;
        id presentedObject = [self presentAnimated:YES sender:sender];
        if (presentedObject) {
            [self addPassthroughViewsToPopoverControllerForObject:presentedObject];
            currentBarButtonItem = self;
            currentBarButtonItem.senderBarButtonItem = sender;
        }
    }
}

// present controller modally or in popover - depending on the platform
- (id)presentModalOrInPopover:(UIViewController *)viewController sender:(id)sender {
    if(PSIsIpad()) {
        //TODO custom popoverVC
        if (self.pdfViewController.popoverController)
        {
            self.pdfViewController.popoverController.popoverContentSize = CGSizeMake(viewController.view.frame.size.width, viewController.view.frame.size.height);
            self.pdfViewController.popoverController.delegate = self;
            [self.pdfViewController delegateWillShowController:viewController embeddedInController:self.pdfViewController.popoverController animated:YES];
            [self.pdfViewController.popoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp | UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight animated:YES];
            return self.pdfViewController.popoverController;
        }
        UIPopoverController *popoverController = [[UIPopoverController alloc] initWithContentViewController:viewController];
        self.pdfViewController.popoverController = popoverController;
        popoverController.popoverContentSize = CGSizeMake(viewController.view.frame.size.width, viewController.view.frame.size.height);
        popoverController.delegate = self;
        [self.pdfViewController delegateWillShowController:viewController embeddedInController:popoverController animated:YES];
        [popoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp | UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight animated:YES];
        return popoverController;
    }else {
        [self.pdfViewController presentModalViewController:viewController withCloseButton:YES animated:YES];
        return nil;
    }
}

- (void)dismissModalOrPopoverAnimated:(BOOL)animated {
    if (PSIsIpad()) {
        [self dismissKeyboard];
        [self.pdfViewController.popoverController dismissPopoverAnimated:animated];
        self.pdfViewController.popoverController = nil;
    }else {
        [self.pdfViewController dismissViewControllerAnimated:animated
                                                   completion:nil];
    }
}

- (void)dismissKeyboard {
    UISearchBar *searchBar = nil;
    UIPopoverController *popoverController = self.pdfViewController.popoverController;
    if ([popoverController.contentViewController respondsToSelector:@selector(searchBar)])
        searchBar = [popoverController.contentViewController performSelector:@selector(searchBar)];
    
    if (searchBar) {
        // lock current size (so that it doesn't change while animating out keyboard
        popoverController.contentViewController.preferredContentSize = popoverController.contentViewController.view.frame.size;
        // instantly resign keyboard, don't wait for viewWillDisappear which is sent AFTER complete popover animation
        [searchBar resignFirstResponder];
    }
}

// Hacky, but not critical if it fails.
+ (UIPopoverController *)popoverControllerForObject:(id)object {
    if (!PSIsIpad())
        return nil;
    
    UIPopoverController *popoverController = object;
    
#ifndef PSPDFKIT_DONT_USE_OBFUSCATED_PRIVATE_API
    NSString *printInteractionControllerKeyPath = [NSString stringWithFormat:@"%1$@%2$@.%1$@%3$@%4$@%5$@.%6$@%5$@", @"print", @"State", @"Panel", @"View", @"Controller", @"pover"];
    @try {
        if ([object isKindOfClass:[UIPopoverController class]]) {
            popoverController = object;
        }else if ([object isKindOfClass:[UIPrintInteractionController class]]) {
            popoverController = [object valueForKeyPath:printInteractionControllerKeyPath];
        }else {
            // Works at least for UIDocumentInteractionController and UIActionSheet
            popoverController = [object valueForKey:NSStringFromSelector(@selector(popoverController))];
        }
    }
    @catch (NSException *exception) {
        @try {
            // If Apple fixes the typo in UIPrintPanelViewController and renames the _poverController ivar into _popoverController
            printInteractionControllerKeyPath = [printInteractionControllerKeyPath stringByReplacingOccurrencesOfString:@"pover" withString:@"popover"];
            popoverController = [object valueForKeyPath:printInteractionControllerKeyPath];
        }
        @catch (NSException *exception) {
            popoverController = nil;
        }
    }
#endif

    if ([popoverController isKindOfClass:[UIPopoverController class]]) {
        return popoverController;
    }else {
        return nil;
    }
}

- (void)addPassthroughViewsToPopoverControllerForObject:(id)object {
    UIPopoverController *popoverController = [[self class] popoverControllerForObject:object];
    popoverController.passthroughViews = [NSArray arrayWithObject:self.pdfViewController.navigationController.navigationBar];
}

#pragma mark - UIPopoverController

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    [self dismissKeyboard];
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    [self didDismiss];
}

@end
