//
//  PSPDFOutlineViewController.m
//  PSPDFKit
//
//  Copyright 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKit.h"
#import "PSPDFOutlineCell.h"
#import "PSPDFBarButtonItem.h"

@interface PSPDFOutlineViewController() <PSPDFOutlineCellDelegate> {
    PSPDFViewController *_pdfController; // weak
    NSArray *visibleItems_;
}
@property(nonatomic, strong) PSPDFDocument *document;

@end

@implementation PSPDFOutlineViewController 

@synthesize outline = outline_;
@synthesize document = document_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - private

- (void)setTopVisibleCellItem {
    NSUInteger firstElement = 0;
    NSArray *visibleCells = self.tableView.visibleCells;
    if ([visibleCells count]) {
        firstElement = [self.tableView indexPathForCell:[visibleCells objectAtIndex:0]].row;
        
        // or is the cell almost not visible anymore?
        CGRect firstCellRect = [[visibleCells objectAtIndex:0] frame];
        if ([visibleCells count] > 1 && (self.tableView.contentOffset.y + firstCellRect.size.height/2 > firstCellRect.origin.y + firstCellRect.size.height)) {
            firstElement++;
        }
    }
    self.document.outlineParser.firstVisibleElement = firstElement;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)document pdfController:(PSPDFViewController *)pdfController {
    if ((self = [super init])) {
        document_ = document;
        _pdfController = pdfController; // weak        
        self.title = document.title;
        outline_ = document.outlineParser.outline;
        visibleItems_ = [outline_ flattenedChildren];
        
        // if there are less than 3 root outline elements, expand them per default
        if ([visibleItems_ count] < 3) {
            for (PSPDFOutlineElement *element in outline_.children) {
                if (element.children > 0) {
                    element.expanded = YES;
                }
            }
            visibleItems_ = [outline_ flattenedChildren];
        }
    }
    return self;
}

- (void)dealloc {
    _pdfController = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

-(BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // try to restore last position
    NSUInteger firstVisibleItem = self.document.outlineParser.firstVisibleElement;
    if (firstVisibleItem < [visibleItems_ count]) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:firstVisibleItem inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self setTopVisibleCellItem];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSPDFOutlineElement *outlineElement = [visibleItems_ objectAtIndex:indexPath.row];
            
    // close controller
    if (PSIsIpad()) {
        [PSPDFBarButtonItem dismissPopoverAnimated:YES];
    }else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    // scroll to page (-1 because we manage pages internally different)
    [_pdfController scrollToPage:outlineElement.page-1 animated:PSPDFShouldAnimate()]; // animate is too slow
    _pdfController.viewMode = PSPDFViewModeDocument; // ensure that we show documents
}

// Cell delegate
- (void)outlineCellDidTapDisclosureButton:(PSPDFOutlineCell *)cell {
	PSPDFOutlineElement *item = cell.outlineElement;
    if (item.children.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[visibleItems_ indexOfObject:item] inSection:0];
        
        if (item.isExpanded) {
            NSMutableArray *removedIndexPaths = [NSMutableArray array];
            NSArray *collapsedChildren = [item flattenedChildren];
            item.expanded = NO;
            for (int i=0; i<collapsedChildren.count; i++) {
                NSIndexPath *removedIndexPath = [NSIndexPath indexPathForRow:indexPath.row + i + 1 inSection:0];
                [removedIndexPaths addObject:removedIndexPath];
            }
            visibleItems_ = [outline_ flattenedChildren];
            if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_5_0) {
                [self.tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationBottom];
            }else {
                [self.tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            }            
        }else {
            item.expanded = YES;
            NSArray *expandedChildren = [item flattenedChildren];
            NSMutableArray *addedIndexPaths = [NSMutableArray array];
            for (int i=0; i<expandedChildren.count; i++) {
                NSIndexPath *addedIndexPath = [NSIndexPath indexPathForRow:indexPath.row + i + 1 inSection:0];
                [addedIndexPaths addObject:addedIndexPath];
            }
            visibleItems_ = [outline_ flattenedChildren];
            
            if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_5_0) {
                [self.tableView insertRowsAtIndexPaths:addedIndexPaths withRowAnimation:UITableViewRowAnimationTop];
            }else {
                [self.tableView insertRowsAtIndexPaths:addedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            }            
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger sections = [visibleItems_ count] > 0 ? 1 : 0;
    return sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = [visibleItems_ count];
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"PSPDFOutlineCell";

	PSPDFOutlineCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];    
	if (cell == nil) {
		cell = [[PSPDFOutlineCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    
    cell.outlineElement = [visibleItems_ objectAtIndex:indexPath.row];;
    cell.delegate = self;

    return cell;
}

@end
