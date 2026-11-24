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

verify_app_signature() {
    local app_path="$1"
    local signing_info

    echo "Verifying strict app signature..."
    codesign --verify --deep --strict --verbose=2 "${app_path}"

    signing_info=$(codesign -dvv "${app_path}" 2>&1)
    if ! grep -Fq "Authority=Developer ID Application:" <<< "${signing_info}"; then
        echo "Error: ${app_path} is not signed with a Developer ID Application certificate." >&2
        exit 1
    fi
    if ! grep -Fq "TeamIdentifier=${APPLE_TEAM_ID}" <<< "${signing_info}"; then
        echo "Error: ${app_path} signature does not match APPLE_TEAM_ID." >&2
        exit 1
    fi
    if ! grep -Fq "Runtime Version" <<< "${signing_info}"; then
        echo "Error: ${app_path} is missing the Hardened Runtime signature." >&2
        exit 1
    fi
}

verify_app_entitlements() {
    local app_path="$1"
    local entitlements_path="$2"

    echo "Verifying release entitlements..."
    codesign -d --entitlements :- "${app_path}" > "${entitlements_path}"
    plutil -lint "${entitlements_path}"

    if [ "$(plutil -extract com.apple.security.personal-information.calendars raw -o - "${entitlements_path}")" != "true" ]; then
        echo "Error: release app is missing the calendar-access entitlement." >&2
        exit 1
    fi
    if plutil -extract com.apple.security.get-task-allow raw -o - "${entitlements_path}" 2>/dev/null | grep -qx "true"; then
        echo "Error: release app enables com.apple.security.get-task-allow." >&2
        exit 1
    fi
}

verify_dmg_artifact() {
    local mount_dir="$1"
    local mounted_app_path="${mount_dir}/${APP_NAME}.app"

    echo "Verifying DMG integrity and notarization ticket..."
    hdiutil verify "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
    spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}"

    hdiutil attach -nobrowse -readonly -mountpoint "${mount_dir}" "${DMG_PATH}"
    if [ ! -d "${mounted_app_path}" ] || [ ! -L "${mount_dir}/Applications" ]; then
        echo "Error: DMG contents are missing ${APP_NAME}.app or the Applications link." >&2
        exit 1
    fi
    verify_app_signature "${mounted_app_path}"
    spctl --assess --type execute --verbose=4 "${mounted_app_path}"
    hdiutil detach "${mount_dir}"
}

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
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=YES \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
    build

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: built app not found at ${APP_PATH}" >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
TMP_DMG_DIR="${TMP_DIR}/dmg-contents"
ENTITLEMENTS_PATH="${TMP_DIR}/release-entitlements.plist"
MOUNT_DIR=""
mkdir -p "${TMP_DMG_DIR}"
cleanup() {
    if [ -n "${MOUNT_DIR}" ] && [ -d "${MOUNT_DIR}" ]; then
        hdiutil detach "${MOUNT_DIR}" -quiet || true
        rmdir "${MOUNT_DIR}" || true
    fi
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

verify_app_signature "${APP_PATH}"
verify_app_entitlements "${APP_PATH}" "${ENTITLEMENTS_PATH}"
bash scripts/check-app-bundle.sh "${APP_PATH}" --distribution

# Package the signed app into a DMG.
echo "Packaging DMG..."

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

MOUNT_DIR=$(mktemp -d)
verify_dmg_artifact "${MOUNT_DIR}"
if [ -d "${MOUNT_DIR}" ]; then
    rmdir "${MOUNT_DIR}"
fi
MOUNT_DIR=""

echo "Release ready: ${DMG_PATH}"
