# 世界角色 Sprite Prompt 組裝模板

- 版本: v3.0（2026-08-14）
- 適用: 主角、NPC、人型事件角色的 D1／D2／D3／Walk Strip
- 規格唯一來源: [世界立繪規格](../../design/世界立繪規格.md)
- Gate 唯一來源: [世界立繪流程](../世界立繪流程.md)

> 本檔只提供 prompt 組裝骨架，不維護尺寸、bbox、步態、命名或驗收數值。每次產圖前必須重新讀權威規格，把其中現行值填入 `[SPEC_*]`；不得沿用聊天記憶或舊 prompt 的數字。

## 一、D1 High-res World Design Reference

D1 是精細非 Pixel Art 的 world 角色設計，不是可縮小的 sprite source。

```text
Create one high-resolution non-pixel-art world character design reference.

Use the supplied official character art and written character setting as identity sources. Preserve the exact face, hairstyle, clothing layers, canonical travel outfit, palette, materials, and asymmetric accessories. Use the shared world-character Q-proportion, neutral grounded pose, and camera direction required by the supplied current specification. This reference exists to make small costume and identity details readable before they are reinterpreted as native pixel art.

DELIVERABLE:
- exact canvas and transparency requirements: [SPEC_D1_CANVAS_AND_ALPHA]
- direction: [DOWN_SIDE_OR_UP]
- full unclipped character, neutral pose, complete feet
- identity feature list to preserve: [MUST_KEEP]
- details allowed to simplify later: [MAY_SIMPLIFY]
- details that must not appear: [MUST_DISCARD_OR_NOT_ADD]

EXCLUSIONS:
- not pixel art, not a sprite sheet, not a walk frame
- no automatic size comparison based on the character's height in centimeters
- no scenery, floor, baked shadow, text, UI, labels, border, logo, or watermark
```

若角色有側馬尾、背包、單肩披風、武器掛側或其他不對稱特徵，必須實際附對應方向 reference；不能只在 prompt 寫「保持一致」。

## 二、D2 Pixel Art Reference／D3 Native Seed 候選

D2 必須重新 Pixel Art 化，禁止把 D1 resize 後當成結果。D3 是同尺寸 D2 的清稿，不另開一張高解析重畫。

```text
Create one native-grid pixel-art overworld character reference from the supplied approved high-resolution world design reference.

Reinterpret the character deliberately on the logical pixel grid. Preserve the approved identity silhouette, hairstyle, main clothing color blocks, face-defining pixels, and required signature accessory in that priority order. Simplify or omit the approved low-priority details instead of compressing them into noisy pixels.

CURRENT SPECIFICATION:
- canvas, visible-bounds class, foot baseline, root anchor, alpha and outline rules: [SPEC_D2_D3_CURRENT_VALUES]
- direction: [DIRECTION]
- canonical world variant: [VARIANT]
- mirror safety and asymmetric side: [MIRROR_RULE]

STYLE:
- high-quality compact world pixel art matching the supplied approved comparison sprite and target-map screenshot
- consistent head visual mass, limb thickness, pixel-cluster density, restrained palette, deep brown or gray-brown outline, and soft top lighting
- readable at native 1x before enlarged inspection

EXCLUSIONS:
- do not resize, quantize, sharpen, trace, or sample colors automatically from the high-resolution reference
- no anti-aliased edge, semi-transparent outline, isolated noise pixels, battle pose, floor, baked shadow, glow, scenery, text, UI, grid, label, logo, or watermark
- do not invent accessories or surface details absent from the approved design
```

D2 產完仍要走 W2；prompt 宣稱符合尺寸不算驗收。D3 清稿只能在同一 logical grid 修改 pixel，並走 W3 validator 與實景 Gate。

## 三、正式 Walk Strip

一個方向一條，實際附上該方向 D3 與目標地圖／核可角色比較圖。`[SPEC_FRAME_LIST]` 必須逐字取自規格 §三的現行步態表。

```text
Create one complete horizontal pixel-art overworld walk strip for a single direction and one character.

Use the attached approved Native Seed as the exact frame-0 production source. Preserve the same character identity, direction, hairstyle, clothing layers, asymmetric details, palette, outline language, logical pixel density, visible scale, foot baseline, and bottom-center root in every frame.

CURRENT SPECIFICATION:
- cell, strip, frame-count, alpha/key background and padding requirements: [SPEC_WALK_CURRENT_VALUES]
- direction: [DIRECTION]
- ordered frame list: [SPEC_FRAME_LIST]
- mirror safety and asymmetric side: [MIRROR_RULE]

The whole strip must be authored as one animation pass on one shared logical grid. Every frame uses the same cell, global scale and root. The grounded foot remains on the approved baseline; body motion must not cause clipping or per-frame zoom. The final walk frame must loop cleanly into the first walk-cycle frame.

EXCLUSIONS:
- no independently generated frames assembled afterward
- no per-frame fit-to-cell, resize, quantization, automatic limb translation, or fake step made only from cloth or arm movement
- no four-direction sheet, floor, baked shadow, glow, scenery, cell borders, labels, text, UI, logo, or watermark
```

## 四、交付前檢查

- [ ] 已重新讀取規格與流程，不從本檔、舊 prompt 或聊天記憶猜數值。
- [ ] D1／D2／D3／Walk Strip 名詞與用途沒有混用。
- [ ] D1 是非 Pixel Art；D2 是獨立 Pixel Art 轉譯，不是自動縮圖；D3 是同 grid 清稿。
- [ ] Walk 實際附上對應方向 D3，frame 0 後續會鎖回逐像素一致。
- [ ] 不對稱角色沒有任意鏡像；四方向分開走 Gate。
- [ ] 產圖後依世界立繪流程交付原生 1×、放大、靜態、動態與實景驗收，不因模型聲稱尺寸正確而跳過 validator。
