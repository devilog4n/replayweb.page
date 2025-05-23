#!/bin/bash

# Comprehensive script to fix UIKit import issues in iOS project
echo "Starting comprehensive fix for iOS project..."

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

# Fix AppDelegate.swift
echo "Fixing AppDelegate.swift..."
cat > App/AppDelegate.swift << EOF
import UIKit
import WebKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    // Background task identifier for maintaining web server in background
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize and start GCDWebServer first
        let serverStarted = WebServerManager.shared.startServer()
        if !serverStarted {
            print("Warning: Failed to start web server")
        }
        
        // Create and set up the main view controller with WKWebView
        let mainVC = MainViewController()
        
        // Set up window with the main view controller
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = mainVC
        window?.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Start background task to keep web server running
        backgroundTask = application.beginBackgroundTask { [weak self] in
            // End the task if time expires
            if let task = self?.backgroundTask, task != .invalid {
                application.endBackgroundTask(task)
                self?.backgroundTask = .invalid
            }
        }
        
        // Notify the MainViewController that we're entering background
        NotificationCenter.default.post(name: NSNotification.Name("AppEnteringBackground"), object: nil)
        
        // Ensure the server keeps running in the background
        WebServerManager.shared.ensureServerRunning()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // End the background task if it's active
        if backgroundTask != .invalid {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("AppDelegate: Ended background task")
        }
        
        // Ensure the server is running
        if !WebServerManager.shared.isRunning {
            print("AppDelegate: Restarting web server after returning to foreground")
            WebServerManager.shared.startServer()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Find MainViewController and refresh Service Worker registrations
        if let rootVC = window?.rootViewController as? MainViewController {
            // Verify Service Worker registrations are intact
            rootVC.checkServiceWorkerRegistration()
            
            // Check network connectivity
            rootVC.checkNetworkConnectivity()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Stop the web server when the app terminates
        WebServerManager.shared.stopServer()
        
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
EOF

# Fix MainViewController.swift
echo "Fixing MainViewController.swift..."
sed -i '' '1,6s/import Foundation.*$/import Foundation\nimport UIKit\nimport WebKit\nimport Combine\nimport Network/' App/MainViewController.swift

# Fix other Swift files with UIKit import issues
echo "Fixing other Swift files with UIKit import issues..."
for file in App/FilePicker.swift App/WebServerManager.swift App/AppTypes.swift; do
  if [ -f "$file" ]; then
    echo "Fixing imports in $file"
    sed -i '' '1,5s/import FrameworkImports/import UIKit/' "$file"
    sed -i '' '1,5s/import Foundation.*$/import Foundation\nimport UIKit/' "$file"
  fi
done

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

# Clean the build folder to remove any cached artifacts
echo "Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*

# Clean and reinstall pods with proper encoding
echo "Cleaning and reinstalling pods..."
pod deintegrate
pod install

echo "Comprehensive fix complete. Please rebuild the project in Xcode."
