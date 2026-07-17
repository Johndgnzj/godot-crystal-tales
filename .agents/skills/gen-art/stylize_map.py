#!/usr/bin/env python3
"""stylize_map.py：把拼好的 TileMap 平面圖（stitch_map.py 產）當參考圖，餵 Gemini 風格化成
一張手繪奇幻地區圖（image-to-image）。骨架來自實際地圖、不求 100% 符合（見 SKILL.md）。

沿用 gen-art skill 的 gen_image.py 的 find_key()／MODELS／重試策略（import，不改 gen-art 本體），
只是在請求裡多送一個 inlineData image part 當條件輸入。

用法：
  python3 stylize_map.py --in-image <stitched.png> --prompt "廢棄水晶礦坑，藍黑色調" \\
      --out godot-project/assets/ui/region_<id>.png

金鑰：GEMINI_API_KEY 環境變數，否則往上層目錄找 .env（沿用 gen-art 邏輯）。
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)   # gen_image.py 同目錄（本腳本住在 gen-art skill 裡）

try:
    import gen_image as ga   # 借 find_key() / MODELS / 重試常數，不重接金鑰邏輯
except ImportError:
    sys.exit("找不到同目錄的 gen_image.py（本腳本應在 .claude/skills/gen-art/）。")

# 風格化指令：明確要求「保留參考圖的迷宮/房間骨架」，把暗＝牆、亮＝走道講清楚。
STYLE_PREFIX = (
    "Redraw this top-down game map as a hand-drawn fantasy region map illustration. "
    "IMPORTANT: preserve the overall maze/corridor and room LAYOUT from the reference image "
    "— in the reference, dark areas are walls/rock and lighter areas are walkable floor and "
    "corridors; keep that same structure and connectivity. Painterly, atmospheric bird's-eye "
    "view, cohesive palette, clear landmarks along the paths. Where a corridor reaches the map "
    "border, render it as a clear OPEN path / gateway leaving the area — do NOT seal every edge "
    "with an unbroken wall of trees or rock. No text, no letters, no numbers, "
    "no grid lines, no UI, no frame. Region theme: "
)


def generate(key, model, prompt, image_bytes):
    b64 = base64.b64encode(image_bytes).decode()
    body = json.dumps({
        "contents": [{"parts": [
            {"text": prompt},
            {"inlineData": {"mimeType": "image/png", "data": b64}},
        ]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }).encode()
    req = urllib.request.Request(
        "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % (model, key),
        data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        d = json.load(r)
    for part in d.get("candidates", [{}])[0].get("content", {}).get("parts", []):
        if "inlineData" in part:
            return base64.b64decode(part["inlineData"]["data"])
    raise RuntimeError("回應中沒有圖片：" + json.dumps(d)[:300])


def stylize(in_image, prompt, out_path):
    if not os.path.exists(in_image):
        sys.exit("找不到輸入圖：%s（先跑 stitch_map.py）" % in_image)
    image_bytes = open(in_image, "rb").read()
    full_prompt = STYLE_PREFIX + prompt
    key = ga.find_key()
    last = None
    for model in ga.MODELS:
        for attempt in range(3):
            try:
                png = generate(key, model, full_prompt, image_bytes)
                os.makedirs(os.path.dirname(os.path.abspath(out_path)) or ".", exist_ok=True)
                open(out_path, "wb").write(png)
                print("OK %s（%d bytes, model=%s）" % (out_path, len(png), model))
                return out_path
            except urllib.error.HTTPError as e:
                last = "%s HTTP %s: %s" % (model, e.code, e.read()[:200])
                if e.code in (429, 500, 503):
                    time.sleep(3 * (attempt + 1))
                    continue
                break
            except Exception as e:
                last = "%s: %s" % (model, e)
                time.sleep(2)
    sys.exit("生成失敗：" + str(last))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in-image", required=True, help="stitch_map.py 拼出的平面 PNG")
    ap.add_argument("--prompt", required=True, help="地區主題描述（接在風格化指令後）")
    ap.add_argument("--out", required=True, help="輸出 PNG，如 godot-project/assets/ui/region_mine.png")
    a = ap.parse_args()
    stylize(a.in_image, a.prompt, a.out)


if __name__ == "__main__":
    main()
