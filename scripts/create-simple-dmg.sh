#!/bin/bash

APP_NAME="Peek"
DMG_NAME="Peek-Installer"
OUTPUT_DIR="artifacts"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"

echo "Building ${APP_NAME}..."

# Build without code signing
xcodebuild \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"

# Find the built app
BUILT_APP="./build/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Could not find built app at: $BUILT_APP"
    exit 1
fi

# Create temporary directory for DMG contents
TMP_DMG_DIR=$(mktemp -d)
echo "Creating DMG in temporary directory: ${TMP_DMG_DIR}"

# Copy app to temp directory
cp -R "${BUILT_APP}" "${TMP_DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${TMP_DMG_DIR}/Applications"

# Create the DMG
echo "Creating DMG..."
mkdir -p "${OUTPUT_DIR}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${TMP_DMG_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

# Clean up
rm -rf "${TMP_DMG_DIR}"

echo "✅ DMG created: ${DMG_PATH}"
echo ""
echo "Note: This DMG is not signed or notarized."
echo "When you open it, you may need to:"
echo "1. Right-click the app and select 'Open'"
echo "2. Or go to System Settings → Privacy & Security and allow it"
