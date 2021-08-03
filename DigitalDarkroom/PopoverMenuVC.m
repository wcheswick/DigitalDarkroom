//
//  PopoverMenuVC.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 7/28/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "PopoverMenuVC.h"
#import "Defines.h"

#define TABLE_W    200
#define TABLE_HPL   44

@interface PopoverMenuVC ()

@property (nonatomic, strong)   UINavigationController *navVC;
@property (nonatomic, strong)   UIPopoverPresentationController *popController;
@property (nonatomic, strong)   UITableView *tableView;
@property (nonatomic, copy)     PopoverSelectRow selectRow;
@property (nonatomic, copy)     PopoverFormatCellForRow formatCellForRow;
@property (assign)              int selected;
@property (assign)              id target;
@property (assign)              int menuRows;
@property (nonatomic, strong)   NSString *title;

@end

@implementation PopoverMenuVC

@synthesize navVC, tableView;
@synthesize popController;
@synthesize selected;
@synthesize menuRows;
@synthesize formatCellForRow, selectRow;
@synthesize target, title;

- (id)initWithFrame:(CGRect) f
                      entries:(int)entryCount
                        title:(NSString *) title
                       target:(id)t
                   formatCell:(PopoverFormatCellForRow)formatCell
                   selectRow:(PopoverSelectRow)selectRow {
    self = [super init];
    if (self) {
        selected = POPMENU_ABORTED;
        menuRows = entryCount;
        formatCellForRow = formatCell;
        self.title = title;
        self.selectRow = selectRow;
        self.view.frame = f;
        target = t;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;

    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                      target:self action:@selector(doCancel:)];
    self.navigationItem.rightBarButtonItem = rightBarButton;
    

    tableView = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStylePlain];
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = TABLE_HPL;
}

- (IBAction)doCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// per https://stackoverflow.com/questions/9121466/objective-c-block-property-with-xcode-code-completion
//- (void)setCompletionBlock:(CompletionBlock)completionBlock;

- (UINavigationController *) prepareMenuUnder:(UIBarButtonItem *) barButton {
//               completion:(CompletionBlock)completion {
    UINavigationController *navVC = [[UINavigationController alloc]
                                                 initWithRootViewController:self];
    navVC.navigationController.navigationBarHidden = NO;
    navVC.modalPresentationStyle = UIModalPresentationPopover;
    navVC.title = self.title;

    UIPopoverPresentationController *popController = navVC.popoverPresentationController;
    popController.delegate = self;
    popController.barButtonItem = (UIBarButtonItem *)barButton;
    
    CGRect f = self.view.frame;
    f.size.height = self.navigationController.navigationBar.frame.size.height +
        TABLE_HPL*menuRows;
    f.origin.y = BELOW(navVC.navigationBar.frame);
    tableView.frame = f;
    self.view.frame = f;
    navVC.view.frame = f;
    navVC.preferredContentSize = f.size;
    [self.view addSubview:tableView];
    return navVC;
}

#pragma mark - Plus Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return menuRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *key = @"TableCells";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:key];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:key];
    }
    formatCellForRow(cell, indexPath.row);
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // magic incantation to get the selector call to work.  See the mysterious
    // https://www.programmersought.com/article/3402873615/
    selectRow((int)indexPath.row);
#ifdef OLD
    IMP imp = [target methodForSelector:selectRow];
    PopoverSelectRow *func = (void *) imp;
    func(target, selectRow, (int)indexPath.row);
    void (*func)(id, SEL, int) = (void *)imp;
    func(target, callBack, (int)indexPath.row);
#endif
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
