//
//  PSPDFLabelParser.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//
//  Special thanks to Cédric Luthi for providing the code.
//

#import "PSPDFLabelParser.h"
#import "PSPDFDocument.h"
#import "PSPDFDocumentProvider.h"
#import "PSPDFGlobalLock.h"

@interface PSPDFLabelParser()
@property(nonatomic, ps_weak) PSPDFDocument *document;
@end

@implementation PSPDFLabelParser

@synthesize document = document_;
@synthesize labels = labels_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

static NSString* pageLabel(NSUInteger pageIndex, NSString *prefix, NSString *labelStyle) {
    // if there's no prefix and no labelStyle, don't bother creating a pageLabel.
    NSString *result = prefix ? [NSString stringWithFormat:@"%lu", (unsigned long)pageIndex] : nil;

    if ([[labelStyle lowercaseString] isEqualToString:@"r"]) {
        // Code from http://www.cocoabuilder.com/archive/cocoa/173503-roman-numerals-nsnumberformatter.html
        NSUInteger i, deflateNumber = pageIndex;
        NSString *romanValue = @"";
        NSDictionary *pairs = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"i", @"1",
                               @"x", @"10",
                               @"c", @"100",
                               @"m", @"1000",
                               @"iv", @"4",
                               @"xl", @"40",
                               @"cd", @"400",
                               @"v", @"5",
                               @"l", @"50",
                               @"d", @"500",
                               @"ix", @"9",
                               @"xc", @"90",
                               @"cm", @"900",
                               nil];
        
        NSArray *values = [NSArray arrayWithObjects:@"1000", @"900", @"500", @"400", @"100", @"90", @"50", @"40", @"10", @"9", @"5", @"4", @"1", nil];
        NSUInteger itemCount = [values count], itemValue;
        
        for (i = 0; i < itemCount; i++) {
            itemValue = [[values objectAtIndex:i] intValue];
            
            while (deflateNumber >= itemValue) {
                romanValue = [romanValue stringByAppendingString:[pairs objectForKey:[values objectAtIndex:i]]];
                deflateNumber -= itemValue;
            }
        }
        
        result = romanValue;
    }else if ([[labelStyle lowercaseString] isEqualToString:@"a"]) {
        NSString *letterValue = @"";
        NSString *letter = [NSString stringWithFormat:@"%lu", (unsigned long)('a' + ((pageIndex - 1) % 26))];
        NSUInteger length = 1 + ((pageIndex - 1) / 26);
        for (NSUInteger i = 0; i < length; i++)
            letterValue = [letterValue stringByAppendingString:letter];
        
        result = letterValue;
    }
    
    if ([labelStyle isEqualToString:@"R"] || [labelStyle isEqualToString:@"A"])
        result = [result uppercaseString];
    
    return prefix ? [prefix stringByAppendingString:result] : result;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)document {
    if ((self = [super init])) {
        PSPDFRegisterObject(self);
        document_ = document;
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
	document_ = nil; // weak
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (NSDictionary *)labels {
    if (!labels_) {
        labels_ = [self parseDocument];
    }
    return labels_;
}

- (NSDictionary *)parseDocument {
    if(![document_ isValid]) return nil;

    NSMutableDictionary *labels = [NSMutableDictionary dictionaryWithCapacity:[document_ pageCount]];
    NSArray *documentProviders = [document_ documentProviders];
    NSUInteger pageOffset = 0;
    for (PSPDFDocumentProvider *documentProvider in documentProviders) {
        @autoreleasepool {
            CGPDFDocumentRef documentRef = [documentProvider requestDocumentRef];
            size_t numberOfPages = CGPDFDocumentGetNumberOfPages(documentRef);
            
            // See PDF Reference §8.3.1 (Page Labels)
            CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(documentRef);
            CGPDFDictionaryRef pdfPageLabels = NULL;
            if (CGPDFDictionaryGetDictionary(catalog, "PageLabels", &pdfPageLabels) && pdfPageLabels) {
                CGPDFArrayRef pdfNums = NULL;
                if (CGPDFDictionaryGetArray(pdfPageLabels, "Nums", &pdfNums) && pdfNums) {
                    size_t count = CGPDFArrayGetCount(pdfNums);
                    for (size_t i = 0; i < count; i += 2) {
                        CGPDFInteger rangeStart = 0;
                        CGPDFInteger rangeEnd = 0;
                        NSString *prefix = nil;
                        NSString *style = nil;
                        CGPDFInteger pdfOffset = 1;
                        
                        CGPDFArrayGetInteger(pdfNums, i, &rangeStart);
                        if ((i + 2) < count) {
                            CGPDFArrayGetInteger(pdfNums, i + 2, &rangeEnd);
                        }else {
                            rangeEnd = numberOfPages;
                        }
                        
                        if (i + 1 < count) {
                            CGPDFDictionaryRef pdfLabelDictionary = NULL;
                            if (CGPDFArrayGetDictionary(pdfNums, i + 1, &pdfLabelDictionary)) {
                                CGPDFStringRef pdfPrefix = NULL;
                                if (CGPDFDictionaryGetString(pdfLabelDictionary, "P", &pdfPrefix) && pdfPrefix) {
                                    prefix = CFBridgingRelease(CGPDFStringCopyTextString(pdfPrefix));
                                }
                                const char *pdfStyle = NULL;
                                if (CGPDFDictionaryGetName(pdfLabelDictionary, "S", &pdfStyle) && pdfStyle) {
                                    style = [NSString stringWithCString:pdfStyle encoding:NSASCIIStringEncoding];
                                }
                                CGPDFDictionaryGetInteger(pdfLabelDictionary, "St", &pdfOffset);
                            }
                        }
                        
                        for (CGPDFInteger j = rangeStart; j < rangeEnd; j++) {
                            NSUInteger n = pdfOffset + j - rangeStart;
                            NSString *label = pageLabel(n, prefix, style);
                            if (label) {
                                [labels setObject:label forKey:[NSNumber numberWithUnsignedInteger:pageOffset+n]];
                            }
                        }
                    }
                }
            }
            pageOffset += numberOfPages;
            [documentProvider releaseDocumentRef:documentRef];
        }
    }

	return labels;
}

- (NSString *)pageLabelForPage:(NSUInteger)page {
    // returns nil if key is not found
    NSString *pageLabel = [self.labels objectForKey:[NSNumber numberWithUnsignedInteger:page]];
    return pageLabel;
}

@end
