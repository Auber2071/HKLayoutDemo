//
//  PSPDFOpenInBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFOpenInBarButtonItem.h"
#import "PSPDFViewController.h"
#import "PSPDFDocument.h"
#import "PSPDFViewController+Internal.h"

@interface PSPDFOpenInBarButtonItem ()
@property (nonatomic, strong) UIDocumentInteractionController *documentInteractionController;
@end

@implementation PSPDFOpenInBarButtonItem 
@synthesize documentInteractionController = documentInteractionController_;

- (BOOL)isAvailable {
    BOOL isAvailable = NO;
    PSPDFDocument *document = self.pdfViewController.document;
    @try {
        if ([UIDocumentInteractionController class] && document.fileUrl) {
            UIDocumentInteractionController *docController = [UIDocumentInteractionController interactionControllerWithURL:document.fileUrl];
            if (docController) {
                // this throws an exception on the simulator, it doesn't kill the app, but it's annoying
                // and we don't expect to find apps that support the openIn in the simulator anyway.
#if !TARGET_IPHONE_SIMULATOR
                isAvailable = [docController presentOpenInMenuFromRect:CGRectMake(0, 0, 1, 1) inView:[UIApplication sharedApplication].keyWindow animated:NO]; // Rect is not allowed to be CGRectZero
                [docController dismissMenuAnimated:NO];
#endif
            }
        }
    }
    @catch (NSException *exception) {
        // this sometimes fires internal exceptions, in that case we disable that feature.
    }

#if TARGET_IPHONE_SIMULATOR
    isAvailable = YES;
#endif
    return isAvailable;
}

- (UIBarButtonSystemItem)systemItem {
    return UIBarButtonSystemItemAction;
}

- (NSString *)actionName {
    return PSPDFLocalize(@"Open in...");
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
#if TARGET_IPHONE_SIMULATOR
    [[[UIAlertView alloc] initWithTitle:@"PSPDFKit Simulator Notice" message:@"Open In... doesn't properly work in the iOS Simulator. It's hard-locked to always show. On a device, we ask UIDocumentInteractionController if the document can be opened with other applications." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    return nil;
#endif

    self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:self.pdfViewController.document.fileUrl];
    self.documentInteractionController.delegate = self;
    [self.pdfViewController delegateWillShowController:documentInteractionController_ embeddedInController:[[self class] popoverControllerForObject:documentInteractionController_] animated:YES];
    [self.documentInteractionController presentOpenInMenuFromBarButtonItem:sender animated:YES];
    return self.documentInteractionController;
}

- (void)dismissAnimated:(BOOL)animated {
    [self.documentInteractionController dismissMenuAnimated:animated];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
    [self didDismiss];
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
    PSPDFLogVerbose(@"Sending document to application: %@", application);
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    PSPDFLogVerbose(@"Sent document to application: %@", application);
    [self didDismiss];
}

@end
