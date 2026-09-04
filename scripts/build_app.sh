#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "==> Building Quotty release binary..."
SWIFT_BUILD_ARGS=(-c release)
if [ "${QUOTTY_DISABLE_SWIFT_SANDBOX:-0}" = "1" ]; then
    SWIFT_BUILD_ARGS=(--disable-sandbox "${SWIFT_BUILD_ARGS[@]}")
fi
swift build "${SWIFT_BUILD_ARGS[@]}"

APP_NAME="Quotty.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Creating $APP_NAME bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp ".build/release/Quotty" "$MACOS/Quotty"
chmod +x "$MACOS/Quotty"

install -m 644 "assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"
install -m 644 "assets/quotty.png" "$RESOURCES/quotty.png"

cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Quotty</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.quotty.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Quotty</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.3</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

echo "==> Signing $APP_NAME bundle (ad-hoc)..."
codesign --force --deep -s - "$APP_DIR"

echo "==> Quotty.app built successfully at: $APP_DIR"
