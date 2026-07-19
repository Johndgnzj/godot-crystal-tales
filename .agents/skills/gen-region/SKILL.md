---
name: gen-region
description: 產生一整個 RPG 地區的 Godot 地圖數據——程序生成迷宮 → 多張 TileMap 世界場景（.tscn，用出入口連成連通圖）→ 自動選派敵人 encounter 表 →（可選）擺 boss。當 John 說「生成地區／新地圖／迷宮／礦坑／洞窟／森林／dungeon」「做一個 N 層地下城」「產一張世界場景」「幫某地區配怪」等需求時就用，即使沒明講 skill 名。只吃現有 32px 素材（草原/森林/礦坑/洞窟；目前無水無雪）。要把地圖轉成手繪風格的「地區圖 png」，改用 gen-art 的「地圖風格化」。
---

# gen-region：產一整個地區的地圖數據

吃一份「地區 recipe」（typed `.tres`，或 `.json`）→ 產出**遊戲用的地圖數據**：
1. **TileMap 世界場景**：多張 `.tscn`（滿足 `world_scene.gd` 的 `@export` 契約），用出入口互相對接成**連通圖**，內建連通性 assert（保證走得通）。
2. **敵人 encounter 表**：依每張圖的 `level_band` 自動選派、組 formation，寫 `resources/content/encounters/<id>.tres`；可選 boss。

> **引擎內 GDScript 生成**（2026-07-16 起，取代舊 Python `region_gen.py`）：演算法在 `godot-project/scripts/map/map_kit.gd`（`MapKit` 靜態工具＋`MapGrid`），驅動器在 `scripts/map/region_generator.gd`（`extends SceneTree`，headless）。`.tscn` 用 `PackedScene.pack`、`.tres` 用 `ResourceSaver.save` 產出（不再字串拼接）。見 `TASKS/12_地圖生成器.md`。
>
> **本 skill 只產數據。** 要把地圖變成手繪風格的地區圖（image-to-image）→ 用 **gen-art** 的「地圖風格化」段（`stitch_map.py`＋`stylize_map.py`）。

## 前置

- **Godot 4.7 執行檔**（headless）：`/Applications/Godot.app/Contents/MacOS/Godot`。
- 首次在乾淨 checkout 上跑，若報 `Identifier "RegionDef"/"MapKit" not declared`，先重建 class 快取：
  `Godot --headless --import --path godot-project`（跑到 exit 0，別中途砍）。開過編輯器則會自動重掃。

## 地區 recipe 格式

recipe 是 typed Resource（`RegionDef` → `MapDef` → `MapExitDef`，在 Godot 編輯器 Inspector 可直接編輯），
存 `resources/map/regions/<region_id>.tres`。範例：`resources/map/regions/east_forest.tres`。
生成器也吃 `.json`（欄位同下；給 `.json` 會順便存一份 `.tres` recipe），範例見
`.Codex/skills/gen-region/examples/east_forest.json`、`sample_region.json`：

```jsonc
{
  "region_id": "crystal_mine",
  "seed": 51,                       // 決定性；同 seed 同設定產出一致（Godot RNG）
  "maps": [
    {
      "id": "cmine_b1",             // 唯一 id，也是 .tscn 檔名與 encounter map_id
      "scene_name": "CMineB1",      // SceneRouter 邏輯名（exits 的 to 指向它）
      "kind": "mine",               // mine | cave | forest | grassland
      "w": 34, "h": 26,             // tile 尺寸
      "complexity": "medium",       // maze 專用：low | medium | high（開放房間數量）
      "layout": "open",             // ""＝依 kind 預設；open（forest/grassland）| maze（mine/cave）
      "openness": "medium",         // open 專用：wide | medium | tight＝路的寬窄（障礙覆蓋率）
      "level_band": [5, 8],         // 自動選怪的難度帶
      "enemies": "auto",            // "auto" 自動；或明列 ["wogol","orc"]（hybrid 指定端）
      "entries": ["Town"],          // 選填：從設定外既有場景進來→自動建 from_Town 落點
      "boss": { "enemy": "goblin_chief", "show_when": "" },  // 選填：迷宮最深處擺 boss
      "exits": [
        { "to": "cmine_b2", "at": "east" },                  // at=east/west/north/south → 擺該邊緣＋鑿開口
        { "to": "Town", "at": "west", "spawn": "shrine" }    // to 可指設定外場景（帶對方 spawn）
      ]
    }
  ]
}
```

**出入口怎麼對得上**：A 的 `exits[].to = B` 會在 A 產一個 exit（`spawn="from_A"`），驅動器**自動在 B 建 `from_A` spawn**——目標落點一定存在，連通性 assert 也會檢查兩端可達。`at`（east/west/north/south；up/down 視為 north/south）決定出入口擺在**哪個地圖邊緣**，並在牆上**鑿 2 寬通道口**讓連通處在圖上明顯可見；同一連線的 exit 與 spawn 共用同一道門。

**接回既有世界**：`to` 指到設定外的既有場景（如 `"Town"`）時，該 exit 落點用你給的 `spawn`（對方場景要有的 spawn_id）；配 `entries: ["Town"]` 會在本圖建 `from_Town` 落點。這些跨場景接口由 wiring 報告列出、你手動接。

**boss**：`boss: {"enemy": <id>, "show_when": "", "adds": true}` → 在迷宮**最深處**（離入口最遠）擺 BossMark，產 `<map_id>_boss` encounter（boss＋隨從）。boss 戰鬥圖走 `res://assets/battle/foe_<sprite>_0.png`。

**支援的地形（誠實清單——只吃現有 32px 素材）**：
- ✅ `grassland` 草原、`forest` 森林（含高草遭遇區）、`mine` 礦坑（碎石遭遇）、`cave` 洞窟（整片遭遇）
- ❌ 水/湖、沙、雪：**目前無對應圖磚**，不支援（見「主題可換」）。`town` 是手工地圖，不自動生成。

**佈局 layout**：
- `open`（forest/grassland 預設）＝滿地可走、散佈有機樹叢（`openness` 調路寬窄）、**外圈用樹牆圍住、只在出入口鑿缺口**、並鑿 **`dirt` 土路小徑**串起各出入口引導玩家。forest/grassland 還會自動擺**樹（fst_tree_*）＋花草裝飾（fst_deco_*）prop** 增加完整度（`stitch_map.py` 預覽也會把 prop 畫出來）。
- `maze`（mine/cave 預設）＝牆到牆的完美迷宮（固定 2 寬走廊）。
- ⚠️ 土路用 `dirt`＋不 autotile（`atlas_forest` 缺 path 的橫向/內角變體，autotile 會變黑）。

## 用法

```bash
# 位置：repo 根 godot-crystal-tales/。先 --dry-run 只驗證不寫檔。
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
PROJ="$(pwd)/godot-project"
CFG="$(pwd)/.Codex/skills/gen-region/examples/east_forest.json"   # 或 res://resources/map/regions/<id>.tres

timeout 120 "$GODOT" --headless -s res://scripts/map/region_generator.gd --path "$PROJ" -- "$CFG" --dry-run
timeout 120 "$GODOT" --headless -s res://scripts/map/region_generator.gd --path "$PROJ" -- "$CFG"
```

- 輸入吃**絕對路徑或 `res://` 路徑**；`.tres` 直接 load，`.json` 用 `from_dict` 建並順便存 `.tres`。
- ⚠️ headless 一律綁 `timeout`：若腳本在 `quit()` 前出 runtime error，Godot 會空轉不結束（見 memory `godot-run-validate`）。

**產完要出美術地區圖** → 交給 gen-art（見 gen-art SKILL.md「地圖風格化」）：
```bash
python3 .Codex/skills/gen-art/stitch_map.py godot-project/scenes/world/<id>.tscn --out /tmp/stitch.png
python3 .Codex/skills/gen-art/stylize_map.py --in-image /tmp/stitch.png --prompt "<主題>" --out godot-project/assets/ui/region_<id>.png
```

## 產出後「要接的線」（重要）

生成器**不會**自動改共享檔案（依專案治理：`scene_router.gd`／`content_db.tres`／`pacing.tres` 各有 owner）。它跑完會**列印**要接的線，請手動套用：

1. `autoload/scene_router.gd` 的 `SCENE_PATHS` 加入每張圖的 `"<scene_name>": "res://scenes/world/<id>.tscn"`。
2. `content_db.tres` 的 `encounters` 陣列聚合新的 `encounters/<id>.tres`（含 `<id>_boss.tres`；否則 `ContentDB` 讀不到，戰鬥會 fallback）。
3. `pacing.tres` 加入每張圖的 `entryLv/targetLv`（EXP 縮放用）。
4. 若有 `entries`／指向既有場景的 `exit`：在對方場景（如 Town）補對應的 exit／spawn（報告的第 ④ 段）。

## 敵人策略（hybrid，優先現有）

`enemies: "auto"` → 依 `level_band` 從現有敵人（`ContentDB.get_all_enemies()`）挑 exp 落在該帶的怪、組 3–4 個 formation（v2 結構：每組帶 `weight` 與 `members` 數量範圍，見 `specs/BATTLE_FORMULAS.md` F-11）。**敵人資料無 level 欄位**，等級帶用 exp 粗估（錨點對齊現有 encounter 表分佈；`_exp_cap` 收緊上限避免低帶混入中階怪）。也可 `enemies: [...]` **明列**（森林建議林地怪 bird/gslime/goblin/worm/wolf，避開礦坑怪）。該帶無合適怪時回退最接近的並印警告——需符合難度的新怪時另補 `EnemyDef`（戰鬥圖是像素素材，Gemini 生不了，要另補 sprite）。

## 主題可換（未來上 16px 包）

地形主題收斂在 `scripts/map/map_kit.gd` 的 `THEME` 表（每個 `kind` → base tile / tileset / atlas / floor）。日後要接 Pixel Crawler(16px，有水) 或別套 tileset，只要新增 tileset/atlas + 在 `THEME`（與 `carve_kind` 的 tile 語意）加一個主題，不用重寫 skill。v1 用現有 32px vocabulary。

## 驗證

- 生成器內建：**連通性 assert**（每入口可達每出口/落點/boss，失敗則 quit 1 不寫檔）；`.tscn` 靠 `PackedScene.pack` 的 err 回傳把關。
- 結構化測試：`bash .Codex/skills/gen-region/test.sh`（跑範例的 `--dry-run`）。
- 產完 + 接好 `SCENE_PATHS` 後跑冒煙測試確認引擎載入 OK：
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/smoke_test.gd --path "$(pwd)/godot-project"
  ```
  （把新 `scene_name`/`.tscn` 加進 `smoke_test.gd` 的 `SCENES` 表即會一起檢查。⚠️ 別用 `--check-only --path .`，不加 `--script` 會卡死。）

## 邊界

- `town` 不自動生成（手工地圖）；水/雪目前無 32px 素材。
- 不自動改共享檔（只回報 wiring）；不修改 `reference/gdevelop/`（唯讀凍結快照）。
- 現有 5 張圖（town/forest/forest2/mine/cave）是**凍結的 authored 內容**，不由本生成器重生（見 `TASKS/12_地圖生成器.md`）。
