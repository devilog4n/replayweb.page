#!/bin/bash

# ReplayWeb iOS Project Configuration Fix Script
# Based on the PRD requirements and optimized TaskMaster configuration
echo "Starting comprehensive ReplayWeb iOS project configuration..."

# Set UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create proper bridging header as specified in the PRD
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

# Create a temporary Objective-C file that imports UIKit
cat > App/FrameworkImporter.m << EOF
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

echo "Created temporary Objective-C file to force framework linking"

# Remove FrameworkImports.swift (this module doesn't exist and causes build errors)
if [ -f "App/FrameworkImports.swift" ]; then
    rm -f App/FrameworkImports.swift
    echo "Removed FrameworkImports.swift module (doesn't exist and causes build errors)"
fi

# Ensure Info.plist has WKAppBoundDomains configured as specified in the PRD
cat > App/Info.plist.template << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
    <string>ReplayWeb Mobile</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>armv7</string>
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UIViewControllerBasedStatusBarAppearance</key>
	<true/>
	<key>WKAppBoundDomains</key>
	<array>
		<string>localhost</string>
	</array>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Web Archive Collection</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Owner</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>org.webrecorder.wacz</string>
				<string>public.archive</string>
				<string>public.zip-archive</string>
			</array>
		</dict>
	</array>
	<key>UTExportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.archive</string>
				<string>public.zip-archive</string>
				<string>public.data</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Web Archive Collection</string>
			<key>UTTypeIdentifier</key>
			<string>org.webrecorder.wacz</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>wacz</string>
				</array>
				<key>public.mime-type</key>
				<array>
					<string>application/wacz</string>
				</array>
			</dict>
		</dict>
	</array>
</dict>
</plist>
EOF

# Only update Info.plist if there are differences
if ! cmp -s App/Info.plist.template App/Info.plist; then
    cp App/Info.plist.template App/Info.plist
    echo "Updated Info.plist with WKAppBoundDomains and proper document type settings"
else
    echo "Info.plist already properly configured"
fi
rm App/Info.plist.template

# Update project.pbxproj to ensure bridging header is properly set
echo "Updating project.pbxproj to ensure bridging header is properly set..."
PBXPROJ="App.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    # Backup the project file
    cp "$PBXPROJ" "${PBXPROJ}.bak"
    
    # Add bridging header setting if it doesn't exist
    if ! grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PBXPROJ"; then
        sed -i '' 's/SWIFT_OPTIMIZATION_LEVEL = "-O";/SWIFT_OPTIMIZATION_LEVEL = "-O";\n\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "App\/ReplayWeb-Bridging-Header.h";/' "$PBXPROJ"
    fi
    
    # Update existing bridging header setting if it exists
    sed -i '' 's/SWIFT_OBJC_BRIDGING_HEADER = ".*";/SWIFT_OBJC_BRIDGING_HEADER = "App\/ReplayWeb-Bridging-Header.h";/' "$PBXPROJ"
    
    echo "Updated project.pbxproj with bridging header settings"
else
    echo "Warning: Could not find project.pbxproj file"
fi

# Fix Swift files with proper imports (removing any FrameworkImports references)
echo "Fixing Swift files with proper imports..."

# Function to fix imports in a file
fix_imports() {
    file=$1
    if [ -f "$file" ]; then
        echo "Fixing imports in $file"
        
        # Create a temporary file
        tmp_file="${file}.tmp"
        
        # Read the first 15 lines to check for imports
        head -15 "$file" > "$tmp_file"
        
        # Check if we need to fix imports (only modify if needed)
        if grep -q "import FrameworkImports" "$tmp_file"; then
            # Fix imports - this pattern matches common import patterns
            sed -i '' '1,15s/import FrameworkImports/import UIKit/' "$file"
            sed -i '' '1,15s/import Foundation.*$/import Foundation\nimport UIKit\nimport WebKit/' "$file"
            
            # Remove duplicate imports
            awk '!seen[$0]++' "$file" > "$tmp_file"
            mv "$tmp_file" "$file"
            
            echo "  Fixed imports in $file"
        else
            echo "  No FrameworkImports found in $file"
            rm "$tmp_file"
        fi
    fi
}

# Fix imports in all Swift files
for swift_file in App/*.swift; do
    fix_imports "$swift_file"
done

# Clean the build folder
echo "Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*

# Prepare a custom capacitor.config.json to align with the PRD's server URL settings
cat > "../capacitor.config.json" << EOF
{
  "appId": "com.example.replayweb",
  "appName": "ReplayWeb Mobile",
  "webDir": "www",
  "server": {
    "url": "http://localhost:8080",
    "cleartext": true,
    "androidScheme": "http"
  },
  "loggingBehavior": "debug",
  "plugins": {
    "SplashScreen": {
      "launchAutoHide": false
    },
    "Http": {
      "enabled": true
    },
    "WebView": {
      "allowNavigation": ["*"],
      "allowGoBackWithBackButton": true,
      "limitsNavigationsToAppBoundDomains": true
    }
  }
}
EOF

echo "Updated capacitor.config.json to use http://localhost:8080 as per PRD requirements"

# Clean and reinstall pods
echo "Cleaning and reinstalling pods..."
pod deintegrate
pod install

echo "ReplayWeb iOS project configuration complete."
echo "This script has:"
echo "1. Removed references to the non-existent FrameworkImports module"
echo "2. Updated all Swift files with proper framework imports"
echo "3. Configured the bridging header according to PRD requirements"
echo "4. Set up WKAppBoundDomains in Info.plist as required for Service Workers"
echo "5. Updated capacitor.config.json to use http://localhost:8080 as per PRD"
echo "6. Reinstalled all pods to ensure proper linking"
echo ""
echo "Please rebuild the project in Xcode."
