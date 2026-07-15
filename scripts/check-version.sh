#!/bin/bash

set -euo pipefail

CONFIG_FILE="Configuration/Version.xcconfig"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing $CONFIG_FILE"
    exit 1
fi

marketing_version=$(awk -F ' = ' '/^MARKETING_VERSION = / { print $2 }' "$CONFIG_FILE")
build_number=$(awk -F ' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' "$CONFIG_FILE")

if [[ ! "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid MARKETING_VERSION: $marketing_version"
    exit 1
fi

if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid CURRENT_PROJECT_VERSION: $build_number"
    exit 1
fi

if ! grep -Fq '<string>$(MARKETING_VERSION)</string>' Peek/Resources/Info.plist; then
    echo "Info.plist is not wired to MARKETING_VERSION"
    exit 1
fi

if ! grep -Fq '<string>$(CURRENT_PROJECT_VERSION)</string>' Peek/Resources/Info.plist; then
    echo "Info.plist is not wired to CURRENT_PROJECT_VERSION"
    exit 1
fi

if grep -Eq 'MARKETING_VERSION = [0-9]|CURRENT_PROJECT_VERSION = [0-9]' Peek.xcodeproj/project.pbxproj; then
    echo "Version duplicated in project.pbxproj; keep it only in $CONFIG_FILE"
    exit 1
fi

configuration_reference_count=$(grep -Ec 'baseConfigurationReference = .* /\* Version\.xcconfig \*/;' Peek.xcodeproj/project.pbxproj || true)
if [ "$configuration_reference_count" -ne 2 ]; then
    echo "Expected Debug and Release app configurations to inherit $CONFIG_FILE"
    exit 1
fi

echo "Peek version $marketing_version ($build_number) is valid."
