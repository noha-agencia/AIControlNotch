#!/usr/bin/env bash
# Builds .build/AIControlNotch.app (release, ad-hoc signed) with aicontrolnotch-tap inside.
#   --install  copies the app to /Applications and the tap to
#              ~/Library/Application Support/AIControlNotch/bin (the path the status line uses).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
BUNDLE_ID="com.noha.aicontrolnotch"
APP=".build/AIControlNotch.app"
SUPPORT_BIN="$HOME/Library/Application Support/AIControlNotch/bin"

install_app=false
for arg in "$@"; do
    case "$arg" in
        --install) install_app=true ;;
        *) echo "usage: $0 [--install]" >&2; exit 64 ;;
    esac
done

echo "› building (release)"
swift build -c release --product AIControlNotch
swift build -c release --product aicontrolnotch-tap
BIN="$(swift build -c release --show-bin-path)"

echo "› assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp "$BIN/AIControlNotch" "$APP/Contents/MacOS/AIControlNotch"
cp "$BIN/aicontrolnotch-tap" "$APP/Contents/Helpers/aicontrolnotch-tap"

ICON_DIR="$(mktemp -d)"
trap 'rm -rf "$ICON_DIR"' EXIT
"$BIN/AIControlNotch" --render-icon "$ICON_DIR" >/dev/null
iconutil --convert icns "$ICON_DIR/AppIcon.iconset" --output "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AIControlNotch</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>AIControlNotch</string>
    <key>CFBundleDisplayName</key><string>AIControlNotch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "› signing (ad-hoc)"
codesign --force --sign - "$APP/Contents/Helpers/aicontrolnotch-tap"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

if $install_app; then
    echo "› installing to /Applications and $SUPPORT_BIN"
    rm -rf "/Applications/AIControlNotch.app"
    cp -R "$APP" "/Applications/AIControlNotch.app"
    (umask 077; mkdir -p "$SUPPORT_BIN")
    cp "$APP/Contents/Helpers/aicontrolnotch-tap" "$SUPPORT_BIN/aicontrolnotch-tap"
fi

echo "✓ $APP ($VERSION)"
