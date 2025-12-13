#!/bin/bash

# Build MacWindowManager.app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="MacWindowManager"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Compile Swift sources
echo "Compiling Swift sources..."
swiftc \
    -O \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework AppKit \
    -framework Carbon \
    -framework ApplicationServices \
    "$SCRIPT_DIR/Sources/main.swift" \
    "$SCRIPT_DIR/Sources/AppDelegate.swift" \
    "$SCRIPT_DIR/Sources/WindowManager.swift" \
    "$SCRIPT_DIR/Sources/HotkeyManager.swift" \
    "$SCRIPT_DIR/Sources/TileEngine.swift" \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Also build for Intel if needed (universal binary)
if [[ "$(uname -m)" == "arm64" ]]; then
    echo "Building universal binary..."
    swiftc \
        -O \
        -target x86_64-apple-macosx12.0 \
        -sdk $(xcrun --show-sdk-path) \
        -framework AppKit \
        -framework Carbon \
        -framework ApplicationServices \
        "$SCRIPT_DIR/Sources/main.swift" \
        "$SCRIPT_DIR/Sources/AppDelegate.swift" \
        "$SCRIPT_DIR/Sources/WindowManager.swift" \
        "$SCRIPT_DIR/Sources/HotkeyManager.swift" \
        "$SCRIPT_DIR/Sources/TileEngine.swift" \
        -o "$BUILD_DIR/$APP_NAME-x86_64"

    # Create universal binary
    lipo -create \
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
        "$BUILD_DIR/$APP_NAME-x86_64" \
        -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME-universal"

    mv "$APP_BUNDLE/Contents/MacOS/$APP_NAME-universal" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    rm "$BUILD_DIR/$APP_NAME-x86_64"
fi

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
