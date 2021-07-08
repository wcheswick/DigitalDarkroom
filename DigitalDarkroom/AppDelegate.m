//
//  AppDelegate.m
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import "AppDelegate.h"
#import "MainVC.h"

@interface AppDelegate ()

@property (nonatomic, strong)   UINavigationController *navController;
@property (nonatomic, strong)   MainVC *mainVC;

@end

@implementation AppDelegate

@synthesize navController;
@synthesize mainVC;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    if (![[NSFileManager defaultManager] changeCurrentDirectoryPath: documentsDirectory])
        NSLog(@"Could not cd to documents directory ***");
    
    self.window = [[UIWindow alloc]
                   initWithFrame:[[UIScreen mainScreen] bounds]];
    mainVC = [[MainVC alloc] init];
    navController = [[UINavigationController alloc]
                     initWithRootViewController:mainVC];
    
    [[NSNotificationCenter defaultCenter] addObserver:mainVC
                                             selector:@selector(newDeviceOrientation)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (BOOL) application:(UIApplication *)application
             openURL:(nonnull NSURL *)url
             options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"incoming URL: %@", url);
    NSLog(@"     options: %@", options);
    NSString* urlPath = url.path;
    if(![[NSFileManager defaultManager] isReadableFileAtPath:urlPath])
    {
        if([url startAccessingSecurityScopedResource])
        {
            NSString* docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString* destPath = [NSString stringWithFormat:@"%@/%@", docsPath, [url.path lastPathComponent]];
            NSLog(@"copy file %@ to %@", docsPath, destPath);
//            urlPath = [FileHandler copyFileAtPath:url.path toPath:destPath increment:YES];
            [url stopAccessingSecurityScopedResource];
        }
    }
    return YES;
}

#ifdef notdef
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    NSLog(@"opening app with URL %@", [url absoluteString]);
    if (!url)
        return NO;
    [mainVC loadImageWithURL: url]loadImageWithURL
    return YES;
}
#endif

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
