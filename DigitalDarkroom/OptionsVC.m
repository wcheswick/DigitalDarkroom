//
//  OptionsVC.m
//  SciEx
//
//  Created by ches on 3/17/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "OptionsVC.h"
#import "Defines.h"

@interface OptionsVC ()

@end

@implementation OptionsVC

@synthesize options;

- (id) initWithOptions:(Options *) o {
    self = [super init];
    if (self) {
        self.options = o;
    }
    return self;
}

#define LABEL_W 100
#define LABEL_FONT_SIZE 20

#define SWITCH_W    30
#define SWITCH_H    SWITCH_W
#define VSEP    10

#define TABLE_W 150
#define TABLE_H (40*5)

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableHeaderView = nil;
    self.tableView.tableFooterView = nil;

    CGRect f = self.view.frame;
    f.size = CGSizeMake(TABLE_W, TABLE_H);
    self.view.frame = f;
    
#ifdef NOTDOINGIT
    self.title = @"Options";
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(doDone:)];
    self.navigationItem.leftBarButtonItem = rightBarButton;
    
    CGRect lr = CGRectMake(SEP, BELOW(self.navigationController.navigationBar.frame)+VSEP, LABEL_W, LABEL_FONT_SIZE+4);
    CGRect sr = CGRectMake(RIGHT(lr) + SEP, lr.origin.y, SWITCH_W, SWITCH_H);
    UILabel *reticleLabel = [[UILabel alloc] initWithFrame:lr];
    reticleLabel.text = @"Reticle";
    [self.view addSubview:reticleLabel];
    
    UISwitch *reticleSwitch = [[UISwitch alloc] initWithFrame:sr];
    reticleSwitch.on = options.reticle;
    [self.view addSubview:reticleSwitch];
    
    lr.origin.y = sr.origin.y = BELOW(lr) + VSEP;
    UILabel *plusLabel = [[UILabel alloc] initWithFrame:lr];
    plusLabel.text = @"+";
    [self.view addSubview:plusLabel];
    UISwitch *plusSwitch = [[UISwitch alloc] initWithFrame:sr];
    plusSwitch.on = options.stackingMode;
    [self.view addSubview:plusSwitch];
    
    lr.origin.y = sr.origin.y = BELOW(lr) + VSEP;
    UILabel *hiresLabel = [[UILabel alloc] initWithFrame:lr];
    hiresLabel.text = @"Hi res";
    [self.view addSubview:hiresLabel];
    UISwitch *hiresSwitch = [[UISwitch alloc] initWithFrame:sr];
    hiresSwitch.on = options.needHires;
    [self.view addSubview:hiresSwitch];
    
    lr.origin.y = sr.origin.y = BELOW(lr) + VSEP;
    UILabel *execDebugLabel = [[UILabel alloc] initWithFrame:lr];
    execDebugLabel.text = @"Debug exec";
    [self.view addSubview:execDebugLabel];
    UISwitch *execDebugSwitch = [[UISwitch alloc] initWithFrame:sr];
    execDebugSwitch.on = options.executeDebug;
    [self.view addSubview:execDebugSwitch];
    
    SET_VIEW_HEIGHT(self.view, BELOW(lr));
    SET_VIEW_WIDTH(self.view, RIGHT(sr) + SEP);
#endif

    self.view.backgroundColor = [UIColor whiteColor];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return OPTION_COUNT + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *key = @"OptionCells";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:key];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:key];
    }
    if (indexPath.row < OPTION_COUNT) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.selectionStyle = UITableViewCellStyleDefault;
        cell.contentView.backgroundColor = [UIColor yellowColor];
        switch (indexPath.row) {
            case 0:
                cell.largeContentTitle = @"Build mode";
                cell.accessoryType = options.stackingMode ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
            case 1:
                cell.largeContentTitle = @"Debug exec";
                cell.accessoryType = options.executeDebug ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
           case 2:
                cell.largeContentTitle = @"Hi res";
                cell.accessoryType = options.needHires ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
            case 3:
                cell.largeContentTitle = @"Reticle";
                cell.accessoryType = options.reticle ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                break;
       }
    } else {   // bottom cell is Dismiss
        assert(indexPath.row == OPTION_COUNT);
        UILabel *dismiss = [[UILabel alloc] initWithFrame:cell.contentView.frame];
        dismiss.largeContentTitle = @"Dismiss";
        dismiss.textColor = [UIColor redColor];
        dismiss.backgroundColor = [UIColor orangeColor];
        dismiss.textAlignment = NSTextAlignmentCenter;
        dismiss.font = [UIFont boldSystemFontOfSize:cell.contentView.frame.size.height];
        dismiss.adjustsFontSizeToFitWidth = YES;
        [cell.contentView addSubview:dismiss];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < OPTION_COUNT) {
        switch (indexPath.row) {
            case 0:
                options.stackingMode = !options.stackingMode;
                break;
            case 1:
                options.executeDebug = !options.executeDebug;
                break;
           case 2:
                options.needHires = !options.needHires;
                break;
            case 3:
                options.reticle = !options.reticle;
                break;
       }
    } else {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
