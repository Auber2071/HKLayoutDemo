//
//  PSPDFEmailBarButtonItem.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFEmailBarButtonItem.h"
#import "PSPDFIconGenerator.h"
#import "PSPDFViewController.h"
#import "PSPDFDocument.h"

@implementation PSPDFEmailBarButtonItem

- (BOOL)isAvailable {
    return [MFMailComposeViewController canSendMail];
}

- (UIImage *)image {
    return [[PSPDFIconGenerator sharedGenerator] iconForType:PSPDFIconTypeEmail];
}

- (NSString *)actionName {
    return PSPDFLocalize(@"Email");
}

- (NSString *)fileName {
    PSPDFDocument *document = self.pdfViewController.document;
    NSString *fileName = document.fileUrl ? [document.fileUrl lastPathComponent] : document.title;
    if ([fileName length] == 0) {
        fileName = PSPDFLocalize(@"Untitled"); // if PDF is build from NSData
    }
    if (![[fileName lowercaseString] hasSuffix:@".pdf"]) {
        fileName = [fileName stringByAppendingString:@".pdf"];
    }
    return fileName;
}

- (id)presentAnimated:(BOOL)animated sender:(PSPDFBarButtonItem *)sender {
    PSPDFDocument *document = self.pdfViewController.document;
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    [mailViewController setSubject:document.title];
    NSError *error = nil;
    NSData *data = document.data ?: [NSData dataWithContentsOfURL:document.fileUrl options:NSDataReadingMappedAlways error:&error];
    if (!data) {
        PSPDFLogError(@"Failed to prepare NSData: %@", [error localizedDescription]);
    }else {
        NSString *fileName = [self fileName];
        [mailViewController addAttachmentData:data mimeType:@"application/pdf" fileName:fileName];
        mailViewController.mailComposeDelegate = self;
        mailViewController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.pdfViewController presentModalViewController:mailViewController withCloseButton:NO animated:animated];
    }
    return nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [[self.pdfViewController masterViewController] dismissViewControllerAnimated:YES completion:nil];
}

@end
