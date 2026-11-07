"""生成 App 图标（1024x1024）。

运行：
    python scripts/make_icon.py
输出：
    Fathom/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

设计：深靛蓝渐变底 + 白色书页 + 琥珀色放大镜，镜片里一个「中」字，
表达「读英文、看中文」。
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

SIZE = 1024
SS = 4                      # 超采样倍数，边缘更干净
W = SIZE * SS

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "Fathom", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")

def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)

# ── 背景：对角渐变 ────────────────────────────────────────────
top = (30, 27, 75)        # #1E1B4B
bottom = (79, 70, 229)    # #4F46E5
bg = Image.new("RGB", (W, W), top)
px = bg.load()
for y in range(W):
    t = y / (W - 1)
    # 略带对角感
    for x in range(0, W, 1):
        tt = min(1.0, (t * 0.82 + (x / (W - 1)) * 0.18))
        px[x, y] = (
            int(top[0] + (bottom[0] - top[0]) * tt),
            int(top[1] + (bottom[1] - top[1]) * tt),
            int(top[2] + (bottom[2] - top[2]) * tt),
        )

# 左上角柔光
glow = Image.new("L", (W, W), 0)
g = ImageDraw.Draw(glow)
g.ellipse((-W * 0.35, -W * 0.45, W * 0.75, W * 0.65), fill=90)
glow = glow.filter(ImageFilter.GaussianBlur(W // 8))
bg.paste(Image.new("RGB", (W, W), (167, 139, 250)), (0, 0), glow)

img = bg.convert("RGBA")

# ── 书页阴影 ─────────────────────────────────────────────────
page_box = (int(W * 0.185), int(W * 0.155), int(W * 0.825), int(W * 0.845))
shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle(
    (page_box[0] + 6 * SS, page_box[1] + 18 * SS, page_box[2] + 6 * SS, page_box[3] + 18 * SS),
    radius=58 * SS, fill=(10, 8, 40, 150),
)
shadow = shadow.filter(ImageFilter.GaussianBlur(24 * SS))
img.alpha_composite(shadow)

d = ImageDraw.Draw(img)

# ── 书页 ─────────────────────────────────────────────────────
d.rounded_rectangle(page_box, radius=58 * SS, fill=(255, 255, 255, 255))

# ── 书页上的文字行 ───────────────────────────────────────────
line_color = (199, 210, 254, 255)     # indigo-200
line_x = int(W * 0.245)
line_w = int(W * 0.42)
line_h = 30 * SS
gap = 58 * SS
line_y = int(W * 0.255)
widths = [1.0, 0.86, 0.94, 0.62]
for i, ratio in enumerate(widths):
    y0 = line_y + i * gap
    d.rounded_rectangle(
        (line_x, y0, line_x + int(line_w * ratio), y0 + line_h),
        radius=line_h // 2, fill=line_color,
    )

# 底部一行短竖线，像被选中的词
sel_y = line_y + 4 * gap + 14 * SS
d.rounded_rectangle(
    (line_x, sel_y, line_x + int(line_w * 0.34), sel_y + line_h),
    radius=line_h // 2, fill=(129, 140, 248, 255),   # indigo-400
)

# ── 放大镜 ───────────────────────────────────────────────────
cx, cy = int(W * 0.665), int(W * 0.665)
r = int(W * 0.145)
ring = 42 * SS
amber = (251, 191, 36, 255)      # amber-400
amber_deep = (245, 158, 11, 255) # amber-500

# 手柄
hx0, hy0 = cx + int(r * 0.72), cy + int(r * 0.72)
hx1, hy1 = cx + int(r * 1.62), cy + int(r * 1.62)
d.line((hx0, hy0, hx1, hy1), fill=amber_deep, width=int(ring * 1.15))
d.ellipse((hx1 - ring // 2, hy1 - ring // 2, hx1 + ring // 2, hy1 + ring // 2), fill=amber_deep)

# 镜片（白色底 + 琥珀色圈）
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 255),
          outline=amber, width=ring)

# 镜片里的「中」
font = None
for path in (r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf"):
    if os.path.exists(path):
        font = ImageFont.truetype(path, int(r * 1.02))
        break

if font is not None:
    text = "中"
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    d.text((cx - tw / 2 - box[0], cy - th / 2 - box[1]), text, font=font, fill=(49, 46, 129, 255))

# ── 输出 ─────────────────────────────────────────────────────
icon = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
icon.save(OUT, "PNG")
print("saved:", OUT, os.path.getsize(OUT), "bytes")
