//
//  PSPDFTabBarView.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFTabBarView.h"
#import "PSPDFTabBarButton.h"

@interface PSPDFTabBarView ()

@property(nonatomic, strong) UIScrollView *scrollView;

@end

@implementation PSPDFTabBarView

@synthesize delegate = delegate_;
@synthesize dataSource = dataSource_;
@dynamic selectedTabIndex;
@synthesize scrollView = scrollView_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        scrollView_ = [[UIScrollView alloc] initWithFrame:self.bounds];
        scrollView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrollView_.scrollsToTop = NO;
        scrollView_.delegate = self;
        scrollView_.showsHorizontalScrollIndicator = NO;
        scrollView_.showsVerticalScrollIndicator = NO;
        scrollView_.delaysContentTouches = NO;
        [self addSubview:scrollView_];
    }
    return self;
}

- (void)dealloc {
    scrollView_.delegate = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

// don't handle touches that are ouside of the tabbar content area
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect contentRect = self.bounds;
    contentRect.size.width = fminf(scrollView_.contentSize.width + scrollView_.contentInset.left + scrollView_.contentInset.right, self.superview.frame.size.width);
    BOOL inside = CGRectContainsPoint(contentRect, point);
    return inside;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)iterateTabButtonsWithBlock:(void(^)(PSPDFTabBarButton *tabButton, BOOL *stop))block {
    BOOL stop = NO;
    for(UIView *subview in scrollView_.subviews) {
        if (stop) {
            break;
        }
        if ([subview isKindOfClass:[PSPDFTabBarButton class]]) {
            block((PSPDFTabBarButton *)subview, &stop);
        }
    }
}

- (void)buttonPressed:(PSPDFTabBarButton *)sender {
    [delegate_ tabBarView:self didSelectTabAtIndex:sender.tag];
    
    [self iterateTabButtonsWithBlock:^(PSPDFTabBarButton *tabButton, BOOL *stop) {
        tabButton.selected = tabButton == sender;
    }];
}

- (void)closeButtonPressed:(PSPDFTabBarCloseButton *)sender {
    [delegate_ tabBarView:self didSelectCloseButtonOfTabAtIndex:sender.superview.tag];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)selectTabAtIndex:(NSUInteger)index animated:(BOOL)animated {
    [self iterateTabButtonsWithBlock:^(PSPDFTabBarButton *tabButton, BOOL *stop) {
        BOOL selected = index == tabButton.tag;
        [tabButton setSelected:selected animated:animated];
    }];
    [delegate_ tabBarView:self didSelectTabAtIndex:index];
}

- (NSUInteger)selectedTabIndex {
    __block NSUInteger selectedTabIndex = NSNotFound;
    
    [self iterateTabButtonsWithBlock:^(PSPDFTabBarButton *tabButton, BOOL *stop) {
        if (tabButton.isSelected) {
            selectedTabIndex = tabButton.tag;
            *stop = YES;
        }
    }];
    return selectedTabIndex;
}

- (void)scrollToTabAtIndex:(NSUInteger)index animated:(BOOL)animated {
    [self iterateTabButtonsWithBlock:^(PSPDFTabBarButton *tabButton, BOOL *stop) {
        if (tabButton.tag == index) {
            // WWDC: why isn't this working on the iPhone?
            //[scrollView_ scrollRectToVisible:tabButton.frame animated:animated];
            
            CGFloat maxContentOffset = fmaxf(self->scrollView_.contentSize.width - self.scrollView.bounds.size.width, 0);
            [self.scrollView setContentOffset:CGPointMake(fminf(tabButton.frame.origin.x, maxContentOffset), 0) animated:animated];
            *stop = YES;
        }
    }];
}

- (void)reloadData {
    [scrollView_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    CGFloat contentOffset = 0.f;
    NSUInteger itemCount = [dataSource_ numberOfTabsInTabBarView:self];
    for (NSUInteger index = 0; index < itemCount; index++) {
        PSPDFTabBarButton *button = [[PSPDFTabBarButton alloc] initWithFrame:CGRectZero];
        button.tag = index;
        [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [button.closeButton addTarget:self action:@selector(closeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        NSString *title = [dataSource_ tabBarView:self titleForTabAtIndex:index];
        [button setTitle:title forState:UIControlStateNormal];
        [button sizeToFit];
        CGRect frame = button.frame; frame.origin.x = contentOffset; button.frame = frame;
        contentOffset += button.frame.size.width;
        [scrollView_ addSubview:button];
    }
    scrollView_.contentSize = CGSizeMake(contentOffset, self.frame.size.height);
}

@end
