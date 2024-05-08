//
//  HKTableViewController.h
//  HKLayoutDemo
//
//  Created by Edward on 2018/4/18.
//  Copyright © 2018年 Edward. All rights reserved.
//

#import "HKBaseViewController.h"

@interface HKTableViewController : HKBaseViewController

@end


#pragma mark - UITableView
@interface HKTableView : UITableView

@end


#pragma mark - HKTableViewCell
@interface HKTableViewCell : UITableViewCell
//- (void)setCellTitle:(NSString *)title content:(NSString *)content time:(NSString *)time;
- (void)configureWithData:(NSString *)data className:(NSString *)className;
@end
