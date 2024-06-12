//
//  PSPDFCache.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFCache.h"
#import "PSPDFKit.h"
#import "PSPDFKitGlobal.h"
#import "UIImage+PSPDFKitAdditions.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#import <libkern/OSAtomic.h>

// for debugging
#ifdef kPSPDFKitAllowMemoryDebugging
#import <mach/mach.h>
#import <mach/mach_host.h>
#endif
#import <objc/runtime.h>

// time tracking
#include <stdint.h>
#include <mach/mach_time.h>

#define kPSPDFCacheTimerInterval 0.5f
#define kPSPDFCachePause (PSPDFIsCrappyDevice() ? 0.3f : 0.1f)

@interface PSPDFCache()

@property(nonatomic, strong) dispatch_queue_t delegateQueue;      // syncs access for the delegates_ set
@property(nonatomic, strong) dispatch_queue_t cacheMgmtQueue;     // syncs adding/releasing queuedItems_/queuedDocuments_
@property(nonatomic, strong) dispatch_queue_t fileMgmtQueue;      // syncs fileMgmtQueue_
@property(nonatomic, strong) dispatch_queue_t cacheRequestQueue;  // syncs access for adding/removing queue requests
@property(nonatomic, strong) NSMutableDictionary *cachedFiles;
@property(nonatomic, strong) NSMutableArray *queuedItems;     // PSPDFCacheQueuedDocument
@property(nonatomic, strong) NSMutableArray *queuedDocuments; // PSPDFCacheQueuedDocument
@property(nonatomic, strong) NSOperationQueue *cacheQueue;
@property(nonatomic, strong) NSTimer *cacheTimer;
@property(nonatomic, strong) NSMutableSet *delegates;
@property(nonatomic, strong) NSMutableSet *pauseServices;

- (BOOL)enqueueItem:(PSPDFCacheQueuedDocument *)item;
- (void)cacheNextDocumentInStack;
- (void)timerFired;
@property(strong, readonly) NSCache *thumbnailCache;
@property(strong, readonly) NSCache *fullPageCache;
@property(nonatomic, strong) NSString *cachedCacheDirectory;
@property(assign, getter=isCacheFileDictLoaded) BOOL cacheFileDictLoaded;

@end

inline void dispatch_sync_reentrant(const void *key, dispatch_queue_t queue, dispatch_block_t block) {
//    dispatch_get_current_queue() == queue ? block() : dispatch_sync(queue, block);
    (dispatch_get_specific(key) == (__bridge void *)(queue)) ? block() : dispatch_sync(queue, block);
}

@implementation PSPDFCache

@synthesize strategy = strategy_;
@synthesize numberOfMaximumCachedDocuments = numberOfMaximumCachedDocuments_;
@synthesize numberOfNearCachedPages = numberOfNearCachedPages_;
@synthesize thumbnailCache = thumbnailCache_;
@synthesize fullPageCache = fullPageCache_;
@synthesize useJPGFormat = useJPGFormat_;
@synthesize useJPGTurbo = useJPGTurbo_;
@synthesize JPGFormatCompression = JPGFormatCompression_;
@synthesize downscaleInterpolationQuality = _downscaleInterpolationQuality;
@synthesize thumbnailSize = thumbnailSize_;
@synthesize tinySize = tinySize_;
@synthesize cacheDirectory = cacheDirectory_;
@synthesize cachedCacheDirectory = cachedCacheDirectory_;
@synthesize cacheFileDictLoaded = cacheFileDictLoaded_;
@synthesize queuedDocuments = queuedDocuments_;
@synthesize queuedItems = queuedItems_;
@synthesize cacheQueue = cacheQueue_;
@synthesize delegateQueue = delegateQueue_;
@synthesize cacheMgmtQueue = cacheMgmtQueue_;
@synthesize fileMgmtQueue = fileMgmtQueue_;
@synthesize cacheRequestQueue = cacheRequestQueue_;
@synthesize cachedFiles = cachedFiles_;
@synthesize cacheTimer = cacheTimer_;
@synthesize delegates = delegates_;
@synthesize pauseServices = pauseServices_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - private

static OSSpinLock pauseServiceSpinLock_;

// dispatch queue that synchronizes access to delegates_
static const void * const delegateQueueKey = (const void*)&delegateQueueKey;
- (dispatch_queue_t)delegateQueue {
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_queue_create("com.petersteinberger.pspdfkit.pspdfcache.delegateQueue", NULL);
        self.delegateQueue = queue;
        dispatch_queue_set_specific(queue, delegateQueueKey, (__bridge void *)(queue), NULL);
	});
	return delegateQueue_;
}

// dispatch queue that synchronizes access to queuedItems_, queuedDocuments_
static const void * const cacheMgmtQueueKey = (const void*)&cacheMgmtQueueKey;
- (dispatch_queue_t)cacheMgmtQueue {
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_queue_create("com.petersteinberger.pspdfkit.pspdfcache.cacheManagementQueue", NULL);
        self.cacheMgmtQueue = queue;
        dispatch_queue_set_specific(queue, cacheMgmtQueueKey, (__bridge void *)(queue), NULL);
	});
	return cacheMgmtQueue_;
}

// synchronizes access to cachedFiles_
static const void * const fileMgmtQueueKey = (const void*)&fileMgmtQueueKey;
- (dispatch_queue_t)fileMgmtQueue {
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_queue_create("com.petersteinberger.pspdfkit.pspdfcache.fileQueue", NULL);
        self.fileMgmtQueue = queue;
        dispatch_queue_set_specific(queue, fileMgmtQueueKey, (__bridge void *)(queue), NULL);
	});
	return fileMgmtQueue_;
}

// sync access to add queue requests
static const void * const cacheRequestQueueKey = (const void*)&cacheRequestQueueKey;
- (dispatch_queue_t)cacheRequestQueue {
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_queue_create("com.petersteinberger.pspdfkit.pspdfcache.cacheRequestQueue", NULL);
        self.cacheRequestQueue = queue;
        dispatch_queue_set_specific(queue, cacheRequestQueueKey, (__bridge void *)(queue), NULL);
	});
	return cacheRequestQueue_;
}

- (NSUInteger)numberOfConcurrentCacheOperations {
    // run only one caching thead on crappy devices, more threads on all other.
    return PSPDFIsCrappyDevice() ? 2 : 4;
}

// return *cahced* cache folder
- (NSString *)cachedCacheDirectory {
    if (!cachedCacheDirectory_) {
        // NSSearchPathForDirectoriesInDomains is slow!
        NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:self.cacheDirectory];
        cachedCacheDirectory_ = cacheFolder;
    }
    return cachedCacheDirectory_;
}

// return cache folder for specific document
- (NSString *)cachedImagePathForDocument:(PSPDFDocument *)aDocument {
    if (!aDocument.uid) {
        PSPDFLogWarning(@"document has empty uid, cannot build cache path!");
        return nil;
    }
    
    NSString *cacheFolder = self.cachedCacheDirectory;
    NSString *DocumentCacheFolder = [cacheFolder stringByAppendingPathComponent:aDocument.uid];    
    return DocumentCacheFolder;
}

- (NSString *)cachedImageFileNameForPage:(NSUInteger)page size:(PSPDFSize)size {
    NSUInteger humanPage = page + 1;
    NSString *formatString = self.useJPGFormat ? @"jpg" : @"png";
    char pageFormat;
    
    if (size == PSPDFSizeNative) {
        pageFormat = 'p';
    }else if(size == PSPDFSizeThumbnail) {
        pageFormat = 't';
    }else { // tiny
        pageFormat = 'y';
    }
    
    NSString *newCurrentPdfFileName = [NSString stringWithFormat:@"%c%lu.%@", pageFormat, (unsigned long)humanPage, formatString];
    return newCurrentPdfFileName;
}

// returns full path to a cached image
- (NSString *)cachedImageFilePathForDocument:(PSPDFDocument *)aDocument page:(NSUInteger)page size:(PSPDFSize)size {
    NSString *DocumentCacheFolder = [self cachedImagePathForDocument:aDocument];
    NSString *newCurrentPdfFileName = [self cachedImageFileNameForPage:page size:size];
    NSString *completeFileName = [DocumentCacheFolder stringByAppendingPathComponent:newCurrentPdfFileName];
    return completeFileName;
}

// filesystem is crawled for already cached files (file-exist cache)
- (void)loadCachedFilesArray {    
    dispatch_async([self fileMgmtQueue], ^{
        PSPDFLog(@"loading cache files from disk...");
        [self.cachedFiles removeAllObjects];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSError *error = nil;
        NSString *cacheFolder = [self cachedCacheDirectory];    
        NSArray *cacheFolders = [fileManager contentsOfDirectoryAtPath:cacheFolder error:&error];
        
        // create cache entry for every cache folder
        for (NSString *documentCacheFolder in cacheFolders) {
            NSArray *folderContents = [fileManager contentsOfDirectoryAtPath:[cacheFolder stringByAppendingPathComponent:documentCacheFolder] error:&error];
            if ([folderContents count]) {
                NSMutableSet *set = [NSMutableSet set];
                [self.cachedFiles setObject:set forKey:documentCacheFolder];
                [set addObjectsFromArray:folderContents];
            }
        }
        self.cacheFileDictLoaded = YES;
    });
}

// add a file to the file-exist cache (checking if a file exists on disk is slow!)
- (void)addFileToExistCacheForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    dispatch_sync_reentrant(fileMgmtQueueKey, [self fileMgmtQueue], ^{
        NSMutableSet *cachedFileSet = [self.cachedFiles objectForKey:document.uid];
        if (!cachedFileSet) {
            cachedFileSet = [NSMutableSet set];
            [self.cachedFiles setObject:cachedFileSet forKey:document.uid];
        }
        NSString *fileName = [self cachedImageFileNameForPage:page size:size];
        [cachedFileSet addObject:fileName];
    });
}

// removes a file from the file-exist cache
- (void)removeFileFromExistCacheForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    dispatch_sync_reentrant(fileMgmtQueueKey, [self fileMgmtQueue], ^{
        NSMutableSet *cachedFileSet = [self.cachedFiles objectForKey:document.uid];
        if (cachedFileSet) {
            NSString *fileName = [self cachedImageFileNameForPage:page size:size];
            [cachedFileSet removeObject:fileName];
        }
    });
}

// calculate optimal scaling for a page
- (CGFloat)scaleForImageSize:(CGSize)imageSize size:(PSPDFSize)size {
    CGSize boundsSize;
    if (size == PSPDFSizeThumbnail) {
        boundsSize = self.thumbnailSize;
    }else if(size == PSPDFSizeTiny) {
        boundsSize = self.tinySize;
    }else {
        // PSPDFSizeNative, removes size of the statusBar if visible
        boundsSize = [[UIScreen mainScreen] bounds].size;   // PSPDFSizeNative
        // TODO: 先注释掉，会有很严重的卡顿
//        if (![UIApplication sharedApplication].statusBarHidden) {
//            CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
//            CGFloat height = statusBarFrame.size.height < statusBarFrame.size.width ? statusBarFrame.size.height : statusBarFrame.size.width;
//            boundsSize.height -= height;
//        }
        
        // we can't use applicationFrame, as it takes landscape into account, and we only render portrait mode here.
        //boundsSize = [[UIScreen mainScreen] applicationFrame].size;
        
        // always generate maximum size for native resolution (e.g. if document is larger in landscape, use that)
        if (imageSize.width > imageSize.height) {
            boundsSize = CGSizeMake(boundsSize.height, boundsSize.width);
        }
    }
    
    // use default settings
    CGFloat scale = PSPDFScaleForSizeWithinSize(imageSize, boundsSize);
    return scale;
}

// calling delegates for document in main thread
- (void)callDelegatesForDocument:(PSPDFDocument *)aDocument page:(NSUInteger)aPage image:(UIImage *)cachedImage size:(PSPDFSize)size {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_sync_reentrant(delegateQueueKey, [self delegateQueue], ^{
            for (id<PSPDFCacheDelegate> aDelegate in self.delegates) {
                [aDelegate didCachePageForDocument:aDocument page:aPage image:cachedImage size:size];
            }
        });
    });
}

- (void)callDelegatesForDocument:(PSPDFDocument *)aDocument {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_sync_reentrant(delegateQueueKey, [self delegateQueue], ^{
            for (id<PSPDFCacheDelegate> aDelegate in self.delegates) {
                if ([aDelegate respondsToSelector:@selector(didFinishCachingDocument:)]) {
                    [aDelegate didFinishCachingDocument:aDocument];
                }
            }
        });
    });
}

- (PSPDFCacheQueuedDocument *)queuedDocumentFromDocument:(PSPDFDocument *)document size:(PSPDFSize)size {
    NSArray *queuedDocuments = [self queuedDocumentsFromDocument:document];
    for (PSPDFCacheQueuedDocument *queuedDocument in queuedDocuments) {
        if (queuedDocument.size == size) {
            return queuedDocument;
        }
    }
    return nil;
}

- (NSArray *)queuedDocumentsFromDocument:(PSPDFDocument *)document {
    __block NSMutableArray *queuedDocuments = [NSMutableArray array];
    
    dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
        for (PSPDFCacheQueuedDocument *aQueuedItem in self.queuedDocuments) {
            if ([aQueuedItem.document isEqual:document]) {
                [queuedDocuments addObject:aQueuedItem];
            }
        }
    });
    
    return queuedDocuments; // not returning an immutable copy, as this is a private method anyways
}

// determine if page should be pre-cached
- (BOOL)shouldMemoryCacheFullPage:(NSUInteger)page forDocument:(PSPDFDocument *)document {
    NSInteger range = ABS(document.displayingPdfController.realPage - page);
    BOOL isNearPage = document.displayingPdfController && range <= floorf(self.numberOfMaximumCachedDocuments/2);
    BOOL isMemCached = [self imageForDocument:document page:page size:PSPDFSizeNative] != nil;
    BOOL shouldMemoryCacheFullPage = isNearPage && !isMemCached;
    if (shouldMemoryCacheFullPage) {
        PSPDFLogVerbose(@"shouldMemoryCacheFullPage:%ld -> YES", (long)page);
    }
    return shouldMemoryCacheFullPage;
}

// determine depending on the caching strategy if we should save the page on disk
- (BOOL)shouldSaveCachedImageForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    // cannot cache of uid is not set.
    if (!document.uid) {
        return NO;
    }
    
    BOOL shouldSave = NO;
    switch (self.strategy) {            
        case PSPDFCacheOnlyThumbnailsAndNearPages: {
            PSPDFCacheQueuedDocument *queuedInfo = [self queuedDocumentFromDocument:document size:size];
            if (size != PSPDFSizeNative || (queuedInfo && ABS(queuedInfo.page - page) < self.numberOfNearCachedPages)) {
                shouldSave = YES;
            }
        }break;
            
        case PSPDFCacheOpportunistic: { // opportunistic caching saves everything, clears later.
            shouldSave = YES;
        }break;
            
        case PSPDFCacheNothing:
        default:
            break;
    }
    
    return shouldSave;
}

// page starts at 0.
- (void)saveCachedImage:(UIImage *)renderedImage document:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    if ([self shouldSaveCachedImageForDocument:document page:page size:size]) {
        
        // check that the cache folder exists.
        NSString *documentCacheFolder = [self cachedImagePathForDocument:document];        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSError *error = nil;
        if (![fileManager fileExistsAtPath:documentCacheFolder]) {
            [fileManager createDirectoryAtPath:documentCacheFolder withIntermediateDirectories:YES attributes:nil error:&error];
        }            
        
        NSData *imageData;
        NSString *cachedImagePathForDocumentPage = [self cachedImageFilePathForDocument:document page:page size:size];
        
        if (self.useJPGFormat) {
            imageData = [NSData dataWithData:UIImageJPEGRepresentation(renderedImage, self.JPGFormatCompression)];
        }else {
            imageData = [NSData dataWithData:UIImagePNGRepresentation(renderedImage)];            
        }
        
        // writing is slow
        if(![imageData writeToFile:cachedImagePathForDocumentPage options:NSDataWritingAtomic error:&error]) {
            PSPDFLogWarning(@"Error while writing image: %@", [error localizedDescription]);
        }
        PSPDFLogVerbose(@"Wrote fullsize page %lu: %@", (unsigned long)page, [self cachedImageFileNameForPage:page size:size]);
        
        // add to cachedFiles file-exist cache
        [self addFileToExistCacheForDocument:document page:page size:size];
    }
}

- (UIImage *)renderImageForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size pdfPage:(CGPDFPageRef)pdfPage {
    if (!pdfPage) {
        return nil; // if we didn't get a lock, return here. will try later again!
    }
    
    // determine the size of the PDF page
    PSPDFPageInfo *pageInfo = [document pageInfoForPage:page pageRef:pdfPage];
    NSInteger pageRotation = pageInfo.pageRotation;
    CGRect cropBox = pageInfo.pageRect;
    if ((pageRotation == 0) || (pageRotation == 180) || (pageRotation == -180)) {
        // noop
    }else {
        ps_swapf(cropBox.size.width, cropBox.size.height);
    }
    
    // we're building the thumbnail here, don't send tiny size. Will reduce later!
    CGFloat pdfScale = [self scaleForImageSize:cropBox.size size:size];
    cropBox.size = PSPDFSizeForScale(cropBox.size, pdfScale);
    
    UIImage *renderedImage = nil;    
    UIGraphicsBeginImageContextWithOptions(cropBox.size, YES, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (!context) {
        PSPDFLogError(@"graphics context is nil - low memory?");
        UIGraphicsEndImageContext();
        return nil;
    }
    
    // render pdf page
    [PSPDFPageRenderer renderPage:pdfPage inContext:context inRectangle:PSRectClearCoords(cropBox) pageInfo:pageInfo interpolationQuality:self.downscaleInterpolationQuality];
    
    // callback for custom overlay drawing
    if ([document shouldDrawOverlayRectForSize:size]) {
        [document drawOverlayRect:cropBox inContext:context forPage:page zoomScale:1.f size:size];    
    }
    
    // draw demo string. is a no-op in full mode
    if (size == PSPDFSizeNative) {
        DrawPSPDFKit(context);
    }
    
    renderedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext(); 
    
    return renderedImage;
}

- (void)saveNativeRenderedImage:(UIImage *)image document:(PSPDFDocument *)document page:(NSUInteger)page {
    [self callDelegatesForDocument:document page:page image:image size:PSPDFSizeNative];
    [self saveCachedImage:image document:document page:page size:PSPDFSizeNative];
    PSPDFLog(@"image rendering complete: %@, page:%lu", document, (unsigned long)page);
}

// creats a single pdf image out of a Document. method is not exposed.
- (UIImage *)createSinglePDFImageForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size error:(NSError **)error {
    if (page >= [document pageCount]) {
        PSPDFLogWarning(@"Requested Page does not exist: %lu (pageCount: %lu, document: %@)", (unsigned long)page, (unsigned long)[document pageCount], document);
        if(error != nil) {
            *error = [NSError errorWithDomain:kPSPDFErrorDomain code:PSPDFErrorCodeUnknown userInfo:nil];
        }
        return nil;
    }
    PSPDFLogVerbose(@"Caching page %lu for %@ (size:%d)", (unsigned long)page, document.title, size);
    
    // rendered size may differ from requested size (optimizations)
    PSPDFSize renderedSize = (size == PSPDFSizeTiny) ? PSPDFSizeThumbnail : size;
    
    // if we want a tiny image, and the thumbnail is already there, use it (and skip pdf rendering)
    BOOL isCached = NO;
    UIImage *renderedImage = nil;
    if (size == PSPDFSizeTiny && [self isImageCachedForDocument:document page:page size:PSPDFSizeThumbnail]) {
        // load thumbnail from disk or cache
        renderedImage = [self cachedImageForDocument:document page:page size:PSPDFSizeThumbnail];
        isCached = YES;
    }
    
    // render pdf (unless already loaded)
    if (!renderedImage) {
        // open pdf
        CGPDFPageRef pdfPage = [[PSPDFGlobalLock sharedPSPDFGlobalLock] tryLockWithDocument:document page:page error:error];
        if (!pdfPage) {
            return nil;
        }
        
        renderedImage = [self renderImageForDocument:document page:page size:renderedSize pdfPage:pdfPage];
        [[PSPDFGlobalLock sharedPSPDFGlobalLock] freeWithPDFPageRef:pdfPage];
    }
    
    if (!renderedImage) {
        PSPDFLogError(@"rendered image is missing. stopping here! Delegates will not be called.");
        return nil;
    }
    
    // save image, call delegates
    if (size == PSPDFSizeNative) {
        [self callDelegatesForDocument:document page:(NSUInteger)page image:renderedImage size:size];
    }
    
    [self saveCachedImage:renderedImage document:document page:page size:renderedSize];
    PSPDFLog(@"Cached page %lu %@ (size:%d).", (unsigned long)page, document.title, size);
    
    // if size is tiny, we'll have to recode image
    if (size == PSPDFSizeTiny) {
        // internally, we created a thumbnail - send events for it!
        if (!isCached) {
            [self cacheImage:renderedImage document:document page:page size:PSPDFSizeThumbnail];
        }
        // tiny listeners listen for thumbnail too.
        [self callDelegatesForDocument:document page:page image:renderedImage size:PSPDFSizeThumbnail];
        
        // now reduce size to tiny
        CGFloat reduceFactor = [self scaleForImageSize:self.thumbnailSize size:size];
        CGSize tinySize = CGSizeMake(ceilf(reduceFactor*renderedImage.size.width), ceilf(reduceFactor*renderedImage.size.height));
        renderedImage = [renderedImage pspdf_imageToFitSize:tinySize method:PSPDFImageResizeCrop honorScaleFactor:YES];
        [self saveCachedImage:renderedImage document:document page:page size:size];        
    }
    
    // save image in thumbnail cache
    if (size != PSPDFSizeNative || [self shouldMemoryCacheFullPage:page forDocument:document]) {
        [self cacheImage:renderedImage document:document page:page size:size];
    }
    
    // must be at the very bottom for the way we create tiny images
    if (size != PSPDFSizeNative) {
        [self callDelegatesForDocument:document page:(NSUInteger)page image:renderedImage size:size];
    }
    if (!renderedImage) {
        PSPDFLogError(@"failed to render image for %@, page %lu", document, (unsigned long)page);
    }
    
    return renderedImage;
}

- (void)cacheNextDocumentInStack {
    PSPDFLogVerbose(@"--cacheNextDocumentInStack--");
    
    // first check the queued items
    __block PSPDFCacheQueuedDocument *cacheRequest = nil;
    __block BOOL isCachingItems = NO;
    dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
        // search a thumbnail request with prority, if not, use last in FIFO
        [self.queuedItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            PSPDFCacheQueuedDocument *aCacheRequest = (PSPDFCacheQueuedDocument *)obj;
            if (aCacheRequest.size != PSPDFSizeNative && !aCacheRequest.isCaching) {
                cacheRequest = aCacheRequest;
                *stop = YES;
            }
        }];
        
        // if no thumbnail request found, try again, this time use any request that's not currently running
        if (!cacheRequest) {
            [self.queuedItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                PSPDFCacheQueuedDocument *aCacheRequest = (PSPDFCacheQueuedDocument *)obj;
                if (!aCacheRequest.isCaching) {
                    cacheRequest = aCacheRequest;
                    *stop = YES;
                }else {
                    isCachingItems = YES;
                }
            }];
        }
    });
    
    if (cacheRequest) {
        PSPDFCacheQueuedDocument *request = cacheRequest;
        request.caching = YES;
        
        NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
        NSValue *weakOpValue = [NSValue valueWithNonretainedObject:blockOperation];
        
        [blockOperation addExecutionBlock:^{
            @autoreleasepool {
                PSPDFLogVerbose(@"starting operation for page: %lu, size:%d", (unsigned long)request.page, request.size);
                NSError *error = nil;
                
                PSPDFLogVerbose(@"BLOCK STARTED: %lu", (unsigned long)request.page);
                BOOL thumbnailCached = [self isImageCachedForDocument:request.document page:request.page size:request.size];
                BOOL shoudBeMemCached = [self shouldMemoryCacheFullPage:request.page forDocument:request.document];
                
                if (!thumbnailCached) {
                    UIImage *cachedImage = [self createSinglePDFImageForDocument:request.document page:request.page size:request.size error:&error];
                    if (error) {
                        PSPDFLogError(@"Error while caching: %@", error);
                    }
                    
                    if (!error && cachedImage) {
                        thumbnailCached = YES;
                    }else {
                        // reset caching status, try again.
                        if (![[weakOpValue nonretainedObjectValue] isCancelled]) {
                            [NSThread sleepForTimeInterval:kPSPDFCachePause]; // sleep some time (system is rendering...)
                        }
                        request.caching = NO;
                    }
                }else if(shoudBeMemCached && request.size == PSPDFSizeNative) {
                    // is intelligent enough to automaticallty memcache if needed
                    PSPDFLogVerbose(@"mem-caching page:%lu", (unsigned long)request.page);
                    [self cachedImageForDocument:request.document page:request.page size:PSPDFSizeNative preload:YES];
                }
                
                if (thumbnailCached || error) {
                    dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
                        if ([self.queuedItems indexOfObject:request] != NSNotFound) {
                            [self.queuedItems removeObject:request];
                        }});
                }
                
                // completion block
                if (![[weakOpValue nonretainedObjectValue] isCancelled]) {
                    [self timerFired];
                }
                
                PSPDFLogVerbose(@"BLOCK ENDED: %lu", (unsigned long)request.page);
            }
        }];
        
//        blockOperation.threadPriority = 0.1f; // perform when everything is idle!
        [cacheQueue_ addOperation:blockOperation];    
        //PSPDFLog(@"operations: %d, concurrent: %d (waiting: %d)", [cacheQueue_ operationCount], [cacheQueue_ maxConcurrentOperationCount], [cachedFiles_ count]);
    }
    // just go away if we're still caching
    else if(!isCachingItems) {
        
        // if we're still there, yet don't have a caching request, look into the queued documents
        __block PSPDFCacheQueuedDocument *cacheMasterRequest = nil;
        dispatch_sync_reentrant(cacheRequestQueueKey, [self cacheRequestQueue], ^{
            dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
                cacheMasterRequest = [self.queuedDocuments lastObject];
            });
            
            // create a cache request out of it!
            if (cacheMasterRequest) {        
                NSUInteger requestsCreated = 0;
                BOOL loopedOver = NO;
                for (NSInteger i=cacheMasterRequest.page; i >= 0;) {
                    
                    NSNumber *iNum = [NSNumber numberWithInteger:i];
                    BOOL isCached = [self isImageCachedForDocument:cacheMasterRequest.document page:i size:cacheMasterRequest.size];
                    BOOL shouldSave = [self shouldSaveCachedImageForDocument:cacheMasterRequest.document page:i size:cacheMasterRequest.size];
                    BOOL shoudBeMemCached = [self shouldMemoryCacheFullPage:i forDocument:cacheMasterRequest.document];
                    BOOL alreadyTriedToCache = [cacheMasterRequest.pagesCached containsObject:iNum];
                    
                    if ((!isCached && shouldSave) || (shoudBeMemCached && !alreadyTriedToCache)) {
                        [cacheMasterRequest.pagesCached addObject:iNum];
                        PSPDFCacheQueuedDocument *queueItem = [PSPDFCacheQueuedDocument queuedDocumentWithDocument:cacheMasterRequest.document page:i size:cacheMasterRequest.size];
                        BOOL requestCreated = [self enqueueItem:queueItem];
                        if (requestCreated) {
                            requestsCreated++;
                            
                            if (requestsCreated >= [self numberOfConcurrentCacheOperations]) {
                                break;
                            }
                        }
                    }
                    
                    // first, look at the FOLLOWING pages, then look BACKWARDS (intelligent caching)
                    NSInteger pageCount = [cacheMasterRequest.document pageCount];
                    if (!loopedOver && i >= pageCount-1) {
                        loopedOver = YES;
                        i = cacheMasterRequest.page;
                    }else if(loopedOver && i > pageCount) {
                        break; // quit special for loop
                    }
                    
                    if (!loopedOver) {
                        i++;
                    }else {
                        i--;
                    }
                }
                
                // if we created a request, great, call ourself and get out of here
                if (requestsCreated == 0) {
                    PSPDFLogVerbose(@"Document finished caching: %@", cacheMasterRequest.document);
                    dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
                        if ([self.queuedDocuments indexOfObject:cacheMasterRequest] != NSNotFound) {
                            [self.queuedDocuments removeObject:cacheMasterRequest];
                        }
                        BOOL moreJobsForDocument = NO;
                        for (PSPDFCacheQueuedDocument *item in self.queuedDocuments) {
                            if ([item.document isEqual:cacheMasterRequest.document]) {
                                moreJobsForDocument = YES;
                                break;
                            }
                        }
                        if (!moreJobsForDocument) {
                            [self callDelegatesForDocument:cacheMasterRequest.document];
                        }
                    });
                }
                
                // only fire if no operations are currently running
                if (!([self.cacheQueue operationCount] <= [self numberOfConcurrentCacheOperations]) && [self.queuedItems count]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                        [self cacheNextDocumentInStack];
                    });
                }
            }
        });
    }
}

- (void)timerFired {
    // start caching if there's stuff in the queue [and the operation queue is empty!
    NSUInteger operationCount = [cacheQueue_ operationCount];
    if (([queuedItems_ count] || [queuedDocuments_ count]) && operationCount < [self numberOfConcurrentCacheOperations]) {
        
        // don't call cacheNextDocumentInStack directly, or we can deadlock in PSPDFCache.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [self cacheNextDocumentInStack];
        });
    }
}

// enqueues an cache request in the current cache
- (BOOL)enqueueItem:(PSPDFCacheQueuedDocument *)item {
    if (!item.document) {
        PSPDFLogVerbose(@"Warning: Document is nil!");
        return NO;
    }
    
    __block BOOL success = NO;    
    dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
        
        // perform this inside the block because pageCount maybe is lazy evaluated and we would spawn a lot of threads otherwise
        if (item.page == NSNotFound || item.page >= [item.document pageCount]) {
            PSPDFLogWarning(@"Page is invalid: %lu (pageCount: %lu)", (unsigned long)item.page, (unsigned long)[item.document pageCount]);
        }else {
            
            PSPDFCacheQueuedDocument *queuedDocument = item;
            
            // queue is unique - if already in there, move to bottom!
            NSUInteger currentPos = [self.queuedItems indexOfObject:queuedDocument];
            if (currentPos != NSNotFound) {
                // preserve object! (cached status, etc)
                queuedDocument = [self.queuedItems objectAtIndex:currentPos];
                [self.queuedItems removeObjectAtIndex:currentPos];
            }
            
            // always add to bottom!
            [self.queuedItems addObject:queuedDocument];
            success = YES;
        }
    });
    
    return success;
}

// check filesystem, fild oldest Documents
- (void)clearOldCacheItems {
    // TODO - clean up code.
}

- (void)didReceiveMemoryWarning {
    // on memory warning, clear full page cache instantly
    [self.fullPageCache removeAllObjects];
    
    if (PSPDFIsCrappyDevice()) {
        [self.thumbnailCache removeAllObjects];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        // set useful defaults
        strategy_ = PSPDFCacheOpportunistic;
        numberOfMaximumCachedDocuments_ = PSPDFIsCrappyDevice() ? 3 : 7;
        numberOfNearCachedPages_ = 3;
        JPGFormatCompression_ = 0.9f;
        useJPGFormat_ = YES;
        useJPGTurbo_ = YES;
        
        _downscaleInterpolationQuality = kCGInterpolationHigh;
        thumbnailSize_ = CGSizeMake(200, 400);
        tinySize_ = CGSizeMake(50, 100);
        cacheDirectory_ = [@"PSPDFKit" copy];
        
        // alloc data structures
        queuedItems_ = [[NSMutableArray alloc] init];
        queuedDocuments_ = [[NSMutableArray alloc] init];
        pauseServices_ = [[NSMutableSet alloc] init];
        
        // delegate set is non-retaining
        delegates_ = (__bridge_transfer NSMutableSet *)CFSetCreateMutable(nil, 0, NULL);
        
        thumbnailCache_ = [[NSCache alloc] init];
        thumbnailCache_.name = @"PSPDFThumbnailCache";
        [thumbnailCache_ setCountLimit:PSPDFIsCrappyDevice() ? 50 : 100];
        thumbnailCache_.delegate = self;
        fullPageCache_ = [[NSCache alloc] init];
        fullPageCache_.name = @"PSPDFFullPageCache";
        [fullPageCache_ setCountLimit:numberOfMaximumCachedDocuments_];
        fullPageCache_.delegate = self;
        cachedFiles_ = [[NSMutableDictionary alloc] init];
        cacheQueue_ = [[NSOperationQueue alloc] init];
        cacheQueue_.name = @"PSPDFCacheQueue";
        cacheQueue_.maxConcurrentOperationCount = [self numberOfConcurrentCacheOperations];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
        // load cache in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [self loadCachedFilesArray];
        });
        
        // ensure timer is registered on main thread
        dispatch_async(dispatch_get_main_queue(), ^ {
            self.cacheTimer = [NSTimer scheduledTimerWithTimeInterval:kPSPDFCacheTimerInterval target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
        });
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
    dispatch_release(cacheMgmtQueue_);
    dispatch_release(fileMgmtQueue_);
    dispatch_release(cacheRequestQueue_);
    dispatch_release(delegateQueue_);
#endif
    [cacheTimer_ invalidate];
    [cacheQueue_ cancelAllOperations];
    [cacheQueue_ waitUntilAllOperationsAreFinished];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setCacheDirectory:(NSString *)aCacheDirectory {
    if (cacheDirectory_ != aCacheDirectory) {
        self.cachedCacheDirectory = nil;
        cacheDirectory_ = [aCacheDirectory copy];
    }
}

- (void)setNumberOfMaximumCachedDocuments:(NSUInteger)numberOfMaximumCachedDocuments {
    // ensure number is odd (or zero)
    if (numberOfMaximumCachedDocuments > 0 && numberOfMaximumCachedDocuments % 2 == 0) {
        numberOfMaximumCachedDocuments++;
    }
    numberOfMaximumCachedDocuments_ = numberOfMaximumCachedDocuments;
    [self.fullPageCache setCountLimit:numberOfMaximumCachedDocuments];
}

- (BOOL)isDocumentCached:(PSPDFDocument *)document size:(PSPDFSize)size {
    NSUInteger pageCount = [document pageCount];
    for (NSUInteger i = 0; i < pageCount; i++) {
        if (![self isImageCachedForDocument:document page:i size:size]) {
            return NO;
        }
    }
    return YES;
}

// check if document is cached. first check memory, then hit filesystem
- (BOOL)isImageCachedForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    // check own memory-cache
    __block BOOL cachedImageExists = [self imageForDocument:document page:page size:size] != nil;
    
    // check document solution (custom provided thumbs?)
    if(!cachedImageExists && size == PSPDFSizeThumbnail) {
        NSURL *externalThumbUrl = [document thumbnailPathForPage:page];
        
        // don't trust external sources
        cachedImageExists = [fileManager fileExistsAtPath:[externalThumbUrl path] isDirectory:nil];            
    }
    
    // check disk-store
    if (!cachedImageExists) {      
        // cache already available?
        if (self.isCacheFileDictLoaded) {
            NSSet *cachedFiles = [cachedFiles_ objectForKey:document.uid];
            NSString *fileName = [self cachedImageFileNameForPage:page size:size];
            cachedImageExists = [cachedFiles containsObject:fileName];
        }else {
            NSString *cachedImagePathForDocumentPage = [self cachedImageFilePathForDocument:document page:page size:size];
            
            // small performance hit, but protects us against wrong thumbnails paths
            cachedImageExists = [fileManager fileExistsAtPath:cachedImagePathForDocumentPage];            
        }
    }
    
#if TARGET_IPHONE_SIMULATOR
    // the device cache might change on the simulator, so check dimensions!
    if (cachedImageExists && size == PSPDFSizeNative) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *path = [self cachedImageFilePathForDocument:document page:page size:size];
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            CGFloat fuzzy = 100;
            if (image.size.height+fuzzy < screenSize.height && image.size.width+fuzzy < screenSize.width) {
                PSPDFLog(@"Images are in wrong size. Cleaning the cache for new device!");
                [self clearCache];
                cachedImageExists = NO;
            }
        });
    }
#endif
    
    return cachedImageExists;
}

- (UIImage *)cachedImageForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    return [self cachedImageForDocument:document page:page size:size preload:NO];
}

// Benchmark feature. Returns time in nanoseconds. (nsec/10E9 = seconds)
- (double)performAndTrackTime:(PSPDFBasicBlock)block trackTime:(BOOL)trackTime {
#ifndef kPSPDFBenchmark
    trackTime = NO;
#endif
    
    if (!trackTime) {
        block();
        return 0;
    }
    
    static double ticksToNanoseconds = 0.0;
    uint64_t startTime = mach_absolute_time();
    
    block();
    
    uint64_t endTime = mach_absolute_time();
    
    // Elapsed time in mach time units
    uint64_t elapsedTime = endTime - startTime;
    
    // The first time we get here, ask the system
    // how to convert mach time units to nanoseconds
    if (0.0 == ticksToNanoseconds) {
        mach_timebase_info_data_t timebase;
        // to be completely pedantic, check the return code of this next call.
        mach_timebase_info(&timebase);
        ticksToNanoseconds = (double)timebase.numer / timebase.denom;
    }
    
    double elapsedTimeInNanoseconds = elapsedTime * ticksToNanoseconds;
    // NSLog(@"seconds: %f", elapsedTimeInNanoseconds/10E9);
    return elapsedTimeInNanoseconds;
}

- (UIImage *)cachedImageForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size preload:(BOOL)preload {
    if (!document) {
        return nil;
    }
    
    // returns cached image of document. If not found, add to TOP of current caching queue.
    if (![self isImageCachedForDocument:document page:page size:size]) {
        PSPDFLogVerbose(@"cache miss for %lu", (unsigned long)page);
        
        // accesses pageCount, may be slow -> 
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            PSPDFCacheQueuedDocument *queueItem = [PSPDFCacheQueuedDocument queuedDocumentWithDocument:document page:page size:size];
            [self enqueueItem:queueItem];
        });
        
        return nil;
    }
    
    // first try to load via memory cache
    __block UIImage *cacheImage = [self imageForDocument:document page:page size:size];
    
    // custom document store
    if(!cacheImage && size == PSPDFSizeThumbnail) {
        cacheImage = [UIImage imageWithContentsOfFile:[[document thumbnailPathForPage:page] path]];
        if (cacheImage) {
            [self cacheImage:cacheImage document:document page:page size:size];
        }
    }
    
    // disk store
    if (!cacheImage) {
        NSString *cacheImagePath = [self cachedImageFilePathForDocument:document page:page size:size];
        
        BOOL trackTime = NO;
        
#ifdef kPSPDFBenchmark
        trackTime = YES;
        preload = YES;
#endif
        
        double nsec = [self performAndTrackTime:^{
            // if JPEGTurbo is enabled, we ignore the preload flag.
            if ([[cacheImagePath lowercaseString] hasSuffix:@"jpg"] && self.useJPGTurbo) {
                cacheImage = [UIImage pspdf_preloadedImageWithContentsOfFile:cacheImagePath useJPGTurbo:self.useJPGTurbo];
            }else {
                cacheImage = [[UIImage alloc] initWithContentsOfFile:cacheImagePath];
                if (preload) {
                    cacheImage = [cacheImage pspdf_preloadedImage];
                }
            }
        } trackTime:trackTime];
        
#ifdef kPSPDFBenchmark
        if (trackTime) {
            //NSLog(@"turbo:%d - milliseconds: %f", useJPGTurbo_, nsec/10E6);
        }
        
        static long long defaultRenderer = 0;
        static long long turboRenderer = 0;
        
        if (useJPGTurbo_) {
            turboRenderer += nsec;
        }else {
            defaultRenderer += nsec;
        }
        NSBlockOperation
        if (useJPGTurbo_) {
            // render again, for timing
            nsec = [self performAndTrackTime:^{
                cacheImage = [[UIImage alloc] initWithContentsOfFile:cacheImagePath];
                if (preload) {
                    cacheImage = [cacheImage pspdf_preloadedImage];
                }} trackTime:trackTime];
            
            //NSLog(@"turbo:%d - milliseconds: %f", NO, nsec/10E6);
            defaultRenderer += nsec;
        }
        //NSLog(@"default:%f - turbo: %f", defaultRenderer/10E6, turboRenderer/10E6);
#else
#pragma unused(nsec)
#endif
        // re-fill thumbnail cache
        if (cacheImage && (size != PSPDFSizeNative || [self shouldMemoryCacheFullPage:page forDocument:document])) {
            [self cacheImage:cacheImage document:document page:page size:size];
        }
    }
    
    return cacheImage;
}

// checks all files
- (void)cacheDocument:(PSPDFDocument *)document startAtPage:(NSUInteger)aPage size:(PSPDFSize)size {
    dispatch_async([self cacheRequestQueue], ^{
        NSUInteger page = aPage;
        if(!document) {
            PSPDFLogWarning(@"Document is nil.");
            return;
        }
        
        if(![document pageCount]) {
            PSPDFLogWarning(@"Document has zero pages. Not caching.");
            return;
        }
        
        if (page >= [document pageCount]) {
            PSPDFLogWarning(@"startPage:%lu to high, resetting to 1.", (unsigned long)page);
            page = 1;
        }    
        
        // manage queuedDocuments_ array, add new caching document request
        dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
            PSPDFCacheQueuedDocument *queueItem = [self queuedDocumentFromDocument:document size:size];
            // if not found, create new queue item, else update
            if (!queueItem) {
                PSPDFCacheQueuedDocument *newQueueItem = [PSPDFCacheQueuedDocument queuedDocumentWithDocument:document page:page size:size];
                [self.queuedDocuments addObject:newQueueItem];
            }else {
                queueItem.page = page;
                queueItem.size = size;
                [queueItem.pagesCached removeAllObjects]; // try again to cache.
            }
        });
        
        // fire up caching machinery!
        [self cacheNextDocumentInStack];
    });    
}

- (BOOL)cacheThumbnailsForDocument:(PSPDFDocument *)aDocument {
    BOOL willPreload = ![self isDocumentCached:aDocument size:PSPDFSizeTiny] || ![self isDocumentCached:aDocument size:PSPDFSizeThumbnail];
    [self cacheDocument:aDocument startAtPage:0 size:PSPDFSizeTiny];
    return willPreload;
}

// remove from cache dict
- (void)stopCachingDocument:(PSPDFDocument *)aDocument {
    if (!aDocument) {
        PSPDFLogVerbose(@"Called with nil document!");
        return;
    }
    
    // remove from queued documents
    dispatch_async([self cacheMgmtQueue], ^{
        [self.queuedDocuments removeObjectsInArray:[self queuedDocumentsFromDocument:aDocument]];
        
        NSArray *cachedItems = [self.queuedItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"document = %@", aDocument]];
        PSPDFLogVerbose(@"removing queued items: %@", self.queuedItems);
        if ([cachedItems count]) {
            [self.queuedItems removeObjectsInArray:cachedItems];
        }
    });
}

- (BOOL)pauseCachingForService:(id)service {
    if (!service) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Service is nil." userInfo:nil]; 
    }
    PSPDFLog(@"Adding %@ to the pause list.", service);
    
    OSSpinLockLock(&pauseServiceSpinLock_);
    BOOL cacheWillBePausedNow = NO;
    if (![pauseServices_ containsObject:service]) {
        [pauseServices_ addObject:service]; // ignores if already a member
        [cacheQueue_ setSuspended:YES];
        cacheWillBePausedNow = [pauseServices_ count] == 1;
    }
    OSSpinLockUnlock(&pauseServiceSpinLock_);
    
    return cacheWillBePausedNow;
}

- (BOOL)resumeCachingForService:(id)service {
    OSSpinLockLock(&pauseServiceSpinLock_);
    if (!service) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Service is nil" userInfo:nil]; 
    }
    
    PSPDFLog(@"Removing %@ from the pause list.", service);
    BOOL serviceIsInList = [pauseServices_ containsObject:service];
    if(serviceIsInList) {
        [pauseServices_ removeObject:service];
    }
    
    BOOL cacheWillContinue = serviceIsInList && [pauseServices_ count] == 0;
    if (serviceIsInList) {
        [cacheQueue_ setSuspended:!cacheWillContinue];
    }
    OSSpinLockUnlock(&pauseServiceSpinLock_);
    return cacheWillContinue;
}

- (void)addDelegate:(id<PSPDFCacheDelegate>)aDelegate {
    dispatch_sync_reentrant(delegateQueueKey, [self delegateQueue], ^{
        if (aDelegate) {
            [self.delegates addObject:aDelegate];
        }
    });
}

- (BOOL)removeDelegate:(id<PSPDFCacheDelegate>)aDelegate {
    __block BOOL retVal = NO;
    dispatch_sync_reentrant(delegateQueueKey, [self delegateQueue], ^{
        for (id<PSPDFCacheDelegate> weakRef in self.delegates) {
            if(weakRef == aDelegate) {
                [self.delegates removeObject:weakRef];
                retVal = YES;
                break;
            }
        }
    });
    return retVal;
}

// don't call directly, use store for deletion
- (void)removeCacheForDocument:(PSPDFDocument *)aDocument deleteDocument:(BOOL)deleteDocument waitUntilDone:(BOOL)wait {
    if(!aDocument) {
        PSPDFLogWarning(@"Document is nil.");
        return;
    }
    
    // remove from cache queue instantly
    [self stopCachingDocument:aDocument];
    
    // delete async!
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        // remove file-exist memory cachex
        dispatch_async([self fileMgmtQueue], ^{
            if ([aDocument.uid length] > 0) {
                [self.cachedFiles removeObjectForKey:aDocument.uid];
            }
        });
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSError *error = nil;
        if (![fileManager removeItemAtPath:[self cachedImagePathForDocument:aDocument] error:&error]) {
            PSPDFLogWarning(@"Deletion failed: %@", [error localizedDescription]);
        }
        
        if (deleteDocument) {
            for (NSString *file in aDocument.files) {
                NSURL *filePath = aDocument.basePath ? [aDocument.basePath URLByAppendingPathComponent:file] : (file ? [NSURL URLWithString:file] : nil);
                if (![fileManager removeItemAtURL:filePath error:&error]) {
                    PSPDFLogWarning(@"Document deletion failed: %@", [error localizedDescription]);
                }
            }
        }
        PSPDFLog(@"Cache deletion for %@ completed!", aDocument.title);
    }];
    [cacheQueue_ addOperation:blockOperation];
    
    if (wait) {
        [cacheQueue_ waitUntilAllOperationsAreFinished];
    }
}

- (BOOL)clearCache {
    __block BOOL success = NO;
    
    // wait for potential async cache add requests that are currently running (else document may gets inserted again after we remove it)
    dispatch_sync_reentrant(cacheRequestQueueKey, [self cacheRequestQueue], ^{
        NSError *error = nil;
        NSString *cacheFolder = self.cachedCacheDirectory;
        
        // stop all current operations
        dispatch_sync_reentrant(cacheMgmtQueueKey, [self cacheMgmtQueue], ^{
            [self.queuedItems removeAllObjects];
            [self.queuedDocuments removeAllObjects];
        });
        
        // cancel all running operations, wait until already running requests finish.
        [self.cacheQueue cancelAllOperations];
        [self.cacheQueue waitUntilAllOperationsAreFinished];
        
        // Deletes the file, link, or directory (including, recursively, all subdirectories, files, and links in the directory) identified by a given path.
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if ([fileManager fileExistsAtPath:cacheFolder]) {
            success = [fileManager removeItemAtPath:cacheFolder error:&error];
        }else {
            success = YES;
        }
        
        // remove file-exist memory cache
        dispatch_async([self fileMgmtQueue], ^{
            [self.cachedFiles removeAllObjects];
        });
        
        if (error) {
            PSPDFLogError(@"Failed to delete cache folder: %@", [error localizedDescription]);
        }
        
        // also clear thumbnail cache
        [self clearThumbnailMemoryCache];
        
        // clear potential cache in global lock (and wait for threads to finish up)
        [[PSPDFGlobalLock sharedPSPDFGlobalLock] requestClearCacheAndWait:YES];
    });
    
    return success;
}

// identifier for thumbnail caching (Number is faster than string in NSCache key checking)
- (NSNumber *)identifierForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    NSUInteger hash = (([document hash] * 31 + page) * 31) + size;
    return [NSNumber numberWithInteger:hash];
}

// save image in an NSCache object for specified identifier.
- (void)cacheImage:(UIImage *)image document:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    if (!image) {
        PSPDFLogWarning(@"Tried to save nil in cache!");
        return;
    }
    NSNumber *identifier = [self identifierForDocument:document page:page size:size];
    NSUInteger cost = 0;
    switch (size) {
        case PSPDFSizeNative:
            cost = 100;
            break;
        case PSPDFSizeThumbnail:
            cost = 10;
            break;
        case PSPDFSizeTiny:
            cost = 1;
            break;
        default:
            break;
    }
    
    PSPDFRegisterObject(image);    
    if (size == PSPDFSizeNative) {
        [self.fullPageCache setObject:image forKey:identifier];
    }else {
        [self.thumbnailCache setObject:image forKey:identifier cost:cost];
    }
}

// load image for a certain identifier
- (UIImage *)imageForDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    NSNumber *identifier = [self identifierForDocument:document page:page size:size];
    UIImage *cachedImage;
    if (size == PSPDFSizeNative) {
        cachedImage = [self.fullPageCache objectForKey:identifier];
    }else {
        cachedImage = [self.thumbnailCache objectForKey:identifier];
    }
    return cachedImage;
}

- (void)clearThumbnailMemoryCache {
    [self.fullPageCache removeAllObjects];
    [self.thumbnailCache removeAllObjects];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    PSPDFLogMemory(@"object removed from cache %@: %@ (size: %@)", cache.name, obj, NSStringFromCGSize([(UIImage *)obj size]));
    PSPDFDeregisterObject(obj);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Singleton

static PSPDFCache *sharedPSPDFCache = nil; 
+ (PSPDFCache *)sharedPSPDFCache { 
    static dispatch_once_t pred; 
    dispatch_once(&pred, ^{ sharedPSPDFCache = [[NSClassFromString(kPSPDFCacheClassName) alloc] init]; });
    return sharedPSPDFCache;
}

@end

@interface PSPDFCacheQueuedDocument() {
    NSString *uid_;
}
@end

@implementation PSPDFCacheQueuedDocument
@synthesize document = document_;
@synthesize page = page_;
@synthesize size = size_;
@synthesize caching = caching_;
@synthesize pagesCached = pagesCached_;

+ (PSPDFCacheQueuedDocument *)queuedDocumentWithDocument:(PSPDFDocument *)document page:(NSUInteger)page size:(PSPDFSize)size {
    PSPDFCacheQueuedDocument *queuedDocument = [[[self class] alloc] init];
    queuedDocument.document = document;
    queuedDocument.page = page;
    queuedDocument.size = size;
    return queuedDocument;
}

- (id)init {
    if ((self = [super init])) {
        pagesCached_ = [[NSMutableSet alloc] init];
    }
    return self;
}

- (NSUInteger)hash {
    // http://stackoverflow.com/questions/254281/best-practices-for-overriding-isequal-and-hash/254380#254380
    return (([document_ hash] + page_) * 31) + (size_ ? 1231 : 1237);
}

- (BOOL)isEqual:(id)other {
    if ([other isKindOfClass:[self class]]) {
        PSPDFCacheQueuedDocument *otherQueueItem = (PSPDFCacheQueuedDocument *)other;
        if (![document_ isEqual:[other document]] || !document_ || ![other document]) {
            return NO;
        }
        if (page_ == otherQueueItem.page && size_ == otherQueueItem.size) {
            return YES;
        }
    }
    return NO;  
}

NSString *NSStringFromPSPDFSize(PSPDFSize size);
NSString *NSStringFromPSPDFSize(PSPDFSize size) {
    switch(size) {
        case PSPDFSizeNative:
            return @"Native";
        case PSPDFSizeThumbnail:
            return @"Thumbnail";
        case PSPDFSizeTiny:
            return @"Tiny";
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PSPDFCacheQueuedDocument document:%@ page:%lu size:%@ caching:%d>", self.document, (unsigned long)self.page, NSStringFromPSPDFSize(self.size), self.caching];
}

@end


// this is for debugging only
static NSString * const PSPDFCacheDebugDictKey = @"PSPDFCacheDebugDictKey";
@implementation PSPDFCache (PSPDFDebuggingSupport)

#ifdef kPSPDFKitAllowMemoryDebugging
dispatch_queue_t get_debug_queue(void);
dispatch_queue_t get_debug_queue(void) {
    static dispatch_queue_t debugQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        debugQueue = dispatch_queue_create("com.petetersteinberger.pspdfkit.debugqueue", NULL);
    });
    return debugQueue;
}

- (NSMutableDictionary *)debugDict {
    NSMutableDictionary *debugDict = (NSMutableDictionary *)objc_getAssociatedObject(self, (__bridge const void *)PSPDFCacheDebugDictKey);
    if (!debugDict) {
        debugDict = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(self, (__bridge const void *)PSPDFCacheDebugDictKey, debugDict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return debugDict;
}

- (NSMutableArray *)arrayForObject:(id)object {
    NSString *className = NSStringFromClass([object class]);
    if ([object isKindOfClass:[UIImage class]]) { // split up images!
        className = [NSString stringWithFormat:@"%@_%.0f", className, ((UIImage *)object).size.width];
    }
    NSMutableDictionary *debugDict = [self debugDict];
    NSMutableArray *classArray = [debugDict objectForKey:className];
    if (!classArray) {
        classArray = (__bridge_transfer NSMutableArray *)CFArrayCreateMutable(nil, 0, NULL);
        [debugDict setObject:classArray forKey:className];
    }
    return classArray;
}

static int memoryWarningCounter = 0;
- (void)debugMemoryWarning {
    if (kPSPDFKitDebugMemory) {
        dispatch_async(get_debug_queue(), ^{
            memoryWarningCounter++;
        });
    }
}

- (void)registerObject:(id)object {
    if (kPSPDFKitDebugMemory) {
        dispatch_sync(get_debug_queue(), ^{
            // after first registration, start timer!
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                dispatch_async(dispatch_get_main_queue(), ^{ // need to be registered on main thread
                    [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(printStatus) userInfo:nil repeats:YES];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(debugMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
                });
            });
            
            NSMutableArray *classArray = [self arrayForObject:object];
            if ([classArray indexOfObjectIdenticalTo:object] != NSNotFound) {
                PSPDFLogWarning(@"Object already registered: %@", object);
            }else {
                [classArray addObject:object];
            }
        });
    }
}

- (void)deregisterObject:(id)object {
    if (kPSPDFKitDebugMemory) {
        dispatch_sync(get_debug_queue(), ^{
            NSMutableArray *classArray = [self arrayForObject:object];
            if ([classArray indexOfObjectIdenticalTo:object] == NSNotFound) {
                PSPDFLogWarning(@"Object NOT registered: %@", object);
            }else {
                [classArray removeObject:object];
            }
        });
    }
}

static void pspdf_print_free_memory() {
    vm_size_t pagesize;    
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);
    vm_statistics_data_t vm_stat;
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        PSPDFLogMemory(@"Failed to fetch vm statistics");
    }else {
        /* Stats in bytes */ 
        vm_size_t mem_used = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize;
        vm_size_t mem_free = vm_stat.free_count * pagesize;
        vm_size_t mem_total = mem_used + mem_free;
        PSPDFLogMemory(@"memory used: %luMB free: %luMB total: %luMB", (unsigned long)mem_used/(1024*1024), (unsigned long)mem_free/(1024*1024), (unsigned long)mem_total/(1024*1024));
    }
}

static int showRecursiveViewCount = 4;
typedef void(^PSPDFSimpleBlock)(void);
- (void)printStatus {
    if (kPSPDFKitDebugMemory) {
        __block NSString *blockDescription = nil;
        PSPDFSimpleBlock debugDescriptionBlock = ^{
#ifndef NS_BLOCK_ASSERTIONS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            blockDescription = [[[UIApplication sharedApplication].windows objectAtIndex:0] performSelector:NSSelectorFromString([NSString stringWithFormat:@"recur%@ipti%@", @"siveDescr", @"on"])]; // non-public api, is not compiled when DEBUG is not set.
#pragma clang diagnostic pop
#endif
        };
        if (showRecursiveViewCount % 4 == 0) {
            if ([NSThread isMainThread]){debugDescriptionBlock();}else {dispatch_sync(dispatch_get_main_queue(), ^{ debugDescriptionBlock();});}
        }
        NSString *recursiveDescription = blockDescription;
        dispatch_sync(get_debug_queue(), ^{
            PSPDFLogMemory(@"--------------------------------------------------------------------------------------------");        
            // print whole ui state
            if(recursiveDescription) { PSPDFLogMemory(@"view state: %@", recursiveDescription); } showRecursiveViewCount++;
            
            NSMutableDictionary *dict = [self debugDict];
            __block NSUInteger objectCount = 0;
            [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                objectCount += [obj count];
            }];
            PSPDFLogMemory(@"[%lu] active objects (excluding singletons)", (unsigned long)objectCount);
            NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingComparator:^NSComparisonResult(id o1, id o2) { return [o1 compare:o2]; }];
            
            for (NSString *sortedKey in sortedKeys) {
                NSMutableArray *array = [dict objectForKey:sortedKey];
                NSString *extraData = @"";
                if ([[array lastObject] isKindOfClass:[UIImage class]]) {
                    CGFloat estimatedSize = 0;
                    for (UIImage *setImage in array) {
                        estimatedSize += (setImage.size.width * setImage.size.height * 4) / (CGFloat)(1024*1024); // MB
                    }
                    extraData = [NSString stringWithFormat:@" (estimated: >=%.2fMB)", estimatedSize];
                }
                if ([array count]) {
                    PSPDFLogMemory(@"%@: [%lu]%@", sortedKey, (unsigned long)[array count], extraData);
                }
            }
            PSPDFLogMemory(@"queuedItems (%lu), queuedDocuments: %@", (unsigned long)[self.queuedItems count], [self.queuedDocuments count] ? [self.queuedDocuments description] : @"(0)");
            PSPDFLogMemory(@"memory warnings received: %d", memoryWarningCounter);
            PSPDFLogMemory(@"current queued render jobs: %lu", (unsigned long)[self.cacheQueue operationCount]);
            pspdf_print_free_memory();
            PSPDFLogMemory(@"--------------------------------------------------------------------------------------------");
        });
    }
}

#else
- (void)registerObject:(NSObject *)object {}
- (void)deregisterObject:(NSObject *)object {}
- (void)printStatus {}
#endif

@end

