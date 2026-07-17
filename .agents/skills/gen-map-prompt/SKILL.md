---
name: gen-map-prompt
description: 用問答收集地圖需求，組出「手繪畫面地圖」的產圖 prompt（純文字，直接貼到 John 的產圖工具）。當 John 說「產地圖 prompt」「幫我出一張地圖的說明」「我要產 M4/新地區的圖」「地圖產圖問答」等需求時使用。規格權威來源是 assets-source/map/MAP_ART_SPEC.md（本 skill 內嵌的基礎規則區塊須與其同步）。
---

# gen-map-prompt：問答 → 產圖 prompt（純文字）

目的：John 要為「手繪畫面地圖」路線（`scenes/world/painted/`）產新圖時，透過問答把該給的資訊補齊，
輸出**一段可直接複製貼上的純文字英文 prompt**（產圖工具吃的），不是 markdown 文件。

## 流程

1. **一次問完**（別擠牙膏式來回）。用一則訊息列出下面的問題清單讓 John 一次回答；
   選項型的問題（類型/尺寸）可用 AskUserQuestion，自由描述型（地貌/氛圍）用文字問。
   John 若在最初的訊息就給了部分資訊，**只問缺的**。
2. 依回答組 prompt（模板見下）。
3. 輸出：**一個 code block，內容是純英文 prompt 文字**——不含 markdown 標記、不含中文、
   不含「【】」段落標題。John 複製整塊就能貼。
4. 同地區多張圖：逐張問「差異項」（地貌細節/出入口/地標）即可，基礎規則與調色盤沿用第一張，
   **同地區的 Mood/palette 描述必須逐字相同**（風格一致性靠這個）。

## 問題清單（缺什麼問什麼）

| # | 問題 | 沒回答時的預設 |
|---|---|---|
| 1 | 地圖類型：野外／地城洞窟／城鎮／boss 房 | 野外 |
| 2 | 地貌主題（例：松樹密林、岩石礦道、雪山隘口） | 必問，無預設 |
| 3 | 氛圍與色調（例：mossy green＋灰石、微霧） | 依主題給一個建議請 John 確認 |
| 4 | 空間骨架（例：西→東蜿蜒主路、中央有空地） | 「一條主路貫穿＋一處開放空地」 |
| 5 | 出入口：哪幾個邊、位置（上/中/下 或 左/中/右）、通往哪張圖 | 必問（對照 map-def.xlsx 鄰接） |
| 6 | 地標（純裝飾；例：北側石陣、乾涸噴泉） | 不放 |
| 7 | （城鎮才問）互動建築幾棟、各是什麼功能與外觀特徵 | — |
| 8 | 尺寸 | 1280×1280 |
| 9 | 特殊：boss 房要 arena 空間？需要前景遮擋層（罕見）？ | 否 |

## Prompt 組裝模板

固定開頭（基礎規則，**與 MAP_ART_SPEC.md 同步，改規格要兩邊一起改**）：

```
Top-down 3/4 view RPG game map, hand-painted pixel-art style.
Canvas exactly {SIZE}. The map area has an irregular organic border;
everything OUTSIDE the map border is flat uniform dark gray (#3a3a3a), no texture.
Grid-friendly layout: walls, paths and doorways align to a 32px grid;
walls at least 32px thick, main paths at least 64px wide.
Every exit is an opening (at least 64px wide) in the border wall,
at the position I specify. Do not draw directional arrows on the map.
Muted, low-saturation cohesive palette; walkable ground is even, low-detail
and brighter; obstacles (walls/trees/rocks) one shade darker than ground.
Soft top-down lighting, no long cast shadows across paths.
Tree canopies and roof eaves must NOT overhang walkable paths.
No text, no letters, no numbers, no grid lines, no UI, no watermark.
No characters, no NPCs, no monsters, no treasure chests, no signboards
with text (interactive objects are placed by the game engine).
```

接著依回答附加（有才加，全用英文換行續在後面）：

- `Theme: {地貌主題英譯}`
- `Mood and palette: {氛圍色調英譯}`
- `Layout: {空間骨架英譯}`
- `Exits: {每個出入口一句，格式 "west edge, middle: opening (leads to the town)"}`
- `Landmarks (decorative only): {地標英譯}`
- boss 房追加：`Include a wide open arena clearing (at least 320x320px) at {位置}, with a slightly distinct ground texture.`
- 城鎮追加：
  ```
  Buildings ({N}): {每棟功能＋外觀特徵，如 "an inn with a red roof, a smithy with a stone chimney"}.
  Each building: front facade facing DOWN, door centered at the bottom edge of the facade,
  door 32-64px wide, at least 64px of clear ground in front of each door.
  Each building visually distinct by roof color and shape (no text signs).
  ```
- 前景遮擋層（John 明說才加）：`Also note: this map will need a separate foreground layer; keep tall objects' canopies compact and clearly separable from the ground.`

## 輸出後提醒（一行即可，不囉嗦）

- 產完自查 MAP_ART_SPEC.md 的交付檢查清單（尺寸整除 32／圖外深灰／開口對位／別畫互動物件）。
- 檔名：`assets-source/map/<Mx>-<region>/<region>-<id>.png`，並更新 map-def.xlsx。

## 範例（John 答：「地城洞窟、廢棄水晶礦坑藍紫微光、北中出口往 M2、南中入口回 h、東側水晶簇地標」）

輸出（純文字，一個 code block）：

```
Top-down 3/4 view RPG game map, hand-painted pixel-art style.
Canvas exactly 1280x1280. The map area has an irregular organic border;
everything OUTSIDE the map border is flat uniform dark gray (#3a3a3a), no texture.
Grid-friendly layout: walls, paths and doorways align to a 32px grid;
walls at least 32px thick, main paths at least 64px wide.
Every exit is an opening (at least 64px wide) in the border wall,
at the position I specify. Do not draw directional arrows on the map.
Muted, low-saturation cohesive palette; walkable ground is even, low-detail
and brighter; obstacles (walls/trees/rocks) one shade darker than ground.
Soft top-down lighting, no long cast shadows across paths.
Tree canopies and roof eaves must NOT overhang walkable paths.
No text, no letters, no numbers, no grid lines, no UI, no watermark.
No characters, no NPCs, no monsters, no treasure chests, no signboards
with text (interactive objects are placed by the game engine).
Theme: abandoned crystal mine tunnels carved in dark rock.
Mood and palette: deep blue-purple tones with faint glowing crystal light, slightly misty.
Layout: winding tunnels connecting a few small chambers.
Exits: north edge, middle: opening (leads deeper into the mine).
south edge, middle: opening (back to the forest).
Landmarks (decorative only): a large crystal cluster along the east wall.
```
