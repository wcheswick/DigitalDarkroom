//
//  SelectInputVC.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/5/20.
//  Copyright © 2020 Cheswick.com. All rights reserved.
//

#import "SelectInputVC.h"

#define THUMB_H 100
#define W   200

@interface SelectInputVC ()

@property (nonatomic, strong) NSArray *fileNames;
@property (nonatomic, strong) NSMutableArray *images;

@end

@implementation SelectInputVC

@synthesize caller;
@synthesize fileNames;
@synthesize images;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    fileNames = [[NSArray alloc] initWithObjects:
                 @"hsvrainbow.jpeg",
                 @"ishihara6.jpeg",
                 @"cube.jpeg",
                 @"ishihara8.jpeg",
                 @"ishihara25.jpeg", @"ishihara29.jpeg",
                 @"ishihara45.jpeg", @"ishihara56.jpeg",
                 @"rainbow.gif", nil];
    images = [[NSMutableArray alloc] initWithCapacity:fileNames.count];
    for (NSString *name in fileNames) {
        NSString *file = [@"images/" stringByAppendingString:name];
        NSString *imagePath = [[NSBundle mainBundle] pathForResource:file ofType:@""];
        if (!imagePath) {
            NSLog(@"**** Image not found: %@", name);
            [images addObject:@""];
        } else {
            UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
            NSLog(@"%@", imagePath);
            NSLog(@"  size: %.0f x %.0f", image.size.width, image.size.height);
            if (!image)
                NSLog(@"*** image failed to load: %@", imagePath);
            else
                [images addObject:image];
        }
    }
    NSLog(@"%lu images found", (unsigned long)images.count);
    self.view.frame = CGRectMake(0, 0, W, 49*2 + images.count*THUMB_H);
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return NCAMERA + images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"InputCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    switch(indexPath.row) {
        case FrontCamera:
            cell.textLabel.text = @"Front camera";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
            break;
        case BackCamera:
            cell.textLabel.text = @"Rear camera";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:20];
            break;
        default: {
            UIImageView *thumbView = [[UIImageView alloc] initWithFrame:cell.contentView.frame];
            thumbView.contentMode =  UIViewContentModeScaleAspectFit;
            UIImage *image = [images objectAtIndex:indexPath.row - NCAMERA];
            thumbView.image = image;
            [cell.contentView addSubview:thumbView];
        }
    }
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case FrontCamera:
            NSLog(@"selected front camera");
            [caller selectCamera:FrontCamera];
            break;
        case BackCamera:
            NSLog(@"selected back camera");
            [caller selectCamera:BackCamera];
            break;
        default:
            NSLog(@"selected image %ld, %@", (long)indexPath.row - NCAMERA,
                  [fileNames objectAtIndex:indexPath.row - NCAMERA]);
            UIImage *image = [images objectAtIndex:indexPath.row - NCAMERA];
            [caller useImage:image];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case FrontCamera:
        case BackCamera:
            return 60;
        default:
            return 60;
    }
}

@end
