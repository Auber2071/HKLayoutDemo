//
//  PSPDFAnnotationCache.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFAnnotationCache.h"
#import "PSPDFAnnotation.h"
#import "PSPDFYouTubeAnnotationView.h"

@interface PSPDFAnnotationCache () {
    NSMutableDictionary *annotationViewCache_;
}
@end

@implementation PSPDFAnnotationCache

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)didReceiveMemoryWarning {
    [self clearAllObjects];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        annotationViewCache_ = [NSMutableDictionary new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ objects:%@>", NSStringFromClass([self class]), annotationViewCache_];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)clearAllObjects {
    [annotationViewCache_ removeAllObjects];
}

- (void)recycleAnnotationView:(id<PSPDFAnnotationView>)annotationView {
    if (![annotationView respondsToSelector:@selector(annotation)] || ![annotationView annotation]) {
        return;
    }
    
    PSPDFAnnotation *annotation = [annotationView annotation];
    NSNumber *cacheKey = [NSNumber numberWithInteger:annotation.type];
    NSMutableDictionary *cache = [annotationViewCache_ objectForKey:cacheKey];
    if (!cache) {
        cache = [NSMutableDictionary new];
        [annotationViewCache_ setObject:cache forKey:cacheKey];
    }
    
    [cache setObject:annotationView forKey:[NSNumber numberWithInteger:[annotation hash]]];
}

- (UIView <PSPDFAnnotationView>*)dequeueViewFromCacheForAnnotation:(PSPDFAnnotation *)annotation {
    UIView <PSPDFAnnotationView>* annotationView = nil;
    NSNumber *cacheKey = [NSNumber numberWithInteger:annotation.type];
    NSMutableDictionary *cache = [annotationViewCache_ objectForKey:cacheKey];
    if (cache) {
        id key = [NSNumber numberWithInteger:[annotation hash]];
        annotationView = [cache objectForKey:key];
        if (!annotationView) {
            key = [[cache keyEnumerator] nextObject];
            if (key) {
                annotationView = [cache objectForKey:key];
            }
        }
        
        if (annotationView) {
            [cache removeObjectForKey:key];
        }
    }
    return annotationView;
}

@end
