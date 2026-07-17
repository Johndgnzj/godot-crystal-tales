---
name: gen-role-prompt
description: 用問答收集角色立繪需求，組出「角色立繪」的產圖 prompt（純文字，直接貼到 John 的產圖工具）。三類立繪：a 戰鬥頭像 / b 對話半身 / c 角色全身，內建去背用「每角色挑對比螢光底＋整圈深描邊」規則。當 John 說「產角色 prompt／立繪 prompt」「幫某角色出頭像／半身／全身 prompt」「角色立繪產圖問答」「重出某角色立繪」等需求時使用。規格權威來源是 assets-source/role/ROLE_ART_SPEC.md（本 skill 內嵌的基礎規則區塊須與其同步）。
---

# gen-role-prompt：問答 → 角色立繪產圖 prompt（純文字）

目的：John 要為角色（主角／NPC）產立繪時，透過問答把該給的資訊補齊，輸出**一段可直接複製貼上的純文字
prompt**（中文或英文，執行前先問；產圖工具吃的），不是 markdown 文件。三類立繪 a/b/c 各產各的 prompt。

權威規格：`assets-source/role/ROLE_ART_SPEC.md`（下方「固定開頭」須與其「三、風格」＋「四、去背螢光底」同步）。
產圖走 CLAUDE.md「產圖驗收流程」兩階段（先預覽驗收、過了才整合）。

## 流程

1. **一次問完**（別擠牙膏式來回）。用一則訊息列出下面問題讓 John 一次回答；**務必先問「產出語言：中文或英文」**
   （John 兩種都用得到，測過中文結果稍好）。選項型問題（語言／類別）可用 AskUserQuestion，自由描述型（外觀／配色）
   用文字問。John 若在最初訊息已給部分資訊，**只問缺的**；`docs/story/角色設定.md` 有的外觀先引用、缺再問。
2. 依回答**挑螢光底色**（見下規則）與**取景**，組 prompt（模板見下，依所選語言取對應版本）。
3. 輸出：**一個 code block，內容是所選語言（中文或英文）的純 prompt 文字**，整段同一語言、不混語言；
   不含 markdown 標記、不含「【】」段落標題。John 複製整塊就能貼。
4. 同角色多張（a/b/c）：**角色描述逐字沿用**，只換「取景那一句」與比例；螢光底色三張一致。
   這樣三張才會是同一個人（風格一致性靠這個）。

## 問題清單（缺什麼問什麼）

| # | 問題 | 沒回答時的預設 |
|---|---|---|
| 0 | **產出語言：中文／英文**（執行前先問）| 中文 |
| 1 | 角色 id 與名稱（對照 ROLE_ART_SPEC「二、角色清單」）| 必問 |
| 2 | 要哪類：a 戰鬥頭像 / b 對話半身 / c 角色全身（可多選）| 必問 |
| 3 | 外觀：性別／年齡感、髮型髮色、眼睛、臉部特徵、氣質表情 | 有角色設定.md 先引用，缺再問 |
| 4 | 服裝與配色（主色＋配件＋武器）——**這決定螢光底色** | 必問，無預設 |
| 5 | 姿勢／表情（b/c 可指定站姿、持劍…）| a 正臉微笑、b/c 自然站姿 |

## 挑螢光底色（依 ROLE_ART_SPEC 四）

看第 4 題的角色配色：
- 預設 **螢光綠 #00FF00**；
- 角色有明顯**綠／青系** → **螢光洋紅 #FF00FF**；
- 角色**同時有綠又有紅／粉** → **螢光青 #00FFFF**。

把選定色**寫成具體色碼**填進 prompt（不要在輸出裡留 `{KEY_COLOR}` 這種變數）。

## Prompt 組裝模板

固定開頭（基礎規則，**與 ROLE_ART_SPEC.md 三＋四同步，改規格要兩邊一起改**）：

**英文版**：

```
High-quality Japanese anime JRPG character portrait, delicate line art with soft watercolor rendering: gentle gradients, translucent washes, subtle paper texture. Not thick-black cel outline, not flat cel shading, not pixel art, not 3D. Expressive anime eyes, an appealing face that looks slightly younger than the stated age, illustration-grade finish and rich detail. One character only, centered, facing the viewer, no frame.
Trace the character's own body contour with one clean, continuous dark (#1A1A1A) ink line about 2-4px thick that hugs the figure's silhouette (inked lineart following the edge of the body), so the character separates cleanly from the background for easy background removal. This line follows the body's shape ONLY — it is NOT a rectangle, border, or frame around the image.
Background: a single flat uniform {KEY_COLOR} fill covering the whole canvas edge to edge (full bleed) — no gradient, no texture, no shadow, no border, no frame, no rounded card edge, no vignette, and no colored light from the background spilling onto the character.
No text, no letters, no numbers, no character name, no logo, no watermark, no UI.
```

**中文版**（與英文等義；依所選語言擇一整段貼）：

```
高品質日系動漫 JRPG 角色立繪，細線稿＋柔和水彩：柔和漸層、透明水洗、淡紙紋。非粗黑 cel 描邊、非平塗、非像素、非 3D。有神的眼睛、五官好看且比實際年齡小的臉，插畫等級的完成度與豐富細節。畫面只有一個角色、置中、面向鏡頭、無外框。
沿角色身體的外輪廓描一條乾淨連續的深色（#1A1A1A）墨線，約 2-4px、緊貼人物外形（順著身體邊緣走的線稿），與背景清楚分離、方便去背；這條線只順著身體形狀走，不是在畫面四周加矩形邊界或外框。
背景：單一平塗純色 {KEY_COLOR} 滿版填滿整個畫面到邊——無漸層、無材質、無陰影、無邊框、無外框、無圓角卡片邊、無暗角，且背景色不可有光暈打到角色身上。
不要文字、字母、數字、角色名、logo、浮水印、UI。
```

接著依回答附加（有才加，續在固定開頭後、**用所選語言且整段同一語言**）：

- 角色描述：英 `Character: {外觀＋服裝配色＋氣質}.`／中 `角色：{外觀＋服裝配色＋氣質}。`
- 取景（依類別擇一）：
  - a 戰鬥頭像：英 `Framing: head-and-shoulders close-up, face clearly visible, square 1:1 composition.`／中 `取景：頭到肩的特寫，臉部清楚，正方形 1:1 構圖。`
  - b 對話半身：英 `Framing: half body from the thighs up, portrait 3:4 composition, relaxed standing pose.`／中 `取景：大腿以上半身，直幅 3:4 構圖，自然站姿。`
  - c 角色全身：英 `Framing: full body head-to-toe standing pose, portrait 3:4, leave headroom above the head and space below the feet, figure centered.`／中 `取景：頭到腳的全身站姿，直幅 3:4，頭頂與腳下都留空，人物置中。`
- 姿勢／表情（有才加）：英 `Pose/expression: {...}.`／中 `姿勢／表情：{...}。`

`{KEY_COLOR}` 換成具體螢光色：英 `fluorescent green #00FF00`／`fluorescent magenta #FF00FF`／`fluorescent cyan #00FFFF`；
中 `螢光綠 #00FF00`／`螢光洋紅 #FF00FF`／`螢光青 #00FFFF`。

## 輸出後提醒（一行即可，不囉嗦）

- 產完自查 ROLE_ART_SPEC.md 交付檢查清單（比例／單人置中／螢光底乾淨＋深描邊封閉／去背無 halo）。
- 檔名：a→`face_<id>.png`（縮 144²；也可從 b 臉部裁，但另產 1:1 特寫框得更好）、b→`portrait_<id>.png`、
  c→`menuart_<id>.png`，存 `godot-project/assets/ui/`。**先預覽給 John 驗收，過了才整合**（CLAUDE.md 產圖驗收流程）；
  整合後 Godot Reimport＋更新 `CREDITS_素材授權.md`。

## 範例（John 答：「路德 ludo、要 b、棕髮金瞳開朗、白襯衫＋棕皮甲＋紅披風、腰配劍、中文」）

配色無綠 → 螢光綠。輸出（純文字，一個 code block）：

```
高品質日系動漫 JRPG 角色立繪，細線稿＋柔和水彩：柔和漸層、透明水洗、淡紙紋。非粗黑 cel 描邊、非平塗、非像素、非 3D。有神的眼睛、五官好看且比實際年齡小的臉，插畫等級的完成度與豐富細節。畫面只有一個角色、置中、面向鏡頭、無外框。
沿角色身體的外輪廓描一條乾淨連續的深色（#1A1A1A）墨線，約 2-4px、緊貼人物外形（順著身體邊緣走的線稿），與背景清楚分離、方便去背；這條線只順著身體形狀走，不是在畫面四周加矩形邊界或外框。
背景：單一平塗純色 螢光綠 #00FF00 滿版填滿整個畫面到邊——無漸層、無材質、無陰影、無邊框、無外框、無圓角卡片邊、無暗角，且背景色不可有光暈打到角色身上。
不要文字、字母、數字、角色名、logo、浮水印、UI。
角色：15 歲少年，蓬鬆棕髮、金褐色眼睛、開朗笑容；白襯衫外罩棕色皮甲、紅色披風，腰間配一把劍。
取景：大腿以上半身，直幅 3:4 構圖，自然站姿。
```
