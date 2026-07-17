#!/usr/bin/env python3
"""stitch_map.py：把一張世界場景 .tscn 的 TileMap＋props 拼成一張平面 PNG。

讀場景根節點的 map_w / ground_tiles / atlas_path 畫地板，再讀 prop_list 把樹木/裝飾/建築等
prop sprite 疊上去——這樣預覽（與餵 Gemini 的骨架圖）才呈現實際遊戲的完整長相，而非只有光禿地磚。

用法：
  python3 stitch_map.py <scene.tscn> --out <preview.png> [--scale 1] [--no-props]

依賴：Pillow（pip install pillow）。
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GODOT = os.path.join(REPO, "godot-project")
TS = 32
COLS = 6

try:
    from PIL import Image
except ImportError:
    sys.exit("缺 Pillow：請先 `pip install pillow`（stitch_map.py 需要它拼圖）")


def _res_to_fs(res_path):
    """res://xxx → 檔案系統絕對路徑（res:// 根＝godot-project/）。"""
    if res_path.startswith("res://"):
        return os.path.join(GODOT, res_path[len("res://"):])
    return res_path


def parse_scene(tscn_path):
    txt = open(tscn_path).read()
    mw = re.search(r'^map_w = (\d+)', txt, re.M)
    mh = re.search(r'^map_h = (\d+)', txt, re.M)
    gt = re.search(r'ground_tiles = PackedInt32Array\(([^)]*)\)', txt)
    at = re.search(r'^atlas_path = "([^"]+)"', txt, re.M)
    if not (mw and gt and at):
        sys.exit("解析失敗：場景缺 map_w / ground_tiles / atlas_path（是世界場景 .tscn 嗎？）")
    tiles = [int(t) for t in gt.group(1).split(",") if t.strip()]
    w = int(mw.group(1))
    h = int(mh.group(1)) if mh else (len(tiles) + w - 1) // w
    # prop_list：build_scene 以 gd_value 輸出成單行 [{"tex":..,"x":..,"y":..,"w":..,"h":..}, ...]
    props = []
    pm = re.search(r'^prop_list = (\[.*\])', txt, re.M)
    if pm:
        for tex, x, y, pw, ph in re.findall(
                r'\{"tex": "([^"]+)", "x": (-?\d+), "y": (-?\d+), "w": (-?\d+), "h": (-?\d+)\}', pm.group(1)):
            props.append(dict(tex=tex, x=int(x), y=int(y), w=int(pw), h=int(ph)))
    return w, h, tiles, at.group(1), props


def stitch(tscn_path, out_path, scale=1, with_props=True):
    w, h, tiles, atlas_res, props = parse_scene(tscn_path)
    atlas_fs = _res_to_fs(atlas_res)
    if not os.path.exists(atlas_fs):
        sys.exit("找不到 atlas 圖：%s（res=%s）" % (atlas_fs, atlas_res))
    atlas = Image.open(atlas_fs).convert("RGBA")

    canvas = Image.new("RGBA", (w * TS, h * TS), (0, 0, 0, 255))
    for idx, tid in enumerate(tiles):
        if tid <= 0:
            continue
        cell = tid - 1                       # tile id 1 起算 → atlas cell 0 起算
        sx, sy = (cell % COLS) * TS, (cell // COLS) * TS
        gx, gy = (idx % w) * TS, (idx // w) * TS
        canvas.alpha_composite(atlas.crop((sx, sy, sx + TS, sy + TS)), (gx, gy))

    n_props = 0
    if with_props:
        for p in sorted(props, key=lambda p: p["y"]):   # 依 y 疊（近似 Y-sort，前景樹蓋住後方）
            fs = _res_to_fs(p["tex"])
            if not os.path.exists(fs):
                continue
            img = Image.open(fs).convert("RGBA")
            if p["w"] > 0 and p["h"] > 0:
                img = img.resize((p["w"], p["h"]))
            canvas.paste(img, (p["x"], p["y"]), img)     # 部分出界會自動裁切
            n_props += 1

    if scale != 1:
        canvas = canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST)
    os.makedirs(os.path.dirname(os.path.abspath(out_path)) or ".", exist_ok=True)
    canvas.convert("RGB").save(out_path)
    print("OK 拼出 %s（%dx%d tiles，%d props → %dx%d px）"
          % (out_path, w, h, n_props, canvas.width, canvas.height))
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene", help="世界場景 .tscn 路徑")
    ap.add_argument("--out", required=True, help="輸出 PNG 路徑")
    ap.add_argument("--scale", type=int, default=1, help="整數放大倍率（NEAREST，預設 1）")
    ap.add_argument("--no-props", action="store_true", help="只畫地板、不畫 prop")
    a = ap.parse_args()
    stitch(a.scene, a.out, a.scale, with_props=not a.no_props)


if __name__ == "__main__":
    main()
