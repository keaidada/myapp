#!/usr/bin/env bash
# 用法: ./scripts/bundle-app.sh   —— 将 release 可执行文件打包成 myapp.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP="dist/myapp.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/myapp" "$APP/Contents/MacOS/myapp"

# 应用图标
if [[ -f "assets/AppIcon.icns" ]]; then
    cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>myapp</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>local.myapp</string>
    <key>CFBundleName</key><string>myapp</string>
    <key>CFBundleDisplayName</key><string>myapp</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 优先用固定证书签名（CDHash 稳定，辅助功能授权不随打包失效）；
# 无证书时退回 ad-hoc（每次签名变化，需重新授权辅助功能）
if security find-identity -p codesigning 2>/dev/null | grep -q "myapp-dev"; then
    codesign --force --sign "myapp-dev" "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "✅ 打包完成: $APP"
