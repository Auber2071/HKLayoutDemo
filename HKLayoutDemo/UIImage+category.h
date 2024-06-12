//
//  UIImage+CategoryCategory.h
//  BookReader
//
//  Created by mythlink on 10-11-17.
//  Copyright 2010 mythlink. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UIImage(CategoryCategory)
- (UIImage *)scaleWithWidth:(CGFloat)newWidth;
- (UIImage *)scaleWithSize:(CGSize)newSize;
- (CGFloat)height;
- (CGFloat)width;

///////////////////
+ (UIImage*)zy_imageNamed:(NSString*)name;

- (UIImage *)resizeImage:(CGSize)size;
- (BOOL)writeImage:(NSString *)fileAtPath;
- (UIImage *)cropImageToRect:(CGRect)cropRect;
- (UIImage *)cropImageFromCenterWithSize:(CGSize)size;

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
+ (UIImage *)imageWithImage:(UIImage*)image rect:(CGRect)rect;

@end


@interface UIImage (MGTint)

- (UIImage *)imageTintedWithColor:(UIColor *)color;
- (UIImage *)imageTintedWithColor:(UIColor *)color fraction:(CGFloat)fraction;
+ (UIImage *)imageNamedAlwaysOriginal:(NSString *)name;

@end

@interface UIImage(Bitmap)
+ (UIImage*)imageWithBitmapContext:(CGContextRef)context;
- (CGContextRef)decodeToBitmapContext;
- (UIImage*)decodeToBitmapImage;
+ (UIImage *)createfNonInterpolatedImageFromCIImage:(CIImage *)iamge withSize:(CGFloat)size;
@end
