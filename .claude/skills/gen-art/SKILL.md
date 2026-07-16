---
name: gen-art
description: 用 Gemini API 生成水晶戰記（Godot 版）的美術素材（NPC/角色立繪、戰鬥背景、區域地圖、標題圖、圖示、室內背景），也能把遊戲的 TileMap 地圖拼起來再 image-to-image 風格化成手繪地區圖（gen-region 產完地圖後的美術收尾）。當 John 說「產圖」「生成素材」「幫某角色畫立繪」「換戰鬥背景」「把地圖變成手繪風格」「地區地圖上色」等美術生成需求時使用。像素級小圖（行走圖、圖磚、敵人戰鬥圖）不適用本 skill——那些用 LPC 合成或商店素材。
---

# gen-art：Gemini 產圖管線（Godot 版）

呼叫 Gemini 產圖，存進 `godot-project/assets/`，交給 Godot 編輯器 import。

## 金鑰

`GEMINI_API_KEY` 走 `.env`（`KEY=VALUE`，須 gitignore，不要寫進程式碼／commit）。腳本會先讀環境變數，否則從 skill 位置往上逐層找 `.env`（最多 8 層）——目前會命中 `GDevelop/.env`，可直接用。

<<<<<<< HEAD
- **建議位置**：專案根 `godot-crystal-tales/.env`（內容 `GEMINI_API_KEY=...`）。根層 `.gitignore` 已排除 `.env`，不會進 git。從舊專案複製：`cp ../GDevelop/.env .env`。
- 若專案根沒有 `.env`，腳本會繼續往上層找（舊行為會命中 `GameCreator/GDevelop/.env`）——GDevelop 目錄已是可移除的舊專案，別再依賴這條路徑。

## 生成
=======
## 產圖
>>>>>>> 7c53c297478c7ed81b0bfc0ac6d808a213631daa

```bash
# 於 godot-crystal-tales/ 根目錄執行；--out 路徑相對 godot-project/
python3 .claude/skills/gen-art/gen_image.py --type <類型> [--frame bust|full] --prompt "<描述>" --out <路徑>
```

模型 `gemini-2.5-flash-image`（自動退階、429/503 自動重試）。`--type` 會自動加對應風格前綴，`--prompt` 只需寫「畫面內容」。各 type：

<<<<<<< HEAD
| type | 長寬比 | 構圖約定 | Godot 存放與後處理 |
|------|--------|----------|--------------|
| `face` | bust→16:9 / full→3:4 | 人物置中、**與角色配色明顯區隔的單色底**＋**整圈連續描邊**（利於去背）、無文字；**不預設色調**（顏色由角色描述帶入）。`--frame bust`＝腰上半身（預設）／`--frame full`＝全身 | **半身**直接存 `godot-project/assets/ui/face_<id>.png`（現有 26 個 `face_*.png` 同慣例）。**⚠️ 待改（GDevelop 專屬）**：原本靠 `scripts/art_v7_faces.py` 偵測人物中心自動裁 144×144 頭像——Godot 沒有這支腳本，改法：整張半身圖直接用、或在 Godot 編輯器用 `AtlasTexture`/`region` 裁切、或另寫 Godot 端裁圖工具（待設計）。**全身**另存 `godot-project/assets/ui/face_<id>_full.png`（作立繪／室內大型前景用；不進頭像流程） |
| `battlebg` | 16:9 | 側視戰場、中景留空、地平線在上 1/3、無角色 | 縮到 640×360 存 `godot-project/assets/ui/battlebg_<場景>.png`（現有 `battlebg*.png` 同慣例）。**⚠️ 待改（GDevelop 專屬）**：原本要在 `build_cq2.py` 的 Bg 物件動畫清單與 BATTLE_JS 的 BGMAP 註冊——Godot 沒有 build_cq2.py，改由戰鬥場景直接依檔名載入貼圖（整合方式待 MOD 戰鬥任務設計） |
| `map` | 16:9 | 鳥瞰地區圖、無文字 | 縮製後替換 `godot-project/assets/ui/region_map.png` |
| `title` | 16:9 | 關鍵美術、無 logo 文字 | 縮 1280×720 替換 `godot-project/assets/ui/menubg.png`。**⚠️ 待改（GDevelop 專屬）**：原合成流程走 `scripts/art_v13_title.py`——Godot 沒有這支腳本，若需疊 logo/文字改在 Godot 場景內用 Label/TextureRect 疊（整合方式待設計） |
| `icon` | 1:1 | 置中主體、深底、無字 | 視用途存 `godot-project/assets/ui/` |
| `building` | 1:1 | **正面平視日系像素 RPG 建築（facade 正對鏡頭、微俯視露屋頂、明確非 isometric 斜角）、門置中在正面下緣**（玩家從下方走上門格進入，方便放進入點）、洋紅底 #ff00ff 去背（地圖用，維持像素風不套水彩） | 去背後縮放置放於地圖；Godot 端存 `godot-project/assets/props/`（或 `assets/map/`，依用途）。去背可在 Godot import 設定或外部工具處理 |
| `interior` | 4:3 | **水彩手繪滿版室內場景**（與立繪同套技法）、色調隨房間氛圍決定、無角色、無文字 | 存 `godot-project/assets/props/int_<key>.png`（現有 `int_*.png` 同慣例）。**⚠️ 待改（GDevelop 專屬）**：原本 build 走 `_clean_ext` 產去背版 `intc_<key>.png` 作立繪＋選單式室內背景——Godot 沒有這道 build 後處理，改法：直接用 `int_*.png` 由編輯器 import，若需去背版另行處理（整合方式待設計；現有 `intc_*.png` 是從 GDevelop 端複製過來的成品） |
| `raw` | 自訂 `--ar` | 無前綴 | — |
=======
| type | 比例 | 用途／存放 |
|------|------|-----------|
| `face` | bust 16:9 / full 3:4 | 角色立繪，置中、單色底、整圈描邊。`--frame bust`＝半身（預設，供頭像）存 `assets/ui/face_<id>.png`；`--frame full`＝全身存 `assets/ui/face_<id>_full.png` |
| `battlebg` | 16:9 | 側視戰場、中景留空、無角色。縮 640×360 存 `assets/ui/battlebg_<場景>.png` |
| `map` | 16:9 | 鳥瞰地區圖、無文字。替換 `assets/ui/region_map.png` |
| `title` | 16:9 | 標題關鍵美術、無 logo 文字。縮 1280×720 替換 `assets/ui/menubg.png` |
| `icon` | 1:1 | 置中主體、深底、無字。存 `assets/ui/` |
| `building` | 1:1 | 45° 斜角像素建築、洋紅底 #ff00ff（維持像素風、供地圖去背）。存 `assets/props/` |
| `interior` | 4:3 | 水彩手繪滿版室內、無角色無文字。存 `assets/props/int_<key>.png` |
| `raw` | 自訂 `--ar` | 無前綴 |
>>>>>>> 7c53c297478c7ed81b0bfc0ac6d808a213631daa

> 去背／頭像裁切／logo 疊字等後製，GDevelop 端原本靠專屬腳本，Godot 沒有對應——先「整張圖直接 import」，需要時再手動或用 Godot 端（`AtlasTexture`/import 設定）處理。

## 立繪風格重點（`face`／`interior` 共用技法）

前綴已內建到 `gen_image.py`，`--prompt` 只寫角色／房間描述即可。要點：

- **細線稿＋水彩手繪感**：柔和漸層、透明水洗、淡紙紋。非粗黑描邊、非平塗 cel、非像素、非 3D。
- **配色由角色／房間決定**，不鎖色系、避免全隊撞色；前綴只給中性打光與中性底。
- 立繪：大而有神的眼睛、俊美臉、年齡誠實、華麗奇幻服裝、人物置中、無外框；**整圈連續描邊＋與角色明顯區隔的單色底**（利於去背）。
- **分鏡**：非主要角色只產 `bust`；主要角色 `bust`＋`full` 各一。全身圖不拿去裁頭像。
- 不穩就重生（每次結果不同），寧可多生兩張挑。

## 產後步驟

1. Read 圖確認構圖，不合格改 prompt 重生。
2. 放進 `assets/` 對應子目錄，由 Godot 編輯器 import。
3. 在 `godot-crystal-tales/CREDITS_素材授權.md` 註明「AI 生成（Gemini），提示詞作者 John」。

## 邊界

<<<<<<< HEAD
- 生成式**不適合** 16-64px 像素素材（行走圖/圖磚/敵人小圖）：偽像素網格對不齊。用 LPC 圖層合成（來源素材在 `godot-project/assets/battle/lpc_src/`）或商店素材。
- prompt 一律描述畫面內容與風格，**不要放遊戲名或人名文字**（模型會把字畫進圖裡）。
- 免費額度有限，失敗先看 HTTP 429（配額）再重試。
- **不要修改 GDevelop 專案**（`../GDevelop/`、`../gd-crystal-tales/`）任何檔案——那邊是唯讀參考來源。

## 地圖風格化（image-to-image；gen-region 的 stage 3）

把一張世界地圖 `.tscn`（gen-region 產的、或現有的 town/forest/cave…）的 TileMap 先拼成平面圖，再餵 Gemini 風格化成手繪地區圖。骨架跟著實際地圖走、不求 100% 符合。這是 image-to-image（多送一個參考圖 part），與上表純文字生圖不同。

```bash
# 1) 拼圖：世界場景 .tscn → 平面 PNG（讀 ground_tiles + atlas，32px/6 欄）
python3 .claude/skills/gen-art/stitch_map.py godot-project/scenes/world/<map>.tscn --out /tmp/stitch_<map>.png

# 2) 風格化：拼圖當參考圖餵 Gemini（沿用本 skill 的 find_key/重試）
python3 .claude/skills/gen-art/stylize_map.py --in-image /tmp/stitch_<map>.png \
    --prompt "<地區主題，如：廢棄水晶礦坑，藍黑色調、微光水晶>" \
    --out godot-project/assets/ui/region_<map>.png
```

- `stitch_map.py` 純還原（無 AI），也可單獨預覽任何世界場景套素材後的樣子；需 Pillow（`pip install pillow`）。
- `stylize_map.py` 的 prompt 前綴已要求「保留參考圖的迷宮/房間骨架、邊緣通道口別封死」。
- 輸出比照 `map` type 的地區圖慣例存 `assets/ui/region_<id>.png`；比照「生成後必做」在 `CREDITS_素材授權.md` 標註 AI 生成。
=======
- 不適合 16–64px 像素小圖（行走圖／圖磚／敵人小圖）——用 LPC 合成或商店素材。
- prompt 不放遊戲名／人名文字（模型會把字畫進圖）；也不放版權 IP／畫師名。
- 不要修改 GDevelop 專案（`../GDevelop/`、`../gd-crystal-tales/`）——唯讀參考來源。
>>>>>>> 7c53c297478c7ed81b0bfc0ac6d808a213631daa
