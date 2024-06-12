//
//  PSPDFBaseViewController.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFBaseViewController.h"
#import "PSPDFKitGlobal.h"

@implementation PSPDFBaseViewController

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

-(BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

@end
