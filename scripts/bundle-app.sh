#!/usr/bin/env bash
# 用法: ./scripts/bundle-app.sh   —— 将 release 可执行文件打包成 AppManager.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP="dist/AppManager.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/AppManager" "$APP/Contents/MacOS/AppManager"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AppManager</string>
    <key>CFBundleIdentifier</key><string>local.appmanager</string>
    <key>CFBundleName</key><string>AppManager</string>
    <key>CFBundleDisplayName</key><string>AppManager</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"  # ad-hoc 签名
echo "✅ 打包完成: $APP"
