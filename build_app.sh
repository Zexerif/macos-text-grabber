#!/bin/bash

APP_NAME="TextGrabber"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "🧹 Cleaning up..."
rm -rf "${BUNDLE_DIR}"
rm -f "${APP_NAME}.zip"

echo "🏗️ Creating App Bundle structure..."
mkdir -p "${MACOS_DIR}"

echo "🔨 Compiling ${APP_NAME}..."
swiftc TextGrabber.swift -o "${MACOS_DIR}/${APP_NAME}" -framework AppKit -framework Vision -framework SwiftUI

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed."
    exit 1
fi

echo "📝 Adding Info.plist..."
cat <<PLIST > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</PLIST>

echo "📦 Packaging into ZIP..."
zip -r "${APP_NAME}.zip" "${BUNDLE_DIR}"

echo "✅ Success! ${APP_NAME}.app is ready."
echo "🚀 You can now move ${APP_NAME}.app to your Applications folder."
