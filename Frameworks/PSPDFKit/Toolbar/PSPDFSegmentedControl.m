//
//  PSPDFSegmentedControl.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFSegmentedControl.h"
#import "PSPDFKitGlobal.h"

@interface PSPDFSegmentedControl ()
@property (nonatomic, strong, readonly) NSMutableArray *normalImages;
@property (nonatomic, strong, readonly) NSMutableArray *selectedImages;
@end

@implementation PSPDFSegmentedControl

@synthesize normalImages = normalImages_;
@synthesize selectedImages = selectedImages_;

static void *selectedSegmentIndexChanged = &selectedSegmentIndexChanged;

- (void)pspdfSegmentedControlInit {
    NSUInteger numberOfSegments = self.numberOfSegments;
    normalImages_ = [[NSMutableArray alloc] initWithCapacity:numberOfSegments];
    selectedImages_ = [[NSMutableArray alloc] initWithCapacity:numberOfSegments];
    for (NSUInteger i = 0; i < numberOfSegments; i++) {
        [normalImages_ addObject:[super imageForSegmentAtIndex:i] ?: [NSNull null]];
        [selectedImages_ addObject:[NSNull null]];
    }
    
    [self addObserver:self forKeyPath:@"selectedSegmentIndex" options:0 context:selectedSegmentIndexChanged];
}

- (id)initWithItems:(NSArray *)items {
    if ((self = [super initWithItems:items])) {
        [self pspdfSegmentedControlInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super initWithCoder:decoder])) {
        [self pspdfSegmentedControlInit];
    }
    return self;
}

- (void)dealloc {
    PSPDF_IF_IOS5_OR_GREATER([self removeObserver:self forKeyPath:@"selectedSegmentIndex" context:selectedSegmentIndexChanged];)
    PSPDF_IF_PRE_IOS5([self removeObserver:self forKeyPath:@"selectedSegmentIndex"];)
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == selectedSegmentIndexChanged) {
        if (self.selectedSegmentIndex >= 0) {
            for (NSInteger i = 0; i < self.numberOfSegments; i++) {
                UIImage *image = i == self.selectedSegmentIndex ? [self selectedImageForSegmentAtIndex:i] : [self imageForSegmentAtIndex:i];
                if (image) {
                    [super setImage:image forSegmentAtIndex:i];
                }
            }
        }
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)insertSegmentWithImage:(UIImage *)image atIndex:(NSUInteger)segment animated:(BOOL)animated {
    [self.normalImages insertObject:image atIndex:segment];
    [self.selectedImages insertObject:[NSNull null] atIndex:segment];
    [super insertSegmentWithImage:image atIndex:segment animated:animated];
}

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)segment animated:(BOOL)animated {
    [self.normalImages insertObject:[NSNull null] atIndex:segment];
    [self.selectedImages insertObject:[NSNull null] atIndex:segment];
    [super insertSegmentWithTitle:title atIndex:segment animated:animated];
}

- (void)removeSegmentAtIndex:(NSUInteger)segment animated:(BOOL)animated {
    [self.normalImages removeObjectAtIndex:segment];
    [self.selectedImages removeObjectAtIndex:segment];
    [super removeSegmentAtIndex:segment animated:animated];
}

- (void)removeAllSegments {
    [self.normalImages removeAllObjects];
    [self.selectedImages removeAllObjects];
    [super removeAllSegments];
}

- (void)setImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)segment {
    [self.normalImages replaceObjectAtIndex:segment withObject:image ?: [NSNull null]];
    [super setImage:image forSegmentAtIndex:segment];
}

- (UIImage *)imageForSegmentAtIndex:(NSUInteger)segment {
    UIImage *image = [self.normalImages objectAtIndex:segment];
    return image == (id)[NSNull null] ? nil : image;
}

- (void)setSelectedImage:(UIImage *)image forSegmentAtIndex:(NSUInteger)segment {
    [self.selectedImages replaceObjectAtIndex:segment withObject:image ?: [NSNull null]];
}

- (UIImage *)selectedImageForSegmentAtIndex:(NSUInteger)segment {
    UIImage *image = [self.selectedImages objectAtIndex:segment];
    return image == (id)[NSNull null] ? nil : image;
}

@end
