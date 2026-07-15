#!/bin/bash

set -euo pipefail

BASE_REF=${1:-}
CONFIG_FILE="Configuration/Version.xcconfig"

if [ -z "$BASE_REF" ]; then
    echo "Usage: $0 <base-ref>"
    exit 1
fi

if ! git cat-file -e "$BASE_REF^{commit}" 2>/dev/null; then
    echo "Base ref $BASE_REF is unavailable; fetch it before checking the version bump."
    exit 1
fi

release_relevant_files=$(git diff --name-only "$BASE_REF"...HEAD -- \
    Peek \
    Peek.xcodeproj \
    Configuration \
    scripts/build-unsigned.sh \
    scripts/create-dmg.sh \
    scripts/create-simple-dmg.sh)

if [ -z "$release_relevant_files" ]; then
    echo "No release-relevant app changes; no version bump required."
    exit 0
fi

if ! git cat-file -e "$BASE_REF:$CONFIG_FILE" 2>/dev/null; then
    echo "Centralized versioning is new in this change; $CONFIG_FILE establishes the baseline."
    exit 0
fi

base_config=$(git show "$BASE_REF:$CONFIG_FILE")
base_build=$(awk -F ' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' <<< "$base_config")
current_build=$(awk -F ' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' "$CONFIG_FILE")

if [[ ! "$base_build" =~ ^[1-9][0-9]*$ ]] || [[ ! "$current_build" =~ ^[1-9][0-9]*$ ]]; then
    echo "Cannot compare invalid build numbers: base=$base_build current=$current_build"
    exit 1
fi

if [ "$current_build" -le "$base_build" ]; then
    echo "Release-relevant files changed, but build $current_build is not greater than base build $base_build."
    echo "Run scripts/bump-version.sh with the appropriate bump and update the changelog and handoff."
    exit 1
fi

echo "Release-relevant changes advance the build from $base_build to $current_build."
