//
//  PSPDFAnnotation.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
// 
//  Rect-Parsing code partially based on code by Sorin Nistor. Thanks!
//  Copyright (c) 2011-2012 Sorin Nistor. All rights reserved. This software is provided 'as-is', without any express or implied warranty.
//  In no event will the authors be held liable for any damages arising from the use of this software.
//  Permission is granted to anyone to use this software for any purpose, including commercial applications,
//  and to alter it and redistribute it freely, subject to the following restrictions:
//  1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software.
//     If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source distribution.
//

#import "UIColor+PSPDFKitAdditions.h"
#import "PSPDFAnnotation.h"
#import "PSPDFKit.h"

@implementation PSPDFAnnotation

@synthesize pageLinkTarget = pageLinkTarget_;
@synthesize siteLinkTarget = siteLinkTarget_;
@synthesize pdfRectangle = pdfRectangle_;
@synthesize page = page_;
@synthesize type = type_;
@synthesize URL = URL_;
@synthesize document = document_;
@synthesize contents = contents_;
@synthesize color = color_;
@synthesize options = options_;
@dynamic overlayAnnotation;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithPDFDictionary:(CGPDFDictionaryRef)annotationDictionary {
    if ((self = [super init])) {
        PSPDFRegisterObject(self);
        // Normalize and cache the annotation rect definition for faster hit testing.
        CGPDFArrayRef rectArray = NULL;
        CGPDFDictionaryGetArray(annotationDictionary, "Rect", &rectArray);
        if (rectArray != NULL) {
            CGPDFReal llx = 0;
            CGPDFArrayGetNumber(rectArray, 0, &llx);
            CGPDFReal lly = 0;
            CGPDFArrayGetNumber(rectArray, 1, &lly);
            CGPDFReal urx = 0;
            CGPDFArrayGetNumber(rectArray, 2, &urx);
            CGPDFReal ury = 0;
            CGPDFArrayGetNumber(rectArray, 3, &ury);
            
            if (llx > urx) {
                CGPDFReal temp = llx;
                llx = urx;
                urx = temp;
            }
            if (lly > ury) {
                CGPDFReal temp = lly;
                lly = ury;
                ury = temp;
            }
            
            pdfRectangle_ = CGRectMake(llx, lly, urx - llx, ury - lly);
        }
        
        CGPDFStringRef contents;
        
        // Get any associated contents (arbitary text entered by the user) from this dictionary
        if (CGPDFDictionaryGetString(annotationDictionary, "Contents", &contents)) {
            contents_ = (__bridge_transfer NSString *)CGPDFStringCopyTextString(contents);
            PSPDFLog(@"%@ contents is \"%@\"", self, contents_);
        }
        
        CGPDFArrayRef components;
        
        // Get the components of a color optionally used to present the annotation
        if (CGPDFDictionaryGetArray(annotationDictionary, "C", &components)) {
            color_ = [[UIColor alloc] initWithCGPDFArray:components];
        }
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
    document_ = nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ type:%lu rect:%@ targetPage:%lu targetSite:%@ URL:%@ (sourcePage:%lu, sourceDoc:%@)>", NSStringFromClass([self class]), (unsigned long)self.type, NSStringFromCGRect(pdfRectangle_), (unsigned long)self.pageLinkTarget, self.siteLinkTarget, self.URL, (unsigned long)self.page, self.document.title];
}

- (NSUInteger)hash {
    // http://stackoverflow.com/questions/254281/best-practices-for-overriding-isequal-and-hash/254380#254380
    return ((((((((type_ * 31 + page_) * 31) + pageLinkTarget_ * 31) + (pdfRectangle_.origin.x + pdfRectangle_.size.width) * 31) + (pdfRectangle_.origin.y + pdfRectangle_.size.height) * 31) + pageLinkTarget_ * 31) + [siteLinkTarget_ hash] * 31) + [options_ hash] * 31);
}

- (BOOL)isEqual:(id)other {
    if ([other isKindOfClass:[self class]]) {
        PSPDFAnnotation *otherAnnotation = (PSPDFAnnotation *)other;
        if (![document_ isEqual:[otherAnnotation document]] || !document_ || ![otherAnnotation document]) {
            return NO;
        }
        
        if (page_ == otherAnnotation.page && CGRectEqualToRect(pdfRectangle_, otherAnnotation.pdfRectangle) && pageLinkTarget_ == otherAnnotation.pageLinkTarget && siteLinkTarget_ == otherAnnotation.siteLinkTarget && type_ == otherAnnotation.type) {
            return YES;
        }
    }
    return NO;  
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (BOOL)isOverlayAnnotation {
    return self.type >= PSPDFAnnotationTypeVideo;
}

- (CGRect)rectForPageRect:(CGRect)pageRect {
    PSPDFPageInfo *pageInfo = [document_ pageInfoForPage:page_];
    return PSPDFConvertPDFRectToViewRect(pdfRectangle_, pageInfo.pageRect, pageInfo.pageRotation, pageRect);
}

- (BOOL)hitTest:(CGPoint)point {
    if ((pdfRectangle_.origin.x <= point.x) &&
        (pdfRectangle_.origin.y <= point.y) &&
        (point.x <= pdfRectangle_.origin.x + pdfRectangle_.size.width) &&
        (point.y <= pdfRectangle_.origin.y + pdfRectangle_.size.height)) {
        return YES;
    } else {
        return NO;
    }
}

- (void)setSiteLinkTarget:(NSString *)siteLinkTarget {
    if (siteLinkTarget != siteLinkTarget_) {
        siteLinkTarget_ = siteLinkTarget;
        
        // pre-set to web url, this may change if a pspdfkit url is detected
        self.type = PSPDFAnnotationTypeWebUrl;
    }
}

- (BOOL)isModal {
    BOOL modal = [[options_ objectForKey:@"modal"] boolValue];
    return modal;
}

- (void)setModal:(BOOL)modal {
    NSMutableDictionary *newOptions = options_ ? [options_ mutableCopy] : [NSMutableDictionary dictionaryWithCapacity:1];
    [newOptions setObject:[NSNumber numberWithBool:modal] forKey:@"modal"];
}

- (BOOL)isPopover {
    BOOL popover = [[options_ objectForKey:@"popover"] boolValue];
    return popover;
}

- (void)setPopover:(BOOL)popover {
    NSMutableDictionary *newOptions = options_ ? [options_ mutableCopy] : [NSMutableDictionary dictionaryWithCapacity:1];
    [newOptions setObject:[NSNumber numberWithBool:popover] forKey:@"popover"];
}

- (CGSize)size {
    CGSize size = CGSizeZero;
    if ([[options_ objectForKey:@"size"] isKindOfClass:[NSString class]]) {
        NSString *sizeString = [options_ objectForKey:@"size"];
        NSArray *parts = [sizeString componentsSeparatedByString:@"x"];
        if ([parts count] == 2) {
            size = CGSizeMake([[parts objectAtIndex:0] floatValue], [[parts objectAtIndex:1] floatValue]);
        }
    }
    return size;
}

- (void)setSize:(CGSize)size {
    NSMutableDictionary *newOptions = options_ ? [options_ mutableCopy] : [NSMutableDictionary dictionaryWithCapacity:1];
    NSString *sizeString = [NSString stringWithFormat:@"%fx%f", size.width, size.height];
    [newOptions setObject:sizeString forKey:@"size"];
}

@end
