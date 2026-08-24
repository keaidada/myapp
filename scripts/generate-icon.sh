#!/usr/bin/env bash
# 生成水豚噜噜图标（用 assets/capybara.svg + 淡奶油渐变底）→ assets/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

TMPDIR_ICON=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ICON"' EXIT

# 1) 把 SVG 渲染成 1024 PNG（qlmanage）
qldir="$TMPDIR_ICON/ql"
mkdir -p "$qldir"
qlmanage -t -s 1024 -o "$qldir" "assets/capybara.svg" >/dev/null 2>&1
QLPNG=$(find "$qldir" -name '*.png' | head -1)
if [[ -z "$QLPNG" ]]; then
    echo "❌ SVG 渲染失败"; exit 1
fi

# 2) 组合：淡奶油渐变圆角底 + 深棕水豚线条
python3 - "$QLPNG" "$TMPDIR_ICON/appicon.png" <<'PY'
import sys
from PIL import Image, ImageDraw
import numpy as np
size = 1024
lulu = Image.open(sys.argv[1]).convert('RGBA')
arr = np.array(lulu).astype(int)
dark = (arr[:,:,0]<120) & (arr[:,:,1]<120) & (arr[:,:,2]<120)
rgba = np.array(lulu.convert('RGBA'))
rgba[:,:,3] = np.where(dark, 255, 0)
brown = np.array([76, 50, 34, 255])
for c in range(3):
    rgba[:,:,c] = np.where(dark, brown[c], rgba[:,:,c])
line = Image.fromarray(rgba, 'RGBA')
bg = Image.new('RGBA',(size,size),(0,0,0,0))
dr = ImageDraw.Draw(bg)
top=(255,240,215); bot=(245,215,170)
for y in range(size):
    t=y/size
    dr.line([(0,y),(size,y)], fill=(int(top[0]+(bot[0]-top[0])*t),int(top[1]+(bot[1]-top[1])*t),int(top[2]+(bot[2]-top[2])*t),255))
mask=Image.new('L',(size,size),0); md=ImageDraw.Draw(mask)
md.rounded_rectangle([64,64,size-64,size-64], radius=216, fill=255)
icon=Image.new('RGBA',(size,size),(0,0,0,0))
icon.paste(bg,(0,0),mask)
s = size*0.76/max(line.size)
nw,nh=int(line.size[0]*s), int(line.size[1]*s)
l2 = line.resize((nw,nh), Image.LANCZOS)
ox,oy=(size-nw)//2,(size-nh)//2
icon.paste(l2,(ox,oy),l2)
icon.save(sys.argv[2])
print("✅ 水豚图标已合成")
PY

cp "$TMPDIR_ICON/appicon.png" assets/appicon.png
mkdir -p "$TMPDIR_ICON/AppIcon.iconset"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
    set -- $spec
    sips -z "$1" "$1" "$TMPDIR_ICON/appicon.png" --out "$TMPDIR_ICON/AppIcon.iconset/$2" >/dev/null
done
iconutil -c icns "$TMPDIR_ICON/AppIcon.iconset" -o assets/AppIcon.icns
echo "✅ 已生成 assets/AppIcon.icns"
