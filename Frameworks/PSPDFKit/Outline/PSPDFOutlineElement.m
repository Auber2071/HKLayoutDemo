//
//  PSPDFOutlineElement.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKitGlobal.h"
#import "PSPDFOutlineElement.h"

@implementation PSPDFOutlineElement

@synthesize title = title_;
@synthesize page = page_;
@synthesize children = children_;
@synthesize level = level_;
@synthesize expanded = expanded_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithTitle:(NSString *)title page:(NSUInteger)page children:(NSArray *)children level:(NSUInteger)level {
    if ((self = [super init])) {
        PSPDFRegisterObject(self);
        title_ = [title copy];
        page_ = page;
        level_ = level;
        children_ = [children copy];
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PSPDFOutlineElement title:%@ page:%lu level:%lu childCount:%lu, children:%@>", self.title, (unsigned long)self.page, (unsigned long)self.level, (unsigned long)[self.children count], self.children];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)addOpenChildren:(NSMutableArray *)list {
	[list addObject:self];
	if (expanded_) {
		for (PSPDFOutlineElement *child in children_) {
			[child addOpenChildren:list];
		}
	}
}

- (NSArray *)flattenedChildren {
	NSMutableArray *flatList = [NSMutableArray array];
	for (PSPDFOutlineElement *child in children_) {
		[child addOpenChildren:flatList];
	}
	return [flatList copy];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PSPDFOutlineElement *outlineElement = [[PSPDFOutlineElement alloc] initWithTitle:title_ page:page_ children:children_ level:level_];
    return outlineElement;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSCoding

// password is not serialized!
- (id)initWithCoder:(NSCoder *)coder {
    NSString *title = [coder decodeObjectForKey:NSStringFromSelector(@selector(title))];
    NSUInteger page = [[coder decodeObjectForKey:NSStringFromSelector(@selector(page))] unsignedIntegerValue];
    NSUInteger level = [[coder decodeObjectForKey:NSStringFromSelector(@selector(level))] unsignedIntegerValue];
    NSArray *children = [coder decodeObjectForKey:NSStringFromSelector(@selector(children))];
    self = [self initWithTitle:title page:page children:children level:level];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:title_ forKey:NSStringFromSelector(@selector(title))];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:page_] forKey:NSStringFromSelector(@selector(page))];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:level_] forKey:NSStringFromSelector(@selector(level))];
    [coder encodeObject:children_ forKey:NSStringFromSelector(@selector(children))];
}

@end
