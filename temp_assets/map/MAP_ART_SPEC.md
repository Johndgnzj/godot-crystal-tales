# 地圖產圖規格（每次產圖必帶的基礎規則）

- 版本: v1.0（2026-07-16，依 M3 東邊森林建置經驗定稿）
- 適用: 手繪畫面地圖路線（整張圖＋Godot 刷碰撞），對應 `scenes/world/painted/`
- 產完交付流程見文末「交付檢查清單」

---

## 一、工程硬規格（不符會增加接圖工，盡量遵守）

| 項目 | 規格 | 為什麼 |
|---|---|---|
| **網格單位** | 32×32 px | 碰撞格、門寬、落點全以此為單位 |
| **圖片尺寸** | **1280×1280**（=40×40 格）；同一地區所有圖同尺寸 | 邊長必須是 32 的倍數才能整除刷格。M3 現有的 1254 不整除，是用 38px 格遷就的——新圖照 1280 來 |
| **圖外背景** | 統一素色深灰（近 #3a3a3a），無雜訊無漸層 | 機器能自動把圖外區域預刷成碰撞，省你手刷外圈 |
| **出入口** | 在邊緣開缺口＋**箭頭標示**（照 M3 現有畫法）；開口寬 **≥2 格（64px）** | 箭頭讓人和機器都能對位；太窄玩家會卡 |
| **開口對位** | 相鄰兩張圖的開口要在**同一軸線位置**（A 東口的 y ≈ B 西口的 y） | 過圖時玩家視覺連續，落點不用亂搬 |
| **牆/路寬** | 牆厚 ≥1 格；主要通道寬 ≥2 格 | 1 格窄道刷碰撞後實際可走空間很緊 |
| **視角** | top-down 3/4（RPG 俯視、微透視），同地區統一 | 與 M3 現有一致 |

## 二、畫面內容禁項（畫進去就是裝飾、動不了）

- ❌ 文字、數字、格線、UI、浮水印
- ❌ 角色、NPC、怪物（引擎 sprite 另擺）
- ❌ **會互動的物件：寶箱、告示牌、採集點、傳送陣**——引擎另擺才有互動；M3 的 a 圖裡畫死的寶箱就打不開（教訓）
- ⭕ 純裝飾（石堆、圓木、花草、柵欄）隨便畫

## 三、遮擋圖層（會蓋住角色的物件）

原則：**能避免就避免**——AI 產兩張完美對齊的分層圖不可靠。

- **預設規則（寫進 prompt）**：樹冠、屋簷不要懸空伸進可走區域；高物件的「頭」壓在自己的碰撞footprint上。這樣整張圖單層即可，玩家永遠在最上層也不穿幫。
- **真的要景深的場景**（例外，逐張標記）：先產基底圖，再從基底圖摳出前景層存 `<id>_fg.png`（同尺寸、透明底、只含會蓋角色的樹冠/屋頂上緣）。用 inpaint 或手動摳，不要讓 AI 憑空產第二張。

## 四、色彩規則（你的直覺是對的，補上原因）

- **中低飽和、中對比**；整地區同一調色盤、同光照方向（頂光、柔陰影）
- **可走地面（草/路）要均勻、低細節、偏亮**；**障礙（牆/樹）比地面暗一階**——角色 sprite 才跳得出來，你刷碰撞時也一眼分得出擋不擋
- 陰影不要大片橫跨走道（會誤導「這裡不能走」）

## 五、城鎮附加規格（有互動建築時）

- 門：**正面朝下、位於建築下緣中間、寬 1–2 格、門前留 ≥2 格空地**（玩家從下方走上門格進入——沿用 gen-art `building` type 的定調）
- 每棟外觀差異要明顯（顏色／屋頂形狀／招牌圖形，不用文字）
- prompt 裡明列棟數與功能，例：「6 棟：公會、旅店、神殿、鎮長宅、道具店、鐵匠鋪」

---

## 每次產圖的 Prompt 模板

```
【基礎規則&風格】（固定，每次照貼）
Top-down 3/4 view RPG game map, hand-painted pixel-art style.
Canvas exactly 1280x1280. The map area has an irregular organic border;
everything OUTSIDE the map border is flat uniform dark gray (#3a3a3a), no texture.
Grid-friendly layout: walls, paths and doorways align to a 32px grid;
walls at least 32px thick, main paths at least 64px wide.
Every exit is an opening (at least 64px wide) in the border wall,
marked with a small wooden arrow sign, at the position I specify.
Muted, low-saturation cohesive palette; walkable ground is even, low-detail
and brighter; obstacles (walls/trees/rocks) one shade darker than ground.
Soft top-down lighting, no long cast shadows across paths.
Tree canopies and roof eaves must NOT overhang walkable paths.
No text, no letters, no numbers, no grid lines, no UI, no watermark.
No characters, no NPCs, no monsters, no treasure chests, no signboards
with text (interactive objects are placed by the game engine).

【地貌描述、大小、出入口】（每張填）
Theme: <地貌，如 dense pine forest / rocky mine tunnels>
Mood/palette: <如 mossy green with grey stone, slightly misty>
Layout: <空間骨架，如 a winding path from west to east, small clearing in the center>
Exits: <如 west edge middle → arrow; east edge middle → arrow; north edge upper-right → stone stairs>
Landmarks: <如 a ring of standing stones in the north clearing>（純裝飾）

【互動型房子】（城鎮才填）
Buildings (N): <棟數＋每棟功能與外觀特徵>
Each building: front facade facing DOWN, door centered at the bottom edge,
door 32–64px wide, at least 64px of clear ground in front of each door.
```

---

## 交付檢查清單（產完給我接圖前自查）

1. [ ] 尺寸 1280×1280（或同地區統一尺寸，且能被 32 整除）
2. [ ] 圖外是素色深灰
3. [ ] 每個出入口有箭頭、開口 ≥2 格，位置跟 map-def 的鄰接關係一致
4. [ ] 相鄰圖開口對位
5. [ ] 圖裡沒有寶箱/告示牌/角色
6. [ ] 檔名照慣例：`temp_assets/map/<Mx>-<region>/<region>-<id>.png`（boss 房加 `-boss-room`）
7. [ ] map-def.xlsx 網格已更新（新圖的空間位置）

之後我接手：檢查尺寸→複製進 `assets/map/<region>/`→建場景＋依 map-def 接連通＋預刷圖外背景→交回給你刷碰撞。
