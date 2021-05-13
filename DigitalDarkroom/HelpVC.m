//
//  HelpVCViewController.m
//  DigitalDarkroom
//
//  Created by William Cheswick on 3/23/21.
//  Copyright © 2021 Cheswick.com. All rights reserved.
//

#import "HelpVC.h"
#import <WebKit/WKWebView.h>
#import <WebKit/WKWebViewConfiguration.h>

#define HELP_FN @"help.html"

@interface HelpVC ()

@property (nonatomic, strong)   WKWebView *webView;
@property (nonatomic, strong)   NSURL *startURL;
@property (weak) UIViewController *lastPresentedController;

@end

@implementation HelpVC

@synthesize webView;
@synthesize startURL;
@synthesize lastPresentedController;

- (id)initWithSection:(NSString * __nullable)section {
    self = [super init];
    if (self) {
        NSString *lastComponent;
        if (section) {
            lastComponent = [NSString stringWithFormat:@"%@#%@", HELP_FN, section];
        } else
            lastComponent = HELP_FN;
        lastComponent = HELP_FN;

        NSString *path = [[NSBundle mainBundle] pathForResource:lastComponent ofType:@""];
        NSURL *url = [NSURL URLWithString:path];
        assert(url);
        NSLog(@"help URL: %@", url);
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
//        config.ignoresViewportScaleLimits = YES;
        webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:config];
        webView.navigationDelegate = self;
        [self.view addSubview:webView];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Documentation";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;

     UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                       target:self action:@selector(doDone:)];
     self.navigationItem.leftBarButtonItem = leftBarButton;
}

- (IBAction)doDone:(UISwipeGestureRecognizer *)sender {
    [webView removeFromSuperview];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"Digital Darkroom help";
    
    webView.frame = self.view.frame;
    NSURLRequest *nsrequest=[NSURLRequest requestWithURL:startURL];
    [webView loadRequest:nsrequest];
}

- (void)webView:(WKWebView *)webView
didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView
didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, [error localizedDescription]);
}

- (void)webView:(WKWebView *)webView
didCommitNavigation:(WKNavigation *)navigation {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, [error localizedDescription]);
}

- (void)webView:(WKWebView *)webView
didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

@end
