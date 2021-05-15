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

#define HELP_FN @"newhelp.html"

@interface HelpVC ()

@property (nonatomic, strong)   WKWebView *webView;
@property (nonatomic, strong)   NSURL *startURL;
@property (nonatomic, strong)   NSMutableArray *sectionTags;   // specific to general, slash separated
@property (weak) UIViewController *lastPresentedController;

@end

@implementation HelpVC

@synthesize webView;
@synthesize startURL;
@synthesize sectionTags;
@synthesize lastPresentedController;

- (id)initWithSection:(NSString * __nullable)tags {
    self = [super init];
    if (self) {
        sectionTags = nil;
        if (tags) {
            NSMutableCharacterSet *okChars = [NSMutableCharacterSet alphanumericCharacterSet];
            [okChars addCharactersInString:@"/"];
            NSCharacterSet *discardChars = [okChars invertedSet];
            NSString *cleanTags = [[tags componentsSeparatedByCharactersInSet:discardChars]
                                   componentsJoinedByString:@""];
            sectionTags = [[cleanTags pathComponents] mutableCopy];
            NSLog(@"help: section tags are:  %@", sectionTags);
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.opaque = YES;

    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(doDone:)];
    self.navigationItem.leftBarButtonItem = leftBarButton;

 //   WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
//        config.ignoresViewportScaleLimits = YES;
//    webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:config];
    webView = [[WKWebView alloc] initWithFrame:self.view.frame];
    webView.navigationDelegate = self;
//    webView.UIDelegate = self;
    [self.view addSubview:webView];
    [self startLoadingTag];
}

// we have an array of HTML tags to go to, from general to specific.  This routine
// attempts to load the most specific tag left, or the default URL if none left.

- (void) startLoadingTag {
    NSURL *helpURL;
    NSString *htmlPath = [@"file://" stringByAppendingString:
                          [[NSBundle mainBundle] pathForResource:HELP_FN
                                                          ofType:@""]];
    NSString *tag = [sectionTags lastObject];
    if (tag) {
        [sectionTags removeLastObject];
        helpURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#%@",
                                        htmlPath, tag]];
    } else
        helpURL = [NSURL URLWithString:htmlPath];
    assert(helpURL);
    NSURL *directoryURL = [helpURL URLByDeletingLastPathComponent];
    [webView loadFileURL:helpURL allowingReadAccessToURL:directoryURL] ;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"request: %@", navigationAction.request);
    decisionHandler(WKNavigationActionPolicyAllow);

#ifdef NOTDEF
    // check whether this request should be stopped - if this is redirect_uri (like user is already authorized)
    if (...) {
        self.webView.navigationDelegate = nil;

        // do what is needed to send authorization data back
        self.completionBlock(...);

        // close current view controller
        [self dismissViewControllerAnimated:YES completion:nil];

        // stop executing current request
        decisionHandler(WKNavigationActionPolicyCancel);

    } else {
        // otherwise allow current request
        decisionHandler(WKNavigationActionPolicyAllow);
    }
#endif
}

- (WKWebView *)webView:(WKWebView *)webView
createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
   forNavigationAction:(WKNavigationAction *)navigationAction
        windowFeatures:(WKWindowFeatures *)windowFeatures {
  if (!navigationAction.targetFrame.isMainFrame) {
    [webView loadRequest:navigationAction.request];
  }

  return nil;
}

- (IBAction)doDone:(UISwipeGestureRecognizer *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"Digital Darkroom help";
    
    webView.frame = self.view.frame;
}

- (void)webView:(WKWebView *)webView
didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"WWWWW %s", __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView
didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"WWWWW %s", __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"WWWWW %s: %@", __PRETTY_FUNCTION__, [error localizedDescription]);
}

- (void)webView:(WKWebView *)webView
didCommitNavigation:(WKNavigation *)navigation {
    NSLog(@"WWWWW %s", __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"WWWWW %s: %@", __PRETTY_FUNCTION__, [error localizedDescription]);
}

- (void)webView:(WKWebView *)webView
didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"WWWWW %s", __PRETTY_FUNCTION__);
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"WWWWW %s", __PRETTY_FUNCTION__);
}

@end
