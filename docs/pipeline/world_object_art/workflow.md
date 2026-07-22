# 地圖互動物件美術流程

## 目的

建立可重用、可互動、能貼合地圖環境的物件素材；不把寶箱、任務物品等互動物件畫死在地圖背景中。

## Step 1 建立互動需求

先記錄以下資訊：

- 類型：`chest`／`quest_item`（首批）；採集點、告示牌等日後再擴充。
- art id：描述外觀族，不含地圖位置或獎勵，例如 `chest_wood`、`chest_mossy`。
- 地區風格：森林、礦坑、城鎮等，只影響材質、配色與磨損程度。
- footprint：首批固定 `1×1` 格（成品 `32×32px`）。
- 狀態：依 [`../../design/地圖互動物件規格.md`](../../design/地圖互動物件規格.md) 的類型規則選擇。

互動邏輯、掉落物、任務 flag 與地圖座標不寫進 prompt；它們屬於 Godot content／scene。

## Step 2 建立描述與外觀錨點

在 `prompts/descriptions/<id>.md` 記錄外觀、地區材質、footprint、目標狀態與固定 anchor 路徑。

先產三張 `design_anchor` 候選。它是非狀態的外觀錨點，驗收通過後，所有狀態都必須實際附上 `design_anchor_alpha.png` 作 image reference；換對話時也必須重新附圖。

## Step 3 選類型模板並建立 prompt

讀 `prompts/types/<type>.md`，選出外觀族與狀態。使用 `prompts/presets/world_object_v1.md` 作固定開頭，再附上描述檔與類型模板的狀態文字。

## Step 4 預覽產圖

每個狀態產三張候選。除了狀態允許的改變外，其餘外觀都必須跟 anchor 一致。

- `chest/opened`：只改蓋子、內部與少量可見內容，不能換箱體或增加地面。
- `quest_item/present`：必須輪廓清楚，不得發光、漂浮或內含可讀文字。

預覽未通過前，禁止複製到 `godot-project/assets/`。

## Step 5 驗收與正規化

依 `checklist.md` 檢查。將核可的 alpha 圖去背、裁切後放回同尺寸畫布，bottom-center 錨點固定；再最近鄰縮放至規格尺寸。

## Step 6 固定來源檔命名

來源放在 `assets-source/props/<id>/`，檔名一律固定、不得附日期；重產時覆蓋對應檔。

| 用途 | 固定檔名 |
|---|---|
| 外觀錨點候選 | `design_anchor_candidate_1_raw.png` 至 `candidate_3_raw.png` |
| 外觀錨點 | `design_anchor_raw.png`、`design_anchor_alpha.png` |
| 狀態候選 | `<state>_candidate_1_raw.png` 至 `candidate_3_raw.png` |
| 核可狀態 | `<state>_raw.png`、`<state>_alpha.png` |
| 正規化來源成品 | `<state>.png` |

## Step 7 正式整合

只有 John 明確驗收通過後才能整合：

1. 複製正規化 PNG 到 `godot-project/assets/props/`。
2. 首批共用寶箱固定覆蓋 `chest_closed.png`、`chest_opened.png`；這可直接被現有 `world_scene.gd` 載入。
3. 任務拾取物或新的外觀族若需要程式載入，先另開實作任務；不可只複製檔案就假設遊戲會顯示。
4. 更新 `CREDITS_素材授權.md`，Reimport，並執行 `godot --headless --check-only --path godot-project`。

## 相關

- [物件規格](../../design/地圖互動物件規格.md)
- [驗收清單](checklist.md)
- [素材管理規範](../素材管理規範.md)
- [地圖畫面規格](../../design/地圖畫面規格.md)
