#!/usr/bin/env python3
"""map_terrain_audit.py — 比對「手繪成圖」與「map-def 地格」是否一致。

用途：抓出產圖沒有逐格照藍圖的偏差（例：芳蕾鎮成圖自己在南邊加了一整條石牆，
而 map-def 那一列是草地 → 碰撞跟畫面對不上，設計員只能手刷 tilemap，而手刷一定會被
invert_paths.gd 清掉）。偏差要回寫 map-def，不是刷 tilemap。

用法：
  python3 tools/map_terrain_audit.py <region> <map> [--out <png>] [--min-ratio 1.35]
  例：python3 tools/map_terrain_audit.py M1 town --out /tmp/audit.png

做法（自我校準，不需要手調顏色門檻）：
  1. 成圖降採樣到 40×40，每格取中央 60% 區域的平均色（避開格線與相鄰格滲色）。
  2. 對每個地格代碼，用 map-def 指派給它的所有格算出「這張圖裡該代碼長什麼樣」的參考色。
     ——參考色來自這張圖自己，所以不受畫風、色調、季節影響。
  3. 逐格找最近的參考色。若最近者不是 map-def 指派的代碼，且「次近距離 / 最近距離」
     ≥ min-ratio（預設 1.35，代表判斷夠明確），就列為疑似偏差。

  4. 同類偏差做 4 向連通，只回報 >= --min-blob（預設 4）的整塊——真偏差會成片
     （例：整條石牆），格界線上的混色是零散單格。

限制：
  - 只當「值得人眼複查的清單」，不要當自動修正依據。
  - 用 16px 子格層（PathPaint16）表達「半格可走」的格子，本工具會判為偏差（成圖看到的是路、
    map-def 寫的是阻擋代碼）——那是刻意的，複查時跳過。
只用標準庫＋Pillow（Pillow 已是 tools/compose_map_overviews.py 的既有依賴）。
"""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MAP_DEF = ROOT / "assets-source" / "map" / "map-def.json"
PALETTE = ROOT / "assets-source" / "map" / "terrain_palette.json"
GRID = 40
INSET = 0.2                      # 每格向內縮 20%，只取中央 60% 取樣


def load_json(path):
    try:
        return json.loads(path.read_text("utf-8"))
    except (OSError, ValueError) as exc:
        sys.exit("讀取失敗 %s：%s" % (path, exc))


def map_image_path(region, key, definition):
    reg = definition["regions"][region]
    rel = "%s/%s_%s.png" % (reg.get("dir", ""), reg.get("file_prefix", ""), key)
    for base in (ROOT / "assets-source" / "map", ROOT / "godot-project" / "assets" / "map"):
        p = base / rel
        if p.is_file():
            return p
    sys.exit("找不到地圖圖檔：%s（已找 assets-source/map 與 godot-project/assets/map）" % rel)


def cell_colors(img):
    """回傳 {(c,r): (r,g,b)}，每格取中央 60% 的平均色。"""
    img = img.convert("RGB")
    w, h = img.size
    cw, ch = w / GRID, h / GRID
    out = {}
    for r in range(GRID):
        for c in range(GRID):
            box = (round((c + INSET) * cw), round((r + INSET) * ch),
                   round((c + 1 - INSET) * cw), round((r + 1 - INSET) * ch))
            patch = img.crop(box)
            n = patch.width * patch.height
            if n == 0:
                out[(c, r)] = (0, 0, 0)
                continue
            px = list(patch.getdata())
            out[(c, r)] = tuple(sum(v[i] for v in px) // n for i in range(3))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("region")
    ap.add_argument("map_key")
    ap.add_argument("--out", help="輸出標註圖 PNG（可選）")
    ap.add_argument("--min-ratio", type=float, default=1.35,
                    help="次近/最近距離比，越大越保守（預設 1.35）")
    ap.add_argument("--min-blob", type=int, default=4,
                    help="同類偏差要連成幾格才回報（預設 4）。真偏差會成片（例：整條石牆），"
                         "邊界混色是零散單格 → 過濾掉雜訊")
    args = ap.parse_args()

    definition = load_json(MAP_DEF)
    if args.region not in definition.get("regions", {}):
        sys.exit("map-def 沒有地區 %s" % args.region)
    maps = definition["regions"][args.region].get("maps", {})
    if args.map_key not in maps:
        sys.exit("地區 %s 沒有地圖 %s" % (args.region, args.map_key))
    m = maps[args.map_key]
    terrain = m.get("terrain")
    if not terrain:
        sys.exit("%s/%s 沒有 terrain 藍圖，無從比對" % (args.region, args.map_key))
    pal = {c["code"]: c for c in load_json(PALETTE)["cells"]}

    img_path = map_image_path(args.region, args.map_key, definition)
    colors = cell_colors(Image.open(img_path))
    rows = [str(x) for x in terrain]

    # 各代碼的參考色＝map-def 指派給它的所有格在成圖中的平均色
    buckets = defaultdict(list)
    for r in range(GRID):
        for c in range(GRID):
            code = rows[r][c] if c < len(rows[r]) else "."
            if code == ".":
                continue
            buckets[code].append(colors[(c, r)])
    ref = {}
    for code, vals in buckets.items():
        if len(vals) < 4:            # 樣本太少的代碼不可信，跳過
            continue
        ref[code] = tuple(sum(v[i] for v in vals) / len(vals) for i in range(3))
    if len(ref) < 2:
        sys.exit("可用參考色不足（地格種類太少），無法比對")

    def dist(a, b):
        return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5

    suspects = []
    for r in range(GRID):
        for c in range(GRID):
            code = rows[r][c] if c < len(rows[r]) else "."
            if code == "." or code not in ref:
                continue
            ranked = sorted(((dist(colors[(c, r)], rc), k) for k, rc in ref.items()))
            best, second = ranked[0], ranked[1]
            if best[1] == code:
                continue
            ratio = (second[0] / best[0]) if best[0] > 0 else 999.0
            if ratio >= args.min_ratio:
                suspects.append((c, r, code, best[1], ratio))

    print("=== %s/%s 成圖 vs map-def 地格比對 ===" % (args.region, args.map_key))
    print("成圖：%s" % img_path.relative_to(ROOT))
    print("參考色（由這張圖自己算出）：")
    for code in sorted(ref):
        rc = ref[code]
        print("  %s %-6s 樣本 %4d 格  平均色 #%02x%02x%02x"
              % (code, pal.get(code, {}).get("label", "?"), len(buckets[code]),
                 int(rc[0]), int(rc[1]), int(rc[2])))
    # 連通塊過濾：同一組 (map-def 代碼, 猜測代碼) 內做 4 向連通，只留 >= min-blob 的塊
    grouped = defaultdict(set)
    for c, r, code, guess, _ in suspects:
        grouped[(code, guess)].add((c, r))
    keep = set()
    for pair, cs in grouped.items():
        seen = set()
        for cell in cs:
            if cell in seen:
                continue
            stack, blob = [cell], []
            seen.add(cell)
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (nx, ny) in cs and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(blob) >= args.min_blob:
                keep.update((pair, b) for b in blob)
    before = len(suspects)
    suspects = [s for s in suspects if ((s[2], s[3]), (s[0], s[1])) in keep]
    print("\n疑似偏差 %d 格（min-ratio=%.2f、min-blob=%d；已濾掉 %d 格零散邊界雜訊）："
          % (len(suspects), args.min_ratio, args.min_blob, before - len(suspects)))
    by_pair = defaultdict(list)
    for c, r, code, guess, ratio in suspects:
        by_pair[(code, guess)].append((c, r))
    for (code, guess), cells in sorted(by_pair.items(), key=lambda kv: -len(kv[1])):
        cw = pal.get(code, {}).get("walkable", True)
        gw = pal.get(guess, {}).get("walkable", True)
        flag = "★會影響碰撞" if cw != gw else "只是外觀差異"
        print("  map-def=%s(%s) 但成圖看起來像 %s(%s)  ×%d 格  %s"
              % (code, pal.get(code, {}).get("label", "?"), guess,
                 pal.get(guess, {}).get("label", "?"), len(cells), flag))
        print("     %s%s" % (sorted(cells)[:14], " …" if len(cells) > 14 else ""))

    if args.out:
        img = Image.open(img_path).convert("RGBA")
        cw, chh = img.width / GRID, img.height / GRID
        dr = ImageDraw.Draw(img, "RGBA")
        for c, r, code, guess, _ in suspects:
            differs = pal.get(code, {}).get("walkable", True) != pal.get(guess, {}).get("walkable", True)
            col = (255, 40, 40, 255) if differs else (255, 210, 40, 255)
            dr.rectangle([c * cw, r * chh, (c + 1) * cw - 1, (r + 1) * chh - 1], outline=col, width=3)
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        img.save(args.out)
        print("\n標註圖：%s（紅＝會影響碰撞、黃＝只是外觀）" % args.out)

    # 只有「會影響碰撞」的偏差才算失敗，方便接進 CI 或驗收腳本
    blocking = [s for s in suspects
                if pal.get(s[2], {}).get("walkable", True) != pal.get(s[3], {}).get("walkable", True)]
    print("\n會影響碰撞的偏差：%d 格" % len(blocking))
    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main())
