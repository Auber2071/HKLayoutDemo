//
//  UIImage+category.m
//  BookReader
//
//  Created by mythlink on 10-11-17.
//  Copyright 2010 mythlink. All rights reserved.
//

#import "UIImage+category.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (category)


- (UIImage *)scaleWithSize:(CGSize)newSize
{
	UIImage * newImage;
    UIGraphicsBeginImageContextWithOptions(newSize, NO, [UIScreen mainScreen].scale);
	//UIGraphicsBeginImageContext(newSize);
	[self drawInRect:CGRectMake(0.0f, 0.0f, newSize.width, newSize.height)];
	newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return newImage;
}

- (UIImage *)scaleWithHeight:(CGFloat)newHeight
{
	return [self scaleWithSize:CGSizeMake((self.size.width / self.size.height) * newHeight, newHeight)];
}

- (UIImage *)scaleWithWidth:(CGFloat)newWidth
{
	return [self scaleWithSize:CGSizeMake(newWidth, (self.size.height / self.size.width) * newWidth)];
}

-(CGFloat)height
{
    return self.size.height;
}
-(CGFloat)width
{
    return self.size.width;
}

///////////////////

+(UIImage*)zy_imageNamed:(NSString*)name{
    return [UIImage imageNamed:name];
}

- (UIImage *)resizeImage:(CGSize)size {
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] != 1.0) {//ipad3
        size = CGSizeMake(size.width*[[UIScreen mainScreen] scale],
                          size.height*[[UIScreen mainScreen] scale]);
    }
    if (self.size.width > size.width || self.size.height > size.height) {
        UIGraphicsBeginImageContext(size);
        [self drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
    }
    else {
        return self;
    }
}

- (BOOL)writeImage:(NSString *)fileAtPath {
    if (self == nil || fileAtPath == nil || fileAtPath.length==0){
        return NO;
    }
    @try{
        NSData *imageData = nil;
        NSString *ext = [fileAtPath pathExtension];
        if ([ext isEqualToString:@"png"]){
            imageData = UIImagePNGRepresentation(self); 
        }
        else {
            imageData = UIImageJPEGRepresentation(self, 0.9);
        }
        if (imageData == nil || [imageData length] <= 0){
            return NO;
        }
        [imageData writeToFile:fileAtPath atomically:YES];       
        return YES;
    }
    @catch (NSException *e){
    }
    return NO;
}

- (UIImage *)cropImageToRect:(CGRect)cropRect {
	// Begin the drawing (again)
	UIGraphicsBeginImageContext(cropRect.size);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	
	// Tanslate and scale upside-down to compensate for Quartz's inverted coordinate system
	CGContextTranslateCTM(ctx, 0.0, cropRect.size.height);
	CGContextScaleCTM(ctx, 1.0, -1.0);
	
	// Draw view into context
	CGRect drawRect = CGRectMake(-cropRect.origin.x, cropRect.origin.y - (self.size.height - cropRect.size.height) , self.size.width, self.size.height);
	CGContextDrawImage(ctx, drawRect, self.CGImage);
	
	// Create the new UIImage from the context
	UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
	
	// End the drawing
	UIGraphicsEndImageContext();
	
	return newImage;
}

- (UIImage *)cropImageFromCenterWithSize:(CGSize)size {
    CGRect cropRect = CGRectMake((self.width-size.width)/2, (self.height-size.height)/2, size.width, size.height);
    
    CGImageRef cgimg = CGImageCreateWithImageInRect(self.CGImage, cropRect);
    UIImage *image = [UIImage imageWithCGImage:cgimg];
    CGImageRelease(cgimg);
    
    return image;
}

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size
{
    // http://stackoverflow.com/questions/1213790/how-to-get-a-color-image-in-iphone-sdk
    
    //Create a context of the appropriate size
    UIGraphicsBeginImageContext(size);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    
    //Build a rect of appropriate size at origin 0,0
    CGRect fillRect = CGRectMake(0, 0, size.width, size.height);
    
    //Set the fill color
    CGContextSetFillColorWithColor(currentContext, color.CGColor);
    
    //Fill the color
    CGContextFillRect(currentContext, fillRect);
    
    //Snap the picture and close the context
    UIImage *colorImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return colorImage;
}

+ (UIImage *)imageWithImage:(UIImage*)image rect:(CGRect)rect
{
    CGImageRef cgImage = CGImageCreateWithImageInRect(image.CGImage, rect);
    image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

@end


@implementation UIImage (MGTint)

+ (UIImage *)imageNamedAlwaysOriginal:(NSString *)name
{
    return [[UIImage imageNamed:name]imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (UIImage *)imageTintedWithColor:(UIColor *)color
{
	// This method is designed for use with template images, i.e. solid-coloured mask-like images.
	return [self imageTintedWithColor:color fraction:0.0]; // default to a fully tinted mask of the image.
}

- (UIImage *)imageTintedWithColor:(UIColor *)color fraction:(CGFloat)fraction
{
	if (color) {
		// Construct new image the same size as this one.
		UIImage *image;
		
		CGRect rect = CGRectZero;
		rect.size = [self size];
		
        //UIGraphicsBeginImageContext([self size]); // 0.0 for scale means "scale for device's main screen".

        UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
        
		// Composite tint color at its own opacity.
		[color set];
		UIRectFill(rect);
		
		// Mask tint color-swatch to this image's opaque mask.
		// We want behaviour like NSCompositeDestinationIn on Mac OS X.
		[self drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0];
		
		// Finally, composite this image over the tinted mask at desired opacity.
		if (fraction > 0.0) {
			// We want behaviour like NSCompositeSourceOver on Mac OS X.
			//kCGBlendModeOverlay kCGBlendModeSourceAtop
			[self drawInRect:rect blendMode:kCGBlendModeOverlay alpha:fraction];
		}
		image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		return image;
	}
	
	return self;
}

@end

@implementation UIImage(Bitmap)
+ (UIImage*)imageWithBitmapContext:(CGContextRef)context
{
    CGImageRef imgCG = CGBitmapContextCreateImage(context);
    UIImage *imgUI = [UIImage imageWithCGImage:imgCG];
    CGImageRelease(imgCG);
    return imgUI;
}

- (CGContextRef)decodeToBitmapContext
{
    CGColorSpaceRef colorSpace;
    CGContextRef context;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate(nil, self.size.width, self.size.height, 8, 4 * self.size.width, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, self.size.width, self.size.height), self.CGImage);
    CGColorSpaceRelease(colorSpace);
    return context;
}

-(UIImage*)decodeToBitmapImage
{
    CGColorSpaceRef colorSpace;
    CGContextRef context;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate(nil, self.size.width, self.size.height, 8, 4 * self.size.width, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    
    NSAssert(context, @"%s %s CGContextRef object is nil, please check parameters", __FILE__, __PRETTY_FUNCTION__);
    
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, self.size.width, self.size.height), self.CGImage);
    CGImageRef bitmapCGImage = CGBitmapContextCreateImage(context);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    UIImage *bitmapUIImage = [UIImage imageWithCGImage:bitmapCGImage];
    CGImageRelease(bitmapCGImage);
    return bitmapUIImage;
}

+ (UIImage *) createfNonInterpolatedImageFromCIImage:(CIImage *)iamge withSize:(CGFloat)size{
    CGRect extent = iamge.extent;
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    size_t with = scale * CGRectGetWidth(extent);
    size_t height = scale * CGRectGetHeight(extent);
    
    UIGraphicsBeginImageContext(CGSizeMake(with, height));
    CGContextRef bitmapContextRef = UIGraphicsGetCurrentContext();
    
    CIContext *context = [CIContext contextWithOptions:nil];
    //通过CIContext 将CIImage生成CGImageRef
    CGImageRef bitmapImage = [context createCGImage:iamge fromRect:extent];
    //在对二维码放大或缩小处理时,禁止插值
    CGContextSetInterpolationQuality(bitmapContextRef, kCGInterpolationNone);
    //对二维码进行缩放
    CGContextScaleCTM(bitmapContextRef, scale, scale);
    //将二维码绘制到图片上下文
    CGContextDrawImage(bitmapContextRef, extent, bitmapImage);
    //获得上下文中二维码
    UIImage *retVal =  UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    CGImageRelease(bitmapImage);
    
    return retVal;
}
@end

