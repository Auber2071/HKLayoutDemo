//
//  UIImage+PSPDFKitAdditions.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "UIImage+PSPDFKitAdditions.h"
#include "turbojpeg.h"

PSPDF_FIX_CATEGORY_BUG(UIImagePSPDFKitAdditions)

@implementation UIImage (PSPDFKitAdditions)

// Some code here is based on MGImageUtilities and properly licensed to allow a non-attribution license.
- (UIImage *)pspdf_imageToFitSize:(CGSize)fitSize method:(PSPDFImageResizingMethod)resizeMethod honorScaleFactor:(BOOL)honorScaleFactor {
	float imageScaleFactor = 1.f;
    if (honorScaleFactor) {
        imageScaleFactor = [self scale];
    }

    float sourceWidth = [self size].width * imageScaleFactor;
    float sourceHeight = [self size].height * imageScaleFactor;
    float targetWidth = fitSize.width;
    float targetHeight = fitSize.height;
    BOOL cropping = !(resizeMethod == PSPDFImageResizeScale);

    // adapt rect based on source image size
    switch (self.imageOrientation) {
        case UIImageOrientationLeft:    // button top
        case UIImageOrientationRight:   // button bottom
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored: {
            ps_swapf(sourceWidth, sourceHeight);
            ps_swapf(targetWidth, targetHeight);
        }break;

        case UIImageOrientationUp:     // button left
        case UIImageOrientationDown:   // button right
        default: {             // works in default
        }break;
    }

    // Calculate aspect ratios
    float sourceRatio = sourceWidth / sourceHeight;
    float targetRatio = targetWidth / targetHeight;

    // Determine what side of the source image to use for proportional scaling
    BOOL scaleWidth = (sourceRatio <= targetRatio);
    // Deal with the case of just scaling proportionally to fit, without cropping
    scaleWidth = (cropping) ? scaleWidth : !scaleWidth;

    // Proportionally scale source image
    CGFloat scalingFactor, scaledWidth, scaledHeight;
    if (scaleWidth) {
        scalingFactor = 1.f / sourceRatio;
        scaledWidth = targetWidth;
        scaledHeight = round(targetWidth * scalingFactor);
    } else {
        scalingFactor = sourceRatio;
        scaledWidth = round(targetHeight * scalingFactor);
        scaledHeight = targetHeight;
    }
    float scaleFactor = scaledHeight / sourceHeight;

    // Calculate compositing rectangles
    CGRect sourceRect, destRect;
    if (cropping) {
        destRect = CGRectMake(0, 0, targetWidth, targetHeight);
        float destX = 0, destY = 0;
        if (resizeMethod == PSPDFImageResizeCrop) {
            // Crop center
            destX = round((scaledWidth - targetWidth) / 2.f);
            destY = round((scaledHeight - targetHeight) / 2.f);
        } else if (resizeMethod == PSPDFImageResizeCropStart) {
            // Crop top or left (prefer top)
            if (scaleWidth) {
                // Crop top
                destX = 0.f;
                destY = 0.f;
            } else {
                // Crop left
                destX = 0.f;
                destY = round((scaledHeight - targetHeight) / 2.f);
            }
        } else if (resizeMethod == PSPDFImageResizeCropEnd) {
            // Crop bottom or right
            if (scaleWidth) {
                // Crop bottom
                destX = round((scaledWidth - targetWidth) / 2.f);
                destY = round(scaledHeight - targetHeight);
            } else {
                // Crop right
                destX = round(scaledWidth - targetWidth);
                destY = round((scaledHeight - targetHeight) / 2.f);
            }
        }
        sourceRect = CGRectMake(destX / scaleFactor, destY / scaleFactor,
                                targetWidth / scaleFactor, targetHeight / scaleFactor);
    } else {
        sourceRect = CGRectMake(0.f, 0.f, sourceWidth, sourceHeight);
        destRect = CGRectMake(0.f, 0.f, scaledWidth, scaledHeight);
    }

    // Create appropriately modified image.
    UIImage *image = nil;
    UIGraphicsBeginImageContextWithOptions(destRect.size, YES, honorScaleFactor ? 0.f : 1.f); // 0.0f for scale means "correct scale for device's main screen".
    CGImageRef sourceImg = CGImageCreateWithImageInRect([self CGImage], sourceRect); // cropping happens here.
    image = [UIImage imageWithCGImage:sourceImg scale:0.f orientation:self.imageOrientation]; //  create cropped UIImage.
    //PSELog(@"image size: %@", NSStringFromCGSize(image.size));
    [image drawInRect:destRect]; // the actual scaling happens here, and orientation is taken care of automatically.
    CGImageRelease(sourceImg);
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

+ (UIImage*)pspdf_imageWithContentsOfResolutionIndependentFile:(NSString *)path {
    return [[UIImage alloc] initWithContentsOfResolutionIndependentFile_pspdf:path];
}

- (id)initWithContentsOfResolutionIndependentFile_pspdf:(NSString *)path {
    if ((int)[[UIScreen mainScreen] scale] != 1.f) {
        NSString *path2x = [[path stringByDeletingLastPathComponent]
                            stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.%@",
                                                            [[path lastPathComponent] stringByDeletingPathExtension],
                                                            [path pathExtension]]];

        if ([[NSFileManager defaultManager] fileExistsAtPath:path2x]) {
            return [self initWithContentsOfFile:path2x];
        }
    }

    return [self initWithContentsOfFile:path];
}

static CGColorSpaceRef colorSpace;
__attribute__((constructor)) static void initialize_colorSpace() {
    colorSpace = CGColorSpaceCreateDeviceRGB();
}
__attribute__((destructor)) static void destroy_colorSpace() {
    CFRelease(colorSpace);
}

// advanced trickery: http://stackoverflow.com/questions/5266272/non-lazy-image-loading-in-ios
+ (UIImage *)pspdf_preloadedImageWithContentsOfFile:(NSString *)path {

    // this *really* loads the image (imageWithContentsOfFile is lazy)
    CGImageRef image = NULL;
    CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename([path cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!dataProvider) {
        PSPDFLogWarning(@"Could not open %@!", path);
        return nil;
    }

    if ([[path lowercaseString] hasSuffix:@"jpg"]) {
        image = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, false, kCGRenderingIntentDefault);
    }else {
        image = CGImageCreateWithPNGDataProvider(dataProvider, NULL, false, kCGRenderingIntentDefault);
    }
    CGDataProviderRelease(dataProvider);

    // make a bitmap context of a suitable size to draw to, forcing decode
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

    CGContextRef imageContext =  CGBitmapContextCreate(NULL, width, height, 8, width*4, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Little);

    // draw the image to the context, release it
    CGContextDrawImage(imageContext, CGRectMake(0.f, 0.f, width, height), image);
    CGImageRelease(image);

    // now get an image ref from the context
    CGImageRef outputImage = CGBitmapContextCreateImage(imageContext);
    UIImage *cachedImage = [UIImage imageWithCGImage:outputImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];

    // clean up
    CGImageRelease(outputImage);
    CGContextRelease(imageContext);
    return cachedImage;
}

- (UIImage *)pspdf_preloadedImage {
    CGImageRef imageRef = self.CGImage;

    // make a bitmap context of a suitable size to draw to, forcing decode
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);

    CGContextRef imageContext = CGBitmapContextCreate(NULL, width, height, 8, width * 4, CGImageGetColorSpace(imageRef),
                                                      kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);

    // draw the image to the context, release it
    CGContextDrawImage(imageContext, CGRectMake(0, 0, width, height), imageRef);

    // now get an image ref from the context
    CGImageRef outputImage = CGBitmapContextCreateImage(imageContext);
    UIImage *cachedImage = [UIImage imageWithCGImage:outputImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];

    // clean up
    CGImageRelease(outputImage);
    CGContextRelease(imageContext);
    return cachedImage;
}

+ (UIImage *)pspdf_imageNamed:(NSString *)imageName bundle:(NSString *)bundleName {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *bundlePath = [resourcePath stringByAppendingPathComponent:bundleName];
    NSString *imagePath = [bundlePath stringByAppendingPathComponent:imageName];
    return [UIImage pspdf_imageWithContentsOfResolutionIndependentFile:imagePath];
}

void ReleaseJPEGBuffer(void *info, const void *data, size_t size);
void ReleaseJPEGBuffer(void *info, const void *data, size_t size) {
    tjFree((void *)data);
}

+ (UIImage *)pspdf_preloadedImageWithContentsOfFile:(NSString *)imagePath useJPGTurbo:(BOOL)useJPGTurbo {
    NSData *data = [NSData dataWithContentsOfFile:imagePath];
    UIImage *cachedImage = nil;
    if (useJPGTurbo) {
        cachedImage = [self pspdf_preloadedImageWithData:data useJPGTurbo:useJPGTurbo];
    }else {
        cachedImage = [UIImage pspdf_preloadedImageWithContentsOfFile:imagePath];
    }
    return cachedImage;
}

+ (UIImage *)pspdf_preloadedImageWithData:(NSData *)data useJPGTurbo:(BOOL)useJPGTurbo {
    UIImage *cachedImage = nil;

    if (useJPGTurbo) {
        // load the file
        unsigned char *jpegBuf = (unsigned char *)[data bytes];
        unsigned char *destBuf = nil;
        unsigned long jpegSize = [data length];
        int jwidth, jheight, jpegSubsamp;
        tjhandle decompressor = tjInitDecompress(); // cannot be shared with other threads

        // get header data
        BOOL failed = tjDecompressHeader2(decompressor, jpegBuf, jpegSize, &jwidth, &jheight, &jpegSubsamp);

        if (!failed) {
            // calculate pixels
            static const size_t bitsPerPixel = 4;
            static const size_t bitsPerComponent = 8;
            unsigned rowBytes = 4 * jwidth;
            unsigned int destBugLength = rowBytes * jheight;
            
            // allocate memory and decompress
            destBuf = tjAlloc(destBugLength);
            failed = tjDecompress2(decompressor, jpegBuf, jpegSize, destBuf, jwidth, jwidth * bitsPerPixel, jheight, TJPF_ABGR, 0);
            tjDestroy(decompressor);

            // transfer bytes to something UIKit can work with
            if (!failed) {
                CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, destBuf, rowBytes * jheight, ReleaseJPEGBuffer);
                CGImageRef cgImage = CGImageCreate(jwidth, jheight, bitsPerComponent, bitsPerComponent*bitsPerPixel, rowBytes, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Little, dataProvider, NULL, false, kCGRenderingIntentDefault);
                cachedImage = [[UIImage alloc] initWithCGImage:cgImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];

                // cleanup
                CFRelease(dataProvider);
                CGImageRelease(cgImage);
            }else {
                ReleaseJPEGBuffer(NULL, destBuf, 0);
                char *errorStr = tjGetErrorStr();
                PSPDFLogError(@"Failed to decompress JPG data: %s", errorStr);
            }
        }
    }else {
        cachedImage = [UIImage imageWithData:data];
        cachedImage = [cachedImage pspdf_preloadedImage];
    }

    return cachedImage;
}

- (UIImage *)pdpdf_imageTintedWithColor:(UIColor *)color fraction:(CGFloat)fraction {
	if (color) {
        CGRect rect = (CGRect){CGPointZero, self.size};
        UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0);
        //CGContextRef context = UIGraphicsGetCurrentContext();
		[color set];
		UIRectFill(rect);
		[self drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0];

		if (fraction > 0.0) {
			[self drawInRect:rect blendMode:kCGBlendModeSourceAtop alpha:fraction];
		}
		UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		return image;
	}
	return self;
}

@end
