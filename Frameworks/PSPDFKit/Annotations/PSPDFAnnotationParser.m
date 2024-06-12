//
//  PSPDFAnnotationParser.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFAnnotationParser.h"
#import "PSPDFKit.h"
#import "PSPDFAnnotation.h"
#import "PSPDFVideoAnnotationView.h"
#import "PSPDFWebAnnotationView.h"
#import "PSPDFLinkAnnotationView.h"
#import "PSPDFHighlightAnnotationView.h"
#import "PSPDFDocumentProvider.h"
#import "PSPDFYouTubeAnnotationView.h"
#import "PSPDFImageAnnotation.h"
#import "NSURL+PSPDFUnicodeURL.h"

@interface PSPDFAnnotationParser ()

@property(nonatomic, strong) NSMutableDictionary *pageCache;
@property(nonatomic, strong) dispatch_queue_t dictCacheQueue;

- (void)parsePageAnnotation:(PSPDFAnnotation *)annotation dictionary:(CGPDFDictionaryRef)annotationDictionary document:(CGPDFDocumentRef)documentRef;
- (void)parseHighlightAnnotation:(PSPDFAnnotation *)annotation dictionary:(CGPDFDictionaryRef)annotationDictionary document:(CGPDFDocumentRef)documentRef;
- (CGPDFArrayRef)findDestinationByName:(const char *)destinationName inDestsTree:(CGPDFDictionaryRef)node;
- (PSPDFAnnotationType)annotationTypeForDictionary:(CGPDFDictionaryRef)annotationDictionary document:(CGPDFDocumentRef)documentRef;
@property(nonatomic, strong) NSMutableDictionary *namedDestinations;
@end

@implementation PSPDFAnnotationParser

@synthesize document = document_;
@synthesize protocolString = protocolString_;
@synthesize namedDestinations = namedDestinations_;
@synthesize createTextHighlightAnnotations = createTextHighlightAnnotations_;
@synthesize pageCache = pageCache_;
@synthesize dictCacheQueue = dictCacheQueue_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)document {
    if ((self = [super init])) {
        PSPDFRegisterObject(self);
        dictCacheQueue_ = dispatch_queue_create("com.petetersteinberger.pspdfkit.annotationCache", NULL);
        document_ = document;
        protocolString_ = @"pspdfkit://";
        pageCache_ = [NSMutableDictionary new];         // annotation page cache
        namedDestinations_ = [NSMutableDictionary new]; // resolve page refs
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
    dispatch_release(dictCacheQueue_);
#endif
    document_ = nil; // weak
    pageCache_ = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setAnnotations:(NSArray *)annotations forPage:(NSUInteger)page {
    dispatch_sync(dictCacheQueue_, ^{
        if (annotations) {
            [self.pageCache setObject:annotations forKey:[NSNumber numberWithInteger:page]];
        }else {
            [self.pageCache removeObjectForKey:[NSNumber numberWithInteger:page]];
        }
    });
}

- (void)setProtocolString:(NSString *)protocolString {
    if (protocolString != protocolString_) {
        protocolString_ = protocolString;
        [pageCache_ removeAllObjects]; // clear page cache after protocol has been re-set
    }
}

- (Class)annotationClassForAnnotation:(PSPDFAnnotation *)annotation {
    Class annotationClass = nil;
    switch (annotation.type) {
        case PSPDFAnnotationTypeAudio:
        case PSPDFAnnotationTypeVideo: {
            annotationClass = [PSPDFVideoAnnotationView class];
        }break;
        case PSPDFAnnotationTypeYouTube: {
            annotationClass = [PSPDFYouTubeAnnotationView class];
        }break;
        case PSPDFAnnotationTypeImage: {
            annotationClass = [PSPDFImageAnnotation class];
        }break;
        case PSPDFAnnotationTypeBrowser: {
            annotationClass = [PSPDFWebAnnotationView class];
        }break;
        case PSPDFAnnotationTypeLink: {
            annotationClass = [PSPDFLinkAnnotationView class];
        }break;
        case PSPDFAnnotationTypeHighlight : {
            if (createTextHighlightAnnotations_) {
                annotationClass = [PSPDFHighlightAnnotationView class];
            }
        }break;
        default: {
            PSPDFLogVerbose(@"Annotation %@ not handled.", annotation);
        }
    }
    return annotationClass;
}

- (UIView <PSPDFAnnotationView>*)createAnnotationViewForAnnotation:(PSPDFAnnotation *)annotation frame:(CGRect)annotationRect {
    UIView <PSPDFAnnotationView> *annotationView = nil;
    
    // annotation factory
    if(annotation) {
        Class annotationClass = [self annotationClassForAnnotation:annotation];
        if (annotationClass) {
            annotationView = [[annotationClass alloc] initWithFrame:annotationRect];
            annotationView.annotation = annotation;
        }
    }
    return annotationView;
}

- (BOOL)hasLoadedAnnotationsForPage:(NSUInteger)page {
    NSNumber *pageNumber = [NSNumber numberWithInteger:page];
    __block NSArray *annotations;
    dispatch_sync(dictCacheQueue_, ^{
        annotations = [self.pageCache objectForKey:pageNumber];
    });
    
    BOOL hasLoaded = annotations != nil;
    return hasLoaded;
}

- (NSArray *)annotationsForPage:(NSUInteger)page filter:(PSPDFAnnotationFilter)filter {
    return [self annotationsForPage:page filter:filter pageRef:nil];
}

- (NSArray *)annotationsForPage:(NSUInteger)page filter:(PSPDFAnnotationFilter)filter pageRef:(CGPDFPageRef)pageRef {
    __block NSArray *annotations = nil;
    
    PSPDFDocument *document = self.document;
    
    // sanity check
    if (!document) {
        PSPDFLogWarning(@"No document attached, returning nil.");
        return nil;
    }
    
    NSNumber *pageNumber = [NSNumber numberWithInteger:page];
    dispatch_sync(dictCacheQueue_, ^{
        annotations = [self.pageCache objectForKey:pageNumber];
    });
    
    if (!annotations) {
        @synchronized(self) {
            PSPDFLogVerbose(@"fetching annotations for page %lu", (unsigned long)page);
            NSMutableArray *newAnnotations = [NSMutableArray array];
            
            // if no pageRef was given, open document ourself
            PSPDFDocumentProvider *documentProvider = [[PSPDFGlobalLock sharedPSPDFGlobalLock] documentProviderForDocument:self.document page:page];
            if (!pageRef) {
                documentProvider = [[PSPDFGlobalLock sharedPSPDFGlobalLock] documentProviderForDocument:self.document page:page];
                pageRef = [documentProvider requestPageRefForPage:[self.document pageNumberForPage:page]];
            }
            CGPDFDocumentRef documentRef = CGPDFPageGetDocument(pageRef);
            CGPDFDictionaryRef pageDictionary = CGPDFPageGetDictionary(pageRef);
            CGPDFArrayRef annotsArray = NULL;
            
            // PDF links are link annotations stored in the page's Annots array.
            CGPDFDictionaryGetArray(pageDictionary, "Annots", &annotsArray);
            if (annotsArray != NULL) {
                size_t annotsCount = CGPDFArrayGetCount(annotsArray);
                
                for (int j = 0; j < annotsCount; j++) {
                    CGPDFDictionaryRef annotationDictionary = NULL;            
                    if (CGPDFArrayGetDictionary(annotsArray, j, &annotationDictionary)) {
                        
                        // identify the current anntotation
                        PSPDFAnnotationType type = [self annotationTypeForDictionary:annotationDictionary document:documentRef];
                        
                        // if the type is recognized,
                        if (type != PSPDFAnnotationTypeUndefined) {
                            
                            // parses & normalizes "Rect" internally
                            PSPDFAnnotation *annotation = [[PSPDFAnnotation alloc] initWithPDFDictionary:annotationDictionary];
                            annotation.page = page;
                            annotation.document = self.document;
                            annotation.type = type;
                            
                            switch (type) {
                                case PSPDFAnnotationTypePage: {
                                    // parses target
                                    [self parsePageAnnotation:annotation dictionary:annotationDictionary document:documentRef];
                                } break;
                                    
                                case PSPDFAnnotationTypeHighlight: {
                                    // parse highlight annotation specific data
                                    [self parseHighlightAnnotation:annotation dictionary:annotationDictionary document:documentRef];                                    
                                } break;
                                    
                                default: {
                                    // annotation is PSPDFAnnotationTypeCustom, not our problem
                                } break;
                            }
                            
                            [newAnnotations addObject:annotation];
                        }
                    }
                }
            }
            
            // resolve external name references (only needed if name is saved in /GoTo page)
            NSDictionary *resolvedNames = [PSPDFOutlineParser resolveDestNames:[NSSet setWithArray:[namedDestinations_ allKeys]] documentRef:documentRef];
            for (NSNumber *destPageName in [resolvedNames allKeys]) {
                NSSet *pageAnnotations = [namedDestinations_ objectForKey:destPageName];
                for (PSPDFAnnotation *annotation in pageAnnotations) {
                    NSInteger destPage = [[resolvedNames objectForKey:destPageName] integerValue];
                    annotation.pageLinkTarget = destPage;
                    annotation.type = PSPDFAnnotationTypeLink;
                }
            }
            
            dispatch_sync(dictCacheQueue_, ^{
                [self.pageCache setObject:newAnnotations forKey:pageNumber];
            });
            
            annotations = newAnnotations;
            [documentProvider releasePageRef:pageRef];
        }
    }
    
    // filter annotations
    NSMutableArray *filteredAnnotations = [NSMutableArray arrayWithCapacity:[annotations count]];
    BOOL addLinkAnnotations = filter & PSPDFAnnotationFilterLink;
    BOOL addOverlayAnnotations = filter & PSPDFAnnotationFilterOverlay;
    
    if (addLinkAnnotations && addOverlayAnnotations) {
        [filteredAnnotations addObjectsFromArray:annotations];
    }else {
        if (filter & PSPDFAnnotationFilterLink) {
            [filteredAnnotations addObjectsFromArray:[annotations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isOverlayAnnotation = NO"]]];
        }
        if (filter & PSPDFAnnotationFilterOverlay) {
            [filteredAnnotations addObjectsFromArray:[annotations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.isOverlayAnnotation = YES"]]];
        }
    }
    
    return filteredAnnotations;
}

/// override to customize and support new url schemes.
- (void)parseAnnotationLinkTarget:(PSPDFAnnotation *)annotation {
    NSMutableString *link = [NSMutableString stringWithString:annotation.siteLinkTarget?:@""];
    
    // some annotations (wrongly) don't add the protocol, work around this.
    if ([[link lowercaseString] hasPrefix:@"www"]) {
        [link insertString:@"http://" atIndex:0];
    }
    
    if ([[link lowercaseString] hasPrefix:self.protocolString]) {
        // we both support a style like pspdfkit://www.xxx and pspdfkit://https://www.xxx 
        // for local files, use pspdfkit://localhost/Folder/File.ext
        [link deleteCharactersInRange:NSMakeRange(0, [self.protocolString length])];
        
        NSMutableDictionary *linkOptions = nil;
        NSString *pdfOptionMarker = @"[";
        NSString *optionEndMarker = @"]";
        if ([[link lowercaseString] hasPrefix:pdfOptionMarker]) {
            NSRange endRange = [link rangeOfString:optionEndMarker options:0 range:NSMakeRange([pdfOptionMarker length], [link length] - [pdfOptionMarker length])];
            if (endRange.length > 0) {
                NSString *optionStr = [link substringWithRange:NSMakeRange([pdfOptionMarker length], endRange.location - [pdfOptionMarker length])];
                [link deleteCharactersInRange:NSMakeRange(0, endRange.location + endRange.length)];
                
                // convert linkOptions to a dictionary
                NSArray *options = [optionStr componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":,"]];
                linkOptions = [NSMutableDictionary dictionary];
                NSUInteger optIndex = 0;
                while (optIndex+1 < [options count]) {
                    NSString *key = [options objectAtIndex:optIndex];
                    NSString *option = [options objectAtIndex:optIndex+1];
                    [linkOptions setObject:option forKey:key];
                    optIndex+=2;
                }
            }
        }
        if ([linkOptions count]) {
            annotation.options = linkOptions;
        }
        
        BOOL hasHttpInside = [[link lowercaseString] hasPrefix:@"http"];
        BOOL isLocalFile = [[link lowercaseString] hasPrefix:@"localhost"];
        if (!hasHttpInside && !isLocalFile) {
            [link insertString:@"http://" atIndex:0];
        }
        
        if (isLocalFile) {
            [link replaceOccurrencesOfString:@"localhost" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [link length])];
            
            NSString *fileBasePath = [[[self.document pathForPage:annotation.page] path] stringByDeletingLastPathComponent];
            
            // resolve with delegate callback if unknown token was found.
            PSPDFResolvePathNamesInMutableString(link, fileBasePath, ^NSString *(NSString *unknownPath) {
                NSString *newPath = nil;
                if ([self.document.displayingPdfController.delegate respondsToSelector:@selector(pdfViewController:resolveCustomAnnotationPathToken:)]) {
                    newPath = [self.document.displayingPdfController.delegate pdfViewController:self.document.displayingPdfController resolveCustomAnnotationPathToken:unknownPath];
                }
                return newPath;
            });
            
            annotation.URL = [NSURL fileURLWithPath:link];
        }else {
            annotation.URL = [[NSURL alloc] initWithUnicodeString_pspdf:link];
        }

        // Set to undefined if file doesn't exist
        if ([annotation.URL isFileURL] && ![[NSFileManager new] fileExistsAtPath:[annotation.URL path]]) {
            annotation.type = PSPDFAnnotationTypeUndefined;
        }else {
            NSString *loLink = [link lowercaseString];
            if ([loLink hasSuffix:@"m3u8"] || [loLink hasSuffix:@"mov"] ||
                [loLink hasSuffix:@"mpg"] || [loLink hasSuffix:@"avi"] || [loLink hasSuffix:@"m4v"]) {
                annotation.type = PSPDFAnnotationTypeVideo;
            }
            else if([loLink hasSuffix:@"mp3"] || [loLink hasSuffix:@"m4a"] || [loLink hasSuffix:@"mp4"]) {
                annotation.type = PSPDFAnnotationTypeAudio;
            }else if([loLink rangeOfString:@"youtube.com/"].length > 0) {
                annotation.type = PSPDFAnnotationTypeYouTube;
            }else if([loLink hasSuffix:@"jpg"] || [loLink hasSuffix:@"png"]  || [loLink hasSuffix:@"tiff"]|| [loLink hasSuffix:@"tif"] || [loLink hasSuffix:@"gif"]
                     || [link hasSuffix:@"bmp"] || [loLink hasSuffix:@"bmpf"] || [loLink hasSuffix:@"ico"] || [loLink hasSuffix:@"cur"] || [loLink hasSuffix:@"xbm"]) {
                annotation.type = PSPDFAnnotationTypeImage;
            }else {
                // fallback if type is not recognized.
                annotation.type = PSPDFAnnotationTypeBrowser;
                
                // check if we may want a link to an external browser window instead.
                if (annotation.isModal || annotation.isPopover) {
                    annotation.type = PSPDFAnnotationTypeLink;
                }
            }
            
            // force annotation to be of a specific type
            if ([[linkOptions objectForKey:@"type"] isKindOfClass:[NSString class]]) {
                NSString *manualType = [[linkOptions objectForKey:@"type"] lowercaseString];
                if ([manualType hasSuffix:@"video"]) {
                    annotation.type = PSPDFAnnotationTypeVideo;
                }else if ([manualType hasSuffix:@"audio"]) {
                    annotation.type = PSPDFAnnotationTypeAudio;
                }else if ([manualType hasSuffix:@"youtube"]) {
                    annotation.type = PSPDFAnnotationTypeYouTube;
                }else if ([manualType hasSuffix:@"link"]) {
                    annotation.type = PSPDFAnnotationTypeLink;
                }else if ([manualType hasSuffix:@"image"]) {
                    annotation.type = PSPDFAnnotationTypeImage;
                }else if ([manualType hasSuffix:@"browser"]) {
                    annotation.type = PSPDFAnnotationTypeBrowser;
                }else {
                    PSPDFLogWarning(@"Unknown type specified: %@", manualType);
                }
            }
        }
        
        // be specific, so that we can have workaround for Keynote/iBookAuthor limitation for custom protocol in 'webpage' hyperlink, eg if we have myprotocol://, Keynote disallows this, but allows http:myprotocol://
    }else if(![[link lowercaseString] hasPrefix:@"http://"] && ![[link lowercaseString] hasPrefix:@"https://"] && ![[link lowercaseString] hasPrefix:@"mailto:"]) {
        annotation.type = PSPDFAnnotationTypeCustom;        
    }else {
        annotation.type = PSPDFAnnotationTypeLink;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (PSPDFAnnotationType)annotationTypeForDictionary:(CGPDFDictionaryRef)annotationDictionary document:(CGPDFDocumentRef)documentRef {
    //identifies and validates the given annotation dictionary
    const char *annotationType;
    CGPDFDictionaryGetName(annotationDictionary, "Subtype", &annotationType);
    PSPDFAnnotationType type;
    
    // Link annotations are identified by Link name stored in Subtype key in annotation dictionary.
    if (strcmp(annotationType, "Link") == 0) {
        // as per previous commits
        type = PSPDFAnnotationTypePage;
        
    } else if (strcmp(annotationType, "Highlight") == 0) {
        type = PSPDFAnnotationTypeHighlight;
    } else {
        type = PSPDFAnnotationTypeUndefined;
    }
    
    return type;
}

- (void)parsePageAnnotation:(PSPDFAnnotation *)annotation dictionary:(CGPDFDictionaryRef)annotationDictionary document:(CGPDFDocumentRef)documentRef {
    // Link target can be stored either in A entry or in Dest entry in annotation dictionary.
    // Dest entry is the destination array that we're looking for. It can be a direct array definition
    // or a name. If it is a name, we need to search recursively for the corresponding destination array 
    // in document's Dests tree.
    // A entry is an action dictionary. There are many action types, we're looking for GoTo and URI actions.
    // GoTo actions are used for links within the same document. The GoTo action has a D entry which is the
    // destination array, same format like Dest entry in annotation dictionary.
    // URI actions are used for links to web resources. The URI action has a 
    // URI entry which is the destination URL.
    // If both entries are present, A entry takes precedence.
    
    CGPDFArrayRef destArray = NULL;
    CGPDFDictionaryRef actionDictionary = NULL;
    if (CGPDFDictionaryGetDictionary(annotationDictionary, "A", &actionDictionary)) {
        const char* actionType;
        if (CGPDFDictionaryGetName(actionDictionary, "S", &actionType)) {
            if (strcmp(actionType, "GoTo") == 0) {
                if(!CGPDFDictionaryGetArray(actionDictionary, "D", &destArray)) {
                    // D is not an array but a named reference?
                    CGPDFStringRef destNameRef;
                    if (CGPDFDictionaryGetString(actionDictionary, "D", &destNameRef)) {
                        NSString *destinationName = CFBridgingRelease(CGPDFStringCopyTextString(destNameRef));
                        NSMutableSet *annotations = [namedDestinations_ objectForKey:destinationName];
                        if (!annotations) {
                            annotations = [NSMutableSet set];
                            [namedDestinations_ setObject:annotations forKey:destinationName];
                        }
                        [annotations addObject:annotation];
                    }
                }
            }
            if (strcmp(actionType, "URI") == 0) {
                CGPDFStringRef uriRef = NULL;
                if (CGPDFDictionaryGetString(actionDictionary, "URI", &uriRef)) {
                    CFStringRef uriStringRef = CGPDFStringCopyTextString(uriRef);
                    if (uriStringRef) {
                        // URLs need to be encoded to UTF8 (we decode them later, but this is needed for punycode url support)
                        annotation.siteLinkTarget = CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, uriStringRef, CFSTR("")));
                        CFRelease(uriStringRef);
                    }
                    [self parseAnnotationLinkTarget:annotation];
                }
            }
        }
    } else {
        // Dest entry can be either a string object or an array object.
        if (!CGPDFDictionaryGetArray(annotationDictionary, "Dest", &destArray)) {
            CGPDFStringRef destName;
            if (CGPDFDictionaryGetString(annotationDictionary, "Dest", &destName)) {
                // Traverse the Dests tree to locate the destination array.
                CGPDFDictionaryRef catalogDictionary = CGPDFDocumentGetCatalog(documentRef);
                CGPDFDictionaryRef namesDictionary = NULL;
                if (CGPDFDictionaryGetDictionary(catalogDictionary, "Names", &namesDictionary)) {
                    CGPDFDictionaryRef destsDictionary = NULL;
                    if (CGPDFDictionaryGetDictionary(namesDictionary, "Dests", &destsDictionary)) {
                        const char *destinationName = (const char *)CGPDFStringGetBytePtr(destName);
                        destArray = [self findDestinationByName:destinationName inDestsTree: destsDictionary];
                    }
                }
            }
        }
    }
    
    if (destArray != NULL) {
        long int targetPageNumber = 0;
        // First entry in the array is the page the links points to.
        CGPDFDictionaryRef pageDictionaryFromDestArray = NULL;
        if (CGPDFArrayGetDictionary(destArray, 0, &pageDictionaryFromDestArray)) {
            size_t documentPageCount = CGPDFDocumentGetNumberOfPages(documentRef);
            for (int i = 1; i <= documentPageCount; i++) {
                CGPDFPageRef page = CGPDFDocumentGetPage(documentRef, i);
                CGPDFDictionaryRef pageDictionaryFromPage = CGPDFPageGetDictionary(page);
                if (pageDictionaryFromPage == pageDictionaryFromDestArray) {
                    targetPageNumber = i;
                    break;
                }
            }
        } else {
            // Some PDF generators use incorrectly the page number as the first element of the array 
            // instead of a reference to the actual page.
            CGPDFInteger pageNumber = 0;
            if (CGPDFArrayGetInteger(destArray, 0, &pageNumber)) {
                targetPageNumber = pageNumber + 1;
            }
        }
        
        if (targetPageNumber > 0) {
            annotation.pageLinkTarget = targetPageNumber;
            annotation.type = PSPDFAnnotationTypeLink;
        }
    }
}

- (void)parseHighlightAnnotation:(PSPDFAnnotation *)annotation dictionary:(CGPDFDictionaryRef)annotationDictionary document:(CGPDFDocumentRef)documentRef {
    //trying to figure out if anything needs to go here...
}

- (CGPDFArrayRef)findDestinationByName:(const char *)destinationName inDestsTree:(CGPDFDictionaryRef)node {
    CGPDFArrayRef destinationArray = NULL;
    CGPDFArrayRef limitsArray = NULL;
    
    // speed up search with respecting the limits table
    if (CGPDFDictionaryGetArray(node, "Limits", &limitsArray)) {
        CGPDFStringRef lowerLimit = NULL;
        CGPDFStringRef upperLimit = NULL;
        if (CGPDFArrayGetString(limitsArray, 0, &lowerLimit)) {
            if (CGPDFArrayGetString(limitsArray, 1, &upperLimit)) {
                const unsigned char *ll = CGPDFStringGetBytePtr(lowerLimit);
                const unsigned char *ul = CGPDFStringGetBytePtr(upperLimit);
                if ((strcmp(destinationName, (const char*)ll) < 0) ||
                    (strcmp(destinationName, (const char*)ul) > 0)) {
                    return NULL;
                }
            }
        }
    }
    
    CGPDFArrayRef namesArray = NULL;
    if (CGPDFDictionaryGetArray(node, "Names", &namesArray)) {
        size_t namesCount = CGPDFArrayGetCount(namesArray);
        for (int i = 0; i < namesCount; i = i + 2) {
            CGPDFStringRef destName;
            if (CGPDFArrayGetString(namesArray, i, &destName)) {
                const unsigned char *dn = CGPDFStringGetBytePtr(destName);
                if (strcmp((const char*)dn, destinationName) == 0) {
                    CGPDFDictionaryRef destinationDictionary = NULL;
                    if (CGPDFArrayGetDictionary(namesArray, i + 1, &destinationDictionary)) {
                        if (CGPDFDictionaryGetArray(destinationDictionary, "D", &destinationArray)) {
                            return destinationArray;
                        }
                    }
                }
            }
        }
    }
    
    CGPDFArrayRef kidsArray = NULL;
    if (CGPDFDictionaryGetArray(node, "Kids", &kidsArray)) {
        size_t kidsCount = CGPDFArrayGetCount(kidsArray);
        for (int i = 0; i < kidsCount; i++) {
            CGPDFDictionaryRef kidNode = NULL;
            if (CGPDFArrayGetDictionary(kidsArray, i, &kidNode)) {
                destinationArray = [self findDestinationByName: destinationName inDestsTree: kidNode];
                if (destinationArray != NULL) {
                    return destinationArray;
                }
            }
        }
    }
    
    return NULL;
}

@end
