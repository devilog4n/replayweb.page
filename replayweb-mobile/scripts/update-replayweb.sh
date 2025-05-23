#!/bin/bash
# Script to update ReplayWeb.page assets in the iOS app
# Usage: ./update-replayweb.sh [version]

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_WWW_DIR="$PROJECT_ROOT/ios/App/App/www"
TEMP_DIR="$PROJECT_ROOT/temp"
DEFAULT_VERSION="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Get version from command line or use default
VERSION=${1:-$DEFAULT_VERSION}

print_header "Updating ReplayWeb.page assets to version: $VERSION"

# Create temp directory if it doesn't exist
mkdir -p "$TEMP_DIR"

# Create www directory if it doesn't exist
mkdir -p "$IOS_WWW_DIR"

# Download ReplayWeb.page release
print_header "Downloading ReplayWeb.page"

if [ "$VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/webrecorder/replayweb.page/releases/latest/download/rwp.zip"
else
    DOWNLOAD_URL="https://github.com/webrecorder/replayweb.page/releases/download/$VERSION/rwp.zip"
fi

echo "Downloading from: $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/rwp.zip"

if [ $? -ne 0 ]; then
    print_error "Failed to download ReplayWeb.page"
    exit 1
fi

# Extract the downloaded zip
print_header "Extracting ReplayWeb.page assets"
unzip -o "$TEMP_DIR/rwp.zip" -d "$TEMP_DIR/rwp"

if [ $? -ne 0 ]; then
    print_error "Failed to extract ReplayWeb.page assets"
    exit 1
fi

# Copy assets to iOS www directory
print_header "Copying assets to iOS app"

# Backup custom files
echo "Backing up custom files..."
if [ -f "$IOS_WWW_DIR/index.html" ]; then
    cp "$IOS_WWW_DIR/index.html" "$TEMP_DIR/index.html.bak"
fi

# Copy all files from the extracted directory to the www directory
echo "Copying ReplayWeb.page assets to iOS app..."
cp -R "$TEMP_DIR/rwp/"* "$IOS_WWW_DIR/"

# Restore custom files
echo "Restoring custom files..."
if [ -f "$TEMP_DIR/index.html.bak" ]; then
    cp "$TEMP_DIR/index.html.bak" "$IOS_WWW_DIR/index.html"
fi

# Ensure Service Worker registration is included
print_header "Checking Service Worker registration"

if grep -q "serviceWorker.register" "$IOS_WWW_DIR/index.html"; then
    echo "Service Worker registration found in index.html"
else
    print_warning "Service Worker registration not found in index.html"
    echo "Adding Service Worker registration to index.html..."
    
    # Add Service Worker registration script
    sed -i '' -e '/<\/head>/i\
    <script>\
        if ("serviceWorker" in navigator) {\
            navigator.serviceWorker.register("/sw.js")\
                .then(registration => {\
                    console.log("Service Worker registered with scope:", registration.scope);\
                })\
                .catch(error => {\
                    console.error("Service Worker registration failed:", error);\
                });\
        }\
    </script>' "$IOS_WWW_DIR/index.html"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to add Service Worker registration to index.html"
    else
        print_success "Added Service Worker registration to index.html"
    fi
fi

# Clean up
print_header "Cleaning up"
rm -rf "$TEMP_DIR/rwp"
rm -f "$TEMP_DIR/rwp.zip"
rm -f "$TEMP_DIR/index.html.bak"

print_success "ReplayWeb.page assets updated successfully!"
echo "Don't forget to rebuild the iOS app to include the updated assets."
