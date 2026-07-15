#!/bin/bash

set -euo pipefail

# Build, package, notarize, and staple a public Peek release.
#
# Required environment variables:
#   APPLE_DEVELOPER_IDENTITY  - The exact "Developer ID Application: ..." identity string.
#   APPLE_ID                  - Apple ID for notarytool.
#   APPLE_APP_SPECIFIC_PASSWORD - App-specific password for notarytool.
#   APPLE_TEAM_ID             - Apple Developer Team ID.
#
# Optional:
#   OUTPUT_DIR                - Directory for the final DMG (default: artifacts).

APP_NAME="Peek"
BUILD_DIR="build/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
OUTPUT_DIR="${OUTPUT_DIR:-artifacts}"

VERSION=$(awk -F ' = ' '/^MARKETING_VERSION = / { print $2 }' Configuration/Version.xcconfig)
BUILD=$(awk -F ' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' Configuration/Version.xcconfig)
DMG_NAME="${APP_NAME}-${VERSION}.${BUILD}"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"

for var in APPLE_DEVELOPER_IDENTITY APPLE_ID APPLE_APP_SPECIFIC_PASSWORD APPLE_TEAM_ID; do
    if [ -z "${!var:-}" ]; then
        echo "Error: ${var} is not set." >&2
        exit 1
    fi
done

echo "Releasing ${APP_NAME} ${VERSION} (${BUILD})..."

# Build a signed Release app.
echo "Building signed Release app..."
xcodebuild \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath ./build \
    CODE_SIGN_IDENTITY="${APPLE_DEVELOPER_IDENTITY}" \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=YES \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
    build

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: built app not found at ${APP_PATH}" >&2
    exit 1
fi

# Package the signed app into a DMG.
echo "Packaging DMG..."
TMP_DMG_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DMG_DIR}"' EXIT

cp -R "${APP_PATH}" "${TMP_DMG_DIR}/"
ln -s /Applications "${TMP_DMG_DIR}/Applications"

mkdir -p "${OUTPUT_DIR}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${TMP_DMG_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# Notarize and staple the DMG.
echo "Submitting DMG for notarization..."
xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

# Also staple the app bundle so direct zip/app exports are valid.
xcrun stapler staple "${APP_PATH}"

echo "Release ready: ${DMG_PATH}"
