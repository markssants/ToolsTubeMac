#!/bin/zsh
# Compila o ToolsTube e monta build/ToolsTube.app
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ToolsTube.app"
echo "▸ Compilando (release)…"
swift build -c release --arch arm64 --arch x86_64 2>/dev/null || swift build -c release
BIN="$(swift build -c release --show-bin-path 2>/dev/null)/ToolsTube"
[[ -f "$BIN" ]] || BIN=".build/apple/Products/Release/ToolsTube"

echo "▸ Montando bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ToolsTube"

echo "▸ Gerando ícone…"
TMP="$(mktemp -d)"
swift scripts/make_icon.swift "$TMP/icon.png" >/dev/null
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ToolsTube</string>
  <key>CFBundleDisplayName</key><string>ToolsTube</string>
  <key>CFBundleIdentifier</key><string>com.toolstube.mac</string>
  <key>CFBundleExecutable</key><string>ToolsTube</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "✓ Pronto: $APP"
echo "  Para instalar: cp -R $APP /Applications/"
