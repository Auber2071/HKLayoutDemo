//
//  PSPDFActionSheet.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFActionSheet.h"
#import <objc/runtime.h>

@interface PSPDFActionSheet() <UIActionSheetDelegate>
@property(nonatomic, strong) NSMutableArray *blocks;
@property(nonatomic, copy) void (^destroyBlock)(void);

@end

static char kPSPDFActionSheetKey;

@implementation PSPDFActionSheet

@synthesize actionSheet = actionSheet_;
@synthesize delegate = delegate_;
@synthesize blocks = blocks_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithTitle:(NSString *)title {
    if ((self = [super init])) {
        actionSheet_ = [[UIActionSheet alloc] initWithTitle:title
                                                   delegate:self
                                          cancelButtonTitle:nil
                                     destructiveButtonTitle:nil
                                          otherButtonTitles:nil];
        
        // Create the blocks storage for handling all button actions
        blocks_ = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    actionSheet_.delegate = nil;
}

- (void)setDestructiveButtonWithTitle:(NSString *)title block:(void (^)(void))block {
    assert([title length] > 0 && "sheet destructive button title must not be empty");
    
    [self addButtonWithTitle:title block:block];
    actionSheet_.destructiveButtonIndex = (actionSheet_.numberOfButtons - 1);
}

- (void)setCancelButtonWithTitle:(NSString *)title block:(void (^)(void))block {
    assert([title length] > 0 && "sheet cancel button title must not be empty");
    
    [self addButtonWithTitle:title block:block];
    actionSheet_.cancelButtonIndex = (actionSheet_.numberOfButtons - 1);
}

- (void)addButtonWithTitle:(NSString *)title block:(void (^)(void))block {
    assert([title length] > 0 && "cannot add button with empty title");
    
    [blocks_ addObject:block ? [block copy] : [NSNull null]];
    [actionSheet_ addButtonWithTitle:title];
}

// Ensure that the delegate (that's us) survives until the sheet is dismissed.
// Release occurs in -actionSheet:clickedButtonAtIndex:
- (void)selfRetain {
    objc_setAssociatedObject(actionSheet_, &kPSPDFActionSheetKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)showInView:(UIView *)view {
    [self selfRetain];
    [actionSheet_ showInView:view];
}

- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated {
    [self selfRetain];
    [actionSheet_ showFromBarButtonItem:item animated:animated];
}

- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated {
    [self selfRetain];
    [actionSheet_ showFromRect:rect inView:view animated:animated];
}

- (void)showFromToolbar:(UIToolbar *)toolbar {
    [self selfRetain];
    [actionSheet_ showFromToolbar:toolbar];
}

- (void)showFromTabBar:(UITabBar *)tabbar {
    [self selfRetain];
    [actionSheet_ showFromTabBar:tabbar];
}

- (NSUInteger)buttonCount {
    return [blocks_ count];
}

- (void)destroy {
    [blocks_ removeAllObjects];
}

- (void)setDestroyBlock:(void (^)(void))block {
    _destroyBlock = [block copy];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIActionSheetDelegate

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // Run the button's block
    if (buttonIndex >= 0 && buttonIndex < [blocks_ count]) {
        id obj = [blocks_ objectAtIndex:buttonIndex];
        if (![obj isEqual:[NSNull null]]) {
            ((void (^)(void))obj)();
        }
    }
    
    if ([delegate_ respondsToSelector:_cmd]) {
        [delegate_ actionSheet:actionSheet clickedButtonAtIndex:buttonIndex];
    }    
}

// Called when we cancel a view (eg. the user clicks the Home button). This is not called when the user clicks the cancel button.
// If not defined in the delegate, we simulate a click in the cancel button
- (void)actionSheetCancel:(UIActionSheet *)actionSheet {
    if ([delegate_ respondsToSelector:_cmd]) {
        [delegate_ actionSheetCancel:actionSheet];
    }
}

// before animation and showing view
- (void)willPresentActionSheet:(UIActionSheet *)actionSheet {
    if ([delegate_ respondsToSelector:_cmd]) {
        [delegate_ willPresentActionSheet:actionSheet];
    }
}

// after animation
- (void)didPresentActionSheet:(UIActionSheet *)actionSheet {
    if ([delegate_ respondsToSelector:_cmd]) {
        [delegate_ didPresentActionSheet:actionSheet];
    }
}

// before animation and hiding view
- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([delegate_ respondsToSelector:_cmd]) {
        [delegate_ actionSheet:actionSheet willDismissWithButtonIndex:buttonIndex];
    }    
}

// after animation
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([delegate_ respondsToSelector:_cmd]) {
        [delegate_ actionSheet:actionSheet didDismissWithButtonIndex:buttonIndex];
    }

    // actionSheet:clickedButtonAtIndex: is not called if we dismiss the actionSheet programmatically.
    // delay release until actionSheet is done calling us.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self destroy];
        // as soon as we remove ourself from the accociated object we get released.
        if (self.destroyBlock) {
            self.destroyBlock();
        }
        self.delegate = nil;
        self.actionSheet.delegate = nil;
        objc_removeAssociatedObjects(self.actionSheet);
    });
}

@end
