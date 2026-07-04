#!/bin/bash
#
# CLT-only build script for Clipboard.app.
#
# Uses /Library/Developer/CommandLineTools/usr/bin/swiftc directly to bypass
# xcrun's requirement for a full Xcode MacOSX.platform bundle. Links against
# system libsqlite3 (which includes FTS5 on Ventura+).
#
# Usage:
#   ./Scripts/build.sh          # debug (default)
#   ./Scripts/build.sh release  # optimized
#   ./Scripts/build.sh run      # build debug then launch
#
set -euo pipefail

MODE="${1:-debug}"

# --- Configuration ------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Clipboard"
BUNDLE_ID="com.local.clipboard"

CLT_ROOT="/Library/Developer/CommandLineTools"
SDK="$CLT_ROOT/SDKs/MacOSX.sdk"
SWIFTC="$CLT_ROOT/usr/bin/swiftc"
TARGET_TRIPLE="x86_64-apple-macos13.0"   # matches Intel Ventura host; change to arm64-apple-macos13.0 on Apple Silicon

BUILD_DIR="$REPO_ROOT/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

# --- Preflight ---------------------------------------------------------------

if [ ! -x "$SWIFTC" ]; then
    echo "❌ swiftc not found at $SWIFTC"
    echo "   Install Command Line Tools:  xcode-select --install"
    exit 1
fi

if [ ! -d "$SDK" ]; then
    echo "❌ macOS SDK not found at $SDK"
    exit 1
fi

# Detect host arch and prefer matching target so we avoid Rosetta.
HOST_ARCH="$(uname -m)"
if [ "$HOST_ARCH" = "arm64" ]; then
    TARGET_TRIPLE="arm64-apple-macos13.0"
fi

echo "🔨 Building $APP_NAME.app  (mode=$MODE, target=$TARGET_TRIPLE)"

# --- Clean & scaffold bundle -------------------------------------------------

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# --- Gather Swift sources ----------------------------------------------------

SWIFT_SOURCES=()
while IFS= read -r -d '' f; do
    SWIFT_SOURCES+=("$f")
done < <(find Sources/Clipboard -type f -name "*.swift" -print0)

echo "   $(printf '%s\n' "${SWIFT_SOURCES[@]}" | wc -l | tr -d ' ') Swift files"

# --- Compile flags -----------------------------------------------------------

COMMON_FLAGS=(
    -sdk "$SDK"
    -target "$TARGET_TRIPLE"
    -swift-version 5
    -parse-as-library
    -module-name "$APP_NAME"
    # Frameworks (dashed args must precede source list per swiftc).
    -framework AppKit
    -framework SwiftUI
    -framework Combine
    -framework Foundation
    -framework Carbon
    -framework CoreFoundation
    -framework CryptoKit
    -framework ServiceManagement
    -framework ApplicationServices
    # Link system SQLite (Ventura ships 3.39+ with FTS5 compiled in).
    -lsqlite3
    # Suppress noisy os_log warnings on private printing.
    -suppress-warnings
)

if [ "$MODE" = "release" ]; then
    COMMON_FLAGS+=(-O -whole-module-optimization)
else
    COMMON_FLAGS+=(-Onone -g)
fi

# --- Compile & link ----------------------------------------------------------

echo "   Compiling…"
"$SWIFTC" \
    "${COMMON_FLAGS[@]}" \
    -o "$MACOS_DIR/$APP_NAME" \
    "${SWIFT_SOURCES[@]}"

# --- Info.plist --------------------------------------------------------------

echo "   Copying Info.plist…"
cp Sources/Clipboard/App/Info.plist "$CONTENTS/Info.plist"

# Ensure the executable name key matches (Info.plist uses $(EXECUTABLE_NAME) which is Xcode-only).
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$CONTENTS/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$CONTENTS/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$CONTENTS/Info.plist"

# --- Resources ---------------------------------------------------------------

echo "   Copying resources…"
# Copy Localizable.strings (base + any *.lproj folders in future).
if [ -f Sources/Clipboard/Resources/Localizable.strings ]; then
    cp Sources/Clipboard/Resources/Localizable.strings "$RESOURCES_DIR/"
fi

# App icon: build .icns from Clipboard.svg if it's missing or stale.
if [ -f Clipboard.svg ]; then
    ICNS="Sources/Clipboard/Resources/AppIcon.icns"
    if [ ! -f "$ICNS" ] || [ Clipboard.svg -nt "$ICNS" ] || [ Scripts/make_icon.sh -nt "$ICNS" ]; then
        echo "   Rendering AppIcon.icns…"
        bash Scripts/make_icon.sh
    fi
    cp "$ICNS" "$RESOURCES_DIR/AppIcon.icns"
fi

# Assets.xcassets needs actool (Xcode-only) to compile into Assets.car.
# Without it, SwiftUI Color("SyntaxKeyword") calls return the fallback color.
# We ship a runtime fallback: SyntaxHighlighter uses hardcoded colors when
# the named colors are not found. See Sources/Clipboard/Core/Highlighting/.
if [ -d Sources/Clipboard/Resources/Assets.xcassets ]; then
    cp -R Sources/Clipboard/Resources/Assets.xcassets "$RESOURCES_DIR/"
    echo "   ⚠️  Assets.xcassets copied raw — actool unavailable in CLT."
    echo "      Named Colors will fall back to hardcoded values at runtime."
fi

# --- Ad-hoc code sign --------------------------------------------------------

echo "   Ad-hoc signing…"
codesign --force --deep --sign - "$APP_BUNDLE"

# --- Optional launch --------------------------------------------------------

if [ "$MODE" = "run" ] || [ "${1:-}" = "run" ]; then
    echo "   Launching…"
    open "$APP_BUNDLE"
fi

echo "✅ Built  $APP_BUNDLE"
echo ""
echo "   Launch:   open $APP_BUNDLE"
echo "   Install:  cp -R $APP_BUNDLE /Applications/"
