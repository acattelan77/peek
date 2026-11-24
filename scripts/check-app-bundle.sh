#!/bin/bash

set -euo pipefail

# Checks that a built Peek.app carries what App Store Connect and App Review
# expect: the privacy manifest, the export-compliance key, usage descriptions
# for every protected resource Peek touches, and the sandbox entitlements.
#
# Usage: scripts/check-app-bundle.sh <path/to/Peek.app> [--distribution]
#
# --distribution also requires a signed app without get-task-allow, which is
# true only for an exported App Store or Developer ID build.

APP_PATH="${1:-}"
MODE="${2:-}"

if [ -z "${APP_PATH}" ] || [ ! -d "${APP_PATH}" ]; then
    echo "Usage: $0 <path/to/Peek.app> [--distribution]" >&2
    exit 2
fi

INFO="${APP_PATH}/Contents/Info.plist"
MANIFEST="${APP_PATH}/Contents/Resources/PrivacyInfo.xcprivacy"
failures=0

fail() {
    echo "FAIL: $1" >&2
    failures=$((failures + 1))
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

echo "Checking ${APP_PATH}"

if [ -f "${MANIFEST}" ]; then
    plutil -lint "${MANIFEST}" >/dev/null || fail "PrivacyInfo.xcprivacy is not a valid plist"
    [ "$(plist_value "${MANIFEST}" NSPrivacyTracking)" = "false" ] || fail "NSPrivacyTracking must be false"
    plist_value "${MANIFEST}" NSPrivacyAccessedAPITypes | grep -q "NSPrivacyAccessedAPICategoryUserDefaults" \
        || fail "privacy manifest does not declare the UserDefaults reason"
    plist_value "${MANIFEST}" NSPrivacyAccessedAPITypes | grep -q "NSPrivacyAccessedAPICategoryFileTimestamp" \
        || fail "privacy manifest does not declare the file timestamp reason"
else
    fail "PrivacyInfo.xcprivacy is missing from Contents/Resources"
fi

[ "$(plist_value "${INFO}" ITSAppUsesNonExemptEncryption)" = "false" ] \
    || fail "ITSAppUsesNonExemptEncryption must be present and false"
[ "$(plist_value "${INFO}" LSApplicationCategoryType)" = "public.app-category.productivity" ] \
    || [ "$(plist_value "${INFO}" LSApplicationCategoryType)" = "public.app-category.utilities" ] \
    || fail "LSApplicationCategoryType is missing or unexpected"
for key in NSCalendarsUsageDescription NSCalendarsFullAccessUsageDescription NSContactsUsageDescription; do
    [ -n "$(plist_value "${INFO}" "${key}")" ] || fail "${key} is missing"
done

ICON_COUNT=$(find "${APP_PATH}/Contents/Resources" -maxdepth 1 \( -name "AppIcon.icns" -o -name "Assets.car" \) | wc -l | tr -d ' ')
[ "${ICON_COUNT}" -gt 0 ] || fail "no compiled app icon (AppIcon.icns or Assets.car)"

if codesign -d "${APP_PATH}" >/dev/null 2>&1; then
    ENTITLEMENTS=$(mktemp)
    trap 'rm -f "${ENTITLEMENTS}"' EXIT
    codesign -d --entitlements :- "${APP_PATH}" > "${ENTITLEMENTS}" 2>/dev/null || true
    if [ -s "${ENTITLEMENTS}" ]; then
        for key in com.apple.security.app-sandbox \
                   com.apple.security.personal-information.calendars \
                   com.apple.security.personal-information.addressbook \
                   com.apple.security.files.user-selected.read-only \
                   com.apple.security.files.bookmarks.app-scope \
                   com.apple.security.network.client; do
            [ "$(plist_value "${ENTITLEMENTS}" "${key}")" = "true" ] || fail "entitlement ${key} is missing"
        done
        if [ "${MODE}" = "--distribution" ] && [ "$(plist_value "${ENTITLEMENTS}" com.apple.security.get-task-allow)" = "true" ]; then
            fail "distribution build enables com.apple.security.get-task-allow"
        fi
    elif [ "${MODE}" = "--distribution" ]; then
        fail "distribution build has no entitlements"
    else
        echo "note: unsigned build, entitlements not checked"
    fi
elif [ "${MODE}" = "--distribution" ]; then
    fail "distribution build is not signed"
else
    echo "note: unsigned build, entitlements not checked"
fi

if [ "${failures}" -gt 0 ]; then
    echo "${failures} check(s) failed." >&2
    exit 1
fi
echo "App bundle checks passed."
