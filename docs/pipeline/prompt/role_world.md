# 世界角色 Sprite Strip Prompt

本檔用於主角、NPC 與人型事件角色。權威規格見 [世界立繪規格](../../design/世界立繪規格.md)，Gate 見 [世界立繪流程](../世界立繪流程.md)。

## 使用順序

1. 先以角色 reference＋目標地圖截圖產一張 `Down Idle` seed。
2. seed 必須以 runtime 原生尺寸合成回地圖，核可後才去背。
3. 每次只產「一個方向＋一個動作家族」的完整 horizontal strip。
4. 不逐幀各產一張，也不直接產 `9×4` 四方向 sheet。

## Prompt 固定核心

```text
Create one horizontal pixel-art sprite strip for an overworld RPG character.

Use the approved world seed as the exact character identity and style source. Preserve the same face, hairstyle, clothing layers, body proportions, palette, outline thickness, top lighting, pixel density, and bottom-center foot anchor in every frame.

OUTPUT LAYOUT:
- exactly [FRAME_COUNT] equal-width cells in one horizontal row
- one complete character in each cell
- frames ordered left to right as: [FRAME_LIST]
- same canvas size, global character scale, foot baseline, and bottom-center root anchor in every cell
- generous solid key-color padding around every silhouette

STYLE:
- high-quality pixel art, compact approximately two-head-tall overworld proportions
- readable at native in-game size, with restrained detail and medium-low saturation
- deep brown or gray-brown outlines, soft top light, no battle-art highlights
- consistent with the supplied target-map screenshot and approved comparison character

BACKGROUND AND EXCLUSIONS:
- full-canvas single flat chroma-key color, perfectly uniform
- no transparency, gradient, floor, baked shadow, glow, scenery, text, logo, frame lines, labels, UI, or watermark
- no cropping; hats, hair, clothes, hands, feet, and held props stay fully inside each cell
```

## 簡易三幀 Down Strip

將變數填成：

```text
[FRAME_COUNT] = 3
[FRAME_LIST] =
1. Down Idle — neutral standing pose, both feet grounded
2. Down Step L — the character's anatomical left foot, seen on the image-right side, is the forward contact foot
3. Down Step R — the character's anatomical right foot, seen on the image-left side, is the forward contact foot
```

追加：

```text
Step L and Step R must visibly exchange the contact foot, knee overlap, trouser or skirt shading, hip occlusion, and sole landing point. Do not fake the step change using only arm movement, cloth movement, mirroring, or whole-body vertical translation.
```

## 正式九幀 Walk Strip

每個方向分開出一條，依序製作 `Down → Left → Right → Up`；前一方向通過場景 Gate 後才做下一方向。

```text
[FRAME_COUNT] = 9
[FRAME_LIST] =
0. neutral Idle
1. left-foot contact
2. left-foot weight
3. left-foot passing
4. left-foot recovery
5. right-foot contact
6. right-foot weight
7. right-foot passing
8. right-foot recovery, able to loop seamlessly into frame 1
```

方向補充：

- `Down`／`Up`：清楚呈現角色解剖上的左右腳交換。
- `Left`：鼻尖、胸口與腳尖朝畫面左。
- `Right`：鼻尖、胸口與腳尖朝畫面右；不得以錯標 slot 冒充方向。

## 尺寸提示

- 標準人型：每格 `64×64px`。
- 若人物服裝／物種比例確實需要，僅按場景需求以 `32px` 增量擴大，不為了保留大圖細節任意放大。
- Prompt 可描述 strip 總尺寸，但驗收以「等格、原生 cell、共用 anchor」為準，不以模型聲稱的數字為準。

## 交付檢查

- [ ] 同一次生成得到完整 strip。
- [ ] frame 0 與核可 world seed 的身份、比例與像素密度一致。
- [ ] 所有格共用 global scale、腳底線與 bottom-center anchor。
- [ ] 沒有內建地面或影子。
- [ ] raw strip 通過後才去背；去背後再做原生尺寸地圖合成。
