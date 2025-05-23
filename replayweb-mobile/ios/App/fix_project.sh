#!/bin/bash

# Script to fix UIKit import issues in iOS project
echo "Fixing UIKit import issues in iOS project..."

# Set UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Update the bridging header with proper framework imports
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
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

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

echo "Updated bridging header with proper framework imports"

# Clean the build folder to remove any cached artifacts
echo "Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*

# Clean and reinstall pods with proper encoding
echo "Cleaning and reinstalling pods..."
pod deintegrate
pod install

echo "Fix complete. Please rebuild the project in Xcode."
