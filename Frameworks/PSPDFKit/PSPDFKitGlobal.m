//
//  PSPDFKitGlobal.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKitGlobal.h"
#import "PSPDFKit.h"
#import "PSPDFPatches.h"
#import "InfoPlist.h" // defines the version string

// draw demo mode code
#ifdef kPSPDFKitDemoMode
inline void DrawPSPDFKit(CGContextRef context) {
    char *text = "PSPDFKit DEMO"; \
    CGFloat demoPosition = PSIsIpad() ? 50.f : 20.f;
    NSUInteger fontSize = PSIsIpad() ? 30 : 14; \
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor); \
    CGContextSelectFont(context, "Helvetica-Bold", fontSize, kCGEncodingMacRoman); \
    CGAffineTransform xform = CGAffineTransformMake(1.0, 0.0, 0.0, -1.0, 0.0, 0.0); \
    CGContextSetTextMatrix(context, xform); \
    CGContextSetTextDrawingMode(context, kCGTextFill); \
    CGContextSetTextPosition(context, demoPosition, demoPosition + round(fontSize / 4.0f)); \
    CGContextShowText(context, text, (text[0] == 'P') ? 13 : 99999); // be nasty, in case text gets deleted strlen(text)
}
#else
inline void DrawPSPDFKit(CGContextRef context) {}
#endif

// global variables
NSString *const kPSPDFErrorDomain = @"com.pspdfkit.error";
PSPDFLogLevel kPSPDFLogLevel = PSPDFLogLevelWarning;
PSPDFAnimate kPSPDFAnimateOption = PSPDFAnimateModernDevices;
CGFloat kPSPDFKitPDFAnimationDuration = 0.1f;
CGFloat kPSPDFKitHUDTransparency = 0.7f;
CGFloat kPSPDFInitialAnnotationLoadDelay = 0.2f;
NSUInteger kPSPDFKitZoomLevels = 0; // late-init
BOOL kPSPDFKitDebugScrollViews = NO;
BOOL kPSPDFKitDebugMemory = NO;
NSString *kPSPDFCacheClassName = @"PSPDFCache";
NSString *kPSPDFIconGeneratorClassName = @"PSPDFIconGenerator";

extern void PSPDFKitInitializeGlobals(void) {
    if (kPSPDFKitZoomLevels == 0) {
        kPSPDFKitZoomLevels = PSPDFIsCrappyDevice() ? 4 : 5;
    }
    
    // apply UIKit-Patch for iOS5 for UIPageViewController
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PSPDF_IF_IOS5_OR_GREATER(pspdf_patchUIKit();)
    });
}

BOOL PSPDFShouldAnimate(void) {
    BOOL shouldAnimate = (!PSPDFIsCrappyDevice() && kPSPDFAnimateOption == PSPDFAnimateModernDevices) || kPSPDFAnimateOption == PSPDFAnimateEverywhere;
    return shouldAnimate;
}

CGSize PSPDFSizeForScale(CGSize size, CGFloat scale) {
	CGSize newSize = CGSizeMake(roundf(size.width*scale), roundf(size.height*scale));
    return newSize;
}

BOOL PSPDFIsCrappyDevice(void) {
    static BOOL isCrappyDevice = YES;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL isSimulator = NO;
        BOOL isIPad2 = (PSIsIpad() && [UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]);
        BOOL hasRetina = [[UIScreen mainScreen] scale] > 1.f;
        
        // enable animations on simulator
#if TARGET_IPHONE_SIMULATOR
        isSimulator = YES;
#endif
        if (isIPad2 || hasRetina || isSimulator) {
            isCrappyDevice = NO;
        }else {
            PSPDFLog(@"Old device detected. Reducing animations.");
        }
    });
    
    return isCrappyDevice;
}

extern NSString *PSPDFVersionString(void) {
    return GIT_VERSION;
}

// for localization
#define kPSPDFKitBundleName @"PSPDFKit.bundle"
NSBundle *pspdfkitBundle(void);
NSBundle *pspdfkitBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:kPSPDFKitBundleName];
        bundle = [NSBundle bundleWithPath:path];
    });
    return bundle;
}

static NSString *preferredLocale(void);
static NSString *preferredLocale(void) {
    static NSString *locale = nil;
    if (!locale) {
        NSArray *locales = [NSLocale preferredLanguages];
        if ([locales count]) {
            locale = [[locales objectAtIndex:0] copy];
        }else {
            PSPDFLogWarning(@"No preferred language? [NSLocale preferredLanguages] returned nil. Defaulting to english.");
            locale = @"en";
        }
    }
    return locale;
}

static NSDictionary *localizationDict_ = nil;
NSString *PSPDFLocalize(NSString *stringToken) {
    // load language from bundle
    NSString *localization = NSLocalizedStringFromTableInBundle(stringToken, @"PSPDFKit", pspdfkitBundle(), @"");
    if (!localization) {
        localization = stringToken;
    }
    
    // try loading from the global translation dict
    NSString *replLocale = nil;
    if (localizationDict_) {
        NSString *language = preferredLocale();
        replLocale = [[localizationDict_ objectForKey:language] objectForKey:stringToken];
        if (!replLocale && ![localizationDict_ objectForKey:language] && ![language isEqualToString:@"en"]) {
            replLocale = [[localizationDict_ objectForKey:@"en"] objectForKey:stringToken];
        }
    }
    
    return replLocale ? replLocale : localization;
}

extern void PSPDFSetLocalizationDictionary(NSDictionary *localizationDict) {
    if (localizationDict != localizationDict_) {
        localizationDict_ = [localizationDict copy];
    }
    
    PSPDFLog(@"new localization dictionary set. locale: %@; dict: %@", preferredLocale(), localizationDict);
}

BOOL PSPDFResolvePathNamesEnableLegacyBehavior = NO;
NSString *PSPDFResolvePathNames(NSString *path, NSString *fallbackPath) {
    NSMutableString *mutableString = [NSMutableString stringWithString:path];
    PSPDFResolvePathNamesInMutableString(mutableString, fallbackPath, NULL);
    return [mutableString copy];
}

BOOL PSPDFResolvePathNamesInMutableString(NSMutableString *mutableString, NSString *fallbackPath, NSString *(^resolveUnknownPathBlock)(NSString *unknownPath)) {
    if (PSPDFResolvePathNamesEnableLegacyBehavior) {
        fallbackPath = nil;
    }
    
    // replace Documents
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSUInteger replacements = [mutableString replaceOccurrencesOfString:@"/Documents" withString:documentsDir options:NSCaseInsensitiveSearch range:NSMakeRange(0, MIN([@"/Documents" length], [mutableString length]))];
    
    // replace Cache
    if (replacements == 0) {
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        replacements = [mutableString replaceOccurrencesOfString:@"/Cache" withString:cachesDir options:NSCaseInsensitiveSearch range:NSMakeRange(0, MIN([@"/Cache" length], [mutableString length]))];
    }
    
    // replace Bundle  
    if (replacements == 0) {
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        replacements = [mutableString replaceOccurrencesOfString:@"/Bundle" withString:bundlePath options:NSCaseInsensitiveSearch range:NSMakeRange(0, MIN([@"/Bundle" length], [mutableString length]))];
        
        // if no replacements could be found, use local bundle
        if (replacements == 0 && resolveUnknownPathBlock) {
            // first check if the pdf view controller wishes to handle special directory paths
            NSString *specialDirIdentifier = [[mutableString componentsSeparatedByString:@"/"] objectAtIndex:1];
            
            if([specialDirIdentifier length]) {
                NSString *resolvedPath = resolveUnknownPathBlock(specialDirIdentifier);
                if ([resolvedPath length]) {
                    NSString *specialPathIdentifier = [NSString stringWithFormat:@"/%@", specialDirIdentifier];
                    replacements = [mutableString replaceOccurrencesOfString:specialPathIdentifier
                                                                  withString:resolvedPath
                                                                     options:0 range:NSMakeRange(0, MIN([specialPathIdentifier length], [mutableString length]))];
                }
            }
        }
        
        if (replacements == 0) {
            BOOL addSlash = ![mutableString hasPrefix:@"/"];
            [mutableString insertString:[NSString stringWithFormat:@"%@%@", fallbackPath ?: bundlePath, addSlash ? @"/" : @""] atIndex:0];
        }
    }
    
    return replacements;
}

UIView *PSPDFGetViewInsideView(UIView *view, NSString *classNamePrefix) {
    UIView *webBrowserView = nil;
    for (UIView *subview in view.subviews) {
        if ([NSStringFromClass([subview class]) hasPrefix:classNamePrefix]) {
            return subview;
        }else {
            if((webBrowserView = PSPDFGetViewInsideView(subview, classNamePrefix))) {
                break;
            }
        }
    }
    return webBrowserView;
}

CGFloat PSPDFScaleForSizeWithinSize(CGSize targetSize, CGSize boundsSize) {
    return PSPDFScaleForSizeWithinSizeWithOptions(targetSize, boundsSize, YES, NO);
}

CGFloat PSPDFScaleForSizeWithinSizeWithOptions(CGSize targetSize, CGSize boundsSize, BOOL zoomMinimalSize, BOOL fitWidth) {
    // don't calculate if imageSize is nil
    if (CGSizeEqualToSize(targetSize, CGSizeZero)) {
        return 1.0;
    }
    
    // set up our content size and min/max zoomscale
    CGFloat xScale = boundsSize.width / targetSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / targetSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = fitWidth ? xScale : fminf(xScale, yScale); // use minimum of these to allow the image to become fully visible
    
    // on high resolution screens we have double the pixel density,
    // so we will be seeing every pixel if we limit the maximum zoom scale to 0.5.
    CGFloat maxScale = 1.0 / [[UIScreen mainScreen] scale];
    
    // don't let minScale exceed maxScale.
    if (!zoomMinimalSize && minScale > maxScale) {
        minScale = maxScale;
    }
    
    if (minScale > 10.0) {
        PSPDFLogWarning(@"Ridiculous high scale detected, limiting.");
        minScale = 10.0;
    }
    
    return minScale;
}


//  Altered code to calculate the pdf points, based on code by Sorin Nistor. Many thanks!
//
//  Copyright (c) 2011-2012 Sorin Nistor. All rights reserved. This software is provided 'as-is', without any express or implied warranty.
//  In no event will the authors be held liable for any damages arising from the use of this software.
//  Permission is granted to anyone to use this software for any purpose, including commercial applications,
//  and to alter it and redistribute it freely, subject to the following restrictions:
//  1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software.
//     If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source distribution.
CGPoint PSPDFConvertViewPointToPDFPoint(CGPoint viewPoint, CGRect cropBox, NSUInteger rotation, CGRect bounds) {
    CGPoint pdfPoint = CGPointMake(0, 0);
    switch (rotation) {
        case 90:
        case -270:
            pdfPoint.x = cropBox.size.width * (viewPoint.y - bounds.origin.y) / bounds.size.height;
            pdfPoint.y = cropBox.size.height * (viewPoint.x - bounds.origin.x) / bounds.size.width;
            break;
        case 180:
        case -180:
            pdfPoint.x = cropBox.size.width * (bounds.size.width - (viewPoint.x - bounds.origin.x)) / bounds.size.width;
            pdfPoint.y = cropBox.size.height * (viewPoint.y - bounds.origin.y) / bounds.size.height;
            break;
        case -90:
        case 270:
            pdfPoint.x = cropBox.size.width * (bounds.size.height - (viewPoint.y - bounds.origin.y)) / bounds.size.height;
            pdfPoint.y = cropBox.size.height * (bounds.size.width - (viewPoint.x - bounds.origin.x)) / bounds.size.width;
            break;
        case 0:
        default:
            pdfPoint.x = cropBox.size.width * (viewPoint.x - bounds.origin.x) / bounds.size.width;
            pdfPoint.y = cropBox.size.height * (bounds.size.height - (viewPoint.y - bounds.origin.y)) / bounds.size.height;
            break;
    }
    pdfPoint.x = pdfPoint.x + cropBox.origin.x;
    pdfPoint.y = pdfPoint.y+ cropBox.origin.y;
    
    return pdfPoint;
}

CGPoint PSPDFConvertPDFPointToViewPoint(CGPoint pdfPoint, CGRect cropBox, NSUInteger rotation, CGRect bounds) {
    CGPoint viewPoint = CGPointMake(0, 0);
    switch (rotation) {
        case 90:
        case -270:
            viewPoint.x = bounds.size.width * (pdfPoint.y - cropBox.origin.y) / cropBox.size.height;
            viewPoint.y = bounds.size.height * (pdfPoint.x - cropBox.origin.x) / cropBox.size.width;
            break;
        case 180:
        case -180:
            viewPoint.x = bounds.size.width * (cropBox.size.width - (pdfPoint.x - cropBox.origin.x)) / cropBox.size.width;
            viewPoint.y = bounds.size.height * (pdfPoint.y - cropBox.origin.y) / cropBox.size.height;
            break;
        case -90:
        case 270:
            viewPoint.x = bounds.size.width * (cropBox.size.height - (pdfPoint.y - cropBox.origin.y)) / cropBox.size.height;
            viewPoint.y = bounds.size.height * (cropBox.size.width - (pdfPoint.x - cropBox.origin.x)) / cropBox.size.width;
            break;
        case 0:
        default:
            viewPoint.x = bounds.size.width * (pdfPoint.x - cropBox.origin.x) / cropBox.size.width;
            viewPoint.y = bounds.size.height * (cropBox.size.height - (pdfPoint.y - cropBox.origin.y)) / cropBox.size.height;
            break;
    }
    
    viewPoint.x = viewPoint.x + bounds.origin.x;
    viewPoint.y = viewPoint.y + bounds.origin.y;
    
    return viewPoint;
}

CGRect PSPDFConvertPDFRectToViewRect(CGRect pdfRect, CGRect cropBox, NSUInteger rotation, CGRect bounds) {
    CGPoint topLeft = PSPDFConvertPDFPointToViewPoint(pdfRect.origin, cropBox, rotation, bounds);
    CGPoint bottomRight = PSPDFConvertPDFPointToViewPoint(CGPointMake(CGRectGetMaxX(pdfRect), CGRectGetMaxY(pdfRect)), cropBox, rotation, bounds);
    CGRect viewRect = CGRectMake(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
    
    return PSPDFNormalizeRect(viewRect);
}

CGRect PSPDFConvertViewRectToPDFRect(CGRect viewRect, CGRect cropBox, NSUInteger rotation, CGRect bounds) {
    CGPoint topLeft = PSPDFConvertViewPointToPDFPoint(viewRect.origin, cropBox, rotation, bounds);
    CGPoint bottomRight = PSPDFConvertViewPointToPDFPoint(CGPointMake(CGRectGetMaxX(viewRect), CGRectGetMaxY(viewRect)), cropBox, rotation, bounds);
    CGRect pdfRect = CGRectMake(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
    return PSPDFNormalizeRect(pdfRect);
}

CGRect PSPDFNormalizeRect(CGRect rect) {
    if (rect.size.height < 0) {
        rect.size.height *= -1;
        rect.origin.y -= rect.size.height;
    }
    
    if (rect.size.width < 0) {
        rect.size.width *= -1;
        rect.origin.x -= rect.size.width;
    }
    return rect;
}
