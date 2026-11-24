#!/bin/bash

set -euo pipefail

# Archive Peek, export a signed Mac App Store package, verify it, and
# optionally upload it to App Store Connect (TestFlight).
#
# Signing is cloud-managed: Xcode uses an App Store Connect API key to create
# or fetch the Apple Distribution and Mac Installer Distribution certificates
# and the Mac App Store provisioning profile. No .p12 or profile is stored in
# the repository or in GitHub secrets.
#
# Required environment variables:
#   APPLE_TEAM_ID        - Apple Developer Team ID.
#   ASC_KEY_ID           - App Store Connect API key ID.
#   ASC_ISSUER_ID        - App Store Connect API issuer ID.
#   ASC_KEY_PATH         - Path to the AuthKey_<ASC_KEY_ID>.p8 file.
#
# Optional:
#   UPLOAD=1             - Also upload the verified build to App Store Connect.
#   PEEK_BUNDLE_ID       - Override PRODUCT_BUNDLE_IDENTIFIER (for example when
#                          com.peek.app is not available in App Store Connect).
#   OUTPUT_DIR           - Directory for the exported package (default: artifacts/app-store).

APP_NAME="Peek"
ARCHIVE_PATH="build/${APP_NAME}-AppStore.xcarchive"
OUTPUT_DIR="${OUTPUT_DIR:-artifacts/app-store}"

VERSION=$(awk -F ' = ' '/^MARKETING_VERSION = / { print $2 }' Configuration/Version.xcconfig)
BUILD=$(awk -F ' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' Configuration/Version.xcconfig)

for var in APPLE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
    if [ -z "${!var:-}" ]; then
        echo "Error: ${var} is not set." >&2
        exit 1
    fi
done
if [ ! -f "${ASC_KEY_PATH}" ]; then
    echo "Error: ASC_KEY_PATH does not point to a file." >&2
    exit 1
fi

AUTH_ARGS=(
    -allowProvisioningUpdates
    -authenticationKeyPath "${ASC_KEY_PATH}"
    -authenticationKeyID "${ASC_KEY_ID}"
    -authenticationKeyIssuerID "${ASC_ISSUER_ID}"
)

BUNDLE_ARGS=()
if [ -n "${PEEK_BUNDLE_ID:-}" ]; then
    BUNDLE_ARGS=(PRODUCT_BUNDLE_IDENTIFIER="${PEEK_BUNDLE_ID}")
fi

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

write_export_options() {
    local destination="$1"
    local path="$2"
    cat > "${path}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>${destination}</string>
	<key>teamID</key>
	<string>${APPLE_TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST
    plutil -lint "${path}" >/dev/null
}

echo "Archiving ${APP_NAME} ${VERSION} (${BUILD}) for the Mac App Store..."
rm -rf "${ARCHIVE_PATH}"
xcodebuild \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "${ARCHIVE_PATH}" \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
    CODE_SIGN_STYLE=Automatic \
    ${BUNDLE_ARGS[@]+"${BUNDLE_ARGS[@]}"} \
    "${AUTH_ARGS[@]}" \
    archive

ARCHIVED_APP="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
if [ ! -d "${ARCHIVED_APP}" ]; then
    echo "Error: archived app not found at ${ARCHIVED_APP}" >&2
    exit 1
fi
bash scripts/check-app-bundle.sh "${ARCHIVED_APP}"

echo "Exporting a signed App Store package..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
write_export_options export "${TMP_DIR}/ExportOptions-export.plist"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${TMP_DIR}/ExportOptions-export.plist" \
    -exportPath "${OUTPUT_DIR}" \
    "${AUTH_ARGS[@]}"

PKG_PATH=$(find "${OUTPUT_DIR}" -maxdepth 1 -name "*.pkg" | head -n 1)
if [ -z "${PKG_PATH}" ]; then
    echo "Error: export produced no .pkg in ${OUTPUT_DIR}" >&2
    exit 1
fi

echo "Verifying the installer signature..."
PKG_SIGNATURE=$(pkgutil --check-signature "${PKG_PATH}")
echo "${PKG_SIGNATURE}"
if ! grep -Eq "3rd Party Mac Developer Installer|Mac Installer Distribution" <<< "${PKG_SIGNATURE}"; then
    echo "Error: ${PKG_PATH} is not signed with a Mac Installer Distribution certificate." >&2
    exit 1
fi

echo "Verifying the packaged app..."
pkgutil --expand-full "${PKG_PATH}" "${TMP_DIR}/expanded"
PACKAGED_APP=$(find "${TMP_DIR}/expanded" -type d -name "${APP_NAME}.app" -prune | head -n 1)
if [ -z "${PACKAGED_APP}" ]; then
    echo "Error: ${APP_NAME}.app not found inside ${PKG_PATH}" >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "${PACKAGED_APP}"
SIGNING_INFO=$(codesign -dvv "${PACKAGED_APP}" 2>&1)
if ! grep -Eq "Authority=(Apple Distribution|3rd Party Mac Developer Application):" <<< "${SIGNING_INFO}"; then
    echo "Error: packaged app is not signed for App Store distribution." >&2
    exit 1
fi
if ! grep -Fq "TeamIdentifier=${APPLE_TEAM_ID}" <<< "${SIGNING_INFO}"; then
    echo "Error: packaged app signature does not match APPLE_TEAM_ID." >&2
    exit 1
fi
if [ ! -f "${PACKAGED_APP}/Contents/embedded.provisionprofile" ]; then
    echo "Error: packaged app has no embedded Mac App Store provisioning profile." >&2
    exit 1
fi
bash scripts/check-app-bundle.sh "${PACKAGED_APP}" --distribution
shasum -a 256 "${PKG_PATH}"

if [ "${UPLOAD:-0}" = "1" ]; then
    echo "Uploading to App Store Connect..."
    write_export_options upload "${TMP_DIR}/ExportOptions-upload.plist"
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportOptionsPlist "${TMP_DIR}/ExportOptions-upload.plist" \
        -exportPath "${TMP_DIR}/upload" \
        "${AUTH_ARGS[@]}"
    echo "Uploaded ${VERSION} (${BUILD}). It appears in App Store Connect > TestFlight after processing."
else
    echo "Upload skipped (set UPLOAD=1 to upload)."
fi

echo "App Store package ready: ${PKG_PATH}"
