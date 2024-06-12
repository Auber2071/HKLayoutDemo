//
//  PSPDFThumbnailGridViewCell.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "PSPDFKit.h"
#import "UIColor+PSPDFKitAdditions.h"

@interface PSPDFThumbnailGridViewCell() {
    CALayer *shadowLayer_;
}
@end

@implementation PSPDFThumbnailGridViewCell

@synthesize imageView = imageView_;
@synthesize siteLabel = siteLabel_;
@synthesize document = document_;
@synthesize page = page_;
@synthesize cellEye = cellEye_;
@synthesize cellBg = cellBg_;
@synthesize shadowEnabled = shadowEnabled_;
@synthesize showingSiteLabel = showingSiteLabel_;
@synthesize edgeInsets = _edgeInsets;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Static

// custom queue for thumbnail parsing
+ (NSOperationQueue *)thumbnailQueue {
    static NSOperationQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 4;
        queue.name = @"PSPDFThumbnailQueue";
    });
    return queue;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

/// Creates the shadow. Subclass to change. Returns a CGPathRef.
- (id)pathShadowForView:(UIView *)imgView {
    CGSize size = imgView.bounds.size;    
    UIBezierPath *path = nil;
    
    //CGFloat moveShadow = -8;
    path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, size.width, size.height)];
    
    // copy path, else ARC instantly deallocates the UIBezierPath backing store
    id cgPath = path ? (__bridge_transfer id)CGPathCreateCopy(path.CGPath) : nil;
    return cgPath;
}

- (void)updateShadow {
    if (!shadowLayer_) {
        shadowLayer_ = [[CALayer alloc] init];
        [self.contentView.layer insertSublayer:shadowLayer_ atIndex:1];
        [self.contentView bringSubviewToFront:self.imageView];
    }
    
    // enable/disable shadows
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CALayer *shadowLayer = shadowLayer_;
    shadowLayer.shadowPath = (__bridge CGPathRef)[self pathShadowForView:self.imageView];
    shadowLayer.frame = self.imageView.frame;
    
    if (self.isShadowEnabled && shadowLayer.shadowRadius != 4.f) {
        shadowLayer.shadowColor = [UIColor blackColor] .CGColor;
        shadowLayer.shadowOpacity = 0.25f;
        shadowLayer.shadowOffset = CGSizeMake(0.0f, 0.0f);
        shadowLayer.shadowRadius = 1.0f;
        shadowLayer.masksToBounds = NO;
    }else if(!self.isShadowEnabled && shadowLayer.shadowRadius > 0.f) {
        shadowLayer.shadowRadius = 0.f;
        shadowLayer.shadowOpacity = 0.f;
    }
    [CATransaction commit];
    
}

#define kPSPDFThumbnailLabelHeight 20
- (void)updateSiteLabel {
    CGFloat cornerRadius = 10.f;
    if (self.isShowingSiteLabel && !siteLabel_.superview) {
        PSPDFRoundedLabel *siteLabel = [[PSPDFRoundedLabel alloc] initWithFrame:CGRectZero];
        siteLabel.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.6f];
        siteLabel.textColor = [UIColor colorWithWhite:1.f alpha:1.f];
        siteLabel.textAlignment = kTextAlignmentCenter;
        siteLabel.font = [UIFont boldSystemFontOfSize:16];
        siteLabel.minimumScaleFactor = 10;
        siteLabel.cornerRadius = cornerRadius;
        siteLabel.adjustsFontSizeToFitWidth = YES;
        siteLabel_ = siteLabel;
        [self.contentView addSubview:siteLabel_];
//        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 54, 54)];
//        imageView.center = self.center;
//        cellEye_ = imageView;
//        cellEye_.hidden = YES;
//        [self.contentView addSubview:cellEye_];
//        [self.contentView bringSubviewToFront:cellEye_];
        cellBg_ = [[UIView alloc] initWithFrame:CGRectMake(-8, -8, self.frame.size.width + 16, self.frame.size.height + 16)];
        cellBg_.backgroundColor = [[UIColor colorWithHexString:@"#e8554d"] colorWithAlphaComponent:0.2];
        [self.contentView addSubview:cellBg_];
        [self.contentView sendSubviewToBack:cellBg_];
        cellBg_.hidden = YES;
        cellBg_.layer.borderWidth = 1.0;
        cellBg_.layer.borderColor = [[UIColor colorWithHexString:@"#e8554d"] colorWithAlphaComponent:0.5].CGColor;
        
    }else if(!self.isShowingSiteLabel && siteLabel_.superview) {
        [siteLabel_ removeFromSuperview];
    }
    
    // calculate new frame and position correct
    [siteLabel_ sizeToFit];
    
    // limit width!
    CGRect labelRect = siteLabel_.frame; labelRect.size.width = fminf(labelRect.size.width, self.imageView.frame.size.width - cornerRadius*2); siteLabel_.frame = labelRect;

    CGFloat siteLabelWidth = siteLabel_.frame.size.width + 20.f;
    siteLabel_.frame = CGRectIntegral(CGRectMake(self.imageView.frame.origin.x + (self.imageView.frame.size.width-siteLabelWidth)/2, self.imageView.frame.origin.y+self.imageView.frame.size.height-kPSPDFThumbnailLabelHeight-5.f, siteLabelWidth, kPSPDFThumbnailLabelHeight));
    if (siteLabel_.superview) {
        [self.contentView bringSubviewToFront:siteLabel_];
    }
}

- (void)setImageSize:(CGSize)imageSize {
    // set aspect ratio and center image    
    CGRect newFrame = UIEdgeInsetsInsetRect(self.bounds, _edgeInsets);
    if (!CGSizeEqualToSize(imageSize, CGSizeZero)) {
        CGFloat scale = PSPDFScaleForSizeWithinSize(imageSize, newFrame.size);
        CGSize thumbSize = CGSizeMake(roundf(imageSize.width * scale), roundf(imageSize.height * scale));
        self.imageView.frame = CGRectMake(roundf(_edgeInsets.left+_edgeInsets.right+(newFrame.size.width-thumbSize.width)/2.f), roundf(_edgeInsets.top+(newFrame.size.height-thumbSize.height)/2.f), thumbSize.width, thumbSize.height);
    }else {
        self.imageView.frame = newFrame;
    }
    [self updateShadow];
    [self updateSiteLabel];
}

- (void)updateImageViewBackgroundColor {
    imageView_.backgroundColor = imageView_.image ? [UIColor clearColor] : [UIColor colorWithWhite:1.f alpha:0.8f];
}

- (void)setImage:(UIImage *)image animated:(BOOL)animated {
    if (animated) {
        CATransition *transition = [CATransition animation];
        transition.duration = 0.25f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [self.imageView.layer addAnimation:transition forKey:@"image"];
    }
    
    self.imageView.image = image;
    CGSize imageSize = image ? image.size : CGSizeZero;
    [self setImageSize:imageSize];    
    [self updateImageViewBackgroundColor];
}

// tries to load thumbnail - loads it async if not existing
- (void)loadImageAsync {
    if (!self.document) {
        PSPDFLogWarning(@"Document is nil!");
        return;
    }
    
    // capture data
    NSUInteger page = self.page;
    PSPDFDocument *document = self.document;
    
    // only returns image directly if it's already in memory
    UIImage *cachedImage = [[PSPDFCache sharedPSPDFCache] imageForDocument:document page:page size:PSPDFSizeThumbnail];
    if (cachedImage) {
        [self setImage:cachedImage animated:NO];
    }else {
        // at least try to set correct aspect ratio
        PSPDFPageInfo *pageInfo = nil;
        if ([self.document hasPageInfoForPage:self.page]) {
            pageInfo = [self.document pageInfoForPage:self.page];
        }else {
            // just try to get the pageInfo for the last detected page instead (will work in many cases)
            pageInfo = [self.document nearestPageInfoForPage:self.page];
        }
        
        if (pageInfo) {
            [self setImageSize:pageInfo.pageRect.size];
        }else {
            [self setImageSize:self.bounds.size];
        }
        
        // load image in background
        NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
            @autoreleasepool {
                BOOL shouldPreload = YES;
                UIImage *thumbnailImage = nil;
                
                // try to load image directly from document
                NSURL *thumbImagePath = [document thumbnailPathForPage:page];
                if (thumbImagePath) {
                    thumbnailImage = [UIImage pspdf_preloadedImageWithContentsOfFile:[thumbImagePath path] useJPGTurbo:[PSPDFCache sharedPSPDFCache].useJPGTurbo];
                    
                    if (thumbnailImage) {
                        [[PSPDFCache sharedPSPDFCache] cacheImage:thumbnailImage document:document page:page size:PSPDFSizeThumbnail];
                    }
                    
                    // external thumbs may are too large - need shrinking (or else system is slow in scrolling)
                    if (thumbnailImage && ((thumbnailImage.size.width / self.bounds.size.width > kPSPDFShrinkOwnImagesTresholdFactor) ||
                        (thumbnailImage.size.height / self.bounds.size.height > kPSPDFShrinkOwnImagesTresholdFactor))) {
                        PSPDFLogVerbose(@"apply additional shrinking for image cells to %@", NSStringFromCGRect(self.bounds));
                        
                        thumbnailImage = [thumbnailImage pspdf_imageToFitSize:self.bounds.size method:PSPDFImageResizeCrop honorScaleFactor:YES];
                        shouldPreload = NO;
                    }
                }
                
                // if we still miss a thumbnail, try to get a cached one from the cache
                if (!thumbnailImage) {
                    thumbnailImage = [[PSPDFCache sharedPSPDFCache] cachedImageForDocument:document page:page size:PSPDFSizeThumbnail preload:shouldPreload];
                }
                                
                // we may or may not have the thumbnail now
                if (thumbnailImage) {                    
                    // set image in main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (page == self.page && document == self.document) {
                            [self setImage:thumbnailImage animated:YES];
                        }else {
                            PSPDFLogVerbose(@"Ignoring loaded thumbnail...");
                        }
                    });        
                }
            }
        }];
        [[[self class] thumbnailQueue] addOperation:blockOperation];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.clipsToBounds = NO; // allow drop shadow
        self.exclusiveTouch = YES; // don't allow touching more cells at once
        
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        view.layer.masksToBounds = NO;
        view.layer.shadowOffset = CGSizeMake(2, 2);
        view.layer.shadowPath = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
        self.contentView = view;
        
        imageView_ = [[UIImageView alloc] initWithFrame:frame];
        imageView_.clipsToBounds = YES;
        imageView_.contentMode = UIViewContentModeScaleAspectFill;
        [self updateImageViewBackgroundColor];
        
        [self.contentView addSubview:imageView_];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.contentView.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        // shadow is enabled per default
        shadowEnabled_ = YES;
        showingSiteLabel_ = YES;
        _edgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        
        [[PSPDFCache sharedPSPDFCache] addDelegate:self];
        [self setNeedsLayout];
    }
    return self;
}

- (void)dealloc {
    [[PSPDFCache sharedPSPDFCache] removeDelegate:self];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    self.imageView.alpha = 0.7f;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    self.imageView.alpha = 1.0f;    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    self.imageView.alpha = 1.0f;   
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setPage:(NSUInteger)page {
    page_ = page;
    
    if (self.document) {
        [self loadImageAsync];
    }
}

- (void)setShadowEnabled:(BOOL)shadowEnabled {
    shadowEnabled_ = shadowEnabled;
    [self setNeedsLayout];
}

- (void)setShowingSiteLabel:(BOOL)showingSiteLabel {
    showingSiteLabel_ = showingSiteLabel;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateShadow];
    [self updateSiteLabel];
}

- (void)prepareForReuse {
    self.page = 0;
    imageView_.image = nil;
    [self updateSiteLabel];
    [self updateImageViewBackgroundColor];
    [super prepareForReuse];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFCacheDelegate

- (void)didCachePageForDocument:(PSPDFDocument *)pdfdocument page:(NSUInteger)aPage image:(UIImage *)cachedImage size:(PSPDFSize)size {
    if (self.document == pdfdocument && aPage == self.page && size == PSPDFSizeThumbnail) {
        [self setImage:cachedImage animated:YES];
    }
}

@end


@implementation PSPDFRoundedLabel

@synthesize cornerRadius = cornerRadius_;
@synthesize rectColor = rectColor_;

- (void)setBackgroundColor:(UIColor *)color {
    [super setBackgroundColor:[UIColor clearColor]];
    self.rectColor = color;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // draw rounded background
    CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:cornerRadius_].CGPath);
    CGContextSetFillColorWithColor(context, rectColor_.CGColor);
    CGContextFillPath(context);

    // draw text
    [super drawRect:rect];
}

@end
