#!/bin/bash

# Script to fix framework import issues in iOS project
echo "Fixing framework import issues in iOS project..."

# Set UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create a Swift file that uses conditional imports
cat > App/FrameworkImports.swift << EOF
// FrameworkImports.swift
// This file provides conditional imports for all required frameworks

import Foundation

// System frameworks with conditional imports
#if canImport(UIKit)
import UIKit
#endif

#if canImport(WebKit)
import WebKit
#endif

// Third-party frameworks with conditional imports
#if canImport(Capacitor)
import Capacitor
#endif

#if canImport(GCDWebServer)
@_exported import GCDWebServer
#endif

// Define UIKit types if not available
#if !canImport(UIKit)
// Basic UIKit type definitions for compilation
public typealias UIViewController = NSObject
public typealias UIView = NSObject
public typealias UIColor = NSObject
public typealias UIFont = NSObject
public typealias UIImage = NSObject
public typealias UIApplication = NSObject
public typealias UIBackgroundTaskIdentifier = Int
public extension UIBackgroundTaskIdentifier {
    static let invalid = 0
}
public typealias UIResponder = NSObject
public typealias UIWindow = NSObject
public typealias UIScreen = NSObject
#endif
EOF

echo "Created FrameworkImports.swift with conditional imports"

# Update all Swift files to use the new imports file
for file in App/*.swift; do
  if [ "$file" != "App/FrameworkImports.swift" ]; then
    echo "Updating imports in $file"
    # Add import for FrameworkImports at the top of each file
    sed -i '' '1s/^/import Foundation\n/' "$file"
    # Replace UIKit imports with FrameworkImports
    sed -i '' 's/import UIKit/import FrameworkImports/' "$file"
    # Replace WebKit imports with FrameworkImports if not already imported
    sed -i '' 's/import WebKit/import FrameworkImports/' "$file"
    # Replace Capacitor imports with FrameworkImports
    sed -i '' 's/import Capacitor/import FrameworkImports/' "$file"
    # Replace GCDWebServer imports with FrameworkImports
    sed -i '' 's/import GCDWebServer/import FrameworkImports/' "$file"
  fi
done

echo "Updated all Swift files to use FrameworkImports"

# Clean the build folder to remove any cached artifacts
echo "Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*

echo "Fix complete. Please rebuild the project in Xcode."
