//
//  UIColor+PSPDFKitAdditions.m
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "UIColor+PSPDFKitAdditions.h"

@implementation UIColor (PSPDFKitAdditions)

+ (UIColor *) colorWithHexString: (NSString *) hexString {
    NSString *colorString = [[hexString stringByReplacingOccurrencesOfString: @"#" withString: @""] uppercaseString];
    CGFloat alpha = 0.0, red = 0.0, blue = 0.0, green = 0.0;
    switch ([colorString length]) {
        case 3: // #RGB
            alpha = 1.0f;
            red   = [self colorComponentFrom: colorString start: 0 length: 1];
            green = [self colorComponentFrom: colorString start: 1 length: 1];
            blue  = [self colorComponentFrom: colorString start: 2 length: 1];
            break;
        case 4: // #ARGB
            alpha = [self colorComponentFrom: colorString start: 0 length: 1];
            red   = [self colorComponentFrom: colorString start: 1 length: 1];
            green = [self colorComponentFrom: colorString start: 2 length: 1];
            blue  = [self colorComponentFrom: colorString start: 3 length: 1];
            break;
        case 6: // #RRGGBB
            alpha = 1.0f;
            red   = [self colorComponentFrom: colorString start: 0 length: 2];
            green = [self colorComponentFrom: colorString start: 2 length: 2];
            blue  = [self colorComponentFrom: colorString start: 4 length: 2];
            break;
        case 8: // #AARRGGBB
            alpha = [self colorComponentFrom: colorString start: 0 length: 2];
            red   = [self colorComponentFrom: colorString start: 2 length: 2];
            green = [self colorComponentFrom: colorString start: 4 length: 2];
            blue  = [self colorComponentFrom: colorString start: 6 length: 2];
            break;
        default:
            break;
    }
    return [UIColor colorWithRed: red green: green blue: blue alpha: alpha];
}

+ (CGFloat) colorComponentFrom: (NSString *) string start: (NSUInteger) start length: (NSUInteger) length {
    NSString *substring = [string substringWithRange: NSMakeRange(start, length)];
    NSString *fullHex = length == 2 ? substring : [NSString stringWithFormat: @"%@%@", substring, substring];
    unsigned hexComponent;
    [[NSScanner scannerWithString: fullHex] scanHexInt: &hexComponent];
    return hexComponent / 255.0;
}


+ (UIColor *)colorWithCGPDFArray:(CGPDFArrayRef)realArray
{
    return [[self alloc] initWithCGPDFArray:realArray];
}

- (id)initWithCGPDFArray:(CGPDFArrayRef)realArray
{
//    The number of array elements determines the color space in which the color is defined:
//    0 No color; transparent
//    1 DeviceGray
//    3 DeviceRGB
//    4 DeviceCMYK
    
    // if we have a valid arg,
    if (realArray) {
        
        size_t count = CGPDFArrayGetCount(realArray);
        
        if (count == 0) {
            
            self = [self initWithWhite:0.0 alpha:0.0];
            
        } else if (count == 1) {
            
            CGPDFReal real;
            if (CGPDFArrayGetNumber(realArray, 0, &real)) {
                
                self = [self initWithWhite:real alpha:0.0];
                
            } else {
                
                // likely an invalid array
                self = nil;
            }
            
        } else if ((count == 3) || (count == 4)) {
            
            CGPDFReal components[count];
            size_t i;
            
            for (i = 0; i < count; i++) {
                
                if (!CGPDFArrayGetNumber(realArray, i, components + i)) {
                    
                    // ruh roh, likely a malformed array
                    break;
                }
            }
            
            //if the real array was processed entirely,
            if (i == count) {
                
                // if rgb color,
                if (i == 3) {
                    
                    self = [self initWithRed:components[0] green:components[1] blue:components[2] alpha:1.0];
                    
                } else if (i == 4) {
                    
                    // don't have a CMYK convenience intializer so we need to invoke CGColor* gods
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceCMYK();
                    CGColorRef colorRef = CGColorCreate(colorSpace, components);
                    self = [self initWithCGColor:colorRef];
                    CGColorRelease(colorRef);
                    CGColorSpaceRelease(colorSpace);
                    
                } else {
                    
                    // invalid argument
                    self = nil;
                }
                
            } else {
                
                //invalid argument
                self = nil;
            }
            
        } else {
            
            self = nil;
        }
        
    } else {
        
        // no argument implies no color; transparent
        self = [self initWithWhite:0.0 alpha:0.0];
    }
    
    return self;
}

@end
