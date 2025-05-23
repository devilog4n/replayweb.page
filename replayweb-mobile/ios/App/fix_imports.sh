#!/bin/bash

# Script to fix UIKit import issues in iOS project
echo "Fixing UIKit import issues in iOS project..."

# Create a temporary Objective-C file that imports UIKit
cat > TempUIKit.m << EOF
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
EOF

# Update the bridging header
cat > App/ReplayWeb-Bridging-Header.h << EOF
//
//  ReplayWeb-Bridging-Header.h
//  App
//
//  Created for ReplayWeb Mobile project
//

#ifndef ReplayWeb_Bridging_Header_h
#define ReplayWeb_Bridging_Header_h

// Import system frameworks
@import UIKit;
@import WebKit;
@import Foundation;

// Import third-party frameworks
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <Capacitor/Capacitor.h>

// Forward declarations for our custom classes
@class WebServerManager;
@class MainViewController;
@class FilePicker;

#endif /* ReplayWeb_Bridging_Header_h */
EOF

echo "Created temporary Objective-C file and updated bridging header"

# Clean and reinstall pods
echo "Cleaning and reinstalling pods..."
pod deintegrate
pod install

echo "Fix complete. Please rebuild the project in Xcode."
