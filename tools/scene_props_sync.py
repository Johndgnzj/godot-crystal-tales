#!/usr/bin/env python3
"""scene_props_sync.py — 把 Godot 場景裡手調過的高物件位置寫回 map-def.json。

用途：設計員在 Godot 編輯器把樹／建築拖到滿意的位置後，跑這支把座標**反向同步**回
`assets-source/map/map-def.json` 的 `props`。map-def 是真相源，之後 build_scenes.gd
重生成場景就會重現這些位置，不必每張圖重調一次。

方向永遠是「場景 → map-def」；map-def → 場景是 build_scenes.gd 的事，兩者不要同時改。

用法：
    python3 tools/scene_props_sync.py nfr_a            # 預覽差異（不寫檔）
    python3 tools/scene_props_sync.py nfr_a --write    # 確認後寫回 map-def
    python3 tools/scene_props_sync.py --all            # 掃全部 painted 場景（預覽）

規則：
  - 只認 `YSort`／`GroundProps` 底下、帶 `metadata/prop_id` 的節點（build_scenes.gd 生成時寫入）。
    舊場景沒有 metadata 時，改用節點名反推素材 id（節點名＝`Prop_<id 去掉數字等字元>_<序號>`）。
    反推不到或有歧義時**拒絕寫入該張圖**，避免把 prop 靜靜弄丟——先重生成一次補上 metadata 即可。
  - cell 由節點座標反推：`c = x/32 - w/2`、`r = y/32 - h`（build_scenes.gd 擺放公式的逆運算）。
  - **不寫 footprint**：那是素材層級規格，真相在素材庫 `meta.json`（校正一次、所有地圖生效）。
  - 掛在 `GroundProps` 但素材庫沒標 `layer:"ground"`（或反之）時，在該筆 prop 寫明 `layer` 覆寫。
  - 場景中被刪掉的 prop 會一併從 map-def 移除；帶 metadata 的新增節點會被收進來。
  - **`gate`（可依旗標開關的路障／柵欄門）沿用 map-def 舊值**：那是資料層設定、場景讀不回來。
    在編輯器新增的 gated 物件同步後只會是普通 prop，`gate` 欄要自己補回 map-def。
"""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_DEF = ROOT / "assets-source" / "map" / "map-def.json"
SCENES = ROOT / "godot-project" / "scenes" / "world" / "painted"
TILE = 32
PROP_PARENTS = ("YSort", "GroundProps")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prop_catalog import prop_catalog                                    # noqa: E402


def safe_name(value: str) -> str:
    """複製 build_scenes.gd 的 _node_safe_name：非字母／底線一律換成底線（數字也會被換掉）。"""
    return "".join(c if (c.isalpha() or c == "_") else "_" for c in value) or "world"


def parse_scene(path: Path):
    """回傳 (scene_id, [prop dict…])；prop dict 帶 name/parent/pos/id/type/fp/asset/guessed。"""
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"(?=^\[node )", text, flags=re.M)
    scene_id, props = "", []
    for b in blocks:
        m = re.match(r'\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]*)")?', b)
        if not m:
            continue
        name, parent = m.group(1), m.group(2)
        if parent is None:                                               # 根節點
            scene_id = name
            continue
        if parent not in PROP_PARENTS or not name.startswith("Prop_"):
            continue
        pos = re.search(r"^position = Vector2\(([-\d.e+]+), ([-\d.e+]+)\)", b, re.M)
        if pos is None:
            continue
        def meta(key):
            mm = re.search(r'^metadata/%s = "([^"]*)"' % key, b, re.M)
            return mm.group(1) if mm else ""
        fp = re.search(r"^metadata/prop_fp = Vector2i\((\d+), (\d+)\)", b, re.M)
        idx = re.search(r"_(\d+)$", name)
        props.append({
            "name": name, "parent": parent,
            "pos": (float(pos.group(1)), float(pos.group(2))),
            "id": meta("prop_id"), "type": meta("prop_type"), "asset": meta("prop_asset"),
            "fp": (int(fp.group(1)), int(fp.group(2))) if fp else None,
            "index": int(idx.group(1)) if idx else None,
        })
    return scene_id, props


def locate_map(mapdef: dict, scene_id: str):
    """scene_id → (region_id, map_key)；比照 build_scenes.gd 的 _scene_id 規則。"""
    for rid, reg in mapdef.get("regions", {}).items():
        prefix = str(reg.get("scene_prefix", "") or "")
        for k, m in reg.get("maps", {}).items():
            sid = str(m.get("scene") or (prefix + k.upper()))
            if sid == scene_id:
                return rid, k
    return None, None


def to_cell(pos, fp):
    """build_scenes.gd：holder=((c+w/2)*32,(r+h)*32) 的逆運算。"""
    w, h = fp
    return round(pos[0] / TILE - w / 2), round(pos[1] / TILE - h)


def reorder_like(old: list, new: list) -> list:
    """把場景讀來的 props 依 map-def 既有順序排好：同 id 取位置最近者配對，剩下的接在後面。

    場景 .tscn 裡 GroundProps 的節點排在 YSort 前面，與 map-def 陣列順序本來就不同；
    不先對齊的話，逐筆比對會把「整批位移」誤報成每一筆都改了。
    """
    pool = list(new)
    out, pairs, removed = [], [], []
    for o in old:
        cands = [n for n in pool if n["id"] == o.get("id")]
        if not cands:
            removed.append(o)                           # 這筆在場景被刪掉了
            continue
        oc = o.get("cell", [0, 0])
        best = min(cands, key=lambda n: (n["cell"][0] - oc[0]) ** 2 + (n["cell"][1] - oc[1]) ** 2)
        pool.remove(best)
        out.append(best)
        pairs.append((o, best))
    return out + pool, pairs, removed, pool             # pool 剩下的＝場景新增的


def sync_scene(path: Path, mapdef: dict, catalog: dict, write: bool):
    scene_id, scene_props = parse_scene(path)
    rid, key = locate_map(mapdef, scene_id)
    if rid is None:
        print(f"  ⚠ {path.name}：map-def 找不到 scene_id={scene_id}，略過")
        return False
    old = mapdef["regions"][rid]["maps"][key].get("props", [])
    new, notes, unresolved = [], [], []
    by_safe = {}
    for cid in catalog:
        by_safe.setdefault(safe_name(cid), []).append(cid)
    for p in scene_props:
        pid, ptype, fp = p["id"], p["type"], p["fp"]
        if not pid:                                                        # 舊場景無 metadata：用節點名反推
            stem = re.sub(r"_\d+$", "", p["name"][len("Prop_"):])
            hits = [i for i in by_safe.get(stem, [])]
            if len(hits) == 1:
                pid = hits[0]
                notes.append(f"{p['name']}：無 metadata，由節點名反推為 {pid}")
            else:
                unresolved.append(f"{p['name']}：無 metadata，節點名"
                                  f"{'對不到素材' if not hits else '有歧義（%s）' % '／'.join(hits)}")
                continue
        if not ptype:
            ptype = catalog[pid]["type"] if pid in catalog else ""
        if fp is None and pid in catalog:
            fp = tuple(catalog[pid]["footprint"])
        item = catalog.get(pid)
        if fp is None:
            fp = tuple(item["footprint"]) if item else (1, 1)
        c, r = to_cell(p["pos"], fp)
        rec = {"id": pid, "type": ptype or (item["type"] if item else "structure"),
               "cell": [c, r], "anchor": "bottom_center"}          # footprint 不寫：素材層級規格，真相在 meta.json
        want_ground = p["parent"] == "GroundProps"
        default_ground = bool(item and item.get("layer") == "ground")
        if want_ground != default_ground:                                  # 與素材庫預設不同才寫覆寫
            rec["layer"] = "ground" if want_ground else "object"
        if p["asset"]:
            rec["asset"] = p["asset"]
        new.append(rec)

    new, pairs, removed, added = reorder_like(old, new)   # 場景節點順序≠map-def 陣列順序，先對齊避免假差異
    for o, n in pairs:
        if "gate" in o:                                   # gate 只存在 map-def，場景讀不回來→沿用舊值
            n["gate"] = o["gate"]
    changed = new != old
    print(f"\n=== {scene_id}（{rid}:{key}）prop {len(old)} → {len(new)} ===")
    for n in notes:
        print("  ⚠", n)
    if unresolved:
        for u in unresolved:
            print("  ✖", u)
        print(f"  → 有 {len(unresolved)} 個 prop 認不出來，**這張圖不寫入**（寫了會弄丟它們）。"
              f"先讓 build_scenes.gd 重生成一次 {scene_id} 補上 metadata，再跑同步。")
        return False
    if not changed:
        print("  無變化")
    else:
        for o, n in pairs:
            if o == n:
                continue
            if o.get("cell") != n.get("cell"):
                print(f"  ~ 移動 {n['id']}  {o.get('cell')} → {n['cell']}")
            else:
                print(f"  ~ {n['id']} @ {n['cell']}（欄位變動："
                      f"{ {k: (o.get(k), n.get(k)) for k in set(o) | set(n) if o.get(k) != n.get(k)} }）")
        for o in removed:
            print(f"  － 移除 {o.get('id')} @ {o.get('cell')}")
        for n in added:
            print(f"  ＋ 新增 {n['id']} @ {n['cell']}")
        if write:
            mapdef["regions"][rid]["maps"][key]["props"] = new
    return changed


def main():
    ap = argparse.ArgumentParser(description="把 Godot 場景手調後的 props 位置寫回 map-def.json")
    ap.add_argument("scenes", nargs="*", help="場景檔名（不含副檔名），例如 nfr_a")
    ap.add_argument("--all", action="store_true", help="掃 painted/ 下所有場景")
    ap.add_argument("--write", action="store_true", help="實際寫回 map-def（預設只預覽）")
    a = ap.parse_args()

    targets = sorted(SCENES.glob("*.tscn")) if a.all else [SCENES / f"{s}.tscn" for s in a.scenes]
    if not targets:
        ap.error("要給場景名，或用 --all")
    missing = [t for t in targets if not t.is_file()]
    if missing:
        ap.error("找不到場景：" + ", ".join(t.name for t in missing))

    mapdef = json.loads(MAP_DEF.read_text(encoding="utf-8"))
    catalog = {i["id"]: i for i in prop_catalog(ROOT / "assets-source")}
    any_change = any([sync_scene(t, mapdef, catalog, a.write) for t in targets])

    if not any_change:
        print("\n沒有需要同步的變動。")
        return
    if not a.write:
        print("\n以上為預覽。確認無誤後加 --write 寫回 map-def。")
        return
    shutil.copy2(MAP_DEF, MAP_DEF.with_suffix(".json.bak"))               # 比照 serve.py 覆寫前備份
    MAP_DEF.write_text(json.dumps(mapdef, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n已寫回 {MAP_DEF.relative_to(ROOT)}（原檔備份為 map-def.json.bak）。")


if __name__ == "__main__":
    main()
