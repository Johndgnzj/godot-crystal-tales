#!/usr/bin/env python3
"""MOD-H 地圖生成管線：從 build_cq2.py 第 4 節移植地圖生成演算法，輸出 Godot 4.3 場景檔。

產出（重跑本腳本會整批重生，均為純文字、直接進 repo）：
  godot-project/scenes/world/{town,forest,forest2,mine,cave}.tscn   （路徑對齊 SceneRouter.SCENE_PATHS）
  godot-project/resources/map/tileset_world.tres / tileset_forest.tres

## 生成路線決定（TASKS/08_地圖管線.md「已知風險」的裁量結果）

採「重新生成」而非轉檔：演算法（迷宮雕刻 carve_maze／城鎮佈局 BLDG_LAYOUT／森林 make_forest）
自 build_cq2.py（唯讀參考）逐段移植，**global RNG 消耗順序與原腳本完全一致（seed=51）**，因此
五張地圖的地面 tile 佈局與 GDevelop 版 tmj 產物可逐格比對（本腳本 --check 內建比對）。
CONTENT.json 的寶箱座標是針對 seed=51 迷宮手選的隱蔽格，只有逐格一致才能保證寶箱不落在牆裡。

輸出端三個 Godot 化決定（理由詳見 world_scene.gd 檔頭與 TASKS/08）：
 1. 地面：TileMapLayer ＋ TileSet .tres（僅 atlas source，無 physics/custom data layer）。
    tile 資料以 PackedInt32Array export 存在場景根節點，_ready() 時 set_cell() 填入——避免手工
    生成 tile_map_data 二進位 blob（格式風險高、無 Godot 執行檔可驗證）。
 2. 碰撞：BLK 阻擋格經水平/垂直貪婪合併成少量 StaticBody2D 矩形，直接烘進 .tscn。比 per-tile
    physics 形狀數量少一個數量級，也避免 CharacterBody2D 滑行時卡內部邊。**BLK 是 per-cell 資料
    （樹/建築擋在草地上），本來就無法映射到 per-tile-type 的 TileSet physics。**
 3. ENC：沿用 CFG.ENC 字串陣列（encounter_tracker.gd 檔頭接法 (b)），存場景根節點 export。

## foot=(0,0,0,0) 陷阱（新舊行為差異，其他任務注意）

GDevelop 版 `prop(..., foot=(0,0,0,0))` 代表「擋住所在那 1 格」（零 offset 的 1x1 footprint），
不是「無碰撞」。本移植**保留原語意**（BLK 需與 GDevelop 版逐格一致），無碰撞的 prop 一律
`foot=None`（不傳）。Godot 端輸出層沒有這個坑：碰撞矩形是從 BLK 網格烘出來的，prop 本身不帶
碰撞概念。

用法：
  python3 gen_maps.py            # 生成 + 連通性 assert + （找得到參考 tmj 時）逐格比對
  python3 gen_maps.py --no-check # 只生成
"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))            # godot-project/
REPO = os.path.dirname(GODOT)
SCENES_DIR = os.path.join(GODOT, "scenes", "world")
RES_MAP_DIR = os.path.join(GODOT, "resources", "map")
CONTENT = json.load(open(os.path.join(GODOT, "resources", "content", "content.json")))
DIALOGUE = json.load(open(os.path.join(GODOT, "resources", "content", "dialogue.json")))
# GDevelop 版 tmj 產物（唯讀參考，僅比對用；不存在時跳過比對）
REF_TMJ_DIR = os.path.join(
    os.path.dirname(REPO), "gd-crystal-tales", "projects", "crystal-quest", "assets", "map"
)

TS = 32
COLS = 6
# atlas tile 順序（build_cq2.py L26-31，tile id = index+1，同 tmj 的 gid）
TILES = ["grass", "grassf", "path", "dirt", "tgrass", "water", "sand", "bridge",
         "rockfloor", "gravel", "cavefloor", "cavedark", "rail", "farm",
         "grass2", "grass3", "plaza",
         "pn", "ps", "pw", "pe", "pnw", "pne", "psw", "pse", "pc",
         "pinw", "pine", "pisw", "pise",
         "cwall", "cwtop", "fwall", "ctop"]
G = {n: i + 1 for i, n in enumerate(TILES)}
# 大樹 96x120，樹底對齊格底、水平置中（build_cq2.py L72-73）
TREE_W, TREE_H = 96, 120
TPX, TPY = -(TREE_W - 32) // 2, 32 - TREE_H
# 玩家腳點 offset：Godot 玩家節點 origin＝GDevelop 腳點（見 world_scene.gd 檔頭「座標約定」）
FEET_X, FEET_Y = 32, 54

random.seed(51)   # build_cq2.py L19；第 4 節前無其他全域 random 消耗（已逐行查核）


# ================= MapB 與迷宮工具（build_cq2.py L531-627 逐段移植）=================
class MapB:
    def __init__(s, MW, MH, base):
        s.MW, s.MH = MW, MH
        s.g = [base] * (MW * MH)
        s.blocked = [[False] * MW for _ in range(MH)]
        s.enc = [[False] * MW for _ in range(MH)]
        s.props = []
        for yy in range(MH):
            s.blocked[yy][0] = s.blocked[yy][MW - 1] = True
        for xx in range(MW):
            s.blocked[0][xx] = s.blocked[MH - 1][xx] = True

    def set(s, x, y, t):
        if 0 <= x < s.MW and 0 <= y < s.MH:
            s.g[y * s.MW + x] = t

    def get(s, x, y):
        return s.g[y * s.MW + x]

    def rect(s, x1, y1, x2, y2, t):
        for yy in range(y1, y2 + 1):
            for xx in range(x1, x2 + 1):
                s.set(xx, yy, t)

    def block(s, x1, y1, x2=None, y2=None):
        x2 = x2 if x2 is not None else x1
        y2 = y2 if y2 is not None else y1
        for yy in range(y1, y2 + 1):
            for xx in range(x1, x2 + 1):
                if 0 <= xx < s.MW and 0 <= yy < s.MH:
                    s.blocked[yy][xx] = True

    def unblock(s, x1, y1, x2=None, y2=None):
        x2 = x2 if x2 is not None else x1
        y2 = y2 if y2 is not None else y1
        for yy in range(y1, y2 + 1):
            for xx in range(x1, x2 + 1):
                if 0 <= xx < s.MW and 0 <= yy < s.MH:
                    s.blocked[yy][xx] = False

    def mark_enc(s):
        for yy in range(s.MH):
            for xx in range(s.MW):
                if s.g[yy * s.MW + xx] in (G["tgrass"], G["gravel"]):
                    s.enc[yy][xx] = True

    # foot 語意照抄 GDevelop 版：foot=(0,0,0,0) 是「擋 1 格」不是「無碰撞」（見檔頭說明）。
    def prop(s, name, tx, ty, foot=None, px=0, py=0):
        s.props.append((name, tx * TS + px, ty * TS + py))
        if foot:
            s.block(tx + foot[0], ty + foot[1], tx + foot[2], ty + foot[3])

    def trees_border(s, skip=(), step=2):
        for xx in range(1, s.MW - 1, step):
            if (xx, 1) not in skip and (xx, 2) not in skip and (xx, 3) not in skip \
                    and not s.blocked[3][xx] and s.g[3 * s.MW + xx] == G["grass"]:
                s.prop("Tree", xx, 3, px=TPX, py=TPY)
                s.block(xx, 1); s.block(xx, 2); s.block(xx, 3)
            yy = s.MH - 2
            if (xx, yy) not in skip and not s.blocked[yy][xx] and s.g[yy * s.MW + xx] == G["grass"]:
                s.prop("Tree", xx, yy, px=TPX, py=TPY)
                s.block(xx, yy)
        for yy in range(2, s.MH - 2, step + 1):
            for xx in (1, s.MW - 2):
                if (xx, yy) not in skip and not s.blocked[yy][xx] and s.g[yy * s.MW + xx] == G["grass"]:
                    s.prop("Tree", xx, yy, px=TPX, py=TPY)
                    s.block(xx, yy)

    def strs(s):
        B = [''.join('1' if s.blocked[y][x] else '0' for x in range(s.MW)) for y in range(s.MH)]
        E = [''.join('1' if s.enc[y][x] else '0' for x in range(s.MW)) for y in range(s.MH)]
        return B, E


def carve_maze(mb, x0, y0, x1, y1, wall, floor):
    """區域填牆後挖迷宮。cell=3（走廊2+牆1），走廊統一 2 格寬。（build_cq2.py L581-604）"""
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            mb.set(xx, yy, wall)
    mb.block(x0, y0, x1, y1)
    cw, ch = (x1 - x0) // 3, (y1 - y0) // 3

    def base(cx, cy):
        return (x0 + 1 + cx * 3, y0 + 1 + cy * 3)

    def open_rect(xa, ya, xb, yb):
        for yy in range(ya, yb + 1):
            for xx in range(xa, xb + 1):
                mb.set(xx, yy, floor)
                mb.unblock(xx, yy)

    seen = [[False] * cw for _ in range(ch)]
    st = [(random.randrange(cw), random.randrange(ch))]
    seen[st[0][1]][st[0][0]] = True
    bx, by = base(*st[0])
    open_rect(bx, by, bx + 1, by + 1)
    while st:
        cx, cy = st[-1]
        nbrs = [(nx, ny) for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1))
                if 0 <= nx < cw and 0 <= ny < ch and not seen[ny][nx]]
        if not nbrs:
            st.pop()
            continue
        nx, ny = random.choice(nbrs)
        seen[ny][nx] = True
        ax, ay = base(cx, cy)
        bx2, by2 = base(nx, ny)
        open_rect(min(ax, bx2), min(ay, by2), max(ax, bx2) + 1, max(ay, by2) + 1)
        st.append((nx, ny))


def tunnel(mb, x, y, dx, dy, floor, wall_ok=None):
    while 1 < x < mb.MW - 2 and 1 < y < mb.MH - 2:
        w = [(x, y), (x + 1, y)] if dy else [(x, y), (x, y + 1)]
        if all(not mb.blocked[wy][wx] for wx, wy in w):
            break
        for wx, wy in w:
            mb.set(wx, wy, floor)
            mb.unblock(wx, wy)
        x += dx
        y += dy


def open_rect_on(mb, xa, ya, xb, yb, floor):
    for yy in range(ya, yb + 1):
        for xx in range(xa, xb + 1):
            mb.set(xx, yy, floor)
            mb.unblock(xx, yy)


def assert_reachable(mb, start, goals, name):
    """連通性 assert 原樣保留（build_cq2.py L616-627）：「build 過＝路通」。"""
    from collections import deque
    q = deque([start])
    seen = {start}
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < mb.MW and 0 <= ny < mb.MH and (nx, ny) not in seen and not mb.blocked[ny][nx]:
                seen.add((nx, ny))
                q.append((nx, ny))
    for gname, g in goals:
        assert g in seen, f"{name}: {gname}{g} 從 {start} 不可達"
    return seen


# ================= Town 42x30（build_cq2.py L629-732）=================
tw = MapB(42, 30, G["grass"])
for _ in range(140):
    tw.set(random.randrange(42), random.randrange(30), G["grassf"])
tw.rect(20, 0, 23, 29, G["path"])
tw.rect(0, 13, 41, 16, G["path"])
tw.rect(18, 10, 25, 17, G["plaza"])
tw.rect(30, 22, 37, 27, G["farm"])

# 六棟建築（ext_*.png 大圖原生尺寸，customSize 縮到底部 5 格寬；L639-689）
BLDG_EXT = {"BGuild": (634, 858), "BInn": (605, 822), "BShrine": (783, 861),
            "BMayor": (1022, 1023), "BShop": (709, 848), "BSmith": (660, 859)}
BLDG_KEY = {"BGuild": "guild", "BInn": "inn", "BShrine": "shrine",
            "BMayor": "mayor", "BShop": "shop", "BSmith": "smithy"}
BLDG_LAYOUT = [("BGuild", 6, 8, 5), ("BInn", 14, 8, 5), ("BShrine", 30, 8, 5),
               ("BMayor", 37, 9, 5), ("BShop", 6, 24, 5), ("BSmith", 14, 24, 5)]
BLDG_SIZE = {}
BLDG_DOOR = {}
BLDG_RECT = {}


def place_building(mb, obj, dx, dy, bw):
    nw, nh = BLDG_EXT[obj]
    W = bw * TS
    H = int(round(W * nh / nw))
    sx = dx * TS + TS // 2 - W // 2
    sy = (dy * TS + 8) - H
    mb.props.append((obj, sx, sy))
    BLDG_SIZE[obj] = (W, H)
    BLDG_DOOR[obj] = (dx, dy)
    BLDG_RECT[obj] = (sx, sy, W, H)
    tx0 = max(0, sx // TS)
    tx1 = min(mb.MW - 1, (sx + W - 1) // TS)
    mb.block(tx0, dy - 2, tx1, dy - 1)
    for xx in range(tx0, tx1 + 1):
        if xx != dx:
            mb.block(xx, dy)


for _o, _dx, _dy, _bw in BLDG_LAYOUT:
    place_building(tw, _o, _dx, _dy, _bw)
tw.prop("Well", 18, 11, foot=(0, 0, 1, 0), px=4, py=-24)
tw.prop("Board", 10, 9, foot=(0, 0, 0, 0))   # foot=(0,0,0,0)＝擋 1 格（見檔頭陷阱說明）
for fx in range(30, 38):
    tw.prop("Fence", fx, 21, foot=(0, 0, 0, 0))
    tw.block(fx, 21)
_bld_clear = set()
for _o, _dx, _dy, _bw in BLDG_LAYOUT:
    _sx, _sy, _W, _H = BLDG_RECT[_o]
    _tx0 = _sx // TS - 1
    _tx1 = (_sx + _W - 1) // TS + 1
    _ty0 = _sy // TS - 1
    _ty1 = _dy + 4
    for _yy in range(_ty0, _ty1 + 1):
        for _xx in range(_tx0, _tx1 + 1):
            _bld_clear.add((_xx, _yy))
_top_skip = {(_x, _y) for _x in range(20, 24) for _y in (1, 2, 3)}
tw.trees_border(skip=_bld_clear | _top_skip, step=3)
# 散佈樹叢石：RNG 用 get/setstate 隔離（L705-716，逐行照抄以保持後續 RNG 流一致）
_rs = random.getstate()
placed = 0
_pl = []
_tries = 0
while placed < 13 and _tries < 1200:
    _tries += 1
    xx, yy = random.randrange(2, 40), random.randrange(2, 28)
    if tw.blocked[yy][xx] or (xx, yy) in _bld_clear or tw.get(xx, yy) not in (G["grass"], G["grassf"]) \
            or (13 <= xx <= 28 and 8 <= yy <= 19):
        continue
    if any(abs(xx - _px) <= 1 and abs(yy - _py) <= 1 for _px, _py in _pl):
        continue
    k = random.choice(["Tree", "Tree", "Bush", "Rock"])
    if k == "Tree":
        tw.prop("Tree", xx, yy, px=TPX, py=TPY)
    else:
        tw.prop(k, xx, yy, py=6)
    tw.block(xx, yy)
    _pl.append((xx, yy))
    placed += 1
random.setstate(_rs)


def deco(name, cells, **kw):
    for _cx, _cy in cells:
        if (_cx, _cy) in _bld_clear:
            continue
        tw.prop(name, _cx, _cy, **kw)


deco("Stall", [(18, 9), (21, 15)], py=-52)
deco("Lamp", [(18, 10), (24, 10), (18, 17), (24, 16), (27, 13)], py=-28)
deco("Flowerbed", [(22, 12), (19, 17), (28, 18)], py=6)
deco("Crate", [(9, 11), (10, 22)], py=4)
deco("Barrel", [(10, 11), (9, 22)], py=-2)
deco("Laundry", [(10, 26)], py=-12)
deco("Bush", [(24, 6), (24, 20), (29, 24), (26, 19), (34, 16)], py=6)
tw.unblock(20, 0, 23, 0)
tw.unblock(41, 13, 41, 16)
tw.mark_enc()

# ================= Forest 兩層 64x44（build_cq2.py L734-790）=================
_FRNG = random.Random(1414)
FTREES = [f"FTree{i}" for i in range(1, 7)]
_FDECO = ["FFern", "FMush", "FFlower", "FPebble", "FFern", "FFlower", "FBush"]


def _forest_decor(m):
    for y in range(1, m.MH - 1):
        for x in range(1, m.MW - 1):
            if m.blocked[y][x]:
                continue
            if m.get(x, y) in (G["grass"], G["grassf"], G["tgrass"]) and _FRNG.random() < 0.10:
                m.prop(_FRNG.choice(_FDECO), x, y, py=6)


def make_forest(MW, MH, entry_y, exit_east=False, boss=False):
    m = MapB(MW, MH, G["grass"])
    carve_maze(m, 1, 1, MW - 2, MH - 2, G["fwall"], G["grass"])
    for yy in range(MH):
        m.set(0, yy, G["fwall"])
        m.set(MW - 1, yy, G["fwall"])
    for xx in range(MW):
        m.set(xx, 0, G["fwall"])
        m.set(xx, MH - 1, G["fwall"])
    m.set(0, entry_y, G["path"])
    m.set(0, entry_y + 1, G["path"])
    open_rect_on(m, 1, entry_y, 2, entry_y + 1, G["path"])
    m.unblock(0, entry_y, 0, entry_y + 1)
    tunnel(m, 3, entry_y, 1, 0, G["path"])
    ey = MH // 2 - 1
    if boss:
        open_rect_on(m, MW - 8, ey - 4, MW - 3, ey + 4, G["dirt"])
        tunnel(m, MW - 9, ey, -1, 0, G["grass"])
    if exit_east:
        m.set(MW - 1, ey, G["path"])
        m.set(MW - 1, ey + 1, G["path"])
        open_rect_on(m, MW - 3, ey, MW - 2, ey + 1, G["path"])
        m.unblock(MW - 1, ey, MW - 1, ey + 1)
        tunnel(m, MW - 4, ey, -1, 0, G["path"])
    for y in range(1, MH - 1):
        for x in range(1, MW - 1):
            if not m.blocked[y][x] and m.get(x, y) == G["grass"]:
                r = random.random()
                if r < 0.10:
                    m.set(x, y, G["grassf"])
                elif r < 0.42:
                    m.set(x, y, G["tgrass"])
    for y in range(3, MH - 2):
        for x in range(2, MW - 2):
            if (m.get(x, y) == G["fwall"] and m.get(x, y - 1) == G["fwall"]
                    and m.get(x, y - 2) == G["fwall"] and random.random() < 0.22):
                m.prop(_FRNG.choice(FTREES), x, y, px=TPX, py=TPY)
    _forest_decor(m)
    m.mark_enc()
    return m


FW, FH = 64, 44
FEY = FH // 2 - 1
fo = make_forest(FW, FH, 15, exit_east=True)
fo2 = make_forest(FW, FH, FEY, boss=True)
_WALK_FO = (G["grass"], G["grassf"], G["tgrass"], G["path"], G["dirt"])
opens_fo = [(x, y) for y in range(3, FH - 3) for x in range(3, FW - 3)
            if not fo.blocked[y][x] and fo.get(x, y) in _WALK_FO]
HERB_TILES = []
for _lo, _hi in [(3, FW // 3), (FW // 3, 2 * FW // 3), (2 * FW // 3, FW - 3)]:
    _seg = [p for p in opens_fo if _lo <= p[0] < _hi]
    if _seg:
        HERB_TILES.append(min(_seg, key=lambda p: (abs(p[1] - FEY), p[0])))
assert_reachable(fo, (2, 15), [("東出口", (FW - 2, FEY))] +
                 [("鏡草%d" % _i, _t) for _i, _t in enumerate(HERB_TILES)], "forest")
assert_reachable(fo2, (2, FEY), [("頭目空地", (FW - 6, FEY))], "forest2")

# ================= Mine 60x42（build_cq2.py L792-832）=================
MMW, MMH = 60, 42
mi = MapB(MMW, MMH, G["rockfloor"])
carve_maze(mi, 1, 1, MMW - 2, MMH - 3, G["cwall"], G["rockfloor"])
for yy in range(MMH):
    mi.set(0, yy, G["cwall"])
    mi.set(MMW - 1, yy, G["cwall"])
for xx in range(MMW):
    mi.set(xx, 0, G["cwall"])
    if not (20 <= xx <= 23):
        mi.set(xx, MMH - 2, G["cwall"])
        mi.block(xx, MMH - 2)
        mi.set(xx, MMH - 1, G["cwall"])
open_rect_on(mi, 21, 2, 22, MMH - 2, G["path"])
mi.rect(21, 4, 22, 8, G["rail"])
for oy in (8, 16, 24, 32):
    tunnel(mi, 20, oy, -1, 0, G["rockfloor"])
    tunnel(mi, 23, oy, 1, 0, G["rockfloor"])
mi.prop("CaveMouth", 19, 1, foot=(0, 1, 4, 3), py=-40)
mi.unblock(21, 2, 22, 4)
for y in range(1, MMH - 2):
    for x in range(1, MMW - 1):
        if not mi.blocked[y][x] and mi.get(x, y) == G["rockfloor"] and random.random() < 0.40:
            mi.set(x, y, G["gravel"])
mi.rect(21, 18, 22, 26, G["gravel"])
for x, y in [(5, 7), (50, 11), (9, 29), (45, 33), (15, 19), (33, 37)]:
    if mi.blocked[y][x]:
        mi.prop("Support", x, y, foot=(0, 0, 0, 0))
opens_mi = [(x, y) for y in range(2, MMH - 3) for x in range(2, MMW - 2)
            if not mi.blocked[y][x] and not (20 <= x <= 23)]
_stals = random.sample(opens_mi, min(20, len(opens_mi)))
for x, y in _stals:
    mi.prop(random.choice(["StalGold", "StalBrown"]), x, y, py=8)
_dmi = [p for p in opens_mi if p not in _stals]
for _i, (x, y) in enumerate(_dmi[3::11][:9]):
    mi.prop(["DunBones", "DunSkull", "DunSkullPile", "DunWeb"][_i % 4], x, y, py=6)
mi.unblock(20, MMH - 1, 23, MMH - 1)
mi.mark_enc()
mleft = [p for p in opens_mi if p[0] < 20][0]
mright = [p for p in opens_mi if p[0] > 23][0]
_relic_cand = [p for p in opens_mi if p[1] < 16 and p not in _stals]
RELIC_TILE = min(_relic_cand, key=lambda p: (abs(p[0] - 21), p[1])) if _relic_cand else (19, 8)
assert_reachable(mi, (21, MMH - 2),
                 [("礦坑口", (21, 3)), ("左區", mleft), ("右區", mright), ("遺物點", RELIC_TILE)], "mine")

# ================= Cave 50x36（build_cq2.py L834-863）=================
CMW, CMH = 50, 36
ca = MapB(CMW, CMH, G["cavefloor"])
carve_maze(ca, 1, 2, CMW - 3, CMH - 4, G["cwall"], G["cavefloor"])
for yy in range(CMH):
    ca.set(0, yy, G["cwall"])
    ca.set(CMW - 1, yy, G["cwall"])
    ca.set(CMW - 2, yy, G["cwall"])
for xx in range(CMW):
    ca.set(xx, 0, G["cwall"])
    ca.set(xx, 1, G["cwtop"] if xx % 3 else G["cwall"])
    for yy in (CMH - 3, CMH - 2, CMH - 1):
        if not (17 <= xx <= 19):
            ca.set(xx, yy, G["cwall"])
            ca.block(xx, yy)
open_rect_on(ca, 14, 2, 22, 6, G["cavedark"])
ca.unblock(14, 2, 22, 6)
tunnel(ca, 17, 7, 0, 1, G["cavefloor"])
open_rect_on(ca, 17, CMH - 3, 19, CMH - 2, G["cavefloor"])
ca.rect(17, CMH - 1, 19, CMH - 1, G["cavefloor"])
ca.unblock(17, CMH - 1, 19, CMH - 1)
tunnel(ca, 17, CMH - 4, 0, -1, G["cavefloor"])
opens_ca = [(x, y) for y in range(7, CMH - 3) for x in range(2, CMW - 3) if not ca.blocked[y][x]]
for x, y in opens_ca:
    if random.random() < 0.16 and ca.get(x, y) == G["cavefloor"]:
        ca.set(x, y, G["cavedark"])
for x, y in random.sample(opens_ca, min(22, len(opens_ca))):
    if not (16 <= x <= 20):
        ca.prop(random.choice(["StalBrown", "StalBlack"]), x, y, py=8)
_dca = [p for p in opens_ca if not (16 <= p[0] <= 20)]
for _i, (x, y) in enumerate(_dca[5::13][:8]):
    ca.prop(["DunBones", "DunWeb", "DunSkull", "DunCrack"][_i % 4], x, y, py=6)
for yy in range(7, CMH - 4):
    for xx in range(1, CMW - 2):
        if not ca.blocked[yy][xx]:
            ca.enc[yy][xx] = True
assert_reachable(ca, (18, CMH - 2), [("魔影廳", (17, 4))], "cave")

# ================= 寶箱擋格＋重驗連通（build_cq2.py L865-885）=================
CHESTS = CONTENT.get("chests", [])
CHEST_BY_MAP = {}
for _c in CHESTS:
    CHEST_BY_MAP.setdefault(_c["map"], []).append(_c)
_CHEST_MAPREF = {
    "forest": (fo, (2, 15), [("東出口", (FW - 2, FEY))]),
    "forest2": (fo2, (2, FEY), [("頭目空地", (FW - 6, FEY))]),
    "mine": (mi, (21, MMH - 2), [("礦坑口", (21, 3)), ("左區", mleft), ("右區", mright)]),
    "cave": (ca, (18, CMH - 2), [("魔影廳", (17, 4))]),
}
for _mk, _cl in CHEST_BY_MAP.items():
    _mb, _start, _goals = _CHEST_MAPREF[_mk]
    for _c in _cl:
        assert not _mb.blocked[_c["ty"]][_c["tx"]], \
            f"{_mk} 寶箱 {_c['id']} 座標({_c['tx']},{_c['ty']})原本就是牆"
        _mb.block(_c["tx"], _c["ty"])
    _seen = assert_reachable(_mb, _start, _goals, _mk + "(含寶箱)")
    for _c in _cl:
        _nb = [(_c["tx"] + dx, _c["ty"] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        assert any(n in _seen for n in _nb), \
            f"{_mk} 寶箱 {_c['id']}({_c['tx']},{_c['ty']}) 無可達鄰格，玩家開不到"

# ================= 後處理（build_cq2.py L887-925）=================
FAMILY = None


def autotile(mb):
    global FAMILY
    if FAMILY is None:
        FAMILY = {G["path"], G["dirt"], G["bridge"], G["farm"], G["rail"], G["plaza"], G["pc"],
                  G["pn"], G["ps"], G["pw"], G["pe"], G["pnw"], G["pne"], G["psw"], G["pse"],
                  G["pinw"], G["pine"], G["pisw"], G["pise"]}
    src = list(mb.g)

    def fam(xx, yy):
        if xx < 0 or yy < 0 or xx >= mb.MW or yy >= mb.MH:
            return True
        return src[yy * mb.MW + xx] in FAMILY

    for y in range(mb.MH):
        for x in range(mb.MW):
            t = src[y * mb.MW + x]
            if t not in (G["path"], G["dirt"]):
                continue
            T, B, L, R = fam(x, y - 1), fam(x, y + 1), fam(x - 1, y), fam(x + 1, y)
            m = {(1, 1, 1, 1): "pc", (0, 1, 1, 1): "pn", (1, 0, 1, 1): "ps", (1, 1, 0, 1): "pw",
                 (1, 1, 1, 0): "pe", (0, 1, 0, 1): "pnw", (0, 1, 1, 0): "pne",
                 (1, 0, 0, 1): "psw", (1, 0, 1, 0): "pse"}
            k = m.get((int(T), int(B), int(L), int(R)), "pc")
            tile = G[k]
            if k == "pc":
                if not fam(x - 1, y - 1):
                    tile = G["pinw"]
                elif not fam(x + 1, y - 1):
                    tile = G["pine"]
                elif not fam(x - 1, y + 1):
                    tile = G["pisw"]
                elif not fam(x + 1, y + 1):
                    tile = G["pise"]
            mb.g[y * mb.MW + x] = tile


def grass_vary(mb):
    gv = [G["grass"], G["grass"], G["grass2"], G["grass3"]]
    mb.g = [random.choice(gv) if t == G["grass"] else t for t in mb.g]


def wall_caps(mb):
    wallset = {G["cwall"], G["ctop"]}
    src = list(mb.g)
    for y in range(mb.MH):
        for x in range(mb.MW):
            if src[y * mb.MW + x] in wallset:
                below = src[(y + 1) * mb.MW + x] if y + 1 < mb.MH else None
                mb.g[y * mb.MW + x] = G["cwall"] if (below is not None and below not in wallset) else G["ctop"]


autotile(tw); autotile(fo); autotile(fo2)
grass_vary(tw); grass_vary(fo); grass_vary(fo2)
wall_caps(mi)

# ================= Town 連通性 assert（build_cq2.py L1118-1125）=================
NPCS_TOWN = [
    {"obj": "NTina", "sprite": "tina", "id": "tina", "x": 7, "y": 9, "face": "Down"},
    {"obj": "NDora", "sprite": "dora", "id": "dora", "x": 14, "y": 9, "face": "Down"},
    {"obj": "NSister", "sprite": "sister", "id": "sister", "x": 29, "y": 9, "face": "Down"},
    {"obj": "NBarton", "sprite": "elder", "id": "barton", "x": 36, "y": 9, "face": "Down"},
    {"obj": "NGid", "sprite": "gid", "id": "gid", "x": 7, "y": 24, "face": "Down"},
    {"obj": "NHank", "sprite": "hank", "id": "hank", "x": 14, "y": 24, "face": "Down"},
    {"obj": "NMartha", "sprite": "martha", "id": "martha", "x": 17, "y": 25, "face": "Left"},
    {"obj": "NGray", "sprite": "gray", "id": "gray", "x": 17, "y": 13, "face": "Right"},
    {"obj": "NMira", "sprite": "villager", "id": "mira", "x": 32, "y": 24, "face": "Down"},
    {"obj": "NGuard", "sprite": "guard", "id": "guard", "x": 21, "y": 27, "face": "Down"},
]
_OUTDOOR_NPCS = {"NGray", "NMira", "NGuard"}
_town_goals = [("北出口", (21, 1)), ("森林出口", (40, 14)), ("告示板前", (10, 10))]
for _n in NPCS_TOWN:
    if _n["obj"] in _OUTDOOR_NPCS:
        _town_goals.append((_n["obj"], (_n["x"], _n["y"])))
for _o, _dx, _dy, _bw in BLDG_LAYOUT:
    _town_goals.append((_o + "門口下", (_dx, _dy + 1)))
assert_reachable(tw, (15, 12), _town_goals, "town")

# ================= 各場景 config（build_cq2.py L2461-2530 抄錄）=================
CUT_ONCE = {k: (v.get("once") or "") for k, v in DIALOGUE.get("cuts", {}).items()}


def px_rect(x1, y1, x2, y2):
    return [x1 * TS, y1 * TS, x2 * TS, y2 * TS]


town_cfg = {
    "spawns": {"home": [15 * TS, 12 * TS], "fromForest": [39 * TS, 14 * TS],
               "fromMine": [21 * TS, 2 * TS], "shrine": [30 * TS, 10 * TS]},
    "exits": [{"r": px_rect(40.4, 12.5, 42, 17), "to": "Forest", "spawn": "fromTown", "minStep": 3,
               "deny": "瑪琳：先跟亞倫先生去礦山吧！（往北）", "pushX": -24},
              {"r": px_rect(19.5, -1, 24, 0.8), "to": "Mine", "spawn": "fromTown"}],
    "triggers": [{"r": px_rect(19.5, 28, 24, 30), "msg": "南方大道封鎖中（找羅素隊長打聽）", "minStep": 0},
                 {"r": px_rect(0, 12, 1.2, 17), "msg": "西邊瀰漫著不自然的濃霧……現在進不去"}],
    "pickups": [],
    "cutOnEnter": [{"cut": "prologue_town", "step": 0}, {"cut": "town_start", "step": 3}],
    "encGroup": "", "bgm": "bgm_town.mp3",
}
forest_cfg = {
    "spawns": {"fromTown": [1 * TS + 8, 15 * TS], "fromForest2": [(FW - 2) * TS - 8, FEY * TS]},
    "exits": [{"r": px_rect(-1, 14, 0.7, 18), "to": "Town", "spawn": "fromForest"},
              {"r": px_rect(FW - 1.6, FEY - 1, FW + 0.5, FEY + 3), "to": "Forest2", "spawn": "fromForest"}],
    "triggers": [], "cutOnEnter": [], "encGroup": "forest", "bgm": "bgm_forest.mp3",
    "pickups": [{"r": px_rect(HERB_TILES[_i][0], HERB_TILES[_i][1], HERB_TILES[_i][0] + 1, HERB_TILES[_i][1] + 1),
                 "flag": "herb", "op": "inc", "once": "herb_p%d" % _i,
                 "showWhen": "mira2==1", "msg": "（採到一株發光的鏡草！）", "sfx": "learn.mp3",
                 "tex": "res://assets/props/herb.png"} for _i in range(len(HERB_TILES))],
}
forest2_cfg = {
    "spawns": {"fromForest": [1 * TS + 8, FEY * TS]},
    "exits": [{"r": px_rect(-1, FEY - 1, 0.7, FEY + 3), "to": "Forest", "spawn": "fromForest2"}],
    "triggers": [], "pickups": [], "cutOnEnter": [], "encGroup": "forest2", "bgm": "bgm_forest.mp3",
}
mine_cfg = {
    "spawns": {"start": [21 * TS, (MMH - 4) * TS], "fromTown": [21 * TS, (MMH - 3) * TS],
               "fromCave": [21 * TS, 4 * TS]},
    "exits": [{"r": px_rect(19.5, MMH - 0.8, 24, MMH + 1), "to": "Town", "spawn": "fromMine",
               "minStep": 3, "deny": "亞倫：現在回頭可不行。", "pushY": -20},
              {"r": px_rect(20, 1.2, 23, 2.6), "to": "Cave", "spawn": "fromMine"}],
    "triggers": [{"r": px_rect(20, 13, 23, 16), "cut": "mine_truth", "when": "ch2>=1"}],
    "cutOnEnter": [{"cut": "mine_intro", "step": 0}], "encGroup": "mine_step0", "bgm": "bgm_dungeon.mp3",
    "pickups": [{"r": px_rect(RELIC_TILE[0], RELIC_TILE[1], RELIC_TILE[0] + 1, RELIC_TILE[1] + 1),
                 "flag": "relic", "op": "set", "val": 1, "once": "relic_p",
                 "showWhen": "ch2>=1", "item": "miner_helmet",
                 "msg": "（撿到一頂鏽蝕的礦工頭盔……上頭刻著「阿吉」）", "sfx": "select.wav",
                 "tex": "res://assets/props/helmet.png"}],
}
cave_cfg = {
    "spawns": {"fromMine": [17 * TS + 16, int((CMH - 3.5) * TS)]},
    "exits": [{"r": px_rect(16.5, CMH - 0.7, 20, CMH + 1), "to": "Mine", "spawn": "fromCave"}],
    "triggers": [{"r": px_rect(14, 4, 22, 8), "cut": "demon_pre", "step": 0},
                 {"r": px_rect(14, 5, 22, 8), "msg": "一道死靈邪氣自更深處的礦道滲出……（第三章敬請期待）",
                  "when": "ch2>=2"},
                 {"r": px_rect(14, 5, 22, 8), "msg": "深處被落石封住了……得先查明礦山外圍的異變（第二章）",
                  "minStep": 3}],
    "pickups": [], "cutOnEnter": [{"cut": "cave_intro", "step": 0}], "encGroup": "cave",
    "bgm": "bgm_dungeon.mp3",
}

# 頭目/精英標記（build_cq2.py L1226/L1230 instance＋L2347-2373 判定資料）
forest2_boss = [{"show_when": "ch1==1", "encounter_id": "ch1_boss", "return_offset": (-90, 0),
                 "x": (FW - 6) * TS, "y": FEY * TS - 28, "w": 64, "h": 80,
                 "tex": "res://assets/battle/foe_maskedorc_0.png"}]
mine_boss = [{"show_when": "ch2==1", "encounter_id": "ch2_bear", "return_offset": (0, 90),
              "x": 21 * TS, "y": 8 * TS - 28, "w": 64, "h": 80,
              "tex": "res://assets/battle/foe_bear_0.png"}]

# prop 物件名 → 貼圖檔（world_objects()/build_world_scene() 的 anim 檔名對照，L1024-1210）
PROP_TEX = {
    "Tree": "tree.png", "Bush": "bush.png", "Rock": "rock.png", "Fence": "fence.png",
    "Well": "well.png", "Board": "board.png", "Barrel": "barrel.png", "Crate": "crate.png",
    "Lamp": "lamp.png", "Flowerbed": "flowerbed.png", "Stall": "stall.png", "Laundry": "laundry.png",
    "CaveMouth": "cavemouth.png", "Support": "support.png", "StalGold": "stal_gold.png",
    "StalBrown": "stal_brown.png", "StalBlack": "stal_black.png", "Rubble": "rubble.png",
    "DunSkull": "dun_skull.png", "DunSkullPile": "dun_skullpile.png", "DunBones": "dun_bones.png",
    "DunWeb": "dun_web.png", "DunCrack": "dun_crack.png",
    "FBush": "fst_deco_bush.png", "FFern": "fst_deco_fern.png", "FMush": "fst_deco_mush.png",
    "FFlower": "fst_deco_flower.png", "FPebble": "fst_deco_pebble.png",
    "BGuild": "extc_guild.png", "BInn": "extc_inn.png", "BShrine": "extc_shrine.png",
    "BMayor": "extc_mayor.png", "BShop": "extc_shop.png", "BSmith": "extc_smithy.png",
}
for _i in range(1, 7):
    PROP_TEX[f"FTree{_i}"] = f"fst_tree_{_i}.png"


# ================= Godot 輸出 =================
def fnum(v):
    """Godot 數字字面值：整數不帶小數點，浮點用最短表示。"""
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    if isinstance(v, int):
        return str(v)
    return repr(float(v))


def gd_esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def gd_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return fnum(v)
    if isinstance(v, str):
        return '"%s"' % gd_esc(v)
    if isinstance(v, tuple) and len(v) == 2:
        return "Vector2(%s, %s)" % (fnum(v[0]), fnum(v[1]))
    if isinstance(v, dict):
        return "{%s}" % ", ".join('"%s": %s' % (gd_esc(str(k)), gd_value(x)) for k, x in v.items())
    if isinstance(v, list):
        return "[%s]" % ", ".join(gd_value(x) for x in v)
    raise TypeError(f"無法序列化 {type(v)}: {v!r}")


def merge_block_rects(mb):
    """BLK 網格 → 貪婪合併矩形（tile 座標，含端點）。逐列取水平連續段，等寬段再向下合併。"""
    rects = []
    active = {}   # (x0,x1) -> [y0, y1]
    for y in range(mb.MH):
        runs = []
        x = 0
        while x < mb.MW:
            if mb.blocked[y][x]:
                x0 = x
                while x < mb.MW and mb.blocked[y][x]:
                    x += 1
                runs.append((x0, x - 1))
            else:
                x += 1
        nxt = {}
        for r in runs:
            if r in active:
                y0, _ = active.pop(r)
                nxt[r] = [y0, y]
            else:
                nxt[r] = [y, y]
        for (x0, x1), (y0, y1) in active.items():
            rects.append((x0, y0, x1, y1))
        active = nxt
    for (x0, x1), (y0, y1) in active.items():
        rects.append((x0, y0, x1, y1))
    return rects


class TscnWriter:
    def __init__(self):
        self.exts = []          # (type, path, id)
        self.subs = []          # (type, id, props)
        self.nodes = []         # (header_line, [prop_lines])
        self._shape_ids = {}

    def ext(self, rtype, path, eid):
        self.exts.append((rtype, path, eid))
        return 'ExtResource("%s")' % eid

    def rect_shape(self, w, h):
        key = ("rect", fnum(w), fnum(h))
        if key not in self._shape_ids:
            sid = "RectangleShape2D_%d" % (len(self._shape_ids) + 1)
            self.subs.append(("RectangleShape2D", sid, [("size", "Vector2(%s, %s)" % (fnum(w), fnum(h)))]))
            self._shape_ids[key] = sid
        return 'SubResource("%s")' % self._shape_ids[key]

    def circle_shape(self, r):
        key = ("circle", fnum(r))
        if key not in self._shape_ids:
            sid = "CircleShape2D_%d" % (len(self._shape_ids) + 1)
            self.subs.append(("CircleShape2D", sid, [("radius", fnum(float(r)))]))
            self._shape_ids[key] = sid
        return 'SubResource("%s")' % self._shape_ids[key]

    def node(self, name, ntype=None, parent=None, instance=None, groups=None, props=()):
        h = '[node name="%s"' % name
        if ntype:
            h += ' type="%s"' % ntype
        if parent is not None:
            h += ' parent="%s"' % parent
        if groups:
            h += " groups=[%s]" % ", ".join('"%s"' % g for g in groups)
        if instance:
            h += " instance=%s" % instance
        h += "]"
        self.nodes.append((h, list(props)))

    def text(self):
        load_steps = len(self.exts) + len(self.subs) + 1
        out = ["[gd_scene load_steps=%d format=3]" % load_steps, ""]
        for rtype, path, eid in self.exts:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, eid))
        if self.exts:
            out.append("")
        for rtype, sid, props in self.subs:
            out.append('[sub_resource type="%s" id="%s"]' % (rtype, sid))
            for k, v in props:
                out.append("%s = %s" % (k, v))
            out.append("")
        for header, props in self.nodes:
            out.append(header)
            for k, v in props:
                out.append("%s = %s" % (k, v))
            out.append("")
        return "\n".join(out).rstrip() + "\n"


def build_scene(scene_name, mapb, cfg, default_spawn, npcs, bosses, chests, tileset_res, atlas_png):
    w = TscnWriter()
    ws = w.ext("Script", "res://scripts/world/world_scene.gd", "1_ws")
    pc = w.ext("Script", "res://scripts/world/player_controller.gd", "2_pc")
    ez = w.ext("Script", "res://scripts/world/exit_zone.gd", "3_ez") if cfg["exits"] else None
    tz = w.ext("Script", "res://scripts/world/trigger_zone.gd", "4_tz") if cfg["triggers"] else None
    pz = w.ext("Script", "res://scripts/world/pickup_zone.gd", "5_pz") if cfg["pickups"] else None
    bm = w.ext("Script", "res://scripts/world/boss_mark.gd", "6_bm") if bosses else None
    dlg = w.ext("PackedScene", "res://scenes/ui/dialogue_box.tscn", "7_dlg")

    # ---- 根節點（world_scene.gd exports）----
    spawns = {k: (v[0] + FEET_X, v[1] + FEET_Y) for k, v in cfg["spawns"].items()}
    B, E = mapb.strs()
    prop_list = []
    for pn, px, py in mapb.props:
        entry = {"tex": "res://assets/props/" + PROP_TEX[pn], "x": px, "y": py, "w": 0, "h": 0}
        if pn in BLDG_SIZE:
            entry["w"], entry["h"] = BLDG_SIZE[pn]
        prop_list.append(entry)
    if scene_name == "Cave":   # build_cq2.py L1228：inst("Rubble",16*TS,1*TS,5,192,112)
        prop_list.append({"tex": "res://assets/props/rubble.png",
                          "x": 16 * TS, "y": 1 * TS, "w": 192, "h": 112})
    npc_list = [{"id": n["id"], "sprite": n["sprite"], "x": n["x"], "y": n["y"], "face": n["face"]}
                for n in npcs]
    chest_list = [{"id": c["id"], "tx": c["tx"], "ty": c["ty"]} for c in chests]
    root_props = [
        ("script", ws),
        ("scene_id", gd_value(scene_name)),
        ("map_w", str(mapb.MW)),
        ("map_h", str(mapb.MH)),
        ("ground_tiles", "PackedInt32Array(%s)" % ", ".join(str(t) for t in mapb.g)),
        ("blk_rows", "PackedStringArray(%s)" % ", ".join('"%s"' % r for r in B)),
        ("enc_rows", "PackedStringArray(%s)" % ", ".join('"%s"' % r for r in E)),
        ("spawns", gd_value(spawns)),
        ("enc_group", gd_value(cfg["encGroup"])),
        ("bgm", gd_value(cfg["bgm"])),
        ("cut_on_enter", gd_value(cfg["cutOnEnter"])),
        ("npc_list", gd_value(npc_list)),
        ("prop_list", gd_value(prop_list)),
        ("chest_list", gd_value(chest_list)),
        ("tileset_path", gd_value(tileset_res)),
        ("atlas_path", gd_value(atlas_png)),
    ]
    w.node(scene_name, "Node2D", None, props=root_props)
    w.node("Ground", "TileMapLayer", ".")

    # ---- 碰撞：BLK 合併矩形 + 地圖外圍四道護欄 ----
    w.node("Collision", "StaticBody2D", ".")
    rects = merge_block_rects(mapb)
    mw_px, mh_px = mapb.MW * TS, mapb.MH * TS
    borders = [(-TS, -TS, mw_px + TS, 0), (-TS, mh_px, mw_px + TS, mh_px + TS),
               (-TS, 0, 0, mh_px), (mw_px, 0, mw_px + TS, mh_px)]
    idx = 0
    for x0, y0, x1, y1 in rects:
        rw, rh = (x1 - x0 + 1) * TS, (y1 - y0 + 1) * TS
        cx, cy = x0 * TS + rw / 2, y0 * TS + rh / 2
        w.node("Col%d" % idx, "CollisionShape2D", "Collision",
               props=[("position", gd_value((cx, cy))), ("shape", w.rect_shape(rw, rh))])
        idx += 1
    for px0, py0, px1, py1 in borders:
        w.node("Col%d" % idx, "CollisionShape2D", "Collision",
               props=[("position", gd_value(((px0 + px1) / 2, (py0 + py1) / 2))),
                      ("shape", w.rect_shape(px1 - px0, py1 - py0))])
        idx += 1

    # ---- Zones ----
    w.node("Zones", "Node2D", ".")

    def zone_shape(parent, r):
        rw, rh = r[2] - r[0], r[3] - r[1]
        w.node("Shape", "CollisionShape2D", "Zones/" + parent,
               props=[("shape", w.rect_shape(rw, rh))])
        return ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)

    for i, e in enumerate(cfg["exits"]):
        name = "Exit%d" % i
        props = [("position", gd_value((((e["r"][0] + e["r"][2]) / 2), ((e["r"][1] + e["r"][3]) / 2)))),
                 ("script", ez),
                 ("to_scene", gd_value(e["to"])),
                 ("spawn_id", gd_value(e["spawn"]))]
        if "minStep" in e:
            props += [("has_min_step", "true"), ("min_step", str(e["minStep"]))]
            if e.get("deny"):
                props.append(("deny_msg", gd_value(e["deny"])))
            props.append(("push_offset", gd_value((e.get("pushX", 0), e.get("pushY", 0)))))
        w.node(name, "Area2D", "Zones", props=props)
        zone_shape(name, e["r"])
    for i, t in enumerate(cfg["triggers"]):
        name = "Trigger%d" % i
        props = [("position", gd_value((((t["r"][0] + t["r"][2]) / 2), ((t["r"][1] + t["r"][3]) / 2)))),
                 ("script", tz)]
        if t.get("when"):
            props.append(("when", gd_value(t["when"])))
        if t.get("cut"):
            props.append(("cut_id", gd_value(t["cut"])))
            if CUT_ONCE.get(t["cut"]):
                props.append(("cut_once_flag", gd_value(CUT_ONCE[t["cut"]])))
        if "step" in t:
            props += [("has_step", "true"), ("step", str(t["step"]))]
        if t.get("msg"):
            props.append(("msg", gd_value(t["msg"])))
        if "minStep" in t:
            props += [("has_min_step", "true"), ("min_step", str(t["minStep"]))]
        w.node(name, "Area2D", "Zones", props=props)
        zone_shape(name, t["r"])
    for i, pk in enumerate(cfg["pickups"]):
        name = "Pickup%d" % i
        props = [("position", gd_value((((pk["r"][0] + pk["r"][2]) / 2), ((pk["r"][1] + pk["r"][3]) / 2)))),
                 ("script", pz),
                 ("show_when", gd_value(pk["showWhen"])),
                 ("once_flag", gd_value(pk["once"])),
                 ("flag_name", gd_value(pk["flag"])),
                 ("op", gd_value(pk["op"]))]
        if pk["op"] == "set":
            props.append(("set_value", str(pk["val"])))
        if pk.get("item"):
            props.append(("item_id", gd_value(pk["item"])))
        props.append(("msg", gd_value(pk.get("msg", ""))))
        props.append(("sfx_name", gd_value(pk.get("sfx", "select.wav"))))
        props.append(("metadata/tex", gd_value(pk["tex"])))
        w.node(name, "Area2D", "Zones", props=props)
        zone_shape(name, pk["r"])
    for i, b in enumerate(bosses):
        name = "Boss%d" % i
        cx, cy = b["x"] + b["w"] / 2, b["y"] + b["h"] / 2
        props = [("position", gd_value((cx, cy))),
                 ("script", bm),
                 ("show_when", gd_value(b["show_when"])),
                 ("encounter_id", gd_value(b["encounter_id"])),
                 ("return_scene_id", gd_value(scene_name)),
                 ("return_offset", gd_value(b["return_offset"])),
                 ("metadata/tex", gd_value(b["tex"])),
                 ("metadata/w", fnum(float(b["w"]))),
                 ("metadata/h", fnum(float(b["h"])))]
        w.node(name, "Area2D", "Zones", props=props)
        w.node("Shape", "CollisionShape2D", "Zones/" + name,
               props=[("shape", w.circle_shape(80.0))])

    # ---- YSort＋Player ----
    w.node("YSort", "Node2D", ".", props=[("y_sort_enabled", "true")])
    px0, py0 = default_spawn[0] + FEET_X, default_spawn[1] + FEET_Y
    w.node("Player", "CharacterBody2D", "YSort", groups=["player"],
           props=[("position", gd_value((px0, py0))), ("script", pc)])
    w.node("Shape", "CollisionShape2D", "YSort/Player",
           props=[("position", "Vector2(0, -1)"), ("shape", w.rect_shape(22, 14))])
    w.node("Camera2D", "Camera2D", "YSort/Player")

    # ---- HUD 提示列＋對話框 ----
    w.node("HUD", "CanvasLayer", ".", props=[("layer", "5")])
    w.node("Prompt", "Label", "HUD",
           props=[("offset_left", "240.0"), ("offset_top", "500.0"),
                  ("offset_right", "1040.0"), ("offset_bottom", "532.0"),
                  ("theme_override_font_sizes/font_size", "22"),
                  ("horizontal_alignment", "1"), ("text", '""')])
    w.node("DialogueBox", parent=".", instance=dlg)
    return w.text()


def write_tileset(path, atlas_res):
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1"]' % atlas_res, "",
             '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_1"]',
             "texture = ExtResource(\"1\")",
             "texture_region_size = Vector2i(32, 32)"]
    for i in range(len(TILES)):
        cx, cy = i % COLS, i // COLS
        lines.append("%d:%d/0 = 0" % (cx, cy))
    lines += ["", "[resource]",
              "tile_size = Vector2i(32, 32)",
              'sources/0 = SubResource("TileSetAtlasSource_1")', ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))


def validate_tscn(text, fname):
    """輕量語法自檢：load_steps 數目、資源引用存在、節點父路徑存在、名稱不重複。"""
    import re
    exts = set(re.findall(r'\[ext_resource[^\]]*? id="([^"]+)"\]', text))
    subs = set(re.findall(r'\[sub_resource[^\]]*? id="([^"]+)"\]', text))
    m = re.search(r"\[gd_scene load_steps=(\d+) format=3\]", text)
    assert m, f"{fname}: 缺 gd_scene 標頭"
    assert int(m.group(1)) == len(exts) + len(subs) + 1, f"{fname}: load_steps 數目不符"
    for rid in re.findall(r'ExtResource\("([^"]+)"\)', text):
        assert rid in exts, f"{fname}: ExtResource {rid} 未宣告"
    for rid in re.findall(r'SubResource\("([^"]+)"\)', text):
        assert rid in subs, f"{fname}: SubResource {rid} 未宣告"
    paths = set()
    for nm, rest in re.findall(r'\[node name="([^"]+)"([^\]]*)\]', text):
        pm = re.search(r'parent="([^"]*)"', rest)
        if pm is None:
            assert not paths, f"{fname}: 多個根節點"
            paths.add(".")
            continue
        parent = pm.group(1)
        assert parent in paths, f"{fname}: 節點 {nm} 的 parent={parent} 不存在"
        p = nm if parent == "." else parent + "/" + nm
        assert p not in paths, f"{fname}: 節點路徑重複 {p}"
        paths.add(p)
    return len(paths)


def compare_with_tmj(name, mapb):
    ref = os.path.join(REF_TMJ_DIR, name + ".tmj")
    if not os.path.exists(ref):
        return None
    data = json.load(open(ref))["layers"][0]["data"]
    if len(data) != len(mapb.g):
        return (len(mapb.g), -1)
    diff = sum(1 for a, b in zip(mapb.g, data) if a != b)
    return (len(mapb.g), diff)


def main():
    check = "--no-check" not in sys.argv
    os.makedirs(SCENES_DIR, exist_ok=True)
    os.makedirs(RES_MAP_DIR, exist_ok=True)

    write_tileset(os.path.join(RES_MAP_DIR, "tileset_world.tres"), "res://assets/map/atlas.png")
    write_tileset(os.path.join(RES_MAP_DIR, "tileset_forest.tres"), "res://assets/map/atlas_forest.png")

    outdoor_npcs = [n for n in NPCS_TOWN if n["obj"] in _OUTDOOR_NPCS]
    scenes = [
        # (場景名, 檔名, MapB, cfg, default_spawn, npcs, bosses, tileset, atlas)
        ("Town", "town", tw, town_cfg, (15 * TS, 12 * TS), outdoor_npcs, [],
         "res://resources/map/tileset_world.tres", "res://assets/map/atlas.png"),
        ("Forest", "forest", fo, forest_cfg, (2 * TS, 15 * TS), [], [],
         "res://resources/map/tileset_forest.tres", "res://assets/map/atlas_forest.png"),
        ("Forest2", "forest2", fo2, forest2_cfg, (2 * TS, FEY * TS), [], forest2_boss,
         "res://resources/map/tileset_forest.tres", "res://assets/map/atlas_forest.png"),
        ("Mine", "mine", mi, mine_cfg, (21 * TS, (MMH - 4) * TS), [], mine_boss,
         "res://resources/map/tileset_world.tres", "res://assets/map/atlas.png"),
        ("Cave", "cave", ca, cave_cfg, (17 * TS + 16, (CMH - 2) * TS), [], [],
         "res://resources/map/tileset_world.tres", "res://assets/map/atlas.png"),
    ]
    tmj_key = {"Town": "town", "Forest": "forest", "Forest2": "forest2", "Mine": "mine", "Cave": "cave"}
    for scene_name, fname, mapb, cfg, spawn, npcs, bosses, tileset, atlas in scenes:
        # Godot 端補充 assert：出生點腳點所在 tile 必須可走（spawn 資料抄錄錯誤時立即擋下）
        for sid, (sx, sy) in cfg["spawns"].items():
            tx, ty = (sx + FEET_X) // TS, (sy + FEET_Y) // TS
            assert 0 <= tx < mapb.MW and 0 <= ty < mapb.MH and not mapb.blocked[ty][tx], \
                f"{scene_name} spawn {sid} 腳點 tile ({tx},{ty}) 是牆"
        chests = CHEST_BY_MAP.get(tmj_key[scene_name], [])
        text = build_scene(scene_name, mapb, cfg, spawn, npcs, bosses, chests, tileset, atlas)
        n_nodes = validate_tscn(text, fname + ".tscn")
        out = os.path.join(SCENES_DIR, fname + ".tscn")
        with open(out, "w") as f:
            f.write(text)
        blocked_n = sum(r.count("1") for r in mapb.strs()[0])
        enc_n = sum(r.count("1") for r in mapb.strs()[1])
        rect_n = len(merge_block_rects(mapb))
        line = (f"{scene_name:8s} {mapb.MW}x{mapb.MH}  blocked={blocked_n}  enc={enc_n}  "
                f"col_rects={rect_n}  nodes={n_nodes}  props={len(mapb.props)}")
        if check:
            cmp = compare_with_tmj(tmj_key[scene_name], mapb)
            if cmp is None:
                line += "  tmj=（無參考檔，略過比對）"
            else:
                total, diff = cmp
                line += f"  tmj_diff={diff}/{total}" + ("  ★逐格一致" if diff == 0 else "  ⚠不一致")
        print(line)
    print("連通性 assert：town/forest/forest2/mine/cave（含寶箱擋格重驗）全數通過")
    print("HERB_TILES=%s RELIC_TILE=%s" % (HERB_TILES, RELIC_TILE))


if __name__ == "__main__":
    main()
