#!/bin/zsh
# Builds PokeRun.app and installs it into ~/Applications.
#   ./scripts/build_app.sh            build + install + launch
#   ./scripts/build_app.sh --no-open  build + install only
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

APP_NAME="PokeRun"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

# 1. Sprites (only downloads what's missing)
python3 scripts/fetch_sprites.py

# 2. Compile
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

# 3. Assemble bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp -R Resources/sprites "$APP/Contents/Resources/sprites"
cp -R Resources/sprites_firered "$APP/Contents/Resources/sprites_firered"
cp Resources/names.json "$APP/Contents/Resources/names.json"

# 4. Icon
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swift scripts/make_icon.swift Resources/sprites/25.gif "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PokeRun</string>
    <key>CFBundleDisplayName</key><string>PokéRun</string>
    <key>CFBundleIdentifier</key><string>com.liamkim.pokerun</string>
    <key>CFBundleExecutable</key><string>PokeRun</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Personal build. Pokémon sprites © Nintendo / Creatures / GAME FREAK / The Pokémon Company.</string>
</dict>
</plist>
PLIST

# 5. Ad-hoc sign (needed for launch-at-login on Apple silicon)
codesign --force --deep --sign - "$APP"

# 6. Install
mkdir -p "$INSTALL_DIR"
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP" "$INSTALL_DIR/"
echo "Installed: $INSTALL_DIR/$APP_NAME.app"

if [[ "${1:-}" != "--no-open" ]]; then
  open "$INSTALL_DIR/$APP_NAME.app"
fi
