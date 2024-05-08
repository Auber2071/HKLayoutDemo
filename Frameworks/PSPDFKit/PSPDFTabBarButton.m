//
//  PSPDFTabBarButton.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFTabBarButton.h"

@implementation PSPDFTabBarButton

@synthesize selected = selected_;
@synthesize closeButton = closeButton_;
@synthesize showCloseButton = showCloseButton_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.titleLabel.textColor = [UIColor colorWithWhite:0.8f alpha:1.f];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        self.titleLabel.shadowColor = [UIColor blackColor];
        self.titleLabel.shadowOffset = CGSizeMake(1, 1);
        self.backgroundColor = [UIColor clearColor];
        self.contentEdgeInsets = UIEdgeInsetsMake(6.f, 25.f, 5.f, 5.f);
        self.exclusiveTouch = YES;
        
        showCloseButton_ = YES;
        closeButton_ = [[PSPDFTabBarCloseButton alloc] initWithFrame:CGRectMake(5.f, 8.f, 25.f, frame.size.height)];
        closeButton_.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        closeButton_.showsTouchWhenHighlighted = YES;
        [self addSubview:closeButton_];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [self setNeedsDisplay];
}

// relay to closeButton
- (void)setNeedsDisplay {
    [super setNeedsDisplay];
    [closeButton_ setNeedsDisplay];
}

// extend clickable area
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL inside = [super pointInside:point withEvent:event];
    if (!inside) {
        CGRect origRect = self.bounds;
        CGRect expandedRect = CGRectInset(origRect, 0, -100);
        inside = CGRectContainsPoint(expandedRect, point);
    }
    return inside;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setShowCloseButton:(BOOL)showCloseButton {
    if (showCloseButton != showCloseButton_) {
        showCloseButton_ = showCloseButton;
        closeButton_.hidden = !showCloseButton;
    }
}

- (void)setSelected:(BOOL)selected {
    if (selected != selected_) {
        selected_ = selected;
        [self setNeedsDisplay];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [UIView animateWithDuration:animated ? 0.25f : 0.f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.selected = selected;
    } completion:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)drawRect:(CGRect)rect {
    UIBezierPath* bezierPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight cornerRadii:CGSizeMake(5, 5)];
    
    UIColor *backgroundColor = self.isSelected ? [UIColor colorWithWhite:0.f alpha:0.8f] : [UIColor colorWithWhite:0.f alpha:0.4f];
    
    if (self.isTouchInside) {
        backgroundColor = [UIColor blueColor];
    }
    
    [backgroundColor setFill];
    [bezierPath fill];
    [super drawRect:rect];
}

@end


@implementation PSPDFTabBarCloseButton

- (void)drawRect:(CGRect)rect {
    // draw an x
    PSPDFTabBarButton *tabBarButton = (PSPDFTabBarButton *)self.superview;

    CGContextRef context = UIGraphicsGetCurrentContext();
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(1.5, 1.5)];
    [bezierPath addCurveToPoint:CGPointMake(12.5, 12.5) controlPoint1:CGPointMake(12.5, 12.5) controlPoint2: CGPointMake(12.5, 12.5)];
    [bezierPath moveToPoint:CGPointMake(1.5, 12.5)];
    [bezierPath addCurveToPoint:CGPointMake(12.5, 1.5) controlPoint1:CGPointMake(12.5, 1.5) controlPoint2:CGPointMake(12.5, 1.5)];
    UIColor *fillColor = tabBarButton.isSelected ? [UIColor whiteColor] : [UIColor darkGrayColor];
    [fillColor setFill];
    [bezierPath fill];
        
    CGContextSaveGState(context);
    //CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:0.6f alpha:1.f].CGColor);
    [fillColor setStroke];
    bezierPath.lineWidth = 2.5;
    [bezierPath stroke];
    CGContextRestoreGState(context);
}

@end