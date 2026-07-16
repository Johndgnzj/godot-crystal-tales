---
name: gen-art
description: 用 Gemini API 生成水晶戰記（Godot 版）的美術素材（NPC/角色立繪、戰鬥背景、區域地圖、標題圖、圖示、室內背景），也能把遊戲的 TileMap 地圖拼起來再 image-to-image 風格化成手繪地區圖（gen-region 產完地圖後的美術收尾）。當 John 說「產圖」「生成素材」「幫某角色畫立繪」「換戰鬥背景」「把地圖變成手繪風格」「地區地圖上色」等美術生成需求時使用。像素級小圖（行走圖、圖磚、敵人戰鬥圖）不適用本 skill——那些用 LPC 合成或商店素材。
---

# gen-art：Gemini 產圖管線（Godot 版）

> 本 skill 由 GDevelop 專案（`../GDevelop/.claude/skills/gen-art/`）移植而來。**核心「呼叫 Gemini 產圖 + 存檔」邏輯與美術風格約定原樣保留**；只把輸出路徑改成 Godot 專案的 `godot-project/assets/` 佈局。
> ⚠️ 原 GDevelop 版有數個「後處理」步驟依賴 GDevelop 專屬 Python 腳本（`scripts/art_v7_faces.py`、`scripts/art_v13_title.py`、`build_cq2.py` 的 Bg/BGMAP 註冊、build 的 `_clean_ext` 去背等）。**這些腳本沒有移植過來、Godot 端也沒有對應**——下表凡標 **⚠️ 待改** 的都是 GDevelop 專屬、Godot 整合方式待設計；Godot 端的做法是「圖直接放進 `assets/` 對應子目錄，交給編輯器 import」，不需要 `art_v*.py` 那套。

## 金鑰

`GEMINI_API_KEY` 走 `.env`（KEY=VALUE 格式，須 gitignore；不要把 key 寫進任何程式碼、文件、commit）。腳本 `find_key()` 會先讀環境變數，否則從 skill 檔案位置**往上層目錄逐層找 `.env`**（最多 8 層）。

- **建議位置**：專案根 `godot-crystal-tales/.env`（內容 `GEMINI_API_KEY=...`）。根層 `.gitignore` 已排除 `.env`，不會進 git。從舊專案複製：`cp ../GDevelop/.env .env`。
- 若專案根沒有 `.env`，腳本會繼續往上層找（舊行為會命中 `GameCreator/GDevelop/.env`）——GDevelop 目錄已是可移除的舊專案，別再依賴這條路徑。

## 生成

```bash
# 於 godot-crystal-tales/ 根目錄執行；--out 路徑相對 godot-project/
python3 .claude/skills/gen-art/gen_image.py --type <類型> [--frame bust|full] --prompt "<描述>" --out <路徑>
```

模型 `gemini-2.5-flash-image`（自動退階 `gemini-2.0-flash-preview-image-generation`；429/503 自動重試）。
`--type` 會自動加上風格前綴，維持與現有素材一致的構圖約定：

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

> 註：原 GDevelop 版把 `face`/`title` 的**中間產物**先存在 `projects/crystal-quest/design/`（設計稿暫存區）再經腳本產出遊戲用檔。Godot 端沒有沿用 `design/` 暫存區慣例——若要保留原稿，自行建 `godot-project/design/`（未 import）存放即可；否則直接輸出到上表的 `assets/` 目標路徑。

## 角色立繪風格（統一方向；2026-07-13 依 `design/ref/role-design-*` 定調）

> 以下風格約定與引擎無關，原樣保留。`design/ref/` 參考圖在 GDevelop 端（唯讀參考，不入 Godot repo／不散布）。

目標＝**細緻手繪水彩感的日式 RPG 動畫插畫**（已內建進 `gen_image.py` 的 `type=face` 前綴）：
- **細線稿**：線條細、乾淨、有輕重變化——**非**粗黑描邊。
- **水彩／手繪感上色**：柔和漸層、透明水洗、淡紙紋；**非**平塗 cel 硬色塊、**非**半寫實厚塗、**非**像素、**非** 3D。
- **配色不鎖色系**：各角色的主色／輔色／瞳色由**角色設計**決定，彼此要有辨識度、避免全隊撞成同一色調。`face` 前綴只給中性打光與中性底，**顏色一律由角色描述句帶入**。
- 大而有神的眼睛、俊美臉；**年齡誠實**——該年輕就俊美年輕，該老就真的蒼老多皺。
- 華麗多層次的奇幻冒險者服裝：皮帶／扣具／肩甲／披風／金邊滾邊／繁複刺繡。
- 人物**置中**、自信有個性的姿態；全身圖用 tall vertical 構圖、**不要裝飾外框**。
- **去背友善（2026-07-13 強化，降低衣物/披風去背失敗率）**：立繪去背是「四角背景色距 flood-fill」，兩個 prompt 條件讓它更穩——
  ① **整圈連續、清晰（但仍細）的線稿**包住輪廓（含披風/袖擺/髮絲/手）＝給 flood 一道牆，即使衣物與底同色也不會滲進去；
  ② 底色為**與該角色衣物/披風/頭髮明顯區隔的單色**（不再固定藍灰，避免灰/藍/鋼調角色與底撞色）。純色底供去背抓人裁像；底色只是背景、不影響角色配色。
- 一致性訣竅：同一批角色沿用同一句 `face` 前綴、只改「角色描述句」；不穩時補 `fine line art / watercolor / NOT pixel art / NOT 3D` 重生，寧可多生兩張挑。

**分鏡規則（`--frame`）**：
- **非主要角色** → 只產 `--frame bust`（腰上半身）。
- **主要角色** → 產 `--frame bust`（半身，供頭像裁切）＋ `--frame full`（全身立繪，另存 `face_<id>_full.png`）各一張。
- 全身圖**不能**拿去裁頭像（頭裁完會太小、且會裁破）——頭像一律走半身圖。

**跨素材共用**：「細線稿＋水彩手繪」這套**技法**是人物立繪與**室內背景**（`type=interior`）共用的美術 DNA，兩者技法要一致（色調各自依角色／房間氛圍決定，不共用）。地圖用的像素建築外觀（`type=building`）維持像素風、不套水彩。

⚠️ **版權**：`design/ref/role-design-*` 是他方版權宣傳美術（Tales 系列等）——**僅作風格「方向」靈感，不臨摹其角色或畫作、不散布**；生成 prompt 內**不放** IP 名或畫師名（既避免臨摹版權作品，也避免模型把字畫進圖）。本 skill 只保留上面用自己的話寫的「文字風格描述」。這些參考圖不入 repo／散布。

## 生成後必做

1. **檢視圖片**（Read 截圖確認構圖），不合格改 prompt 重生成——每次生成都會不同，寧可多生兩張挑。
2. 把圖放進 `godot-project/assets/` 對應子目錄後，由 **Godot 編輯器 import**（會自動產生 `.png.import`）。⚠️ 上表標 **待改** 的 GDevelop build/腳本後處理在 Godot 沒有對應，別假設能跑；需要頭像裁切／去背等後製時，走 Godot 端方案（待設計）或先手動處理。
3. **授權標註**：在 `godot-crystal-tales/CREDITS_素材授權.md` 註明「AI 生成（Gemini），提示詞作者 John」。

## 邊界

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
