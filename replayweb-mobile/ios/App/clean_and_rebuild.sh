#!/bin/bash
# Script to perform a complete clean and rebuild cycle for the ReplayWeb iOS app

echo "Starting complete clean and rebuild process..."

# Set UTF-8 encoding for CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# 1. Clean Xcode derived data (the most thorough cleaning)
echo "Cleaning Xcode derived data for App project..."
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*

# 2. Clean CocoaPods
echo "Deintegrating CocoaPods..."
pod deintegrate

# 3. Remove Pods directory
echo "Removing Pods directory..."
rm -rf Pods
rm -rf Podfile.lock

# 4. Reinstall pods
echo "Reinstalling pods..."
pod install

# 5. Touch bridging header to ensure Xcode recognizes it
echo "Updating bridging header timestamp..."
touch App/ReplayWeb-Bridging-Header.h

echo "Clean and rebuild preparation complete."
echo "Please open App.xcworkspace in Xcode and build the project (Cmd+B)."
echo "If you still encounter 'No such module' errors, try:"
echo "1. In Xcode, select Product > Clean Build Folder (Cmd+Shift+K)"
echo "2. Restart Xcode"
echo "3. Rebuild the project (Cmd+B)"
