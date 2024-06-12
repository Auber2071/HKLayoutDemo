//
//  PSPDFVideoAnnotationView.m
//  PSPDFKit
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKitGlobal.h"
#import "PSPDFVideoAnnotationView.h"
#import "PSPDFAnnotation.h"
#import "PSPDFViewController+Internal.h"
#import "PSPDFDocument.h"

@interface PSPDFVideoAnnotationView () {
    BOOL isShowing_;
    BOOL wasPlaying_;
}
@end

@implementation PSPDFVideoAnnotationView
@synthesize annotation = annotation_;
@synthesize URL = URL_;
@synthesize player = player_;
@synthesize autostartEnabled = autostartEnabled_;
@synthesize useApplicationAudioSession = useApplicationAudioSession_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

// try to find the root view. With a cheap fallback if the rootViewController (wrongly) isn't set.
- (UIView *)rootView {
    if(!self.window.rootViewController) {
        PSPDFLogWarning(@"Cannot find the rootViewController. Are you using the deprecated method of using addSubview to add yout window to the rootViewController? This is wrong, please change this to the iOS4+ way of doing it. (See your AppDelegate)");
    }
    UIView *rootView = self.window.rootViewController.view;
    if (!rootView && [self.window.subviews count] == 1) {
        rootView = [self.window.subviews lastObject];
    }

    // if rootView isn't what we want (no window!) query the view hierarchy up.
    if (!rootView.window) {
        rootView = self.superview;
        while (rootView.superview) {
            rootView = rootView.superview;
        }
    }
    return rootView;
}

- (void)updateFullscreenPlayerFrame {
    CGRect newFrame = [self convertRect:self.bounds toView:[self rootView]];
    player_.view.frame = newFrame;
}

// attach view to window while we are in fullscreen (to survive rotation events)
- (void)willEnterFullscreen {
    [[self rootView] insertSubview:self.player.view atIndex:0];
    player_.view.autoresizingMask = UIViewAutoresizingNone;
    [self updateFullscreenPlayerFrame];

    // hide HUD. First of all, this is expected, second the navigationBar bleeds through when we rotate.
    [self.annotation.document.displayingPdfController hideControls];
}

- (void)willExitFullscreen {
    [[NSNotificationCenter defaultCenter] postNotificationName:kPSPDFFixNavigationBarFrame object:self];
}

// re-attach to annotation view
- (void)didExitFullscreen {
    [self addSubview:self.player.view];
    player_.view.frame = self.bounds;
    player_.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;    
    
    // send both at will and did, as depending on the animationbar state we can fix this while or after the animation.
    [[NSNotificationCenter defaultCenter] postNotificationName:kPSPDFFixNavigationBarFrame object:self];
}

// ensure that we don't play in the background because if some timing issues and autostart
- (void)didChangePlaybackState {    
    if(player_.playbackState == MPMoviePlaybackStatePlaying && !isShowing_) {
        [player_ pause];
    }
}

- (void)registerNotifications {
    if (player_) {
        NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
        [dnc addObserver:self selector:@selector(willEnterFullscreen) name:MPMoviePlayerWillEnterFullscreenNotification object:player_];
        [dnc addObserver:self selector:@selector(willExitFullscreen) name:MPMoviePlayerWillExitFullscreenNotification object:player_];
        [dnc addObserver:self selector:@selector(didExitFullscreen) name:MPMoviePlayerDidExitFullscreenNotification object:player_];
        [dnc addObserver:self selector:@selector(didChangePlaybackState) name:MPMoviePlayerPlaybackStateDidChangeNotification object:player_];
    }
}

- (void)deregisterNotifications {
    if (player_) {
        NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
        [dnc removeObserver:self name:MPMoviePlayerWillEnterFullscreenNotification object:player_];
        [dnc removeObserver:self name:MPMoviePlayerWillExitFullscreenNotification object:player_];
        [dnc removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:player_];
        [dnc removeObserver:self name:MPMoviePlayerPlaybackStateDidChangeNotification object:player_];
    }
}

- (void)addPlayerController {
    //NSTimeInterval position = [player_ currentPlaybackTime];
    if (!player_ || ![player_.contentURL isEqual:URL_]) {
        [self deregisterNotifications];
        player_ = [[MPMoviePlayerController alloc] initWithContentURL:URL_];
        player_.useApplicationAudioSession = useApplicationAudioSession_;
        [self registerNotifications];
        player_.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        player_.view.frame = self.bounds;
        [self addSubview:player_.view];
        //player_.currentPlaybackTime = position;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        PSPDFRegisterObject(self);
        
#if defined(__i386__) || defined(__x86_64__)
        NSLog(@"------------------------------------------------------------------------------");
        NSLog(@"Note: If the embedded video crashes, it's a bug in Apple's Simulator. Please try on a real device.");
        NSLog(@"Referencing \"Error loading /System/Library/Extensions/AudioIPCDriver.kext/... Symbol not found: ___CFObjCIsCollectable.\"");
        NSLog(@"This is a known bug in Xcode 4.2+ / Lion");
        NSLog(@"This note will only show up in the i386 codebase and not on the device.");
        NSLog(@"------------------------------------------------------------------------------");
#endif
    }
    return self;
}

- (void)dealloc {
    PSPDFDeregisterObject(self);
    [self deregisterNotifications];
    [player_ stop];
    [player_.view removeFromSuperview];
    // TODO: sometimes throws KVODeallocate errors with presentationSize and nonForcedSubtitleDisplayEnabled
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    if (player_.view.superview == self) {
        player_.view.frame = self.bounds;
    }else {
        [self updateFullscreenPlayerFrame];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)setURL:(NSURL *)URL {
    if (URL != URL_) {
        URL_ = URL;
        [self addPlayerController];

        // if it's a file reference, check if the file actually exists!
        if ([URL isFileURL] && ![[NSFileManager defaultManager] isReadableFileAtPath:[URL path]]) {
            PSPDFLogWarning(@"File not found: %@ referenced from annotation at page %lu.", [URL path], (unsigned long)annotation_.page);
        }
    }
}

- (void)setAnnotation:(PSPDFAnnotation *)annotation {
    if (annotation != annotation_) {
        annotation_  = annotation;
                        
        // defaults to NO if not found.
        BOOL autostartEnabled = [[annotation.options objectForKey:@"autostart"] boolValue];
        self.autostartEnabled = autostartEnabled;
        
        // reset cached properties
        wasPlaying_ = NO;
        useApplicationAudioSession_ = NO;
        
        // lastly, set URL. This creates the control.
        self.URL = annotation.URL;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFAnnotationView

- (void)willShowPage:(NSUInteger)page {
    [self didShowPage:page];
}

/// page is displayed
- (void)didShowPage:(NSUInteger)page {
    // don't handle this event at all; fullscreen is handled totally differently
    if (player_.view.superview != self) {
        return;
    }
        
    if (!isShowing_) {
        isShowing_ = YES;
        [self addPlayerController];
        
        [player_ prepareToPlay];
        [player_ setShouldAutoplay:self.isAutostartEnabled];
        
        // start the video for iOS4, prepareToPlay isn't enough to show the controls here
        PSPDF_IF_PRE_IOS5([player_ play];
                          if(!self.isAutostartEnabled && !wasPlaying_) [player_ pause];)
        
        PSPDF_IF_IOS5_OR_GREATER(
        if (wasPlaying_) {
            [player_ play];
        })
    }    
}

- (void)willHidePage:(NSUInteger)page {
    [self didHidePage:page];
}

/// page is hidden
- (void)didHidePage:(NSUInteger)page {
    // don't handle this event at all; fullscreen is handled totally differently
    if (player_.view.superview != self) {
        return;
    }
        
    if (isShowing_) {
        isShowing_ = NO;
        
        if (player_.playbackState == MPMoviePlaybackStatePlaying) {
            [player_ pause];
            wasPlaying_ = YES;
        }else{
            wasPlaying_ = NO;
        }        
    }
}

- (void)didChangePageFrame:(CGRect)frame {
    CGRect targetRect = (CGRect){CGPointZero, self.frame.size};
    player_.view.frame = targetRect;
}

@end
