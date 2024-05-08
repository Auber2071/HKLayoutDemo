//
//  PSPDFViewState.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFViewState.h"

@implementation PSPDFViewState

@synthesize zoomScale = zoomScale_;
@synthesize contentOffset = contentOffset_;
@synthesize page = page_;
@synthesize showHUD = showHUD_;

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ page:%lu contentOffset:%@ zoomScale:%.2f showHud:%@>", NSStringFromClass([self class]), (unsigned long)page_, NSStringFromCGPoint(contentOffset_), zoomScale_, showHUD_ ? @"YES" : @"NO"];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PSPDFViewState *viewState = [PSPDFViewState new];
    viewState.zoomScale = self.zoomScale;
    viewState.contentOffset = self.contentOffset;
    viewState.page = self.page;
    viewState.showHUD = self.showHUD;
    return viewState;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCoding

// password is not serialized!
- (id)initWithCoder:(NSCoder *)coder {
    if((self = [self init])) {
        zoomScale_ = [[coder decodeObjectForKey:NSStringFromSelector(@selector(zoomScale))] floatValue];
        contentOffset_ = [[coder decodeObjectForKey:NSStringFromSelector(@selector(contentOffset))] CGPointValue];
        page_ = [[coder decodeObjectForKey:NSStringFromSelector(@selector(page))] unsignedIntegerValue];
        showHUD_ = [[coder decodeObjectForKey:NSStringFromSelector(@selector(showHUD))] boolValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[NSNumber numberWithFloat:zoomScale_] forKey:NSStringFromSelector(@selector(zoomScale))];
    [coder encodeObject:[NSValue valueWithCGPoint:contentOffset_] forKey:NSStringFromSelector(@selector(contentOffset))];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:page_] forKey:NSStringFromSelector(@selector(page))];
    [coder encodeObject:[NSNumber numberWithBool:showHUD_] forKey:NSStringFromSelector(@selector(showHUD))];
}

@end
