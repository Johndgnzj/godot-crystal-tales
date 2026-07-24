#!/usr/bin/env python3
"""blueprint_desc.py — 把某張地圖的 40×40 地格藍圖轉成中文結構描述（Layout / Exits 兩行）。

供 gen-map-prompt 組「手繪畫面地圖」產圖 prompt 時，貼進附加段的 Layout:/Exits:
（該圖若已有藍圖，就用這裡的輸出取代人工描述空間骨架與出入口）。

用法：python3 tools/map_editor/blueprint_desc.py <region> <map>
  例：python3 tools/map_editor/blueprint_desc.py M5 a

真相源：assets-source/map/map-def.json（每張圖的 terrain 藍圖）
        assets-source/map/terrain_palette.json（地格語意：label/walkable/role）
只用 Python 標準庫。輸出中文（John 指示產圖 prompt 一律中文）。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_DEF = ROOT / "assets-source" / "map" / "map-def.json"
PALETTE = ROOT / "assets-source" / "map" / "terrain_palette.json"
GRID = 40

SIDE_ZH = {"west": "西", "east": "東", "north": "北", "south": "南",
           "up": "上", "down": "下", "interior": "內部"}
ROW_ZH = {0: "北", 1: "中", 2: "南"}
COL_ZH = {0: "西", 1: "中", 2: "東"}
CORNER = {(0, 0): "西北", (0, 2): "東北", (2, 0): "西南", (2, 2): "東南"}


def band(i):
    return 0 if i <= 12 else (1 if i <= 26 else 2)


def zone_zh(c, r):
    rb, cb = band(r), band(c)
    if rb == 1 and cb == 1:
        return "中央"
    if rb == 1:
        return {0: "西側", 2: "東側"}[cb]
    if cb == 1:
        return {0: "北側", 2: "南側"}[rb]
    return CORNER[(rb, cb)]


def zones_occupied(cells):
    counts = {}
    for c, r in cells:
        z = zone_zh(c, r)
        counts[z] = counts.get(z, 0) + 1
    return [z for z, _ in sorted(counts.items(), key=lambda kv: -kv[1])]


def describe(label, cells, walkable):
    where = "、".join(zones_occupied(cells)[:3]) or "全圖"
    if walkable:
        xs = [c for c, _ in cells]
        ys = [r for _, r in cells]
        h, v = max(xs) - min(xs), max(ys) - min(ys)
        if h >= 24 and v < 12:
            return "一條%s自西向東貫穿%s" % (label, where)
        if v >= 24 and h < 12:
            return "一條%s自北向南貫穿%s" % (label, where)
        return "%s蜿蜒經過%s" % (label, where)
    return "%s分布於%s" % (label, where)


def edge_openings(e_cells):
    by = {}
    for c, r in e_cells:
        dw, de, dn, ds = c, GRID - 1 - c, r, GRID - 1 - r
        nearest = min(dw, de, dn, ds)
        if nearest == dw:
            side, idx = "west", r
        elif nearest == de:
            side, idx = "east", r
        elif nearest == dn:
            side, idx = "north", c
        else:
            side, idx = "south", c
        by.setdefault(side, []).append(idx)
    return {s: (min(v), max(v)) for s, v in by.items()}


def describe_to(to, regions, cur):
    if not to:
        return "（未接）"
    if ":" in to:
        rg, mk = to.split(":", 1)
        r = regions.get(rg, {})
        mm = r.get("maps", {}).get(mk, {})
        return mm.get("label") or (r.get("name", "") + mk) or to
    if to in regions:
        return regions[to].get("name", to) + "（待接整區）"
    mm = regions.get(cur, {}).get("maps", {}).get(to, {})
    return mm.get("label") or to


def main():
    if len(sys.argv) < 3:
        sys.exit("用法：blueprint_desc.py <region> <map>（例：M5 a）")
    region_id, map_key = sys.argv[1], sys.argv[2]
    data = json.loads(MAP_DEF.read_text("utf-8"))
    regions = data.get("regions", {})
    reg = regions.get(region_id)
    if not reg or map_key not in reg.get("maps", {}):
        sys.exit("map-def.json 找不到 %s:%s" % (region_id, map_key))
    m = reg["maps"][map_key]
    terrain = m.get("terrain")
    if not terrain:
        sys.exit("%s:%s 尚無 terrain 藍圖（先在網頁工具畫）" % (region_id, map_key))

    pal = json.loads(PALETTE.read_text("utf-8"))
    info, base, exit_code = {}, ".", "E"
    for cell in pal.get("cells", []):
        info[cell["code"]] = cell
        if cell.get("role") == "base":
            base = cell["code"]
        if cell.get("role") == "exit":
            exit_code = cell["code"]

    cells = {}
    for r, row in enumerate(terrain[:GRID]):
        for c, ch in enumerate(str(row)[:GRID]):
            cells.setdefault(ch, []).append((c, r))

    clauses = []
    for code, cs in cells.items():
        ci = info.get(code)
        if code in (base, exit_code, " ") or not ci or ci.get("describe", True) is False:
            continue                                          # 跳過空/草地等 describe=false 的一般地面
        clauses.append(describe(ci.get("label", code), cs, ci.get("walkable", True)))
    layout = "；".join(clauses) if clauses else "大致為開闊的可行走地面"

    openings = edge_openings(cells.get(exit_code, []))
    side_count = {}
    for ex in m.get("exits", {}).values():
        s = ex.get("side", "")
        side_count[s] = side_count.get(s, 0) + 1
    parts = []
    for ex in m.get("exits", {}).values():
        side = ex.get("side", "")
        tgt = describe_to(ex.get("to", ""), regions, region_id)
        op = openings.get(side) if side_count.get(side, 0) == 1 else None
        if op:
            unit = "行" if side in ("west", "east") else "列"
            parts.append("%s側開口（第 %d–%d %s）通往 %s" % (SIDE_ZH.get(side, side), op[0], op[1], unit, tgt))
        else:
            parts.append("%s側開口通往 %s" % (SIDE_ZH.get(side, side), tgt))
    exits = "；".join(parts) if parts else "無"

    print("Layout: %s。" % layout)
    print("Exits: %s。" % exits)


if __name__ == "__main__":
    main()
