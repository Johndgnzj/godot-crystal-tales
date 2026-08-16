# 世界魔物／事件 Actor Sprite Prompt 組裝模板

- 版本: v3.2（2026-08-14；同步 D2 logical grid、outline 與原生 D3 分層）
- 規格唯一來源: [世界立繪規格](../../design/世界立繪規格.md)
- Gate 唯一來源: [世界立繪流程](../世界立繪流程.md)

適用於直接出現在地圖上的敵人、四足動物、直立魔物與劇情 actor。只在戰鬥畫面出現的敵人不需要 world sprite。

> 本檔不維護尺寸與驗收數值。每次組 prompt 必須從規格與 W0 已鎖定的例外體型讀入 `[SPEC_*]`；不可把下列模板當成第二份規格。

## 核心流程

- 新單位同樣走 D1 高解析非 Pixel Art Design Reference → D2 grid-authored 中等細節 Pixel Art Reference → D3 原生 Native Seed → 單姿態完整 strip。D1 不得自動轉成 D2，D1／D2 也不得自動縮小成 D3。
- D1／D2 的人型或魔物 reference prompt 依 [role_world.md](role_world.md) 的分層原則組裝；本檔的固定核心只用於已通過 W3 的 D3 之後的事件 strip。
- 一條 strip 只包含同一方向／姿態家族，例如 `Field` 四足或 `Upright` 直立；不同任務姿態分開製作。
- 非標準體型在 W0 依目標場景鎖定 cell、bbox、ground anchor 與影子，不按現實身高或為塞進一般人型 cell 而縮小。
- 圖內不得烘入影子；影子規則只讀世界立繪規格。

## Prompt 固定核心

```text
Create one complete horizontal native-grid pixel-art animation strip for a world-map event creature.

Use the attached approved Native Seed as the exact frame-0 production source. Preserve the same species anatomy, head shape, fur or skin pattern, body mass, limb count, palette, outline language, top lighting, logical pixel density, ground baseline, and root anchor in every frame.

CURRENT SPECIFICATION:
- cell, strip, frame count, alpha/key background, visible bounds and anchor: [SPEC_FROM_WORLD_DESIGN_AND_W0]
- posture family and ordered frames: [POSTURE_AND_FRAME_LIST]
- target-map comparison creature or character: [APPROVED_COMPARISON]

Author the entire strip in one animation pass on one shared logical grid. Keep the entire creature inside every cell, including ears, muzzle, paws, tail, claws and raised limbs. Body volume, markings and anatomy must not drift.

STYLE:
- high-quality world pixel art readable at native in-game size
- restrained palette, deep brown or gray-brown outline, soft top light, and material detail matching the supplied target-map screenshot
- same visual family as the supplied approved comparison sprite

EXCLUSIONS:
- no independently generated frames assembled afterward, per-frame zoom, resize, quantization, extra or missing limbs, changing markings, floor, baked shadow, glow, scenery, borders, labels, text, UI, logo, or watermark
```

標準人型事件敵人直接使用 [role_world.md](role_world.md)；四足／直立／超寬角色的 cell 與姿態在 W0 個別定案，不在 prompt 模板硬編另一套固定尺寸。

## 驗收重點

- [ ] D1／D2／D3 都已依 Gate 核可；frame 0 與 D3 後續逐像素一致。
- [ ] raw、Alpha、逐幀 montage、原生尺寸實景與動態預覽齊全。
- [ ] 姿態符合劇情用途，沒有把四足／直立或不同方向混成同一 strip。
- [ ] 體積、解剖、花紋、輪廓、global scale 與 ground anchor 不跨幀漂移。
- [ ] 影子由 runtime 依 W0 體積資料生成，沒有烘入 PNG。
