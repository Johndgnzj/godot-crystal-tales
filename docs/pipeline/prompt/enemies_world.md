# 世界魔物／事件 Actor Sprite Strip Prompt

適用於會直接出現在地圖上的敵人、四足動物、直立魔物與劇情 actor。遭遇表內只在戰鬥畫面出現的敵人不需要本素材。

## 核心規則

- 先核可一張目標姿態 seed，再一次產完整 horizontal strip。
- 一條 strip 只包含同一姿態家族，例如 `Field` 四足或 `Upright` 正面直立；不同任務姿態分開製作。
- 大型角色可依場景體積，在 `64×64` 基礎上以 `32px` 增量擴充橫或高。
- 圖內不得包含影子；影子由場景端套用 [世界立繪規格](../../design/世界立繪規格.md) 的半透明漸層。

## Prompt 固定核心

```text
Create one horizontal pixel-art sprite strip for a world-map event creature in an RPG.

Use the approved creature seed as the exact identity and style source. Preserve the same species anatomy, head shape, fur or skin pattern, body mass, limb count, palette, outline thickness, top lighting, pixel density, and bottom-center ground anchor in every frame.

OUTPUT LAYOUT:
- exactly [FRAME_COUNT] equal-width cells in one horizontal row
- frames ordered left to right as: [FRAME_LIST]
- same cell size, global creature scale, ground line, camera angle, and root anchor in every cell
- the entire creature, including ears, muzzle, paws, tail, claws, and raised limbs, remains inside every cell

STYLE:
- high-quality pixel art designed to stay readable at native in-game size
- medium-low saturation and deep brown or gray-brown outline
- soft top light and restrained material detail matching the supplied target-map screenshot
- same visual family as the supplied approved player or NPC comparison sprite

BACKGROUND AND EXCLUSIONS:
- full-canvas single flat chroma-key color, perfectly uniform
- no transparency, gradient, floor, baked shadow, glow, scenery, text, logo, cell borders, labels, UI, or watermark
- no pose drift, anatomy mutation, extra limbs, missing limbs, changing fur markings, or per-frame zoom
```

## 常用尺寸與幀組

### 四足大型魔物

```text
cell size: 96×64px
[FRAME_COUNT] = 3
[FRAME_LIST] =
1. front-facing quadruped field idle
2. subtle weight shift and breathing, all four paws anatomically valid
3. opposite subtle weight shift and breathing, able to loop into frame 1
```

### 正面直立大型魔物

```text
cell size: 64×96px
[FRAME_COUNT] = 3
[FRAME_LIST] =
1. front-facing upright idle, both hind feet firmly grounded
2. subtle chest expansion and forelimb tension
3. subtle chest release and opposite forelimb tension, able to loop into frame 1
```

### 標準人型事件敵人

使用 [role_world.md](role_world.md) 的 `64×64` 三幀或九幀模板，外觀改由敵人 seed 鎖定。

## 驗收重點

- [ ] raw strip、逐幀 montage、alpha frames 與原生尺寸場景合成都已提供。
- [ ] 四足／直立姿態符合指定任務，沒有把兩種用途混用。
- [ ] 體積比標準人型大得合理，不因縮回 `64×64` 而失去壓迫感。
- [ ] 各幀解剖、花紋、輪廓與 global scale 一致。
- [ ] bottom-center 接地穩定；場景影子寬度按實際身形調整。
