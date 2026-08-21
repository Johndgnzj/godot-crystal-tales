#!/usr/bin/env python3
"""blueprint_from_image.py — 從既有手繪成圖逆推 40×40 地格藍圖（terrain／entrances）。

用途：M4 東之森深處（efd_a~n）這批圖是「藍圖機制之前」產的——圖已定稿、但 map-def 沒有
terrain，導致 blueprint_to_paths.gd 導不出碰撞（場景全空、走不了）。本工具把成圖的可走走廊
判讀成候選藍圖，讓設計員在網頁工具裡微調而不是從零塗 1600 格。

**候選＝給人複查用**，不是自動真相：預設只印 JSON＋產對照 PNG，要寫進 map-def.json 得加 --write。

用法：
  python3 tools/blueprint_from_image.py M4 a --preview /tmp/bp        # 單張，只看
  python3 tools/blueprint_from_image.py M4 --all --preview /tmp/bp    # 整區
  python3 tools/blueprint_from_image.py M4 a --write                  # 認可後寫回 map-def

判讀方式（每格取中央 70% 區域，避開格界混色）：
  圖外   飽和度與亮度都低（成圖的畫布底色 #333）→ '.'，且只認「從畫布邊界連通進來」的那片
  可走   格內幾乎沒有暗像素（樹冠必有陰影）＋亮度夠 → 'g' 草地／偏土黃且低飽和 → 'd' 泥路
  森林   其餘 → 'f'
再做形態學清理：去掉面積過小的孤立可走塊、填掉森林裡的單格小洞。

滿版化（--full-bleed）：比照 M5 nfr 的「整張都是地形」構圖——圖外與邊界石牆填成森林、
走廊延伸到畫布最外圈。用來把「圓形島嶼＋留白」的舊圖轉成滿版重產的版圖鎖定藍圖。

限制：
  - 樹冠與空地的界線本來就漸變，邊緣一兩格會有出入——複查時以「玩家看得出能不能走」為準。
  - 只認得草／土／森林這條森林圖的詞彙；河、橋、牆、山壁要在網頁工具補畫。
只用標準庫＋Pillow（與 tools/map_terrain_audit.py 同依賴）。
"""
import argparse
import colorsys
import json
import sys
from collections import deque
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("需要 Pillow：pip3 install Pillow")

ROOT = Path(__file__).resolve().parent.parent
MAP_DEF = ROOT / "assets-source/map/map-def.json"
PALETTE = ROOT / "assets-source/map/terrain_palette.json"

# 判讀門檻（efd_a/efd_j 實測校準；改這裡就好）
OUTSIDE_SAT = 0.15      # 飽和度低於此且亮度低 → 畫布外底色
OUTSIDE_VAL = 0.30
DARK_PIXEL = 0.16       # 低於此亮度算「暗像素」（樹冠陰影）
DARK_RATIO = 0.08       # 暗像素比例超過此值 → 判為森林
WALK_VAL = 0.30         # 可走區的最低平均亮度
WALK_VAL_SATURATED = 0.22   # 亮度低但顏色夠鮮（樹影下的走廊）也算可走
WALK_SAT_MIN = 0.55
WALK_HUE_MAX = 62.0     # 走廊是偏黃的踩踏地面；森林縫隙的草偏綠（色相 62 以上）
WALL_SAT = 0.45         # 貼著圖外、飽和度低於此的亮帶＝畫布邊界的石牆，不是路
DIRT_HUE = 48.0         # 色相低於此且飽和度不高 → 泥路而非草地
DIRT_SAT = 0.50
MIN_WALK_BLOB = 6       # 小於此格數的孤立可走塊 → 收回森林
MAX_HOLE = 2            # 小於等於此格數的森林小洞 → 填成可走
EXIT_BAND = [18, 19, 20, 21]   # 邊界開口統一落在畫布正中這 4 格，接圖才對得上
EDGE_MARGIN = 5         # 找出入口時容許路沒畫到最外圈的內縮格數（頂部常被石牆帶壓住）


def load_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except OSError as exc:
        sys.exit(f"讀不到 {path}：{exc}")
    except json.JSONDecodeError as exc:
        sys.exit(f"{path} 不是合法 JSON：{exc}")


def cell_features(im, cx, cy, cell):
    """回傳該格中央 70% 區域的 (亮度均值, 暗像素比例, 色相均值, 飽和度均值)。"""
    pad = int(cell * 0.15)
    box = (cx * cell + pad, cy * cell + pad,
           cx * cell + cell - pad, cy * cell + cell - pad)
    px = list(im.crop(box).getdata())
    n = len(px)
    v_sum = s_sum = h_sum = 0.0
    dark = 0
    for r, g, b in px:
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        v_sum += v
        s_sum += s
        h_sum += h * 360
        if v < DARK_PIXEL:
            dark += 1
    return v_sum / n, dark / n, h_sum / n, s_sum / n


def feature_grid(im, grid, cell):
    return [[cell_features(im, cx, cy, cell) for cx in range(grid)] for cy in range(grid)]


def is_walkable(vmean, dark, hmean, smean):
    if dark >= DARK_RATIO or hmean >= WALK_HUE_MAX:
        return False
    return vmean >= WALK_VAL or (vmean >= WALK_VAL_SATURATED and smean >= WALK_SAT_MIN)


def classify(feats, grid):
    """逐格初判，回傳 (code_grid, is_canvas_bg_grid)。"""
    codes = [["f"] * grid for _ in range(grid)]
    bg = [[False] * grid for _ in range(grid)]
    for cy in range(grid):
        for cx in range(grid):
            vmean, dark, hmean, smean = feats[cy][cx]
            if smean < OUTSIDE_SAT and vmean < OUTSIDE_VAL:
                bg[cy][cx] = True
                codes[cy][cx] = "."
            elif is_walkable(vmean, dark, hmean, smean):
                codes[cy][cx] = "d" if (hmean < DIRT_HUE and smean < DIRT_SAT) else "g"
    return codes, bg


def wall_from_border(codes, feats, outside, grid):
    """畫布邊界那圈石牆亮度像路但顏色灰——貼著圖外又不夠鮮的可走格收成牆。"""
    for cy in range(grid):
        for cx in range(grid):
            if codes[cy][cx] not in "gd":
                continue
            if feats[cy][cx][3] >= WALL_SAT:
                continue
            adj = any(0 <= cx + dx < grid and 0 <= cy + dy < grid and outside[cy + dy][cx + dx]
                      for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if adj:
                codes[cy][cx] = "#"
    return codes


def flood_outside(bg, grid):
    """只把「從畫布邊界連通進來」的底色格當圖外，圖中央的暗色空地不算。"""
    outside = [[False] * grid for _ in range(grid)]
    q = deque()
    for i in range(grid):
        for cx, cy in ((i, 0), (i, grid - 1), (0, i), (grid - 1, i)):
            if bg[cy][cx] and not outside[cy][cx]:
                outside[cy][cx] = True
                q.append((cx, cy))
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < grid and 0 <= ny < grid and bg[ny][nx] and not outside[ny][nx]:
                outside[ny][nx] = True
                q.append((nx, ny))
    return outside


def blobs(codes, grid, match):
    """4 向連通分塊，回傳符合 match(code) 的格子群組列表。"""
    seen = [[False] * grid for _ in range(grid)]
    out = []
    for cy in range(grid):
        for cx in range(grid):
            if seen[cy][cx] or not match(codes[cy][cx]):
                continue
            group, q = [], deque([(cx, cy)])
            seen[cy][cx] = True
            while q:
                x, y = q.popleft()
                group.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if (0 <= nx < grid and 0 <= ny < grid and not seen[ny][nx]
                            and match(codes[ny][nx])):
                        seen[ny][nx] = True
                        q.append((nx, ny))
            out.append(group)
    return out


def cleanup(codes, grid):
    """去掉零碎可走塊、填掉森林裡的小洞——導出的碰撞才不會坑坑洞洞。"""
    for group in blobs(codes, grid, lambda c: c in "gd"):
        if len(group) < MIN_WALK_BLOB:
            for x, y in group:
                codes[y][x] = "f"
    for group in blobs(codes, grid, lambda c: c == "f"):
        if len(group) <= MAX_HOLE:
            touches_outside = any(
                x == 0 or y == 0 or x == grid - 1 or y == grid - 1 for x, y in group)
            if not touches_outside:
                for x, y in group:
                    codes[y][x] = "g"
    return codes


def _longest_run(indices):
    """把一串索引切成連續段，回傳最長那段。"""
    best, cur = [], []
    for i in sorted(indices):
        if cur and i == cur[-1] + 1:
            cur.append(i)
        else:
            cur = [i]
        if len(cur) > len(best):
            best = list(cur)
    return best


def full_bleed(codes, exits, grid):
    """滿版化（比照 M5 nfr）：圖外與邊界石牆一律填森林，走廊延伸到畫布邊緣。

    這批 efd 圖原本是「圓形島嶼＋外圈留白」構圖，滿版後整張都是地形，出入口落在最外圈。
    """
    for cy in range(grid):
        for cx in range(grid):
            if codes[cy][cx] in ".#":
                codes[cy][cx] = "f"
            elif codes[cy][cx] == "d":
                codes[cy][cx] = "g"      # efd 走廊判讀 99% 是草徑，統一成 g 免得產圖描述混雜

    sides = {e.get("side") for e in exits.values() if isinstance(e, dict)}
    for side in sorted(s for s in sides if s):
        walk = [(x, y) for y in range(grid) for x in range(grid) if codes[y][x] == "g"]
        if not walk:
            continue
        # 舊圖的開口位置各張不同（d↔e、g↔h、i↔k、k↔n 原本就對不上接圖）。統一落在畫布
        # 正中 EXIT_BAND，再從原開口 L 形折過去——重產時每條邊兩側必然對齊。
        if side in ("west", "east"):
            edge = min(x for x, _ in walk) if side == "west" else max(x for x, _ in walk)
            band = _longest_run([y for x, y in walk if x == edge])
            link = range(min(band + EXIT_BAND), max(band + EXIT_BAND) + 1)
            for y in link:
                codes[y][edge] = "g"
            for y in EXIT_BAND:
                span = range(0, edge) if side == "west" else range(edge + 1, grid)
                for x in span:
                    codes[y][x] = "g"
        else:
            edge = min(y for _, y in walk) if side == "north" else max(y for _, y in walk)
            band = _longest_run([x for x, y in walk if y == edge])
            link = range(min(band + EXIT_BAND), max(band + EXIT_BAND) + 1)
            for x in link:
                codes[edge][x] = "g"
            for x in EXIT_BAND:
                span = range(0, edge) if side == "north" else range(edge + 1, grid)
                for y in span:
                    codes[y][x] = "g"

    # 走不到的空地就別留：只保留連得到畫布邊緣（＝連得到出入口）的可走區
    for group in blobs(codes, grid, lambda c: c == "g"):
        if not any(x in (0, grid - 1) or y in (0, grid - 1) for x, y in group):
            for x, y in group:
                codes[y][x] = "f"
    return split_path_core(codes, grid)


def split_path_core(codes, grid):
    """走廊分兩層（John 2026-08-20 定案，比照 nfr 的 d／g 分工）：離林緣 2 格以上的
    走廊核心＝`d` 泥徑，貼著林緣的一圈＝`g` 草地。畫布邊界不算林緣，路才穿得出去。"""
    INF = 99
    dist = [[INF] * grid for _ in range(grid)]
    q = deque()
    for cy in range(grid):
        for cx in range(grid):
            if codes[cy][cx] not in "gd":
                dist[cy][cx] = 0
                q.append((cx, cy))
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < grid and 0 <= ny < grid and dist[ny][nx] > dist[cy][cx] + 1:
                dist[ny][nx] = dist[cy][cx] + 1
                q.append((nx, ny))
    for cy in range(grid):
        for cx in range(grid):
            if codes[cy][cx] in "gd":
                codes[cy][cx] = "d" if dist[cy][cx] >= 2 else "g"
    return codes


def mark_entrances(codes, exits, grid):
    """依 map-def 的 exits 在對應邊找貼邊可走格標 E；找不到就回報，留給人補。"""
    ent = [["."] * grid for _ in range(grid)]
    missing = []
    sides = {e.get("side") for e in exits.values() if isinstance(e, dict)}
    for side in sorted(s for s in sides if s):
        found = []
        for depth in range(EDGE_MARGIN):
            for i in range(grid):
                if side == "west":
                    x, y = depth, i
                elif side == "east":
                    x, y = grid - 1 - depth, i
                elif side == "north":
                    x, y = i, depth
                elif side == "south":
                    x, y = i, grid - 1 - depth
                else:
                    continue
                if codes[y][x] in "gd":
                    found.append((x, y))
            if found:
                break
        if not found:
            missing.append(side)
            continue
        for x, y in found:
            ent[y][x] = "E"
    return ent, missing


def preview(im, codes, ent, grid, cell, out_path, palette_colors):
    """並排輸出「原圖 | 藍圖疊色」，格線每 5 格加粗，出入口畫紅框。"""
    side = 640
    base = im.convert("RGB").resize((side, side), Image.LANCZOS)
    over = base.copy()
    draw = ImageDraw.Draw(over, "RGBA")
    px = side / grid
    for cy in range(grid):
        for cx in range(grid):
            code = codes[cy][cx]
            if code == ".":
                continue
            rgb = palette_colors.get(code, (255, 0, 255))
            draw.rectangle([cx * px, cy * px, (cx + 1) * px, (cy + 1) * px],
                           fill=rgb + (110,))
    for i in range(grid + 1):
        w = 2 if i % 5 == 0 else 1
        draw.line([(i * px, 0), (i * px, side)], fill=(0, 0, 0, 90), width=w)
        draw.line([(0, i * px), (side, i * px)], fill=(0, 0, 0, 90), width=w)
    for cy in range(grid):
        for cx in range(grid):
            if ent[cy][cx] == "E":
                draw.rectangle([cx * px, cy * px, (cx + 1) * px, (cy + 1) * px],
                               outline=(255, 60, 60, 255), width=2)
    canvas = Image.new("RGB", (side * 2 + 8, side), (24, 24, 24))
    canvas.paste(base, (0, 0))
    canvas.paste(over, (side + 8, 0))
    try:
        canvas.save(out_path)
    except OSError as exc:
        sys.exit(f"寫不出預覽 {out_path}：{exc}")


def export_blueprint(codes, grid, cell, out_path, palette_colors):
    """輸出 1280×1280 純地格色塊圖（等同網頁工具的⬇️匯出），給產圖當版圖鎖定圖。"""
    tile = Image.new("RGB", (grid, grid))
    tile.putdata([palette_colors.get(codes[y][x], (58, 58, 58))
                  for y in range(grid) for x in range(grid)])
    try:
        tile.resize((grid * cell, grid * cell), Image.NEAREST).save(out_path)
    except OSError as exc:
        sys.exit(f"寫不出藍圖 {out_path}：{exc}")


def process(region_key, map_key, region, palette_colors, args):
    maps = region.get("maps", {})
    if map_key not in maps:
        sys.exit(f"{region_key} 沒有 map「{map_key}」")
    m = maps[map_key]
    grid = 40
    img_path = ROOT / "assets-source/map" / region["dir"] / f"{region['file_prefix']}_{map_key}.png"
    if not img_path.exists():
        print(f"  {map_key}: 找不到成圖 {img_path.name}，跳過")
        return None
    try:
        im = Image.open(img_path).convert("RGB")
    except OSError as exc:
        print(f"  {map_key}: 讀圖失敗（{exc}），跳過")
        return None
    if im.size[0] != im.size[1] or im.size[0] % grid:
        print(f"  {map_key}: 尺寸 {im.size} 不是 {grid} 的整數倍正方形，跳過")
        return None
    cell = im.size[0] // grid

    feats = feature_grid(im, grid, cell)
    codes, bg = classify(feats, grid)
    outside = flood_outside(bg, grid)
    codes = wall_from_border(codes, feats, outside, grid)
    for cy in range(grid):
        for cx in range(grid):
            if bg[cy][cx] and not outside[cy][cx]:
                codes[cy][cx] = "f"      # 圖中央的暗色地面不是圖外，當森林交給人複查
    codes = cleanup(codes, grid)
    if args.full_bleed:
        codes = full_bleed(codes, m.get("exits", {}), grid)
    ent, missing = mark_entrances(codes, m.get("exits", {}), grid)

    walk = sum(1 for row in codes for c in row if c in "gd")
    wall = sum(1 for row in codes for c in row if c == "#")
    out_cnt = sum(1 for row in codes for c in row if c == ".")
    forest = grid * grid - walk - wall - out_cnt
    note = f"，出入口沒找到可走格：{'/'.join(missing)}" if missing else ""
    print(f"  {map_key}: 可走 {walk}／森林 {forest}／邊界牆 {wall}／圖外 {out_cnt}{note}")

    if args.preview:
        out_dir = Path(args.preview)
        out_dir.mkdir(parents=True, exist_ok=True)
        preview(im, codes, ent, grid, cell,
                out_dir / f"{region['file_prefix']}_{map_key}_bp.png", palette_colors)
    if args.export_blueprint:
        bp_dir = Path(args.export_blueprint)
        bp_dir.mkdir(parents=True, exist_ok=True)
        export_blueprint(codes, grid, cell,
                         bp_dir / f"{region['file_prefix']}_{map_key}_blueprint.png",
                         palette_colors)
    return ["".join(r) for r in codes], ["".join(r) for r in ent]


def main():
    ap = argparse.ArgumentParser(description="從手繪成圖逆推 terrain 藍圖候選")
    ap.add_argument("region")
    ap.add_argument("maps", nargs="*", help="map key（可多個）；配 --all 時不用給")
    ap.add_argument("--all", action="store_true", help="整區所有 map")
    ap.add_argument("--preview", metavar="DIR", help="輸出對照 PNG 的目錄")
    ap.add_argument("--full-bleed", action="store_true",
                    help="滿版化（比照 M5 nfr）：圖外／邊界牆填森林、走廊延伸到畫布邊緣")
    ap.add_argument("--export-blueprint", metavar="DIR",
                    help="輸出 1280×1280 純地格色塊圖（產圖用的版圖鎖定圖）")
    ap.add_argument("--write", action="store_true", help="寫回 map-def.json（預設只看不寫）")
    ap.add_argument("--overwrite", action="store_true", help="連已有 terrain 的圖也覆蓋")
    args = ap.parse_args()

    data = load_json(MAP_DEF)
    palette = load_json(PALETTE)
    colors = {}
    for c in palette.get("cells", []):
        hexv = c.get("color")
        if hexv:
            colors[c["code"]] = tuple(int(hexv[i:i + 2], 16) for i in (1, 3, 5))

    region = data.get("regions", {}).get(args.region)
    if region is None:
        sys.exit(f"map-def 沒有地區 {args.region}")
    keys = list(region.get("maps", {})) if args.all else args.maps
    if not keys:
        sys.exit("要給 map key 或 --all")

    changed = 0
    print(f"{args.region} {region.get('name')}：{len(keys)} 張")
    for key in keys:
        m = region["maps"].get(key, {})
        if "terrain" in m and not args.overwrite:
            print(f"  {key}: 已有 terrain，跳過（要重算加 --overwrite）")
            continue
        result = process(args.region, key, region, colors, args)
        if result is None:
            continue
        terrain, ent = result
        if args.write:
            m["terrain"] = terrain
            if any("E" in row for row in ent):
                m["entrances"] = ent
            changed += 1

    if args.write and changed:
        try:
            with open(MAP_DEF, "w", encoding="utf-8") as fh:
                json.dump(data, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
        except OSError as exc:
            sys.exit(f"寫不回 map-def.json：{exc}")
        print(f"已寫回 map-def.json（{changed} 張）")
    elif args.write:
        print("沒有可寫入的結果")


if __name__ == "__main__":
    main()
