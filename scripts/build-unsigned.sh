#!/bin/bash

set -euo pipefail

# Build configuration
APP_NAME="Peek"
BUILD_DIR="build/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME} (unsigned)..."

# Build without code signing
xcodebuild \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

if [ ! -d "${APP_PATH}" ]; then
    echo "Build finished but app bundle was not found at: ${APP_PATH}"
    exit 1
fi

echo "Build successful."
echo "App location: ${APP_PATH}"

if [ "${1:-}" = "--install" ]; then
    echo "Copying to /Applications..."
    sudo cp -R "${APP_PATH}" /Applications/
    echo "${APP_NAME} installed to /Applications."
    echo "You may need to allow the app in System Settings > Privacy & Security."
else
    echo "Tip: run ./scripts/build-unsigned.sh --install to copy the app to /Applications."
fi
