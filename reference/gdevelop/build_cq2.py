#!/usr/bin/env python3
"""水晶戰記 v2「芳蕾鎮篇」：Title/Town/Forest/Mine/Cave/Battle 六場景，
   序章+第一章劇情、屬性/等級/加點戰鬥系統。讀 CONTENT.json。"""
import json, os, uuid, random, math
from PIL import Image, ImageDraw

_HERE = os.path.dirname(os.path.abspath(__file__))
PROJ  = os.path.dirname(_HERE)                    # projects/crystal-quest（由腳本位置推導、可攜）
GDROOT = os.path.dirname(os.path.dirname(PROJ))   # GDevelop 工作區根（含 tools/）
A = f"{PROJ}/assets"
SCRATCH = "/private/tmp/claude-501/-Users-john-Projects-60-soho-30-Personal-GameCreator-GDevelop/038d8d3e-e22f-48f1-b3aa-164f0cb4c09d/scratchpad"
CONTENT = json.load(open(f"{PROJ}/CONTENT.json"))
PICKED = json.load(open(f"{SCRATCH}/rpg_picked.json"))
HERO_DIMS = json.load(open(f"{PROJ}/assets/battle/hero_dims.json"))
NATIVE = {"goblin":[16,16],"maskedorc":[16,20],"bear":[63,66],"bird":[16,16],"gslime":[16,16],
          "worm":[32,32],"wogol":[16,20],"ogre":[32,32],"necro":[16,20],"chort":[16,24],
          "orc":[16,20],"skeleton":[16,16],"demon":[32,36]}
NATIVE.update(HERO_DIMS)
random.seed(51)
TS = 32

# ================= 1. Atlas（LPC terrain 整合版）=================
LPCT = Image.open(f"{GDROOT}/tools/lpc-terrain/terrain_atlas.png").convert("RGBA")
def lpc(c,r): return LPCT.crop((c*32,r*32,c*32+32,r*32+32))

tiles = ["grass","grassf","path","dirt","tgrass","water","sand","bridge",
         "rockfloor","gravel","cavefloor","cavedark","rail","farm",
         "grass2","grass3","plaza",
         "pn","ps","pw","pe","pnw","pne","psw","pse","pc",
         "pinw","pine","pisw","pise",
         "cwall","cwtop","fwall","ctop"]
COLS = 6
rows_n = (len(tiles)+COLS-1)//COLS
atlas = Image.new("RGBA",(COLS*TS,rows_n*TS),(0,0,0,0))
d = ImageDraw.Draw(atlas)
G = {n:i+1 for i,n in enumerate(tiles)}
def cell(i): return ((i%COLS)*TS,(i//COLS)*TS)
def put(name, tile_img):
    x,y = cell(G[name]-1); atlas.paste(tile_img,(x,y))
def put_lpc(name,c,r): put(name, lpc(c,r))
# 草地三變體
put_lpc("grass",22,5); put_lpc("grass2",21,5); put_lpc("grass3",23,5)
# 花草地 = 草 + 小花
gf = lpc(22,5).copy(); dgf = ImageDraw.Draw(gf)
for fx,fy,c1 in [(7,8,(250,230,110)),(21,13,(240,140,160)),(13,23,(185,155,245))]:
    dgf.ellipse([fx-2,fy-2,fx+2,fy+2],fill=c1); dgf.point((fx,fy),fill=(120,90,40))
put("grassf",gf)
# 土路系（過渡塊 (5,17)-(7,19)、內角 (6,15)-(7,16)、素土填充）
put_lpc("pc",6,18); put_lpc("pn",6,17); put_lpc("ps",6,19); put_lpc("pw",5,18); put_lpc("pe",7,18)
put_lpc("pnw",5,17); put_lpc("pne",7,17); put_lpc("psw",5,19); put_lpc("pse",7,19)
put_lpc("pinw",7,16); put_lpc("pine",6,16); put_lpc("pisw",7,15); put_lpc("pise",6,15)
put_lpc("path",9,21)          # 礦山道路用素土
put_lpc("dirt",8,20)
put_lpc("plaza",11,22)        # 城鎮中心廣場：改用自然淡色夯土（原石板磚 (3,16) John 覺得太「磚」）
# 長草 = 草底 + 蘆葦層
tg = lpc(22,5).copy(); reed = lpc(8,17)
tg.alpha_composite(reed); put("tgrass",tg)
# 洞窟專用磚（LPC base_out：岩壁面 / 沙岩頂）
BASEO = Image.open(f"{GDROOT}/tools/lpc-atlas1/base_out_atlas.png").convert("RGBA")
def baseo(c,r): return BASEO.crop((c*32,r*32,c*32+32,r*32+32))
put("cwall", baseo(1,3)); put("cwtop", baseo(5,1)); put("ctop", baseo(18,8))
# 森林迷宮牆＝大樹樹冠內部的密葉紋理（加深色調讓通道更好讀）
fw = LPCT.crop((960,936,992,968)).convert("RGB")
fw = Image.eval(fw, lambda v: int(v*0.72)).convert("RGBA")
put("fwall", fw)
# 其餘（水/沙/橋/礦區/洞穴/軌道/農田）由 art_v2.py 補繪
atlas.save(f"{A}/map/atlas.png")

# LPC 大樹與松樹——像素連通掃描的完整邊界（舊裁切少了樹冠頂/樹根 → 破圖只剩下半部）
oak = LPCT.crop((928,900,1024,1020)); oak.save(f"{A}/props/tree.png")     # 96x120
pine = LPCT.crop((960,0,1024,152)); pine.save(f"{A}/props/pine.png")      # 64x152
TREE_W,TREE_H = oak.size
TPX,TPY = -(TREE_W-32)//2, 32-TREE_H   # 樹底對齊所在格底邊、水平置中
# anokolisa 多樹種（art_v14 產 fst_tree_1..6，統一 96x120 沿用 TPX/TPY）。各用獨立 RNG→不動全域流、彼此不互擾。
FTREES = [f"FTree{_i}" for _i in range(1,7)]
_FRNG = random.Random(1414)            # 森林樹種/裝飾
_TRNG = random.Random(2025)            # 城鎮樹種
def _town_tree(): return _TRNG.choice(FTREES)

# ================= 2. 新道具圖 =================
P = f"{A}/props"
def make_house(wall,roof,banner=None,W=160,H=140):
    img=Image.new("RGBA",(W,H),(0,0,0,0)); dd=ImageDraw.Draw(img)
    dd.rectangle([10,50,W-10,H-4],fill=wall,outline=(70,50,35),width=2)
    for py in range(62,H-4,12): dd.line([(12,py),(W-12,py)],fill=tuple(max(0,v-18) for v in wall))
    dd.polygon([(0,52),(W//2,4),(W,52)],fill=roof,outline=(60,35,25))
    dd.rectangle([W//2-13,H-48,W//2+13,H-4],fill=(110,76,46),outline=(60,40,25),width=2)
    dd.ellipse([W//2+6,H-26,W//2+10,H-22],fill=(230,200,90))
    for wx in (24,W-52):
        dd.rectangle([wx,68,wx+28,92],fill=(165,210,235),outline=(70,50,35),width=2)
        dd.line([(wx+14,68),(wx+14,92)],fill=(70,50,35)); dd.line([(wx,80),(wx+28,80)],fill=(70,50,35))
    if banner:
        dd.rectangle([W//2-10,16,W//2+10,46],fill=banner,outline=(50,40,30),width=2)
        dd.polygon([(W//2-10,46),(W//2,38),(W//2+10,46)],fill=roof)
    return img
make_house((222,198,158),(92,110,152),banner=(60,110,200)).save(f"{P}/b_guild.png")   # 公會(藍旗)
make_house((228,204,164),(178,86,64)).save(f"{P}/b_inn.png")                          # 旅店
make_house((205,205,210),(120,88,66)).save(f"{P}/b_mayor.png")                        # 鎮長宅
make_house((214,196,170),(96,140,90)).save(f"{P}/b_shop.png")                         # 道具店
make_house((190,180,175),(80,78,86)).save(f"{P}/b_smith.png")                         # 鐵匠鋪
img=Image.new("RGBA",(120,130),(0,0,0,0)); dd=ImageDraw.Draw(img)                     # 小神殿
dd.rectangle([12,52,108,126],fill=(238,234,226),outline=(120,110,100),width=2)
dd.polygon([(2,54),(60,8),(118,54)],fill=(200,190,175),outline=(110,100,90))
dd.rectangle([52,20,68,36],fill=(240,220,140),outline=(140,120,70))                   # 女神徽記
dd.ellipse([55,23,65,33],fill=(150,190,120))
dd.rectangle([48,86,72,126],fill=(150,120,90),outline=(90,70,50),width=2)
img.save(f"{P}/b_shrine.png")
# 礦坑口：寬 160=5 格（放 tile19 → 洞口正對 tile21-22 的 2 格通道，局部 x64..128）
img=Image.new("RGBA",(160,112),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.polygon([(0,112),(10,44),(44,10),(116,10),(150,44),(160,112)],fill=(120,112,104),outline=(70,64,58))
for rx,ry,rr in [(24,60,10),(134,54,12),(76,20,9),(112,26,7)]:
    dd.ellipse([rx-rr,ry-rr//1.4,rx+rr,ry+rr//1.4],outline=(96,90,84),width=2)      # 岩塊紋理
dd.ellipse([58,34,134,140],fill=(25,22,28))                                          # 洞口(68 寬，蓋過通道)
dd.rectangle([64,60,128,112],fill=(25,22,28))
dd.rectangle([52,32,60,112],fill=(110,84,54)); dd.rectangle([132,32,140,112],fill=(110,84,54))
dd.rectangle([48,24,144,36],fill=(126,98,62),outline=(80,60,40))                     # 門楣
img.save(f"{P}/cavemouth.png")
img=Image.new("RGBA",(64,80),(0,0,0,0)); dd=ImageDraw.Draw(img)                       # 坑道木架
dd.rectangle([4,8,12,78],fill=(116,88,56),outline=(78,58,36))
dd.rectangle([52,8,60,78],fill=(116,88,56),outline=(78,58,36))
dd.rectangle([0,0,64,12],fill=(130,100,64),outline=(80,60,40))
img.save(f"{P}/support.png")
img=Image.new("RGBA",(120,70),(0,0,0,0)); dd=ImageDraw.Draw(img)                      # 落石堆
for cx,cy,r in [(28,44,24),(66,38,28),(98,48,20),(46,56,18),(84,58,16)]:
    dd.ellipse([cx-r,cy-r//1.3,cx+r,cy+r//1.3],fill=(120,112,104),outline=(74,68,62),width=2)
img.save(f"{P}/rubble.png")
img=Image.new("RGBA",(40,52),(0,0,0,0)); dd=ImageDraw.Draw(img)                       # 告示板
dd.rectangle([17,26,23,50],fill=(110,84,54))
dd.rectangle([2,2,38,28],fill=(160,124,80),outline=(90,66,40),width=2)
dd.line([(6,10),(34,10)],fill=(235,225,200),width=2); dd.line([(6,17),(28,17)],fill=(235,225,200),width=2)
img.save(f"{P}/board.png")

# ---- 地圖寶箱 Chest：程序繪像素寶箱（closed 棕木箱＋金邊＋鎖扣／opened 掀蓋露出微光）----
# 32x32 貼滿一格、底部對齊格底；放置時 py=0。與 rock 同為程序繪 prop。
_CW_,_CWD_,_CWL_=(150,104,58),(104,70,38),(182,134,80)     # 木色 / 暗 / 亮
_CG_,_CGD_,_CGL_=(232,192,84),(168,126,42),(255,232,150)   # 金 / 暗 / 亮
_COL_=(60,40,24)
def _chest_closed():
    img=Image.new("RGBA",(32,32),(0,0,0,0)); dd=ImageDraw.Draw(img)
    dd.ellipse([4,28,27,31],fill=(0,0,0,70))                  # 地面陰影
    dd.rectangle([4,17,27,29],fill=_CW_,outline=_COL_,width=1)  # 箱身
    for x in (12,20): dd.line([(x,18),(x,28)],fill=_CWD_)       # 木板接縫
    dd.line([(5,18),(26,18)],fill=_CWL_)                        # 上緣高光
    dd.pieslice([4,8,27,24],180,360,fill=_CW_,outline=_COL_)    # 拱形箱蓋
    dd.rectangle([4,16,27,17],fill=_CWD_)                       # 蓋底陰影
    dd.arc([6,10,25,22],185,355,fill=_CWL_)                     # 拱蓋反光
    dd.rectangle([4,16,27,18],fill=_CG_,outline=_CGD_)          # 金色接縫帶
    for x in (8,23): dd.rectangle([x,10,x+2,28],fill=_CG_,outline=_CGD_)  # 金色束帶
    dd.line([(9,11),(9,27)],fill=_CGL_); dd.line([(24,11),(24,27)],fill=_CGL_)
    dd.rectangle([14,15,18,23],fill=_CG_,outline=_CGD_)         # 鎖扣
    dd.rectangle([15,13,17,16],fill=_CGD_)                      # 鎖鼻
    dd.point((16,19),fill=(50,34,18)); dd.line([(16,19),(16,21)],fill=(50,34,18))  # 鎖孔
    return img
def _chest_opened():
    img=Image.new("RGBA",(32,32),(0,0,0,0)); dd=ImageDraw.Draw(img)
    dd.ellipse([4,28,27,31],fill=(0,0,0,70))
    dd.polygon([(6,13),(25,13),(24,4),(7,4)],fill=_CWD_,outline=_COL_)  # 掀開的蓋（背光面）
    dd.arc([7,2,24,10],180,360,fill=_CW_)                              # 蓋頂拱
    dd.line([(7,4),(24,4)],fill=_CWL_)
    dd.line([(6,13),(25,13)],fill=_CG_,width=1)                        # 蓋緣金邊
    dd.rectangle([4,16,27,29],fill=_CW_,outline=_COL_,width=1)         # 箱身
    for x in (12,20): dd.line([(x,20),(x,28)],fill=_CWD_)
    dd.line([(5,17),(26,17)],fill=_CWL_)
    dd.rectangle([6,13,25,18],fill=(44,30,18),outline=_COL_)           # 內部暗腔
    for r,al in [(11,55),(8,105),(5,170),(2,235)]:                     # 溢出的金光
        dd.ellipse([16-r,15-r//2,16+r,15+r//2],fill=(255,226,124,al))
    dd.line([(16,15),(16,8)],fill=(255,242,175,150))                   # 光束
    dd.line([(12,15),(10,9)],fill=(255,242,175,90)); dd.line([(20,15),(22,9)],fill=(255,242,175,90))
    dd.rectangle([4,16,27,18],fill=_CG_,outline=_CGD_)                 # 前緣金帶
    for x in (8,23): dd.rectangle([x,18,x+2,28],fill=_CG_,outline=_CGD_)
    dd.line([(9,19),(9,27)],fill=_CGL_); dd.line([(24,19),(24,27)],fill=_CGL_)
    return img
_chest_closed().save(f"{P}/chest_closed.png")
_chest_opened().save(f"{P}/chest_opened.png")

# ---- 支線 pickup 素材：鏡草(herb，發光青草)／阿吉的礦工頭盔(helmet，斑駁鏽色) ----
img=Image.new("RGBA",(32,32),(0,0,0,0)); dd=ImageDraw.Draw(img)
for r,al in [(13,40),(9,60),(5,95)]:                                      # 柔光暈
    dd.ellipse([16-r,20-r,16+r,20+r],fill=(150,230,235,al))
dd.ellipse([9,27,23,31],fill=(0,0,0,60))                                  # 地面陰影
for bx,by,tx,ty,w in [(16,29,16,10,3),(16,29,10,15,2),(16,29,23,14,2),(16,29,13,20,2),(16,29,20,19,2)]:
    dd.line([(bx,by),(tx,ty)],fill=(70,150,140),width=w)                  # 葉莖
    dd.line([(bx,by),(tx,ty)],fill=(175,240,225),width=1)                 # 葉脈高光
for sx,sy in [(16,9),(11,14),(22,13)]:
    dd.ellipse([sx-2,sy-2,sx+2,sy+2],fill=(220,255,250,230)); dd.point((sx,sy),fill=(255,255,255,255))
img.save(f"{P}/herb.png")

img=Image.new("RGBA",(32,32),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.ellipse([5,26,27,31],fill=(0,0,0,70))                                  # 地面陰影
dd.pieslice([5,8,27,28],180,360,fill=(120,86,52),outline=(70,48,28))      # 圓頂
dd.chord([5,20,27,28],0,180,fill=(96,68,40),outline=(70,48,28))           # 帽簷
dd.arc([8,11,24,26],185,355,fill=(168,126,80))                            # 頂部反光
dd.line([(6,22),(26,22)],fill=(150,110,66))                              # 簷上緣高光
dd.ellipse([13,13,19,19],fill=(240,206,110),outline=(150,110,40))         # 頭燈
dd.ellipse([14,14,17,17],fill=(255,242,180))                             # 頭燈反光
for _rx,_ry in [(10,18),(22,17)]: dd.point((_rx,_ry),fill=(60,42,24))     # 鏽斑
img.save(f"{P}/helmet.png")

# ================= Track B：觸控按鈕素材（半透明圓底＋符號；程序繪，存 ui/ 平滑載入）=================
from PIL import ImageFont as _IF
def _cjkfont(px):
    for _fp in ["/System/Library/Fonts/STHeiti Medium.ttc","/System/Library/Fonts/PingFang.ttc",
                "/System/Library/Fonts/Hiragino Sans GB.ttc","/Library/Fonts/Arial Unicode.ttf"]:
        try: return _IF.truetype(_fp,px)
        except Exception: pass
    return None
_U=f"{A}/ui"
def _bbg(sz,fill=(18,24,38,150),edge=(200,220,245,220),ew=3):
    im=Image.new("RGBA",(sz,sz),(0,0,0,0)); dr=ImageDraw.Draw(im)
    dr.ellipse([ew//2,ew//2,sz-1-ew//2,sz-1-ew//2],fill=fill,outline=edge,width=ew)
    return im,dr
im,dr=_bbg(140,fill=(20,28,46,70),edge=(200,220,245,120),ew=4); dr.ellipse([36,36,104,104],outline=(200,220,245,70),width=2); im.save(f"{_U}/joybase.png")
im,dr=_bbg(70,fill=(150,200,235,175),edge=(240,248,255,225),ew=3); im.save(f"{_U}/joyknob.png")
im,dr=_bbg(100,fill=(38,66,56,150),edge=(170,235,190,230),ew=4); dr.ellipse([31,31,68,68],outline=(210,255,220,210),width=3); im.save(f"{_U}/btn_a.png")
im,dr=_bbg(76); [dr.line([(24,_y),(52,_y)],fill=(220,232,250,235),width=4) for _y in (28,38,48)]; im.save(f"{_U}/btn_menu.png")
im,dr=_bbg(76,fill=(48,26,30,155),edge=(240,180,180,220)); dr.line([(26,26),(50,50)],fill=(245,200,200,235),width=5); dr.line([(50,26),(26,50)],fill=(245,200,200,235),width=5); im.save(f"{_U}/btn_back.png")
def _pad(nm,tri):
    im,dr=_bbg(80); dr.polygon(tri,fill=(225,235,252,235)); im.save(f"{_U}/pad_{nm}.png")
_pad("u",[(40,22),(55,47),(25,47)]); _pad("d",[(40,58),(25,33),(55,33)])
_pad("l",[(22,40),(47,25),(47,55)]); _pad("r",[(58,40),(33,25),(33,55)])
_afont=_cjkfont(32)
for _sid,_ch,_col in [("s1","力",(232,120,110)),("s2","敏",(120,210,150)),("s3","智",(130,175,238))]:
    im,dr=_bbg(66,fill=(_col[0]//3,_col[1]//3,_col[2]//3,175),edge=_col+(235,))
    if _afont:
        _bb=dr.textbbox((0,0),_ch,font=_afont); _w=_bb[2]-_bb[0]; _h=_bb[3]-_bb[1]
        dr.text(((66-_w)/2-_bb[0],(66-_h)/2-_bb[1]-1),_ch,font=_afont,fill=(248,250,255,255))
    else:
        dr.line([(24,33),(42,33)],fill=(248,250,255,255),width=4); dr.line([(33,24),(33,42)],fill=(248,250,255,255),width=4)
    im.save(f"{_U}/btn_{_sid}.png")

# ---- 小鎮裝飾道具（河濱／廣場／街道；皆為純裝飾，place 時「不給 foot」以免擋動線）----
_rr = random.Random(1234)   # 區域性 RNG：不污染全域序列（維持迷宮/隨機物生成不變）
# 酒桶 barrel 28x34
img=Image.new("RGBA",(28,34),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.ellipse([3,28,25,33],fill=(30,30,30,80))
dd.polygon([(4,6),(24,6),(26,17),(24,30),(4,30),(2,17)],fill=(150,104,58),outline=(92,62,34))
for wy in (9,16,25): dd.line([(3,wy),(25,wy)],fill=(70,50,30),width=2)
for sx in (9,14,19): dd.line([(sx,7),(sx,29)],fill=(120,82,46))
dd.line([(13,7),(13,29)],fill=(168,124,74))
img.save(f"{P}/barrel.png")
# 木箱 crate 30x28
img=Image.new("RGBA",(30,28),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.ellipse([3,23,27,27],fill=(30,30,30,80))
dd.rectangle([3,4,26,25],fill=(158,116,66),outline=(90,60,32),width=2)
dd.line([(3,4),(26,25)],fill=(112,78,44),width=2); dd.line([(26,4),(3,25)],fill=(112,78,44),width=2)
dd.rectangle([3,4,26,9],fill=(172,128,74),outline=(112,78,44))
img.save(f"{P}/crate.png")
# 路燈 lamp 18x60（底對齊格底：place py=32-60=-28）
img=Image.new("RGBA",(18,60),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.ellipse([4,55,14,59],fill=(30,30,30,80))
dd.rectangle([7,14,10,57],fill=(72,68,78),outline=(44,40,48))
dd.rectangle([5,12,12,16],fill=(88,84,92))
dd.polygon([(3,4),(15,4),(13,13),(5,13)],fill=(60,54,64),outline=(38,34,42))
dd.rectangle([5,5,12,12],fill=(255,224,150),outline=(150,120,60))
dd.polygon([(6,1),(12,1),(9,4)],fill=(70,64,74))
img.save(f"{P}/lamp.png")
# 花圃 flowerbed 44x26
img=Image.new("RGBA",(44,26),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.rectangle([2,12,42,24],fill=(120,84,50),outline=(80,54,30),width=2)
dd.rectangle([4,14,40,22],fill=(78,54,34))
for fx in range(6,40,5):
    fh=_rr.randint(3,7); dd.line([(fx,15),(fx,15-fh)],fill=(70,130,60))
    c=_rr.choice([(240,110,140),(250,220,110),(180,150,240),(240,150,90),(230,90,110)])
    dd.ellipse([fx-3,15-fh-3,fx+3,15-fh+3],fill=c); dd.point((fx,15-fh),fill=(250,250,220))
img.save(f"{P}/flowerbed.png")
# 攤位 stall 100x84（條紋布篷＋木架＋貨物；place py=32-84=-52）
img=Image.new("RGBA",(100,84),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.ellipse([6,78,94,83],fill=(30,50,30,70))
for pxp in (10,86): dd.rectangle([pxp,26,pxp+4,80],fill=(120,84,50),outline=(82,56,32))
dd.rectangle([8,58,92,70],fill=(150,110,64),outline=(92,62,34),width=2)
dd.line([(8,64),(92,64)],fill=(120,84,48))
for gx,gc in [(22,(220,90,80)),(38,(240,180,70)),(54,(120,180,90)),(70,(230,120,150)),(84,(200,150,220))]:
    dd.ellipse([gx-5,50,gx+5,60],fill=gc,outline=tuple(max(0,v-40) for v in gc))
dd.polygon([(4,26),(96,26),(90,41),(10,41)],fill=(206,80,72),outline=(150,50,44))
for sx in range(10,90,12): dd.rectangle([sx,26,sx+5,41],fill=(238,228,214))
dd.polygon([(4,26),(96,26),(50,13)],fill=(226,72,64),outline=(150,50,44))
for wx in range(10,90,11): dd.pieslice([wx,37,wx+11,48],0,180,fill=(190,70,64))
img.save(f"{P}/stall.png")
# 曬衣繩 laundry 104x44（兩柱＋繩＋衣物；place py=32-44=-12）
img=Image.new("RGBA",(104,44),(0,0,0,0)); dd=ImageDraw.Draw(img)
for pxp in (6,95): dd.rectangle([pxp,6,pxp+3,42],fill=(120,84,50),outline=(82,56,32))
dd.line([(8,10),(97,13)],fill=(70,58,46))
for cx,cc in [(20,(220,90,90)),(38,(240,220,110)),(56,(110,160,220)),(74,(230,150,200)),(88,(150,210,150))]:
    dd.line([(cx,11),(cx,14)],fill=(80,70,60))
    dd.polygon([(cx-8,15),(cx-8,30),(cx+8,30),(cx+8,15),(cx+5,15),(cx+3,18),(cx-3,18),(cx-5,15)],
               fill=cc,outline=tuple(max(0,v-40) for v in cc))
img.save(f"{P}/laundry.png")
# 小母雞 hen 18x16（兩幀：站立／啄食，供鎮上小動物巡走）
def _hen(peck):
    im=Image.new("RGBA",(18,16),(0,0,0,0)); d2=ImageDraw.Draw(im)
    d2.ellipse([2,14,15,16],fill=(30,30,30,70))
    d2.ellipse([3,6,15,14],fill=(242,242,236),outline=(198,198,192))
    d2.polygon([(13,7),(17,9),(13,11)],fill=(236,236,230),outline=(198,198,192))
    hy=9 if peck else 4
    d2.ellipse([2,hy,8,hy+6],fill=(246,246,240),outline=(200,200,194))
    d2.polygon([(3,hy-2),(6,hy-1),(5,hy+1)],fill=(220,60,50))
    d2.polygon(([(2,hy+4),(0,hy+6),(3,hy+5)] if peck else [(1,hy+2),(3,hy+3),(2,hy+1)]),fill=(240,150,40))
    d2.point((5,hy+2),fill=(24,20,20))
    d2.line([(6,14),(6,16)],fill=(228,148,40)); d2.line([(10,14),(10,16)],fill=(228,148,40))
    return im
_hen(False).save(f"{P}/hen_0.png"); _hen(True).save(f"{P}/hen_1.png")

# ================= 2b. 選單 UI 元件（依 Claude Design 原型：accent #AADCEB、HP/MP 血條、選取列高亮）=================
UIACC=(170,220,235)
img=Image.new("RGBA",(152,14),(16,20,32,235)); dd=ImageDraw.Draw(img)
dd.rectangle([0,0,151,13],outline=(76,90,120),width=1)
img.save(f"{A}/ui/bar_bg.png")
# 戰鬥下方面板：半透明底
img=Image.new("RGBA",(96,96),(0,0,0,0)); dd=ImageDraw.Draw(img)
dd.rounded_rectangle([0,0,95,95],radius=10,fill=(34,44,66,140),outline=(150,175,215,245),width=2)
dd.rounded_rectangle([3,3,92,92],radius=8,outline=(64,80,112,200),width=1)
img.save(f"{A}/ui/panel_tr.png")
def bar_fill(c1,c2,name):
    img=Image.new("RGBA",(148,10),(0,0,0,0))
    for x in range(148):
        t=x/147
        col=tuple(round(c1[i]+(c2[i]-c1[i])*t) for i in range(3))+(255,)
        for y in range(10): img.putpixel((x,y),col)
    img.save(f"{A}/ui/{name}")
bar_fill((44,196,84),(150,246,168),"bar_hp.png")       # HP（鮮綠）
bar_fill((42,132,255),(150,206,255),"bar_mp.png")      # MP（亮藍）
bar_fill((146,92,235),(206,170,255),"bar_atb.png")     # ATB 蓄力（紫，與 MP 藍區隔）
bar_fill((255,204,52),(255,240,170),"bar_atbf.png")    # ATB 滿格（金）
bar_fill((240,70,70),(255,160,150),"bar_ehp.png")      # 敵人血條（紅）
# 選取列高亮：左 4px accent 直條 + 向右淡出漸層（原型 .row.on 樣式；選單青色/戰鬥金色兩版）
def make_rowhi(col,name):
    img=Image.new("RGBA",(640,28),(0,0,0,0)); dd=ImageDraw.Draw(img)
    dd.rectangle([0,0,3,27],fill=col+(255,))
    for x in range(4,640):
        a=int(42*(1-(x-4)/600))
        if a<=0: break
        dd.line([(x,0),(x,27)],fill=col+(a,))
    img.save(f"{A}/ui/{name}")
make_rowhi(UIACC,"rowhi.png")
make_rowhi((255,225,120),"rowhi_g.png")

# ================= 2c. 戰鬥特效幀圖 =================
FXD=f"{A}/battle"
img=Image.new("RGBA",(4,4),(0,0,0,0)); img.save(f"{FXD}/fx_idle.png")
for i in range(3):                                    # 斬擊：白刃光弧掃過
    img=Image.new("RGBA",(64,64),(0,0,0,0)); dd=ImageDraw.Draw(img)
    a0=-100+i*55
    for w,col in [(11,(200,225,255,80)),(7,(235,245,255,170)),(3,(255,255,255,255))]:
        dd.arc([6,6,58,58],a0,a0+85,fill=col,width=w)
    dd.line([(14,50-i*8),(50,14-i*4)],fill=(255,255,255,120),width=2)
    img.save(f"{FXD}/fx_slash_{i}.png")
for i in range(4):                                    # 爆裂：暖色物理技能
    img=Image.new("RGBA",(64,64),(0,0,0,0)); dd=ImageDraw.Draw(img)
    r=7+i*8; alpha=max(60,255-i*55)
    for k in range(10):
        ang=math.radians(k*36+i*11)
        x,y=32+r*math.cos(ang),32+r*math.sin(ang)
        rr=max(2,6-i)
        dd.ellipse([x-rr,y-rr,x+rr,y+rr],fill=(255,190+(k%2)*45,80,alpha))
    cr=max(3,11-i*3)
    dd.ellipse([32-cr,32-cr,32+cr,32+cr],fill=(255,244,205,alpha))
    img.save(f"{FXD}/fx_burst_{i}.png")
for i in range(4):                                    # 魔光：青紫智力技能
    img=Image.new("RGBA",(64,64),(0,0,0,0)); dd=ImageDraw.Draw(img)
    r=6+i*8; alpha=max(60,255-i*55)
    dd.ellipse([32-r,32-r,32+r,32+r],outline=(150,210,255,alpha),width=3)
    for k in range(6):
        ang=math.radians(k*60+i*22)
        x,y=32+r*math.cos(ang),32+r*math.sin(ang)
        dd.ellipse([x-3,y-3,x+3,y+3],fill=(190,160,255,alpha))
    dd.ellipse([28,28,36,36],fill=(220,240,255,alpha))
    img.save(f"{FXD}/fx_spark_{i}.png")
for i in range(4):                                    # 治癒：上升綠光十字
    img=Image.new("RGBA",(64,64),(0,0,0,0)); dd=ImageDraw.Draw(img)
    alpha=max(60,230-i*40)
    for k,(bx,by) in enumerate([(18,44),(34,50),(46,40),(26,34),(40,28)]):
        y=by-i*7-(k%2)*3
        if y<6: continue
        dd.line([(bx-4,y),(bx+4,y)],fill=(140,240,160,alpha),width=3)
        dd.line([(bx,y-4),(bx,y+4)],fill=(140,240,160,alpha),width=3)
    dd.ellipse([24,36-i*5,40,52-i*5],outline=(170,255,190,max(30,alpha-60)),width=2)
    img.save(f"{FXD}/fx_heal_{i}.png")

# ================= 2c2. 戰鬥背景（依地圖三款，640x360 拉伸） =================
def bbg_base(sky1,sky2,ground1,ground2,horizon=225):
    img=Image.new("RGBA",(640,360),(0,0,0,255)); dd=ImageDraw.Draw(img)
    for y in range(horizon):
        t=y/horizon
        dd.line([(0,y),(640,y)],fill=tuple(round(sky1[i]+(sky2[i]-sky1[i])*t) for i in range(3)))
    for y in range(horizon,360):
        t=(y-horizon)/(360-horizon)
        dd.line([(0,y),(640,y)],fill=tuple(round(ground1[i]+(ground2[i]-ground1[i])*t) for i in range(3)))
    for _ in range(260):                                   # 地面雜點
        x,y=random.randrange(0,640),random.randrange(horizon+6,360)
        c=random.randint(-14,14)
        base=ground1 if y<(horizon+360)/2 else ground2
        dd.point((x,y),fill=tuple(max(0,min(255,base[i]+c)) for i in range(3)))
    return img,dd
# 三張戰鬥背景改用 gen-art 明亮版（design/battlebg/，取代舊程序化暗圖；bbg_base 保留但不再使用）
for _bn in ["forest","mine","cave"]:
    _src=f"{PROJ}/design/battlebg/{_bn}.png"
    if os.path.exists(_src):
        Image.open(_src).convert("RGB").resize((1280,720),Image.LANCZOS).save(f"{A}/ui/battlebg_{_bn}.png")

# ================= 2d. 敵人精緻化：商店多幀 idle + 深色描邊 + 陰影 =================
SRCF=f"{A}/battle/src_foes"
fman=json.load(open(f"{SRCF}/manifest.json")) if os.path.exists(f"{SRCF}/manifest.json") else {}
fman["bear"]=None                                    # 熊只有單幀（grafxkid pack）
fman["wolf"]=None                                    # 野狼＝熊單幀 recolor 冷灰佔位（商店/LPC 皆無四足狼；見 CREDITS）
SINGLE_FRAME={"bear":"Bear_Idle.png","wolf":"Wolf_Idle.png"}
# 野狼佔位圖：Bear_Idle 去飽和→冷灰、略暗；每次 build 由熊圖重生，不手動維護二進位檔
_bsrc=Image.open(f"{A}/battle/Bear_Idle.png").convert("RGBA"); _bpx=_bsrc.load()
_wolfim=Image.new("RGBA",_bsrc.size,(0,0,0,0)); _wpx=_wolfim.load()
for _wy in range(_bsrc.height):
    for _wx in range(_bsrc.width):
        _r,_g,_b,_a=_bpx[_wx,_wy]
        if _a==0: continue
        _L=(0.3*_r+0.59*_g+0.11*_b)*0.86
        _wpx[_wx,_wy]=(int(max(0,min(255,_L*0.93))),int(max(0,min(255,_L*0.98))),int(max(0,min(255,_L*1.12))),_a)
_wolfim.save(f"{A}/battle/Wolf_Idle.png")
def outline_img(im,col=(26,20,30,255)):
    im=im.convert("RGBA")
    pad_w,pad_h=im.width+4,im.height+4
    a=im.split()[3]
    ol=Image.new("L",(pad_w,pad_h),0)
    for ddx in (-1,0,1):
        for ddy in (-1,0,1):
            if ddx or ddy: ol.paste(255,(2+ddx,2+ddy),a)
    base=Image.new("RGBA",(pad_w,pad_h),(0,0,0,0))
    base.paste(Image.new("RGBA",(pad_w,pad_h),col),(0,0),ol)
    base.alpha_composite(im,(2,2))
    return base
FOE_FRAMES={}; FOE_DIMS={}
LPC_FOES={"goblin","orc","maskedorc","skeleton","necro","ogre",       # 人形怪：art_v8_foes.py LPC 合成
          "gslime","worm","wogol","demon","chort","bird","bear","wolf"} # 非人形怪：art_v9_creatures.py OGA LPC 生物包（優先讀 lpc_src/<key>_0.png）
LPCF=f"{A}/battle/lpc_src"
for k,fs in fman.items():
    _lp=f"{LPCF}/{k}_0.png"
    if k in LPC_FOES and os.path.exists(_lp):
        frames=[Image.open(_lp)]
    elif fs is None:
        frames=[Image.open(f"{A}/battle/{SINGLE_FRAME[k]}")]
    else:
        frames=[Image.open(f"{SRCF}/{fn}") for fn in fs]
    FOE_FRAMES[k]=len(frames)
    for i,im in enumerate(frames):
        out=outline_img(im); out.save(f"{A}/battle/foe_{k}_{i}.png")
        FOE_DIMS[k]=list(out.size)
NATIVE.update(FOE_DIMS)
img=Image.new("RGBA",(64,18),(0,0,0,0)); dd=ImageDraw.Draw(img)    # 腳下軟陰影
for r,alp in [(1.0,60),(0.72,55),(0.45,50)]:
    dd.ellipse([32-30*r,9-7*r,32+30*r,9+7*r],fill=(10,8,14,alp))
img.save(f"{A}/battle/shadow.png")

# ================= 3. JSON 輔助 =================
def res_(name,file,kind,sm=False):
    r={"alwaysLoaded":False,"file":file,"kind":kind,"metadata":"","name":name,"userAdded":True}
    if kind=="image": r["smoothed"]=sm
    return r
def frame(img):
    return {"hasCustomCollisionMask":False,"image":img,"points":[],
            "originPoint":{"name":"origine","x":0,"y":0},
            "centerPoint":{"automatic":True,"name":"centre","x":0,"y":0},"customCollisionMask":[]}
def anim(name,imgs,tbf=0.08,loop=True):
    return {"name":name,"useMultipleDirections":False,
            "directions":[{"looping":loop,"timeBetweenFrames":tbf,"sprites":[frame(i) for i in imgs]}]}
def sprite(name,anims,behaviors=None):
    return {"name":name,"type":"Sprite","tags":"","variables":[],"effects":[],
            "behaviors":behaviors or [],"adaptCollisionMaskAutomatically":True,
            "updateIfNotVisible":False,"animations":anims}
def text_obj(name,text="",size=26,color="255;255;255",bold=True,align="left"):
    return {"name":name,"type":"TextObject::Text","tags":"","variables":[],"effects":[],"behaviors":[],
            "content":{"text":text,"font":"","characterSize":size,"color":color,"bold":bold,
                       "italic":False,"underlined":False,"smoothed":True,"textAlignment":align,
                       "verticalTextAlignment":"top","isOutlineEnabled":True,"outlineColor":"10;10;20",
                       "outlineThickness":2,"isShadowEnabled":False,"shadowColor":"0;0;0","shadowOpacity":127,
                       "shadowDistance":3,"shadowAngle":90,"shadowBlurRadius":2}}
def shapepainter(name):
    # 角色選單盒狀面板：以程序繪製（clearBetweenFrames 每幀自清、absoluteCoordinates 走螢幕座標）
    return {"name":name,"type":"PrimitiveDrawing::Drawer","tags":"","variables":[],"effects":[],"behaviors":[],
            "fillOpacity":255,"outlineSize":2,"outlineOpacity":255,
            "absoluteCoordinates":True,"clearBetweenFrames":True,"antialiasing":"none",
            "fillColor":"30;34;54","outlineColor":"10;10;20"}
def inst(name,x,y,z=1,w=0,h=0,layer_="",variables=None):
    dd={"angle":0,"customSize":bool(w or h),"height":h,"layer":layer_,"locked":False,
        "name":name,"persistentUuid":str(uuid.uuid4()),"width":w,"x":x,"y":y,
        "zOrder":z,"numberProperties":[],"stringProperties":[],"initialVariables":[]}
    if variables:
        dd["initialVariables"]=[{"name":k,"type":"number","value":v} for k,v in variables.items()]
    return dd
def layer_def(name=""):
    return {"ambientLightColorB":32,"ambientLightColorG":32,"ambientLightColorR":32,
            "camera3DFarPlaneDistance":10000,"camera3DFieldOfView":45,"camera3DNearPlaneDistance":0.1,
            "followBaseLayerCamera":False,"isLightingLayer":False,"isLocked":False,"name":name,
            "renderingType":"","visibility":True,"effects":[],
            "cameras":[{"defaultSize":True,"defaultViewport":True,"height":0,"width":0,
                        "viewportBottom":1,"viewportLeft":0,"viewportRight":1,"viewportTop":0}]}
def jsev(code):
    return {"type":"BuiltinCommonInstructions::JsCode","inlineCode":code,
            "parameterObjects":"","useStrict":False,"eventsSheetExpanded":False}
def scene(name,bg=(20,24,34)):
    return {"b":bg[2],"r":bg[0],"v":bg[1],"disableInputWhenNotFocused":False,"mangledName":name,
            "name":name,"standardSortMethod":True,"stopSoundsOnStartup":True,"title":"","uiSettings":{},
            "variables":[],"instances":[],"objects":[],"objectsFolderStructure":{"folderName":"__ROOT"},
            "objectsGroups":[],"events":[],"layers":[layer_def(""),layer_def("UI")],
            "behaviorsSharedData":[],"usedResources":[]}
def svar(n,t,v): return {"name":n,"type":t,"value":v}

ROWS=["Up","Left","Down","Right"]
def char_anims(cn,full):
    out=[]
    for dn in ROWS:
        if full: out.append(anim("Walk"+dn,[f"{cn}_{dn}_{c}.png" for c in range(1,9)]))
        out.append(anim("Idle"+dn,[f"{cn}_{dn}_0.png"],1,False))
    return out
# 戶外遊走 NPC 的 sprite：需完整走路循環（Walk<dir>），遊走時才有真的走路動畫、不會用浮的。
# 其餘 NPC 站定不動，只給 Idle（4 幀）即可。gray/guard 由 art_v10_npcwalk.py 產 36 幀；villager 已有。
WALK_SPRITES={"gray","guard","villager"}
def follower_anims():
    out=[]
    for cn in ["marin","aaron"]:
        for dn in ROWS:
            out.append(anim(f"{cn}_Walk{dn}",[f"{cn}_{dn}_{c}.png" for c in range(1,9)]))
            out.append(anim(f"{cn}_Idle{dn}",[f"{cn}_{dn}_0.png"],1,False))
    return out
FACE_IDS=["ludo","marin","aaron","tina","dora","sister","barton","gid","hank","martha","gray","mira","guard"]
def face_anims():
    return [anim(k,[f"face_{k}.png"],1,False) for k in FACE_IDS]
ART_IDS=["ludo","marin","aaron"]   # 有全身立繪者（選單故事頁展示）
def art_anims():
    return [anim(k,[f"menuart_{k}.png"],1,False) for k in ART_IDS]
def portrait_anims():   # 對話用大型去背半身立繪（取代舊 144 小頭像框）
    return [anim(k,[f"portrait_{k}.png"],1,False) for k in FACE_IDS]

def tmj_write(name,MW,MH,ground):
    tmj={"compressionlevel":-1,"width":MW,"height":MH,"tilewidth":TS,"tileheight":TS,"infinite":False,
         "orientation":"orthogonal","renderorder":"right-down","tiledversion":"1.12.2","type":"map",
         "version":"1.10","nextlayerid":2,"nextobjectid":1,
         "tilesets":[{"firstgid":1,"name":"atlas","image":"atlas.png","imagewidth":COLS*TS,
                      "imageheight":rows_n*TS,"tilewidth":TS,"tileheight":TS,"columns":COLS,
                      "tilecount":COLS*rows_n,"margin":0,"spacing":0}],
         "layers":[{"id":1,"name":"g","type":"tilelayer","visible":True,"opacity":1,
                    "width":MW,"height":MH,"x":0,"y":0,"data":ground}]}
    json.dump(tmj,open(f"{A}/map/{name}.tmj","w"))

# ================= 4. 地圖建構 =================
class MapB:
    def __init__(s,MW,MH,base):
        s.MW,s.MH=MW,MH
        s.g=[base]*(MW*MH)
        s.blocked=[[False]*MW for _ in range(MH)]
        s.enc=[[False]*MW for _ in range(MH)]
        s.props=[]
        for yy in range(MH): s.blocked[yy][0]=s.blocked[yy][MW-1]=True
        for xx in range(MW): s.blocked[0][xx]=s.blocked[MH-1][xx]=True
    def set(s,x,y,t):
        if 0<=x<s.MW and 0<=y<s.MH: s.g[y*s.MW+x]=t
    def get(s,x,y): return s.g[y*s.MW+x]
    def rect(s,x1,y1,x2,y2,t):
        for yy in range(y1,y2+1):
            for xx in range(x1,x2+1): s.set(xx,yy,t)
    def block(s,x1,y1,x2=None,y2=None):
        x2=x2 if x2 is not None else x1; y2=y2 if y2 is not None else y1
        for yy in range(y1,y2+1):
            for xx in range(x1,x2+1):
                if 0<=xx<s.MW and 0<=yy<s.MH: s.blocked[yy][xx]=True
    def unblock(s,x1,y1,x2=None,y2=None):
        x2=x2 if x2 is not None else x1; y2=y2 if y2 is not None else y1
        for yy in range(y1,y2+1):
            for xx in range(x1,x2+1):
                if 0<=xx<s.MW and 0<=yy<s.MH: s.blocked[yy][xx]=False
    def mark_enc(s):
        for yy in range(s.MH):
            for xx in range(s.MW):
                if s.g[yy*s.MW+xx] in (G["tgrass"],G["gravel"]): s.enc[yy][xx]=True
    def prop(s,name,tx,ty,foot=None,px=0,py=0):
        s.props.append((name,tx*TS+px,ty*TS+py))
        if foot: s.block(tx+foot[0],ty+foot[1],tx+foot[2],ty+foot[3])
    def trees_border(s,skip=(),step=2,tree="Tree"):
        pick=tree if callable(tree) else (lambda:tree)   # tree 可為固定名或每棵回傳名的 callable
        for xx in range(1,s.MW-1,step):
            # 頂排：樹放第 3 列（120 高的樹 py=-88，樹冠才不會超出世界頂端被裁切），連 1-2 列一起擋
            if (xx,1) not in skip and (xx,2) not in skip and (xx,3) not in skip and not s.blocked[3][xx] and s.g[3*s.MW+xx]==G["grass"]:
                s.prop(pick(),xx,3,px=TPX,py=TPY); s.block(xx,1); s.block(xx,2); s.block(xx,3)
            yy=s.MH-2
            if (xx,yy) not in skip and not s.blocked[yy][xx] and s.g[yy*s.MW+xx]==G["grass"]:
                s.prop(pick(),xx,yy,px=TPX,py=TPY); s.block(xx,yy)
        for yy in range(2,s.MH-2,step+1):
            for xx in (1,s.MW-2):
                if (xx,yy) not in skip and not s.blocked[yy][xx] and s.g[yy*s.MW+xx]==G["grass"]:
                    s.prop(pick(),xx,yy,px=TPX,py=TPY); s.block(xx,yy)
    def strs(s):
        B=[''.join('1' if s.blocked[y][x] else '0' for x in range(s.MW)) for y in range(s.MH)]
        E=[''.join('1' if s.enc[y][x] else '0' for x in range(s.MW)) for y in range(s.MH)]
        return B,E

# ---- 迷宮工具：2 格寬走廊、遞迴回溯 ----
def carve_maze(mb,x0,y0,x1,y1,wall,floor):
    """區域填牆後挖迷宮。cell=3（走廊2+牆1），走廊統一 2 格寬。"""
    for yy in range(y0,y1+1):
        for xx in range(x0,x1+1): mb.set(xx,yy,wall)
    mb.block(x0,y0,x1,y1)
    cw,ch=(x1-x0)//3,(y1-y0)//3
    def base(cx,cy): return (x0+1+cx*3,y0+1+cy*3)
    def open_rect(xa,ya,xb,yb):
        for yy in range(ya,yb+1):
            for xx in range(xa,xb+1):
                mb.set(xx,yy,floor); mb.unblock(xx,yy)
    seen=[[False]*cw for _ in range(ch)]
    st=[(random.randrange(cw),random.randrange(ch))]
    seen[st[0][1]][st[0][0]]=True
    bx,by=base(*st[0]); open_rect(bx,by,bx+1,by+1)
    while st:
        cx,cy=st[-1]
        nbrs=[(nx,ny) for nx,ny in ((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1))
              if 0<=nx<cw and 0<=ny<ch and not seen[ny][nx]]
        if not nbrs: st.pop(); continue
        nx,ny=random.choice(nbrs); seen[ny][nx]=True
        ax,ay=base(cx,cy); bx2,by2=base(nx,ny)
        open_rect(min(ax,bx2),min(ay,by2),max(ax,bx2)+1,max(ay,by2)+1)
        st.append((nx,ny))
def tunnel(mb,x,y,dx,dy,floor,wall_ok=None):
    """從 (x,y) 沿方向打 2 格寬通道，直到接上已開放區域（或到邊界前）。"""
    while 1<x<mb.MW-2 and 1<y<mb.MH-2:
        w=[(x,y),(x+1,y)] if dy else [(x,y),(x,y+1)]
        if all(not mb.blocked[wy][wx] for wx,wy in w): break
        for wx,wy in w: mb.set(wx,wy,floor); mb.unblock(wx,wy)
        x+=dx; y+=dy
def open_rect_on(mb,xa,ya,xb,yb,floor):
    for yy in range(ya,yb+1):
        for xx in range(xa,xb+1):
            mb.set(xx,yy,floor); mb.unblock(xx,yy)
def assert_reachable(mb,start,goals,name):
    from collections import deque
    q=deque([start]); seen={start}
    while q:
        x,y=q.popleft()
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx,ny=x+dx,y+dy
            if 0<=nx<mb.MW and 0<=ny<mb.MH and (nx,ny) not in seen and not mb.blocked[ny][nx]:
                seen.add((nx,ny)); q.append((nx,ny))
    for gname,g in goals:
        assert g in seen, f"{name}: {gname}{g} 從 {start} 不可達"
    return seen

# ---- Town 42x30 ----
tw=MapB(42,30,G["grass"])
for _ in range(140): tw.set(random.randrange(42),random.randrange(30),G["grassf"])
tw.rect(20,0,23,29,G["path"]); tw.rect(0,13,41,16,G["path"])   # 十字路
tw.rect(18,10,25,17,G["plaza"])                    # 石板廣場（蓋在路口上，道路匯入廣場）
tw.rect(30,22,37,27,G["farm"])                     # 農田
# （河流/石橋已移除——John：河流完全沒必要；鎮東改回草地開闊空間）
# ---- Track J：45° 斜角外觀建築 ----
# 六棟改用 ext_*.png 大圖（原生 ~600-1022px），以 instance customSize 縮到底部約 5 格寬。
# 每棟定義「門口格」(door_tx,door_ty)＝底部中央、務必可站立才能觸發進屋。
BLDG_EXT={"BGuild":(634,858),"BInn":(605,822),"BShrine":(783,861),
          "BMayor":(1022,1023),"BShop":(709,848),"BSmith":(660,859)}   # ext 原生 (w,h)
BLDG_INT={"BGuild":(1118,839),"BInn":(1088,814),"BShrine":(1099,838),
          "BMayor":(1122,844),"BShop":(1077,816),"BSmith":(1074,820)}  # int 原生 (w,h)
BLDG_KEY={"BGuild":"guild","BInn":"inn","BShrine":"shrine",
          "BMayor":"mayor","BShop":"shop","BSmith":"smithy"}
# ext_ 大圖去背不完全（部分留有洋紅底座）——build 時 color-key 出乾淨版 extc_*.png（原檔不動）
def _lerp3(a,b,f): return tuple(int(a[i]+(b[i]-a[i])*f) for i in range(3))
_ROOF_SHADOW=(42,46,56); _ROOF_HI=(120,128,142)   # 深藍灰石板屋頂漸層
def _clean_ext(src,dst,stone=False):
    """去洋紅底；stone=True 時再把六棟統一成石造——磚紅屋頂→深色石板、暖乳白牆→中性灰米石（John 定案）。"""
    im=Image.open(src).convert("RGBA"); w,h=im.size; px=im.load()
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]
            if a==0: continue
            # 洋紅底/殘暈（r、b 高、g 明顯偏低）→ 透明（比舊版更廣，連 g≈90 的殘暈也清掉）
            if r>118 and b>84 and g<r-38 and g<b-12:
                px[x,y]=(r,g,b,0); continue
            if not stone: continue
            if r-g>44 and r-b>44 and r>95:                    # 飽和磚紅/橘紅屋頂 → 深色石板（亮度保留瓦片明暗）
                L=(r*30+g*59+b*11)//100; f=max(0.0,min(1.0,(L-40)/140.0))
                px[x,y]=_lerp3(_ROOF_SHADOW,_ROOF_HI,f)+(a,); continue
            if r>150 and 22<=r-b<=95 and r-g<40 and g>b:      # 暖乳白牆 → 稍中性化成灰米石（不動窗光/深木/石）
                nb=b+(r-b)*35//100; nr=r-(r-b)*22//100
                px[x,y]=(nr,(g+nb)//2 if g>nb else g,nb,a)
    im.save(dst)
BLDG_EXTF={}
for _bo,_bk in BLDG_KEY.items():
    _clean_ext(f"{P}/ext_{_bk}.png",f"{P}/extc_{_bk}.png",stone=True); BLDG_EXTF[_bo]="extc_"+_bk+".png"
    _clean_ext(f"{P}/int_{_bk}.png",f"{P}/intc_{_bk}.png")   # 手繪室內大圖去洋紅底（折衷方案：當室內背景，配隱形碰撞）
# (obj, door_tx, door_ty, 底部寬幾格)
# 房子大小還原成 5 格寬（John：4 格太小、要配合人物大小）。樹一律避開建築實際覆蓋範圍→不會被遮成一角/擋門口。
BLDG_LAYOUT=[("BGuild",6,8,5),("BInn",14,8,5),("BShrine",30,8,5),
             ("BMayor",37,9,5),("BShop",6,24,5),("BSmith",14,24,5)]
BLDG_SIZE={}   # obj -> (W,H) 縮放後像素尺寸（instance customSize 用）
BLDG_DOOR={}   # obj -> (door_tx,door_ty)
BLDG_RECT={}   # obj -> (sx,sy,W,H) 精靈實際像素矩形（給樹木淨空區用）
def place_building(mb,obj,dx,dy,bw):
    nw,nh=BLDG_EXT[obj]
    W=bw*TS; H=int(round(W*nh/nw))
    sx=dx*TS+TS//2-W//2                 # 精靈水平置中於門口格
    sy=(dy*TS+8)-H                       # 底部落在門口格上緣附近
    mb.props.append((obj,sx,sy))
    BLDG_SIZE[obj]=(W,H); BLDG_DOOR[obj]=(dx,dy); BLDG_RECT[obj]=(sx,sy,W,H)
    # 碰撞footprint＝精靈實際覆蓋的 tile 範圍（消除「看不到卻擋路」的隱形牆）
    tx0=max(0,sx//TS); tx1=min(mb.MW-1,(sx+W-1)//TS)
    mb.block(tx0,dy-2,tx1,dy-1)          # 建築本體(底部上兩排)擋牆
    for xx in range(tx0,tx1+1):          # 門口那排：門格保留可站立，其餘擋牆
        if xx!=dx: mb.block(xx,dy)
for _o,_dx,_dy,_bw in BLDG_LAYOUT: place_building(tw,_o,_dx,_dy,_bw)
tw.prop("Well",18,11,foot=(0,0,1,0),px=4,py=-24)   # 井腳只擋 2×1(可見底座)，不多擋一排
tw.prop("Board",10,9,foot=(0,0,0,0))               # 公會旁告示板（移離 NPC 便於互動）
for fx in range(30,38): tw.prop("Fence",fx,21,foot=(0,0,0,0)); tw.block(fx,21)
# 建築淨空區＝每棟精靈實際覆蓋的整塊 tile（左右各留 1 格邊、上緣到屋頂上 1 格、門口下方留 4 排）。
# 樹一律不進此區→不會被建築遮成「只剩左上角」、也不會種在房子下方擋住進屋動線（John 兩個 bug 一次解）。
_bld_clear=set()
for _o,_dx,_dy,_bw in BLDG_LAYOUT:
    _sx,_sy,_W,_H=BLDG_RECT[_o]
    _tx0=_sx//TS-1; _tx1=(_sx+_W-1)//TS+1; _ty0=_sy//TS-1; _ty1=_dy+4
    for _yy in range(_ty0,_ty1+1):
        for _xx in range(_tx0,_tx1+1): _bld_clear.add((_xx,_yy))
# 北向道路出口上緣別種樹（樹冠會戳到路口）
_top_skip={(_x,_y) for _x in range(20,24) for _y in (1,2,3)}
tw.trees_border(skip=_bld_clear|_top_skip,step=3,tree=_town_tree)   # 邊界樹疏一點；anokolisa 樹種（_TRNG 獨立不動全域流）
# 散佈樹叢石：數量砍半(26→13)＋彼此不緊貼(避免破圖)。用 get/setstate 隔離 RNG→不影響後續地牢迷宮
_rs=random.getstate()
placed=0; _pl=[]; _tries=0
while placed<13 and _tries<1200:
    _tries+=1
    xx,yy=random.randrange(2,40),random.randrange(2,28)
    if tw.blocked[yy][xx] or (xx,yy) in _bld_clear or tw.get(xx,yy) not in (G["grass"],G["grassf"]) or (13<=xx<=28 and 8<=yy<=19): continue
    if any(abs(xx-_px)<=1 and abs(yy-_py)<=1 for _px,_py in _pl): continue   # 不緊貼
    k=random.choice(["Tree","Tree","Bush","Rock"])
    if k=="Tree": tw.prop(_town_tree(),xx,yy,px=TPX,py=TPY)   # anokolisa 樹種（此區已 getstate/setstate 隔離）
    else: tw.prop(k,xx,yy,py=6)
    tw.block(xx,yy); _pl.append((xx,yy)); placed+=1
random.setstate(_rs)   # 還原 RNG
# ---- 街道／廣場裝飾（純裝飾，一律不 block；py 讓底部對齊格底）----
# 房子放大成 5 格後，原本貼著小房子的街道裝飾會被新建築遮住→deco() 自動跳過落在建築淨空區的格子。
def deco(name,cells,**kw):
    for _cx,_cy in cells:
        if (_cx,_cy) in _bld_clear: continue   # 別讓裝飾被建築遮成一角
        tw.prop(name,_cx,_cy,**kw)
deco("Stall",[(18,9),(21,15)],py=-52)
deco("Lamp",[(18,10),(24,10),(18,17),(24,16),(27,13)],py=-28)
deco("Flowerbed",[(22,12),(19,17),(28,18)],py=6)
deco("Crate",[(9,11),(10,22)],py=4)                 # 街角木箱（房子之間的巷道）
deco("Barrel",[(10,11),(9,22)],py=-2)
deco("Laundry",[(10,26)],py=-12)
deco("Bush",[(24,6),(24,20),(29,24),(26,19),(34,16)],py=6)   # 開闊草地點綴灌木
# 出口通道保持暢通
tw.unblock(20,0,23,0); tw.unblock(41,13,41,16)
tw.mark_enc()

# ---- Forest 兩層 64x44：樹牆迷宮（第一層通往深處、第二層有頭目）----
# 森林地面裝飾（FTREES/_FRNG 已於檔頭定義）。獨立 RNG，絕不動全域 random 流。
_FDECO = ["FFern","FMush","FFlower","FPebble","FFern","FFlower","FBush"]  # 加權：蕨/花多、灌木少
def _forest_decor(m):
    for y in range(1,m.MH-1):
        for x in range(1,m.MW-1):
            if m.blocked[y][x]: continue
            if m.get(x,y) in (G["grass"],G["grassf"],G["tgrass"]) and _FRNG.random()<0.10:
                m.prop(_FRNG.choice(_FDECO),x,y,py=6)             # 無 foot → 不擋路、連通性不受影響
def make_forest(MW,MH,entry_y,exit_east=False,boss=False):
    m=MapB(MW,MH,G["grass"])
    carve_maze(m,1,1,MW-2,MH-2,G["fwall"],G["grass"])
    for yy in range(MH): m.set(0,yy,G["fwall"]); m.set(MW-1,yy,G["fwall"])
    for xx in range(MW): m.set(xx,0,G["fwall"]); m.set(xx,MH-1,G["fwall"])
    m.set(0,entry_y,G["path"]); m.set(0,entry_y+1,G["path"])
    open_rect_on(m,1,entry_y,2,entry_y+1,G["path"])          # 西入口通道
    m.unblock(0,entry_y,0,entry_y+1)
    tunnel(m,3,entry_y,1,0,G["path"])
    ey=MH//2-1
    if boss:
        open_rect_on(m,MW-8,ey-4,MW-3,ey+4,G["dirt"])        # 頭目空地（東側深處）
        tunnel(m,MW-9,ey,-1,0,G["grass"])
    if exit_east:                                            # 東出口 → 森林深處
        m.set(MW-1,ey,G["path"]); m.set(MW-1,ey+1,G["path"])
        open_rect_on(m,MW-3,ey,MW-2,ey+1,G["path"])
        m.unblock(MW-1,ey,MW-1,ey+1)
        tunnel(m,MW-4,ey,-1,0,G["path"])
    for y in range(1,MH-1):                                  # 花 10%、高草(遇敵) 32%
        for x in range(1,MW-1):
            if not m.blocked[y][x] and m.get(x,y)==G["grass"]:
                r=random.random()
                if r<0.10: m.set(x,y,G["grassf"])
                elif r<0.42: m.set(x,y,G["tgrass"])
    for y in range(3,MH-2):                                  # 牆帶立體大樹（上兩格也是牆才種）
        for x in range(2,MW-2):
            if (m.get(x,y)==G["fwall"] and m.get(x,y-1)==G["fwall"]
                and m.get(x,y-2)==G["fwall"] and random.random()<0.22):
                m.prop(_FRNG.choice(FTREES),x,y,px=TPX,py=TPY)   # 多樹種（全域 0.22 判定不變→種樹位置與原本一致）
    _forest_decor(m)                                             # 開闊草地撒非阻擋裝飾
    m.mark_enc()
    return m
FW,FH=64,44
FEY=FH//2-1                                          # 東西向通道列＝21
fo=make_forest(FW,FH,15,exit_east=True)
fo2=make_forest(FW,FH,FEY,boss=True)
# 支線A：三株鏡草採集點——左/中/右三段各取一個最靠近東西主動線(FEY)的可達格（確定性，不動 RNG 流）
_WALK_FO=(G["grass"],G["grassf"],G["tgrass"],G["path"],G["dirt"])
opens_fo=[(x,y) for y in range(3,FH-3) for x in range(3,FW-3)
          if not fo.blocked[y][x] and fo.get(x,y) in _WALK_FO]
HERB_TILES=[]
for _lo,_hi in [(3,FW//3),(FW//3,2*FW//3),(2*FW//3,FW-3)]:
    _seg=[p for p in opens_fo if _lo<=p[0]<_hi]
    if _seg: HERB_TILES.append(min(_seg,key=lambda p:(abs(p[1]-FEY),p[0])))
assert_reachable(fo,(2,15),[("東出口",(FW-2,FEY))]+[("鏡草%d"%_i,_t) for _i,_t in enumerate(HERB_TILES)],"forest")
assert_reachable(fo2,(2,FEY),[("頭目空地",(FW-6,FEY))],"forest2")

# ---- Mine 60x42：岩壁迷宮＋中央軌道主通道 ----
MMW,MMH=60,42
mi=MapB(MMW,MMH,G["rockfloor"])
carve_maze(mi,1,1,MMW-2,MMH-3,G["cwall"],G["rockfloor"])
for yy in range(MMH): mi.set(0,yy,G["cwall"]); mi.set(MMW-1,yy,G["cwall"])
for xx in range(MMW):
    mi.set(xx,0,G["cwall"])
    if not (20<=xx<=23):
        mi.set(xx,MMH-2,G["cwall"]); mi.block(xx,MMH-2); mi.set(xx,MMH-1,G["cwall"])
open_rect_on(mi,21,2,22,MMH-2,G["path"])           # 中央主通道（南口→礦坑口）
mi.rect(21,4,22,8,G["rail"])                       # 軌道段
for oy in (8,16,24,32):                            # 主通道兩側開口接迷宮
    tunnel(mi,20,oy,-1,0,G["rockfloor"])
    tunnel(mi,23,oy,1,0,G["rockfloor"])
mi.prop("CaveMouth",19,1,foot=(0,1,4,3),py=-40)
mi.unblock(21,2,22,4)                              # 洞口通道(含洞口footprint內)
# 迷宮走廊灑碎石(遇敵) 40%；主通道中段一段碎石（序章教學戰）
for y in range(1,MMH-2):
    for x in range(1,MMW-1):
        if not mi.blocked[y][x] and mi.get(x,y)==G["rockfloor"] and random.random()<0.40:
            mi.set(x,y,G["gravel"])
mi.rect(21,18,22,26,G["gravel"])
# 支撐架與鐘乳石點綴（放牆邊，不擋走廊）
for x,y in [(5,7),(50,11),(9,29),(45,33),(15,19),(33,37)]:
    if mi.blocked[y][x]: mi.prop("Support",x,y,foot=(0,0,0,0))
opens_mi=[(x,y) for y in range(2,MMH-3) for x in range(2,MMW-2)
          if not mi.blocked[y][x] and not (20<=x<=23)]
_stals=random.sample(opens_mi,min(20,len(opens_mi)))
for x,y in _stals:
    mi.prop(random.choice(["StalGold","StalBrown"]),x,y,py=8)   # 純裝飾不擋路（迷宮走廊擋一格就可能斷路）
# 第二章氛圍：骨骸/骷髏/蜘蛛網（呼應骷髏礦工；確定性挑點、不動 RNG、不擋路）
_dmi=[p for p in opens_mi if p not in _stals]
for _i,(x,y) in enumerate(_dmi[3::11][:9]):
    mi.prop(["DunBones","DunSkull","DunSkullPile","DunWeb"][_i%4],x,y,py=6)
mi.unblock(20,MMH-1,23,MMH-1)
mi.mark_enc()
mleft=[p for p in opens_mi if p[0]<20][0]; mright=[p for p in opens_mi if p[0]>23][0]
# 支線B：阿吉頭盔遺物點——深處(y<16)、最靠近中央主通道、不與鐘乳石重疊的可達格（確定性挑選，不動 RNG 流）
_relic_cand=[p for p in opens_mi if p[1]<16 and p not in _stals]
RELIC_TILE=min(_relic_cand,key=lambda p:(abs(p[0]-21),p[1])) if _relic_cand else (19,8)
assert_reachable(mi,(21,MMH-2),[("礦坑口",(21,3)),("左區",mleft),("右區",mright),("遺物點",RELIC_TILE)],"mine")

# ---- Cave 50x36：岩壁迷宮 ----
CMW,CMH=50,36
ca=MapB(CMW,CMH,G["cavefloor"])
carve_maze(ca,1,2,CMW-3,CMH-4,G["cwall"],G["cavefloor"])
for yy in range(CMH): ca.set(0,yy,G["cwall"]); ca.set(CMW-1,yy,G["cwall"]); ca.set(CMW-2,yy,G["cwall"])
for xx in range(CMW):                              # 頂部岩壁帶＋底部封牆（出口除外）
    ca.set(xx,0,G["cwall"]); ca.set(xx,1,G["cwtop"] if xx%3 else G["cwall"])
    for yy in (CMH-3,CMH-2,CMH-1):
        if not (17<=xx<=19): ca.set(xx,yy,G["cwall"]); ca.block(xx,yy)
open_rect_on(ca,14,2,22,6,G["cavedark"])           # 序章魔影廳（北端）
ca.unblock(14,2,22,6)
tunnel(ca,17,7,0,1,G["cavefloor"])                 # 魔影廳向南接迷宮
open_rect_on(ca,17,CMH-3,19,CMH-2,G["cavefloor"])  # 南出口通道
ca.rect(17,CMH-1,19,CMH-1,G["cavefloor"]); ca.unblock(17,CMH-1,19,CMH-1)
tunnel(ca,17,CMH-4,0,-1,G["cavefloor"])
# 走廊灑暗斑與石筍（不擋路）
opens_ca=[(x,y) for y in range(7,CMH-3) for x in range(2,CMW-3) if not ca.blocked[y][x]]
for x,y in opens_ca:
    if random.random()<0.16 and ca.get(x,y)==G["cavefloor"]: ca.set(x,y,G["cavedark"])
for x,y in random.sample(opens_ca,min(22,len(opens_ca))):
    if not (16<=x<=20): ca.prop(random.choice(["StalBrown","StalBlack"]),x,y,py=8)   # 純裝飾不擋路
# 洞穴氛圍：骨骸/蜘蛛網/裂縫（確定性、不動 RNG、不擋路）
_dca=[p for p in opens_ca if not (16<=p[0]<=20)]
for _i,(x,y) in enumerate(_dca[5::13][:8]):
    ca.prop(["DunBones","DunWeb","DunSkull","DunCrack"][_i%4],x,y,py=6)
# 迷宮區可遇敵（魔影廳與出口通道除外）
for yy in range(7,CMH-4):
    for xx in range(1,CMW-2):
        if not ca.blocked[yy][xx]: ca.enc[yy][xx]=True
assert_reachable(ca,(18,CMH-2),[("魔影廳",(17,4))],"cave")

# ---- 地圖寶箱：依 CONTENT.chests 擋住寶箱格（寶箱本身擋路），並重驗連通性 ----
# 手選的可達隱蔽格（scripts/scratch 分析 seed=51 迷宮：死路盡頭/角落/通道旁）。
# 擋掉寶箱格後，各地圖原目標仍須可達，且每個寶箱至少一個可達鄰格（玩家走到旁邊開箱）。
CHESTS = CONTENT.get("chests", [])
CHEST_BY_MAP = {}
for _c in CHESTS: CHEST_BY_MAP.setdefault(_c["map"], []).append(_c)
_CHEST_MAPREF = {
    "forest":  (fo,  (2,15),      [("東出口",(FW-2,FEY))]),
    "forest2": (fo2, (2,FEY),     [("頭目空地",(FW-6,FEY))]),
    "mine":    (mi,  (21,MMH-2),  [("礦坑口",(21,3)),("左區",mleft),("右區",mright)]),
    "cave":    (ca,  (18,CMH-2),  [("魔影廳",(17,4))]),
}
for _mk,_cl in CHEST_BY_MAP.items():
    _mb,_start,_goals = _CHEST_MAPREF[_mk]
    for _c in _cl:
        assert not _mb.blocked[_c["ty"]][_c["tx"]], f"{_mk} 寶箱 {_c['id']} 座標({_c['tx']},{_c['ty']})原本就是牆"
        _mb.block(_c["tx"],_c["ty"])                        # 寶箱擋路
    _seen = assert_reachable(_mb,_start,_goals,_mk+"(含寶箱)")
    for _c in _cl:
        _nb=[(_c["tx"]+dx,_c["ty"]+dy) for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))]
        assert any(n in _seen for n in _nb), f"{_mk} 寶箱 {_c['id']}({_c['tx']},{_c['ty']}) 無可達鄰格，玩家開不到"

FAMILY = None
def autotile(mb):
    global FAMILY
    if FAMILY is None:
        FAMILY = {G["path"],G["dirt"],G["bridge"],G["farm"],G["rail"],G["plaza"],G["pc"],G["pn"],G["ps"],G["pw"],G["pe"],G["pnw"],G["pne"],G["psw"],G["pse"],G["pinw"],G["pine"],G["pisw"],G["pise"]}
    src = list(mb.g)
    def fam(xx,yy):
        if xx<0 or yy<0 or xx>=mb.MW or yy>=mb.MH: return True
        return src[yy*mb.MW+xx] in FAMILY
    for y in range(mb.MH):
        for x in range(mb.MW):
            t = src[y*mb.MW+x]
            if t not in (G["path"],G["dirt"]): continue
            T,B,L,R = fam(x,y-1),fam(x,y+1),fam(x-1,y),fam(x+1,y)
            m = {(1,1,1,1):"pc",(0,1,1,1):"pn",(1,0,1,1):"ps",(1,1,0,1):"pw",(1,1,1,0):"pe",
                 (0,1,0,1):"pnw",(0,1,1,0):"pne",(1,0,0,1):"psw",(1,0,1,0):"pse"}
            k = m.get((int(T),int(B),int(L),int(R)),"pc")
            tile = G[k]
            if k=="pc":
                if not fam(x-1,y-1): tile=G["pinw"]
                elif not fam(x+1,y-1): tile=G["pine"]
                elif not fam(x-1,y+1): tile=G["pisw"]
                elif not fam(x+1,y+1): tile=G["pise"]
            mb.g[y*mb.MW+x]=tile
def grass_vary(mb):
    gv=[G["grass"],G["grass"],G["grass2"],G["grass3"]]
    mb.g=[random.choice(gv) if t==G["grass"] else t for t in mb.g]
def wall_caps(mb):
    """岩壁立體化（礦山用）：牆格下方是地板→畫牆面(cwall)，否則畫暗圓石牆頂(ctop)。"""
    wallset={G["cwall"],G["ctop"]}
    src=list(mb.g)
    for y in range(mb.MH):
        for x in range(mb.MW):
            if src[y*mb.MW+x] in wallset:
                below=src[(y+1)*mb.MW+x] if y+1<mb.MH else None
                mb.g[y*mb.MW+x]=G["cwall"] if (below is not None and below not in wallset) else G["ctop"]
autotile(tw); autotile(fo); autotile(fo2)
grass_vary(tw); grass_vary(fo); grass_vary(fo2)
wall_caps(mi)
tmj_write("town",42,30,tw.g)
tmj_write("forest",FW,FH,fo.g); tmj_write("forest2",FW,FH,fo2.g)
tmj_write("mine",MMW,MMH,mi.g); tmj_write("cave",CMW,CMH,ca.g)

# ================= 5. 對話/劇情資料 =================
DLG = {
 "tina": [
   # 委託（公會功能，依進度自動變化）
   {"when":"ch1==2","cmd":"quest","label":"委託","name":"緹娜","lines":["委託完成確認——哥布林頭目討伐！","報酬 200 金幣已支付。你們是本鎮的驕傲！","（第一章完──「重返礦山」即將開放）"],"action":"ch1_reward"},
   {"when":"ch1==1","cmd":"quest","label":"委託","name":"緹娜","lines":["委託進行中：討伐東之森深處的哥布林頭目。","牠就在森林最東邊的空地，小心點！"]},
   {"when":"reg==1","cmd":"quest","label":"委託","name":"緹娜","lines":["有新委託喔——農家回報東之森的哥布林越來越囂張，","牠們的頭目就盤踞在森林深處。","【委託】討伐哥布林頭目（報酬 200G）。接受嗎？就當你接受了！","頭目比雜魚強得多——建議練到 Lv5、跟漢克拿把好劍再去。"],"action":"ch1_take"},
   {"when":"step>=3","cmd":"quest","label":"委託","name":"緹娜","lines":["歡迎來到冒險者公會！要登錄成為冒險者嗎？","……路德和瑪琳，兩位都登錄完成！","從今天起你們就是 F 級冒險者了。委託隨時來找我。"],"action":"register"},
   {"when":"always","cmd":"quest","label":"委託","name":"緹娜","lines":["目前沒有適合你們的新委託。","升上一階、或到週邊多探探，說不定就有新工作囉。"]},  # 💠 後備閒聊(待潤)
   # 閒聊
   {"when":"step==0","cmd":"talk","name":"緹娜","lines":["這不是路德嗎？要去礦山見習？","等你正式登錄的那天，公會隨時歡迎你。"]},
   {"when":"ch1==3","cmd":"talk","name":"緹娜","lines":["哥布林頭目的委託已經結案囉，辛苦了！","接下來想找活兒的話，水井旁的老葛雷正在找人幫忙。"]},
   {"when":"ch2>=1","cmd":"talk","name":"緹娜","lines":["礦坑的委託，是老葛雷私下拜託你們的吧？","那些失蹤的礦工……公會這邊也一直很掛心。","小心點，別逞強——活著回來才是好冒險者。"]},
   {"when":"always","cmd":"talk","name":"緹娜","lines":["委託都貼在牆上的告示板，慢慢看。","有什麼想問的，儘管來櫃檯找我。"]},  # 💠 後備閒聊(待潤)
 ],
 "dora": [
   {"when":"always","cmd":"rest","label":"住宿","name":"朵拉","lines":["累了吧？床鋪都幫你們鋪好了。","（隊伍完全恢復了！）"],"action":"heal"},
   {"when":"step==0","cmd":"talk","name":"朵拉","lines":["要跟亞倫先生出門？路上小心。","回來我煮好吃的等你們。"]},
   {"when":"always","cmd":"talk","name":"朵拉","lines":["瑪琳那孩子，就拜託你多照應了。","想歇歇隨時說一聲，自己家不收錢的。"]},  # 💠 後備閒聊(待潤)
 ],
 "sister": [
   {"when":"ch2>=2","cmd":"pray","label":"祈禱","name":"希雅修女","lines":["你們從礦山帶回來的……不只是疲憊。","那是亡者未能安息的哀嘆。願蓋婭女神接引他們。","（隊伍完全恢復了！）","……路德，女神在你身上的記號，又亮了一分。"],"action":"heal"},
   {"when":"always","cmd":"pray","label":"祈禱","name":"希雅修女","lines":["願蓋婭女神看顧你們的旅途。","（在女神像前禱告，隊伍完全恢復了！）"],"action":"heal"},
   {"when":"step==0","cmd":"talk","name":"希雅修女","lines":["蓋婭女神看顧著每一位旅人。"]},
   {"when":"always","cmd":"talk","name":"希雅修女","lines":["……女神在你身上留了記號呢。願風平息。","累了就來祈禱，女神的恩澤不分你我。"]},  # 💠 後備閒聊(待潤)
 ],
 "barton": [
   {"when":"ch2>=3","cmd":"talk","name":"巴頓鎮長","lines":["礦工失蹤的事……我早該多過問一句的。","孩子，你們比這鎮上所有大人都勇敢。","把礦山看到的一切，原原本本告訴大城的人吧。"]},
   {"when":"ch1==3","cmd":"talk","name":"巴頓鎮長","lines":["哥布林的事多虧你們了。","但礦山的異變……我總覺得沒那麼簡單。"]},
   {"when":"step==0","cmd":"talk","name":"巴頓鎮長","lines":["聽說亞倫先生要帶你去礦山見習？","好好跟著學，別亂跑。"]},
   {"when":"always","cmd":"talk","name":"巴頓鎮長","lines":["礦山最近不太平靜，連老獵人都不敢靠近。","亞倫先生的事……我很遺憾。孩子，別勉強自己。"]},
 ],
 "hank": [
   # 一次性事件：臨別贈言（送鐵劍）；ch1>=1 出現、gotSword 後消失
   {"when":"ch1>=1","done":"gotSword","cmd":"hank_gift","label":"臨別贈言","name":"漢克","lines":["……路德，你也要出去闖了啊。","拿去，我打的劍。別死在外面。","（獲得『鐵劍』！開啟 選單→裝備 分頁換上它）"],"action":"give_sword"},
   # 交易（鐵匠鋪功能）
   {"when":"reg==1","cmd":"trade","label":"交易","name":"漢克","lines":["冒險者？裝備可不能馬虎。來，看看我的貨。"],"action":"shop_hank"},
   {"when":"always","cmd":"trade","label":"交易","name":"漢克","lines":["要補貨就直說，鐵匠鋪隨時開著。"],"action":"shop_hank"},
   # 閒聊
   {"when":"step==0","cmd":"talk","name":"漢克","lines":["哼，礦山？","……跟緊亞倫先生，別給他添麻煩。"]},
   {"when":"always","cmd":"talk","name":"漢克","lines":["冒險者？哼，那不是鬧著玩的。","你亞倫大哥那麼強的人都……算了。要去就去吧。"]},
 ],
 "martha": [
   # 一次性事件：母親的心意（送活力戒指）；gotRing 後消失
   {"when":"always","done":"gotRing","cmd":"martha_gift","label":"母親的心意","name":"瑪莎","lines":["你這孩子，越來越像年輕時的你爸了。","這枚戒指你戴著——是我年輕時你爸打的，保平安。","（獲得『活力戒指』！開啟 選單→裝備 可以裝上）"],"action":"give_ring"},
   {"when":"always","cmd":"talk","name":"瑪莎","lines":["你這孩子，越來越像年輕時的你爸了。","路上一定要吃飽穿暖，聽到沒？"]},
 ],
 "gid": [
   # 一次性事件：新客招待（送藥水）；gotPotion 後消失
   {"when":"always","done":"gotPotion","cmd":"gid_gift","label":"新客招待","name":"吉德","lines":["第一次上門吧？來，先送你 2 瓶藥水，別客氣。","補給要趁早，這是老冒險者的鐵則！","（獲得『藥水』×2！）"],"action":"give_potion"},
   # 交易
   {"when":"always","cmd":"trade","label":"交易","name":"吉德","lines":["歡迎光臨！要看看我店裡的商品嗎？"],"action":"shop_gid"},
   # 閒聊
   {"when":"always","cmd":"talk","name":"吉德","lines":["藥水備齊再出門，這是老冒險者的鐵則！","缺什麼儘管開口，我這什麼都有。"]},  # 💠 後備閒聊(待潤)
 ],
 "gray": [
   {"when":"relic==1","name":"老葛雷","lines":["這頂頭盔……是阿吉的！你們在裡頭找到的？","（老葛雷的手抖個不停）……謝謝你們，把他的東西帶了回來。","這是我僅有的一點謝禮，別嫌少。","（獲得 100 金幣）"],"action":"relic_turnin"},
   {"when":"ch2==3","name":"老葛雷","lines":["那些孩子……總算能入土為安了。","你們替這座礦山、也替我這老頭子，了了一樁心事。","剩下的——深處那股邪氣的源頭，就拜託你們了。"]},
   {"when":"ch2==2","name":"老葛雷","lines":["你們臉色不對……在裡頭看到什麼了？","……戴著礦工帽、掄著鎬子的骷髏？那就是我那些老夥計沒錯了。","（老葛雷沉默了好久）謝謝你們告訴我真相。這點心意收下。","聽說深處的落石被你們清開了？那底下的東西，才是禍首。快去回報鎮長吧。"],"action":"ch2_report"},
   {"when":"ch2==1","name":"老葛雷","lines":["礦坑外圍就從鎮北的舊軌道進去。","失蹤的老夥計要是還在……不，你們親眼去看看吧。","（記得先把裝備和藥水在鎮上備齊）"]},
   {"when":"ch1==3","name":"老葛雷","lines":["解決了哥布林？好身手。","那……礦坑的事，能拜託你們嗎？我的老夥計們一個接一個失蹤，","官府當是逃工不管，可我知道——他們絕不會丟下家人跑掉。","【委託】重返北方礦山外圍，查明礦工失蹤的真相。接下嗎？就當你們答應了。"],"action":"ch2_take"},
   {"when":"step==0","name":"老葛雷","lines":["那礦坑二十年前就封了……最近夜裡卻有聲音。","要進去？……跟緊亞倫先生。"]},
   {"when":"always","name":"老葛雷","lines":["那礦坑二十年前就封了……最近夜裡卻有聲音。","你們就是在裡面出事的吧。唉，可憐的亞倫先生。"]},
 ],
 "mira": [
   {"when":"mira2==2","name":"米拉","lines":["那些鏡草夠我熬好一陣子的藥了，真是幫了大忙！","路上也別忘了照顧自己的傷。"]},
   {"when":"herb==3","name":"米拉","lines":["三株鏡草都採齊了？太好了！","來，這些藥水你們拿去——採藥的謝禮。","（獲得『藥水』×3！）"],"action":"mira_reward"},
   {"when":"mira2==1","name":"米拉","lines":["東之森裡三株會發光的『鏡草』，就麻煩你們了。","它們喜歡長在水邊和大石頭旁。"]},
   {"when":"gotEar==0","name":"米拉","lines":["東之森的藥草最近都採不到了……草叢裡老是冒出怪物。","你們要進森林嗎？能不能順手幫我採三株『鏡草』回來？","對了，這耳環是我在森林邊撿到的，先送你們——就當訂金。","（獲得『凝神耳環』！）","（【支線】到東之森採集鏡草×3）"],"action":"mira_start"},
   {"when":"always","name":"米拉","lines":["鏡草要三株才夠熬一鍋藥。","東之森的水邊和大石頭旁比較好找。"]},
 ],
 "guard": [
   {"when":"ch1==3","name":"羅素隊長","lines":["南方大道還在封鎖中。","等王都的指示一到就放行——你們的事蹟我會寫進報告。"]},
   {"when":"always","name":"羅素隊長","lines":["前方道路因魔物騷動封閉中，王都的援軍還沒到。","想去大城的話，再等等吧。"]},
 ],
}
CUTS = {
 "prologue_town": {"once":"c_pro_town","lines":[["瑪琳","路德！聽說你要跟亞倫先生去礦山見習？"],["路德","嗯！我很快就回來——等著聽我的冒險故事吧！"],["亞倫","（在鎮北等著）……準備好了就從北邊出口出發。想先逛逛鎮子也行。"],["","（可以先和鎮民聊聊。準備好了就走北邊出口前往礦山）"]]},
 "mine_intro": {"once":"c_mine_intro","lines":[["亞倫","跟緊我，路德。礦山不是給小孩玩的地方。"],["路德","我、我才不是小孩！我十五歲了！"],["亞倫","……哼。前面的碎石地會竄出魔物，正好給你練練手。"],["","（教學：走進碎石地會遭遇戰鬥。方向鍵移動，往北邊的礦坑口前進）"]]},
 "cave_intro": {"once":"c_cave_intro","lines":[["亞倫","……深處的氣息不對勁。跟在我身後，別亂跑。"],["路德","（好冷……這裡真的只是廢棄礦坑嗎？）"]]},
 "demon_pre":  {"once":"c_demon","lines":[["？？？","（低沉的咆哮迴盪在洞穴深處──）"],["亞倫","趴下！路德──這傢伙不是這裡該有的東西！"],["","（撐過 3 回合！）"],],"battle":"prologue_demon"},
 "demon_post": {"lines":[["亞倫","（擋在路德身前）……快跑！把這裡的事告訴鎮上的人！"],["路德","亞倫大哥──！！"],["","──三天後，芳蕾鎮。"]],"transfer":["Town","home"],"setstep":3},
 "town_start": {"once":"c_town","lines":[["瑪琳","路德！你總算肯出房門了。"],["瑪琳","……亞倫先生的事，不是你的錯。"],["路德","瑪琳。我決定了——我要成為真正的冒險者，查出那天的真相。"],["瑪琳","一個人？想得美。要去，就一起去。"],["","（瑪琳加入了隊伍！先去公會找緹娜登錄吧）"]],"party":["ludo","marin"],"setstep":4},
 "mine_truth": {"once":"c_mine_truth","lines":[
   ["路德","（這裡的空氣……比序章那次更冷了。）"],
   ["瑪琳","路德，那邊有東西在動——是礦工？他們還活著？！"],
   ["路德","不對……瑪琳，退後！牠的臉……牠根本沒有臉！"],
   ["瑪琳","拿著鎬子、戴著礦工帽的骷髏……老葛雷說的失蹤礦工，難道就是……"],
   ["路德","（他們早就死了。是有人……把他們變成了這個樣子。）"],
   ["","（深處的舊礦道被落石半掩，一頭巨影在崩石後低吼——先解決擋路的東西）"]]},
 "mine_after": {"once":"c_mine_after","lines":[
   ["","（洞熊倒下，崩石隨著牠的重量嘩啦鬆開，露出一道向下的黑暗礦道）"],
   ["瑪琳","這股味道……和那天，我們遇上那東西的時候一模一樣。"],
   ["路德","下面有東西。骷髏、洞熊……都是被它從這裡……"],
   ["路德","（亞倫大哥……當年擋在我面前的，是不是也和這底下的東西有關？）"],
   ["","（深處的路開了。先回鎮上把所見告訴老葛雷與鎮長吧）"]]},
}

# ================= 6. 場景 objects 共用 =================
def world_objects(npc_list, extra=None):
    objs=[{"name":"Map","type":"TileMap::TileMap","tags":"","variables":[],"effects":[],"behaviors":[],
           "content":{"tilemapJsonFile":"__TMJ__","tilesetJsonFile":"","tilemapAtlasImage":"atlas.png",
                      "displayMode":"visible","layerIndex":0,"levelIndex":0,"animationSpeedScale":1,"animationFps":4}},
          sprite("Player",char_anims("ludo",True),[{
              "name":"Move","type":"TopDownMovementBehavior::TopDownMovementBehavior",
              "allowDiagonals":True,"acceleration":1200,"deceleration":1500,"maxSpeed":190,
              "angularMaxSpeed":360,"rotateObject":False,"angleOffset":0,
              "ignoreDefaultControls":False,"movementAngleOffset":0,
              "viewpoint":"TopDown","customIsometryAngle":30}]),
          sprite("Tree",[anim("i",["tree.png"],1,False)]),
          sprite("Bush",[anim("i",["bush.png"],1,False)]),
          sprite("Rock",[anim("i",["rock.png"],1,False)]),
          *[sprite(f"FTree{_i}",[anim("i",[f"fst_tree_{_i}.png"],1,False)]) for _i in range(1,7)],  # 森林多樹種(anokolisa)
          sprite("FBush",[anim("i",["fst_deco_bush.png"],1,False)]),      # 以下森林非阻擋地面裝飾
          sprite("FFern",[anim("i",["fst_deco_fern.png"],1,False)]),
          sprite("FMush",[anim("i",["fst_deco_mush.png"],1,False)]),
          sprite("FFlower",[anim("i",["fst_deco_flower.png"],1,False)]),
          sprite("FPebble",[anim("i",["fst_deco_pebble.png"],1,False)]),
          sprite("Fence",[anim("i",["fence.png"],1,False)]),
          sprite("Chest",[anim("closed",["chest_closed.png"],1,False),
                          anim("opened",["chest_opened.png"],1,False)]),
          sprite("Follower",follower_anims()),
          text_obj("HudParty","",20),text_obj("HudGold","",20,"255;225;120"),
          text_obj("HudGoal","",22,"170;230;170"),
          text_obj("Prompt","",24,align="center"),
          sprite("DlgPanel",[anim("i",["panel.png"],1,False)]),
          sprite("DlgFace",face_anims()),
          sprite("DlgArt",portrait_anims()),
          text_obj("DlgName","",26,"255;225;120"),text_obj("DlgText","",28),
          text_obj("Banner","",38,"255;235;140",align="center"),
          sprite("MenuBg",[anim("i",["menubg.png"],1,False)]),
          shapepainter("MenuGfx"),
          sprite("MenuPanel",[anim("i",["panel.png"],1,False)]),
          sprite("RowHi",[anim("i",["rowhi.png"],1,False)]),
          sprite("BarBg",[anim("i",["bar_bg.png"],1,False)]),
          sprite("BarFill",[anim("hp",["bar_hp.png"],1,False),anim("mp",["bar_mp.png"],1,False)]),
          sprite("MenuFace",face_anims()),
          sprite("MenuArt",art_anims()),
          sprite("MenuMap",[anim("i",["region_map.png"],1,False)]),
          text_obj("MenuTitle","",30,"255;225;120"),
          text_obj("MenuTab","",26)]+[
          text_obj(f"MTop{i}","",22) for i in range(7)]+[
          text_obj(f"MRow{i}","",22) for i in range(64)]+[
          text_obj("MenuHint","",20,"170;180;220")]+[
          sprite("JoyBase",[anim("i",["joybase.png"],1,False)]),
          sprite("JoyKnob",[anim("i",["joyknob.png"],1,False)]),
          sprite("BtnA",[anim("i",["btn_a.png"],1,False)]),
          sprite("BtnMenu",[anim("i",["btn_menu.png"],1,False)]),
          sprite("PadU",[anim("i",["pad_u.png"],1,False)]),
          sprite("PadD",[anim("i",["pad_d.png"],1,False)]),
          sprite("PadL",[anim("i",["pad_l.png"],1,False)]),
          sprite("PadR",[anim("i",["pad_r.png"],1,False)]),
          sprite("BtnBack",[anim("i",["btn_back.png"],1,False)]),
          sprite("BtnS1",[anim("i",["btn_s1.png"],1,False)]),
          sprite("BtnS2",[anim("i",["btn_s2.png"],1,False)]),
          sprite("BtnS3",[anim("i",["btn_s3.png"],1,False)])]
    for n in npc_list: objs.append(sprite(n["obj"],char_anims(n["sprite"],n["sprite"] in WALK_SPRITES)))
    for e in (extra or []): objs.append(e)
    return objs

def ui_insts(W=1280):
    rows=[inst(f"MRow{i}",200,176+i*28,9503,0,0,"UI") for i in range(64)]
    rows.append(inst("RowHi",0,0,9501,640,28,"UI"))
    for _ in range(6):
        rows.append(inst("BarBg",0,0,9502,152,14,"UI"))
        rows.append(inst("BarFill",0,0,9503,148,10,"UI"))
    btns=[inst("JoyBase",0,0,9990,140,140,"UI"),inst("JoyKnob",0,0,9991,70,70,"UI"),
          inst("BtnA",1150,585,9992,100,100,"UI"),inst("BtnMenu",1164,489,9992,76,76,"UI"),
          inst("PadU",70,516,9992,80,80,"UI"),inst("PadD",70,608,9992,80,80,"UI"),
          inst("PadL",18,562,9992,80,80,"UI"),inst("PadR",122,562,9992,80,80,"UI"),
          inst("BtnBack",214,610,9992,76,76,"UI"),
          inst("BtnS1",1118,267,9992,66,66,"UI"),inst("BtnS2",1118,339,9992,66,66,"UI"),inst("BtnS3",1118,411,9992,66,66,"UI")]
    return btns+[inst("HudParty",20,12,9999,0,0,"UI"),inst("HudGold",W-380,12,9999,0,0,"UI"),
            inst("HudGoal",20,44,9999,0,0,"UI"),
            inst("Prompt",W//2-150,560,9999,300,0,"UI"),
            inst("DlgPanel",60,540,9000,1160,160,"UI"),
            inst("DlgFace",70,388,9002,144,144,"UI"),
            inst("DlgArt",30,160,8998,300,380,"UI"),
            inst("DlgName",90,556,9001,0,0,"UI"),inst("DlgText",90,596,9001,1100,0,"UI"),
            inst("Banner",240,90,9999,800,0,"UI"),
            inst("MenuBg",0,0,9490,W,720,"UI"),
            inst("MenuGfx",0,0,9500,0,0,"UI"),
            inst("MenuPanel",140,80,9500,1000,520,"UI"),
            inst("MenuTitle",180,100,9501,0,0,"UI"),
            inst("MenuTab",420,104,9501,0,0,"UI"),
            inst("MenuFace",940,150,9502,144,144,"UI"),
            inst("MenuArt",812,112,9502,306,470,"UI"),
            inst("MenuMap",330,180,9502,620,360,"UI"),
            inst("MenuHint",180,556,9501,0,0,"UI")]+[
            inst(f"MTop{i}",20+i*150,14,9501,0,0,"UI") for i in range(7)]+rows

# NPC 定義: (場景, obj名, sprite, id(對話鍵), tile x,y, 面向)
NPCS_TOWN=[
 {"obj":"NTina","sprite":"tina","id":"tina","x":7,"y":9,"face":"Down"},
 {"obj":"NDora","sprite":"dora","id":"dora","x":14,"y":9,"face":"Down"},
 {"obj":"NSister","sprite":"sister","id":"sister","x":29,"y":9,"face":"Down"},
 {"obj":"NBarton","sprite":"barton_use_elder","id":"barton","x":36,"y":9,"face":"Down"},
 {"obj":"NGid","sprite":"gid","id":"gid","x":7,"y":24,"face":"Down"},
 {"obj":"NHank","sprite":"hank","id":"hank","x":14,"y":24,"face":"Down"},
 {"obj":"NMartha","sprite":"martha","id":"martha","x":17,"y":25,"face":"Left"},
 {"obj":"NGray","sprite":"gray","id":"gray","x":17,"y":13,"face":"Right"},
 {"obj":"NMira","sprite":"mira_use_villager","id":"mira","x":32,"y":24,"face":"Down"},
 {"obj":"NGuard","sprite":"guard_reuse","id":"guard","x":21,"y":27,"face":"Down"},
]
# sprite 重用對應
SPR_MAP={"barton_use_elder":"elder","mira_use_villager":"villager","guard_reuse":"guard"}
for n in NPCS_TOWN:
    n["sprite"]=SPR_MAP.get(n["sprite"],n["sprite"])

# Town 連通性 assert：spawn→北出口/森林出口/告示板/戶外 NPC/各建築門口下方接近格 皆可達
# （建築主人 NPC 已搬進室內，戶外只留老葛雷/米拉/羅素隊長）
_OUTDOOR_NPCS={"NGray","NMira","NGuard"}
_town_goals=[("北出口",(21,1)),("森林出口",(40,14)),("告示板前",(10,10))]
for _n in NPCS_TOWN:
    if _n["obj"] in _OUTDOOR_NPCS: _town_goals.append((_n["obj"],(_n["x"],_n["y"])))
for _o,_dx,_dy,_bw in BLDG_LAYOUT: _town_goals.append((_o+"門口下",(_dx,_dy+1)))
assert_reachable(tw,(15,12),_town_goals,"town")

# 地牢氛圍裝飾 prop（OGA [LPC] Dungeon Elements，Sharm，CC-BY）：物件名→檔名
_DUN_PROPS=[("DunSkull","dun_skull"),("DunSkullPile","dun_skullpile"),("DunBones","dun_bones"),("DunWeb","dun_web"),("DunCrack","dun_crack")]

# ================= Track J2：物件擺放式室內（取代單張室內大圖）=================
# 房間外殼(int_room_wood/stone) + 可碰撞家具物件，家具由 art_v12_furniture.py 產。
INT_GEO={"rw":720,"rh":520,"wall":84,"side":18}   # ★對齊 art_v12_furniture.py 的 RW/RH/WALL/SIDE
FURN_OBJ={"FBed":"f_bed","FTable":"f_table","FChair":"f_chair","FStool":"f_stool",
 "FCounter":"f_counter","FShelf":"f_shelf","FGoods":"f_goods","FRug":"f_rug",
 "FHearth":"f_hearth","FForge":"f_forge","FAltar":"f_altar","FAnvil":"f_anvil",
 "FRack":"f_rack","FPlant":"f_plant","FBoard2":"f_board"}   # 室內專屬家具（Barrel/Crate 沿用戶外物件）
# 家具底部碰撞深度(px；None＝可走過的地毯/小盆栽)。碰撞 rect＝底部這麼高、左右內縮 3px。
FURN_FOOT={"FBed":58,"FTable":28,"FChair":18,"FStool":16,"FCounter":32,"FShelf":26,
 "FGoods":26,"FRug":None,"FHearth":30,"FForge":30,"FAltar":30,"FAnvil":24,"FRack":24,
 "FPlant":None,"FBoard2":22,"Barrel":30,"Crate":32}
# 每間室內：shell(wood/stone)、furn[(obj,lx,ly)]（家具左上，room-local px）、owners[(腳底x,y)..]、entry(腳底x,y)
INT_ROOMS={
 "guild":{"shell":"wood","furn":[["FRug",300,346],["FCounter",250,116],["FShelf",34,96],
    ["FBoard2",610,98],["FTable",120,306],["FChair",126,278],["FChair",126,360],
    ["FTable",512,306],["FStool",520,284],["FPlant",664,300]],
    "owners":[[322,150]],"entry":[360,446]},
 "inn":{"shell":"wood","furn":[["FBed",34,100],["FBed",34,178],["FBed",34,256],
    ["FBed",640,100],["FBed",640,178],["FHearth",322,96],
    ["FTable",300,320],["FChair",300,292],["FStool",372,322],
    ["Barrel",600,306],["Crate",648,316]],
    "owners":[[430,320]],"entry":[360,446]},
 "shrine":{"shell":"stone","furn":[["FAltar",324,100],["FRug",300,300],
    ["FChair",150,250],["FChair",150,330],["FChair",544,250],["FChair",544,330],
    ["FPlant",40,110],["FPlant",648,110]],
    "owners":[[360,190]],"entry":[360,446]},
 "mayor":{"shell":"wood","furn":[["FCounter",280,116],["FShelf",34,96],["FShelf",96,96],
    ["FShelf",610,98],["FHearth",560,300],["FChair",504,306],["FRug",250,330],
    ["FTable",150,330],["FChair",150,302],["FPlant",40,300]],
    "owners":[[352,150]],"entry":[360,446]},
 "shop":{"shell":"wood","furn":[["FCounter",255,116],["FGoods",34,96],["FGoods",96,96],
    ["FGoods",610,96],["FGoods",548,96],["Barrel",120,306],["Crate",166,316],
    ["Barrel",560,306],["Crate",606,316],["FRug",300,350],["FPlant",664,300]],
    "owners":[[325,150]],"entry":[360,446]},
 "smithy":{"shell":"stone","furn":[["FForge",322,94],["FAnvil",330,264],
    ["FRack",34,96],["FRack",96,96],["FRack",620,96],
    ["Barrel",600,306],["Crate",646,316],["Crate",120,320],["Barrel",160,306]],
    "owners":[[228,150],[430,150]],"entry":[360,446]},
}

def build_world_scene(name,mapb,tmjname,npcs,cfg,default_spawn):
    sc=scene(name)
    npc_objs=[{"obj":n["obj"],"sprite":n["sprite"]} for n in npcs]
    extra=[]
    if name=="Town":
        # 45° 斜角外觀（ext_*.png，customSize 由 instance 縮放）
        for _bo in ["BGuild","BInn","BShrine","BMayor","BShop","BSmith"]:
            extra.append(sprite(_bo,[anim("i",[BLDG_EXTF[_bo]],1,False)]))
        # 室內折衷方案：單一 Interior 物件、6 個手繪大圖動畫（intc_<key>），進哪棟切哪張；碰撞走隱形 st.furn
        extra.append(sprite("Interior",[anim(BLDG_KEY[_bo],["intc_"+BLDG_KEY[_bo]+".png"],1,False)
                     for _bo in ["BGuild","BInn","BShrine","BMayor","BShop","BSmith"]]))
        # 立繪＋選單式室內：大型前景立繪（先做緹娜）＋指令標籤（描邊字）
        extra.append(sprite("IntArt",[anim(_o,[f"portrait_{_o}.png"],1,False) for _o in ["tina","dora","sister","barton","gid","hank"]]))  # 各棟 owner 立繪（與對話 DlgArt 共用 portrait_）
        extra.append(sprite("IntCmdBg",[anim("i",["panel.png"],1,False)]))   # 指令選單半透明底板
        for _ci in range(6): extra.append(text_obj(f"IntCmd{_ci}","",30))     # 動態指令列（最多 6）
        extra.append(sprite("Well",[anim("i",["well.png"],1,False)]))
        extra.append(sprite("Board",[anim("i",["board.png"],1,False)]))
        for _dn,_fn in [("Barrel","barrel"),("Crate","crate"),("Lamp","lamp"),
                        ("Flowerbed","flowerbed"),("Stall","stall"),("Laundry","laundry")]:
            extra.append(sprite(_dn,[anim("i",[_fn+".png"],1,False)]))
        extra.append(sprite("Hen",[anim("i",["hen_0.png","hen_1.png"],0.35,True)]))  # 巡走小動物
    if name=="Mine":
        extra.append(sprite("CaveMouth",[anim("i",["cavemouth.png"],1,False)]))
        extra.append(sprite("Support",[anim("i",["support.png"],1,False)]))
        extra.append(sprite("StalGold",[anim("i",["stal_gold.png"],1,False)]))
        extra.append(sprite("StalBrown",[anim("i",["stal_brown.png"],1,False)]))
        extra.append(sprite("BearMark",[anim("i",["foe_bear_0.png"],1,False)]))   # 章末狂暴洞熊地圖圖示（ch2==1 顯示）
        extra.append(sprite("RelicHelmet",[anim("i",["helmet.png"],1,False)]))     # 支線B：阿吉的頭盔
        for _dn,_df in _DUN_PROPS:
            extra.append(sprite(_dn,[anim("i",[_df+".png"],1,False)]))              # 地牢氛圍裝飾（OGA LPC）
    if name=="Cave":
        extra.append(sprite("Rubble",[anim("i",["rubble.png"],1,False)]))
        extra.append(sprite("StalBrown",[anim("i",["stal_brown.png"],1,False)]))
        extra.append(sprite("StalBlack",[anim("i",["stal_black.png"],1,False)]))
        for _dn,_df in _DUN_PROPS:
            extra.append(sprite(_dn,[anim("i",[_df+".png"],1,False)]))
    if name=="Forest2":
        extra.append(sprite("BossMark",[anim("i",["foe_maskedorc_0.png"],1,False)]))
    if name=="Forest":
        for _h in ["Herb1","Herb2","Herb3"]:
            extra.append(sprite(_h,[anim("i",["herb.png"],1,False)]))               # 支線A：鏡草
    sc["objects"]=world_objects(npc_objs,extra)
    B,E=mapb.strs()
    insts=[inst("Map",0,0,0)]
    for pn,px,py in mapb.props:
        if name=="Town" and pn in BLDG_SIZE:                 # 建築帶 customSize 縮放
            _bw,_bh=BLDG_SIZE[pn]; insts.append(inst(pn,px,py,5,_bw,_bh))
        else: insts.append(inst(pn,px,py,5))
    if name=="Town":
        for _hx,_hy in [(13,26),(34,24),(7,27)]: insts.append(inst("Hen",_hx*TS+7,_hy*TS+8,5))
        insts.append(inst("Interior",0,0,1,585,440))         # 室內手繪大圖（init 隱藏，進屋時定位/縮放）
        insts.append(inst("IntArt",0,0,50))                  # 立繪前景（進屋時定位/縮放）
        insts.append(inst("IntCmdBg",96,440,9994,300,180,"UI"))   # 指令選單底板（進場時定位/縮放）
        for _ci in range(6): insts.append(inst(f"IntCmd{_ci}",130,456+_ci*46,9995,0,0,"UI"))  # 動態指令列
    for n in npcs: insts.append(inst(n["obj"],n["x"]*TS,n["y"]*TS-16,5))
    if name=="Forest2":
        insts.append(inst("BossMark",(FW-6)*TS,FEY*TS-28,5,64,80))
    if name=="Cave":
        insts.append(inst("Rubble",16*TS,1*TS,5,192,112))
    if name=="Mine":
        insts.append(inst("BearMark",21*TS,8*TS-28,5,64,80))
        insts.append(inst("RelicHelmet",RELIC_TILE[0]*TS,RELIC_TILE[1]*TS,5))
    if name=="Forest":
        for _hi,_ht in enumerate(HERB_TILES):
            insts.append(inst("Herb%d"%(_hi+1),_ht[0]*TS,_ht[1]*TS,5))
    # 地圖寶箱：32x32 貼滿一格、底對格底（px/py=0）；cidx=在本場景 chests 陣列的索引，runtime 用來對應資料
    _MAPKEY={"Forest":"forest","Forest2":"forest2","Mine":"mine","Cave":"cave"}
    scene_chests=CHEST_BY_MAP.get(_MAPKEY.get(name,""),[])
    for _ci,_ch in enumerate(scene_chests):
        insts.append(inst("Chest",_ch["tx"]*TS,_ch["ty"]*TS,5,0,0,"",{"cidx":_ci}))
    insts.append(inst("Player",*default_spawn,5))
    for _ in range(3): insts.append(inst("Follower",default_spawn[0],default_spawn[1],5))
    insts+=ui_insts()
    sc["instances"]=insts
    cfg2=dict(cfg); cfg2.update({"SCENE":name,"MW":mapb.MW,"MH":mapb.MH,"BLK":B,"ENC":E,
        "chests":[{"id":c["id"],"tx":c["tx"],"ty":c["ty"],"tier":c["tier"],"loot":c["loot"]} for c in scene_chests]})
    js=WORLD_JS.replace("__CFG__",json.dumps(cfg2,ensure_ascii=False))
    sc["events"]=[jsev(js)]
    # tilemap 檔名
    sc["objects"][0]["content"]["tilemapJsonFile"]=tmjname+".tmj"
    _MAP_ATLAS={"Forest":"atlas_forest.png","Forest2":"atlas_forest.png","Town":"atlas_town.png"}
    if name in _MAP_ATLAS:                                  # 這些地圖用 anokolisa 專屬地面（其餘續用 atlas.png）
        sc["objects"][0]["content"]["tilemapAtlasImage"]=_MAP_ATLAS[name]
    return sc

# ================= 7. World 引擎 JS =================
WORLD_JS = r"""
var rs = runtimeScene;
var CFG = __CFG__;
var DLG = __DLG__;
var CUTS = __CUTS__;
var CONTENT = __CONTENT__;
var C_DERIVED = CONTENT.derived;
var g = rs.getGame().getVariables();
var TS = 32;
function one(n){var a=rs.getObjects(n);return a.length?a[0]:null;}
function sfx(n){gdjs.evtTools.sound.playSound(rs,n,false,100,1);}
function J(name,defv){var s=g.get(name).getAsString(); if(!s)return defv; try{return JSON.parse(s);}catch(e){return defv;}}
function setJ(name,v){g.get(name).setString(JSON.stringify(v));}
function flags(){return J("g_flags",{step:0,reg:0,ch1:0});}
// 共用旗標條件比對："always" / "旗標==數字" / "旗標>=數字"（未定義旗標視為 0）
function matchWhen(f,w){
  if(!w||w==="always")return true;
  var m=(""+w).match(/^(\w+)(==|>=)(\d+)$/); if(!m)return false;
  var v=f[m[1]]||0,n=parseInt(m[3]); return (m[2]==="==")?(v===n):(v>=n);
}
// ---------- 存檔（localStorage；Track G）----------
var SAVE_KEY="cq_save";
function saveGame(){
  try{
    if(!window.localStorage)return;
    var sv=rs.__v||{}; var pl=one("Player"); var sx=-1,sy=-1;
    if(sv.inside&&sv.curDoor){ sx=sv.curDoor.tx*TS; sy=(sv.curDoor.ty+1)*TS; }  // 室內存門口外，重載不卡牆
    else if(pl){ sx=Math.round(pl.getX()); sy=Math.round(pl.getY()); }
    var s={v:1,scene:CFG.SCENE,x:sx,y:sy,
      flags:g.get("g_flags").getAsString(),party:g.get("g_party").getAsString(),
      eqInv:g.get("g_eqInv").getAsString(),itemInv:g.get("g_itemInv").getAsString(),
      gold:g.get("g_gold").getAsNumber(),chests:g.get("g_chests").getAsString(),
      auto:g.get("g_autoBattle").getAsNumber()};
    window.localStorage.setItem(SAVE_KEY,JSON.stringify(s));
  }catch(e){}
}
function party(){return J("g_party",[]);}
// ---------- 多道具背包 g_itemInv（id→數量 JSON） ----------
function invAll(){return J("g_itemInv",{});}
function invGet(id){var v=invAll();return v[id]||0;}
function invAdd(id,n){var v=invAll();v[id]=(v[id]||0)+n;if(v[id]<0)v[id]=0;setJ("g_itemInv",v);}
function invUse(id){invAdd(id,-1);}
// 開啟商店：預吃一輪按鍵邊緣，避免關對話的同一按鍵誤觸商店
function openShop(id){var st=rs.__v;st.shop={id:id,tab:0,sel:0,msg:""};st.menu=false;
  st.kp=st.kp||{};["Return","Space","Escape","Up","Down","Left","Right"].forEach(function(k){st.kp[k]=true;});
  sfx("menu.mp3");}
function boardLines(){
  var f=flags();var mp=CONTENT.pacing.maps;var body,lv,tip;
  if((f.step||0)<3){ body="序章見習──隨亞倫前往礦山"; lv=mp.tutorial.entryLv; tip="初次冒險，量力而為。"; }
  else if(!f.reg){ body="本鎮徵求冒險者，請至公會登錄（找緹娜）"; lv=mp.forest.entryLv; tip="登錄後方可承接委託。"; }
  else if((f.ch1||0)===0){ body="東之森哥布林為患，公會備有討伐委託（詢問緹娜）"; lv=mp.forest.entryLv; tip="出發前先備妥藥水。"; }
  else if(f.ch1===1){ body="【承接中】討伐東之森深處的哥布林頭目"; lv=mp.forest2.targetLv; tip="頭目強悍，建議先練級並更新裝備。"; }
  else if(f.ch1===2){ body="【待結案】頭目已討伐──回公會向緹娜回報"; lv=mp.forest2.targetLv; tip="別忘了領取 200G 報酬。"; }
  else { body="目前無公開委託。感謝各位冒險者的辛勞。"; lv=mp.cave.targetLv; tip="第二章敬請期待。"; }
  return ["── 芳蕾鎮 · 冒險者告示板 ──","委託："+body,"建議等級：Lv"+lv+" 以上　｜　"+tip];
}
var EQ={};
for(var i=0;i<(CONTENT.equipment||[]).length;i++)EQ[CONTENT.equipment[i].id]=CONTENT.equipment[i];
var ITEM={};
for(var i=0;i<(CONTENT.items||[]).length;i++)ITEM[CONTENT.items[i].id]=CONTENT.items[i];
var CATN={consumable:"消耗",material:"素材",key:"重要"};
// 統一取得任一 id 的商店中繼資料（道具或裝備）
function itemMeta(id){
  if(ITEM[id])return {id:id,name:ITEM[id].name,buy:ITEM[id].buy||0,sell:ITEM[id].sell||0,
    cat:ITEM[id].cat,kind:"item",tier:ITEM[id].tier,label:CATN[ITEM[id].cat]||"道具",desc:ITEM[id].effect||""};
  if(EQ[id])return {id:id,name:EQ[id].name,buy:EQ[id].buy||0,sell:EQ[id].sell||0,
    slot:EQ[id].slot,kind:"eq",tier:EQ[id].tier,label:SLOTN[EQ[id].slot]||"裝備",desc:eqDesc(EQ[id])};
  return null;
}
function eqStat(m,k){var t=0;if(m.eq){for(var s in m.eq){var e=EQ[m.eq[s]];if(e&&e[k])t+=e[k];}}return t;}
function expNeed(lv){var d=CONTENT.derived;return d.expBase+Math.round(d.expCoef*Math.pow(lv,d.expPow));}
function derive(m){
  var d=CONTENT.derived;
  if(m.eq===undefined){m.eq={};
    for(var i=0;i<CONTENT.party.length;i++){var t=CONTENT.party[i];
      if(t.id===m.id&&t.startEq){for(var s in t.startEq)m.eq[s]=t.startEq[s];}}}
  m.maxhp=d.hpBase+m.attrs.str*d.hpPerStr+eqStat(m,"hp");
  m.maxmp=d.mpBase+m.attrs.int*d.mpPerInt+eqStat(m,"mp");
  m.patk=d.weaponAtk+m.attrs[m.mainAttr]*2+eqStat(m,"patk");
  m.matk=Math.round(m.attrs.int*d.matkPerInt)+eqStat(m,"matk");
  m.pdef=m.attrs.str+eqStat(m,"pdef");
  m.mdef=Math.round(m.attrs.int*d.mdefPerInt)+eqStat(m,"mdef");
  m.dodgeV=Math.round(m.attrs.agi*d.dodgePerAgi)+eqStat(m,"dodge");
  m.critV=Math.round((d.critBase+m.attrs.agi*d.critPerAgi+eqStat(m,"crit"))*10)/10;
  m.spd=m.attrs.agi;
  // ===== 真實系統：幸運 / 武器熟練度 / 屬性加護 / 特別加護 =====
  var _def=null,_si;for(_si=0;_si<CONTENT.party.length;_si++){if(CONTENT.party[_si].id===m.id){_def=CONTENT.party[_si];break;}}
  var _bl=(m.blessing&&(CONTENT.blessings||{})[m.blessing])||null;
  var _lb=(_def&&_def.base&&_def.base.luck)||0,_lg=(_def&&_def.growth&&_def.growth.luck)||0;
  m.luck=_lb+Math.floor(((m.lv||1)-1)*_lg)+eqStat(m,"luck")+((_bl&&_bl.stats&&_bl.stats.luck)||0);
  if(!m.prof)m.prof={};
  var _wid=m.eq&&m.eq.weapon;m.wtype=(_wid&&EQ[_wid]&&EQ[_wid].wtype)||null;
  if(m.wtype)m.patk+=Math.floor((m.prof[m.wtype]||0)*(d.profAtkPer||0));
  if(_bl&&_bl.stats){var _s=_bl.stats;
    m.patk+=_s.patk||0;m.matk+=_s.matk||0;m.pdef+=_s.pdef||0;m.mdef+=_s.mdef||0;
    m.dodgeV+=_s.dodge||0;m.critV+=_s.crit||0;m.maxhp+=_s.hp||0;m.maxmp+=_s.mp||0;}
  var _EL=["earth","fire","wind","water","ice","thunder","light","dark"];
  m.elem={};for(_si=0;_si<_EL.length;_si++){var _ek=_EL[_si];
    m.elem[_ek]=((_def&&_def.elem&&_def.elem[_ek])||0)+eqStat(m,"el_"+_ek)+((_bl&&_bl.elem&&_bl.elem[_ek])||0);}
  m.critV=Math.round((m.critV+m.luck*(d.critPerLuck||0))*10)/10;
  if(m.hp===undefined||m.hp>m.maxhp)m.hp=m.maxhp;
  if(m.mp===undefined||m.mp>m.maxmp)m.mp=m.maxmp;
  if(!m.sk){m.sk={};for(var i=0;i<CONTENT.skills.length;i++){var s=CONTENT.skills[i];
    if(s["class"]===m.cls&&m.lv>=s.unlockLv)m.sk[s.id]=1;}}
  if(m.spts===undefined)m.spts=0;
  return m;
}
function skillList(m){
  var out=[];
  for(var i=0;i<CONTENT.skills.length;i++){var s=CONTENT.skills[i];
    if(m.sk&&m.sk[s.id])out.push(s);}
  return out;
}
function clsName(m){return {explorer:"探索者",veteran:"A級冒險者"}[m.cls]||m.cls;}
function mkMember(id){
  var t=null; for(var i=0;i<CONTENT.party.length;i++){if(CONTENT.party[i].id===id)t=CONTENT.party[i];}
  var m={id:id,name:t.name,cls:t["class"],mainAttr:t.mainAttr,sprite:t.sprite,guest:!!t.guest,
         lv:t.startLevel||1,exp:0,pts:0,spts:0,attrs:{str:t.base.str,agi:t.base.agi,int:t.base.int}};
  return derive(m);
}
var FACE={"路德":"ludo","瑪琳":"marin","亞倫":"aaron",
  "緹娜":"tina","朵拉":"dora","希雅修女":"sister","巴頓鎮長":"barton","吉德":"gid",
  "漢克":"hank","瑪莎":"martha","老葛雷":"gray","米拉":"mira","羅素隊長":"guard"};
function setFace(nm){
  var fo=one("DlgFace"); if(fo)fo.hide(true);                        // 舊 144 小頭像框停用（改用大型去背立繪）
  var ar=one("DlgArt"); if(!ar)return;
  var _st=rs.__v;
  if(_st&&_st.inside&&_st.intMode==="menu"){ar.hide(true);return;}   // 立繪＋選單式室內：已有 IntArt 大立繪
  var a=FACE[nm];
  if(!a){ar.hide(true);return;}                                     // 無對應立繪（旁白等）→ 不顯示
  ar.setAnimationName(a); if(ar.setScale)ar.setScale(1);            // 先重置原生尺寸，再依高度縮放（比例正確）
  var H=380, nR=ar.getWidth()/ar.getHeight(), W=Math.round(H*nR);
  if(W>470){W=470;H=Math.round(W/nR);}                              // 寬服裝角色（拖擺長袍）限寬
  ar.setWidth(W); ar.setHeight(H); ar.setX(14); ar.setY(540-H); ar.hide(false);   // 貼近左緣（間距減半）
}
function healAll(){var ps=party();for(var i=0;i<ps.length;i++){derive(ps[i]);ps[i].hp=ps[i].maxhp;ps[i].mp=ps[i].maxmp;}setJ("g_party",ps);}
function blocked(px,py){
  var tx=Math.floor(px/TS),ty=Math.floor(py/TS);
  if(tx<0||ty<0||tx>=CFG.MW||ty>=CFG.MH)return true;
  return CFG.BLK[ty].charAt(tx)==="1";
}
function inEnc(px,py){
  var tx=Math.floor(px/TS),ty=Math.floor(py/TS);
  if(tx<0||ty<0||tx>=CFG.MW||ty>=CFG.MH)return false;
  return CFG.ENC[ty].charAt(tx)==="1";
}
function feet(o){return [o.getX()+o.getWidth()/2,o.getY()+o.getHeight()*0.85];}
function baseZ(o){return Math.round(o.getY()+o.getHeight());}

if(!rs.__v){
  rs.__v={dlg:null,dlgIdx:0,sp:false,enc:0,encNext:600+Math.random()*800,grace:1.2,cut:null,cutIdx:0,queue:[]};
  rs.__bgmT=0;
  var st0=rs.__v;
  ["Tree","FTree1","FTree2","FTree3","FTree4","FTree5","FTree6","FBush","FFern","FMush","FFlower","FPebble","Bush","Rock","Fence","Well","BGuild","BInn","BShrine","BMayor","BShop","BSmith","Board","Barrel","Crate","Lamp","Flowerbed","Stall","Laundry","CaveMouth","Support","Rubble","BossMark","BearMark","StalGold","StalBrown","StalBlack","Herb1","Herb2","Herb3","RelicHelmet","DunSkull","DunSkullPile","DunBones","DunWeb","DunCrack"]
    .forEach(function(n){rs.getObjects(n).forEach(function(o){o.setZOrder(baseZ(o));});});
  st0.npcHome={}; st0.npcw=[];
  CFG.npcs.forEach(function(n){var o=one(n.obj);if(o){o.setAnimationName("Idle"+(n.face||"Down"));o.setZOrder(baseZ(o));st0.npcHome[n.obj]=[o.getX(),o.getY()];
    if(isOutdoorNpc(n.obj))st0.npcw.push({o:o,hx:o.getX(),hy:o.getY(),tx:o.getX(),ty:o.getY(),wait:Math.random()*2.5,face:n.face||"Down"});}});
  // Track J：室內初始隱藏；有 doors 的場景（Town）室外只顯示戶外 NPC（主人平時在室內）
  st0.inside=null;
  var iv0=one("Interior"); if(iv0)iv0.hide(true);
  ["IntArt","IntCmdBg","IntCmd0","IntCmd1","IntCmd2","IntCmd3","IntCmd4","IntCmd5"].forEach(function(n){var o=one(n);if(o)o.hide(true);});
  if(CFG.doors){
    CFG.npcs.forEach(function(n){var o=one(n.obj);if(!o)return;
      var out=false;for(var oi=0;oi<CFG.outdoorNpcs.length;oi++)if(CFG.outdoorNpcs[oi]===n.obj)out=true;
      if(!out)o.hide(true);});
  }
  st0.hens=[];
  rs.getObjects("Hen").forEach(function(o){st0.hens.push({o:o,hx:o.getX(),hy:o.getY(),tx:o.getX(),ty:o.getY(),wait:Math.random()*2});o.setZOrder(baseZ(o));});
  // 地圖寶箱：以 cidx 對應 CFG.chests；已開者（g_chests 內）套 opened 動畫、不再給獎。持久化重進不重複。
  st0.chests=[];
  var _openedSet=J("g_chests",[]);
  rs.getObjects("Chest").forEach(function(o){
    var _ci=o.getVariables().get("cidx").getAsNumber();
    var _cd=(CFG.chests||[])[_ci]; if(!_cd)return;
    var _op=false; for(var _k=0;_k<_openedSet.length;_k++)if(_openedSet[_k]===_cd.id)_op=true;
    o.setAnimationName(_op?"opened":"closed"); o.setZOrder(baseZ(o));
    st0.chests.push({o:o,d:_cd,opened:_op});
  });
  var hideL=["DlgPanel","DlgFace","DlgArt","DlgName","DlgText","Prompt","Banner","MenuPanel","MenuFace","MenuArt","MenuMap","MenuTab","MenuTitle","MenuHint"];
  for(var hi=0;hi<20;hi++)hideL.push("MRow"+hi);
  hideL.forEach(function(n){var o=one(n);if(o)o.hide(true);});
  ["RowHi","BarBg","BarFill"].forEach(function(n){rs.getObjects(n).forEach(function(o){o.hide(true);});});
  rs.getObjects("Follower").forEach(function(o){o.hide(true);});
  var f=flags();
  // 出生點
  var p0=one("Player");
  var res=g.get("g_result").getAsString();
  if(res==="win"||res==="flee"||res==="story"||res==="resume"){
    if(g.get("g_returnX").getAsNumber()>=0&&p0){p0.setX(g.get("g_returnX").getAsNumber());p0.setY(g.get("g_returnY").getAsNumber());}
  } else {
    var spn=g.get("g_spawn").getAsString();
    if(spn&&CFG.spawns&&CFG.spawns[spn]&&p0){p0.setX(CFG.spawns[spn][0]);p0.setY(CFG.spawns[spn][1]);}
  }
  g.get("g_spawn").setString("");
  // 戰後劇情推進：序章魔影戰結束
  if(res==="story"&&CFG.SCENE==="Cave"){ st0.queue.push("demon_post"); }
  // 章末：擊退狂暴洞熊回到礦山→落石鬆動過場（一次性）
  if(res==="win"&&CFG.SCENE==="Mine"){var fma=flags();if(fma.ch2===2&&!fma.c_mine_after){st0.queue.push("mine_after");}}
  if(res==="lose"){ healAll(); st0.queue.push("__lose__"); }
  g.get("g_result").setString("");
  // 場景進場劇情
  if(CFG.cutOnEnter){
    for(var i=0;i<CFG.cutOnEnter.length;i++){
      var c=CFG.cutOnEnter[i]; var cc=CUTS[c.cut]; var f2=flags();
      var okStep=(c.step===undefined)||(f2.step===c.step);
      var done=cc.once&&f2[cc.once];
      if(okStep&&!done){ st0.queue.push(c.cut); }
    }
  }
  if(p0)st0.last=[p0.getX(),p0.getY()];
  // 魔王記號顯示條件
  var bm=one("BossMark");
  if(bm){ var f3=flags(); bm.hide(!(f3.ch1===1)); }
  var brm=one("BearMark");
  if(brm){ brm.hide(!(flags().ch2===1)); }
  saveGame();   // 進場自動存檔（涵蓋地圖切換/戰後返回/升級）
}
var st=rs.__v;
var dt=rs.getElapsedTime()/1000;
// 鎮上小動物：以自家為圓心的小範圍隨機漫步（純視覺，不碰撞、不擋路）
if(st.hens){for(var _hi=0;_hi<st.hens.length;_hi++){var H=st.hens[_hi];
  H.wait-=dt;
  if(H.wait<=0){var _a=Math.random()*6.283,_r=10+Math.random()*38;H.tx=H.hx+Math.cos(_a)*_r;H.ty=H.hy+Math.sin(_a)*_r;H.wait=1.0+Math.random()*2.5;}
  var _ox=H.o.getX(),_oy=H.o.getY(),_dx=H.tx-_ox,_dy=H.ty-_oy,_d=Math.sqrt(_dx*_dx+_dy*_dy);
  if(_d>0.8){var _mv=Math.min(20*dt,_d);H.o.setX(_ox+_dx/_d*_mv);H.o.setY(_oy+_dy/_d*_mv);H.o.setZOrder(baseZ(H.o));}
}}
// 戶外 NPC 在住家附近小範圍隨機遊走（純視覺、不擋路、不吃碰撞外；對話/選單/室內時停住，方便互動）
if(st.npcw&&!st.dlg&&!st.cut&&!st.menu&&!st.shop&&!st.inside){
  var _NDIR=[[0,-1,"Up"],[0,1,"Down"],[-1,0,"Left"],[1,0,"Right"]];   // 上下左右四方向
  for(var _ni=0;_ni<st.npcw.length;_ni++){var N=st.npcw[_ni];
    N.wait-=dt;
    if(N.wait<=0){
      // 隨機挑一個四方向、只沿該軸直線走一小段（不斜走）；夾在住家半徑內避免越走越遠
      var _d=_NDIR[Math.floor(Math.random()*4)],_len=16+Math.random()*40,R=54;
      var _tx=Math.max(N.hx-R,Math.min(N.hx+R,N.o.getX()+_d[0]*_len));
      var _ty=Math.max(N.hy-R,Math.min(N.hy+R,N.o.getY()+_d[1]*_len));
      N.tx=_tx;N.ty=_ty;N.dstep=_d;N.wait=1.2+Math.random()*3.2;
    }
    var _d2=N.dstep,_ox2=N.o.getX(),_oy2=N.o.getY();
    // 只沿選定單軸移動；殘距＝該軸差（另一軸恆為 0）
    var _rem=_d2?(_d2[0]?Math.abs(N.tx-_ox2):Math.abs(N.ty-_oy2)):0;
    if(_d2&&_rem>1.5){var _nmv=Math.min(26*dt,_rem),_nx=_ox2+_d2[0]*_nmv,_ny=_oy2+_d2[1]*_nmv;
      if(!blocked(_nx+N.o.getWidth()/2,_ny+N.o.getHeight()*0.85)){
        N.o.setX(_nx);N.o.setY(_ny);N.o.setAnimationName("Walk"+_d2[2]);}
      else N.wait=0.3;
      N.o.setZOrder(baseZ(N.o));
    } else N.o.setAnimationName("Idle"+N.face);
  }
}
// BGM：首幀試播一次；瀏覽器自動播放被擋時，偵測到第一次互動後再接上
function ensureBgm(file){
  if(!window.__auHook){window.__auHook=1;window.__audioUnlocked=0;
    ["pointerdown","keydown","touchstart"].forEach(function(ev){
      document.addEventListener(ev,function(){window.__audioUnlocked=1;},{once:true,capture:true});});}
  if(rs.__bgmT===undefined)rs.__bgmT=-1;
  rs.__bgmT++;
  var first=(rs.__bgmT===0);
  if(!first&&(!window.__audioUnlocked||rs.__bgmT%45!==0))return;
  var mu=rs.getGame().getSoundManager().getMusicOnChannel(1);
  if(!mu||!mu.playing())gdjs.evtTools.sound.playMusicOnChannel(rs,file,1,true,65,1);
}
if(CFG.bgm)ensureBgm(CFG.bgm);
var p=one("Player"); if(!p)return;
var b=p.getBehavior("Move");
if(st.grace>0)st.grace-=dt;
var f=flags();
// ===== Track J：進屋機制（同場景就地室內切換） =====
var OUTDOOR_HIDE=["Tree","FTree1","FTree2","FTree3","FTree4","FTree5","FTree6","FBush","FFern","FMush","FFlower","FPebble","Bush","Rock","Fence","Well","BGuild","BInn","BShrine","BMayor","BShop","BSmith","Board","Barrel","Crate","Lamp","Flowerbed","Stall","Laundry","Hen"];
function setOutdoorHidden(h){
  var m=one("Map"); if(m)m.hide(h);
  for(var oi=0;oi<OUTDOOR_HIDE.length;oi++){rs.getObjects(OUTDOOR_HIDE[oi]).forEach(function(o){o.hide(h);});}
}
function isOutdoorNpc(obj){for(var i=0;i<((CFG.outdoorNpcs)||[]).length;i++)if(CFG.outdoorNpcs[i]===obj)return true;return false;}
function npcFace(obj){for(var i=0;i<CFG.npcs.length;i++){if(CFG.npcs[i].obj===obj)return CFG.npcs[i].face||"Down";}return "Down";}
function npcId(obj){for(var i=0;i<CFG.npcs.length;i++){if(CFG.npcs[i].obj===obj)return CFG.npcs[i].id;}return "";}
// 播某角色「指定 cmd」的第一個符合 when 的對話條目（cmd 預設 talk）
function openOwnerCmd(id,cmd){var defs=DLG[id]||[],f=flags();cmd=cmd||"talk";
  for(var i=0;i<defs.length;i++){var e=defs[i];if((e.cmd||"talk")!==cmd)continue;
    if(matchWhen(f,e.when)){st.dlg={name:e.name,lines:e.lines,action:e.action};st.dlgIdx=0;sfx("select.wav");return true;}}
  return false;}
// 立繪＋選單式室內：大型前景立繪定位（原生尺寸→依房高縮放→錨右下），供進場與交談切換說話者共用
function setIntArt(id){var art=one("IntArt"),b=st.intBox;if(!art||!b)return;
  try{art.setAnimationName(id);}catch(e){}
  if(art.setScale)art.setScale(1);
  var nR=art.getWidth()/art.getHeight(),aH=Math.round(b.dH*0.82),aW=Math.round(aH*nR);
  art.setWidth(aW);art.setHeight(aH);art.setX(b.RX+b.dW-aW+Math.round(b.dW*0.02));art.setY(b.RY+b.dH-aH);art.setZOrder(50);art.hide(false);}
// 依 owner(s) 的 DLG 掃出室內動態指令清單：交談 ＋ 功能(唯一) ＋ 符合條件的一次性事件 ＋ 離開
function buildIntCmds(){var f=flags(),owners=st.ownerAll||[],cmds=[{cmd:"talk",label:"交談"}],func={};
  for(var oi=0;oi<owners.length;oi++){var oid=owners[oi],defs=DLG[oid]||[];
    for(var i=0;i<defs.length;i++){var e=defs[i],k=e.cmd||"talk";
      if(k==="talk")continue;
      if(k==="trade"||k==="quest"||k==="rest"||k==="pray"){if(!func[k]){func[k]=1;cmds.push({cmd:k,label:e.label||k,who:oid});}}
      else if(matchWhen(f,e.when)&&!(e.done&&f[e.done])){cmds.push({cmd:k,label:e.label||"？",who:oid});}  // 一次性事件：符合且未完成才出現
    }}
  cmds.push({cmd:"leave",label:"離開"});st.intCmds=cmds;if(!(st.intCmd<cmds.length))st.intCmd=0;}
// 執行選單指令
function runIntCmd(c){if(!c)return;
  if(c.cmd==="leave"){exitBuilding();return;}
  if(c.cmd==="talk"){st.talkKind="talk";st.talkRest=(st.ownerAll||[]).slice(1);setIntArt(st.owner);openOwnerCmd(st.owner,"talk");return;}
  st.talkKind=c.cmd;st.talkRest=[];setIntArt(c.who||st.owner);openOwnerCmd(c.who||st.owner,c.cmd);}  // trade/rest/pray/quest/事件：跑對應條目，動作於對話結尾觸發
function enterBuilding(door){
  st.inside=door.obj; st.curDoor=door;
  setOutdoorHidden(true);
  CFG.npcs.forEach(function(n){var o=one(n.obj);if(o)o.hide(true);});
  rs.getObjects("Follower").forEach(function(o){o.hide(true);});
  var key=door.key, nat=CFG.intNat[key]||[1118,839];
  var cfgR=CFG.intDrawn[key]||CFG.intDrawnDefault;
  var cx=CFG.MW*TS/2, cy=CFG.MH*TS/2;
  var dH=700, dW=Math.round(dH*nat[0]/nat[1]);          // 顯示尺寸（維持原生長寬比）
  var RX=Math.round(cx-dW/2), RY=Math.round(cy-dH/2);
  st.intCam=[cx,cy]; st.intZoom=Math.min(1280/dW,720/dH)*0.96;   // 房間填滿螢幕
  st.intBox={RX:RX,RY:RY,dW:dW,dH:dH};   // 供 setIntArt 依房間框定位立繪
  var iv=one("Interior");
  if(iv){iv.hide(false);iv.setAnimationName(key);iv.setWidth(dW);iv.setHeight(dH);iv.setX(RX);iv.setY(RY);iv.setZOrder(1);}
  function fx(v){return RX+v*dW;} function fy(v){return RY+v*dH;}
  var art=one("IntArt");
  if(cfgR.mode==="menu"){
    // === 立繪＋選單式（不走動）：手繪背景＋大型立繪前景＋指令選單 ===
    st.intMode="menu"; st.intCmd=0; st.intJustEntered=true; st.room=null; st.furn=[]; st.furnObjs=[];
    st.kp=st.kp||{}; st.kp.Space=true; st.kp.Return=true;   // 把進門那次（可能被壓住數幀）的 Space 標成已按下，避免一進門就誤觸「交談」
    p.hide(true);
    var oid=(door.owners&&door.owners[0])?npcId(door.owners[0]):""; st.owner=oid;
    st.ownerAll=(door.owners||[]).map(function(o){return npcId(o);});   // 全部 owner id（多 owner 棟依序談）
    setIntArt(oid);      // 進場立繪＝第一位 owner
    buildIntCmds();      // 依 owner(s) 與進度建動態指令清單
    st.last=[p.getX(),p.getY()]; sfx("select.wav"); return;
  }
  // === walk 模式（其餘棟）：手繪背景＋隱形碰撞，可走動 ===
  st.intMode="walk"; if(art)art.hide(true); p.hide(false);
  var rm=cfgR.room, ex=cfgR.exit;
  st.room={l:fx(rm[0]),t:fy(rm[1]),r:fx(rm[2]),b:fy(rm[3]),exL:fx(ex[0]),exR:fx(ex[1]),exY:fy(ex[2])};
  st.furn=(cfgR.furn||[]).map(function(f){return [fx(f[0]),fy(f[1]),fx(f[2]),fy(f[3])];});
  st.furnObjs=[];
  for(var k=0;k<door.owners.length&&k<cfgR.owners.length;k++){
    var no=one(door.owners[k]); if(!no)continue; no.hide(false);
    no.setX(fx(cfgR.owners[k][0])-no.getWidth()/2); no.setY(fy(cfgR.owners[k][1])-no.getHeight());
    no.setAnimationName("IdleDown"); no.setZOrder(baseZ(no));
  }
  var pw=p.getWidth(),ph=p.getHeight();
  p.setX(fx(cfgR.entry[0])-pw/2); p.setY(fy(cfgR.entry[1])-ph*0.85);
  p.setAnimationName("IdleUp"); st.last=[p.getX(),p.getY()];
  st.exitArmed=false; sfx("select.wav");
}
function exitBuilding(){
  var door=st.curDoor; st.inside=null; st.curDoor=null; st.intMode=null;
  setOutdoorHidden(false);
  var iv=one("Interior"); if(iv)iv.hide(true);
  var art=one("IntArt"); if(art)art.hide(true);
  ["IntCmdBg","IntCmd0","IntCmd1","IntCmd2","IntCmd3","IntCmd4","IntCmd5"].forEach(function(n){var o=one(n);if(o)o.hide(true);});
  p.hide(false);
  st.furnObjs=[]; st.furn=[];
  CFG.npcs.forEach(function(n){var o=one(n.obj);if(!o)return;
    if(isOutdoorNpc(n.obj)){o.hide(false);
      if(st.npcHome&&st.npcHome[n.obj]){o.setX(st.npcHome[n.obj][0]);o.setY(st.npcHome[n.obj][1]);}
      o.setAnimationName("Idle"+npcFace(n.obj)); o.setZOrder(baseZ(o));}
    else o.hide(true);});
  var pw=p.getWidth(),ph=p.getHeight();
  p.setX((door.tx+0.5)*TS-pw/2); p.setY((door.ty+1.5)*TS-ph*0.85);
  p.setAnimationName("IdleDown"); st.last=[p.getX(),p.getY()];
  sfx("cancel.mp3");
}
// E2E 測試掛勾：window.__forceEnc="forest" 直接進入該遭遇戰
try{if(window.__forceEnc){var fe=window.__forceEnc;window.__forceEnc=null;
  g.get("g_returnScene").setString(CFG.SCENE);
  g.get("g_returnX").setNumber(p.getX());g.get("g_returnY").setNumber(p.getY());
  g.get("g_encounter").setString(fe);
  gdjs.evtTools.runtimeScene.replaceScene(rs,"Battle",true);return;}}catch(e){}
// E2E 測試掛勾：window.__tp=[tileX,tileY] 把玩家腳底瞬移到該格中心（production 無此變數 → no-op）。
// 置於移動/夾制之前，因此室內時同幀會被 st.floor 夾回開闊地板——正好用來驗證家具碰撞。
try{if(window.__tp){var _t=window.__tp;window.__tp=null;
  p.setX(_t[0]*TS+TS/2-p.getWidth()/2);
  p.setY(_t[1]*TS+TS*0.5-p.getHeight()*0.85);
  st.last=[p.getX(),p.getY()];}}catch(e){}

// ---------- 寶箱：發獎與開啟 ----------
function chestLootDesc(loot){
  var parts=[];
  for(var i=0;i<loot.length;i++){var L=loot[i];
    if(L.type==="gold"){parts.push(L.amount+" 金幣");}
    else if(L.type==="item"){var n=L.count||1;var nm=(ITEM[L.id]?ITEM[L.id].name:L.id);parts.push(nm+(n>1?"×"+n:""));}
    else if(L.type==="eq"){parts.push(EQ[L.id]?EQ[L.id].name:L.id);}
  }
  return parts.join("、");
}
function grantChestLoot(loot){
  for(var i=0;i<loot.length;i++){var L=loot[i];
    if(L.type==="gold"){g.get("g_gold").setNumber(g.get("g_gold").getAsNumber()+L.amount);}
    else if(L.type==="item"){invAdd(L.id,L.count||1);}
    else if(L.type==="eq"){var iv=J("g_eqInv",[]);iv.push(L.id);setJ("g_eqInv",iv);}
  }
}
function openChest(C){
  if(C.opened)return;
  C.opened=true; C.o.setAnimationName("opened"); C.o.setZOrder(baseZ(C.o));
  // 持久化：記入 g_chests（去重）；重進地圖 init 會據此還原 opened 狀態、不再發獎
  var opened=J("g_chests",[]); var dup=false;
  for(var k=0;k<opened.length;k++)if(opened[k]===C.d.id)dup=true;
  if(!dup){opened.push(C.d.id);setJ("g_chests",opened);}
  grantChestLoot(C.d.loot);
  st.dlg={name:"寶箱",lines:["打開了寶箱！獲得 "+chestLootDesc(C.d.loot)+"。"],action:null};st.dlgIdx=0;
  sfx("win.wav"); saveGame();
}

// ---------- 劇情佇列 ----------
if(!st.cut&&st.queue.length){
  var key=st.queue.shift();
  if(key==="__lose__"){ st.cut={lines:[["","你們在芳蕾鎮教堂的祭壇前醒來……蓋婭女神接住了倒下的旅人。（隊伍已完全恢復）"]],key:null}; st.cutIdx=0; }
  else { var c=CUTS[key]; st.cut={lines:c.lines,key:key}; st.cutIdx=0; sfx("select.wav"); }
}

// ================= Track B：觸控輸入（虛擬搖桿＋按鈕；合成鍵餵給既有鍵盤流程）=================
var im=rs.getGame().getInputManager();
if(!st.tk)st.tk={}; else {for(var _tkk in st.tk)delete st.tk[_tkk];}   // 本幀 touch-key 集合
var _startT=im.getStartedTouchIdentifiers();
var _allT=(im.getAllTouchIdentifiers?im.getAllTouchIdentifiers():_startT)||_startT;
function _tx(id){return im.getTouchX(id);} function _ty(id){return im.getTouchY(id);}
var _starts=[]; for(var _si=0;_si<_startT.length;_si++)_starts.push({x:_tx(_startT[_si]),y:_ty(_startT[_si]),id:_startT[_si]});
function inBtn(n,px,py){var o=one(n);if(!o||o.isHidden())return false;return o.insideObject(px,py);}
function anyStartIn(n){for(var _i=0;_i<_starts.length;_i++)if(inBtn(n,_starts[_i].x,_starts[_i].y))return true;return false;}
if(anyStartIn("PadU"))st.tk["Up"]=1;      if(anyStartIn("PadD"))st.tk["Down"]=1;
if(anyStartIn("PadL"))st.tk["Left"]=1;    if(anyStartIn("PadR"))st.tk["Right"]=1;
if(anyStartIn("BtnBack"))st.tk["Escape"]=1; if(anyStartIn("BtnMenu"))st.tk["m"]=1;
if(anyStartIn("BtnS1"))st.tk["Num1"]=1;   if(anyStartIn("BtnS2"))st.tk["Num2"]=1; if(anyStartIn("BtnS3"))st.tk["Num3"]=1;
var _btnA=anyStartIn("BtnA");
if(_btnA){st.tk["Return"]=1;st.tk["Space"]=1;}
// 虛擬搖桿（floating 左下；追蹤單一觸控 id）
if(st.joyId!==undefined&&st.joyId!==null){var _still=false;for(var _i=0;_i<_allT.length;_i++)if(_allT[_i]===st.joyId)_still=true;if(!_still)st.joyId=null;}
var _canJoy=!st.cut&&!st.dlg&&!st.menu&&!st.shop;
if(_canJoy&&(st.joyId===undefined||st.joyId===null)){
  for(var _i=0;_i<_starts.length;_i++){var _s=_starts[_i];
    if(_s.x<620&&_s.y>250&&!inBtn("BtnA",_s.x,_s.y)&&!inBtn("BtnMenu",_s.x,_s.y)){st.joyId=_s.id;st.joyOx=_s.x;st.joyOy=_s.y;break;}}
}
var _joyOn=false,_jdx=0,_jdy=0;
if(st.joyId!==undefined&&st.joyId!==null&&_canJoy){_jdx=_tx(st.joyId)-st.joyOx;_jdy=_ty(st.joyId)-st.joyOy;_joyOn=true;}
else if(!_canJoy)st.joyId=null;
if(_joyOn){var _DE=14;
  if(_jdx>_DE)b.simulateControl("Right"); else if(_jdx<-_DE)b.simulateControl("Left");
  if(_jdy>_DE)b.simulateControl("Down");  else if(_jdy<-_DE)b.simulateControl("Up");}
var _jb=one("JoyBase"),_jk=one("JoyKnob");
if(_joyOn){var _R=52,_mg=Math.sqrt(_jdx*_jdx+_jdy*_jdy);
  var _kx=st.joyOx+(_mg>_R?_jdx/_mg*_R:_jdx),_ky=st.joyOy+(_mg>_R?_jdy/_mg*_R:_jdy);
  if(_jb){_jb.hide(false);_jb.setX(st.joyOx-_jb.getWidth()/2);_jb.setY(st.joyOy-_jb.getHeight()/2);}
  if(_jk){_jk.hide(false);_jk.setX(_kx-_jk.getWidth()/2);_jk.setY(_ky-_jk.getHeight()/2);}
}else{if(_jb)_jb.hide(true);if(_jk)_jk.hide(true);}
// 觸控按鈕顯示狀態（依上一幀選單狀態；一幀延遲無感）
function _showB(n,v){var o=one(n);if(o)o.hide(!v);}
var _roam=!st.cut&&!st.dlg&&!st.menu&&!st.shop;
_showB("BtnA",true); _showB("BtnMenu",_roam||!!st.menu);
var _clu=(!!st.menu||!!st.shop);
_showB("PadU",_clu);_showB("PadD",_clu);_showB("PadL",_clu);_showB("PadR",_clu);_showB("BtnBack",_clu);
var _attr=false;   // 屬性配點改用畫面內 +/- 步進鈕（可點擊）＋鍵盤 1/2/3，隱藏舊 S1-3 觸控鈕
_showB("BtnS1",_attr);_showB("BtnS2",_attr);_showB("BtnS3",_attr);
var _tapAdv=(st.cut||st.dlg)&&_starts.length>0;   // 對話/過場：點任意處推進
// ---------- 空白鍵（鍵盤＋觸控）----------
var space=gdjs.evtTools.input.isKeyPressed(rs,"Space");
var hit=(space&&!st.sp)||_btnA||_tapAdv; st.sp=space;

// ---------- 劇情播放 ----------
var lock=false;
if(st.cut){
  lock=true;
  var line=st.cut.lines[st.cutIdx];
  var pn=one("DlgPanel"),dn=one("DlgName"),dx=one("DlgText");
  if(pn)pn.hide(false); if(dn){dn.hide(false);dn.setString(line[0]);} if(dx){dx.hide(false);dx.setString(line[1]+"　▽");}
  setFace(line[0]);
  if(hit){
    st.cutIdx++;
    if(st.cutIdx>=st.cut.lines.length){
      var key=st.cut.key; st.cut=null;
      if(key){
        var c=CUTS[key];
        var f4=flags();
        if(c.once)f4[c.once]=1;
        if(c.setstep!==undefined)f4.step=c.setstep;
        setJ("g_flags",f4);
        if(c.party){ var old=party(); var np=[];
          for(var i=0;i<c.party.length;i++){
            var ex=null; for(var j=0;j<old.length;j++){if(old[j].id===c.party[i])ex=old[j];}
            np.push(ex||mkMember(c.party[i]));
          } setJ("g_party",np); }
        if(c.battle){
          g.get("g_returnScene").setString(CFG.SCENE);
          g.get("g_returnX").setNumber(p.getX()); g.get("g_returnY").setNumber(p.getY());
          g.get("g_encounter").setString(c.battle);
          gdjs.evtTools.runtimeScene.replaceScene(rs,"Battle",true); return;
        }
        if(c.transfer){
          g.get("g_spawn").setString(c.transfer[1]);
          gdjs.evtTools.runtimeScene.replaceScene(rs,c.transfer[0],true); return;
        }
      }
    }
  }
} else {
  // ---------- NPC 對話 ----------
  var near=null;
  var _talkR=st.inside?134:72;   // 室內主人常在櫃檯/桌後（深家具），對話半徑放寬才搆得到
  for(var i=0;i<CFG.npcs.length;i++){
    var o=one(CFG.npcs[i].obj); if(!o||o.isHidden())continue;
    var dxx=(o.getX()+o.getWidth()/2)-(p.getX()+p.getWidth()/2);
    var dyy=(o.getY()+o.getHeight()/2)-(p.getY()+p.getHeight()/2);
    if(Math.sqrt(dxx*dxx+dyy*dyy)<_talkR){near=CFG.npcs[i];break;}
  }
  // 告示板：走近顯示當前委託＋建議等級（讀 CONTENT.pacing／劇情旗標）
  var boardO=one("Board");var nearBoard=false;
  if(boardO){
    var bdx=(boardO.getX()+boardO.getWidth()/2)-(p.getX()+p.getWidth()/2);
    var bdy=(boardO.getY()+boardO.getHeight()/2)-(p.getY()+p.getHeight()/2);
    nearBoard=(bdx*bdx+bdy*bdy)<72*72;
  }
  // 建築門口（僅室外）：站在門口格或其正下方一格→提示進入
  var nearDoor=null;
  if(!st.inside){
    var pftx=Math.floor((p.getX()+p.getWidth()/2)/TS);
    var pfty=Math.floor((p.getY()+p.getHeight()*0.85)/TS);
    for(var di=0;di<((CFG.doors)||[]).length;di++){
      var dd=CFG.doors[di];
      if(pftx===dd.tx&&(pfty===dd.ty||pfty===dd.ty+1)){nearDoor=dd;break;}
    }
  }
  // 寶箱：鄰接偵測（玩家腳掌 tile 與寶箱 tile Chebyshev≤1；避免隔一格牆還能開）
  var nearChest=null;
  if(st.chests){
    var _pcx=Math.floor((p.getX()+p.getWidth()/2)/TS), _pcy=Math.floor((p.getY()+p.getHeight()*0.85)/TS);
    for(var ci=0;ci<st.chests.length;ci++){var C=st.chests[ci];
      if(C.opened)continue;
      if(Math.abs(_pcx-C.d.tx)<=1 && Math.abs(_pcy-C.d.ty)<=1){nearChest=C;break;}
    }
  }
  st.nearNpc=near?near.id:""; st.nearDoor=nearDoor?nearDoor.obj:"";   // E2E 掛勾
  st.nearChest=nearChest?nearChest.d.id:"";   // E2E 掛勾
  if(st.dlg){
    lock=true;
    var d0=st.dlg;
    var pn=one("DlgPanel"),dn=one("DlgName"),dx=one("DlgText");
    if(pn)pn.hide(false); if(dn){dn.hide(false);dn.setString(d0.name);} if(dx){dx.hide(false);dx.setString(d0.lines[st.dlgIdx]+"　▽");}
    setFace(d0.name);
    if(hit){
      st.dlgIdx++;
      if(st.dlgIdx>=d0.lines.length){
        // 動作
        var f5=flags();
        if(d0.action==="heal"){healAll();sfx("heal.wav");}
        else if(d0.action==="register"){f5.reg=1;setJ("g_flags",f5);sfx("win.wav");}
        else if(d0.action==="ch1_take"){f5.ch1=1;setJ("g_flags",f5);sfx("select.wav");var bm=one("BossMark");if(bm)bm.hide(false);}
        else if(d0.action==="ch1_reward"){f5.ch1=3;setJ("g_flags",f5);g.get("g_gold").setNumber(g.get("g_gold").getAsNumber()+200);sfx("win.wav");}
        else if(d0.action==="shop_gid"){openShop("gid");}
        else if(d0.action==="shop_hank"){openShop("hank");}
        else if(d0.action==="give_sword"){var fsw=flags();if(!fsw.gotSword){fsw.gotSword=1;setJ("g_flags",fsw);var invsw=J("g_eqInv",[]);invsw.push("iron_sword");setJ("g_eqInv",invsw);sfx("learn.mp3");}}   // 事件：漢克臨別贈言
        else if(d0.action==="give_potion"){var fpt=flags();if(!fpt.gotPotion){fpt.gotPotion=1;setJ("g_flags",fpt);invAdd("potion",2);sfx("learn.mp3");}}   // 事件：吉德新客招待
        else if(d0.action==="give_ring"){var f6c=flags();if(!f6c.gotRing){f6c.gotRing=1;setJ("g_flags",f6c);
          var inv7=J("g_eqInv",[]);inv7.push("vital_ring");setJ("g_eqInv",inv7);sfx("learn.mp3");}}
        else if(d0.action==="give_earring"){var f6d=flags();if(!f6d.gotEar){f6d.gotEar=1;setJ("g_flags",f6d);
          var inv8=J("g_eqInv",[]);inv8.push("focus_earring");setJ("g_eqInv",inv8);sfx("learn.mp3");}}
        else if(d0.action==="ch2_take"){var fct=flags();fct.ch2=1;setJ("g_flags",fct);sfx("select.wav");}
        else if(d0.action==="ch2_report"){var fcr=flags();fcr.ch2=3;setJ("g_flags",fcr);
          g.get("g_gold").setNumber(g.get("g_gold").getAsNumber()+150);invAdd("potion",2);sfx("win.wav");}
        else if(d0.action==="mira_start"){var fms=flags();if(!fms.gotEar){fms.gotEar=1;fms.mira2=1;setJ("g_flags",fms);
          var invms=J("g_eqInv",[]);invms.push("focus_earring");setJ("g_eqInv",invms);sfx("learn.mp3");}}
        else if(d0.action==="mira_reward"){var fmr=flags();fmr.mira2=2;setJ("g_flags",fmr);invAdd("potion",3);sfx("heal.wav");}
        else if(d0.action==="relic_turnin"){var frl=flags();frl.relic=2;setJ("g_flags",frl);
          g.get("g_gold").setNumber(g.get("g_gold").getAsNumber()+100);invAdd("miner_helmet",-1);sfx("win.wav");}
        if(d0.action)saveGame();   // 對話帶動作（旗標/金幣/道具變動）→ 自動存檔
        st.dlg=null;
        // 多人交談（如鐵匠鋪 漢克→瑪莎）：閒聊講完接著談下一位，立繪切到他
        if(st.intMode==="menu"&&st.talkKind==="talk"&&st.talkRest&&st.talkRest.length){
          var _nx=st.talkRest.shift(); setIntArt(_nx); openOwnerCmd(_nx,"talk");
        }
      }
    }
  } else if(near&&hit&&!st.menu&&!st.shop){
    var defs=DLG[near.id]||[];
    var f7=flags(); var chosen=null;
    for(var i=0;i<defs.length;i++){
      if(matchWhen(f7,defs[i].when)){chosen=defs[i];break;}
    }
    if(chosen){st.dlg={name:chosen.name,lines:chosen.lines,action:chosen.action};st.dlgIdx=0;sfx("select.wav");}
  } else if(nearBoard&&hit&&!st.menu&&!st.shop){
    st.dlg={name:"告示板",lines:boardLines(),action:null};st.dlgIdx=0;sfx("select.wav");
  } else if(nearDoor&&hit&&!st.menu&&!st.shop){
    enterBuilding(nearDoor);
  } else if(nearChest&&hit&&!st.menu&&!st.shop){
    openChest(nearChest);
  }
  var pr=one("Prompt");
  var showTalk=near&&!st.dlg&&!st.menu&&!st.shop;
  var showBoard=!near&&nearBoard&&!st.dlg&&!st.menu&&!st.shop;
  var showDoor=!st.inside&&!near&&!nearBoard&&nearDoor&&!st.dlg&&!st.menu&&!st.shop;
  var showChest=!near&&!nearBoard&&!nearDoor&&nearChest&&!st.dlg&&!st.menu&&!st.shop;
  var showLeave=st.inside&&st.intMode!=="menu"&&!showTalk&&!st.dlg&&!st.menu&&!st.shop;   // 立繪選單式室內用選單離開，不顯示走動提示
  if(pr){pr.hide(!(showTalk||showBoard||showDoor||showChest||showLeave));
    if(showTalk)pr.setString("空白鍵：交談");
    else if(showBoard)pr.setString("空白鍵：查看告示板");
    else if(showDoor)pr.setString("空白鍵：進入"+(nearDoor.label||""));
    else if(showChest)pr.setString("空白鍵：開啟寶箱");
    else if(showLeave)pr.setString("走到下方門口即可離開");}
}
// ---------- 選單（角色/道具/地圖/稱號/系統） ----------
if(!st.kp)st.kp={};
function keyHit(k){var d=gdjs.evtTools.input.isKeyPressed(rs,k)||!!(st.tk&&st.tk[k]);var was=st.kp[k];st.kp[k]=d;return d&&!was;}
// ===== 立繪＋選單式室內：動態指令選單（交談／功能／事件／離開），不走動 =====
if(st.inside&&st.intMode==="menu"){
  lock=true;   // 鎖 TopDown 移動，方向鍵留給選單游標
  var _bg=one("IntCmdBg");
  if(!st.dlg&&!st.cut&&!st.menu&&!st.shop){
    buildIntCmds();   // 每幀重建：事件完成／進度變化後指令即時更新
    var _cmds=st.intCmds||[], _n=_cmds.length, _rh=46, _px=96, _pw=300, _py=590-_n*_rh;
    if(_bg){_bg.hide(false);_bg.setX(_px);_bg.setY(_py-14);_bg.setWidth(_pw);_bg.setHeight(_n*_rh+24);_bg.setZOrder(9994);}
    if(keyHit("Up"))  {st.intCmd=(st.intCmd-1+_n)%_n;sfx("cursor.mp3");}
    if(keyHit("Down")){st.intCmd=(st.intCmd+1)%_n;sfx("cursor.mp3");}
    var _cl=-1;
    for(var _i=0;_i<6;_i++){var _r=one("IntCmd"+_i);if(!_r)continue;
      if(_i<_n){_r.hide(false);_r.setX(_px+28);_r.setY(_py+_i*_rh);
        _r.setString((st.intCmd===_i?"▶ ":"　")+_cmds[_i].label);
        _r.setColor(st.intCmd===_i?"255;245;200":"210;214;230");
        if(anyStartIn("IntCmd"+_i))_cl=_i;
      } else _r.hide(true);
    }
    if(_cl>=0)st.intCmd=_cl;
    var _canC=!st.intJustEntered&&!st.dlgPrev; st.intJustEntered=false;   // 略過進門/對話關閉當幀的按鍵，避免誤觸
    if(_canC&&(_cl>=0||keyHit("Space")||keyHit("Return"))) runIntCmd(_cmds[st.intCmd]);
  }else{ if(_bg)_bg.hide(true); for(var _j=0;_j<6;_j++){var _rr=one("IntCmd"+_j);if(_rr)_rr.hide(true);} }
}
var TABS=["角色","道具","地圖","稱號","系統"];   // 頂層分類（裝備已收進角色頁子分頁）
// Claude Design 原型 tokens：accent=#AADCEB（John 選定）、gold 留給金幣/警示
var C_ACC="170;220;235", C_GOLD="255;225;120", C_DIM="120;130;150";
var SLOTS=[["weapon","武器"],["armor","防具"],["boots","靴子"],["wrist","護腕"],["acc1","飾品Ⅰ"],["acc2","飾品Ⅱ"]];
var SLOTN={weapon:"武器",armor:"防具",boots:"靴子",wrist:"護腕",acc:"飾品"};
function slotType(slot){return (slot==="acc1"||slot==="acc2")?"acc":slot;}
function slotLabel(sk){for(var i=0;i<SLOTS.length;i++){if(SLOTS[i][0]===sk)return SLOTS[i][1];}return sk;}
function accSlotFor(m,it){if(it.slot!=="acc")return it.slot;
  if(!m.eq||!m.eq.acc1)return "acc1"; if(!m.eq.acc2)return "acc2"; return "acc1";}
function pDef(id){for(var i=0;i<CONTENT.party.length;i++){if(CONTENT.party[i].id===id)return CONTENT.party[i];}return null;}
var TITLES=__TITLES__;
function titleEarned(t){
  var f0=flags();
  var mres=t.req.match(/^(\w+)(==|>=)(\d+)$/);
  if(!mres)return false;
  var val=f0[mres[1]]||0,num=parseInt(mres[3]);
  return (mres[2]==="==")?(val===num):(val>=num);
}
function skPow(sk,slv){return 1+C_DERIVED.skillPowerPerLv*((slv||1)-1);}
var EQSTAT_N={patk:"物攻",matk:"魔攻",pdef:"物防",mdef:"魔防",dodge:"閃避",crit:"會心",hp:"生命",mp:"法力",luck:"幸運"};
function eqDesc(e){
  var out=[];
  for(var k in EQSTAT_N){if(e[k])out.push(EQSTAT_N[k]+"+"+e[k]);}
  return out.join(" ");
}
function cycleEq(m,slot){
  var tp=slotType(slot);
  var inv=J("g_eqInv",[]);
  var cur=(m.eq&&m.eq[slot])||null;
  // 穩定環：卸下 + (背包∪目前) 依 id 排序——按 Enter 沿環前進，先換下一件、繞完一圈才是卸下
  var set={};
  for(var i=0;i<inv.length;i++){if(EQ[inv[i]]&&EQ[inv[i]].slot===tp)set[inv[i]]=1;}
  if(cur)set[cur]=1;
  var ring=[null].concat(Object.keys(set).sort());
  if(ring.length<2){sfx("cancel.mp3");return false;}
  var next=ring[(ring.indexOf(cur)+1)%ring.length];
  if(next===cur)return false;
  if(cur)inv.push(cur);
  if(next){inv.splice(inv.indexOf(next),1);m.eq[slot]=next;}
  else delete m.eq[slot];
  setJ("g_eqInv",inv);
  sfx("select.wav");
  return true;
}
// 選單/商店共用的面板渲染：rows→MRow、barsp→BarBg/BarFill、RowHi 高亮、金幣附於 hint
function renderPanel(rows,barsp,opt){
  opt=opt||{};
  var mp0=one("MenuPanel"),mt=one("MenuTitle"),mh=one("MenuHint"),mtab=one("MenuTab");
  if(mp0)mp0.hide(false);
  if(mt){mt.hide(false);mt.setString(opt.title||"選單");}
  if(mtab){if(opt.tab!==undefined&&opt.tab!==null){mtab.hide(false);mtab.setColor(opt.tabCol||C_ACC);mtab.setString(opt.tab);}else mtab.hide(true);}
  var hiRow=null;
  for(var i=0;i<64;i++){
    var ro=one("MRow"+i);if(!ro)continue;
    if(i<rows.length&&rows[i]){ro.hide(false);ro.setString(rows[i].t);
      var rx=rows[i].x!==undefined?rows[i].x:200, ry=rows[i].y!==undefined?rows[i].y:176+i*28;
      ro.setX(rx);ro.setY(ry);
      ro.setColor(rows[i].sel?C_ACC:(rows[i].c||"235;235;245"));
      if(rows[i].sel&&!hiRow)hiRow={x:rx,y:ry,w:rows[i].hw||640};}
    else ro.hide(true);
  }
  var rh=one("RowHi");
  if(rh){rh.hide(!hiRow);
    if(hiRow){rh.setX(hiRow.x-16);rh.setY(hiRow.y-2);rh.setWidth(hiRow.w);rh.setHeight(28);}}
  var bgs=rs.getObjects("BarBg"),bfs=rs.getObjects("BarFill");
  for(var i=0;i<bgs.length;i++){
    if(i<barsp.length){var bp=barsp[i];
      bgs[i].hide(false);bgs[i].setX(bp.x-2);bgs[i].setY(bp.y-2);
      bgs[i].setWidth(bp.w+4);bgs[i].setHeight(14);
      var rr=bp.max>0?Math.max(0,Math.min(1,bp.cur/bp.max)):0;
      if(bfs[i]){bfs[i].setAnimationName(bp.kind);bfs[i].hide(false);
        bfs[i].setX(bp.x);bfs[i].setY(bp.y);
        bfs[i].setWidth(Math.max(1,Math.round(bp.w*rr)));bfs[i].setHeight(10);}
    } else {bgs[i].hide(true);if(bfs[i])bfs[i].hide(true);}
  }
  var mf=one("MenuFace");
  if(mf){mf.hide(!opt.showFace);if(opt.showFace)mf.setAnimationName(opt.showFace);}
  var mart=one("MenuArt");   // 故事頁大型全身立繪（三主角）；統一畫布→固定顯示尺寸、右側定位
  if(mart){
    if(opt.showArt){mart.hide(false);mart.setAnimationName(opt.showArt);
      mart.setWidth(306);mart.setHeight(470);mart.setX(812);mart.setY(112);}
    else mart.hide(true);
  }
  var mmap=one("MenuMap");
  if(mmap)mmap.hide(!opt.showMap);
  if(mh){mh.hide(false);mh.setString((opt.hint||"")+"　　金幣 "+g.get("g_gold").getAsNumber());}
}
if(!st.cut&&!st.dlg&&!st.shop){
  if(keyHit("Escape")||keyHit("m")){
    if(st.menu&&st.tab===0&&st.eqSwap){st.eqSwap=false;sfx("cancel.mp3");}
    else if(st.menu&&st.tab===0&&st.skUse){st.skUse=null;sfx("cancel.mp3");}
    else if(st.menu&&st.tab===1&&st.iMode==="who"){st.iMode="list";sfx("cancel.mp3");}
    else{st.menu=!st.menu;st.tab=0;st.cMem=0;st.cTab=0;st.cSel=0;st.sel=0;
         st.iMode="list";st.iSel=0;st.eqSwap=false;st.skUse=null;st.confirmQuit=false;
         sfx(st.menu?"menu.mp3":"cancel.mp3");}
  }
}
if(st.menu){
  lock=true;
  var ps=party();
  var GFX=one("MenuGfx");
  if(st.cMem===undefined)st.cMem=0; if(ps.length&&st.cMem>=ps.length)st.cMem=ps.length-1; if(st.cMem<0)st.cMem=0;
  if(st.cTab===undefined)st.cTab=0;
  if(st.cSel===undefined)st.cSel=0;
  if(st.sel===undefined)st.sel=0;
  var eRet=keyHit("Return"),eSpc=keyHit("Space");var enter=eRet||eSpc;
  var up=keyHit("Up"),down=keyHit("Down"),lk=keyHit("Left"),rk=keyHit("Right");
  var qh=keyHit("q"),eh=keyHit("e");
  var TBH=54,PX=16,PY=62,PW=396,RX=424,RW=680,RY=62,RB=690,PPB=508,SUBH=40,BODY_Y=110;
  var SUB=["屬性","裝備","技能","故事"];
  var C_GOLD="255;225;120",C_SELY="255;235;120",C_ACC="170;220;235",C_DIM2="120;130;150";
  var _ti=0;
  function T(s,x,y,sz,col){var o=one("MRow"+_ti);_ti++;if(!o)return;o.hide(false);o.setString(String(s));o.setX(Math.round(x));o.setY(Math.round(y));if(o.setCharacterSize)o.setCharacterSize(sz||18);o.setColor(col||"235;235;245");}
  function box(x,y,w,h,fill,fop,oc,os){if(!GFX)return;GFX.setFillColor(fill);GFX.setFillOpacity(fop);GFX.setOutlineColor(oc||"10;10;20");GFX.setOutlineSize(os===undefined?2:os);GFX.setOutlineOpacity(os===0?0:255);GFX.drawRectangle(x,y,x+w,y+h);}
  function fillR(x,y,w,h,fill,fop){if(!GFX)return;GFX.setFillColor(fill);GFX.setFillOpacity(fop===undefined?255:fop);GFX.setOutlineSize(0);GFX.setOutlineOpacity(0);GFX.drawRectangle(x,y,x+w,y+h);}
  function bar(x,y,w,h,ratio,fill){box(x,y,w,h,"42;46;64",255,"10;10;20",2);var fw=Math.max(0,Math.round((w-4)*Math.max(0,Math.min(1,ratio))));if(fw>0)fillR(x+2,y+2,fw,h-4,fill,255);}
  function hitRect(x,y,w,h){for(var _q=0;_q<_starts.length;_q++){var _s=_starts[_q];if(_s.x>=x&&_s.x<=x+w&&_s.y>=y&&_s.y<=y+h)return true;}return false;}
  var mbg=one("MenuBg");if(mbg){mbg.hide(false);mbg.setX(0);mbg.setY(0);mbg.setWidth(1280);mbg.setHeight(720);}
  fillR(0,0,1280,720,"10;11;20",210);
  fillR(0,0,1280,TBH,"12;14;26",245);fillR(0,TBH,1280,3,"10;10;20",255);
  var _mtab=one("MenuTab");if(_mtab)_mtab.hide(true);
  (function(){var o=one("MTop0");if(o){o.hide(false);o.setString("MENU");o.setX(22);o.setY(16);if(o.setCharacterSize)o.setCharacterSize(20);o.setColor(C_GOLD);}})();
  var _cx=140;var _catRect=[];
  for(var _ci=0;_ci<TABS.length;_ci++){var _lab=TABS[_ci];var _on=(_ci===st.tab);var _wpx=_lab.length*22+(_on?26:6);
    var o2=one("MTop"+(_ci+1));if(o2){o2.hide(false);o2.setString((_on?"【":"")+_lab+(_on?"】":""));o2.setX(_cx);o2.setY(15);if(o2.setCharacterSize)o2.setCharacterSize(22);o2.setColor(_on?C_SELY:"225;228;238");}
    _catRect.push({x:_cx-6,w:_wpx+8,i:_ci});_cx+=_lab.length*22+40;}
  (function(){var o=one("MTop6");if(o){o.hide(false);o.setString("金幣 "+g.get("g_gold").getAsNumber());o.setX(1080);o.setY(16);if(o.setCharacterSize)o.setCharacterSize(20);o.setColor(C_GOLD);}})();
  var _navCat=function(ni){st.tab=((ni%TABS.length)+TABS.length)%TABS.length;st.cSel=0;st.sel=0;st.iMode="list";st.iSel=0;st.eqSwap=false;st.skUse=null;st.confirmQuit=false;sfx("cursor.mp3");};
  for(var _ci=0;_ci<_catRect.length;_ci++){if(_catRect[_ci].i!==st.tab&&hitRect(_catRect[_ci].x,10,_catRect[_ci].w,TBH-8)){_navCat(_catRect[_ci].i);break;}}
  if(qh)_navCat(st.tab-1); else if(eh)_navCat(st.tab+1);
  if(st.tab!==0){if(lk){_navCat(st.tab-1);lk=false;} else if(rk){_navCat(st.tab+1);rk=false;}}
  var rows=[],barsp=[],hint="",showFace=null,showArt=null,showMap=false;
  if(st.tab!==0){var _mahide=one("MenuArt");if(_mahide)_mahide.hide(true);}

  if(st.tab===0){
    var m=ps[st.cMem];derive(m);
    box(PX,PY,PW,PPB-PY,"22;26;40",242,"10;10;20",2);
    fillR(PX+3,PY+3,PW-6,PPB-PY-6,"52;58;74",255);
    var mart=one("MenuArt");
    if(mart){mart.hide(false);mart.setAnimationName(m.id);
      var _ph=PPB-PY-74;var _pw=Math.round(_ph*(306/470));if(_pw>PW-24){_pw=PW-24;_ph=Math.round(_pw*(470/306));}
      mart.setWidth(_pw);mart.setHeight(_ph);mart.setX(PX+PW/2-_pw/2);mart.setY(PPB-_ph-6);}
    fillR(PX+3,PPB-72,PW-6,66,"10;10;20",180);
    if(ps.length>1){T("◀",PX+12,PPB-60,26,C_ACC);T("▶",PX+PW-32,PPB-60,26,C_ACC);
      if(hitRect(PX+4,PPB-64,44,50)){st.cMem=(st.cMem+ps.length-1)%ps.length;st.cSel=0;sfx("cursor.mp3");}
      if(hitRect(PX+PW-48,PPB-64,44,50)){st.cMem=(st.cMem+1)%ps.length;st.cSel=0;sfx("cursor.mp3");}}
    m=ps[st.cMem];derive(m);
    T(m.name,PX+46,PPB-66,30,C_GOLD);
    T("Lv"+m.lv,PX+46+m.name.length*30+12,PPB-58,16,"255;255;255");
    T("職業："+clsName(m),PX+46,PPB-32,17,"255;255;255");
    var _sw=Math.floor((RW-24)/4);
    for(var _si=0;_si<4;_si++){var _sx=RX+_si*(_sw+8);var _son=(_si===st.cTab);
      box(_sx,RY,_sw,SUBH,_son?"58;64;90":"20;22;38",_son?255:212,_son?C_SELY:"70;80;120",2);
      T((_son?"◆ ":"")+SUB[_si],_sx+_sw/2-(_son?34:22),RY+9,20,_son?C_SELY:"200;204;220");
      if(_si!==st.cTab&&hitRect(_sx,RY,_sw,SUBH)){st.cTab=_si;st.cSel=0;st.eqSwap=false;st.skUse=null;sfx("cursor.mp3");}}
    if(lk){st.cTab=(st.cTab+3)%4;st.cSel=0;st.eqSwap=false;st.skUse=null;sfx("cursor.mp3");}
    if(rk){st.cTab=(st.cTab+1)%4;st.cSel=0;st.eqSwap=false;st.skUse=null;sfx("cursor.mp3");}
    box(RX,BODY_Y,RW,RB-BODY_Y,"16;18;32",236,"10;10;20",2);
    var bx=RX+16,bw=RW-32,byy=BODY_Y+16;

    if(st.cTab===0){
      if(ps.length>1){if(up){st.cMem=(st.cMem+ps.length-1)%ps.length;sfx("cursor.mp3");}else if(down){st.cMem=(st.cMem+1)%ps.length;sfx("cursor.mp3");}}
      m=ps[st.cMem];derive(m);
      T("HP",bx,byy,16,"255;255;255");T(m.hp+"/"+m.maxhp,bx+bw/2-96,byy,15,"255;255;255");
      bar(bx+34,byy+1,bw/2-150,16,m.maxhp?m.hp/m.maxhp:0,"208;88;74");
      T("MP",bx+bw/2+6,byy,16,"255;255;255");T(m.mp+"/"+m.maxmp,bx+bw-62,byy,15,"255;255;255");
      bar(bx+bw/2+40,byy+1,bw/2-150,16,m.maxmp?m.mp/m.maxmp:0,"90;160;200");
      var dy=byy+30;
      var DER=[["物攻",m.patk],["魔攻",m.matk],["物防",m.pdef],["魔防",m.mdef],["閃避",m.dodgeV],["會心",m.critV+"%"]];
      var cw=Math.floor((bw-5*7)/6);
      for(var _i=0;_i<6;_i++){var _cx2=bx+_i*(cw+7);box(_cx2,dy,cw,46,"30;34;54",214,"10;10;20",2);
        T(DER[_i][0],_cx2+8,dy+6,13,"170;180;220");T(String(DER[_i][1]),_cx2+8,dy+22,20,C_ACC);}
      dy+=58;
      box(bx,dy,bw,90,"34;38;58",230,"10;10;20",2);
      T("主屬性配點",bx+12,dy+9,17,"255;255;255");
      T("剩餘 "+(m.pts||0),bx+bw-118,dy+10,16,(m.pts||0)>0?C_SELY:"170;180;220");
      var ATT=[["力量","str"],["敏捷","agi"],["智力","int"]];var aw=Math.floor((bw-24-2*10)/3);var _alloc=false;
      if(keyHit("Num1")&&(m.pts||0)>0){m.attrs.str++;m.pts--;_alloc=true;sfx("select.wav");}
      if(keyHit("Num2")&&(m.pts||0)>0){m.attrs.agi++;m.pts--;_alloc=true;sfx("select.wav");}
      if(keyHit("Num3")&&(m.pts||0)>0){m.attrs.int++;m.pts--;_alloc=true;sfx("select.wav");}
      for(var _i=0;_i<3;_i++){var _ax=bx+12+_i*(aw+10);var _ay=dy+36;
        T(ATT[_i][0],_ax+aw/2-16,_ay-2,16,"255;255;255");
        box(_ax,_ay+18,34,30,"20;22;38",255,"70;80;120",2);T("－",_ax+8,_ay+21,20,"255;255;255");
        T(String(m.attrs[ATT[_i][1]]),_ax+aw/2-7,_ay+20,22,C_SELY);
        box(_ax+aw-34,_ay+18,34,30,"20;22;38",255,"70;80;120",2);T("＋",_ax+aw-28,_ay+21,20,(m.pts||0)>0?C_GOLD:C_DIM2);
        if((m.pts||0)>0&&hitRect(_ax+aw-34,_ay+18,34,30)){m.attrs[ATT[_i][1]]++;m.pts--;_alloc=true;sfx("select.wav");}}
      if(_alloc){derive(m);setJ("g_party",ps);}
      dy+=100;
      var _dbh=RB-14-dy;box(bx,dy,bw,_dbh,"34;38;58",230,"10;10;20",2);
      var f0=flags();var _et="";for(var _i=0;_i<TITLES.length;_i++){if(TITLES[_i].id===f0.eqTitle)_et=TITLES[_i].name;}
      var _bl=(m.blessing&&(CONTENT.blessings||{})[m.blessing]);
      T("◆ 詳細屬性",bx+12,dy+8,15,C_GOLD);
      T("幸運 "+m.luck,bx+12,dy+30,15,C_ACC);
      T("特別加護 "+(_bl?_bl.name:"—"),bx+150,dy+30,15,_bl?C_GOLD:C_DIM2);
      T("稱號 "+(_et||"—"),bx+400,dy+30,15,_et?C_GOLD:C_DIM2);
      T("武器熟練度",bx+12,dy+54,13,"136;146;150");
      var WT=[["劍","sword"],["槍","spear"],["斧","axe"],["盾","shield"],["投射","throw"],["杖","staff"],["鎚","hammer"]];
      var pw2=Math.floor((bw-24-6*5)/7);
      for(var _i=0;_i<7;_i++){var _wx=bx+12+_i*(pw2+5);var _v=(m.prof&&m.prof[WT[_i][1]])||0;var _eqt=(m.wtype===WT[_i][1]);
        box(_wx,dy+72,pw2,38,_eqt?"58;64;90":"20;22;40",255,_eqt?C_SELY:"70;80;120",2);
        T(WT[_i][0]+" +"+_v,_wx+8,dy+82,14,_v>0?C_SELY:"160;168;190");}
      T("屬性攻擊加護",bx+12,dy+118,13,"136;146;150");
      var EL=[["土","earth","111;82;40"],["火","fire","168;69;42"],["風","wind","67;128;82"],["水","water","58;112;146"],["冰","ice","80;144;170"],["雷","thunder","160;138;42"],["光","light","184;168;72"],["暗","dark","79;66;112"]];
      var ew=Math.floor((bw-24-7*5)/8);
      for(var _i=0;_i<8;_i++){var _ex=bx+12+_i*(ew+5);var _ev=(m.elem&&m.elem[EL[_i][1]])||0;
        box(_ex,dy+136,ew,40,EL[_i][2],_ev>0?255:120,"10;10;20",2);
        T(EL[_i][0]+(_ev>0?" +"+_ev:" 0"),_ex+7,dy+147,14,_ev>0?"255;255;255":"200;204;214");}
      hint="←→ 分頁　↑↓ 換隊員　1/2/3 或點＋ 配點　Q/E 分類　Esc 關閉";
    } else if(st.cTab===1){
      var SN=SLOTS.length;
      if(!st.eqSwap){if(up&&st.cSel>0){st.cSel--;sfx("cursor.mp3");}if(down&&st.cSel<SN-1){st.cSel++;sfx("cursor.mp3");}}
      if(st.cSel>=SN)st.cSel=SN-1;
      var lw=214;
      for(var _i=0;_i<SN;_i++){var _sk=SLOTS[_i][0];var _eid=m.eq&&m.eq[_sk];var _sy=byy+_i*46;var _sel=(_i===st.cSel&&!st.eqSwap);
        box(bx,_sy,lw,42,_sel?"58;64;90":"20;22;40",_sel?255:212,_sel?C_SELY:"70;80;120",2);
        T(SLOTS[_i][1],bx+8,_sy+4,13,"170;180;220");
        T(_eid?EQ[_eid].name:"— 未裝備",bx+8,_sy+20,15,_eid?"255;255;255":C_DIM2);
        if(hitRect(bx,_sy,lw,42)){st.cSel=_i;st.eqSwap=false;sfx("cursor.mp3");}}
      var rx2=bx+lw+14,rw2=bw-lw-14;
      var curSlot=SLOTS[st.cSel][0],curId=m.eq&&m.eq[curSlot];
      box(rx2,byy,rw2,96,"30;34;54",217,"10;10;20",2);
      if(curId){var e=EQ[curId];T(e.name,rx2+12,byy+8,22,C_GOLD);
        T(SLOTN[e.slot]||"裝備",rx2+12+e.name.length*22+12,byy+15,13,C_ACC);
        T(e.desc||"",rx2+12,byy+42,13,"170;180;200");
        T("效果 "+(eqDesc(e)||"（無屬性加成）"),rx2+12,byy+68,14,C_ACC);}
      else{T("（未裝備）",rx2+12,byy+34,18,C_DIM2);}
      var tp=slotType(curSlot);var _inv=J("g_eqInv",[]);var alts=[],acnt={};
      for(var _i=0;_i<_inv.length;_i++){var _e=EQ[_inv[_i]];if(_e&&_e.slot===tp){if(acnt[_inv[_i]]===undefined){acnt[_inv[_i]]=0;alts.push(_inv[_i]);}acnt[_inv[_i]]++;}}
      alts.sort();
      var opts=[];if(curId)opts.push("__off__");for(var _i=0;_i<alts.length;_i++)opts.push(alts[_i]);
      T("可更換（"+(SLOTN[tp]||"裝備")+"）",rx2,byy+106,15,C_GOLD);
      var doEquip=function(pick){var iv2=J("g_eqInv",[]);
        if(pick==="__off__"){if(m.eq&&m.eq[curSlot]){iv2.push(m.eq[curSlot]);delete m.eq[curSlot];setJ("g_eqInv",iv2);derive(m);setJ("g_party",ps);sfx("select.wav");}}
        else if(pick){var ix=iv2.indexOf(pick);if(ix>=0)iv2.splice(ix,1);if(m.eq[curSlot])iv2.push(m.eq[curSlot]);m.eq[curSlot]=pick;setJ("g_eqInv",iv2);derive(m);setJ("g_party",ps);sfx("learn.mp3");}
        st.eqSwap=false;};
      var listY=byy+130;
      if(st.eqSwap){if(st.eqPick===undefined)st.eqPick=0;if(st.eqPick>=opts.length)st.eqPick=Math.max(0,opts.length-1);
        if(up&&st.eqPick>0){st.eqPick--;sfx("cursor.mp3");}if(down&&st.eqPick<opts.length-1){st.eqPick++;sfx("cursor.mp3");}}
      if(!opts.length){T("（沒有可更換的"+(SLOTN[tp]||"裝備")+"——多探索、多和鎮民聊聊）",rx2,listY,14,"150;160;190");}
      for(var _i=0;_i<opts.length&&_i<8;_i++){var _oy=listY+_i*32;var _sel2=(st.eqSwap&&_i===st.eqPick);
        box(rx2,_oy,rw2,30,_sel2?"58;64;90":"20;22;38",_sel2?255:204,_sel2?C_SELY:"10;10;20",2);
        if(opts[_i]==="__off__"){T("▶ 卸下目前裝備",rx2+10,_oy+6,15,"255;150;150");}
        else{var _e2=EQ[opts[_i]];var sim=JSON.parse(JSON.stringify(m));if(!sim.eq)sim.eq={};sim.eq[curSlot]=opts[_i];derive(sim);
          var _df="";var DK=[["patk","物攻"],["matk","魔攻"],["pdef","物防"],["mdef","魔防"],["dodgeV","閃避"],["critV","會心"],["maxhp","HP"],["maxmp","MP"],["luck","幸運"]];
          for(var _k=0;_k<DK.length;_k++){var a0=m[DK[_k][0]],b0=sim[DK[_k][0]];if(a0!==b0)_df+=DK[_k][1]+(b0>a0?" +":" ")+(Math.round((b0-a0)*10)/10)+" ";}
          T(_e2.name+(acnt[opts[_i]]>1?" x"+acnt[opts[_i]]:""),rx2+10,_oy+6,15,"255;255;255");
          T(_df||"（無變化）",rx2+rw2-300,_oy+7,13,"120;230;150");}
        if(hitRect(rx2,_oy,rw2,30)){doEquip(opts[_i]);}}
      if(enter){if(!st.eqSwap){if(opts.length){st.eqSwap=true;st.eqPick=0;sfx("select.wav");}else sfx("cancel.mp3");}
        else{doEquip(opts[st.eqPick]);}}
      hint=st.eqSwap?"↑↓ 選裝備　Enter 確定　Esc 取消":"↑↓ 選槽位　Enter 更換　←→ 分頁　點立繪◀▶ 換隊員　Esc 關閉";
    } else if(st.cTab===2){
      var sl=skillList(m);
      if(!st.skUse){if(up&&st.cSel>0){st.cSel--;sfx("cursor.mp3");}if(down&&st.cSel<sl.length-1){st.cSel++;sfx("cursor.mp3");}}
      if(st.cSel>=sl.length)st.cSel=Math.max(0,sl.length-1);
      T("技能點 "+(m.spts||0),bx+bw-150,byy-4,16,(m.spts||0)>0?C_SELY:"170;180;220");
      var ATG={fire:"火",wind:"風",water:"水",earth:"土",ice:"冰",thunder:"雷",light:"光",dark:"暗"};
      for(var _i=0;_i<sl.length&&_i<5;_i++){var sk1=sl[_i];var slv=m.sk[sk1.id];var _yy=byy+18+_i*74;var _sel=(_i===st.cSel);
        box(bx,_yy,bw,68,_sel?"58;64;90":"22;24;40",_sel?255:212,_sel?C_SELY:"70;80;120",2);
        T(sk1.name,bx+14,_yy+8,18,"255;255;255");
        T(sk1.attr==="int"?"魔法":"物理",bx+14+sk1.name.length*18+12,_yy+11,12,C_ACC);
        if(sk1.element)T(ATG[sk1.element]||sk1.element,bx+14+sk1.name.length*18+60,_yy+11,12,C_GOLD);
        T("MP"+sk1.mp,bx+bw-268,_yy+10,13,"170;180;220");
        var pw1=skPow(sk1,slv);T((sk1.attr==="int"?"魔攻":"物攻")+"x"+(sk1.mult*pw1).toFixed(2),bx+bw-206,_yy+10,13,"170;180;220");
        T("Lv"+slv+"/"+C_DERIVED.skillMaxLv,bx+14,_yy+40,13,C_GOLD);
        bar(bx+96,_yy+42,bw-330,12,slv/C_DERIVED.skillMaxLv,"208;133;74");
        var _canUp=(m.spts||0)>0&&slv<C_DERIVED.skillMaxLv;
        box(bx+bw-98,_yy+36,86,26,"20;22;38",255,"70;80;120",2);T("升級",bx+bw-80,_yy+40,15,_canUp?C_GOLD:C_DIM2);
        if(hitRect(bx+bw-98,_yy+36,86,26)&&_canUp){m.sk[sk1.id]++;m.spts--;derive(m);setJ("g_party",ps);sfx("learn.mp3");}
        if(sk1.kind==="heal"){box(bx+bw-192,_yy+36,86,26,"20;22;38",255,"70;80;120",2);T("使用",bx+bw-174,_yy+40,15,C_ACC);
          if(hitRect(bx+bw-192,_yy+36,86,26)){st.skUse=sk1.id;st.skWho=0;sfx("select.wav");}}
        if(hitRect(bx,_yy,bw-200,68)){st.cSel=_i;sfx("cursor.mp3");}}
      if(!sl.length)T("（尚未習得技能）",bx+12,byy+30,16,C_DIM2);
      if(enter&&!st.skUse&&sl[st.cSel]){var sk0=sl[st.cSel];
        if((m.spts||0)>0&&m.sk[sk0.id]<C_DERIVED.skillMaxLv){m.sk[sk0.id]++;m.spts--;derive(m);setJ("g_party",ps);sfx("learn.mp3");}else sfx("cancel.mp3");}
      if(st.skUse){var sk2=null;for(var _i=0;_i<CONTENT.skills.length;_i++)if(CONTENT.skills[_i].id===st.skUse)sk2=CONTENT.skills[_i];
        fillR(RX,BODY_Y,RW,RB-BODY_Y,"8;9;18",190);
        box(RX+40,BODY_Y+34,RW-80,60+ps.length*46,"30;34;54",244,C_SELY,2);
        T("以「"+(sk2?sk2.name:"")+"」治療誰？（MP"+(sk2?sk2.mp:0)+"）",RX+58,BODY_Y+48,17,C_GOLD);
        if(up&&st.skWho>0){st.skWho--;sfx("cursor.mp3");}if(down&&st.skWho<ps.length-1){st.skWho++;sfx("cursor.mp3");}
        for(var _i=0;_i<ps.length;_i++){var mm=ps[_i];derive(mm);var _ty2=BODY_Y+82+_i*46;var _sw2=(_i===st.skWho);
          box(RX+58,_ty2,RW-116,40,_sw2?"58;64;90":"20;22;38",_sw2?255:212,_sw2?C_SELY:"70;80;120",2);
          T(mm.name+"　HP "+mm.hp+"/"+mm.maxhp,RX+72,_ty2+10,16,"255;255;255");
          if(hitRect(RX+58,_ty2,RW-116,40)){st.skWho=_i;}}
        if(enter&&sk2){var tgt=ps[st.skWho];derive(tgt);
          if(m.mp<sk2.mp){sfx("cancel.mp3");}else if(tgt.hp>=tgt.maxhp){sfx("cancel.mp3");}
          else{var pw3=skPow(sk2,(m.sk&&m.sk[sk2.id])||1);var heal=Math.round((m.matk*sk2.mult+sk2.flat)*pw3);
            tgt.hp=Math.min(tgt.maxhp,tgt.hp+heal);m.mp-=sk2.mp;derive(m);setJ("g_party",ps);sfx("heal.wav");st.skUse=null;}}
        hint="↑↓ 選對象　Enter 施放　Esc 取消";}
      else{hint="←→ 分頁　↑↓ 選技能　Enter 升級　Q/E 分類　Esc 關閉";}
    } else {
      if(ps.length>1){if(up){st.cMem=(st.cMem+ps.length-1)%ps.length;sfx("cursor.mp3");}else if(down){st.cMem=(st.cMem+1)%ps.length;sfx("cursor.mp3");}}
      m=ps[st.cMem];
      var pd0=pDef(m.id)||{};
      var _iw=Math.floor((bw-2*10)/3);
      var INF=[["年齡",pd0.age!==undefined?pd0.age:"—"],["出身",pd0.origin||"—"],["武器傾向",pd0.weaponTendency||"—"]];
      for(var _i=0;_i<3;_i++){var _ix=bx+_i*(_iw+10);box(_ix,byy,_iw,54,"30;34;54",214,"10;10;20",2);
        T(INF[_i][0],_ix+10,byy+8,13,"170;180;220");T(String(INF[_i][1]),_ix+10,byy+26,18,C_ACC);}
      var sy2=byy+66;box(bx,sy2,bw,RB-14-sy2,"22;24;40",214,"10;10;20",2);
      T("◆ 人物誌",bx+12,sy2+10,16,C_GOLD);
      var stv=pd0.story||["（沒有相關紀錄）"];
      for(var _i=0;_i<stv.length&&_i<8;_i++)T(stv[_i],bx+14,sy2+40+_i*28,15,"230;232;240");
      hint="←→ 分頁　↑↓ 換隊員　Q/E 分類　Esc 關閉";
    }
    var _mh=one("MenuHint");if(_mh){_mh.hide(false);_mh.setString(hint);_mh.setX(RX);_mh.setY(RB+2);if(_mh.setCharacterSize)_mh.setCharacterSize(15);}
    ["MenuPanel","RowHi","MenuMap","MenuFace","MenuTitle"].forEach(function(n){var o=one(n);if(o)o.hide(true);});
    rs.getObjects("BarBg").forEach(function(o){o.hide(true);});rs.getObjects("BarFill").forEach(function(o){o.hide(true);});
    for(var _z=_ti;_z<64;_z++){var _o=one("MRow"+_z);if(_o)_o.hide(true);}
  } else {
    box(130,66,1020,556,"16;18;32",236,"10;10;20",2);   // 其他分頁：面板深底（壓掉 menubg 浮水印，與角色頁一致）
    if(st.tab===1){
      if(st.iMode===undefined)st.iMode="list";
      if(st.iSel===undefined)st.iSel=0;
      if(st.iWho===undefined)st.iWho=0;
      var iv=invAll();
      var cons=[],mats=[],keys=[];
      for(var i=0;i<(CONTENT.items||[]).length;i++){var it=CONTENT.items[i];var q=iv[it.id]||0;if(q<=0)continue;
        if(it.cat==="consumable")cons.push({id:it.id,n:q,meta:it});
        else if(it.cat==="material")mats.push({id:it.id,n:q,meta:it});
        else if(it.cat==="key")keys.push({id:it.id,n:q,meta:it});}
      if(st.iSel>=cons.length)st.iSel=Math.max(0,cons.length-1);
      if(st.iMode==="who"&&!cons.length)st.iMode="list";
      if(st.iMode==="list"){
        if(up&&st.iSel>0){st.iSel--;sfx("cursor.mp3");}
        if(down&&st.iSel<cons.length-1){st.iSel++;sfx("cursor.mp3");}
        rows.push({t:"── 道具袋 ──　消耗品",c:C_ACC,x:180,y:150});
        if(!cons.length)rows.push({t:"（沒有可用的消耗品——去吉德的道具店補貨吧）",c:"150;160;190",x:180,y:200});
        for(var i=0;i<cons.length&&i<8;i++){var c0=cons[i];
          rows.push({t:(i===st.iSel?"▶ ":"　 ")+c0.meta.name+"　×"+c0.n,sel:i===st.iSel,x:180,y:200+i*30,hw:460});}
        if(cons[st.iSel]){var sc=cons[st.iSel].meta;var usable=(sc.kind==="heal"||sc.kind==="mp");
          rows.push({t:"效果：　"+(sc.effect||"（無說明）"),c:"170;220;235",x:180,y:472,hw:520});
          rows.push({t:usable?"→ Enter 選擇使用對象":"→ 此道具目前無法在選單中使用",c:usable?"150;230;150":"170;150;150",x:180,y:504});}
        var ry0=200;
        rows.push({t:"─ 素材 ─",c:C_DIM,x:700,y:ry0});ry0+=28;
        if(!mats.length){rows.push({t:"（無）",c:"110;120;140",x:720,y:ry0});ry0+=26;}
        for(var i=0;i<mats.length&&i<6;i++){rows.push({t:mats[i].meta.name+"　×"+mats[i].n,c:"205;205;215",x:720,y:ry0});ry0+=26;}
        rows.push({t:"─ 重要物品 ─",c:C_DIM,x:700,y:ry0});ry0+=28;
        if(!keys.length){rows.push({t:"（無）",c:"110;120;140",x:720,y:ry0});ry0+=26;}
        for(var i=0;i<keys.length&&i<4;i++){rows.push({t:keys[i].meta.name,c:"205;205;215",x:720,y:ry0});ry0+=26;}
        if(enter&&cons[st.iSel]){var sc2=cons[st.iSel].meta;
          if(sc2.kind==="heal"||sc2.kind==="mp"){st.iMode="who";st.iWho=0;sfx("select.wav");}
          else sfx("cancel.mp3");}
        hint="↑↓ 選道具　Enter 使用　←→/Q/E 分頁　Esc 關閉";
      } else {
        var it2=cons[st.iSel];var isMp=(it2.meta.kind==="mp");
        if(up&&st.iWho>0){st.iWho--;sfx("cursor.mp3");}
        if(down&&st.iWho<ps.length-1){st.iWho++;sfx("cursor.mp3");}
        if(ps[st.iWho])showFace=ps[st.iWho].id;
        rows.push({t:"對誰使用：　"+it2.meta.name+"　×"+it2.n+"　"+(it2.meta.effect||""),c:C_ACC,x:180,y:150,hw:900});
        for(var i=0;i<ps.length;i++){var mm=ps[i];derive(mm);
          var y0=224+i*64;
          rows.push({t:(i===st.iWho?"▶ ":"　 ")+mm.name+"　Lv"+mm.lv,sel:i===st.iWho,x:180,y:y0,hw:820});
          rows.push({t:"HP "+mm.hp+"/"+mm.maxhp,x:220,y:y0+30});
          barsp.push({x:390,y:y0+38,w:150,cur:mm.hp,max:mm.maxhp,kind:"hp"});
          rows.push({t:"MP "+mm.mp+"/"+mm.maxmp,x:600,y:y0+30});
          barsp.push({x:760,y:y0+38,w:150,cur:mm.mp,max:mm.maxmp,kind:"mp"});}
        if(enter&&ps[st.iWho]){var tgt=ps[st.iWho];derive(tgt);
          var full=isMp?(tgt.mp>=tgt.maxmp):(tgt.hp>=tgt.maxhp);
          if(full)sfx("cancel.mp3");
          else{var pw=it2.meta.power||0;
            if(isMp)tgt.mp=Math.min(tgt.maxmp,tgt.mp+pw);
            else tgt.hp=Math.min(tgt.maxhp,tgt.hp+pw);
            invUse(it2.id);setJ("g_party",ps);sfx("heal.wav");
            if(invGet(it2.id)<=0)st.iMode="list";}}
        hint="↑↓ 選隊員　Enter 使用　Esc 返回";
      }
    } else if(st.tab===2){
      showMap=true;
      var LOC={Town:"芳蕾鎮",Forest:"東之森",Forest2:"東之森深處",Mine:"礦山外圍",Cave:"礦山洞穴"};
      rows.push({t:"現在位置：{loc}　（南方大道/西方迷霧森林 目前封鎖中）".replace("{loc}",LOC[CFG.SCENE]||CFG.SCENE),c:C_GOLD});
      var PM=(CONTENT.pacing&&CONTENT.pacing.maps)||{};
      var lvR=function(k){var p=PM[k];return p?("Lv"+p.entryLv+"-"+p.targetLv):"—";};
      rows.push({t:"建議等級　東之森 "+lvR("forest")+"　森林深處 "+lvR("forest2")+"　礦山 "+lvR("mine")+"　洞穴 "+lvR("cave"),
        x:330,y:512,c:C_ACC});
    } else if(st.tab===3){
      if(up&&st.sel>0){st.sel--;sfx("cursor.mp3");}
      if(down&&st.sel<TITLES.length-1){st.sel++;sfx("cursor.mp3");}
      var f10=flags();
      rows.push({t:"── 稱號（Enter 佩戴）──",c:C_ACC});
      for(var i=0;i<TITLES.length;i++){var tt=TITLES[i];var got=titleEarned(tt);
        var tag=(f10.eqTitle===tt.id)?"【佩戴中】":"";
        rows.push({t:(i===st.sel?"▶ ":"　 ")+(got?tt.name+"　"+tag+"　— "+tt.desc:"？？？　— "+tt.hint),
                   sel:i===st.sel,c:got?null:"110;120;140"});}
      if(enter){var tt2=TITLES[st.sel];
        if(titleEarned(tt2)){var f11=flags();f11.eqTitle=tt2.id;setJ("g_flags",f11);sfx("select.wav");}
        else sfx("cancel.mp3");
      }
      hint="↑↓ 選稱號　Enter 佩戴　←→ 分頁　Esc 關閉";
    } else {
      if(up&&st.sel>0){st.sel--;st.confirmQuit=false;sfx("cursor.mp3");}
      if(down&&st.sel<1){st.sel++;sfx("cursor.mp3");}
      rows.push({t:(st.sel===0?"▶ ":"　 ")+"操作說明",sel:st.sel===0});
      rows.push({t:(st.sel===1?"▶ ":"　 ")+(st.confirmQuit?"回到標題畫面（再按一次 Enter 確認，進度不保存！）":"回到標題畫面"),sel:st.sel===1,
                 c:st.confirmQuit?"255;150;150":null});
      rows.push({t:""});
      rows.push({t:"　方向鍵：移動　空白鍵：交談/推進對話",c:"170;180;220"});
      rows.push({t:"　M / Esc：選單　戰鬥：方向鍵+Enter 或 滑鼠點擊",c:"170;180;220"});
      rows.push({t:"　旅店（瑪琳家）與神殿可免費全恢復",c:"170;180;220"});
      if(enter&&st.sel===1){
        if(!st.confirmQuit){st.confirmQuit=true;sfx("cancel.mp3");}
        else{gdjs.evtTools.runtimeScene.replaceScene(rs,"Title",true);return;}
      }
      hint="↑↓ 選擇　Enter 執行　←→ 分頁　Esc 關閉";
    }
    renderPanel(rows,barsp,{title:TABS[st.tab],showFace:showFace,showArt:showArt,showMap:showMap,hint:hint,tab:null});
  }
} else if(st.shop){
  // ---------- 商店（買/賣兩頁籤，複用選單面板元件）----------
  lock=true;
  (function(){var _mb=one("MenuBg");if(_mb)_mb.hide(true);for(var _tj=0;_tj<7;_tj++){var _to=one("MTop"+_tj);if(_to)_to.hide(true);}})();
  var shopDef=(CONTENT.shops||{})[st.shop.id]||{name:"商店",sell:[]};
  var fsh=flags();
  // 買清單：tier>=2 需第二章旗標 ch2（目前恆未進貨）
  var buyList=[];
  for(var i=0;i<shopDef.sell.length;i++){var bm=itemMeta(shopDef.sell[i]);
    if(bm&&!(bm.tier&&bm.tier>=2&&!fsh.ch2))buyList.push(bm);}
  // 賣清單：背包內 sell>0 的道具 ＋ 裝備袋內 sell>0 的裝備
  var sellList=[];var ivS=invAll();
  for(var i=0;i<(CONTENT.items||[]).length;i++){var it0=CONTENT.items[i];var q=ivS[it0.id]||0;
    if(q>0){var sm=itemMeta(it0.id);if(sm&&sm.sell>0){sm.count=q;sellList.push(sm);}}}
  var eqS=J("g_eqInv",[]);var ecnt={},euniq=[];
  for(var i=0;i<eqS.length;i++){if(!EQ[eqS[i]])continue;
    if(ecnt[eqS[i]]===undefined){ecnt[eqS[i]]=0;euniq.push(eqS[i]);}ecnt[eqS[i]]++;}
  for(var i=0;i<euniq.length;i++){var sm2=itemMeta(euniq[i]);if(sm2&&sm2.sell>0){sm2.count=ecnt[euniq[i]];sellList.push(sm2);}}
  // 輸入
  if(keyHit("Left")||keyHit("Right")){st.shop.tab^=1;st.shop.sel=0;st.shop.msg="";sfx("cursor.mp3");}
  var list=st.shop.tab===0?buyList:sellList;
  if(st.shop.sel>=list.length)st.shop.sel=Math.max(0,list.length-1);
  if(keyHit("Up")&&st.shop.sel>0){st.shop.sel--;st.shop.msg="";sfx("cursor.mp3");}
  if(keyHit("Down")&&st.shop.sel<list.length-1){st.shop.sel++;st.shop.msg="";sfx("cursor.mp3");}
  var shEnter=keyHit("Return")||keyHit("Space");
  if(keyHit("Escape")){st.shop=null;sfx("cancel.mp3");}
  else if(shEnter&&list[st.shop.sel]){
    var tr=list[st.shop.sel];var gold=g.get("g_gold").getAsNumber();
    if(st.shop.tab===0){
      if(tr.buy<=0){st.shop.msg="這件不賣。";sfx("cancel.mp3");}
      else if(gold<tr.buy){st.shop.msg="金幣不足！";sfx("cancel.mp3");}
      else{g.get("g_gold").setNumber(gold-tr.buy);
        if(tr.kind==="eq"){var iv3=J("g_eqInv",[]);iv3.push(tr.id);setJ("g_eqInv",iv3);}
        else invAdd(tr.id,1);
        st.shop.msg="購買了 "+tr.name+"（-"+tr.buy+"G）";sfx("select.wav");}
    }else{
      g.get("g_gold").setNumber(gold+tr.sell);
      if(tr.kind==="eq"){var iv4=J("g_eqInv",[]);var ix4=iv4.indexOf(tr.id);if(ix4>=0)iv4.splice(ix4,1);setJ("g_eqInv",iv4);}
      else invUse(tr.id);
      st.shop.msg="賣出 "+tr.name+"（+"+tr.sell+"G）";sfx("win.wav");
      if(st.shop.sel>0&&st.shop.sel>=list.length-1)st.shop.sel--;
    }
    saveGame();   // 買/賣後金幣與背包變動 → 自動存檔
  }
  // 渲染（Esc 已把 st.shop 設為 null 時跳過，下一幀由 else 分支收起面板）
  if(st.shop){
    var rows=[],barsp=[];
    var vlist=st.shop.tab===0?buyList:sellList;
    var base=Math.max(0,Math.min(st.shop.sel-5,vlist.length-11));if(base<0)base=0;
    if(!vlist.length)rows.push({t:st.shop.tab===0?"（目前沒有進貨的商品）":"（沒有可販售的道具或裝備）",c:C_DIM,x:180,y:214});
    for(var i=base;i<vlist.length&&i<base+11;i++){var vi=vlist[i];
      var line;
      if(st.shop.tab===0){var owned=vi.kind==="item"?invGet(vi.id):0;
        var afford=g.get("g_gold").getAsNumber()>=vi.buy;
        line={t:(i===st.shop.sel?"▶ ":"　 ")+"［"+vi.label+"］"+vi.name+"　"+vi.buy+"G"+(owned>0?"（持有 "+owned+"）":""),
          sel:i===st.shop.sel,c:afford?null:"170;140;140",x:180,y:206+(i-base)*26,hw:920};
      }else{line={t:(i===st.shop.sel?"▶ ":"　 ")+"［"+vi.label+"］"+vi.name+"　×"+vi.count+"　售 "+vi.sell+"G",
          sel:i===st.shop.sel,x:180,y:206+(i-base)*26,hw:920};}
      rows.push(line);
    }
    if(vlist[st.shop.sel])rows.push({t:"　"+(vlist[st.shop.sel].desc||"（無說明）"),c:"170;220;235",x:180,y:508,hw:960});
    var tabStr=(st.shop.tab===0?"【購買】":" 購買 ")+"　"+(st.shop.tab===1?"【販售】":" 販售 ");
    var shHint=(st.shop.msg?st.shop.msg+"　　":"")+"←→ 買/賣　↑↓ 選　Enter 成交　Esc 離開";
    renderPanel(rows,barsp,{title:shopDef.name,tab:tabStr,hint:shHint});
  }
} else {
  var hideM=["MenuPanel","MenuTitle","MenuTab","MenuHint","MenuFace","MenuArt","MenuMap","MenuBg"];
  for(var hj=0;hj<64;hj++)hideM.push("MRow"+hj);
  for(var hj=0;hj<7;hj++)hideM.push("MTop"+hj);
  hideM.forEach(function(n){var o=one(n);if(o)o.hide(true);});
  ["RowHi","BarBg","BarFill"].forEach(function(n){rs.getObjects(n).forEach(function(o){o.hide(true);});});
}
b.ignoreDefaultControls(lock);
if(!st.dlg&&!st.cut){var pn=one("DlgPanel"),dn=one("DlgName"),dx=one("DlgText"),df=one("DlgFace"),da=one("DlgArt");
  if(pn)pn.hide(true);if(dn)dn.hide(true);if(dx)dx.hide(true);if(df)df.hide(true);if(da)da.hide(true);}

// ---------- 移動/碰撞/動畫 ----------
var ft=feet(p);
if(st.inside&&st.intMode==="menu"){
  // 立繪＋選單式室內：不走動（玩家隱藏），移動/碰撞整段略過。
}else if(st.inside){
  // 室內：夾在牆內可行走矩形，且腳底不得進入任一家具 footprint（可碰撞家具＝真的擋路）。底部中央為出口。
  var rb=st.room, fr=st.furn||[];
  var offx=ft[0]-p.getX(), offy=ft[1]-p.getY();
  var nx=Math.max(rb.l,Math.min(rb.r,ft[0]));
  var ny=Math.max(rb.t,Math.min(rb.b,ft[1]));
  function inFurn(px,py){for(var i=0;i<fr.length;i++){var R=fr[i];if(px>R[0]&&px<R[2]&&py>R[1]&&py<R[3])return true;}return false;}
  if(inFurn(nx,ny)){                             // 分軸退讓→可沿家具邊緣滑動、不會整個卡死
    var lx2=st.last[0]+offx, ly2=st.last[1]+offy;
    if(!inFurn(nx,ly2)) ny=ly2;
    else if(!inFurn(lx2,ny)) nx=lx2;
    else { nx=lx2; ny=ly2; }
  }
  p.setX(nx-offx); p.setY(ny-offy);
  st.last=[p.getX(),p.getY()]; ft=feet(p);
  var inExit=(ft[0]>rb.exL && ft[0]<rb.exR && ft[1]>rb.exY);
  if(!inExit) st.exitArmed=true;               // 離開出口區才 arm，回到出口區即離場
  if(inExit&&st.exitArmed) exitBuilding();
}else if(blocked(ft[0],ft[1])){p.setX(st.last[0]);p.setY(st.last[1]);}
else{st.last=[p.getX(),p.getY()];}
var ang=((b.getAngle()%360)+360)%360,dir;
if(ang>=45&&ang<135)dir="Down";else if(ang>=135&&ang<225)dir="Left";
else if(ang>=225&&ang<315)dir="Up";else dir="Right";
var walking=b.isMoving()&&!lock;
p.setAnimationName((walking?"Walk":"Idle")+dir);
p.setZOrder(baseZ(p));

// ---------- 隊伍排隊跟隨（室內不跟隨） ----------
if(st.inside){
  rs.getObjects("Follower").forEach(function(o){o.hide(true);});
}else{
if(!st.trail){st.trail=[];for(var i=0;i<160;i++)st.trail.push([p.getX(),p.getY(),"Down"]);}
var hd=st.trail[0];
var mdx=p.getX()-hd[0],mdy=p.getY()-hd[1];
if(mdx*mdx+mdy*mdy>=16){st.trail.unshift([p.getX(),p.getY(),dir]);if(st.trail.length>160)st.trail.pop();}
var ps9=party();
var fobjs=rs.getObjects("Follower");
var FSPRITES={marin:1,aaron:1};
var fi=0;
for(var i=1;i<ps9.length&&i<4;i++){
  var mem=ps9[i];
  if(fi>=fobjs.length)break;
  var fo=fobjs[fi];fi++;
  if(!FSPRITES[mem.sprite]){fo.hide(true);continue;}
  var idx=Math.min(st.trail.length-1,i*13);
  var pt=st.trail[idx];
  fo.hide(false);fo.setX(pt[0]);fo.setY(pt[1]);
  fo.setAnimationName(mem.sprite+"_"+(walking?"Walk":"Idle")+pt[2]);
  fo.setZOrder(baseZ(fo));
}
for(;fi<fobjs.length;fi++)fobjs[fi].hide(true);
}

// ---------- 出口/觸發區 ----------
if(!st.armed)st.armed={};
for(var i=0;i<(CFG.exits||[]).length;i++){
  var e0=CFG.exits[i];
  var inside0=(ft[0]>=e0.r[0]&&ft[0]<=e0.r[2]&&ft[1]>=e0.r[1]&&ft[1]<=e0.r[3]);
  if(!inside0)st.armed[i]=true;
}
if(!lock&&!st.inside){
  for(var i=0;i<(CFG.exits||[]).length;i++){
    var e=CFG.exits[i];
    if(st.armed[i]&&ft[0]>=e.r[0]&&ft[0]<=e.r[2]&&ft[1]>=e.r[1]&&ft[1]<=e.r[3]){
      if(e.minStep!==undefined&&f.step<e.minStep){
        var pr2=one("Prompt"); if(pr2){pr2.hide(false);pr2.setString(e.deny||"現在還不能離開");}
        p.setX(st.last[0]=st.last[0]+(e.pushX||0)); p.setY(st.last[1]=st.last[1]+(e.pushY||0));
        break;
      }
      g.get("g_spawn").setString(e.spawn);
      gdjs.evtTools.runtimeScene.replaceScene(rs,e.to,true); return;
    }
  }
  for(var i=0;i<(CFG.triggers||[]).length;i++){
    var t=CFG.triggers[i];
    if(ft[0]>=t.r[0]&&ft[0]<=t.r[2]&&ft[1]>=t.r[1]&&ft[1]<=t.r[3]){
      var f8=flags();
      if(!matchWhen(f8,t.when))continue;              // 旗標閘門（無 when=永遠成立）
      if(t.cut){var cc=CUTS[t.cut];
        var okStep=(t.step===undefined)||(f8.step===t.step);
        if(okStep&&!(cc.once&&f8[cc.once])){st.queue.push(t.cut);break;}
      }
      if(t.msg){
        var okS=(t.minStep===undefined)||(f8.step>=t.minStep);
        if(okS){var pr3=one("Prompt");if(pr3){pr3.hide(false);pr3.setString(t.msg);}break;}
      }
    }
  }
}

// ---------- 高草遇敵 ----------
if(!lock&&st.grace<=0&&b.isMoving()&&inEnc(ft[0],ft[1])&&CFG.encGroup){
  st.enc+=b.getSpeed()*dt;
  if(st.enc>=st.encNext){
    g.get("g_returnScene").setString(CFG.SCENE);
    g.get("g_returnX").setNumber(p.getX());g.get("g_returnY").setNumber(p.getY());
    g.get("g_encounter").setString(CFG.encGroup==="mine_step0"?(f.step===0?"tutorial":"mine"):CFG.encGroup);
    sfx("magic.wav");
    gdjs.evtTools.runtimeScene.replaceScene(rs,"Battle",true);return;
  }
}
// ---------- 頭目 ----------
var bm=one("BossMark");
if(bm&&!bm.isHidden()&&!lock){
  var bx=(bm.getX()+bm.getWidth()/2)-(p.getX()+p.getWidth()/2);
  var by=(bm.getY()+bm.getHeight()/2)-(p.getY()+p.getHeight()/2);
  if(Math.sqrt(bx*bx+by*by)<80){
    g.get("g_returnScene").setString(CFG.SCENE);
    g.get("g_returnX").setNumber(p.getX()-90);g.get("g_returnY").setNumber(p.getY());
    g.get("g_encounter").setString("ch1_boss");
    sfx("hurt.wav");
    gdjs.evtTools.runtimeScene.replaceScene(rs,"Battle",true);return;
  }
}
if(bm){var f9=flags();if(f9.ch1!==1)bm.hide(true);}
// 章末精英：狂暴洞熊（ch2==1 顯示；戰勝→ch2=2 自動隱藏，戰敗/逃走仍可重試）
var brm2=one("BearMark");
if(brm2&&!brm2.isHidden()&&!lock){
  var wx=(brm2.getX()+brm2.getWidth()/2)-(p.getX()+p.getWidth()/2);
  var wy=(brm2.getY()+brm2.getHeight()/2)-(p.getY()+p.getHeight()/2);
  if(Math.sqrt(wx*wx+wy*wy)<80){
    g.get("g_returnScene").setString(CFG.SCENE);
    g.get("g_returnX").setNumber(p.getX());g.get("g_returnY").setNumber(p.getY()+90);
    g.get("g_encounter").setString("ch2_bear");
    sfx("hurt.wav");
    gdjs.evtTools.runtimeScene.replaceScene(rs,"Battle",true);return;
  }
}
if(brm2){if(flags().ch2!==1)brm2.hide(true);}

// ---------- 撿取物（支線採集：鏡草／遺物）----------
if(CFG.pickups){
  var fpk=flags();
  for(var pi=0;pi<CFG.pickups.length;pi++){
    var pk=CFG.pickups[pi]; var po=one(pk.obj); if(!po)continue;
    var pdone=pk.once&&fpk[pk.once];
    var pshown=matchWhen(fpk,pk.showWhen)&&!pdone;
    po.hide(!pshown);
    if(pshown&&!lock&&!st.inside&&ft[0]>=pk.r[0]&&ft[0]<=pk.r[2]&&ft[1]>=pk.r[1]&&ft[1]<=pk.r[3]){
      if(pk.op==="inc")fpk[pk.flag]=(fpk[pk.flag]||0)+1; else fpk[pk.flag]=pk.val;
      if(pk.once)fpk[pk.once]=1; setJ("g_flags",fpk);
      if(pk.item)invAdd(pk.item,1);
      po.hide(true);
      if(pk.msg){var prp=one("Prompt");if(prp){prp.hide(false);prp.setString(pk.msg);}}
      sfx(pk.sfx||"select.wav"); saveGame();
    }
  }
}

// ---------- HUD ----------（選單/商店開啟時隱藏，避免與頂框重疊）
var _hudHide=(!!st.menu||!!st.shop);
var hp=one("HudParty");
if(hp){if(_hudHide)hp.hide(true);else{hp.hide(false);var ps=party();hp.setString(ps.map(function(m){derive(m);return m.name+" Lv"+m.lv+" "+m.hp+"/"+m.maxhp;}).join("   "));}}
var hg=one("HudGold");
if(hg){if(_hudHide)hg.hide(true);else{hg.hide(false);
  var f12=flags();var eq=null;
  for(var i=0;i<TITLES.length;i++){if(TITLES[i].id===f12.eqTitle)eq=TITLES[i].name;}
  hg.setString((eq?"〈"+eq+"〉　":"")+"金幣 "+g.get("g_gold").getAsNumber()+"　[M]選單");
}}
var goal=one("HudGoal");
if(goal&&_hudHide){goal.hide(true);}
else if(goal){goal.hide(false);
  var t="";
  if(f.step===0&&CFG.SCENE==="Town")t="▶ 逛逛鎮子，準備好就從北出口前往礦山";
  else if(f.step===0)t="▶ 跟著亞倫深入礦山（往北）";
  else if(f.step<3)t="▶ 逃出洞穴";
  else if(!f.reg)t="▶ 到公會找緹娜登錄冒險者";
  else if(f.ch1===0)t="▶ 找緹娜接委託";
  else if(f.ch1===1)t="▶ 討伐東之森深處的哥布林頭目";
  else if(f.ch1===2)t="▶ 回公會向緹娜回報";
  else if(f.ch1===3&&!f.ch2)t="▶ 找水井旁的老葛雷打聽礦山的委託";
  else if(f.ch2===1)t="▶ 前往北方礦山外圍，查明礦工失蹤真相";
  else if(f.ch2===2)t="▶ 回鎮上向老葛雷回報所見";
  else t="▶ 第二章完！深入礦坑洞穴、追查邪氣源頭（第三章敬請期待）";
  goal.setString(t);
}
// 相機：室外 1.8x 跟隨；室內 1.15x 鎖定室內中心（放大房間後 zoom 降低才容得下全景）
var cam=rs.getLayer("");
if(st.inside){
  cam.setCameraZoom(st.intZoom||1.15);
  cam.setCameraX(st.intCam[0]); cam.setCameraY(st.intCam[1]);
}else{
  var Z=1.8; cam.setCameraZoom(Z);
  var hw=640/Z, hh=360/Z;
  cam.setCameraX(Math.max(hw,Math.min(CFG.MW*TS-hw,p.getX()+p.getWidth()/2)));
  cam.setCameraY(Math.max(hh,Math.min(CFG.MH*TS-hh,p.getY()+p.getHeight()/2)));
}
st.dlgPrev=!!st.dlg;   // 記錄本幀對話狀態→下幀立繪選單用來略過「關閉對話那次按鍵」
try{window.__B=null;window.__G=g;}catch(e){}   // 清掉戰鬥殘留掛勾；__G=全域變數容器（E2E 佈置背包/隊伍用）
try{window.__W={scene:CFG.SCENE,x:Math.round(p.getX()),y:Math.round(p.getY()),
  lock:lock,step:f.step,reg:f.reg||0,ch1:f.ch1||0,ch2:f.ch2||0,flags:f,gold:g.get("g_gold").getAsNumber(),
  cutQ:st.queue.length,inEnc:st.inside?false:inEnc(ft[0],ft[1]),inside:st.inside||"",
  pft:[Math.floor(ft[0]/TS),Math.floor(ft[1]/TS)],nearNpc:st.nearNpc||"",nearDoor:st.nearDoor||"",
  nearChest:st.nearChest||"",chestsSaved:J("g_chests",[]),
  chests:st.chests?st.chests.map(function(c){return {id:c.d.id,tier:c.d.tier,opened:c.opened};}):[],
  dlg:st.dlg?{name:st.dlg.name,line:st.dlg.lines[st.dlgIdx]||""}:null,
  menu:!!st.menu,tab:st.tab||0,mMode:st.mMode||"",mPage:st.mPage||0,eqMode:st.eqMode||"",
  iMode:st.iMode||"",shop:st.shop?st.shop.id:"",shopTab:st.shop?st.shop.tab:-1,shopSel:st.shop?st.shop.sel:-1,
  itemInv:invAll(),
  inv:J("g_eqInv",[]),
  followers:rs.getObjects("Follower").filter(function(o){return !o.isHidden();}).length,
  party:party().map(function(m){return {id:m.id,lv:m.lv,pts:m.pts||0,spts:m.spts||0,sk:m.sk||{},eq:m.eq||{}};})};
  var mu=rs.getGame().getSoundManager().getMusicOnChannel(1);
  window.__W.mus=!!(mu&&mu.playing());}catch(e){}
"""
TITLES_DATA=[
 {"id":"t_rookie","name":"礦山生還者","req":"step>=3","desc":"歷經礦山的意外而歸來","hint":"完成序章"},
 {"id":"t_f","name":"F級冒險者","req":"reg>=1","desc":"完成冒險者公會登錄","hint":"到公會找緹娜登錄"},
 {"id":"t_gob","name":"哥布林剋星","req":"ch1>=2","desc":"討伐東之森的哥布林頭目","hint":"完成第一章討伐委託"},
 {"id":"t_pride","name":"芳蕾鎮的驕傲","req":"ch1>=3","desc":"向公會回報討伐成果","hint":"回公會領取委託報酬"},
 {"id":"t_miner","name":"礦山的見證者","req":"ch2>=2","desc":"揭開失蹤礦工的真相","hint":"查明礦山外圍的異變"},
 {"id":"t_relic","name":"故人之託","req":"relic>=2","desc":"送還礦工阿吉的遺物","hint":"在礦山深處找回並上繳頭盔"},
]
WORLD_JS = (WORLD_JS.replace("__DLG__",json.dumps(DLG,ensure_ascii=False))
            .replace("__CUTS__",json.dumps(CUTS,ensure_ascii=False))
            .replace("__TITLES__",json.dumps(TITLES_DATA,ensure_ascii=False))
            .replace("__CONTENT__",json.dumps(CONTENT,ensure_ascii=False)))

# ================= 8. 各場景 config =================
def px_rect(x1,y1,x2,y2): return [x1*TS,y1*TS,x2*TS,y2*TS]

# Track J：門口/室內設定
_DOOR_LABEL={"BGuild":"公會","BInn":"旅店","BShrine":"神殿","BMayor":"鎮長宅","BShop":"道具店","BSmith":"鐵匠鋪"}
_DOOR_OWNERS={"BGuild":["NTina"],"BInn":["NDora"],"BShrine":["NSister"],
              "BMayor":["NBarton"],"BShop":["NGid"],"BSmith":["NHank","NMartha"]}
town_doors=[{"obj":o,"tx":BLDG_DOOR[o][0],"ty":BLDG_DOOR[o][1],"key":BLDG_KEY[o],
             "label":_DOOR_LABEL[o],"owners":_DOOR_OWNERS[o]}
            for o in ["BGuild","BInn","BShrine","BMayor","BShop","BSmith"]]
# Track J3：折衷室內——手繪大圖(intc_<key>)當背景 ＋ fraction 定義的隱形碰撞。座標皆為手繪圖 W/H 的比例[l,t,r,b]。
TOWN_INTNAT={BLDG_KEY[o]:list(BLDG_INT[o]) for o in BLDG_INT}   # key -> [原生w,原生h]（供顯示長寬比）
# 只有 guild 已逐一對齊碰撞；其餘先用 default（手繪已上、碰撞待微調，John 先驗公會）
INT_DRAWN={
 "guild":{"room":[0.15,0.52,0.90,0.87],
   "furn":[[0.15,0.55,0.50,0.69],   # 長櫃檯
           [0.55,0.45,0.74,0.58],   # 右上圓桌+椅（吊燈下）
           [0.75,0.56,0.92,0.70],   # 右圓桌+椅
           [0.46,0.71,0.64,0.87]],  # 下方圓桌+椅
   "owners":[[0.46,0.56]],          # (walk 模式用) 緹娜站櫃檯後靠右端
   "entry":[0.68,0.66],"exit":[0.64,0.86,0.80],
   "mode":"menu"},                  # ★立繪＋選單式（不走動）：手繪背景＋緹娜大型立繪＋指令選單
 # 其餘棟同款立繪＋選單式（指令由 buildIntCmds 依 DLG 動態生成、runIntCmd 執行）。
 # 鐵匠鋪(smithy)有 2 owner(漢克+瑪莎)：進場顯示漢克立繪，交談時漢克講完接瑪莎，漢克的商店延到全員談完才開。
 "inn":{"mode":"menu"},"shrine":{"mode":"menu"},"mayor":{"mode":"menu"},"shop":{"mode":"menu"},"smithy":{"mode":"menu"},
}
INT_DRAWN_DEFAULT={"room":[0.20,0.55,0.86,0.86],"furn":[],
   "owners":[[0.30,0.56]],"entry":[0.60,0.72],"exit":[0.44,0.74,0.80]}
town_cfg={"npcs":[{"obj":n["obj"],"id":n["id"],"face":n["face"]} for n in NPCS_TOWN],
 "spawns":{"home":[15*TS,12*TS],"fromForest":[39*TS,14*TS],"fromMine":[21*TS,2*TS],"shrine":[30*TS,10*TS]},
 "doors":town_doors,"outdoorNpcs":["NGray","NMira","NGuard"],
 "intNat":TOWN_INTNAT,"intDrawn":INT_DRAWN,"intDrawnDefault":INT_DRAWN_DEFAULT,
 "exits":[{"r":px_rect(40.4,12.5,42,17),"to":"Forest","spawn":"fromTown","minStep":3,"deny":"瑪琳：先跟亞倫先生去礦山吧！（往北）","pushX":-24},
          {"r":px_rect(19.5,-1,24,0.8),"to":"Mine","spawn":"fromTown"}],
 "triggers":[{"r":px_rect(19.5,28,24,30),"msg":"南方大道封鎖中（找羅素隊長打聽）","minStep":0},
             {"r":px_rect(0,12,1.2,17),"msg":"西邊瀰漫著不自然的濃霧……現在進不去"}],
 "cutOnEnter":[{"cut":"prologue_town","step":0},{"cut":"town_start","step":3}],
 "encGroup":None,"bgm":"bgm_town.mp3"}
forest_cfg={"npcs":[],
 "spawns":{"fromTown":[1*TS+8,15*TS],"fromForest2":[(FW-2)*TS-8,FEY*TS]},
 "exits":[{"r":px_rect(-1,14,0.7,18),"to":"Town","spawn":"fromForest"},
          {"r":px_rect(FW-1.6,FEY-1,FW+0.5,FEY+3),"to":"Forest2","spawn":"fromForest"}],
 "triggers":[],"cutOnEnter":[],"encGroup":"forest","bgm":"bgm_forest.mp3"}
forest2_cfg={"npcs":[],
 "spawns":{"fromForest":[1*TS+8,FEY*TS]},
 "exits":[{"r":px_rect(-1,FEY-1,0.7,FEY+3),"to":"Forest","spawn":"fromForest2"}],
 "triggers":[],"cutOnEnter":[],"encGroup":"forest2","bgm":"bgm_forest.mp3"}
mine_cfg={"npcs":[],
 "spawns":{"start":[21*TS,(MMH-4)*TS],"fromTown":[21*TS,(MMH-3)*TS],"fromCave":[21*TS,4*TS]},
 "exits":[{"r":px_rect(19.5,MMH-0.8,24,MMH+1),"to":"Town","spawn":"fromMine","minStep":3,"deny":"亞倫：現在回頭可不行。","pushY":-20},
          {"r":px_rect(20,1.2,23,2.6),"to":"Cave","spawn":"fromMine"}],
 "triggers":[{"r":px_rect(20,13,23,16),"cut":"mine_truth","when":"ch2>=1"}],
 "cutOnEnter":[{"cut":"mine_intro","step":0}],"encGroup":"mine_step0","bgm":"bgm_dungeon.mp3"}
# 支線 pickups（走過區域→設/加旗標＋加道具＋隱藏 prop，showWhen 閘門；tile 由前段確定性挑選＋連通性 assert 保證）
forest_cfg["pickups"]=[{"r":px_rect(HERB_TILES[_i][0],HERB_TILES[_i][1],HERB_TILES[_i][0]+1,HERB_TILES[_i][1]+1),
    "flag":"herb","op":"inc","once":"herb_p%d"%_i,"obj":"Herb%d"%(_i+1),
    "showWhen":"mira2==1","msg":"（採到一株發光的鏡草！）","sfx":"learn.mp3"} for _i in range(len(HERB_TILES))]
mine_cfg["pickups"]=[{"r":px_rect(RELIC_TILE[0],RELIC_TILE[1],RELIC_TILE[0]+1,RELIC_TILE[1]+1),
    "flag":"relic","op":"set","val":1,"once":"relic_p","obj":"RelicHelmet",
    "showWhen":"ch2>=1","item":"miner_helmet","msg":"（撿到一頂鏽蝕的礦工頭盔……上頭刻著「阿吉」）","sfx":"select.wav"}]
cave_cfg={"npcs":[],
 "spawns":{"fromMine":[17*TS+16,int((CMH-3.5)*TS)]},
 "exits":[{"r":px_rect(16.5,CMH-0.7,20,CMH+1),"to":"Mine","spawn":"fromCave"}],
 "triggers":[{"r":px_rect(14,4,22,8),"cut":"demon_pre","step":0},
             {"r":px_rect(14,5,22,8),"msg":"一道死靈邪氣自更深處的礦道滲出……（第三章敬請期待）","when":"ch2>=2"},
             {"r":px_rect(14,5,22,8),"msg":"深處被落石封住了……得先查明礦山外圍的異變（第二章）","minStep":3}],
 "cutOnEnter":[{"cut":"cave_intro","step":0}],"encGroup":"cave","bgm":"bgm_dungeon.mp3"}

town_sc=build_world_scene("Town",tw,"town",NPCS_TOWN,town_cfg,(15*TS,12*TS))
forest_sc=build_world_scene("Forest",fo,"forest",[],forest_cfg,(2*TS,15*TS))
forest2_sc=build_world_scene("Forest2",fo2,"forest2",[],forest2_cfg,(2*TS,FEY*TS))
mine_sc=build_world_scene("Mine",mi,"mine",[],mine_cfg,(21*TS,(MMH-4)*TS))
cave_sc=build_world_scene("Cave",ca,"cave",[],cave_cfg,(17*TS+16,(CMH-2)*TS))

# ================= 9. Battle v2 =================
battle=scene("Battle",(10,12,15))
RESULT=["OverlayBg","ResultTitle","ResultMsg","BtnCont","TxtCont"]
battle["objects"]=[
  sprite("Bg",[anim("forest",["battlebg_forest.png"],1,False),
               anim("mine",["battlebg_mine.png"],1,False),
               anim("cave",["battlebg_cave.png"],1,False)]),
  sprite("Hero",[anim(k,[f"hero_{k}_f{i}.png" for i in range(4)],0.22,True) for k in ["ludo","marin","aaron"]]),
  sprite("FoeShadow",[anim("i",["shadow.png"],1,False)]),
  sprite("Foe",[anim(k,[f"foe_{k}_{i}.png" for i in range(FOE_FRAMES[k])],0.16,FOE_FRAMES[k]>1) for k in FOE_FRAMES]),
  sprite("Cursor",[anim("i",["cursor.png"],1,False)]),
  sprite("Fx",[anim("idle",["fx_idle.png"],1,False),
               anim("slash",[f"fx_slash_{i}.png" for i in range(3)],0.09,False),
               anim("burst",[f"fx_burst_{i}.png" for i in range(4)],0.09,False),
               anim("spark",[f"fx_spark_{i}.png" for i in range(4)],0.09,False),
               anim("heal",[f"fx_heal_{i}.png" for i in range(4)],0.10,False)]),
  sprite("MsgPanel",[anim("i",["panel.png"],1,False)]),
  sprite("CmdPanel",[anim("i",["panel_tr.png"],1,False)]),
  sprite("StatusPanel",[anim("i",["panel_tr.png"],1,False)]),
  sprite("RowHiG",[anim("i",["rowhi_g.png"],1,False)]),
  sprite("BarBg",[anim("i",["bar_bg.png"],1,False)]),
  sprite("BarFill",[anim("hp",["bar_hp.png"],1,False),anim("mp",["bar_mp.png"],1,False),
                    anim("atb",["bar_atb.png"],1,False),anim("atbf",["bar_atbf.png"],1,False),
                    anim("ehp",["bar_ehp.png"],1,False)]),
  text_obj("MsgText","",28),
  text_obj("BossName","",24,"255;225;120"),
  text_obj("CmdAtk","⚔ 攻擊",26),text_obj("CmdSkill","✦ 技能",26),text_obj("CmdItem","✚ 道具",26),
  text_obj("CmdGuard","🛡 防禦",26),text_obj("CmdFlee","► 逃跑",26),
  text_obj("BtnBack","← 返回",22,"200;210;255"),
  text_obj("BtnAuto","⚙ 自動:關　[A]",22,"170;180;200"),
  text_obj("Spell0","",22),text_obj("Spell1","",22),text_obj("Spell2","",22),
  text_obj("Spell3","",22),text_obj("Spell4","",22),
  text_obj("Item0","",22),text_obj("Item1","",22),text_obj("Item2","",22),
  text_obj("Item3","",22),text_obj("Item4","",22),
  text_obj("Status0","",19),text_obj("Status1","",19),text_obj("Status2","",19),text_obj("Status3","",19)]+[
  text_obj(f"HpV{i}","",15,"170;220;235") for i in range(4)]+[
  text_obj(f"MpV{i}","",15,"170;220;235") for i in range(4)]+[
  text_obj(f"DmgPop{i}","",34,align="center") for i in range(6)]+[
  text_obj("FoeName0","",18,align="center"),text_obj("FoeName1","",18,align="center"),
  text_obj("FoeName2","",18,align="center"),text_obj("FoeName3","",18,align="center"),
  sprite("OverlayBg",[anim("i",["overlay.png"],1,False)]),
  text_obj("ResultTitle","",64,"255;235;140",align="center"),
  text_obj("ResultMsg","",28,align="center"),
  sprite("BtnCont",[anim("i",["btn.png"],1,False)]),text_obj("TxtCont","繼續",30),
]
HERO_POS=[[1055,165],[1055,290],[1055,415],[1055,535]]
FOE_POS=[[300,250],[470,340],[260,430],[440,190]]
battle["instances"]=[inst("Bg",0,0,0,1280,720)]
for i in range(4): battle["instances"].append(inst("FoeShadow",0,0,4,64,18,"",{"slot":i}))
for i in range(4): battle["instances"].append(inst("Hero",1000,160+i*125,5,0,0,"",{"slot":i}))
for i in range(4): battle["instances"].append(inst("Foe",300,250,5,0,0,"",{"slot":i}))
battle["instances"]+=[inst("Fx",0,0,40,90,90) for _ in range(4)]
# 敵人血條 4 + 隊伍窗 HP/MP/ATB 12 + Boss 頂部大血條 1 ＋備用 = BarBg/BarFill ×18
battle["instances"]+=[inst("BarBg",0,0,7,104,11) for _ in range(18)]
battle["instances"]+=[inst("BarFill",0,0,8,100,7) for _ in range(18)]
battle["instances"]+=[inst("DmgPop%d"%i,0,0,60,120,0) for i in range(6)]
battle["instances"]+=[
  inst("Cursor",0,0,6,40,40),
  inst("FoeName0",200,340,7,200,0),inst("FoeName1",370,430,7,200,0),
  inst("FoeName2",160,520,7,200,0),inst("FoeName3",340,280,7,200,0),
  inst("MsgPanel",40,16,8,1200,58),inst("MsgText",60,28,9,1160,0),
  inst("BossName",340,84,9,600,0),
  inst("CmdPanel",40,566,8,520,146),inst("StatusPanel",575,566,8,665,146),
  inst("RowHiG",0,0,9,650,30),
  inst("CmdAtk",64,598,9),inst("CmdSkill",224,598,9),inst("CmdItem",384,598,9),
  inst("CmdGuard",64,652,9),inst("CmdFlee",224,652,9),
  inst("Spell0",64,586,9),inst("Spell1",300,586,9),inst("Spell2",64,624,9),
  inst("Spell3",300,624,9),inst("Spell4",64,662,9),
  inst("Item0",64,586,9),inst("Item1",300,586,9),inst("Item2",64,624,9),
  inst("Item3",300,624,9),inst("Item4",64,662,9),
  inst("BtnBack",440,678,9),
  inst("BtnAuto",1046,16,9),
  inst("Status0",590,578,10),inst("Status1",590,612,10),inst("Status2",590,646,10),inst("Status3",590,680,10)]+[
  inst(f"HpV{i}",782,582+i*34,10) for i in range(4)]+[
  inst(f"MpV{i}",936,582+i*34,10) for i in range(4)]+[
  inst("OverlayBg",0,0,50,1280,720),
  inst("ResultTitle",340,150,51,600,0),inst("ResultMsg",240,260,51,800,0),
  inst("BtnCont",460,600,51,360,84),inst("TxtCont",600,624,52),
]

BATTLE_JS = r"""
var rs=runtimeScene;
var C=__CONTENT__;
var NATIVE=__NATIVE__;
var HERO_POS=__HP__; var FOE_POS=__FP__;
var g=rs.getGame().getVariables();
function one(n){var a=rs.getObjects(n);return a.length?a[0]:null;}
function bySlot(n,s){var a=rs.getObjects(n);for(var i=0;i<a.length;i++){if(a[i].getVariables().get("slot").getAsNumber()===s)return a[i];}return null;}
function sfx(n){gdjs.evtTools.sound.playSound(rs,n,false,100,1);}
function J(nm,dv){var s=g.get(nm).getAsString();if(!s)return dv;try{return JSON.parse(s);}catch(e){return dv;}}
function setJ(nm,v){g.get(nm).setString(JSON.stringify(v));}
var EQ={};
for(var i=0;i<(C.equipment||[]).length;i++)EQ[C.equipment[i].id]=C.equipment[i];
var ITEM={};
for(var i=0;i<(C.items||[]).length;i++)ITEM[C.items[i].id]=C.items[i];
// ---------- 多道具背包 g_itemInv ----------
function invAll(){return J("g_itemInv",{});}
function invGet(id){var v=invAll();return v[id]||0;}
function invAdd(id,n){var v=invAll();v[id]=(v[id]||0)+n;if(v[id]<0)v[id]=0;setJ("g_itemInv",v);}
function invUse(id){invAdd(id,-1);}
function itemUsableInBattle(meta){return meta&&(meta.kind==="heal"||meta.kind==="mp");}
// 背包內 consumable 清單（依固定順序），戰鬥道具選單用
function battleItems(){
  var iv=invAll();var out=[];
  for(var i=0;i<(C.items||[]).length;i++){var it=C.items[i];
    if(it.cat==="consumable"&&(iv[it.id]||0)>0)out.push({id:it.id,n:iv[it.id],meta:it});}
  return out;
}
function eqStat(m,k){var t=0;if(m.eq){for(var s in m.eq){var e=EQ[m.eq[s]];if(e&&e[k])t+=e[k];}}return t;}
function derive(m){
  var d=C.derived;
  if(m.eq===undefined){m.eq={};
    for(var i=0;i<C.party.length;i++){var t=C.party[i];
      if(t.id===m.id&&t.startEq){for(var s in t.startEq)m.eq[s]=t.startEq[s];}}}
  m.maxhp=d.hpBase+m.attrs.str*d.hpPerStr+eqStat(m,"hp");
  m.maxmp=d.mpBase+m.attrs.int*d.mpPerInt+eqStat(m,"mp");
  m.patk=d.weaponAtk+m.attrs[m.mainAttr]*2+eqStat(m,"patk");
  m.matk=Math.round(m.attrs.int*d.matkPerInt)+eqStat(m,"matk");
  m.pdef=m.attrs.str+eqStat(m,"pdef");
  m.mdef=Math.round(m.attrs.int*d.mdefPerInt)+eqStat(m,"mdef");
  m.dodgeV=Math.round(m.attrs.agi*d.dodgePerAgi)+eqStat(m,"dodge");
  m.critV=d.critBase+m.attrs.agi*d.critPerAgi+eqStat(m,"crit");
  m.spd=m.attrs.agi;
  // ===== 真實系統：幸運 / 武器熟練度 / 屬性加護 / 特別加護 =====
  var _def=null,_si;for(_si=0;_si<C.party.length;_si++){if(C.party[_si].id===m.id){_def=C.party[_si];break;}}
  var _bl=(m.blessing&&(C.blessings||{})[m.blessing])||null;
  var _lb=(_def&&_def.base&&_def.base.luck)||0,_lg=(_def&&_def.growth&&_def.growth.luck)||0;
  m.luck=_lb+Math.floor(((m.lv||1)-1)*_lg)+eqStat(m,"luck")+((_bl&&_bl.stats&&_bl.stats.luck)||0);
  if(!m.prof)m.prof={};
  var _wid=m.eq&&m.eq.weapon;m.wtype=(_wid&&EQ[_wid]&&EQ[_wid].wtype)||null;
  if(m.wtype)m.patk+=Math.floor((m.prof[m.wtype]||0)*(d.profAtkPer||0));
  if(_bl&&_bl.stats){var _s=_bl.stats;
    m.patk+=_s.patk||0;m.matk+=_s.matk||0;m.pdef+=_s.pdef||0;m.mdef+=_s.mdef||0;
    m.dodgeV+=_s.dodge||0;m.critV+=_s.crit||0;m.maxhp+=_s.hp||0;m.maxmp+=_s.mp||0;}
  var _EL=["earth","fire","wind","water","ice","thunder","light","dark"];
  m.elem={};for(_si=0;_si<_EL.length;_si++){var _ek=_EL[_si];
    m.elem[_ek]=((_def&&_def.elem&&_def.elem[_ek])||0)+eqStat(m,"el_"+_ek)+((_bl&&_bl.elem&&_bl.elem[_ek])||0);}
  m.critV=Math.round((m.critV+m.luck*(d.critPerLuck||0))*10)/10;
  if(m.hp===undefined||m.hp>m.maxhp)m.hp=m.maxhp;
  if(m.mp===undefined||m.mp>m.maxmp)m.mp=m.maxmp;
  if(!m.sk){m.sk={};for(var i=0;i<C.skills.length;i++){var s=C.skills[i];
    if(s["class"]===m.cls&&m.lv>=s.unlockLv)m.sk[s.id]=1;}}
  if(m.spts===undefined)m.spts=0;
  return m;
}
function expNeed(lv){var d=C.derived;return d.expBase+Math.round(d.expCoef*Math.pow(lv,d.expPow));}
function skillsFor(m){
  var out=[];
  for(var i=0;i<C.skills.length;i++){var s=C.skills[i];
    if(m.sk&&m.sk[s.id])out.push(s);}
  return out;
}
function skPow(a,sk){var slv=(a.sk&&a.sk[sk.id])||1;return 1+C.derived.skillPowerPerLv*(slv-1);}
function skBase(a,sk){  // 技能以普攻數值為基礎：智力系吃魔攻、其餘吃物攻（敵人用 atk 折算）
  if(sk.attr==="int")return a.attrs?a.matk:Math.round((a.atk||0)*0.8);
  return a.attrs?a.patk:(a.atk||0);
}
// 元素倍率：攻擊者屬性加護 × 目標弱點/抗性（無 element 的技能回傳 1）
function elemMul(a,t,sk){
  if(!sk||!sk.element)return {m:1,weak:false,resist:false};
  var d=C.derived,e=sk.element;
  var aff=1+(((a.elem&&a.elem[e])||0)*(d.elemAffinityPer||0));
  var wk=(t.weak||[]).indexOf(e)>=0, rs=(t.resist||[]).indexOf(e)>=0;
  var wr=wk?(d.weakMul||1.5):(rs?(d.resistMul||0.5):1);
  return {m:aff*wr,weak:wk,resist:rs};
}
var EXPSCALE=__EXPSCALE__;
var ATB_K=1.05;   // ATB 速度：慢（Claude Design Tweaks 定案；waitMode=true 由狀態機天然實現）
if(!rs.__b){initB();}
var b=rs.__b;
try{window.__B=b;window.__W=null;window.__G=g;}catch(e){}
var dt=rs.getElapsedTime()/1000;
(function(){
  if(!window.__auHook){window.__auHook=1;window.__audioUnlocked=0;
    ["pointerdown","keydown","touchstart"].forEach(function(ev){
      document.addEventListener(ev,function(){window.__audioUnlocked=1;},{once:true,capture:true});});}
  if(rs.__bgmT===undefined)rs.__bgmT=-1;
  rs.__bgmT++;
  var first=(rs.__bgmT===0);
  if(!first&&(!window.__audioUnlocked||rs.__bgmT%45!==0))return;
  var mu=rs.getGame().getSoundManager().getMusicOnChannel(1);
  if(!mu||!mu.playing())gdjs.evtTools.sound.playMusicOnChannel(rs,"bgm_battle.mp3",1,true,65,1);
})();
var im=rs.getGame().getInputManager();
var cs=[];var ids=im.getStartedTouchIdentifiers();
for(var i=0;i<ids.length;i++){cs.push([im.getTouchX(ids[i]),im.getTouchY(ids[i])]);}
function clickOn(n){var o=one(n);if(!o||o.isHidden())return false;for(var i=0;i<cs.length;i++){if(o.insideObject(cs[i][0],cs[i][1]))return true;}return false;}
if(!b.kp)b.kp={};
function keyHit(k){var d=gdjs.evtTools.input.isKeyPressed(rs,k);var was=b.kp[k];b.kp[k]=d;return d&&!was;}
var kRet=keyHit("Return"),kSpc=keyHit("Space");
var kEnter=kRet||kSpc;
var kEsc=keyHit("Escape");
var kUp=keyHit("Up"),kDown=keyHit("Down"),kLeft=keyHit("Left"),kRight=keyHit("Right");
// 自動戰鬥切換（A 鍵或點畫面上的自動鈕）：開啟後我方回合直接普攻，不跳指令選單
if((keyHit("a")||clickOn("BtnAuto"))&&b.state!=="win"&&b.state!=="lose"){
  var _na=g.get("g_autoBattle").getAsNumber()?0:1; g.get("g_autoBattle").setNumber(_na);
  banner("自動戰鬥："+(_na?"開啟──我方自動普攻":"關閉")); sfx("select.wav");
  if(_na&&b.state==="menu"&&b.actor)autoAttack(b.actor);   // 若正停在指令選單，立即代打
}

// ================= ATB 主狀態機 =================
if(b.state==="run"){
  // 等待模式：只有 run 狀態蓄力（開任何選單/演出即暫停）
  var all=b.heroes.concat(b.foes);
  for(var i=0;i<all.length;i++){var u=all[i];
    if(u.alive)u.atb=Math.min(100,(u.atb||0)+(10+(u.attrs?u.attrs.agi:u.spd))*ATB_K*dt);}
  var rdy=null;
  for(var i=0;i<b.heroes.length;i++){var h=b.heroes[i];
    if(h.alive&&h.atb>=100){rdy=h;break;}}
  if(rdy){openCmd(rdy);}
  else{
    for(var i=0;i<b.foes.length;i++){var f=b.foes[i];
      if(f.alive&&f.atb>=100){foeAct(f);break;}}
  }
}else if(b.state==="anim"){
  b.t-=dt;
  if(b.t<=0){
    if(b.storyEnd){g.get("g_result").setString("story");saveParty();back();return;}
    if(!checkEnd())b.state="run";
  }
}else if(b.state==="menu"){
  if(b.sel===undefined)b.sel=0;
  if(kLeft){b.sel=(b.sel+4)%5;sfx("cursor.mp3");}
  if(kRight){b.sel=(b.sel+1)%5;sfx("cursor.mp3");}
  if(kUp||kDown){b.sel=(b.sel>=3)?(b.sel-3):Math.min(4,b.sel+3);sfx("cursor.mp3");}
  var CMDS=["CmdAtk","CmdSkill","CmdItem","CmdGuard","CmdFlee"];
  var pick=-1;
  for(var i=0;i<5;i++){if(clickOn(CMDS[i]))pick=i;}
  if(kEnter)pick=b.sel;
  if(pick===0){sfx("select.wav");b.pend={t:"atk"};b.state="target";b.tSel=0;}
  else if(pick===1){sfx("select.wav");b.state="skill";b.sSel=0;}
  else if(pick===2){sfx("select.wav");b.state="item";b.iSel=0;}
  else if(pick===3){sfx("select.wav");b.actor.defending=true;
    banner(b.actor.name+" 擺出防禦姿態（物理傷害減半）");endAction(0.45);}
  else if(pick===4){
    sfx("select.wav");
    if(!b.scripted&&b.enc!=="ch1_boss"&&Math.random()<0.7){saveParty();g.get("g_result").setString("flee");back();return;}
    banner(b.actor.name+" 想逃跑，但是失敗了！");endAction(0.6);
  }
}else if(b.state==="skill"){
  var sl=skillsFor(b.actor);
  var nSl=Math.min(sl.length,5);
  if(b.sSel===undefined)b.sSel=0;
  if(kUp&&b.sSel>0){b.sSel--;sfx("cursor.mp3");}
  if(kDown&&b.sSel<nSl-1){b.sSel++;sfx("cursor.mp3");}
  if(clickOn("BtnBack")||kEsc){b.state="menu";sfx("cancel.mp3");}
  else{
    var pick=-1;
    for(var i=0;i<nSl;i++){if(clickOn("Spell"+i))pick=i;}
    if(kEnter)pick=b.sSel;
    if(pick>=0&&sl[pick]){var sk=sl[pick];
      if(b.actor.mp<sk.mp){banner("MP 不足！");sfx("cancel.mp3");}
      else{sfx("select.wav");b.pend={t:"skill",sk:sk};b.tSel=0;
        if(sk.target==="enemy")b.state="target";
        else if(sk.target==="ally")b.state="target_ally";
        else applyAll(sk);}
    }
  }
}else if(b.state==="item"){
  var items=battleItems();
  if(b.iSel===undefined)b.iSel=0;
  if(b.iSel>=items.length)b.iSel=Math.max(0,items.length-1);
  if(kUp&&b.iSel>0){b.iSel--;sfx("cursor.mp3");}
  if(kDown&&b.iSel<items.length-1){b.iSel++;sfx("cursor.mp3");}
  if(clickOn("BtnBack")||kEsc){b.state="menu";sfx("cancel.mp3");}
  else{
    var pick=-1;
    for(var i=0;i<items.length&&i<5;i++){if(clickOn("Item"+i))pick=i;}
    if(kEnter&&items.length)pick=b.iSel;
    if(pick<0){if(kEnter&&!items.length){banner("沒有可用的道具！");sfx("cancel.mp3");}}
    else{var pit=items[pick];
      if(!itemUsableInBattle(pit.meta)){banner(pit.meta.name+" 無法在戰鬥中使用");sfx("cancel.mp3");}
      else{sfx("select.wav");b.pend={t:"item",item:pit.id};b.state="target_ally";b.tSel=0;}}
  }
}else if(b.state==="target"){
  var alive=b.foes.filter(function(u){return u.alive;});
  if(b.tSel===undefined)b.tSel=0;
  if((kUp||kLeft)&&alive.length){b.tSel=(b.tSel+alive.length-1)%alive.length;sfx("cursor.mp3");}
  if((kDown||kRight)&&alive.length){b.tSel=(b.tSel+1)%alive.length;sfx("cursor.mp3");}
  if(clickOn("BtnBack")||kEsc){b.state="menu";sfx("cancel.mp3");}
  else{
    var chosen=null;
    for(var i=0;i<b.foes.length;i++){var e=b.foes[i];if(!e.alive)continue;
      for(var j=0;j<cs.length;j++){if(e.obj.insideObject(cs[j][0],cs[j][1]))chosen=e;}}
    if(kEnter&&alive.length)chosen=alive[b.tSel%alive.length];
    if(chosen){applyOne([chosen]);}
  }
}else if(b.state==="target_ally"){
  var aliveH=b.heroes.filter(function(u){return u.alive;});
  if(b.tSel===undefined)b.tSel=0;
  if((kUp||kLeft)&&aliveH.length){b.tSel=(b.tSel+aliveH.length-1)%aliveH.length;sfx("cursor.mp3");}
  if((kDown||kRight)&&aliveH.length){b.tSel=(b.tSel+1)%aliveH.length;sfx("cursor.mp3");}
  if(clickOn("BtnBack")||kEsc){b.state="menu";sfx("cancel.mp3");}
  else{
    var chosen=null;
    for(var i=0;i<b.heroes.length;i++){var h=b.heroes[i];if(!h.alive)continue;
      var hitp=false;
      for(var j=0;j<cs.length;j++){if(h.obj.insideObject(cs[j][0],cs[j][1]))hitp=true;}
      var row=one("Status"+h.slot);
      if(row){for(var j=0;j<cs.length;j++){if(row.insideObject(cs[j][0],cs[j][1]))hitp=true;}}
      if(hitp)chosen=h;}
    if(kEnter&&aliveH.length)chosen=aliveH[b.tSel%aliveH.length];
    if(chosen){applyOne([chosen]);}
  }
}else if(b.state==="win"||b.state==="lose"){
  if(clickOn("BtnCont")||kEnter){sfx("select.wav");
    if(b.state==="lose"){g.get("g_returnScene").setString("Town");g.get("g_spawn").setString("shrine");}  // 全滅→教堂重生
    g.get("g_result").setString(b.state);back();return;}
}
refresh();return;

function back(){
  var sc=g.get("g_returnScene").getAsString()||"Town";
  gdjs.evtTools.runtimeScene.replaceScene(rs,sc,true);
}
function banner(m){b.msg=m;}
function autoAttack(h){
  var af=b.foes.filter(function(u){return u.alive;});
  if(!af.length)return false;
  b.actor=h;h.defending=false;b.pend={t:"atk"};b.state="target";b.tSel=0;applyOne([af[0]]);return true;
}
function openCmd(h){
  h.defending=false;
  // 自動模式：直接對第一個存活敵人普攻，不開指令選單
  if(g.get("g_autoBattle").getAsNumber()&&autoAttack(h))return;
  b.state="menu";b.actor=h;b.sel=0;
  banner(h.name+" 的回合──選擇指令");
  sfx("cursor.mp3");
}
function endAction(t){
  if(b.actor)b.actor.atb=0;
  b.actor=null;b.pend=null;
  b.state="anim";b.t=(t||0.7);
}
function initB(){
  rs.__b={};b=rs.__b;
  b.enc=g.get("g_encounter").getAsString()||"forest";
  var groups=C.encounters[b.enc]||C.encounters.forest;
  var grp=groups[Math.floor(Math.random()*groups.length)];
  b.scripted=(b.enc==="prologue_demon");b.surviveActs=3;b.acted=0;
  var ps=J("g_party",[]);
  b.heroes=[];
  for(var i=0;i<ps.length&&i<4;i++){
    var m=ps[i];derive(m);m.side="hero";m.slot=i;m.alive=m.hp>0;
    m.atb=Math.random()*40;m.defending=false;
    b.heroes.push(m);
  }
  var byId={};for(var i=0;i<C.enemies.length;i++)byId[C.enemies[i].id]=C.enemies[i];
  b.foes=[];
  for(var i=0;i<grp.length&&i<4;i++){
    var t=byId[grp[i]];
    b.foes.push({id:t.id,name:t.name,sprite:t.sprite,hp:t.hp,maxhp:t.hp,atk:t.atk,def:t.def,
      spd:t.spd,exp:t.exp,gold:t.gold,big:!!t.big,healer:!!t.healer,allAttack:!!t.allAttack,
      foeSkills:t.foeSkills||null,weak:t.weak||[],resist:t.resist||[],
      drops:t.drops||[],side:"foe",slot:i,alive:true,atb:Math.random()*30});
  }
  // 陣型：前排（近我方）／後排；big（頭目級）預設後排、3 隻以上自動分兩排
  b.frontRow=[];b.backRow=[];
  for(var i=0;i<b.foes.length;i++){var e0=b.foes[i];(e0.big?b.backRow:b.frontRow).push(e0);}
  while(b.frontRow.length>2&&b.frontRow.length>b.backRow.length+1)b.backRow.push(b.frontRow.pop());
  for(var i=0;i<b.foes.length;i++)b.foes[i].row=(b.backRow.indexOf(b.foes[i])>=0)?"back":"front";
  // 戰鬥背景依地圖切換
  var BGMAP={forest:"forest",forest2:"forest",ch1_boss:"forest",tutorial:"mine",
             mine:"mine",cave:"cave",prologue_demon:"cave",ch2_bear:"mine"};
  var bg0=one("Bg");if(bg0)bg0.setAnimationName(BGMAP[b.enc]||"forest");
  for(var i=0;i<b.heroes.length;i++)layout(b.heroes[i]);
  for(var i=0;i<b.foes.length;i++)layout(b.foes[i]);
  for(var s=b.heroes.length;s<4;s++){var o=bySlot("Hero",s);if(o)o.hide(true);}
  for(var s=b.foes.length;s<4;s++){var o=bySlot("Foe",s);if(o)o.hide(true);}
  rs.getObjects("Fx").forEach(function(o){o.hide(true);});
  b.fxT={};b.fxN=0;b.pops=[];
  b.state="anim";b.t=1.0;
  b.msg=b.scripted?"異變的魔影擋在面前……撐過牠的 3 次攻擊！":"遭遇敵人！行動條蓄滿即可下令";
  b.sel=0;b.sSel=0;b.tSel=0;
}
function layout(u){
  var o=bySlot(u.side==="hero"?"Hero":"Foe",u.slot);u.obj=o;
  o.setAnimationName(u.sprite);
  var nat=NATIVE[u.sprite]||[16,16];
  var H=u.side==="hero"?130:(u.big?170:95);
  var w=Math.round(nat[0]/nat[1]*H);
  o.setWidth(w);o.setHeight(H);
  var pos;
  if(u.side==="hero"){pos=HERO_POS[u.slot];}
  else{
    var rowArr=(u.row==="back")?b.backRow:b.frontRow;
    var idx=Math.max(0,rowArr.indexOf(u)), n=Math.max(1,rowArr.length);
    var cx=(u.row==="back")?250:445;
    pos=[cx+((idx%2)?16:-12), 330+(idx-(n-1)/2)*128];
  }
  o.setX(pos[0]-w/2);o.setY(pos[1]-H/2);
  u.bx=pos[0]-w/2; u.by=pos[1]-H/2;
  o.hide(!u.alive);
  o.setOpacity(255);
  if(u.side==="foe")o.flipX(false);
}
// ---- 演出：攻擊前進 / 受擊震動+閃紅 / 技能光效 / 浮動傷害 ----
function fxShow(kind,u){
  if(!u||!u.obj)return;
  var pool=rs.getObjects("Fx"); if(!pool.length)return;
  var fo=pool[b.fxN%pool.length]; b.fxN=(b.fxN||0)+1;
  fo.setAnimationName("idle"); fo.setAnimationName(kind);
  var FW=Math.max(80,u.obj.getWidth()*0.9);
  fo.setWidth(FW);fo.setHeight(FW);
  fo.setX(u.obj.getX()+u.obj.getWidth()/2-FW/2);
  fo.setY(u.obj.getY()+u.obj.getHeight()/2-FW/2);
  fo.setZOrder(45); fo.hide(false);
  if(!b.fxT)b.fxT={};
  b.fxT[fo.id]={o:fo,t:0.45};
}
function hitFx(att,tgt,kind){
  att.lungeT=0.28;
  if(tgt){tgt.shakeT=0.32;tgt.flashT=0.3;fxShow(kind,tgt);}
}
function popDmg(u,text,color){
  if(!u||!u.obj)return;
  for(var i=0;i<6;i++){
    var o=one("DmgPop"+i); if(!o)return;
    var used=false;
    for(var j=0;j<b.pops.length;j++){if(b.pops[j].o===o)used=true;}
    if(used)continue;
    o.setString(text);o.setColor(color||"255;255;255");o.setOpacity(255);
    var x=u.obj.getX()+u.obj.getWidth()/2-60, y=u.obj.getY()+u.obj.getHeight()*0.25;
    o.setX(x);o.setY(y);o.hide(false);
    b.pops.push({o:o,t:1.0,y0:y});
    return;
  }
}
function heroAtk(u){return u.patk;}
function heroDef(u){return u.pdef;}
function dodge(att,defn){
  var d=C.derived;
  var dv=defn.attrs?defn.dodgeV:defn.spd*d.dodgePerAgi;
  var av=att.attrs?att.attrs.agi*d.dodgePerAgi:att.spd*d.dodgePerAgi;
  var ch=Math.max(0,Math.min(d.dodgeCap,dv-av));
  return Math.random()*100<ch;
}
function phys(att,defn){
  var atk=att.attrs?heroAtk(att):att.atk;
  var df=defn.attrs?heroDef(defn):defn.def;
  var base=atk*1.8-df;if(base<1)base=1;
  if(defn.defending)base*=0.5;
  var critCh=att.attrs?att.critV/100:C.derived.critBase/100;
  var crit=Math.random()<critCh;
  return {d:Math.max(1,Math.round(base*(0.85+Math.random()*0.15)*(crit?1.5:1))),crit:crit};
}
function skDef(t,sk){
  if(sk.attr==="int")return t.attrs?t.mdef:Math.round(t.def*0.5);
  return t.attrs?t.pdef:t.def;
}
function kill(u){if(u.hp<=0){u.hp=0;
  if(b.scripted&&u.side==="hero"){u.hp=1;return;}
  u.alive=false;u.dieT=0.45;}}
function applyOne(ts){
  var a=b.actor,pd=b.pend,msg="";
  if(pd.t==="atk"){
    var t=ts[0];
    a.lungeT=0.28;
    if(dodge(a,t)){msg=t.name+" 靈巧地閃開了！";popDmg(t,"MISS","170;220;235");sfx("select.wav");}
    else{var r=phys(a,t);t.hp-=r.d;sfx("atk.wav");sfx("hurt.wav");
      t.shakeT=0.32;t.flashT=0.3;fxShow("slash",t);
      popDmg(t,r.d+(r.crit?"!":""),r.crit?"255;235;120":"255;255;255");
      msg=a.name+" 攻擊 "+t.name+"，造成 "+r.d+" 傷害"+(r.crit?"（會心！）":"");kill(t);}
  }else if(pd.t==="skill"){
    var sk=pd.sk;a.mp-=sk.mp;
    var t=ts[0];var pw=skPow(a,sk);var slv=(a.sk&&a.sk[sk.id])||1;
    var skTag="「"+sk.name+(slv>1?" Lv"+slv:"")+"」";
    if(sk.kind==="damage"){
      var df=skDef(t,sk);var em=elemMul(a,t,sk);
      var dmg=Math.max(1,Math.round(((skBase(a,sk)*sk.mult+sk.flat)*pw-df*0.6)*em.m*(0.85+Math.random()*0.15)));
      t.hp-=dmg;sfx("magic.wav");sfx("hurt.wav");
      hitFx(a,t,sk.attr==="int"?"spark":"burst");
      popDmg(t,String(dmg)+(em.weak?"!":""),em.weak?"255;120;120":(em.resist?"170;190;220":"255;255;255"));
      msg=a.name+skTag+"！"+t.name+" 受到 "+dmg+" 傷害"+(em.weak?"（弱點！）":(em.resist?"（抗性…）":""));kill(t);
    }else{
      var before=t.hp;t.hp=Math.min(t.maxhp,t.hp+Math.round((skBase(a,sk)*sk.mult+sk.flat)*pw));
      a.lungeT=0.22;fxShow("heal",t);
      popDmg(t,"+"+(t.hp-before),"140;240;160");
      sfx("heal.wav");msg=a.name+skTag+"！"+t.name+" 恢復 "+(t.hp-before)+" HP";
    }
  }else if(pd.t==="item"){
    var itm=ITEM[pd.item]||{name:"藥水",kind:"heal",power:60};
    invUse(pd.item);
    var t=ts[0];fxShow("heal",t);
    if(itm.kind==="mp"){var before=t.mp;t.mp=Math.min(t.maxmp,t.mp+(itm.power||0));
      popDmg(t,"+"+(t.mp-before)+" MP","150;200;255");sfx("heal.wav");
      msg=a.name+" 使用"+itm.name+"！"+t.name+" 恢復 "+(t.mp-before)+" MP";}
    else{var before=t.hp;t.hp=Math.min(t.maxhp,t.hp+(itm.power||0));
      popDmg(t,"+"+(t.hp-before),"140;240;160");sfx("heal.wav");
      msg=a.name+" 使用"+itm.name+"！"+t.name+" 恢復 "+(t.hp-before)+" HP";}
  }
  banner(msg);
  endAction(0.75);
}
function applyAll(sk){
  var a=b.actor;a.mp-=sk.mp;
  var list=b.foes.filter(function(u){return u.alive;});
  var tot=0;var pw=skPow(a,sk);var slv=(a.sk&&a.sk[sk.id])||1;
  a.lungeT=0.28;
  for(var i=0;i<list.length;i++){
    var em=elemMul(a,list[i],sk);
    var dmg=Math.max(1,Math.round(((skBase(a,sk)*sk.mult+sk.flat)*pw-skDef(list[i],sk)*0.6)*em.m*(0.85+Math.random()*0.15)));
    list[i].hp-=dmg;tot+=dmg;
    list[i].shakeT=0.32;list[i].flashT=0.3;
    fxShow(sk.attr==="int"?"spark":"burst",list[i]);
    popDmg(list[i],String(dmg)+(em.weak?"!":""),em.weak?"255;120;120":(em.resist?"170;190;220":"255;255;255"));
    kill(list[i]);
  }
  sfx("magic.wav");sfx("hurt.wav");
  banner(a.name+"「"+sk.name+(slv>1?" Lv"+slv:"")+"」橫掃全體敵人！共 "+tot+" 傷害");
  endAction(0.8);
}
function foeAct(a){
  a.atb=0;
  if(b.scripted)b.acted=(b.acted||0)+1;
  // 治療型
  if(a.healer){
    var low=b.foes.filter(function(u){return u.alive&&u.hp<u.maxhp*0.55&&u!==a;});
    if(low.length){var t2=low[0];var hl=20+Math.round(Math.random()*10);
      t2.hp=Math.min(t2.maxhp,t2.hp+hl);sfx("heal.wav");
      a.lungeT=0.22;fxShow("heal",t2);popDmg(t2,"+"+hl,"140;240;160");
      banner(a.name+" 治療了 "+t2.name+"（+"+hl+" HP）");finishFoe();return;}
  }
  var alive=b.heroes.filter(function(u){return u.alive;});
  if(!alive.length){checkEnd();return;}
  // Boss 具名技能：40% 機率使出（重擊單體 / 全體）
  if(a.foeSkills&&a.foeSkills.length&&Math.random()<0.4){
    var fsk=a.foeSkills[Math.floor(Math.random()*a.foeSkills.length)];a.lungeT=0.3;
    if(fsk.target==="all"){
      var tot=0;
      for(var i=0;i<alive.length;i++){var rr=phys(a,alive[i]);var d=Math.max(1,Math.round(rr.d*fsk.mult));
        alive[i].hp-=d;tot+=d;alive[i].shakeT=0.34;alive[i].flashT=0.32;fxShow("burst",alive[i]);
        popDmg(alive[i],String(d),"255;150;150");kill(alive[i]);}
      sfx("atk.wav");sfx("hurt.wav");
      banner(a.name+" 使出【"+fsk.name+"】！全體共受到 "+tot+" 傷害");finishFoe();return;
    } else {
      var t3=alive[Math.floor(Math.random()*alive.length)];
      if(dodge(a,t3)){banner(t3.name+" 閃開了 "+a.name+" 的【"+fsk.name+"】！");popDmg(t3,"MISS","170;220;235");finishFoe();return;}
      var rr2=phys(a,t3);var d2=Math.max(1,Math.round(rr2.d*fsk.mult));t3.hp-=d2;
      sfx("atk.wav");sfx("hurt.wav");t3.shakeT=0.36;t3.flashT=0.34;fxShow("burst",t3);
      popDmg(t3,String(d2),"255;120;120");kill(t3);
      banner(a.name+" 使出【"+fsk.name+"】，對 "+t3.name+" 造成 "+d2+" 傷害"+(rr2.crit?"（會心！）":""));
      finishFoe();return;
    }
  }
  if(a.allAttack&&Math.random()<0.3){
    var tot=0;a.lungeT=0.28;
    for(var i=0;i<alive.length;i++){var r=phys(a,alive[i]);alive[i].hp-=r.d;tot+=r.d;
      alive[i].shakeT=0.32;alive[i].flashT=0.3;fxShow("slash",alive[i]);
      popDmg(alive[i],String(r.d),"255;156;156");kill(alive[i]);}
    sfx("atk.wav");sfx("hurt.wav");
    banner(a.name+" 的橫掃攻擊！全體共受到 "+tot+" 傷害");finishFoe();return;
  }
  var t=alive[Math.floor(Math.random()*alive.length)];
  a.lungeT=0.28;
  if(dodge(a,t)){banner(t.name+" 靈巧地閃開了 "+a.name+" 的攻擊！");popDmg(t,"MISS","170;220;235");finishFoe();return;}
  var r=phys(a,t);t.hp-=r.d;sfx("atk.wav");sfx("hurt.wav");
  t.shakeT=0.32;t.flashT=0.3;fxShow("slash",t);
  popDmg(t,String(r.d),"255;156;156");kill(t);
  banner(a.name+" 攻擊 "+t.name+"，造成 "+r.d+" 傷害"+(r.crit?"（會心！）":"")+(t.defending?"（防禦中）":""));
  finishFoe();
}
function finishFoe(){
  if(b.scripted&&b.acted>=b.surviveActs)b.storyEnd=true;
  b.state="anim";b.t=0.75;
}
function saveParty(){
  var ps=J("g_party",[]);
  for(var i=0;i<b.heroes.length;i++){
    var h=b.heroes[i];
    for(var j=0;j<ps.length;j++){
      if(ps[j].id===h.id){ps[j].hp=Math.max(1,h.hp);ps[j].mp=h.mp;ps[j].lv=h.lv;ps[j].exp=h.exp;
        ps[j].pts=h.pts;ps[j].spts=h.spts;ps[j].sk=h.sk;ps[j].eq=h.eq;ps[j].attrs=h.attrs;
        if(h.prof)ps[j].prof=h.prof; if(h.blessing!==undefined)ps[j].blessing=h.blessing;}
    }
  }
  setJ("g_party",ps);
}
function checkEnd(){
  var ha=b.heroes.filter(function(u){return u.alive;}).length;
  var fa=b.foes.filter(function(u){return u.alive;}).length;
  if(b.scripted)return false;
  if(fa===0){
    var exp=0,gold=0;
    for(var i=0;i<b.foes.length;i++){exp+=b.foes[i].exp;gold+=b.foes[i].gold;}
    // EXP 節奏：依 CONTENT.pacing 換算的地圖係數（農怪時間由 battles 參數控制）
    if(EXPSCALE[b.enc]!==undefined)exp=Math.max(1,Math.round(exp*EXPSCALE[b.enc]));
    // 幸運：以隊伍最高幸運提升金幣報酬
    var _maxLuck=0;for(var i=0;i<b.heroes.length;i++){if((b.heroes[i].luck||0)>_maxLuck)_maxLuck=b.heroes[i].luck||0;}
    gold=Math.round(gold*(1+_maxLuck*(C.derived.luckRewardPer||0)));
    g.get("g_gold").setNumber(g.get("g_gold").getAsNumber()+gold);
    var gain=[];var anyUp=false,anyLearn=false;
    var members=b.heroes.filter(function(u){return !u.guest;});
    var each=Math.ceil(exp/Math.max(1,members.length));
    for(var i=0;i<members.length;i++){
      var m=members[i];m.exp+=each;var ups=0;var learned=[];
      while(m.exp>=expNeed(m.lv)){m.exp-=expNeed(m.lv);m.lv++;ups++;
        var gr=null;
        for(var k=0;k<C.party.length;k++){if(C.party[k].id===m.id)gr=C.party[k].growth||{};}
        m.attrs.str+=(gr.str||0);m.attrs.agi+=(gr.agi||0);m.attrs.int+=(gr.int||0);
        m.pts=(m.pts||0)+C.derived.pointsPerLevel;
        m.spts=(m.spts||0)+C.derived.skillPointsPerLevel;
        for(var k=0;k<C.skills.length;k++){var s=C.skills[k];
          if(s["class"]===m.cls&&s.unlockLv===m.lv&&!(m.sk&&m.sk[s.id])){
            if(!m.sk)m.sk={};m.sk[s.id]=1;learned.push(s.name);}}
        derive(m);m.hp=m.maxhp;m.mp=m.maxmp;
      }
      if(ups>0){anyUp=true;
        gain.push(m.name+" 升級 Lv"+m.lv+"！"+(learned.length?"　習得『"+learned.join("』『")+"』！":""));
        if(learned.length)anyLearn=true;}
    }
    // 武器熟練度：戰鬥後為所裝武器型別 +profPerBattle（上限 profMax）
    for(var i=0;i<members.length;i++){var mm=members[i];
      var _wid=mm.eq&&mm.eq.weapon,_wt=_wid&&EQ[_wid]&&EQ[_wid].wtype;
      if(_wt){if(!mm.prof)mm.prof={};
        mm.prof[_wt]=Math.min(C.derived.profMax||99,(mm.prof[_wt]||0)+(C.derived.profPerBattle||0));}}
    saveParty();
    var dropMsg="";
    // 敵人素材掉落：依 drops 機率加入背包
    var dropCount={};
    for(var i=0;i<b.foes.length;i++){var dl=b.foes[i].drops||[];
      for(var k=0;k<dl.length;k++){if(Math.random()<dl[k].rate)dropCount[dl[k].id]=(dropCount[dl[k].id]||0)+1;}}
    var dropNames=[];
    for(var did in dropCount){invAdd(did,dropCount[did]);
      var dnm=(ITEM[did]&&ITEM[did].name)||did;dropNames.push(dnm+(dropCount[did]>1?" ×"+dropCount[did]:""));}
    if(dropNames.length)dropMsg="\n獲得道具：「"+dropNames.join("」「")+"」";
    if(b.enc==="ch1_boss"){var f=J("g_flags",{});f.ch1=2;setJ("g_flags",f);
      var invW=J("g_eqInv",[]);invW.push("leather_vest");invW.push("hunter_bracer");setJ("g_eqInv",invW);
      dropMsg+="\n獲得『皮革護胸』『獵人護腕』！（選單→裝備 分頁）";}
    if(b.enc==="ch2_bear"){var fb=J("g_flags",{});fb.ch2=2;setJ("g_flags",fb);
      var invB=J("g_eqInv",[]);invB.push("swift_boots");setJ("g_eqInv",invB);
      dropMsg+="\n擊退了狂暴洞熊！獲得『疾風靴』！崩塌的礦道鬆動了……";}
    b.winMsg="獲得 "+exp+" 經驗值 · "+gold+" 金幣"+dropMsg
      +(gain.length?("\n"+gain.join("\n")):"")
      +(anyUp?"\n（獲得屬性點與技能點——在選單→角色 分配）":"");
    b.endState="win";b.state="win";
    sfx(anyUp?"levelup.mp3":"win.wav");
    if(anyLearn)sfx("learn.mp3");
    return true;
  }
  if(ha===0){
    var ps=J("g_party",[]);
    for(var i=0;i<ps.length;i++){derive(ps[i]);ps[i].hp=ps[i].maxhp;ps[i].mp=ps[i].maxmp;}
    setJ("g_party",ps);
    b.state="lose";b.winMsg="隊伍全滅……被送回了鎮上";b.endState="lose";sfx("lose.wav");return true;
  }
  return false;
}
function setTxt(n,s){var o=one(n);if(o)o.setString(s);}
function setCol(n,c){var o=one(n);if(o)o.setColor(c);}
function show(n,v){var o=one(n);if(o)o.hide(!v);}
function refresh(){
  b.animT=(b.animT||0)+dt;
  var ht=b.actor&&b.actor.side==="hero";
  var alvF=b.foes.filter(function(u){return u.alive;});
  var alvH=b.heroes.filter(function(u){return u.alive;});
  var selF=(ht&&b.state==="target"&&alvF.length)?alvF[(b.tSel||0)%alvF.length]:null;
  var selH=(ht&&b.state==="target_ally"&&alvH.length)?alvH[(b.tSel||0)%alvH.length]:null;
  // 演出位移：前進/震動/浮動/閃紅/死亡淡出/選取上浮
  function updUnit(u,dirn){
    if(!u.obj||u.bx===undefined)return;
    var ox=0;
    if(u.lungeT>0){u.lungeT-=dt;var p=1-Math.max(0,u.lungeT)/0.28;
      ox+=dirn*Math.sin(Math.PI*Math.min(1,p))*30;}
    if(u.shakeT>0){u.shakeT-=dt;
      ox+=Math.sin(b.animT*55)*6*(Math.max(0,u.shakeT)/0.32);}
    u.obj.setX(u.bx+ox);
    if(u.side==="foe"){
      var oy=(u.alive?Math.sin(b.animT*2.2+u.slot*1.9)*4:0)+(selF===u?-5:0);
      u.obj.setY(u.by+oy);
    }
    if(u.flashT>0){u.flashT-=dt;
      u.obj.setColor(Math.floor(u.flashT*14)%2?"255;110;90":"255;225;200");}
    else u.obj.setColor("255;255;255");
    if(!u.alive&&u.dieT>0){u.dieT-=dt;
      u.obj.setOpacity(Math.max(0,255*u.dieT/0.45));
      if(u.dieT<=0)u.obj.hide(true);}
  }
  for(var i=0;i<b.heroes.length;i++)updUnit(b.heroes[i],-1);
  for(var i=0;i<b.foes.length;i++)updUnit(b.foes[i],1);
  if(b.fxT){for(var k in b.fxT){var e=b.fxT[k];e.t-=dt;
    if(e.t<=0){e.o.hide(true);delete b.fxT[k];}}}
  var end=(b.state==="win"||b.state==="lose");
  // 浮動傷害數字
  for(var i=b.pops.length-1;i>=0;i--){var pp=b.pops[i];pp.t-=dt;
    if(pp.t<=0||end){pp.o.hide(true);b.pops.splice(i,1);continue;}
    pp.o.setY(pp.y0-64*(1-pp.t));
    pp.o.setOpacity(Math.min(255,pp.t*2.2*255));}
  // ---- Bar 池分配：敵血條 + 隊伍 HP/MP/ATB（結算時全部收起）----
  var bgs=rs.getObjects("BarBg"),bfs=rs.getObjects("BarFill");
  var bi=0;
  function setBar(x,y,w,h,ratio,kind){
    if(bi>=bgs.length||bi>=bfs.length)return;
    var bg=bgs[bi],bf=bfs[bi];bi++;
    bg.hide(false);bg.setX(x-2);bg.setY(y-2);bg.setWidth(w+4);bg.setHeight(h+4);
    bf.setAnimationName(kind);bf.hide(false);bf.setX(x);bf.setY(y);
    bf.setWidth(Math.max(1,Math.round(w*Math.max(0,Math.min(1,ratio)))));bf.setHeight(h);
  }
  if(end){
    for(var i=0;i<bgs.length;i++){bgs[i].hide(true);if(bfs[i])bfs[i].hide(true);}
    rs.getObjects("FoeShadow").forEach(function(o){o.hide(true);});
    for(var i=0;i<4;i++){show("FoeName"+i,false);show("Status"+i,false);show("HpV"+i,false);show("MpV"+i,false);}
    var rhg0=one("RowHiG");if(rhg0)rhg0.hide(true);
    bi=bgs.length;
  }
  // 敵人陰影 / 血條 / 名字（僅選取或受擊時顯名）
  var shs=rs.getObjects("FoeShadow");
  for(var i=0;i<4&&!end;i++){
    var e=b.foes[i], sh=shs[i];
    if(sh){if(e&&e.alive&&e.obj){var w=e.obj.getWidth();
      sh.hide(false);sh.setWidth(w*0.95);sh.setHeight(14);
      sh.setX(e.bx+w*0.025);sh.setY(e.by+e.obj.getHeight()-7);sh.setZOrder(4);
    } else sh.hide(true);}
    var nm="FoeName"+i;
    if(e&&e.alive&&e.obj){
      if(!e.big)setBar(e.bx+e.obj.getWidth()/2-42, e.by+e.obj.getHeight()+10, 84,10, e.hp/e.maxhp, "ehp");
      var showNm=!e.big&&((selF===e)||(e.flashT>0));
      show(nm,showNm);
      if(showNm){setTxt(nm,e.name);
        var o=one(nm);if(o){o.setX(e.bx+e.obj.getWidth()/2-100);o.setY(e.by+e.obj.getHeight()+24);}
        setCol(nm,selF===e?"255;235;120":"235;235;245");}
    } else show(nm,false);
  }
  // Boss：名稱＋大血條固定在畫面上方（訊息橫幅下）
  var boss=null;
  for(var i=0;i<b.foes.length;i++){if(b.foes[i].big&&b.foes[i].alive)boss=b.foes[i];}
  var bn=one("BossName");
  if(bn){bn.hide(!boss||end);
    if(boss&&!end){
      bn.setString("☠ "+boss.name);
      setBar(340,118,600,12,boss.hp/boss.maxhp,"ehp");
    }}
  // 隊伍視窗：名字 | HP | MP | ATB
  var hiY=null;
  for(var i=0;i<4&&!end;i++){
    var row="Status"+i;
    if(i<b.heroes.length){var h=b.heroes[i];var y0=576+i*34;
      show(row,true);
      setTxt(row,h.name+" Lv"+h.lv+(h.defending?"〔防〕":""));
      var col="255;255;255";
      if(!h.alive)col="120;120;130";
      else if(b.actor===h)col="255;245;170";
      else if(h.atb>=100)col="255;225;120";
      else if(selH===h)col="120;230;140";
      setCol(row,col);
      setBar(708,y0+10,70,12,h.hp/h.maxhp,"hp");
      setTxt("HpV"+i,Math.max(0,h.hp)+"/"+h.maxhp);
      setCol("HpV"+i,(h.hp/h.maxhp<0.25)?"255;150;150":"170;220;235");
      show("HpV"+i,true);
      setBar(862,y0+10,70,12,h.mp/h.maxmp,"mp");
      setTxt("MpV"+i,h.mp+"/"+h.maxmp);show("MpV"+i,true);
      setBar(1120,y0+10,100,12,(h.atb||0)/100,(h.atb>=100)?"atbf":"atb");
      if(b.actor===h)hiY=y0-2;
    }else{show(row,false);show("HpV"+i,false);show("MpV"+i,false);}
  }
  for(;bi<bgs.length;bi++){bgs[bi].hide(true);if(bfs[bi])bfs[bi].hide(true);}
  var rhg=one("RowHiG");
  if(rhg){rhg.hide(hiY===null);
    if(hiY!==null){rhg.setX(580);rhg.setY(hiY);rhg.setWidth(650);rhg.setHeight(30);}}
  // 指令窗
  var mcmd=ht&&b.state==="menu";
  var CMDS=["CmdAtk","CmdSkill","CmdItem","CmdGuard","CmdFlee"];
  for(var i=0;i<5;i++){show(CMDS[i],mcmd);
    if(mcmd)setCol(CMDS[i],i===(b.sel||0)?"255;235;120":"255;255;255");}
  show("BtnBack",ht&&["skill","item","target","target_ally"].indexOf(b.state)>=0);
  var _ao=g.get("g_autoBattle").getAsNumber();
  show("BtnAuto",b.state!=="win"&&b.state!=="lose");
  setTxt("BtnAuto",(_ao?"⚙ 自動:開":"⚙ 自動:關")+"　[A]");
  setCol("BtnAuto",_ao?"120;230;150":"170;180;200");
  var sl=ht?skillsFor(b.actor):[];
  for(var i=0;i<5;i++){
    var sp="Spell"+i;
    if(ht&&b.state==="skill"&&sl[i]){show(sp,true);
      var slv=(b.actor.sk&&b.actor.sk[sl[i].id])||1;
      setTxt(sp,(i===(b.sSel||0)?"▶":"　")+sl[i].name+" Lv"+slv+" ("+sl[i].mp+"MP)");
      setCol(sp,b.actor.mp<sl[i].mp?"120;120;130":(i===(b.sSel||0)?"255;235;120":"255;255;255"));
    }else show(sp,false);
  }
  var bitems=(ht&&b.state==="item")?battleItems():[];
  for(var i=0;i<5;i++){var ino="Item"+i;
    if(ht&&b.state==="item"&&bitems[i]){show(ino,true);var bit=bitems[i];
      setTxt(ino,(i===(b.iSel||0)?"▶":"　")+bit.meta.name+" x"+bit.n);
      setCol(ino,itemUsableInBattle(bit.meta)?(i===(b.iSel||0)?"255;235;120":"255;255;255"):"120;120;130");}
    else show(ino,false);}
  if(ht&&b.state==="item"&&!bitems.length){show("Item0",true);setTxt("Item0","（沒有可用的道具）");setCol("Item0","120;120;130");}
  var cur=one("Cursor");
  if(cur){
    var tgt=selF||selH;
    if(tgt&&tgt.obj){cur.hide(false);cur.setX(tgt.obj.getX()+tgt.obj.getWidth()+4);cur.setY(tgt.obj.getY()+tgt.obj.getHeight()/2-20);}
    else if(ht&&["menu","skill","item"].indexOf(b.state)>=0&&b.actor.obj){
      cur.hide(false);cur.setX(b.actor.obj.getX()+b.actor.obj.getWidth()+4);cur.setY(b.actor.obj.getY()+b.actor.obj.getHeight()/2-20);}
    else cur.hide(true);}
  // 訊息橫幅
  var mt=b.msg||"";
  if(b.state==="target")mt="選擇攻擊目標（←→ 切換、Enter 確定、Esc 返回）";
  else if(b.state==="target_ally")mt="選擇對象（←→ 切換、Enter 確定、Esc 返回）";
  else if(b.state==="skill")mt="選擇技能（↑↓ 選、Enter 確定、Esc 返回）";
  else if(b.state==="item")mt="選擇道具（Enter 使用、Esc 返回）";
  setTxt("MsgText",mt);
  var end=(b.state==="win"||b.state==="lose");
  __RESULT__.forEach(function(n){show(n,end);});
  if(end){setTxt("ResultTitle",b.state==="win"?"勝　利！":"戰　敗");
    setCol("ResultTitle",b.state==="win"?"255;235;140":"255;150;150");
    setTxt("ResultMsg",b.winMsg||"");setTxt("TxtCont",b.state==="win"?"繼續":"回到鎮上");}
}
"""
# EXP 節奏係數：讓「entryLv 練到 targetLv」約需 battles 場戰鬥（battles=可調的農怪時間系數）
def exp_need_py(lv):
    d=CONTENT["derived"]; return d["expBase"]+round(d["expCoef"]*lv**d["expPow"])
EXPSCALE={}
_pac=CONTENT.get("pacing",{})
_ebyid={e["id"]:e for e in CONTENT["enemies"]}
for _k,_cfg in _pac.get("maps",{}).items():
    _groups=CONTENT["encounters"].get(_k,[])
    if not _groups: continue
    _avg=sum(sum(_ebyid[i]["exp"] for i in gp) for gp in _groups)/len(_groups)
    _need=sum(exp_need_py(l) for l in range(_cfg["entryLv"],_cfg["targetLv"]))
    _party=_cfg.get("party",_pac.get("partySize",2))
    EXPSCALE[_k]=round(_party*_need/(_cfg["battles"]*_avg),3) if _avg>0 else 1
print("EXPSCALE:",EXPSCALE)

BATTLE_JS=(BATTLE_JS.replace("__CONTENT__",json.dumps(CONTENT,ensure_ascii=False))
  .replace("__NATIVE__",json.dumps(NATIVE))
  .replace("__HP__",json.dumps(HERO_POS)).replace("__FP__",json.dumps(FOE_POS))
  .replace("__RESULT__",json.dumps(RESULT))
  .replace("__EXPSCALE__",json.dumps(EXPSCALE)))
battle["events"]=[jsev(BATTLE_JS)]

# ================= 10. Title =================
title=scene("Title",(12,10,26))
title["objects"]=[
  sprite("TBg",[anim("i",["menubg.png"],1,False)]),           # 森林手繪＋log「水晶奇譚」已烘進
  sprite("TxtStart",[anim("i",["t_start.png"],1,False)]),     # 開始遊戲（無框、文字描邊）
  sprite("TxtCont",[anim("i",["t_cont.png"],1,False)]),       # 繼續冒險（有存檔）
  sprite("TxtRestart",[anim("i",["t_restart.png"],1,False)]), # 重新開始（有存檔）
  sprite("TxtNew",[anim("i",["t_new.png"],1,False)]),         # 開始新遊戲（無存檔）
  text_obj("THelp","方向鍵/搖桿選擇 · 空白鍵或點擊確定",20,"210;220;242",align="center"),
]
title["instances"]=[
  inst("TBg",0,0,0,1280,720),
  inst("TxtStart",520,556,3),inst("TxtCont",520,506,3),inst("TxtRestart",520,592,3),inst("TxtNew",520,556,3),
  inst("THelp",240,678,2,800,0),
]
title["events"]=[jsev(r"""
var rs=runtimeScene;
var im=rs.getGame().getInputManager();
var g=rs.getGame().getVariables();
var C=__CONTENT__;
(function(){
  if(!window.__auHook){window.__auHook=1;window.__audioUnlocked=0;
    ["pointerdown","keydown","touchstart"].forEach(function(ev){
      document.addEventListener(ev,function(){window.__audioUnlocked=1;},{once:true,capture:true});});}
  if(rs.__t===undefined)rs.__t=-1;
  rs.__t++;
  var first=(rs.__t===0);
  if(!first&&(!window.__audioUnlocked||rs.__t%45!==0))return;
  var mu=rs.getGame().getSoundManager().getMusicOnChannel(1);
  if(!mu||!mu.playing())gdjs.evtTools.sound.playMusicOnChannel(rs,"bgm_title.mp3",1,true,65,1);
})();
function mk(id){
  var t=null;for(var i=0;i<C.party.length;i++){if(C.party[i].id===id)t=C.party[i];}
  var m={id:id,name:t.name,cls:t["class"],mainAttr:t.mainAttr,sprite:t.sprite,guest:!!t.guest,
    lv:t.startLevel||1,exp:0,pts:0,attrs:{str:t.base.str,agi:t.base.agi,int:t.base.int}};
  m.maxhp=C.derived.hpBase+m.attrs.str*C.derived.hpPerStr;
  m.maxmp=C.derived.mpBase+m.attrs.int*C.derived.mpPerInt;
  m.hp=m.maxhp;m.mp=m.maxmp;return m;
}
function oneT(n){var a=rs.getObjects(n);return a.length?a[0]:null;}
function clrTransient(){g.get("g_returnScene").setString("");g.get("g_encounter").setString("");
  g.get("g_returnX").setNumber(-1);g.get("g_returnY").setNumber(-1);}
function newGame(){
  g.get("g_flags").setString(JSON.stringify({step:0,reg:0,ch1:0}));
  g.get("g_party").setString(JSON.stringify([mk("ludo"),mk("aaron")]));
  g.get("g_gold").setNumber(30);
  g.get("g_itemInv").setString('{"potion":4}');
  g.get("g_eqInv").setString('["swift_boots","lucky_coin"]');
  g.get("g_chests").setString("[]");
  clrTransient(); g.get("g_result").setString(""); g.get("g_spawn").setString("home");
  g.get("g_autoBattle").setNumber(0);
  try{if(window.localStorage)window.localStorage.removeItem("cq_save");}catch(e){}
  gdjs.evtTools.sound.playSound(rs,"select.wav",false,100,1);
  gdjs.evtTools.runtimeScene.replaceScene(rs,"Town",true);
}
function loadSave(){
  try{
    var s=JSON.parse(window.localStorage.getItem("cq_save"));
    g.get("g_flags").setString(s.flags);g.get("g_party").setString(s.party);
    g.get("g_eqInv").setString(s.eqInv);g.get("g_itemInv").setString(s.itemInv);
    g.get("g_gold").setNumber(s.gold);g.get("g_chests").setString(s.chests);
    g.get("g_autoBattle").setNumber(s.auto||0);
    clrTransient();
    g.get("g_returnX").setNumber(s.x);g.get("g_returnY").setNumber(s.y);
    g.get("g_result").setString("resume");g.get("g_spawn").setString("");
    var VALID={Town:1,Forest:1,Forest2:1,Mine:1,Cave:1},sc=VALID[s.scene]?s.scene:"Town";
    gdjs.evtTools.sound.playSound(rs,"select.wav",false,100,1);
    gdjs.evtTools.runtimeScene.replaceScene(rs,sc,true);
  }catch(e){newGame();}
}
var hasSave=false;try{hasSave=!!(window.localStorage&&window.localStorage.getItem("cq_save"));}catch(e){}
if(rs.__ts===undefined){rs.__ts=0;rs.__tsel=0;rs.__kp={};rs.__mb=false;}   // 0=登陸 1=選單
function kHit(k){var d=gdjs.evtTools.input.isKeyPressed(rs,k),was=rs.__kp[k];rs.__kp[k]=d;return d&&!was;}
// 本幀點擊點：觸控起始 ＋ 滑鼠左鍵按下邊緣（皆支援）
var clicks=[];
try{var _t=im.getStartedTouchIdentifiers();for(var i=0;i<_t.length;i++)clicks.push([im.getTouchX(_t[i]),im.getTouchY(_t[i])]);}catch(e){}
try{var _mb=gdjs.evtTools.input.isMouseButtonPressed(rs,"Left"); if(_mb&&!rs.__mb)clicks.push([im.getCursorX(),im.getCursorY()]); rs.__mb=_mb;}catch(e){}

var oS=oneT("TxtStart"),oC=oneT("TxtCont"),oR=oneT("TxtRestart"),oN=oneT("TxtNew");
function cxc(o){return o?640-o.getWidth()/2:0;}
function hitObj(o,p){return o&&!o.isHidden()&&o.insideObject(p[0],p[1]);}
function go(opt){gdjs.evtTools.sound.playSound(rs,"select.wav",false,100,1); if(opt==="cont")loadSave(); else newGame();}  // restart/new 皆 newGame
if(oS)oS.setPosition(cxc(oS),548);

if(rs.__ts===0){
  // 登陸：只出現「開始遊戲」（無框、文字描邊）；按任意鍵或點擊 → 選單
  if(oS)oS.hide(false); if(oC)oC.hide(true); if(oR)oR.hide(true); if(oN)oN.hide(true);
  if(kHit("Space")||kHit("Return")||kHit("Up")||kHit("Down")||clicks.length>0){
    rs.__ts=1; rs.__tsel=0; gdjs.evtTools.sound.playSound(rs,"cursor.mp3",false,100,1);
  }
}else if(hasSave){
  // 有存檔：繼續冒險（預設）／重新開始
  if(oS)oS.hide(true); if(oN)oN.hide(true); if(oC)oC.hide(false); if(oR)oR.hide(false);
  if(oC)oC.setPosition(cxc(oC),500); if(oR)oR.setPosition(cxc(oR),584);
  if(kHit("Up")||kHit("Down")){rs.__tsel=(rs.__tsel+1)%2;gdjs.evtTools.sound.playSound(rs,"cursor.mp3",false,100,1);}
  var selv=rs.__tsel===0?"cont":"restart";
  if(oC)oC.setColor(selv==="cont"?"255;255;255":"148;150;162");
  if(oR)oR.setColor(selv==="restart"?"255;255;255":"148;150;162");
  for(var j=0;j<clicks.length;j++){
    if(hitObj(oC,clicks[j])){go("cont");return;}
    if(hitObj(oR,clicks[j])){go("restart");return;}
  }
  if(kHit("Space")||kHit("Return")){go(selv);return;}
}else{
  // 無存檔：只「開始新遊戲」（語意較對，取代「重新開始」）
  if(oS)oS.hide(true); if(oC)oC.hide(true); if(oR)oR.hide(true); if(oN)oN.hide(false);
  if(oN){oN.setPosition(cxc(oN),548); oN.setColor("255;255;255");}
  for(var j2=0;j2<clicks.length;j2++){ if(hitObj(oN,clicks[j2])){go("new");return;} }
  if(kHit("Space")||kHit("Return")){go("new");return;}
}
""".replace("__CONTENT__",json.dumps(CONTENT,ensure_ascii=False)))]

# ================= 11. 專案組裝 =================
resources=[res_("atlas.png","assets/map/atlas.png","image"),
           res_("atlas_forest.png","assets/map/atlas_forest.png","image"),   # 森林專屬地面（anokolisa，art_v14 產）
           res_("atlas_town.png","assets/map/atlas_town.png","image")]        # 城鎮專屬地面（anokolisa，art_v14 產）
for t in ["town","forest","forest2","mine","cave"]:
    resources.append(res_(t+".tmj",f"assets/map/{t}.tmj","tilemap"))
for f in sorted(os.listdir(f"{A}/char")):
    if f.endswith(".png"): resources.append(res_(f,f"assets/char/{f}","image"))
for f in sorted(os.listdir(f"{A}/props")):
    # 室內折衷：手繪 intc_<key> 當背景要註冊；原始 int_<key>（含洋紅底）不入庫（int_room_* 房間外殼保留）
    if f.startswith("int_") and not f.startswith("int_room"): continue
    if f.endswith(".png"): resources.append(res_(f,f"assets/props/{f}","image"))
for f in sorted(os.listdir(f"{A}/battle")):
    if f.endswith(".png"): resources.append(res_(f,f"assets/battle/{f}","image"))
for f in sorted(os.listdir(f"{A}/ui")):
    if f.endswith(".png"): resources.append(res_(f,f"assets/ui/{f}","image",True))
for f in sorted(os.listdir(f"{A}/sfx")):
    if f.endswith((".wav",".mp3")): resources.append(res_(f,f"assets/sfx/{f}","audio"))
for f in sorted(os.listdir(f"{A}/bgm")):
    if f.endswith(".mp3"): resources.append(res_(f,f"assets/bgm/{f}","audio"))

game={"firstLayout":"Title","gdVersion":{"major":5,"minor":6,"build":268,"revision":0},
 "properties":{"adaptGameResolutionAtRuntime":True,"antialiasingMode":"none",
   "antialisingEnabledOnMobile":False,"folderProject":False,"orientation":"landscape",
   "packageName":"com.wising.crystalquest","pixelsRounding":True,"projectUuid":str(uuid.uuid4()),
   "scaleMode":"nearest","sizeOnStartupMode":"adaptWidth","templateSlug":"",
   "version":"2.1.0","name":"水晶奇譚","description":"水晶奇譚 Crystal Tale — 芳蕾鎮篇：序章+第一章",
   "author":"John Chou","windowWidth":1280,"windowHeight":720,
   "latestCompilationDirectory":"","maxFPS":60,"minFPS":20,"verticalSync":False,
   "platformSpecificAssets":{},
   "loadingScreen":{"backgroundColor":0,"backgroundFadeInDuration":0.2,"backgroundImageResourceName":"",
     "gdevelopLogoStyle":"light","logoAndProgressFadeInDuration":0.2,"logoAndProgressLogoFadeInDelay":0,
     "minDuration":1.0,"progressBarColor":16777215,"progressBarHeight":20,"progressBarMaxWidth":200,
     "progressBarMinWidth":40,"progressBarWidthPercent":30,"showGDevelopSplash":True,"showProgressBar":True},
   "watermark":{"placement":"bottom-left","showWatermark":True},
   "authorIds":[],"authorUsernames":[],"categories":[],"playableDevices":[],
   "extensionProperties":[],"platforms":[{"name":"GDevelop JS platform"}],
   "currentPlatform":"GDevelop JS platform"},
 "resources":{"resources":resources},"usedResources":[],"objects":[],
 "objectsFolderStructure":{"folderName":"__ROOT"},"objectsGroups":[],
 "variables":[svar("g_flags","string",""),svar("g_party","string",""),
   svar("g_gold","number",30),svar("g_itemInv","string",'{"potion":4}'),svar("g_eqInv","string","[]"),
   svar("g_encounter","string","forest"),svar("g_returnScene","string",""),
   svar("g_returnX","number",-1),svar("g_returnY","number",-1),
   svar("g_result","string",""),svar("g_spawn","string",""),
   svar("g_chests","string","[]"),svar("g_autoBattle","number",0)],
 "layouts":[title,town_sc,forest_sc,forest2_sc,mine_sc,cave_sc,battle],
 "externalEvents":[],"eventsFunctionsExtensions":[],"externalLayouts":[]}
json.dump(game,open(f"{PROJ}/game.json","w"),indent=1,ensure_ascii=False)
print("cq2 written:",len(game["layouts"]),"scenes,",len(resources),"resources")
print("town props:",len(tw.props),"forest:",len(fo.props),"mine:",len(mi.props),"cave:",len(ca.props))
