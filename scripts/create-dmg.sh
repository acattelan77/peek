#!/bin/bash

set -euo pipefail

# Build configuration
APP_NAME="Peek"
DMG_NAME="Peek-Installer"
BUILD_DIR="build/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
OUTPUT_DIR="artifacts"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"
TMP_DMG_DIR=""

cleanup() {
    if [ -n "${TMP_DMG_DIR}" ] && [ -d "${TMP_DMG_DIR}" ]; then
        rm -rf "${TMP_DMG_DIR}"
    fi
}
trap cleanup EXIT

# Build the app with ad-hoc signing so runtime entitlements remain available.
echo "Building ${APP_NAME}..."
xcodebuild \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY=- \
  clean build

if [ ! -d "${APP_PATH}" ]; then
    echo "Build finished but app bundle was not found at: ${APP_PATH}"
    exit 1
fi

# Create temporary DMG directory
TMP_DMG_DIR=$(mktemp -d)
echo "Created temporary directory: ${TMP_DMG_DIR}"

# Copy app to temp directory
cp -R "${APP_PATH}" "${TMP_DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${TMP_DMG_DIR}/Applications"

# Create the DMG
echo "Creating DMG..."
mkdir -p "${OUTPUT_DIR}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${TMP_DMG_DIR}" -ov -format UDZO "${DMG_PATH}"

echo "DMG created: ${DMG_PATH}"
