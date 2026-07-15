---
name: gen-art
description: 用 Gemini API 生成水晶戰記（Godot 版）的美術素材（NPC/角色立繪、戰鬥背景、區域地圖、標題圖、圖示、室內背景）。當 John 說「產圖」「生成素材」「幫某角色畫立繪」「換戰鬥背景」等美術生成需求時使用。像素級小圖（行走圖、圖磚、敵人戰鬥圖）不適用本 skill——那些用 LPC 合成或商店素材。
---

# gen-art：Gemini 產圖管線（Godot 版）

呼叫 Gemini 產圖，存進 `godot-project/assets/`，交給 Godot 編輯器 import。

## 金鑰

`GEMINI_API_KEY` 走 `.env`（`KEY=VALUE`，須 gitignore，不要寫進程式碼／commit）。腳本會先讀環境變數，否則從 skill 位置往上逐層找 `.env`（最多 8 層）——目前會命中 `GDevelop/.env`，可直接用。

## 產圖

```bash
# 於 godot-crystal-tales/ 根目錄執行；--out 路徑相對 godot-project/
python3 .claude/skills/gen-art/gen_image.py --type <類型> [--frame bust|full] --prompt "<描述>" --out <路徑>
```

模型 `gemini-2.5-flash-image`（自動退階、429/503 自動重試）。`--type` 會自動加對應風格前綴，`--prompt` 只需寫「畫面內容」。各 type：

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

- 不適合 16–64px 像素小圖（行走圖／圖磚／敵人小圖）——用 LPC 合成或商店素材。
- prompt 不放遊戲名／人名文字（模型會把字畫進圖）；也不放版權 IP／畫師名。
- 不要修改 GDevelop 專案（`../GDevelop/`、`../gd-crystal-tales/`）——唯讀參考來源。
