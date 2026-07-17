#!/usr/bin/env python3
"""Gemini 產圖腳本（gen-art skill 的執行端）。

用法（Godot 專案版；路徑相對 godot-project/）：
  python3 .claude/skills/gen-art/gen_image.py --type face --frame bust --prompt "鐵匠漢克：壯碩老年男子、花白絡腮鬍、皮圍裙" --out godot-project/assets/ui/face_hank.png
  python3 .claude/skills/gen-art/gen_image.py --type face --frame full --prompt "主角魯多：俊美青年劍士、藍披風"            --out godot-project/assets/ui/face_ludo_full.png
  python3 .claude/skills/gen-art/gen_image.py --type battlebg --prompt "廢棄礦坑深處，藍黑色調"                          --out godot-project/assets/ui/battlebg_cave2.png
  python3 .claude/skills/gen-art/gen_image.py --type interior --prompt "溫暖的旅店大廳，木質吧台"                        --out godot-project/assets/props/int_inn2.png
  python3 .claude/skills/gen-art/gen_image.py --type raw      --prompt "..." --ar 1:1 --out /tmp/test.png

金鑰：讀環境變數 GEMINI_API_KEY，否則往上層目錄找 .env（KEY=VALUE 格式）。
      建議放專案根 godot-crystal-tales/.env（根 .gitignore 已排除 .env，不會進 git）；
      若根目錄沒有，會繼續往上找（例如舊的 GameCreator/GDevelop/.env，沿用同一把金鑰）。
      詳見 SKILL.md「金鑰」段。
模型：gemini-2.5-flash-image（失敗時退 gemini-2.0-flash-preview-image-generation）。
"""
import argparse, base64, json, os, sys, time, urllib.request, urllib.error

MODELS = ["gemini-2.5-flash-image", "gemini-2.0-flash-preview-image-generation"]

# 各素材類型的風格前綴（維持與遊戲現有素材一致的構圖約定）
STYLES = {
    # 立繪基底風格（2026-07-13 依 design/ref/role-design-* 定調：細線稿＋水彩手繪感）。
    # 構圖：人物置中、與角色配色對比的單色深底。配色由角色描述帶入。
    # Godot 端：半身圖(frame=bust)直接存 assets/ui/face_<id>.png；不需要 GDevelop 的
    #   art_v7_faces.py 自動裁 144px 頭像那套流程（Godot 直接用整張圖或在編輯器裁 region）。
    "face": ("Hand-drawn anime JRPG character illustration in a soft watercolor, painterly style: "
             "fine and delicate line art with subtle line-weight variation (NOT thick heavy black "
             "outlines), gentle watercolor-like shading with soft gradients, translucent washes and "
             "a faint paper texture (NOT flat cel blocks, NOT semi-realistic thick oil paint, NOT "
             "pixel art, NOT 3D). Soft, even key light. Use the character's own described colors as "
             "their distinctive palette; do NOT default every character to warm tones. Expressive "
             "eyes and a refined, handsome face; age "
             "the character honestly: youthful and beautiful when young, but genuinely weathered, "
             "wrinkled and aged when old. Elaborate layered fantasy adventurer outfit rich in detail "
             "(belts, buckles, straps, gold trim, ornate embroidery, flowing cloth). Character "
             "centered in the frame in a confident, characterful pose. IMPORTANT for clean cutout: "
             "draw a clean, CONTINUOUS (still fine) outline all the way around the whole silhouette "
             "— including cape, sleeves, hem, hands and loose hair strands — so no part melts softly "
             "into the backdrop. Solid flat single-colour background in a muted tone chosen to CLEARLY "
             "CONTRAST the character's own clothing, cape and hair (so the figure separates cleanly; "
             "do NOT make the backdrop the same colour or tone as any garment, cape or the hair), "
             "no scenery, no floor, no border, no frame, no text, no letters, no numbers, no watermark. "),
    "battlebg": ("Side-view JRPG battle background, painterly pixel-art style, rich vivid colors, "
                 "clearly lit and readable (NOT dark, NOT black), gentle depth, empty flat middle "
                 "ground for combatants to stand on, horizon around upper third, "
                 "no characters, no people, no text, no UI. Scene: "),
    "map": ("Hand-drawn fantasy region map, parchment-free dark style, bird's-eye view, clear "
            "landmarks and roads, Traditional Chinese label-free (no text at all). Region: "),
    "title": ("Lush hand-painted fantasy JRPG title-screen key art, richly detailed natural scene "
              "with atmospheric mist and layered depth, soft cinematic lighting, mysterious yet "
              "hopeful adventurous mood, classic SNES/PS1-era painterly JRPG look, foreground "
              "elements framing a luminous focal point in the misty distance. "
              "No logo, no text, no letters, no numbers, no watermark, no UI. Scene: "),
    "icon": ("Single game icon, centered subject, dark background, clean silhouette, no text. "
             "Subject: "),
    # 正面平視日系像素建築、門在正面下緣（洋紅底去背 → 縮放置放於地圖）
    "building": ("Pixel art game asset sprite, FLAT FRONT ELEVATION view: the facade is square to "
                 "the viewer and seen only slightly from above so the pitched roof shows; the "
                 "building is NOT rotated and this is NOT an isometric or angled 3/4 corner view "
                 "(do not show two receding side walls). Classic SNES-era Japanese RPG town "
                 "building with the main door / entrance centered on the FRONT-BOTTOM edge facing "
                 "the viewer, so the player can walk up from below onto the doorway to enter. Clean "
                 "readable 2D JRPG style, cohesive warm palette, centered, on a solid flat magenta "
                 "#ff00ff background for easy cutout, no ground plane, no drop shadow, no text, no "
                 "letters, no numbers, no people. Building: "),
    # 室內背景大圖（水彩手繪，滿版場景，與立繪同一套風格 DNA；作立繪＋選單式室內背景）。
    # Godot 端：存 assets/props/int_<key>.png，由編輯器 import；GDevelop build 的 _clean_ext
    #   去背產 intc_<key>.png 那套後處理在 Godot 沒有對應（整合方式待設計，見 SKILL.md）。
    "interior": ("Hand-drawn watercolor, painterly JRPG interior background scene: fine and delicate "
                 "line work, soft watercolor shading with gentle gradients (NOT flat cel blocks, NOT "
                 "pixel art, NOT 3D). Color palette and lighting chosen to suit the room's own mood "
                 "and materials (do not force warm tones). Richly detailed fantasy room with "
                 "characterful furniture and props and atmospheric depth. Full-frame scene filling "
                 "the whole image, no characters, no people, no text, no letters, no numbers, no "
                 "watermark. Room: "),
    "raw": "",
}
ASPECT = {"face": "16:9", "battlebg": "16:9", "map": "16:9", "title": "16:9", "icon": "1:1",
          "building": "1:1", "interior": "4:3", "raw": None}

# face 專用分鏡（接在 STYLES["face"] 之後）。bust=腰上半身（供裁頭像，須橫幅）；full=全身。
# 非主要角色只需 bust；主要角色 bust + full 各一張。
FACE_FRAME = {
    "bust": ("Framing: waist-up half-body portrait, head near the top with a little headroom, "
             "landscape frame. Character: "),
    "full": ("Framing: full-body from head to feet, the entire figure visible with margin above "
             "and below, standing, tall vertical portrait-orientation composition (no decorative "
             "border, no frame). Character: "),
}
FACE_AR = {"bust": "16:9", "full": "3:4"}


def find_key():
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"].strip()
    d = os.path.abspath(os.path.dirname(__file__))
    for _ in range(8):
        p = os.path.join(d, ".env")
        if os.path.exists(p):
            for line in open(p):
                line = line.strip()
                if line.startswith("GEMINI_API_KEY="):
                    return line.split("=", 1)[1].strip()
        nd = os.path.dirname(d)
        if nd == d:
            break
        d = nd
    sys.exit("找不到 GEMINI_API_KEY（環境變數或上層 .env）")


def _img_part(path):
    ext = os.path.splitext(path)[1].lower()
    mime = "image/jpeg" if ext in (".jpg", ".jpeg") else "image/png"
    with open(path, "rb") as f:
        return {"inlineData": {"mimeType": mime, "data": base64.b64encode(f.read()).decode()}}


def generate(key, model, prompt, aspect, ref_images=None):
    gc = {"responseModalities": ["IMAGE"]}
    if aspect:
        gc["imageConfig"] = {"aspectRatio": aspect}
    # 參考圖（image-to-image / 多圖風格錨）放在文字前面，讓模型先看風格再讀指令。
    parts = [_img_part(p) for p in (ref_images or [])] + [{"text": prompt}]
    body = json.dumps({"contents": [{"parts": parts}],
                       "generationConfig": gc}).encode()
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}",
        data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.load(r)
    for part in d.get("candidates", [{}])[0].get("content", {}).get("parts", []):
        if "inlineData" in part:
            return base64.b64decode(part["inlineData"]["data"])
    raise RuntimeError("回應中沒有圖片：" + json.dumps(d)[:300])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--type", default="raw", choices=list(STYLES))
    ap.add_argument("--frame", default="bust", choices=list(FACE_FRAME),
                    help="face 專用：bust=腰上半身(預設，供裁頭像)／full=全身")
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ar", default=None, help="覆寫長寬比，如 16:9 / 1:1 / 3:4")
    ap.add_argument("--ref-image", action="append", default=[], dest="ref_images",
                    help="參考圖路徑（可重複）：image-to-image／多圖風格錨，例如用現有素材當風格參考")
    a = ap.parse_args()

    key = find_key()
    if a.type == "face":
        prompt = STYLES["face"] + FACE_FRAME[a.frame] + a.prompt
        aspect = a.ar or FACE_AR[a.frame]
    else:
        prompt = STYLES[a.type] + a.prompt
        aspect = a.ar or ASPECT[a.type]
    last = None
    for model in MODELS:
        for attempt in range(3):
            try:
                png = generate(key, model, prompt, aspect, a.ref_images)
                os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
                open(a.out, "wb").write(png)
                print(f"OK {a.out} ({len(png)} bytes, model={model})")
                return
            except urllib.error.HTTPError as e:
                last = f"{model} HTTP {e.code}: {e.read()[:200]}"
                if e.code in (429, 500, 503):
                    time.sleep(3 * (attempt + 1)); continue
                break
            except Exception as e:
                last = f"{model}: {e}"
                time.sleep(2)
    sys.exit("生成失敗：" + str(last))


if __name__ == "__main__":
    main()
