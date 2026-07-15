#!/bin/bash

set -euo pipefail

CONFIG_FILE="Configuration/Version.xcconfig"
requested=${1:-}

if [ -z "$requested" ]; then
    echo "Usage: $0 <major|minor|patch|build|X.Y.Z>"
    exit 1
fi

bash scripts/check-version.sh

current_version=$(awk -F ' = ' '/^MARKETING_VERSION = / { print $2 }' "$CONFIG_FILE")
current_build=$(awk -F ' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' "$CONFIG_FILE")
IFS='.' read -r major minor patch <<< "$current_version"

case "$requested" in
    major)
        new_version="$((major + 1)).0.0"
        ;;
    minor)
        new_version="$major.$((minor + 1)).0"
        ;;
    patch)
        new_version="$major.$minor.$((patch + 1))"
        ;;
    build)
        new_version="$current_version"
        ;;
    *)
        if [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            new_version="$requested"
        else
            echo "Invalid bump: $requested"
            exit 1
        fi
        ;;
esac

new_build=$((current_build + 1))
temporary_file=$(mktemp)
trap 'rm -f "$temporary_file"' EXIT

awk -v version="$new_version" -v build="$new_build" '
    /^MARKETING_VERSION = / { print "MARKETING_VERSION = " version; next }
    /^CURRENT_PROJECT_VERSION = / { print "CURRENT_PROJECT_VERSION = " build; next }
    { print }
' "$CONFIG_FILE" > "$temporary_file"

mv "$temporary_file" "$CONFIG_FILE"
trap - EXIT

echo "Bumped Peek from $current_version ($current_build) to $new_version ($new_build)."
echo "Update CHANGELOG.md and docs/HANDOFF.md before handing off."
