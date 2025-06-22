#!/bin/bash

# Development installation script for talk_to_text
# This creates a fixed installation path to avoid accessibility permission issues

set -e

PROJECT_DIR="/Users/yamazakiyuuta/Library/Mobile Documents/com~apple~CloudDocs/Product/talk_to_text"
INSTALL_DIR="/Applications/TalkToText-Dev"
APP_NAME="talk_to_text.app"
BUILD_DIR="$PROJECT_DIR/DerivedData/talk_to_text-*/Build/Products/Debug"

echo "🔨 Building application..."
cd "$PROJECT_DIR"
xcodebuild -project talk_to_text.xcodeproj -scheme talk_to_text -configuration Debug

echo "📁 Finding built application..."
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/talk_to_text-*/Build/Products/Debug -name "$APP_NAME" -type d | head -1)

if [[ -z "$BUILT_APP" ]]; then
    echo "❌ Error: Could not find built application"
    exit 1
fi

echo "Found: $BUILT_APP"

echo "📦 Installing to fixed location..."
# Remove old installation
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy app to fixed location
cp -R "$BUILT_APP" "$INSTALL_DIR/"

echo "✅ Installation complete!"
echo "📍 App installed at: $INSTALL_DIR/$APP_NAME"
echo ""
echo "🔐 For accessibility permissions, use this fixed path:"
echo "   $INSTALL_DIR/$APP_NAME"
echo ""
echo "🚀 To launch: open '$INSTALL_DIR/$APP_NAME'"