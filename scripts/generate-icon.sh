#!/usr/bin/env bash
# 生成可爱的 Capybara 水豚图标 → assets/AppIcon.icns
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

// 奶油色圆角背景
let bg = NSBezierPath(roundedRect: NSRect(x: 30, y: 30, width: 964, height: 964), xRadius: 200, yRadius: 200)
NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.87, alpha: 1).setFill()
bg.fill()

// 底部淡色装饰圆
NSColor(calibratedRed: 0.93, green: 0.85, blue: 0.72, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 120, y: 90, width: 784, height: 200)).fill()

// 居中大 emoji（海狸 = 最接近水豚的棕色圆胖啮齿）
let emoji = "🦫"
let font = NSFont.systemFont(ofSize: 560)
let str = NSAttributedString(string: emoji, attributes: [.font: font])
let strSize = str.size()
str.draw(at: NSPoint(x: (size - strSize.width) / 2, y: (size - strSize.height) / 2 + 40))

// 底部小爱心
let heartFont = NSFont.systemFont(ofSize: 120)
let heart = NSAttributedString(string: "❤️", attributes: [.font: heartFont])
let heartSize = heart.size()
heart.draw(at: NSPoint(x: (size - heartSize.width) / 2, y: 60))

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError() }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("✅ 图标已生成")
SWIFT

swift "$TMPDIR_ICON/gen.swift" "$TMPDIR_ICON/capybara.png"

mkdir -p assets "$TMPDIR_ICON/AppIcon.iconset"
cp "$TMPDIR_ICON/capybara.png" assets/capybara.png

for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
    set -- $spec
    sips -z "$1" "$1" "$TMPDIR_ICON/capybara.png" --out "$TMPDIR_ICON/AppIcon.iconset/$2" >/dev/null
done

iconutil -c icns "$TMPDIR_ICON/AppIcon.iconset" -o assets/AppIcon.icns
echo "✅ 已生成 assets/AppIcon.icns"
