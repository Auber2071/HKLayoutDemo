//
//  PSPDFTilingView.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "PSPDFViewController+Internal.h"

@interface PSPDFTilingView()
@property(nonatomic, strong) NSLock *renderLock;
@property(nonatomic, strong) NSTimer *debugTimer;
@property(nonatomic, assign) BOOL renderStepTwo;
@property(nonatomic, strong) UIImage *pdfRenderImage;
@end

@implementation PSPDFTilingView

@synthesize document = document_;
@synthesize page = page_;
@synthesize pdfRenderImage = pdfRenderImage_;
@synthesize pageView = pageView_;
@synthesize zoomScale = zoomScale_;
@synthesize fitWidth = fitWidth_;
@synthesize renderLock = renderLock_;
@synthesize debugTimer = debugTimer_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)drawPDFInContext:(CGContextRef)context {
    CGPDFPageRef pdfPage = [[PSPDFGlobalLock sharedPSPDFGlobalLock] lockWithDocument:self.document page:self.page error:nil];
    if (!pdfPage) {
        PSPDFLogWarning(@"Failed to aquire page ref. file removed? %@", self.document);
    }else {
        // draw pdf
        PSPDFPageInfo *pageInfo = [self.document pageInfoForPage:self.page];
        [PSPDFPageRenderer renderPage:pdfPage inContext:context inRectangle:self.bounds pageInfo:pageInfo];
        
        // release lock
        [[PSPDFGlobalLock sharedPSPDFGlobalLock] freeWithPDFPageRef:pdfPage];                
        
        // call document hook to draw additional data
        if ([self.document shouldDrawOverlayRectForSize:PSPDFSizeNative]) {
            [self.document drawOverlayRect:self.bounds inContext:context forPage:self.page zoomScale:zoomScale_ size:PSPDFSizeNative];
        }        
    }
}

- (void)timerFired {
    // sometimes, the PSPDFTiledLayer gets deallocated, before our timer is destroyed. so, check for a window!
    if (kPSPDFKitDebugScrollViews && self.window) {
        if (self.alpha > 0.f) {
            PSPDFLogVerbose(@"Hiding ScrollView");
            self.alpha = 0.f;
        }else {
            PSPDFLogVerbose(@"Showing ScrollView");
            self.alpha = 1.f;
        }
    }
}

- (CATiledLayer *)tiledLayer {
    CATiledLayer *tiledLayer = (CATiledLayer *)[self layer];
    return tiledLayer;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

// Create a new PSPDFTilingView with the desired frame and scale.
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        PSPDFRegisterObject(self);
        page_ = -1;
        renderLock_ = [[NSLock alloc] init];
        
        if (kPSPDFKitDebugScrollViews) {
            self.backgroundColor = [UIColor colorWithRed:1.f green:0.95f blue:0.f alpha:0.5f];
            debugTimer_ = [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(timerFired) userInfo:nil repeats:YES];        
        }
        
        CATiledLayer *tiledLayer = [self tiledLayer];
        [tiledLayer setNeedsDisplayOnBoundsChange:NO];
        tiledLayer.opaque = YES;
        
        // maximum possible tileSize since of iOS5.
        // In iOS4, tiles up to 2048x2048 were rendered, although the documentation retains maxmum view size to 1024x1024.
        tiledLayer.tileSize = PSPDFIsCrappyDevice() ? CGSizeMake(512.f, 512.f) : CGSizeMake(1024.f, 1024.f);
        
        // if you set the levels of detail (LOD) to 4 and the bias to 1, you'd get 2x zooming in (2^1) 'native zoom' (2^0), 2x zoomed out (2^-1) and 4x zoomed out (2^-2). If you set the LOD to 8 and the bias to 5 you'd get 32x zoomed in (2^5) to 4x zoomed out (2^-2).
        
        // Levels of detail determines the # of levels of detail
        tiledLayer.levelsOfDetail = kPSPDFKitZoomLevels;
        
        // bias determines how many are 'reserved' for zooming in
        // if levelsOfDetail == levelsOfDetailBias, the initial zoom level is rendered slightly blurry.
        tiledLayer.levelsOfDetailBias = kPSPDFKitZoomLevels-1;
        
        // to handle the interaction between CATiledLayer and high resolution screens, we need to manually set the
        // tiling view's contentScaleFactor to 1.0. (If we omitted this, it would be 2.0 on high resolution screens,
        // which would cause the CATiledLayer to ask us for tiles of the wrong scales.)
        self.contentScaleFactor = 1.0;
        
        self.clearsContextBeforeDrawing = NO;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    _myFrame = frame;
}

// clean up
- (void)dealloc {    
    if (kPSPDFKitDebugScrollViews) {
        [debugTimer_ invalidate];
    }
    PSPDFDeregisterObject(self);
    pageView_ = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

// Set the layer's class to be a CATiledLayer.
+ (Class)layerClass {
    return [PSPDFTiledLayer class];
}

- (void)drawRect:(CGRect)rect {
    // UIView uses the existence of -drawRect: to determine if it should allow its CALayer
    // to be invalidated, which would then lead to the layer creating a backing store and
    // -drawLayer:inContext: being called.
    // By implementing an empty -drawRect: method, we allow UIKit to continue to implement
    // this logic, while doing our real drawing work inside of -drawLayer:inContext:
}

// Draw the CGPDFPageRef into the layer at the correct scale.
- (void)drawLayer:(CALayer*)layer inContext:(CGContextRef)context {
    
    // debug output
    if (kPSPDFKitDebugScrollViews) {
        CGRect rect = [self convertRect:self.frame toView:self.window];
        PSPDFLogVerbose(@"drawing in rect: %@", NSStringFromCGRect(rect));
    }

    // render pdf and return page ref
    if (self.document) {            
        // if fitWidth is enabled, the cache image is invalid and we need to re-render it
        if (zoomScale_ <= 1.f && !self.renderStepTwo && !fitWidth_) {
            
            // don't render pdf more than once (and lock mutex so that pdfRenderImage is not set s/w else)
            [self.renderLock lock];
            
            if (!self.pdfRenderImage) {
                
                // save generated image async, to not block pdf rendering
                PSPDFDocument *document = self.document;
                NSUInteger page = self.page;
                
                // if image is in filesystem, load it from there
                if ([[PSPDFCache sharedPSPDFCache] isImageCachedForDocument:document page:page size:PSPDFSizeNative]) {
                    self.pdfRenderImage = [[PSPDFCache sharedPSPDFCache] cachedImageForDocument:document page:page size:PSPDFSizeNative preload:YES];
                }
                
                if (!self.pdfRenderImage) {
                    // get a lock and render image!
                    CGPDFPageRef pdfPage = [[PSPDFGlobalLock sharedPSPDFGlobalLock] lockWithDocument:document page:page error:nil];
                    self.pdfRenderImage = [[PSPDFCache sharedPSPDFCache] renderImageForDocument:document page:page size:PSPDFSizeNative pdfPage:pdfPage];
                    [[PSPDFGlobalLock sharedPSPDFGlobalLock] freeWithPDFPageRef:pdfPage];
                    
                    if (!self.pdfRenderImage) {
                        PSPDFLogError(@"missing render image!");
                    }
                    
                    // save image on disk cache
                    UIImage *pdfRenderImage = self.pdfRenderImage;
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^ {
                        [[PSPDFCache sharedPSPDFCache] saveNativeRenderedImage:pdfRenderImage document:document page:page];
                    });
                }
            }
            
            // draw recent image in context!
            CGImageRef cgImage = self.pdfRenderImage.CGImage;
            if(cgImage) {		
                CGContextSaveGState(context);
                CGRect bounding = CGRectMake(0, 0, self.myFrame.size.width, self.myFrame.size.height);
                CGContextTranslateCTM(context, 0.f, roundf(bounding.size.height));
                CGContextScaleCTM(context, 1.f, -1.f);	
                CGContextSetInterpolationQuality(context, kCGInterpolationHigh); // nicer zoomed images
                CGContextDrawImage(context, CGRectMake(0, 0, self.myFrame.size.width, self.myFrame.size.height), cgImage);                    
                CGContextRestoreGState(context);
            }else {
                PSPDFLogError(@"Missing PDF IMAGE FOR %@", self.document);
            }
            
            [self.renderLock unlock];
            
            // draw zoomed
        }else {
            [self drawPDFInContext:context];
            DrawPSPDFKit(context);
        }                
    }
}

// http://stackoverflow.com/questions/9691891/catiledlayer-in-ipad-retina-simulator-yields-poor-performance
// if we don't set the scale factor to 1, the CATiledLayer will draw twice as many tiles and also will try to scale them down.
- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentScaleFactor = 1.f;
}

///////////////////////////////////////////////////////////////////////////////////////////////////1
#pragma mark - Properties

- (void)setDocument:(PSPDFDocument *)aDocument {
    if (document_ != aDocument) {
        NSAssert([NSThread isMainThread], @"Must run on main thread");
        document_ = aDocument;
    }
    
    // clear out delegate if document is removed
    ((CATiledLayer *)[self layer]).delegate = aDocument ? self : nil;
    self.renderStepTwo = NO;
    [self setNeedsDisplay];
}

- (void)setPdfRenderImage:(UIImage *)pdfRenderImage {
    if (pdfRenderImage != pdfRenderImage_) {
        pdfRenderImage_ = pdfRenderImage;
        
        // relay rendered image to background
        if (pdfRenderImage) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                [self.pageView setBackgroundImage:pdfRenderImage animated:YES];
                
                [self.pageView.pdfController delegateDidRenderPageView:self.pageView];
                                
                // forces layer to render a second time, increases image sharpness. only done at zoom level 0
                if (self.document.isTwoStepRenderingEnabled) {
                    // restart rendering, with sharp image
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                        // synced so that we don't delete pdfRenderImage while a thread is drawing it
                        [self.renderLock lock];
                        
                        self.pdfRenderImage = nil;
                        self.renderStepTwo = YES;
                        
                        [self.renderLock unlock];

                        // pretty crazy code, but works flawlessly. apparently, it's ok to set contents = nil in background.
                        // this waits for all threads to finish, so it would make a huge lag when called within main.
                        // Transforms the CATiledLayer into a dumb CALayer.
                        // WWDC: is that ok?
                        ((CATiledLayer *)[self layer]).contents = nil;                         
                        
                        // finally, notify CATiledLayer that we wanna redraw. This transforms the CALayer back to CATiledLayer.
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setNeedsDisplay];
                        });
                    });
                }
            });
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)resetLayer {
    NSAssert([NSThread isMainThread], @"Must run on main thread");
    ((CATiledLayer *)[self layer]).contents = nil;
    [self setNeedsDisplay];
}

- (void)stopTiledRenderingAndRemoveFromSuperlayer {
    NSAssert([NSThread isMainThread], @"Must run on main thread");
    ((CATiledLayer *)[self layer]).delegate = nil;
    [self removeFromSuperview];
    [self.layer removeFromSuperlayer];
}

@end

// subclassed CATiledLayer to set different fade duration.
// Note: This is not registed in PSPDFRegisterObject because of a ARC-recursion-bug with iOS 4.x.
@implementation PSPDFTiledLayer : CATiledLayer

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

+ (CFTimeInterval)fadeDuration {
return PSPDFIsCrappyDevice() ? 0.f : kPSPDFKitPDFAnimationDuration; // default would be 0.25f
}
@end
