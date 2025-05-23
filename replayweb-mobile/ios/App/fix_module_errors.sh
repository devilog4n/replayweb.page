#!/bin/bash
# Fix for persistent "No such module 'UIKit'" errors

# Set UTF-8 encoding
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "Fixing 'No such module UIKit' errors..."

# 1. Create a module.modulemap file in the project
# This ensures UIKit and other frameworks are properly mapped
mkdir -p App/Modules
cat > App/Modules/module.modulemap << EOF
framework module UIKit [system] {
  header "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/UIKit.framework/Headers/UIKit.h"
  export *
}

framework module WebKit [system] {
  header "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/WebKit.framework/Headers/WebKit.h"
  export *
}

framework module Foundation [system] {
  header "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/Foundation.framework/Headers/Foundation.h"
  export *
}
EOF

echo "Created module map file"

# 2. Update the project.xcconfig file to include the module map directory
cat > xcconfig_additions.txt << EOF

// Fix for "No such module 'UIKit'" errors
SWIFT_INCLUDE_PATHS = $(SRCROOT)/App/Modules
EOF

# Check if xcconfig files already exist
if [ -f "Pods/Target Support Files/Pods-App/Pods-App.debug.xcconfig" ]; then
  echo "Updating debug.xcconfig file"
  cat xcconfig_additions.txt >> "Pods/Target Support Files/Pods-App/Pods-App.debug.xcconfig"
fi

if [ -f "Pods/Target Support Files/Pods-App/Pods-App.release.xcconfig" ]; then
  echo "Updating release.xcconfig file"
  cat xcconfig_additions.txt >> "Pods/Target Support Files/Pods-App/Pods-App.release.xcconfig"
fi

# 3. Force Xcode to recognize the bridging header
echo "Updating bridging header..."
touch App/ReplayWeb-Bridging-Header.h

# 4. Reset simulator to force module cache refresh
echo "Resetting iOS simulator..."
xcrun simctl shutdown all
xcrun simctl erase all

# 5. Clear Xcode module cache
echo "Clearing Xcode module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*

echo "Done! Now try the following steps:"
echo "1. Close Xcode completely"
echo "2. Reopen the App.xcworkspace (not xcodeproj)"
echo "3. Select Product > Clean Build Folder (Cmd+Shift+K)"
echo "4. Build the project (Cmd+B)"
