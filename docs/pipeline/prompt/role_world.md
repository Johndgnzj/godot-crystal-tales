# 世界角色 Sprite Prompt 組裝模板

- 版本: v3.4（2026-08-14；D2 prompt 加入 logical grid、binary Alpha 與 outline）
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
- exact shared D1/D2 body proportion and silhouette requirements: [SPEC_D1_BODY_PROPORTION]
- direction: [DOWN_SIDE_OR_UP]
- full unclipped character, neutral pose, complete feet
- identity feature list to preserve: [MUST_KEEP]
- details allowed to simplify later: [MAY_SIMPLIFY]
- details that must not appear: [MUST_DISCARD_OR_NOT_ADD]

EXCLUSIONS:
- not pixel art, not a sprite sheet, not a walk frame
- not a three-to-five-head-tall character portrait scaled down to fit the canvas
- no automatic size comparison based on the character's height in centimeters
- no scenery, floor, baked shadow, text, UI, labels, border, logo, or watermark
```

若角色有側馬尾、背包、單肩披風、武器掛側或其他不對稱特徵，必須實際附對應方向 reference；不能只在 prompt 寫「保持一致」。

## 二、D2 High-res Pixel Art Reference

D2 是核可 D1 的中等細節高解析 Pixel Art 版本，不是 native world seed，也不得由 D1 resize／quantize 得到。

```text
Create one medium-detail grid-authored pixel-art world character reference from the supplied approved non-pixel-art world design reference.

Preserve the exact approved two-head-tall body proportion, pose, silhouette mass, face, hairstyle, major clothing layers, palette, direction, and asymmetric accessories. Translate the illustration deliberately on the exact logical grid defined by the current specification. Use coherent hard-edged clusters, controlled color ramps, binary alpha, consistent logical pixel density, color-selective outlines, readable major material separation, and soft top lighting. Simplify individual hair strands, tiny embroidery, skin micro-shading, and surface texture into a few representative clusters.

CURRENT SPECIFICATION:
- canvas, transparency and high-resolution pixel-art rules: [SPEC_D2_CURRENT_VALUES]
- logical-grid unit, nearest-neighbor delivery scale, binary-alpha and outline rules: [SPEC_D2_GRID_ALPHA_OUTLINE]
- shared D1/D2 body proportion and silhouette: [SPEC_D1_D2_BODY_PROPORTION]
- direction: [DIRECTION]
- canonical world variant: [VARIANT]
- mirror safety and asymmetric side: [MIRROR_RULE]

STYLE:
- medium-detail high-resolution pixel art, not a low-detail native-size overworld sprite and not a fine-grained high-resolution pixel illustration
- same approved character design and chibi silhouette as D1, expressed entirely through pixel-art rendering
- use the supplied low-detail pixel-art sample as the lower boundary: add one clear level of facial, hair, clothing-layer, trim, and material information
- use the supplied over-detailed pixel-art sample only as the upper boundary: use substantially larger clusters, fewer color steps, fewer surface patterns, and no strand-by-strand or embroidery-by-embroidery rendering
- preserve only representative trim motifs and signature ornaments; let deliberate omission remain visible
- use one logical pixel for the normal outer outline; keep it continuous except for intentional negative space, with sufficient contrast around light hair and white clothing
- use hue-compatible deep brown, gray-brown, or a dark local-color variant; reserve internal outlines for major overlaps and clothing layers

EXCLUSIONS:
- do not resize, quantize, sharpen, trace, or sample colors automatically from D1
- do not reduce or collapse the D2 logical grid into the native world sprite; D3 is a separate redesign
- do not reproduce every D1 costume ornament, hair strand, fabric pattern, highlight, or micro-shadow
- no pure-black heavy outer border, doubled outline around the whole silhouette, sub-grid line, semi-transparent edge, or outline noise
- do not apply native-seed visible bounds, foot baseline, root anchor, or strip-frame constraints
- no blurred anti-aliased edge, mixed illustration rendering, isolated noise pixels, battle pose, floor, baked shadow, glow, scenery, text, UI, grid, label, logo, or watermark
- do not invent accessories or surface details absent from the approved design
```

D2 產完仍要走 W2；prompt 宣稱符合規格不算驗收。

## 三、D3 Approved Native Seed 候選

D3 以 D1 鎖定身份、D2 鎖定 Pixel Art 語言，但必須在 native grid 重新設計，不是任一高解析圖的縮小版。

```text
Create one native-grid pixel-art overworld character seed.

Use the supplied approved D1 as the identity and costume source, and the approved D2 as the pixel-art language and material-rendering source. Reinterpret the character deliberately for the native world grid. Preserve the identity silhouette, hairstyle, main clothing color blocks, face-defining pixels, and required signature accessory in that priority order. Simplify or omit low-priority details instead of compressing them into noise.

CURRENT SPECIFICATION:
- native canvas, visible-bounds class, foot baseline, root anchor, alpha, outline and palette rules: [SPEC_D3_CURRENT_VALUES]
- direction: [DIRECTION]
- canonical world variant: [VARIANT]
- mirror safety and asymmetric side: [MIRROR_RULE]
- approved identity priorities: [MUST_KEEP_MAY_SIMPLIFY_MUST_DISCARD]

STYLE:
- high-quality compact world pixel art readable at native 1x
- match the supplied approved world comparison sprite and target-map screenshot in head mass, limb thickness, pixel-cluster density, restrained palette, outline language, and top lighting
- preserve D2's visual language without attempting pixel-for-pixel correspondence

EXCLUSIONS:
- do not resize, collapse, quantize, sharpen, trace, or automatically sample D1 or D2
- no anti-aliased edge, semi-transparent outline, isolated noise pixels, incorrect extra detail, battle pose, floor, baked shadow, glow, scenery, text, UI, grid, label, logo, or watermark
- do not invent accessories or surface details absent from the approved design
```

D3 產完必須走 W3 validator、原生 1×、放大、核可角色同框與目標地圖實景 Gate。

## 四、正式 Walk Strip

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

## 五、交付前檢查

- [ ] 已重新讀取規格與流程，不從本檔、舊 prompt 或聊天記憶猜數值。
- [ ] D1／D2／D3／Walk Strip 名詞與用途沒有混用。
- [ ] D1 是高解析非 Pixel Art；D2 是獨立的中等細節高解析 Pixel Art 轉譯；D3 才是重新設計的原生 world seed。
- [ ] D1／D2 沒有被縮小成 D3；D2 沒有被 native bbox、腳底線或 validator 驗收。
- [ ] Walk 實際附上對應方向 D3，frame 0 後續會鎖回逐像素一致。
- [ ] 不對稱角色沒有任意鏡像；四方向分開走 Gate。
- [ ] D3／strip 依世界立繪流程交付原生 1×、放大、靜態、動態與實景驗收，不因模型聲稱尺寸正確而跳過 validator。
