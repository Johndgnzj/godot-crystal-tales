"""六翼釘頭錘的幾何示意圖產生器（無 AI，純計算）。

規格見同目錄上層 description.md：六片等腰三角形翼片，底邊 = 腰長 × 1.5，底邊垂直焊於柄、尖端朝外。
輸出 geometry_side.png（側視線框）與 geometry_top.png（俯視六芒星），供產圖工具當 image-to-image 參考圖——
純文字描述會被模型誤解成「正對鏡頭的星形」，一定要附這兩張。

    python3 docs/design/武器/錘/ref_src/geometry.py
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

LEG = 1.0
BASE = 1.5 * LEG                                  # 底邊 = 腰長 × 1.5
HEIGHT = math.sqrt(LEG ** 2 - (BASE / 2) ** 2)    # 尖端伸出的長度
SHAFT_R = 0.10

BG = (64, 64, 68)
INK = (24, 24, 26)
PLATE = (226, 232, 240)
GOLD = (214, 172, 74)
WRAP = (168, 205, 219)

W, H = 864, 1152
SCALE = 200
ELEV = math.radians(18)
AZ0 = math.radians(20)


def fin_tris(az0):
    """六片翼片的 3D 頂點：底邊兩端貼柄（上下），尖端朝外。"""
    out = []
    for i in range(6):
        phi = az0 + i * math.pi / 3
        cx, cy = math.cos(phi), math.sin(phi)
        out.append([
            (SHAFT_R * cx, SHAFT_R * cy, BASE / 2),
            (SHAFT_R * cx, SHAFT_R * cy, -BASE / 2),
            ((SHAFT_R + HEIGHT) * cx, (SHAFT_R + HEIGHT) * cy, 0.0),
        ])
    return out


# ---------- 側視線框圖 ----------
cx, cy = W // 2, int(H * 0.30)


def proj(x, y, z):
    sx = cx + x * SCALE
    sy = cy - (z * math.cos(ELEV) - y * math.sin(ELEV)) * SCALE
    return sx, sy


side = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(side)

half = SHAFT_R * SCALE
d.rectangle([cx - half, proj(0, 0, BASE / 2 + 0.25)[1], cx + half,
             proj(0, 0, -BASE / 2 - 2.9)[1]], fill=PLATE, outline=INK, width=4)
d.rectangle([cx - half, proj(0, 0, -BASE / 2 - 1.9)[1], cx + half,
             proj(0, 0, -BASE / 2 - 2.75)[1]], fill=WRAP, outline=INK, width=4)

# 半透明填色，六片的內部邊線才都看得見（實心填色會互相遮蔽成一塊）
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
for tri in fin_tris(AZ0):
    od.polygon([proj(*v) for v in tri], fill=PLATE + (90,))
side = Image.alpha_composite(side.convert("RGBA"), overlay).convert("RGB")

d = ImageDraw.Draw(side)
for tri in fin_tris(AZ0):
    pts = [proj(*v) for v in tri]
    d.line(pts + [pts[0]], fill=INK, width=6, joint="curve")

for z in (BASE / 2, -BASE / 2):
    ry = proj(0, 0, z)[1]
    d.rectangle([cx - half * 2.0, ry - 14, cx + half * 2.0, ry + 14],
                fill=GOLD, outline=INK, width=4)

side.save(os.path.join(OUT, "geometry_side.png"))

# ---------- 俯視圖 ----------
S = 864
top = Image.new("RGB", (S, S), BG)
td = ImageDraw.Draw(top)
tc = S // 2
TS = 300
THICK = 0.035
for i in range(6):
    phi = i * math.pi / 3
    n = (math.cos(phi), math.sin(phi))
    t = (-n[1], n[0])
    quad = [
        (tc + (SHAFT_R * n[0] + THICK * t[0]) * TS, tc + (SHAFT_R * n[1] + THICK * t[1]) * TS),
        (tc + ((SHAFT_R + HEIGHT) * n[0] + THICK * t[0]) * TS,
         tc + ((SHAFT_R + HEIGHT) * n[1] + THICK * t[1]) * TS),
        (tc + ((SHAFT_R + HEIGHT) * n[0] - THICK * t[0]) * TS,
         tc + ((SHAFT_R + HEIGHT) * n[1] - THICK * t[1]) * TS),
        (tc + (SHAFT_R * n[0] - THICK * t[0]) * TS, tc + (SHAFT_R * n[1] - THICK * t[1]) * TS),
    ]
    td.polygon(quad, fill=PLATE, outline=INK)
    td.line(quad + [quad[0]], fill=INK, width=5, joint="curve")

r = SHAFT_R * TS
td.ellipse([tc - r, tc - r, tc + r, tc + r], fill=GOLD, outline=INK, width=5)
top.save(os.path.join(OUT, "geometry_top.png"))

print(f"底邊={BASE:.3f} 腰={LEG:.1f} 三角形高={HEIGHT:.3f}")
print("→ geometry_side.png / geometry_top.png")
