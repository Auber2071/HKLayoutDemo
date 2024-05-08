//
//  PSPDFTabbedViewController.m
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFTabbedViewController.h"
#import "PSPDFViewController.h"
#import "PSPDFTabBarView.h"
#import "PSPDFHUDView.h"

@interface PSPDFTabbedViewController () <PSPDFTabBarViewDelegate, PSPDFTabBarViewDataSource> {
    PSPDFTabBarView *tabBar_;
    NSMutableDictionary *viewStateDictionary_;
}
@end

@implementation PSPDFTabbedViewController

@synthesize documents = documents_;
@synthesize pdfViewController = pdfViewController_;
@synthesize delegate = delegate_;
@synthesize statePersistanceKey = statePersistanceKey_;
@synthesize enableAutomaticStatePersistance = enableAutomaticStatePersistance_;
@dynamic visibleDocument;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithPDFViewController:(PSPDFViewController *)pdfViewController {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        PSPDF_IF_PRE_IOS5(NSLog(@"Error: This component needs iOS5 or later."); return nil;);
        
        statePersistanceKey_ = @"kPSPDFTabbedDocumentsPersistKey";
        enableAutomaticStatePersistance_ = NO;
        viewStateDictionary_ = [NSMutableDictionary new];
        pdfViewController_ = pdfViewController ?: [[PSPDFViewController alloc] initWithDocument:nil];
        pdfViewController_.useParentNavigationBar = YES;
    }
    return self;
}

- (id)init {
    return [self initWithPDFViewController:nil];
}

// Interface Builder/Storyboarding.
- (id)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithPDFViewController:nil];
}

// this class is not designed to be used with a nib file.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithPDFViewController:nil];
}

- (void)dealloc {
    if (self.enableAutomaticStatePersistance) {
        [self persistState];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

- (void)updateTabBarFrame {
    // increased high to make touches easier.
    CGFloat navigationBarHeight = [self.pdfViewController contentRect].origin.y;
    tabBar_.frame = CGRectMake(0.f, navigationBarHeight, self.view.bounds.size.width, 64.f);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addChildViewController:pdfViewController_];
    pdfViewController_.view.frame = self.view.bounds;
    pdfViewController_.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:pdfViewController_.view];
//    self.wantsFullScreenLayout = !PSIsIpad();
    
    // remove document item set from PSPDFViewController.
    self.navigationItem.leftBarButtonItem = nil;
    
    // add custom tabbar
    // TODO: use contentView in PSPDFKit v2.
    tabBar_ = [[PSPDFTabBarView alloc] initWithFrame:CGRectZero];
    tabBar_.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    tabBar_.delegate = self;
    tabBar_.dataSource = self;
    [self updateTabBarFrame];
    [pdfViewController_.hudView addSubview:tabBar_];
    [tabBar_ reloadData];
    [self selectCurrentDocumentInTabBarAnimated:NO scrollToPosition:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // WWDC: timing problem with child view controllers.
    // navigationBar will only be changed in the PSPDFViewController's viewWillAppear.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateTabBarFrame];
    });
}

//- (void)viewDidUnload {
//    [super viewDidUnload];
//    [pdfViewController_ removeFromParentViewController];
//    tabBar_.delegate = nil;
//    tabBar_.dataSource = nil;
//    tabBar_ = nil;
//}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateTabBarFrame];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (void)addDocuments:(NSArray *)documents atIndex:(NSUInteger)index animated:(BOOL)animated {
    NSMutableArray *newDocuments = [self.documents mutableCopy];
    index = MIN(index, [newDocuments count]);

    NSArray *documentsToInsert = [documents filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return ![newDocuments containsObject:evaluatedObject];
    }]];

    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, [documentsToInsert count])];
    [newDocuments insertObjects:documentsToInsert atIndexes:indexSet];
    [self setDocuments:newDocuments animated:animated];
}

- (void)removeDocuments:(NSArray *)documents animated:(BOOL)animated {
    NSMutableArray *newDocuments = [self.documents mutableCopy];
    for (PSPDFDocument *document in documents) {
        if ([newDocuments containsObject:document]) {
            [newDocuments removeObject:document];
        }else {
            PSPDFLogWarning(@"Ignoring document %@, not in self.documents array.", document);
        }
    }
    [self setDocuments:newDocuments animated:animated];
}

- (void)selectCurrentDocumentInTabBarAnimated:(BOOL)animated scrollToPosition:(BOOL)scrollToPosition {
    NSUInteger activeIndex = [self.documents indexOfObject:self.visibleDocument];
    if (activeIndex != NSNotFound) {
        [tabBar_ selectTabAtIndex:activeIndex animated:animated];
        if (scrollToPosition) {
            [tabBar_ scrollToTabAtIndex:activeIndex animated:animated];
        }
    }
}

- (void)setEnableAutomaticStatePersistance:(BOOL)enableAutomaticStatePersistance {
    if(enableAutomaticStatePersistance != enableAutomaticStatePersistance_) {
        enableAutomaticStatePersistance_ = enableAutomaticStatePersistance;
        if (enableAutomaticStatePersistance) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(persistState) name:UIApplicationDidEnterBackgroundNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(persistState) name:UIApplicationWillTerminateNotification object:nil];
        }else {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
        }
    }
}

- (void)persistState {
    PSPDFLogVerbose(@"persisting state.");
    NSMutableDictionary *persistDict = [NSMutableDictionary dictionaryWithCapacity:2];
    if (self.documents) {
        [persistDict setObject:self.documents forKey:NSStringFromSelector(@selector(documents))];
    }
    if (self.visibleDocument) {
        [persistDict setObject:self.visibleDocument forKey:NSStringFromSelector(@selector(visibleDocument))];
    }
    [self persistViewStateForCurrentVisibleDocument];
    [persistDict setObject:viewStateDictionary_ forKey:@"viewStateDictionary"];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:persistDict];
    [[NSUserDefaults standardUserDefaults] setObject:archive forKey:self.statePersistanceKey];
}

- (BOOL)restoreState {
    return [self restoreStateAndMergeWithDocuments:nil];
}

- (BOOL)restoreStateAndMergeWithDocuments:(NSArray *)documents {
    // load documents fron user defaults
    NSData *archiveData = [[NSUserDefaults standardUserDefaults] objectForKey:self.statePersistanceKey];
    NSDictionary *persistDict = nil;
    if (archiveData) {
        PSPDFLogVerbose(@"restoring state.");
        @try {
            // This method raises an NSInvalidArchiveOperationException if data is not a valid archive.
            persistDict = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
        }
        @catch (NSException *exception) {
            NSLog(@"Failed to restore persist state: %@", exception);
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:self.statePersistanceKey];
        }
    }

    NSArray *newDocuments = nil;
    PSPDFDocument *newVisibleDocument = nil;

    // set new properties
    if (persistDict) {
        newDocuments = [persistDict objectForKey:NSStringFromSelector(@selector(documents))];
        newVisibleDocument = [persistDict objectForKey:NSStringFromSelector(@selector(visibleDocument))];
        viewStateDictionary_ = [persistDict objectForKey:@"viewStateDictionary"] ?: viewStateDictionary_;
        [self restoreViewStateForCurrentVisibleDocument];
    }

    // merge docments with current state
    NSMutableArray *mergedDocuments = [newDocuments mutableCopy] ?: [NSMutableArray array];
    for (PSPDFDocument *document in documents) {
        if (![newDocuments containsObject:document]) {
            [mergedDocuments addObject:document];
        }
    }
    self.documents = mergedDocuments;
    if ([documents count] > 0) {
        newVisibleDocument = [documents objectAtIndex:0];
    }
    self.visibleDocument = newVisibleDocument;

    return persistDict != nil;
}

- (void)setDocuments:(NSArray *)documents {
    [self setDocuments:documents animated:NO];
}

- (void)setDocuments:(NSArray *)documents animated:(BOOL)animated {
    if (documents != documents_) {
        
        BOOL allowChange = YES;
        if ([delegate_ respondsToSelector:@selector(tabbedPDFController:willChangeDocuments:)]) {
            allowChange = [delegate_ tabbedPDFController:self willChangeDocuments:documents];
        }
        
        if (allowChange) {
            NSArray *oldDocuments = documents_;
            documents_ = documents;
            [tabBar_ reloadData];
            [self selectCurrentDocumentInTabBarAnimated:animated scrollToPosition:YES];

            // replace visibleDocument?
            if ((self.visibleDocument && [documents indexOfObject:self.visibleDocument] == NSNotFound) || !self.visibleDocument) {
                if ([documents count]) {
                    self.visibleDocument = [documents objectAtIndex:0];
                    [tabBar_ selectTabAtIndex:0 animated:NO];
                }else {
                    self.visibleDocument = nil;
                }
            }
            
            // remove view cache data
            NSMutableSet *oldDocumentsSet = [NSMutableSet setWithArray:oldDocuments];
            [oldDocumentsSet minusSet:[NSSet setWithArray:documents]];
            [viewStateDictionary_ removeObjectsForKeys:[[oldDocumentsSet valueForKeyPath:@"self.uid"] allObjects]];
            
            if ([delegate_ respondsToSelector:@selector(tabbedPDFController:didChangeDocuments:)]) {
                [delegate_ tabbedPDFController:self didChangeDocuments:oldDocuments];
            }
        }
    }
}

- (PSPDFDocument *)visibleDocument {
    return pdfViewController_.document;
}

- (void)restoreViewStateForCurrentVisibleDocument {
    PSPDFViewState *viewState = [viewStateDictionary_ objectForKey:self.visibleDocument.uid];
    if (viewState) {
        [pdfViewController_ restoreDocumentViewState:viewState animated:NO];
    }
}

- (void)persistViewStateForCurrentVisibleDocument {
    if (pdfViewController_.document) {
        PSPDFViewState *viewState = [pdfViewController_ documentViewState];
        [viewStateDictionary_ setObject:viewState forKey:pdfViewController_.document.uid];
    }
}

- (void)setVisibleDocument:(PSPDFDocument *)visibleDocument {
    [self setVisibleDocument:visibleDocument animated:NO scrollToPosition:YES];
}

- (void)setVisibleDocument:(PSPDFDocument *)visibleDocument animated:(BOOL)animated scrollToPosition:(BOOL)scrollToPosition {
    if (pdfViewController_.document != visibleDocument) {
        [self persistViewStateForCurrentVisibleDocument];
        
        pdfViewController_.document = visibleDocument;
        [self restoreViewStateForCurrentVisibleDocument];

        [self selectCurrentDocumentInTabBarAnimated:animated scrollToPosition:scrollToPosition];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFTabBarViewDelegate

- (void)tabBarView:(PSPDFTabBarView *)tabBarView didSelectTabAtIndex:(NSUInteger)index {
    PSPDFDocument *newDocument = [self.documents objectAtIndex:index];
    BOOL allowChange = YES;
    if ([delegate_ respondsToSelector:@selector(tabbedPDFController:willChangeVisibleDocument:)]) {
        allowChange = [delegate_ tabbedPDFController:self willChangeVisibleDocument:newDocument];
    }
    
    // only set if allowed
    if (allowChange) {
        PSPDFDocument *oldDocument = self.visibleDocument;
        [self setVisibleDocument:newDocument animated:YES scrollToPosition:NO];
        
        if ([delegate_ respondsToSelector:@selector(tabbedPDFController:didChangeVisibleDocument:)]) {
            [delegate_ tabbedPDFController:self didChangeVisibleDocument:oldDocument];
        }
    }
}

- (void)tabBarView:(PSPDFTabBarView *)tabBarView didSelectCloseButtonOfTabAtIndex:(NSUInteger)index {
    NSMutableArray *newDocuments = [self.documents mutableCopy];
    [newDocuments removeObjectAtIndex:index];
    
    BOOL allowChange = YES;
    if ([delegate_ respondsToSelector:@selector(tabbedPDFController:willChangeDocuments::)]) {
        allowChange = [delegate_ tabbedPDFController:self willChangeDocuments:newDocuments];
    }

    // only set if allowed
    if (allowChange) {
        NSArray *oldDocumentsSet = self.documents;
        self.documents = newDocuments;
        
        if ([delegate_ respondsToSelector:@selector(tabbedPDFController:didChangeDocuments:)]) {
            [delegate_ tabbedPDFController:self didChangeDocuments:oldDocumentsSet];
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFTabBarViewDataSource

- (NSInteger)numberOfTabsInTabBarView:(PSPDFTabBarView *)tabBarView {
    return [self.documents count];
}

- (NSString *)tabBarView:(PSPDFTabBarView *)tabBarView titleForTabAtIndex:(NSUInteger)index {
    return [[self.documents objectAtIndex:index] title];
}

@end
