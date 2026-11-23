#!/bin/bash
# Fails when a design value is hardcoded outside the design system.
# Colors, fonts, spacing, radius and sizes must come from
# Peek/Sources/Presentation/DesignSystem/ (PeekColor, PeekFont, PeekIcon,
# PeekSpacing, PeekRadius, PeekMetrics). `spacing: 0` is allowed.

set -euo pipefail

cd "$(dirname "$0")/.."

SOURCES="Peek/Sources"
DESIGN_SYSTEM="Peek/Sources/Presentation/DesignSystem"

status=0

check() {
    local description="$1"
    local pattern="$2"
    local matches
    matches=$(grep -rnE --include='*.swift' "$pattern" "$SOURCES" | grep -v "^$DESIGN_SYSTEM/" || true)
    if [ -n "$matches" ]; then
        echo "error: $description (use a design-system token):"
        echo "$matches"
        echo
        status=1
    fi
}

check "hex or RGB color literal" '(Color|NSColor)\((hex:|red:|srgbRed:|calibratedRed:|deviceRed:)|"#[0-9A-Fa-f]{6}'
check "system color used as a design color" '(Color|NSColor)\.(systemRed|systemOrange|systemBlue|systemGreen|red|orange|blue|green|yellow|purple|pink|gray)\b'
check "hardcoded font size" '\.system\(size:'
check "hardcoded corner radius" 'cornerRadius: *[0-9]'
check "hardcoded padding" '\.padding\((\.[a-zA-Z]+, *)?[0-9]'
check "hardcoded stack spacing" 'spacing: *([1-9]|0\.[0-9])'
check "hardcoded frame size" '\.frame\([^)]*(width|height|maxWidth|maxHeight|minWidth|minHeight): *[0-9]'
check "hardcoded line width" 'lineWidth: *[0-9]'

if [ "$status" -eq 0 ]; then
    echo "Design tokens OK: no hardcoded design values outside $DESIGN_SYSTEM."
fi

exit "$status"
