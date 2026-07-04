#!/bin/bash
#
# Turn Clipboard.svg into a macOS .icns bundle.
#
# CLT-only path: NSImage rasterizes the SVG in a tiny Swift helper, then
# iconutil packs the standard sizes. No Xcode, no rsvg, no ImageMagick.
#
# Output: <repo>/Sources/Clipboard/Resources/AppIcon.icns
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SVG="$REPO_ROOT/Clipboard.svg"
OUT_DIR="$REPO_ROOT/Sources/Clipboard/Resources"
OUT_ICNS="$OUT_DIR/AppIcon.icns"

CLT_ROOT="/Library/Developer/CommandLineTools"
SWIFTC="$CLT_ROOT/usr/bin/swiftc"
SDK="$CLT_ROOT/SDKs/MacOSX.sdk"

HOST_ARCH="$(uname -m)"
TARGET_TRIPLE="${HOST_ARCH}-apple-macos13.0"

if [ ! -f "$SVG" ]; then
    echo "❌ $SVG not found"; exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

RENDERER="$TMP/render_icon"
"$SWIFTC" \
    -target "$TARGET_TRIPLE" \
    -sdk "$SDK" \
    -O \
    -o "$RENDERER" \
    "$REPO_ROOT/Scripts/render_icon.swift"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

# Names iconutil expects. Retina variants use @2x suffix.
declare -a SIZES=(
    "16    icon_16x16.png"
    "32    icon_16x16@2x.png"
    "32    icon_32x32.png"
    "64    icon_32x32@2x.png"
    "128   icon_128x128.png"
    "256   icon_128x128@2x.png"
    "256   icon_256x256.png"
    "512   icon_256x256@2x.png"
    "512   icon_512x512.png"
    "1024  icon_512x512@2x.png"
)

for entry in "${SIZES[@]}"; do
    read -r size name <<< "$entry"
    "$RENDERER" "$SVG" "$size" "$ICONSET/$name"
done

mkdir -p "$OUT_DIR"
iconutil -c icns "$ICONSET" -o "$OUT_ICNS"

echo "✅ Built $OUT_ICNS"
