#!/usr/bin/env bash
# 生成抽象的 myapp 图标（渐变底 + 白色卡片 + 三个琥珀圆点）→ assets/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

TMPDIR_ICON=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ICON"' EXIT

cat > "$TMPDIR_ICON/gen.swift" <<'SWIFT'
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
guard let ctx = NSGraphicsContext.current else { fatalError() }
ctx.imageInterpolation = .high
ctx.shouldAntialias = true

// 圆角方形背景：深蓝紫渐变
let bgPath = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 216, yRadius: 216)
let bg = NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.30, blue: 0.57, alpha: 1),
    NSColor(calibratedRed: 0.33, green: 0.42, blue: 0.73, alpha: 1),
    NSColor(calibratedRed: 0.46, green: 0.56, blue: 0.90, alpha: 1)
])!
bg.draw(in: bgPath, angle: -90)

// 白色圆角卡片
let cardRect = NSRect(x: 280, y: 280, width: 464, height: 464)
let card = NSBezierPath(roundedRect: cardRect, xRadius: 112, yRadius: 112)
NSColor(calibratedRed: 0.97, green: 0.985, blue: 1.0, alpha: 1).setFill()
card.fill()

// 三个琥珀圆点（品字形）：塔顶一 + 底二，象征统一调度应用/服务/命令
let accent = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.32, alpha: 1)
let r: CGFloat = 74
accent.setFill()
NSBezierPath(ovalIn: NSRect(x: 512 - r, y: 588 - r, width: 2*r, height: 2*r)).fill()
NSBezierPath(ovalIn: NSRect(x: 372 - r, y: 420 - r, width: 2*r, height: 2*r)).fill()
NSBezierPath(ovalIn: NSRect(x: 652 - r, y: 420 - r, width: 2*r, height: 2*r)).fill()

img.unlockFocus()
guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError() }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("✅ 图标已生成")
SWIFT

swift "$TMPDIR_ICON/gen.swift" "$TMPDIR_ICON/appicon.png"

mkdir -p assets "$TMPDIR_ICON/AppIcon.iconset"
cp "$TMPDIR_ICON/appicon.png" assets/appicon.png

for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
    set -- $spec
    sips -z "$1" "$1" "$TMPDIR_ICON/appicon.png" --out "$TMPDIR_ICON/AppIcon.iconset/$2" >/dev/null
done

iconutil -c icns "$TMPDIR_ICON/AppIcon.iconset" -o assets/AppIcon.icns
echo "✅ 已生成 assets/AppIcon.icns"
