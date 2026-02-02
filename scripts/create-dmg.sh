#!/bin/bash

# Build configuration
APP_NAME="Peek"
DMG_NAME="Peek-Installer"
BUILD_DIR="build/Release"

# Build the app
echo "Building ${APP_NAME}..."
xcodebuild -scheme "${APP_NAME}" -configuration Release -derivedDataPath ./build clean build

# Create temporary DMG directory
TMP_DMG_DIR=$(mktemp -d)
echo "Created temporary directory: ${TMP_DMG_DIR}"

# Copy app to temp directory
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${TMP_DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${TMP_DMG_DIR}/Applications"

# Create the DMG
echo "Creating DMG..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${TMP_DMG_DIR}" -ov -format UDZO "${DMG_NAME}.dmg"

# Clean up
rm -rf "${TMP_DMG_DIR}"

echo "DMG created: ${DMG_NAME}.dmg"
