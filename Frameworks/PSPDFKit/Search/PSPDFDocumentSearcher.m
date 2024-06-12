//
//  PSPDFDocumentSearch.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "PSPDFDocumentSearcher.h"
#import "PSPDFSearchOperation.h"
#import "Scanner.h"

@interface PSPDFDocumentSearcher() {
    NSOperationQueue *searchQueue_;
}
@property (nonatomic, strong) NSMutableString *currentData;
@property (nonatomic, strong) NSMutableDictionary *pageDict;
@end

@implementation PSPDFDocumentSearcher

@synthesize document = document_;
@synthesize currentData = currentData_;
@synthesize pageDict = pageDict_;
@synthesize searchMode = searchMode_;
@synthesize delegate = delegate_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)document {
    if ((self = [super init])) {
        PSPDFRegisterObject(self);
        searchMode_ = PSPDFSearchAdvancedWithHighlighting;
        document_ = document;
        searchQueue_ = [[NSOperationQueue alloc] init];
        searchQueue_.name = @"SearchQueue";
        searchQueue_.maxConcurrentOperationCount = 1;
        [searchQueue_ addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
        pageDict_ = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    delegate_ = nil;
    [self cancelAllOperationsAndWait];
    [searchQueue_ removeObserver:self forKeyPath:@"operationCount"];
    [[PSPDFCache sharedPSPDFCache] resumeCachingForService:self];
    PSPDFDeregisterObject(self);
    document_ = nil; // weak
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // KVO to dynamically stop caching when we're searching
    if (object == searchQueue_ && [keyPath isEqualToString:@"operationCount"]) {
        if (PSPDFIsCrappyDevice()) {
            if (searchQueue_.operationCount == 0) {
                [[PSPDFCache sharedPSPDFCache] resumeCachingForService:self];
            }else {
                [[PSPDFCache sharedPSPDFCache] pauseCachingForService:self];    
            }
        }
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)cancelAllOperationsAndWait {
    [searchQueue_ cancelAllOperations];
    [searchQueue_ waitUntilAllOperationsAreFinished];    
}

- (BOOL)hasTextForPage:(NSUInteger)page {
    BOOL hasText = [pageDict_ objectForKey:[NSNumber numberWithInteger:page]] != nil;
    return hasText;
}

- (NSString *)textForPage:(NSUInteger)page {
    if (![self hasTextForPage:page]) {
        [self searchForString:@"---DUMMYSTRING---"]; // just invoke search so page text is cached
        [searchQueue_ waitUntilAllOperationsAreFinished];
    }
    
    // returns nil if key is not set
    NSString *fullText = [self.pageDict objectForKey:[NSNumber numberWithInteger:page]];
    return fullText;
}

- (void)searchForString:(NSString *)searchText {
    [self searchForString:searchText visiblePages:nil onlyVisible:NO];
}

- (void)searchForString:(NSString *)searchText visiblePages:(NSArray *)visiblePages onlyVisible:(BOOL)onlyVisible {
    PSPDFSearchOperation *searchOperation = [[PSPDFSearchOperation alloc] initWithDocument:document_ searchText:searchText];
    searchOperation.selectionSearchPages = visiblePages;
    searchOperation.pageTextDict = pageDict_; // set dict for text
    searchOperation.delegate = self;
    searchOperation.searchMode = searchMode_;
    if (onlyVisible) {
        searchOperation.searchPages = [NSArray array]; // empty array to omit full page search
    }
    
    // copy over page text dict if not yet parsed
    __ps_weak PSPDFSearchOperation *weakSearchOperation = searchOperation;
    [searchOperation setCompletionBlock:^{
        // call back delegate
        dispatch_sync(dispatch_get_main_queue(), ^{
            PSPDFSearchOperation *strongSearchOperation = weakSearchOperation;
            if (strongSearchOperation.isFinished) {
                [self.delegate didFinishSearchForString:strongSearchOperation.searchText searchResults:strongSearchOperation.searchResults isFullSearch:!onlyVisible];
            }else {
                [self.delegate didCancelSearchForString:strongSearchOperation.searchText isFullSearch:!onlyVisible];
            }            
        });
        
        // copy not yet filled out parts of pageDict
        PSPDFSearchOperation *strongSearchOperation = weakSearchOperation;
        if ([self.pageDict count] < [strongSearchOperation.pageTextDict count]) {
            [strongSearchOperation.pageTextDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (![self.pageDict objectForKey:key]) {
                    [self.pageDict setObject:obj forKey:key];
                }
            }];
        }
    }];
    // start search
    [searchQueue_ cancelAllOperations];
    [searchQueue_ addOperation:searchOperation];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFSearchOperationDelegate

- (void)willStartSearchOperation:(PSPDFSearchOperation *)operation forString:(NSString *)searchString isFullSearch:(BOOL)isFullSearch {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!operation.isCancelled) {
            [self.delegate willStartSearchForString:searchString isFullSearch:isFullSearch];
        }
    });
}

- (void)didUpdateSearchOperation:(PSPDFSearchOperation *)operation forString:(NSString *)searchString newSearchResults:(NSArray *)searchResults forPage:(NSUInteger)page {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!operation.isCancelled) {
            [self.delegate didUpdateSearchForString:searchString newSearchResults:searchResults forPage:page];
        }
    });
}

@end
