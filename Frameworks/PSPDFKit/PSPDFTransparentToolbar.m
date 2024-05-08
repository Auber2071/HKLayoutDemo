//
//  PSPDFTransparentToolbar.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFTransparentToolbar.h"
#import "PSPDFKitGlobal.h"

@implementation PSPDFTransparentToolbar

// Override draw rect to avoid background coloring
- (void)drawRect:(CGRect)rect {
    // do nothing in here
}

// Set properties to make background translucent.
- (void)applyTranslucentBackground {
	self.backgroundColor = [UIColor clearColor];
	self.opaque = NO;
	self.translucent = YES;
}

- (id)init {
    if((self = [super init])) {
        PSPDFRegisterObject(self);
        [self applyTranslucentBackground];
    }
	return self;
}

- (id)initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {
        PSPDFRegisterObject(self);
        [self applyTranslucentBackground];
    }
	return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
}

@end
