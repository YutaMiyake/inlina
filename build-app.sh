#!/bin/bash
set -e

APP_NAME="inlina"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Building ${APP_NAME} in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp Info.plist "${CONTENTS}/Info.plist"

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${RESOURCES}/AppIcon.icns"
    echo "Copied app icon"
fi

# Copy KeyboardShortcuts bundle resources if they exist
RESOURCE_BUNDLE=$(find "${BUILD_DIR}" -name "KeyboardShortcuts_KeyboardShortcuts.bundle" -type d 2>/dev/null | head -1)
if [ -n "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${RESOURCES}/"
    echo "Copied KeyboardShortcuts resource bundle"
fi

# Sign with entitlements (ad-hoc for local use)
echo "Signing app bundle..."
codesign --force --deep --sign - --entitlements Entitlements.plist "${APP_BUNDLE}"

echo ""
echo "Done! ${APP_BUNDLE} created."
echo ""
echo "To install:"
echo "  cp -R ${APP_BUNDLE} /Applications/"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "NOTE: On first launch, grant Accessibility permission in:"
echo "  System Settings > Privacy & Security > Accessibility"
