//
//  PSPDFThumbnailGridViewCell.h
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PSPDFKit.h"
#import "PSPDFGridViewCell.h"

// if own thumbs are provided and they are larger than the cell, apply shrinking before setting
#define kPSPDFShrinkOwnImagesTresholdFactor 1.5

@class PSPDFRoundedLabel;

/// Thumbnail cell.
@interface PSPDFThumbnailGridViewCell : PSPDFGridViewCell <PSPDFCacheDelegate>

/// manually set image. use if you override class.
- (void)setImage:(UIImage *)image animated:(BOOL)animated;

/// called when cell resizes. use in override class to re-positionize your content.
- (void)setImageSize:(CGSize)imageSize;

/// internal image view.
@property(nonatomic, strong) UIImageView *imageView;

/// referenced document.
@property(nonatomic, strong) PSPDFDocument *document;

/// site label.
@property(nonatomic, strong) UILabel *siteLabel;

//TODO: cellEye
@property(nonatomic, strong) UIImageView *cellEye;
@property(nonatomic, strong) UIView *cellBg;;

/// referenced page.
@property(nonatomic, assign) NSUInteger page;

/// Allow a margin. Defaults to 0,0,0,0.
@property(nonatomic, assign) UIEdgeInsets edgeInsets;

/// enables thumbnail shadow. defaults to YES.
@property(nonatomic, assign, getter=isShadowEnabled) BOOL shadowEnabled;

/// enable page label.
@property(nonatomic, assign, getter=isShowingSiteLabel) BOOL showingSiteLabel;

/// Creates the shadow. Subclass to change. Returns a CGPathRef.
- (id)pathShadowForView:(UIView *)imgView;

/// Internal static queue for thumbnail parsing.
+ (NSOperationQueue *)thumbnailQueue;

- (void)updateSiteLabel;

@end

/// Simple rounded label.
@interface PSPDFRoundedLabel : UILabel

@property (nonatomic, assign) NSInteger cornerRadius;
@property (nonatomic, strong) UIColor *rectColor;

@end