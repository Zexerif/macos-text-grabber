#!/bin/bash
set -e

APP_NAME="TextGrabberPro"
BUNDLE_DIR="${APP_NAME}.app"
MACOS_DIR="${BUNDLE_DIR}/Contents/MacOS"

# Remove stale old builds that pollute the TCC Screen Recording list
rm -rf "TextGrabber.app" "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"

echo "🔨 Compiling..."
swiftc TextGrabber.swift \
    -o "${MACOS_DIR}/${APP_NAME}" \
    -framework AppKit \
    -framework Vision \
    -framework SwiftUI

echo "📝 Writing Info.plist..."
# Use printf instead of heredoc to avoid confusion with the </PLIST> XML closing tag
printf '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>%s</string>
    <key>CFBundleIdentifier</key>
    <string>com.zexerif.%s</string>
    <key>CFBundleName</key>
    <string>%s</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>TextGrabber needs Screen Recording access to capture the area you select so it can extract text from it. No recording is ever saved or transmitted.</string>
    <key>NSScreenRecordingUsageDescription</key>
    <string>TextGrabber needs Screen Recording access to capture the area you select so it can extract text from it. No recording is ever saved or transmitted.</string>
</dict>
</plist>
' "${APP_NAME}" "${APP_NAME}" "${APP_NAME}" > "${BUNDLE_DIR}/Contents/Info.plist"

chmod +x "${MACOS_DIR}/${APP_NAME}"

# Ad-hoc sign so macOS TCC tracks the Screen Recording permission
# by a stable identity across rebuilds.
echo "🔏 Signing..."
codesign --deep --force -s - "${BUNDLE_DIR}"

echo "✅ Build complete: ${BUNDLE_DIR}"
