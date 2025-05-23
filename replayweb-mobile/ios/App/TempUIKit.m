#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>
#import <GCDWebServer/GCDWebServer.h>
#import <Capacitor/Capacitor.h>

// This file is used to force Xcode to link against UIKit and other frameworks
// It will be compiled as part of the project build process
void dummyFunction() {
    // This function is never called, it just ensures the imports are used
    UIView *view = [[UIView alloc] init];
    WKWebView *webView = [[WKWebView alloc] init];
    NSString *string = @"Hello";
    GCDWebServer *server = [[GCDWebServer alloc] init];
}
