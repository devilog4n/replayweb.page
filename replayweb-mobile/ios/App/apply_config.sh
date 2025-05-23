#!/bin/bash

# Apply xcconfig settings to the Xcode project
defaults write /Users/leandroalmeida/replayweb-projects/replayweb-mobile/ios/App/App.xcodeproj/project.pbxproj -dict-add "buildSettings" "{SWIFT_INCLUDE_PATHS = \"\$(SRCROOT)/App/Modules\"; MODULEMAP_FILE = \"\$(SRCROOT)/App/Modules/module.modulemap\"; FRAMEWORK_SEARCH_PATHS = \"\$(inherited) \$(DEVELOPER_FRAMEWORKS_DIR) \$(PLATFORM_DIR)/Developer/Library/Frameworks\"; OTHER_LDFLAGS = \"\$(inherited) -framework UIKit -framework WebKit -framework Foundation\"; CLANG_ENABLE_MODULES = YES; DEFINES_MODULE = YES; SWIFT_INSTALL_OBJC_HEADER = YES;}"

echo "Configuration applied successfully!"
