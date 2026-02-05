#!/bin/bash

# Build configuration
APP_NAME="Peek"
BUILD_DIR="build/Release"

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

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "App location: ${BUILD_DIR}/${APP_NAME}.app"
    
    # Copy to Applications for easy access
    echo "Copying to /Applications..."
    sudo cp -R "${BUILD_DIR}/${APP_NAME}.app" /Applications/
    
    echo "✅ ${APP_NAME} installed to /Applications"
    echo "Note: You may need to allow the app in System Settings → Privacy & Security"
else
    echo "❌ Build failed"
    exit 1
fi
