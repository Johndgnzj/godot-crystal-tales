"""從 sample_jess.png 產出兩張部件圖。

- anatomy.png       編號版（照 docs/design/武器/刀 的慣例：圖上只放編號，名稱在 description.md 表格）
- anatomy_labeled.png 中文標註版（工作用；中文標註交給產圖模型會變亂碼，所以自己疊）

    python3 docs/design/武器/錘/ref_src/annotate.py

錨點座標以 sample_jess.png（864×1152）為基準；換圖要一併調整 ANCHORS。
"""
import os
from PIL import Image, ImageDraw, ImageFont

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(DIR, "sample_jess.png")

CJK = "/System/Library/Fonts/Hiragino Sans GB.ttc"
ARIAL = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# 編號: (錨點x, 錨點y, 中文, 英文)  — 對照 description.md 的部件表
# 座標量自 sample_jess.png（864×1184）：上環座 y214-234、下環座 y493-513、頭部最寬 y360 x227-639、
# 護手圓盤 y855-864、握把 y869-1021、柄尾至 y1064。換圖請重量一次。
ANCHORS = {
    1: (315, 325, "翼片 ×6", "flange — 等腰三角形，底邊焊於柄"),
    2: (625, 360, "翼片尖端", "tip — 鈍厚圓角，不開刃"),
    3: (437, 224, "上環座", "collar / socket — 束緊六片翼"),
    4: (437, 503, "下環座", "collar — 與上環座成對夾住翼片"),
    5: (433, 190, "柄軸頂端", "無獨立頂冠（crown）；柄自頭部上端穿出"),
    6: (433, 680, "柄", "shaft / haft — 木芯包鋼，60–80 cm"),
    7: (433, 860, "護手圓盤", "disc guard — 刻意做小，不搶眼"),
    8: (433, 945, "握把", "grip — 淺藍布條纏繞"),
    9: (433, 1045, "柄尾配重", "pommel — 平衡重心"),
}


def load_art(height):
    """回傳縮放後的圖與縮放比；比例由原圖高度動態算出，換圖不會飄。"""
    art = Image.open(SRC).convert("RGB")
    s = height / art.height
    return art.resize((int(art.width * s), height), Image.LANCZOS), s


# ---------------- 編號版 ----------------
W, H = 1400, 1240
BG, INK = (250, 250, 250), (26, 26, 28)
img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
f_num = ImageFont.truetype(ARIAL, 40)

art, S = load_art(1120)
AX, AY = (W - art.width) // 2, 60
img.paste(art, (AX, AY))

# 號碼擺位：左欄 / 右欄 / 頂端
PLACE = {1: (150, 300), 3: (150, 150), 4: (150, 560), 5: (700, 32),
         2: (1250, 340), 6: (1250, 690), 7: (1250, 830), 8: (1250, 950), 9: (1250, 1080)}

for n, (ax, ay, _, _) in ANCHORS.items():
    axp, ayp = AX + ax * S, AY + ay * S
    nx, ny = PLACE[n]
    d.line([nx, ny, axp, ayp], fill=INK, width=4)
    d.ellipse([axp - 7, ayp - 7, axp + 7, ayp + 7], fill=INK)
    d.ellipse([nx - 33, ny - 33, nx + 33, ny + 33], fill=BG)
    t = str(n)
    d.text((nx - d.textlength(t, font=f_num) / 2, ny - 26), t, font=f_num, fill=INK)

img.save(os.path.join(DIR, "anatomy.png"))

# ---------------- 中文標註版 ----------------
W, H = 1900, 1470
BG, FG, DIM, LEAD, ACCENT, EDGE = ((26, 28, 32), (234, 238, 244), (152, 160, 172),
                                   (238, 190, 92), (140, 205, 225), (78, 84, 94))
img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
f_ttl = ImageFont.truetype(CJK, 46)
f_sub = ImageFont.truetype(CJK, 23)
f_lbl = ImageFont.truetype(CJK, 27)
f_en = ImageFont.truetype(CJK, 19)
f_note = ImageFont.truetype(CJK, 21)

art, S = load_art(1000)
AX, AY = 640, 170
img.paste(art, (AX, AY))
d.rectangle([AX - 1, AY - 1, AX + art.width, AY + 1000], outline=EDGE, width=2)

d.text((60, 56), "潔絲的武器　部件說明", font=f_ttl, fill=FG)
d.text((62, 116), "六翼釘頭錘　shestoper (шестопёр「六羽」) / flanged mace　—　實物為 12 世紀"
                  "起源於基輔羅斯的 pernach 系武器", font=f_sub, fill=ACCENT)

L_EDGE, R_EDGE = 600, 1450
LY = {5: 250, 3: 348, 1: 452, 4: 600, 2: 470, 6: 745, 7: 880, 8: 990, 9: 1090}
LEFT = {1, 3, 4, 5}

for n, (ax, ay, zh, en) in ANCHORS.items():
    axp, ayp = AX + ax * S, AY + ay * S
    ly = LY[n]
    if n in LEFT:
        d.line([(L_EDGE + 16, ly + 16), (axp, ayp)], fill=LEAD, width=2)
        d.text((L_EDGE - d.textlength(zh, font=f_lbl), ly - 10), zh, font=f_lbl, fill=FG)
        d.text((L_EDGE - d.textlength(en, font=f_en), ly + 26), en, font=f_en, fill=DIM)
    else:
        d.line([(R_EDGE - 16, ly + 16), (axp, ayp)], fill=LEAD, width=2)
        d.text((R_EDGE, ly - 10), zh, font=f_lbl, fill=FG)
        d.text((R_EDGE, ly + 26), en, font=f_en, fill=DIM)
    d.ellipse([axp - 6, ayp - 6, axp + 6, ayp + 6], fill=LEAD)

IS = 280
ins = Image.open(os.path.join(DIR, "geometry_top.png")).convert("RGB").resize((IS, IS), Image.LANCZOS)
IX, IY = 90, 780
img.paste(ins, (IX, IY))
d.rectangle([IX - 1, IY - 1, IX + IS, IY + IS], outline=EDGE, width=2)
d.text((IX, IY - 62), "俯視：六翼配置", font=f_lbl, fill=FG)
d.text((IX, IY - 28), "每隔 60°；底邊貼柄、尖端朝外", font=f_en, fill=DIM)

NX, NY = 90, 1245
d.line([NX, NY - 30, W - 90, NY - 30], fill=EDGE, width=2)
for i, (k, v) in enumerate([
    ("翼片幾何", "等腰三角形；底邊 = 腰長 × 1.5（底邊最長），底邊垂直焊於柄"),
    ("翼片數", "6（實物常見 4–12 片，六與八最普遍）"),
    ("材質配色", "翼片與柄銀白鋼；握把淺藍布條；上下環座與柄尾金色"),
    ("設計目的", "翼片集中衝擊力、可打穿板甲——鈍器但致命"),
    ("持法", "單手；全長 60–80 cm（約身高 40%），不是及身高的長柄"),
]):
    y = NY + i * 38
    d.text((NX, y), k, font=f_note, fill=ACCENT)
    d.text((NX + 140, y), v, font=f_note, fill=DIM)

img.save(os.path.join(DIR, "anatomy_labeled.png"))
print("→ anatomy.png / anatomy_labeled.png")
